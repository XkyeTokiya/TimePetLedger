import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import 'recording_goal_flow_test.dart' show time;
import 'review_form_entry_test.dart' show settleNative, tapText;
import 'review_submission_flow_test.dart' show enter;

final historical = CivilDate(year: 2025, month: 12, day: 31);
final moved = CivilDate(year: 2026, month: 1, day: 1);
final today = CivilDate(year: 2026, month: 10, day: 2);
const goalId = '00000000-0000-4000-8000-000000000001';
const blockId = '00000000-0000-4000-8000-000000000002';
const annotationId = '00000000-0000-4000-8000-000000000003';
const reviewId = '00000000-0000-4000-8000-000000000004';

class ReadFault extends QueryInterceptor {
  bool failFacts = false;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failFacts && sql.contains('FROM time_blocks ')) {
      throw StateError('private fact read failure');
    }
    return executor.runSelect(sql, args);
  }
}

class RouteApp {
  RouteApp(
    this.dir,
    this.db,
    this.recording,
    this.drafts,
    this.openings,
    this.reads,
  );
  final Directory dir;
  final AppDatabase db;
  final DriftRecordingDraftStore recording;
  final DriftReviewDraftStore drafts;
  final DriftSleepOpeningStore openings;
  final ReadFault reads;
  DateTime clock = DateTime(2026, 10, 2, 12);
  DriftReviewRepository get reviews => DriftReviewRepository(db);

  static Future<RouteApp> open(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = (await t.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('review_routes_');
      final reads = ReadFault();
      final db = await AppDatabase.open(
        NativeDatabase(File('${dir.path}/facts.sqlite')).interceptWith(reads),
      );
      final recording = await DriftRecordingDraftStore.open(
        NativeDatabase(File('${dir.path}/recording.sqlite')),
      );
      final drafts = await DriftReviewDraftStore.open(
        NativeDatabase(File('${dir.path}/review.sqlite')),
      );
      final openings = await DriftSleepOpeningStore.open(
        NativeDatabase.memory(),
      );
      await openings.claim(today);
      await openings.claim(CivilDate(year: 2026, month: 10, day: 3));
      return RouteApp(dir, db, recording, drafts, openings, reads);
    }))!;
    addTearDown(() => app.close(t));
    return app;
  }

  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => recording,
        openReviewDrafts: () async => drafts,
        openSleepOpenings: () async => openings,
        now: () => clock,
      ),
    );
    await settleNative(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    var closed = false;
    late Future<void> pending;
    await t.runAsync(() async {
      pending = Future.wait([
        db.close(),
        recording.close(),
        drafts.close(),
        openings.close(),
      ]).then((_) => closed = true);
    });
    for (var i = 0; i < 100 && !closed; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(closed, true, reason: 'Drain app-owned native close continuations.');
    await t.runAsync(() => pending);
    await t.runAsync(() => dir.delete(recursive: true));
  }

  Future<List<Map<String, Object?>>> reviewRows() async =>
      (await db.customSelect('SELECT * FROM daily_reviews ORDER BY id').get())
          .map((r) => r.data)
          .toList();

  Future<Map<String, Object?>> facts() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  };

  Future<void> source({bool withGoal = false}) async {
    if (withGoal) {
      await DriftGoalRepository(db).create(id: goalId, name: '原目标', now: 1);
    }
    await DriftLedgerRepository(db).createTimeBlock(
      id: blockId,
      startedAt: DateTime(2025, 12, 31, 8).millisecondsSinceEpoch,
      endedAt: DateTime(2025, 12, 31, 9).millisecondsSinceEpoch,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '原活动',
      goalId: withGoal ? goalId : null,
      annotation: const AddAnnotation(
        id: annotationId,
        state: RhythmState.progress,
        continuationHint: '原记录接续点',
      ),
      now: 2,
    );
  }
}

Future<void> back(WidgetTester t) async {
  await t.pageBack();
  await settleNative(t);
}

Future<void> date(WidgetTester t, String label, String value) async {
  final input = find.widgetWithText(TextField, label);
  await t.ensureVisible(input);
  await t.enterText(input, value);
  await settleNative(t);
}

String input(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

void main() {
  testWidgets(
    'real summary save-return, historical ledger read/edit, move to new day and delete leave original facts intact',
    (t) async {
      final app = await RouteApp.open(t);
      await t.runAsync(() => app.source());
      final facts = await t.runAsync(app.facts);
      await app.mount(t);
      await date(t, '查看日期', '2025-12-31');
      await tapText(t, '打开基础摘要');
      expect(find.text('日期：2025-12-31'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      expect(find.text('当天事实上下文：2025-12-31'), findsOneWidget);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await tapText(t, '填写复盘');
      expect(input(t, 'review-date'), '2025-12-31');
      expect(input(t, 'review-summary'), '');
      expect(input(t, 'review-reflection'), '');
      expect(
        input(t, 'review-step'),
        '',
        reason: 'A continuation hint is not an automatic first step.',
      );
      expect(find.text('下一步目标：未关联（可选）'), findsOneWidget);
      expect(find.text('尚未记录：1380 分钟'), findsOneWidget);
      await enter(t, 'review-step', '仅由用户填写的下一步');
      await tapText(t, '保存复盘');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('已存复盘日期：2025-12-31'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-01'), findsOneWidget);
      expect(find.text('明天第一步'), findsOneWidget);
      expect(find.text('仅由用户填写的下一步'), findsOneWidget);
      final saved = (await t.runAsync(app.reviewRows))!.single;
      expect(saved['summary'], isNull);
      expect(saved['reflection'], isNull);
      expect(saved['tomorrow_first_step_goal_id'], isNull);
      await back(t);
      expect(find.byType(DaySummaryPage), findsOneWidget);
      expect(find.text('已交代：60 分钟'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      expect(find.text('已有复盘'), findsOneWidget);
      expect(find.text('填写复盘'), findsNothing);
      await back(t);
      await back(t);
      await tapText(t, '打开日账本');
      expect(find.text('接续点：原记录接续点'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      await tapText(t, '编辑复盘草稿');
      expect(input(t, 'review-step'), '仅由用户填写的下一步');
      expect(find.text('保存复盘'), findsNothing);
      await enter(t, 'review-date', '2026-01-01');
      await tapText(t, '保存更正');
      expect(find.text('已存复盘日期：2026-01-01'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-02'), findsOneWidget);
      final updated = (await t.runAsync(app.reviewRows))!.single;
      expect(updated['id'], saved['id']);
      expect(updated['created_at'], saved['created_at']);
      expect(
        await t.runAsync(() => app.reviews.findByDate(historical)),
        isNull,
      );
      expect(
        (await t.runAsync(() => app.reviews.findByDate(moved)))!.id,
        saved['id'],
      );
      await back(t);
      expect(find.text('日期：2025-12-31'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await back(t);
      await date(t, '账本日期', '2026-01-01');
      await tapText(t, '打开此日复盘');
      expect(find.text('仅由用户填写的下一步'), findsOneWidget);
      await tapText(t, '编辑复盘草稿');
      await tapText(t, '删除复盘');
      await tapText(t, '确认删除');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await back(t);
      expect(find.text('日期：2026-01-01'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(find.text('仅由用户填写的下一步'), findsNothing);
      await tapText(t, '填写复盘');
      expect(input(t, 'review-step'), '');
      await tapText(t, '保留草稿并返回');
      expect(await t.runAsync(app.reviewRows), isEmpty);
      expect(await t.runAsync(app.facts), facts);
    },
  );

  testWidgets(
    'actual fact correction refreshes ledger, summary and review context while archived original Goal and review text keep their source',
    (t) async {
      final app = await RouteApp.open(t);
      await t.runAsync(() async {
        await app.source(withGoal: true);
        await app.reviews.create(
          id: reviewId,
          date: historical,
          summary: '已存概述',
          reflection: '已存反思\n保留段落',
          tomorrowFirstStepText: '已存明天第一步',
          tomorrowFirstStepGoalId: goalId,
          now: 3,
        );
        await DriftGoalRepository(app.db).archive(id: goalId, now: 4);
      });
      final original = await t.runAsync(app.reviewRows);
      await app.mount(t);
      await date(t, '查看日期', '2025-12-31');
      await tapText(t, '打开日账本');
      await date(t, '账本日期', '2025-12-31');
      final ledgerPage = t.widget<DayLedgerPage>(find.byType(DayLedgerPage));
      expect(find.text('接续点：原记录接续点'), findsOneWidget);
      expect(find.text('已存明天第一步'), findsNothing);
      await tapText(t, '打开此日复盘');
      expect(find.text('第一步目标：原目标（已归档）'), findsOneWidget);
      expect(find.text('明天第一步'), findsOneWidget);
      expect(find.text('已存明天第一步'), findsOneWidget);
      expect(find.text('已交代：60 分钟'), findsOneWidget);
      await tapText(t, '编辑复盘草稿');
      expect(input(t, 'review-step'), '已存明天第一步');
      await tapText(t, '保留草稿并返回');
      // Use the actual app-composed editor route over the review to exercise
      // route-return refresh without adding a new product editing entry.
      Navigator.of(t.element(find.byType(ReviewContextPage)))
          .push<void>(MaterialPageRoute<void>(builder: (_) => ledgerPage));
      await settleNative(t);
      final tile = find.byKey(
        const ValueKey((type: LedgerFactType.timeBlock, id: blockId)),
      );
      await t.ensureVisible(tile);
      await t.tap(tile);
      await settleNative(t);
      await time(t, '结束时间', '2025-12-31 10:00');
      await enter(t, 'continuation-hint', '更正后的接续点');
      await tapText(t, '保存更正');
      expect(find.text('接续点：更正后的接续点'), findsOneWidget);
      await t.runAsync(
        () =>
            DriftGoalRepository(app.db)
                .rename(id: goalId, name: '当前名称', now: 5),
      );
      await back(t);
      expect(find.byType(ReviewContextPage), findsOneWidget);
      expect(find.text('已交代：120 分钟'), findsOneWidget);
      expect(find.text('尚未记录：1320 分钟'), findsOneWidget);
      expect(find.text('第一步目标：当前名称（已归档）'), findsOneWidget);
      expect(find.text('已存概述'), findsOneWidget);
      expect(find.text('已存反思\n保留段落'), findsOneWidget);
      expect(find.text('已存明天第一步'), findsOneWidget);
      expect(await t.runAsync(app.reviewRows), original);
      await back(t);
      expect(find.text('接续点：更正后的接续点'), findsOneWidget);
      await back(t);
      await date(t, '查看日期', '2025-12-31');
      await tapText(t, '打开基础摘要');
      expect(find.text('已交代：120 分钟'), findsOneWidget);
      await tapText(t, '打开此日复盘');
      expect(find.text('已交代：120 分钟'), findsOneWidget);
      expect(find.text('已存反思\n保留段落'), findsOneWidget);
      expect(await t.runAsync(app.reviewRows), original);
      // A second real SQLite connection reads exactly the persisted review,
      // not a controller snapshot or a derived statistics record.
      await t.runAsync(() async {
        final reopened = await AppDatabase.open(
          NativeDatabase(File('${app.dir.path}/facts.sqlite')),
        );
        try {
          expect(
            (await reopened
                    .customSelect('SELECT * FROM daily_reviews ORDER BY id')
                    .get())
                .map((r) => r.data)
                .toList(),
            original,
          );
        } finally {
          await reopened.close();
        }
      });
    },
  );

  for (final summary in [true, false]) {
    testWidgets(
      '${summary ? 'summary' : 'ledger'} entry allows failed facts, rejects invalid dates and pins displayed today across midnight with one route',
      (t) async {
        final app = await RouteApp.open(t);
        await app.mount(t);
        await tapText(t, summary ? '打开基础摘要' : '打开日账本');
        final label = summary ? '摘要日期 YYYY-MM-DD' : '账本日期';
        await date(t, label, '2025-02-30');
        expect(
          t
              .widget<FilledButton>(find.widgetWithText(FilledButton, '打开此日复盘'))
              .onPressed,
          isNull,
        );
        await tapText(t, '今天');
        app.reads.failFacts = true;
        await tapText(t, summary ? '刷新摘要' : '刷新账本');
        expect(
          find.text(summary ? '摘要读取失败，请重试。' : '账本读取失败，请重试。'),
          findsOneWidget,
        );
        app.reads.failFacts = false;
        app.clock = DateTime(2026, 10, 3, 0, 5);
        final open = t
            .widget<FilledButton>(find.widgetWithText(FilledButton, '打开此日复盘'))
            .onPressed!;
        open();
        open();
        await settleNative(t);
        expect(
          find.byType(ReviewContextPage, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('当天事实上下文：2026-10-02'), findsOneWidget);
        await tapText(t, '填写复盘');
        expect(input(t, 'review-date'), '2026-10-02');
        await enter(t, 'review-step', '当前所选日的用户行动');
        await tapText(t, '保存复盘');
        expect(find.text('已存复盘日期：2026-10-02'), findsOneWidget);
        expect(find.text('下一自然日：2026-10-03'), findsOneWidget);
        expect(
          (await t.runAsync(() => app.reviews.findByDate(today)))!
              .tomorrowFirstStep
              .text,
          '当前所选日的用户行动',
        );
        await back(t);
        expect(find.text('日期：2026-10-03'), findsOneWidget);
        await tapText(t, '打开此日复盘');
        expect(find.text('当天事实上下文：2026-10-03'), findsOneWidget);
        expect(find.text('这一天尚无复盘。'), findsOneWidget);
        await back(t);
        await date(t, label, '2026-10-02');
        await tapText(t, '打开此日复盘');
        expect(find.text('已有复盘'), findsOneWidget);
        expect(find.text('当前所选日的用户行动'), findsOneWidget);
      },
    );
  }
}
