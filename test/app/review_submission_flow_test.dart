import '../support/ledger_date_selection.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:drift/native.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import '../features/review/application/review_entry_saver_test.dart'
    show ReviewHarness, reviewDate, draftContext, goalId;
import 'review_form_entry_test.dart' show settleNative, tapText;
import 'support/checked_sleep_opening.dart';

Future<void> enter(WidgetTester t, String key, String value) async {
  if (key == 'review-date') await tapText(t, '修改日期');
  if (['review-summary', 'review-reflection'].contains(key) &&
      find.byKey(ValueKey(key)).evaluate().isEmpty) {
    await tapText(t, '再写几句 ＋');
  }
  final finder = find.byKey(ValueKey(key));
  await t.ensureVisible(finder);
  await t.enterText(finder, value);
  await settleNative(t);
  if (key == 'review-date') await tapText(t, '应用日期');
}

Future<void> host(WidgetTester t, ReviewHarness h) async {
  final routes = RouteObserver<ModalRoute<void>>();
  await t.pumpWidget(
    MaterialApp(
      navigatorObservers: [routes],
      home: ReviewContextPage(
        loader: createReviewContextLoader(h.db),
        drafts: h.drafts,
        saver: h.saver,
        goals: DriftGoalRepository(h.db),
        now: () => h.clock,
        dateOfInstant: (_) => reviewDate,
        initialDate: reviewDate,
        routeObserver: routes,
      ),
    ),
  );
  await settleNative(t);
  await tapText(t, '填写复盘');
}

void main() {
  late ReviewHarness h;
  setUp(() async {
    h = ReviewHarness();
    await h.open();
  });

  Future<void> sized(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  Future<void> unmount(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    var closed = false;
    late Future<void> pending;
    await t.runAsync(() async {
      pending = h.close().then((_) => closed = true);
    });
    for (var i = 0; i < 100 && !closed; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(
      closed,
      true,
      reason:
          'Drain native and fake-async close continuations before teardown.',
    );
    await t.runAsync(() => pending);
  }

  testWidgets(
    'actual bootstrap submits only a step with remaining Gap, fast repeat click creates one row and reads changed historical date',
    (t) async {
      await sized(t);
      final clock = DateTime.fromMillisecondsSinceEpoch(h.clock);
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => h.db,
          openDrafts: () async => recording,
          openReviewDrafts: () async => h.drafts,
          openSleepOpenings: () => openCheckedSleepOpening(clock),
          now: () => clock,
        ),
      );
      await settleNative(t);
      await tapText(t, '打开按日复盘');
      await tapText(t, '填写复盘');
      await enter(t, 'review-date', '2025-12-31');
      await enter(t, 'review-step', '  用户第一步\n\n  保留内部格式😀  ');
      await tapText(t, '查看当日事实');
      expect(find.text('尚未记录：24 小时'), findsOneWidget);
      final save = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存复盘'))
          .onPressed!;
      save();
      save(); // Two callbacks before a repaint still share the controller guard.
      await settleNative(t);
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('已存复盘日期：2025-12-31'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-01'), findsOneWidget);
      expect(find.text('用户第一步\n\n  保留内部格式😀'), findsOneWidget);
      final rows = (await t.runAsync(
        () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
      ))!;
      expect(rows.length, 1);
      expect(rows.single.data['summary'], isNull);
      expect(rows.single.data['reflection'], isNull);
      expect(rows.single.data['tomorrow_first_step_goal_id'], isNull);
      expect(rows.single.data['created_at'], h.clock);
      expect(
        await t.runAsync(
          () => h.drafts.read(
            ReviewDraftContext.newEntry(
              date: CivilDate(year: 2026, month: 10, day: 2),
            ),
          ),
        ),
        isNull,
      );
      await tapText(t, '编辑复盘草稿');
      expect(find.text('保存复盘'), findsNothing);
      await enter(t, 'review-reflection', '仅修改编辑草稿');
      await tapText(t, '保留草稿并返回');
      expect(
        (await t.runAsync(() => h.reviews.findByDate(reviewDate)))!.reflection,
        isNull,
      );
      await unmount(t);
    },
  );

  testWidgets(
    'real clear and refresh failures are post-commit feedback; retry cannot create, edit or discard the saved review',
    (t) async {
      await sized(t);
      await t.runAsync(() => h.failClear(true));
      h.failRefresh = true;
      await host(t, h);
      await enter(t, 'review-step', '已提交的步骤😀');
      await tapText(t, '保存复盘');
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(find.textContaining('草稿清理和读回失败'), findsOneWidget);
      expect(find.text('保存复盘'), findsNothing);
      expect(
        t.widget<TextField>(find.byKey(const ValueKey('review-step'))).enabled,
        false,
      );
      await t.tap(find.byTooltip('更多'));
      await settleNative(t);
      expect(
        t
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, '放弃此复盘草稿'),
            )
            .enabled,
        isFalse,
      );
      await t.binding.handlePopRoute();
      await settleNative(t);
      final saved = (await t.runAsync(() => h.reviews.findByDate(reviewDate)))!;
      expect(await t.runAsync(() => h.drafts.read(draftContext)), isNotNull);
      expect(h.reviews.creates, 1);
      await t.runAsync(() => h.failClear(false));
      await tapText(t, '重试复盘收尾');
      expect(find.textContaining('复盘已保存，但读回失败'), findsOneWidget);
      expect(await t.runAsync(() => h.drafts.read(draftContext)), isNull);
      h.failRefresh = false;
      await tapText(t, '重试复盘收尾');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('已提交的步骤😀'), findsOneWidget);
      final reread = (await t.runAsync(
        () => h.reviews.findByDate(reviewDate),
      ))!;
      expect(reread.id, saved.id);
      expect(reread.updatedAt, saved.updatedAt);
      expect(h.reviews.creates, 1);
      expect(find.textContaining('private SQL'), findsNothing);
      await unmount(t);
    },
  );

  testWidgets(
    'return and reopen original entry recovers a changed-date residual draft without another create',
    (t) async {
      await sized(t);
      await t.runAsync(() => h.failClear(true));
      await host(t, h);
      await enter(t, 'review-date', '2024-02-29');
      await enter(t, 'review-step', '已提交的历史步骤');
      await tapText(t, '保存复盘');
      expect(find.textContaining('草稿清理失败'), findsOneWidget);
      await tapText(t, '返回复盘读取');
      expect(find.text('已存复盘日期：2024-02-29'), findsOneWidget);
      await selectLedgerDate(t, '2025-12-31');
      await settleNative(t);
      await tapText(t, '填写复盘');
      expect(find.textContaining('草稿清理失败'), findsOneWidget);
      expect(find.text('已恢复未保存的复盘输入。'), findsNothing);
      expect(find.text('保存复盘'), findsNothing);
      expect(h.reviews.creates, 1);
      await t.runAsync(() => h.failClear(false));
      await tapText(t, '重试复盘收尾');
      expect(find.text('已存复盘日期：2024-02-29'), findsOneWidget);
      expect(h.reviews.creates, 1);
      expect(await t.runAsync(() => h.drafts.read(draftContext)), isNull);
      await unmount(t);
    },
  );

  testWidgets(
    'Goal archive/delete after choice and another review created after form read reject writes; manual date/Goal correction succeeds without overwrite',
    (t) async {
      await sized(t);
      final goals = DriftGoalRepository(h.db);
      const secondGoal = '00000000-0000-4000-8000-000000000002';
      const competitor = '00000000-0000-4000-8000-000000000003';
      await t.runAsync(() async {
        await goals.create(id: goalId, name: '选后归档', now: 1);
        await goals.create(id: secondGoal, name: '选后删除', now: 1);
      });
      await host(t, h);
      await enter(t, 'review-step', '失败也保留的步骤');
      await tapText(t, '选择下一步目标');
      await tapText(t, '选后归档');
      await t.runAsync(() => goals.archive(id: goalId, now: 2));
      await tapText(t, '保存复盘');
      expect(find.textContaining('目标已归档或不存在'), findsOneWidget);
      expect(
        (await t.runAsync(() => h.drafts.read(draftContext)))!
            .tomorrowFirstStepGoalId,
        goalId,
      );
      final model = t.widget<ReviewForm>(find.byType(ReviewForm)).controller;
      await t.runAsync(model.loadGoals);
      await settleNative(t);
      await tapText(t, '选择下一步目标');
      await tapText(t, '选后删除');
      await t.runAsync(() => goals.delete(id: secondGoal, now: 3));
      await tapText(t, '保存复盘');
      expect(find.textContaining('目标已归档或不存在'), findsOneWidget);
      await tapText(t, '清空目标关联');
      await t.runAsync(
        () => DriftReviewRepository(h.db).create(
          id: competitor,
          date: reviewDate,
          tomorrowFirstStepText: '另一份已存复盘',
          now: 4,
        ),
      );
      await tapText(t, '保存复盘');
      expect(find.textContaining('该日期已有复盘，未覆盖'), findsOneWidget);
      expect(model.firstStep, '失败也保留的步骤');
      expect(
        (await t.runAsync(() => h.reviews.findByDate(reviewDate)))!.id,
        competitor,
      );
      await enter(t, 'review-date', '2026-01-01');
      await tapText(t, '保存复盘');
      expect(find.text('已存复盘日期：2026-01-01'), findsOneWidget);
      expect(find.text('失败也保留的步骤'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-02'), findsOneWidget);
      expect(
        (await t.runAsync(() => h.reviews.findByDate(reviewDate)))!
            .tomorrowFirstStep
            .text,
        '另一份已存复盘',
      );
      expect(await t.runAsync(() => h.drafts.read(draftContext)), isNull);
      await unmount(t);
    },
  );

  testWidgets(
    'blank/overlong feedback retains raw input; real formal SQL failure retains draft and correction retry succeeds',
    (t) async {
      await sized(t);
      await host(t, h);
      await tapText(t, '保存复盘');
      expect(find.textContaining('请检查复盘日期与文字'), findsOneWidget);
      expect(h.reviews.creates, 0);
      await enter(t, 'review-step', '用户步骤');
      final over = ' ${'😀' * 2001} ';
      await enter(t, 'review-summary', over);
      await tapText(t, '保存复盘');
      expect(h.reviews.creates, 0);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-summary')))
            .controller!
            .text,
        over,
      );
      await enter(t, 'review-summary', '  多行\n\n  概述😀  ');
      await t.runAsync(() => h.failWrite(true));
      await tapText(t, '保存复盘');
      expect(find.textContaining('正式保存失败，输入和草稿已保留'), findsOneWidget);
      expect(
        (await t.runAsync(() => h.drafts.read(draftContext)))!.summary,
        '  多行\n\n  概述😀  ',
      );
      expect(await t.runAsync(() => h.reviews.findByDate(reviewDate)), isNull);
      expect(find.textContaining('private SQL'), findsNothing);
      await t.runAsync(() => h.failWrite(false));
      await tapText(t, '保存复盘');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('多行\n\n  概述😀'), findsOneWidget);
      expect(h.reviews.creates, 2);
      expect(await t.runAsync(() => h.drafts.read(draftContext)), isNull);
      await unmount(t);
    },
  );
}
