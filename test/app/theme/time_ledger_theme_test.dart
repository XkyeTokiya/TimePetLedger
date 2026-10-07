import '../../support/ledger_date_selection.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import '../../support/rendered_text_contrast.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import '../../features/ledger/presentation/recording_form_controller_test.dart'
    show FormDraftStore, formContext;
import '../support/checked_sleep_opening.dart';

const captureKey = ValueKey('theme-capture');

void configureView(WidgetTester tester, double width, double scale) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['UI_T02_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> guidelines(
  WidgetTester tester, {
  bool standardPixelContrast = false,
}) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (standardPixelContrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  await expectLater(
    tester,
    meetsGuideline(const RenderedTextContrast(captureKey: captureKey)),
  );
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> mountForm(WidgetTester tester, FormDraftStore store) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        theme: timeLedgerTheme,
        home: RecordingForm(
          context: formContext,
          store: store,
          loadSuggestion: () async => const ManualTimeEntry(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    // Local fonts only improve captured test evidence; production uses system
    // fonts and adds no assets or font dependency.
    final font = Platform.environment['UI_T02_FONT_PATH'];
    if (font != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        File(font).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });

  for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
    testWidgets('startup loading and failure at $width / $scale', (
      tester,
    ) async {
      configureView(tester, width, scale);
      final semantics = tester.ensureSemantics();
      final pending = Completer<AppDatabase>();
      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: AppBootstrap(openDatabase: () => pending.future),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('日账本'), findsNothing);
        final loadingTheme = Theme.of(
          tester.element(find.byType(CircularProgressIndicator)),
        );
        expect(loadingTheme.brightness, Brightness.light);
        await capture(tester, 'loading-$width-$scale');
        // No text or interactive target exists in this original loading state.
        await guidelines(tester, standardPixelContrast: true);
        pending.completeError(const DatabaseOpenException('private SQL path'));
        await tester.pumpAndSettle();
        final failure = find.text('无法打开本地存储，请重新启动应用。');
        expect(failure, findsOneWidget);
        expect(find.textContaining('private SQL'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        final failedTheme = Theme.of(tester.element(failure));
        expect(failedTheme.colorScheme, loadingTheme.colorScheme);
        expect(
          failedTheme.scaffoldBackgroundColor,
          loadingTheme.scaffoldBackgroundColor,
        );
        expect(tester.takeException(), isNull);
        await capture(tester, 'failure-$width-$scale');
        await guidelines(tester, standardPixelContrast: true);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    });
  }

  for (final (width, scale) in [(360.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'ready app retains date error and original entries at $width / $scale',
      (tester) async {
        configureView(tester, width, scale);
        final semantics = tester.ensureSemantics();
        final now = DateTime(2026, 10, 3, 12);
        final database = (await tester.runAsync(
          () => AppDatabase.open(NativeDatabase.memory()),
        ))!;
        final drafts = (await tester.runAsync(
          () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
        ))!;
        final openings = (await tester.runAsync(
          () => openCheckedSleepOpening(now),
        ))!;
        try {
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: AppBootstrap(
                openDatabase: () async => database,
                openDrafts: () async => drafts,
                openSleepDrafts: emptyLegacySleepDrafts,
                openReviewDrafts: emptyLegacyReviewDrafts,
                openSleepOpenings: () async => openings,
                now: () => now,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('日账本'), findsOneWidget);
          expect(
            tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
            same(homeTheme),
          );
          await capture(tester, 'ready-$width-$scale');
          await guidelines(tester);
          await openManualLedgerDate(tester);
          await tester.enterText(
            find.widgetWithText(TextField, '账本日期'),
            'invalid',
          );
          await tester.tap(find.text('确认日期'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.widgetWithText(TextField, '账本日期'))
                .decoration!
                .errorText,
            isNotNull,
          );
          expect(
            find.byKey(const ValueKey('ledger-date-picker')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('home-record-activity')),
            findsOneWidget,
          );
          await capture(tester, 'ready-error-$width-$scale');
          await guidelines(tester);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          semantics.dispose();
        }
      },
    );
  }

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('existing form and time dialog at $width / $scale', (
        tester,
      ) async {
        configureView(tester, width, scale);
        final semantics = tester.ensureSemantics();
        final store = FormDraftStore();
        try {
          await mountForm(tester, store);
          await tapVisible(tester, find.text('记得'));
          final activity = find.byKey(const ValueKey('activity'));
          await Scrollable.ensureVisible(
            tester.element(activity),
            alignment: 0,
          );
          await tester.tap(activity);
          await tester.enterText(activity, '设计首页');
          await tester.pumpAndSettle();
          expect(
            tester.widget<TextField>(activity).focusNode?.hasFocus ??
                tester
                    .state<EditableTextState>(
                      find.descendant(
                        of: activity,
                        matching: find.byType(EditableText),
                      ),
                    )
                    .widget
                    .focusNode
                    .hasFocus,
            isTrue,
          );
          final inputTheme = Theme.of(tester.element(activity));
          final focusBorder = inputTheme.inputDecorationTheme.focusedBorder!;
          expect(
            focusBorder.borderSide.width,
            greaterThan(
              inputTheme.inputDecorationTheme.enabledBorder!.borderSide.width,
            ),
          );
          expect(focusBorder.borderSide.color, inputTheme.colorScheme.primary);
          await capture(tester, 'form-focus-$width-$scale');
          await guidelines(tester);

          // The fixture has no formal saver: the original save button remains
          // disabled and its appearance cannot make it an executable action.
          final save = find.widgetWithText(FilledButton, '保存到账本');
          if (save.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              save,
              250,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await Scrollable.ensureVisible(tester.element(save), alignment: .8);
          await tester.pumpAndSettle();
          expect(tester.widget<FilledButton>(save).onPressed, isNull);
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(find.text('补一笔'), findsOneWidget);
          await capture(tester, 'form-disabled-$width-$scale');
          await guidelines(tester);

          await tapVisible(tester, find.text('开始时间'));
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          final dialogTheme = Theme.of(tester.element(dialog));
          expect(dialogTheme.colorScheme, inputTheme.colorScheme);
          await tester.enterText(
            find.byKey(const ValueKey('time-dialog-input')),
            'invalid',
          );
          await tester.tap(find.widgetWithText(TextButton, '确认'));
          await tester.pumpAndSettle();
          final error = find.text('请输入有效日期和时间，格式为 YYYY-MM-DD HH:mm。');
          expect(error, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
            isFalse,
          );
          expect(tester.takeException(), isNull);
          await capture(tester, 'dialog-error-$width-$scale');
          await guidelines(tester);
          await tester.tap(find.widgetWithText(TextButton, '取消'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.widgetWithText(ListTile, '未填写'), findsNWidgets(2));
          expect(store.value!.title, '设计首页');
          expect(store.value!.startedAt, isNull);
          expect(store.value!.endedAt, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          semantics.dispose();
        }
      });
    }
  }
}
