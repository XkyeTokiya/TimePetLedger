import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import '../support/page_t01_fixture.dart';

const imageKey = ValueKey('page-t01-image');

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, String text) async {
  final finder = find.text(text);
  await t.ensureVisible(finder);
  await t.tap(finder);
  await settle(t);
}

Future<void> capture(WidgetTester t, String screen) async {
  expect(t.takeException(), isNull);
  final directory = Platform.environment['EDITOR_CAPTURE'];
  if (directory == null) return;
  await t.runAsync(() async {
    final image = await t
        .renderObject<RenderRepaintBoundary>(find.byKey(imageKey))
        .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$screen.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> mount(WidgetTester t, Widget page) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(360, 800);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.reset);
  final font = Platform.environment['HOME_FONT'];
  if (font != null) {
    await t.runAsync(() async {
      await (FontLoader(
        'PageT01',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    });
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  await t.pumpWidget(
    MaterialApp(
      theme: font == null
          ? timeLedgerTheme
          : timeLedgerTheme.copyWith(
              textTheme: timeLedgerTheme.textTheme.apply(fontFamily: 'PageT01'),
            ),
      builder: (context, child) =>
          RepaintBoundary(key: imageKey, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => page)),
            child: const Text('打开夹具'),
          ),
        ),
      ),
    ),
  );
  await tap(t, '打开夹具');
  expect(t.testTextInput.isVisible, isFalse);
}

Future<void> unmount(WidgetTester t, PageT01Fixture f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await t.pumpWidget(const SizedBox());
  await settle(t);
  var closed = false;
  late Future<void> pending;
  await t.runAsync(() async {
    pending = f.close().then((_) => closed = true);
  });
  for (var i = 0; i < 100 && !closed; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(closed, isTrue, reason: 'Drain native close and widget continuations');
  await t.runAsync(() => pending);
}

void main() {
  testWidgets('V01 real Gap save and V06 atomic conflict retains input', (
    t,
  ) async {
    final f = (await t.runAsync(PageT01Fixture.open))!;
    await t.runAsync(f.seedWalk);
    await mount(
      t,
      RecordingForm(
        context: PageT01Fixture.gap,
        store: f.recordingDrafts,
        entrySaver: f.recordingSaver,
        goals: f.goals,
        loadSuggestion: () async => DirectTimeSuggestion(
          RecordingTimeInput(
            startedAt: PageT01Fixture.instant(2, 10, 30),
            endedAt: PageT01Fixture.instant(2, 11),
          ),
        ),
      ),
    );
    await tap(t, '记得');
    await t.enterText(find.byKey(const ValueKey('activity')), '整理桌面');
    t.view.viewInsets = const FakeViewPadding(bottom: 232);
    await settle(t);
    final draft = (await t.runAsync(
      () => f.recordingDrafts.read(PageT01Fixture.gap),
    ))!;
    expect(draft.startPrecision, TimePrecision.approximate);
    expect(draft.endPrecision, TimePrecision.approximate);
    expect(draft.endedAt! - draft.startedAt!, 30 * 60000);
    expect(find.text('10:30 → 11:00'), findsOneWidget);
    expect(find.text('约30分钟'), findsOneWidget);
    final goalRect = t.getRect(
      find.byKey(const ValueKey('recording-goal-toggle')),
    );
    final rhythmRect = t.getRect(
      find.byKey(const ValueKey('recording-rhythm-toggle')),
    );
    expect(goalRect.top, rhythmRect.top);
    expect(goalRect.right, lessThan(rhythmRect.left));
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存到账本'))
          .onPressed,
      isNotNull,
    );
    await capture(t, 'V01');
    t.view.resetViewInsets();
    FocusManager.instance.primaryFocus?.unfocus();
    t.testTextInput.hide();
    await settle(t);
    await tap(t, '修改时间');
    await tap(t, '手动输入日期与时间');
    await t.ensureVisible(find.byKey(const ValueKey('time-end')));
    await t.enterText(
      find.byKey(const ValueKey('time-end')),
      '2026-10-02 11:15',
    );
    await tap(t, '应用时间');
    await tap(t, '保存到账本');
    expect(find.byType(RecordingForm), findsOneWidget);
    final retained = (await t.runAsync(
      () => f.recordingDrafts.read(PageT01Fixture.gap),
    ))!;
    expect(retained.title, '整理桌面');
    expect(retained.endedAt, PageT01Fixture.instant(2, 11, 15));
    final rows = (await t.runAsync(
      () => f.db.customSelect('SELECT * FROM time_blocks').get(),
    ))!;
    expect(rows.length, 1);
    expect(rows.single.data['id'], PageT01Fixture.walkId);
    expect(rows.single.data['ended_at'], PageT01Fixture.instant(2, 11, 30));
    expect(find.textContaining('冲突记录：'), findsOneWidget);
    expect(find.textContaining('散步 ·'), findsOneWidget);
    expect(find.textContaining(PageT01Fixture.walkId), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    t.testTextInput.hide();
    await settle(t);
    await capture(t, 'V06');
    expect(find.text('保存到账本'), findsNothing);
    expect(find.text('修改时间'), findsNothing);
    expect(find.textContaining('11:00–11:15'), findsOneWidget);
    await tap(t, '调整当前记录时间');
    await tap(t, '手动输入日期与时间');
    await t.ensureVisible(find.byKey(const ValueKey('time-end')));
    await t.enterText(
      find.byKey(const ValueKey('time-end')),
      '2026-10-02 11:00',
    );
    await tap(t, '应用时间');
    await tap(t, '保存到账本');
    expect(find.byType(RecordingForm), findsNothing);
    final saved = (await t.runAsync(
      () => f.db
          .customSelect("SELECT * FROM time_blocks WHERE title = '整理桌面'")
          .get(),
    ))!;
    expect(saved.length, 1);
    expect(saved.single.data['start_precision'], 'approximate');
    expect(saved.single.data['end_precision'], 'approximate');
    expect(
      await t.runAsync(() => f.recordingDrafts.read(PageT01Fixture.gap)),
      isNull,
    );
    await unmount(t, f);
  });

  testWidgets(
    'V02 complete source edit and V05 cancel isolates temporary values',
    (t) async {
      final f = (await t.runAsync(PageT01Fixture.open))!;
      await t.runAsync(f.seedSleep);
      final context = SleepDraftContext.edit(
        date: PageT01Fixture.day,
        sleepSessionId: PageT01Fixture.sleepId,
      );
      final model = SleepFormController(
        context: context,
        store: f.sleepDrafts,
        entryEditor: f.sleepEditor,
        entrySaver: f.sleepSaver,
      );
      await mount(t, SleepForm(controller: model));
      expect(model.original!.id, PageT01Fixture.sleepId);
      expect(model.endedAt! - model.startedAt!, 460 * 60000);
      expect(model.startPrecision, TimePrecision.approximate);
      expect(model.endPrecision, TimePrecision.exact);
      await capture(t, 'V02');
      final before = await t.runAsync(() => f.sleepDrafts.read(context));
      await tap(t, '调整入睡与醒来');
      await capture(t, 'V05');
      await t.tap(find.widgetWithText(ChoiceChip, '准确').first);
      await tap(t, '手动输入日期与时间');
      await t.ensureVisible(find.byKey(const ValueKey('sleep-start')));
      await t.enterText(
        find.byKey(const ValueKey('sleep-start')),
        '2026-10-01 23:00',
      );
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(model.startedAt, PageT01Fixture.instant(1, 23, 40));
      expect(model.startPrecision, TimePrecision.approximate);
      expect(model.endPrecision, TimePrecision.exact);
      expect(await t.runAsync(() => f.sleepDrafts.read(context)), before);
      await tap(t, '保存更正');
      expect(find.byType(SleepForm), findsNothing);
      final rows = (await t.runAsync(
        () => f.db.customSelect('SELECT * FROM sleep_sessions').get(),
      ))!;
      expect(rows.length, 1);
      expect(rows.single.data['id'], PageT01Fixture.sleepId);
      expect(rows.single.data['started_at'], PageT01Fixture.instant(1, 23, 40));
      expect(rows.single.data['ended_at'], PageT01Fixture.instant(2, 7, 20));
      await unmount(t, f);
      model.dispose();
    },
  );

  for (final expanded in [false, true]) {
    testWidgets(
      expanded
          ? 'V04 expanded real review writing'
          : 'V03 step-only real review save',
      (t) async {
        final f = (await t.runAsync(PageT01Fixture.open))!;
        final model = ReviewFormController(
          context: ReviewDraftContext.newEntry(date: PageT01Fixture.day),
          store: f.reviewDrafts,
          entrySaver: f.reviewSaver,
          goals: f.goals,
        );
        await mount(
          t,
          ReviewForm(
            controller: model,
            loader: f.reviewLoader,
            now: () => PageT01Fixture.now,
            dateOfInstant: (_) => PageT01Fixture.day,
          ),
        );
        await t.enterText(
          find.byKey(const ValueKey('review-step')),
          '打开设计稿，\n先画补记弹层。',
        );
        t.view.viewInsets = FakeViewPadding(bottom: expanded ? 184 : 232);
        await settle(t);
        if (expanded) {
          await tap(t, '再写几句 ＋');
          expect(
            t
                .widget<TextField>(find.byKey(const ValueKey('review-summary')))
                .focusNode!
                .hasFocus,
            isTrue,
          );
          await t.enterText(
            find.byKey(const ValueKey('review-reflection')),
            '开始画图之前，先明确要解决的问题。',
          );
          await t.enterText(
            find.byKey(const ValueKey('review-summary')),
            '上午完成了首页草图。',
          );
          await t.ensureVisible(find.byKey(const ValueKey('review-summary')));
          await settle(t);
        }
        await capture(t, expanded ? 'V04' : 'V03');
        await tap(t, '保存复盘');
        expect(find.byType(ReviewForm), findsNothing);
        final saved = (await t.runAsync(
          () => f.reviews.findByDate(PageT01Fixture.day),
        ))!;
        expect(saved.tomorrowFirstStep.intendedDate.year, 2026);
        expect(saved.tomorrowFirstStep.intendedDate.month, 10);
        expect(saved.tomorrowFirstStep.intendedDate.day, 3);
        expect(saved.summary, expanded ? '上午完成了首页草图。' : isNull);
        await unmount(t, f);
        model.dispose();
      },
    );
  }
}
