import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

import '../features/review/application/review_correction_saver_test.dart';
import '../features/review/application/review_entry_saver_test.dart'
    show reviewDate, goalId;
import 'review_form_entry_test.dart' show settleNative, tapText;
import 'review_submission_flow_test.dart' show enter;
import 'support/checked_sleep_opening.dart';

void main() {
  late CorrectionHarness h;
  setUp(() async {
    h = CorrectionHarness();
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
      reason: 'Drain real NativeDatabase close continuations.',
    );
    await t.runAsync(() => pending);
  }

  Future<void> host(WidgetTester t) async {
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
    await tapText(t, '编辑复盘草稿');
    expect(find.text('保存复盘'), findsNothing);
    expect(find.text('保存更正'), findsOneWidget);
  }

  testWidgets(
    'actual bootstrap restores edit draft, retains archived Goal, saves moved date and no-op without changing identity or creation time',
    (t) async {
      await sized(t);
      await t.runAsync(() async {
        final goals = DriftGoalRepository(h.db);
        await goals.create(id: goalId, name: '原归档目标', now: 1);
        await seedReview(h, goal: goalId);
        await goals.archive(id: goalId, now: 20);
        await h.drafts.save(
          correction(
            summary: '',
            reflection: '',
            step: '  恢复的下一步\n\n内部格式😀  ',
            goal: goalId,
          ),
        );
      });
      h.clock = DateTime(2025, 12, 31, 12).millisecondsSinceEpoch;
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => h.db,
          openDrafts: () async => recording,
          openReviewDrafts: () async => h.drafts,
          openSleepOpenings: () => openCheckedSleepOpening(
            DateTime.fromMillisecondsSinceEpoch(h.clock),
          ),
          now: () => DateTime.fromMillisecondsSinceEpoch(h.clock),
        ),
      );
      await settleNative(t);
      await tapText(t, '打开按日复盘');
      await tapText(t, '编辑复盘草稿');
      expect(find.text('已恢复未保存的复盘输入。'), findsOneWidget);
      expect(find.text('下一步目标：原归档目标（已归档）'), findsOneWidget);
      final original = (await t.runAsync(
        () => h.reviews.findByDate(reviewDate),
      ))!;
      expect(original.reflection, '原反思');
      await enter(t, 'review-date', '2024-02-29');
      final save = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, '保存更正'))
          .onPressed!;
      save();
      save();
      await settleNative(t);
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('已存复盘日期：2024-02-29'), findsOneWidget);
      expect(find.text('下一自然日：2024-03-01'), findsOneWidget);
      final saved = (await t.runAsync(
        () => h.reviews.findByDate(CivilDate(year: 2024, month: 2, day: 29)),
      ))!;
      expect(saved.id, sourceId);
      expect(saved.createdAt, 10);
      expect(saved.updatedAt, h.clock);
      expect(saved.summary, isNull);
      expect(saved.reflection, isNull);
      expect(saved.tomorrowFirstStep.goalId, goalId);
      expect(await t.runAsync(() => h.reviews.findByDate(reviewDate)), isNull);
      expect(await t.runAsync(() => h.drafts.read(editContext)), isNull);
      h.clock += 5000;
      await tapText(t, '编辑复盘草稿');
      await tapText(t, '保存更正');
      final noChange = (await t.runAsync(
        () => h.reviews.findByDate(saved.date),
      ))!;
      expect(noChange.id, saved.id);
      expect(noChange.updatedAt, saved.updatedAt);
      expect((await t.runAsync(() => rows(h)))!.length, 1);
      await unmount(t);
    },
  );

  testWidgets(
    'date conflict keeps raw edit and both reviews; source deleted after read reports missing and never recreates',
    (t) async {
      await sized(t);
      await t.runAsync(() => seedReview(h));
      await host(t);
      await enter(t, 'review-date', '2024-02-29');
      await enter(t, 'review-reflection', '  更正失败仍保留\n\n😀  ');
      await t.runAsync(
        () => h.traced.inner.create(
          id: replacementId,
          date: CivilDate(year: 2024, month: 2, day: 29),
          tomorrowFirstStepText: '竞争者原文',
          now: 20,
        ),
      );
      final before = (await t.runAsync(() => rows(h)))!;
      await tapText(t, '保存更正');
      expect(find.textContaining('该日期已有复盘，未覆盖'), findsOneWidget);
      expect(await t.runAsync(() => rows(h)), before);
      expect(
        (await t.runAsync(() => h.drafts.read(editContext)))!.reflection,
        '  更正失败仍保留\n\n😀  ',
      );
      await enter(t, 'review-date', '2025-12-31');
      await t.runAsync(() => h.traced.inner.delete(sourceId));
      await tapText(t, '保存更正');
      expect(find.textContaining('原复盘已不存在'), findsOneWidget);
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(h.traced.updates, 2);
      expect(h.traced.creates, 0);
      expect(await t.runAsync(() => h.reviews.findByDate(reviewDate)), isNull);
      expect((await t.runAsync(() => rows(h)))!.length, 1);
      await tapText(t, '返回');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(await t.runAsync(() => h.drafts.read(editContext)), isNotNull);
      await unmount(t);
    },
  );

  testWidgets(
    'post-update clear/read failure feedback freezes input and retries only finalization',
    (t) async {
      await sized(t);
      await t.runAsync(() => seedReview(h));
      await host(t);
      await enter(t, 'review-summary', '  正式更正概述  ');
      await t.runAsync(() => h.failClear(true));
      h.failRefresh = true;
      await tapText(t, '保存更正');
      expect(find.text('此复盘已正式保存。'), findsOneWidget);
      expect(find.textContaining('本地收尾和读回失败'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-summary')))
            .enabled,
        false,
      );
      expect(
        t
            .widget<TextButton>(find.widgetWithText(TextButton, '放弃此复盘草稿'))
            .onPressed,
        isNull,
      );
      final committed = (await t.runAsync(
        () => h.reviews.findByDate(reviewDate),
      ))!;
      expect(committed.summary, '正式更正概述');
      expect(committed.id, sourceId);
      await t.runAsync(() => h.failClear(false));
      h.clock += 1000;
      await tapText(t, '重试复盘收尾');
      expect(find.textContaining('复盘已保存，但读回失败'), findsOneWidget);
      h.failRefresh = false;
      await tapText(t, '重试复盘收尾');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('正式更正概述'), findsOneWidget);
      expect(
        (await t.runAsync(() => h.reviews.findByDate(reviewDate)))!.updatedAt,
        committed.updatedAt,
      );
      expect(h.traced.updates, 1);
      expect(h.traced.creates, 0);
      expect(await t.runAsync(() => h.drafts.read(editContext)), isNull);
      await unmount(t);
    },
  );
}
