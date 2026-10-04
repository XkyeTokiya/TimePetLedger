import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';

import '../features/ledger/presentation/sleep_form_controller_test.dart'
    show FormSleepStore;
import '../features/ledger/presentation/recording_form_controller_test.dart'
    show FormDraftStore;
import '../features/review/presentation/review_form_controller_test.dart'
    show MemoryDrafts;
import '../features/review/presentation/review_context_controller_test.dart'
    show contextFor;

void main() {
  testWidgets(
    'editor mobile matrix, continuous writing and staged time cancel',
    (t) async {
      final font = Platform.environment['HOME_FONT'];
      if (font != null) {
        await t.runAsync(() async {
          await (FontLoader('EditorCapture')
                ..addFont(File(font).readAsBytes().then(ByteData.sublistView)))
              .load();
        });
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final day = CivilDate(year: 2026, month: 10, day: 2);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetViewInsets);
      const imageKey = ValueKey('editor-capture');
      Future<void> capture(String name) async {
        final directory = Platform.environment['EDITOR_CAPTURE'];
        if (directory == null) return;
        await t.runAsync(() async {
          final image = await t
              .renderObject<RenderRepaintBoundary>(find.byKey(imageKey))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File('$directory/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final width in [360.0, 320.0, 412.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.view.physicalSize = Size(width, 800);
          Future<void> mount(Widget page) async {
            await t.pumpWidget(
              MaterialApp(
                key: UniqueKey(),
                theme: font == null
                    ? timeLedgerTheme
                    : timeLedgerTheme.copyWith(
                        textTheme: timeLedgerTheme.textTheme.apply(
                          fontFamily: 'EditorCapture',
                        ),
                      ),
                builder: (context, child) => RepaintBoundary(
                  key: imageKey,
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: page,
              ),
            );
            await t.pumpAndSettle();
            expect(t.testTextInput.isVisible, isFalse);
            expect(t.takeException(), isNull);
          }

          final sleepStore = FormSleepStore();
          final sleep = SleepFormController(
            context: SleepDraftContext.newEntry(date: day),
            store: sleepStore,
          );
          await sleep.initialize();
          sleep.setType(SleepType.mainSleep);
          sleep.setStartedAtInput('2026-10-01 23:40');
          sleep.setEndedAtInput('2026-10-02 07:20');
          sleep.setPrecision(
            start: TimePrecision.approximate,
            end: TimePrecision.exact,
          );
          await sleep.flush();
          await mount(SleepForm(controller: sleep));
          if (width == 360 && scale == 1) {
            await capture('sleep');
            await t.ensureVisible(find.text('调整入睡与醒来'));
            await t.tap(find.text('调整入睡与醒来'));
            await t.pumpAndSettle();
            await capture('sleep-time');
            await t.tap(find.widgetWithText(ChoiceChip, '准确').first);
            await t.pumpAndSettle();
            await t.tap(find.byType(BackButton));
            await t.pumpAndSettle();
            expect(sleep.startPrecision, TimePrecision.approximate);
          }
          await t.pumpWidget(const SizedBox());
          await sleep.flush();
          sleep.dispose();
          final activityStore = FormDraftStore();
          await mount(
            RecordingForm(
              context: RecordingDraftContext.gap(
                date: day,
                startedAt: DateTime(2026, 10, 2, 10, 30).millisecondsSinceEpoch,
                endedAt: DateTime(2026, 10, 2, 11).millisecondsSinceEpoch,
              ),
              store: activityStore,
              loadSuggestion: () async => DirectTimeSuggestion(
                RecordingTimeInput(
                  startedAt: DateTime(
                    2026,
                    10,
                    2,
                    10,
                    30,
                  ).millisecondsSinceEpoch,
                  endedAt: DateTime(2026, 10, 2, 11).millisecondsSinceEpoch,
                ),
              ),
            ),
          );
          await t.tap(find.text('记得'));
          await t.pumpAndSettle();
          await t.enterText(find.byKey(const ValueKey('activity')), '整理桌面');
          await t.pumpAndSettle();
          t.view.viewInsets = const FakeViewPadding(bottom: 232);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (width == 360 && scale == 1) await capture('activity-ime');
          t.view.resetViewInsets();
          t.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
          final review = ReviewFormController(
            context: ReviewDraftContext.newEntry(date: day),
            store: MemoryDrafts(),
          );
          await mount(
            ReviewForm(
              controller: review,
              loader: ReviewContextLoader(
                readContext: ({required date, required now}) async =>
                    contextFor(date),
              ),
              now: () => 1,
              dateOfInstant: (_) => day,
            ),
          );
          await t.enterText(
            find.byKey(const ValueKey('review-step')),
            '打开设计稿，\n先画补记弹层。',
          );
          await t.pumpAndSettle();
          t.view.viewInsets = const FakeViewPadding(bottom: 232);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (width == 360 && scale == 1) await capture('review-ime');
          await t.scrollUntilVisible(
            find.text('再写几句 ＋'),
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          await t.tap(find.text('再写几句 ＋'));
          await t.pumpAndSettle();
          expect(
            t
                .widget<TextField>(find.byKey(const ValueKey('review-summary')))
                .focusNode!
                .hasFocus,
            isTrue,
          );
          await t.enterText(
            find.byKey(const ValueKey('review-summary')),
            '上午完成了首页草图。',
          );
          await t.pumpAndSettle();
          if (width == 360 && scale == 1) await capture('review-expanded');
          expect(t.takeException(), isNull);
          t.view.resetViewInsets();
          t.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpWidget(const SizedBox());
          await review.leave();
          review.dispose();
        }
      }
    },
  );
}
