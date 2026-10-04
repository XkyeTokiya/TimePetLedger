import '../support/ledger_date_selection.dart';

import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/derived_duration.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/goal_rhythm_summary_view.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';
import 'package:time_pet_ledger/features/ledger/presentation/summary_formatting.dart';

import '../support/app_recording_navigation.dart' show enter, stateTap;
import '../support/app_sleep_navigation.dart' as sleep;
import 'goal_rhythm_closure_test.dart'
    show ClosureApp, back, createGoal, chooseGoal, goalAction;
import 'recording_goal_flow_test.dart' show time, textTap, tap, disposeApp;
import 'sleep_recording_flow_test.dart' show fill;
import 'support/checked_sleep_opening.dart';

const minute = 60000;

class Writes extends QueryInterceptor {
  int count = 0;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    count++;
    return executor.runInsert(sql, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    count++;
    return executor.runUpdate(sql, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    count++;
    return executor.runDelete(sql, args);
  }
}

class SummaryApp extends ClosureApp {
  SummaryApp(super.dir);
  final writes = Writes();
  @override
  Future<void> connect() async {
    db = await AppDatabase.open(
      NativeDatabase(File('${dir.path}/facts.sqlite'))
          .interceptWith(reads)
          .interceptWith(writes),
    );
    drafts = await DriftRecordingDraftStore.open(
      NativeDatabase(File('${dir.path}/drafts.sqlite')),
    );
  }

  @override
  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openSleepDrafts: () => DriftSleepDraftStore.open(
          NativeDatabase(File('${dir.path}/sleep.sqlite')),
        ),
        openSleepOpenings: () => openCheckedSleepOpening(clock),
        now: () => clock,
      ),
    );
    await t.pumpAndSettle();
  }

  static Future<SummaryApp> start(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = (await t.runAsync(() async {
      final app = SummaryApp(
        await Directory.systemTemp.createTemp('summary_recalculation_'),
      );
      await app.connect();
      return app;
    }))!;
    addTearDown(() async {
      await disposeApp(t);
      await t.runAsync(() async {
        await app.db.close();
        await app.drafts.close();
        await app.dir.delete(recursive: true);
      });
    });
    await app.mount(t);
    return app;
  }
}

Future<void> homeDate(WidgetTester t, String date) async {
  await selectLedgerDate(t, date);
  await t.pumpAndSettle();
}

Future<String> ordinary(
  WidgetTester t,
  SummaryApp app,
  String from,
  String to, {
  bool unknown = false,
  String? goal,
  RhythmState? state,
  bool draft = false,
}) async {
  final before = (await t.runAsync(app.snapshot))!['time_blocks']!;
  await textTap(t, '记录活动');
  if (!unknown) await enter(t, 'activity', '活动');
  await textTap(t, unknown ? '想不起来' : '记得做了什么');
  await time(t, '开始时间', from);
  await time(t, '结束时间', to);
  await textTap(t, '开始准确');
  await textTap(t, '结束准确');
  if (goal != null) await chooseGoal(t, goal);
  if (state != null) await stateTap(t, state);
  await textTap(t, draft ? '保留草稿并返回' : '保存到账本');
  if (draft) return '';
  final after = (await t.runAsync(app.snapshot))!['time_blocks']!;
  return after.singleWhere((r) => !before.any((b) => b['id'] == r['id']))['id']!
      as String;
}

Future<String> createSleep(
  WidgetTester t,
  SummaryApp app,
  String from,
  String to, {
  bool nap = false,
}) async {
  final before = (await t.runAsync(app.snapshot))!['sleep_sessions']!;
  await textTap(t, '记录睡眠');
  await fill(t, from, to, nap: nap, approxStart: !nap);
  await sleep.tapText(t, '确认并保存到账本');
  final after = (await t.runAsync(app.snapshot))!['sleep_sessions']!;
  return after.singleWhere((r) => !before.any((b) => b['id'] == r['id']))['id']!
      as String;
}

Future<void> ledgerEdit(WidgetTester t, LedgerFactType type, String id) async {
  await textTap(t, '打开日账本');
  await tap(t, find.byKey(ValueKey((type: type, id: id))));
}

DayLedgerController summaryController(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(
              find
                  .descendant(
                    of: find.byType(DaySummaryPage),
                    matching: find.byType(ListenableBuilder),
                  )
                  .first,
            )
            .listenable
        as DayLedgerController;
Object duration(SummaryDuration d) =>
    (d.milliseconds, d.hasRecords, d.hasApproximation);
Object signature(DayLedgerView v) => [
  v.date,
  v.window.startedAt,
  v.window.endedAt,
  (v.accountedDuration.milliseconds, v.accountedDuration.hasApproximation),
  (v.unknownDuration.milliseconds, v.unknownDuration.hasApproximation),
  (v.unresolvedDuration.milliseconds, v.unresolvedDuration.hasApproximation),
  v.unresolvedSpans.map((g) => (g.startedAt, g.endedAt)).toList(),
  for (final s in [v.sleepSummary.mainSleep, v.sleepSummary.nap])
    [
      duration(s.totalDuration),
      s.records
          .map(
            (r) => (
              r.id,
              r.startedAt,
              r.endedAt,
              r.startPrecision,
              r.endPrecision,
            ),
          )
          .toList(),
    ],
  for (final g in v.goalSummaries)
    [
      g.goalId,
      g.name,
      g.isArchived,
      duration(g.totalDuration),
      duration(g.progressDuration),
      duration(g.stuckDuration),
      duration(g.recoveryDuration),
      duration(g.unannotatedDuration),
    ],
  duration(v.rhythmSummary.progressDuration),
  duration(v.rhythmSummary.stuckDuration),
  duration(v.rhythmSummary.recoveryDuration),
];
Future<DayLedgerView> check(
  WidgetTester t,
  SummaryApp app, {
  required int accounted,
  required int unknown,
  required int gap,
  int? main,
  int? nap,
  int? goalTotal,
  int? progress,
  int? stuck,
  int? recovery,
  int? unannotated,
}) async {
  final view = summaryController(t).view!;
  expect(view.accountedDuration.milliseconds, accounted * minute);
  expect(view.unknownDuration.milliseconds, unknown * minute);
  expect(view.unresolvedDuration.milliseconds, gap * minute);
  expect(
    view.accountedDuration.milliseconds + view.unresolvedDuration.milliseconds,
    view.window.milliseconds,
  );
  expect(
    view.unknownDuration.milliseconds,
    inInclusiveRange(0, view.accountedDuration.milliseconds),
  );
  if (main != null) {
    expect(
      view.sleepSummary.mainSleep.totalDuration.milliseconds,
      main * minute,
    );
  }
  if (nap != null) {
    expect(view.sleepSummary.nap.totalDuration.milliseconds, nap * minute);
  }
  if (goalTotal != null) {
    expect(
      view.goalSummaries.single.totalDuration.milliseconds,
      goalTotal * minute,
    );
  }
  if (progress != null) {
    expect(view.rhythmSummary.progressDuration.milliseconds, progress * minute);
  }
  if (stuck != null) {
    expect(view.rhythmSummary.stuckDuration.milliseconds, stuck * minute);
  }
  if (recovery != null) {
    expect(view.rhythmSummary.recoveryDuration.milliseconds, recovery * minute);
  }
  if (unannotated != null) {
    expect(
      view.goalSummaries.single.unannotatedDuration.milliseconds,
      unannotated * minute,
    );
  }
  for (final g in view.goalSummaries) {
    expect(
      g.progressDuration.milliseconds +
          g.stuckDuration.milliseconds +
          g.recoveryDuration.milliseconds +
          g.unannotatedDuration.milliseconds,
      g.totalDuration.milliseconds,
    );
  }
  expect(
    find.text('已交代：${formatDerivedDuration(view.accountedDuration)}'),
    findsOneWidget,
  );
  expect(
    find.text('其中未知：${formatDerivedDuration(view.unknownDuration)}'),
    findsOneWidget,
  );
  expect(
    find.text('尚未记录：${formatDerivedDuration(view.unresolvedDuration)}'),
    findsOneWidget,
  );
  await t.ensureVisible(find.byType(SleepSummaryView));
  await t.pumpAndSettle();
  expect(
    identical(
      t.widget<SleepSummaryView>(find.byType(SleepSummaryView)).summary,
      view.sleepSummary,
    ),
    isTrue,
  );
  await t.ensureVisible(find.byType(GoalRhythmSummaryView));
  await t.pumpAndSettle();
  final goals = t.widget<GoalRhythmSummaryView>(
    find.byType(GoalRhythmSummaryView),
  );
  expect(identical(goals.goals, view.goalSummaries), isTrue);
  expect(identical(goals.rhythm, view.rhythmSummary), isTrue);
  for (final g in view.goalSummaries) {
    final card = find.byKey(ValueKey('summary-goal-${g.goalId}'));
    for (final text in [
      g.name,
      '目标相关：${formatDerivedDuration(g.totalDuration.duration)}',
      '明确推进：${formatSummaryDuration(g.progressDuration, kind: SummaryDurationKind.progress)}',
      '明确卡住：${formatSummaryDuration(g.stuckDuration, kind: SummaryDurationKind.stuck)}',
      '目标内恢复：${formatSummaryDuration(g.recoveryDuration, kind: SummaryDurationKind.recovery)}',
      '未标记节奏：${formatSummaryDuration(g.unannotatedDuration, kind: SummaryDurationKind.unannotated)}',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    if (g.isArchived) {
      expect(
        find.descendant(of: card, matching: find.text('已归档')),
        findsOneWidget,
      );
    }
  }
  for (final text in [
    '全局推进：${formatSummaryDuration(view.rhythmSummary.progressDuration, kind: SummaryDurationKind.progress)}',
    '全局卡住：${formatSummaryDuration(view.rhythmSummary.stuckDuration, kind: SummaryDurationKind.stuck)}',
    '全局恢复：${formatSummaryDuration(view.rhythmSummary.recoveryDuration, kind: SummaryDurationKind.recovery)}',
  ]) {
    expect(find.text(text), findsOneWidget);
  }

  final reread = (await t.runAsync(
    () =>
        createDayLedgerLoader(app.db)
            .load(date: view.date, now: app.clock.millisecondsSinceEpoch),
  ))!;
  expect(signature(view), signature(reread));
  expect(find.textContaining('%'), findsNothing);
  expect(find.textContaining('效率'), findsNothing);
  expect(find.textContaining('导致'), findsNothing);
  return view;
}

Future<DayLedgerView> inspect(
  WidgetTester t,
  SummaryApp app, {
  required int accounted,
  required int unknown,
  required int gap,
  int? main,
  int? nap,
  int? goalTotal,
  int? progress,
  int? stuck,
  int? recovery,
  int? unannotated,
}) async {
  await textTap(t, '打开基础摘要');
  final view = await check(
    t,
    app,
    accounted: accounted,
    unknown: unknown,
    gap: gap,
    main: main,
    nap: nap,
    goalTotal: goalTotal,
    progress: progress,
    stuck: stuck,
    recovery: recovery,
    unannotated: unannotated,
  );
  await back(t);
  return view;
}

void main() {
  testWidgets(
    'real file app UI mutations keep historical mixed summaries derived from current facts',
    (t) async {
      final app = await SummaryApp.start(t);
      await textTap(t, '打开目标');
      final goal = await createGoal(t, app);
      await back(t);
      await homeDate(t, '2026-10-01');
      await t.runAsync(
        () => DriftReviewRepository(app.db).create(
          id: '00000000-0000-4000-8000-000000000099',
          date: CivilDate(year: 2026, month: 10, day: 1),
          summary: '原复盘',
          reflection: '用户自己的解释',
          tomorrowFirstStepText: '下一步',
          now: 1,
        ),
      );
      final originalReviews = (await t.runAsync(
        app.snapshot,
      ))!['daily_reviews'];
      final sleepId = await createSleep(
        t,
        app,
        '2026-09-30 23:00',
        '2026-10-01 01:00',
      );
      final first = await ordinary(
        t,
        app,
        '2026-10-01 01:00',
        '2026-10-01 02:00',
        goal: goal,
      );
      final unknownId = await ordinary(
        t,
        app,
        '2026-10-01 02:00',
        '2026-10-01 02:30',
        unknown: true,
      );
      await ordinary(
        t,
        app,
        '2026-10-01 03:00',
        '2026-10-01 03:30',
        goal: goal,
        state: RhythmState.stuck,
      );
      await ordinary(
        t,
        app,
        '2026-10-01 03:30',
        '2026-10-01 04:00',
        state: RhythmState.recovery,
      );
      final original = await inspect(
        t,
        app,
        accounted: 210,
        unknown: 30,
        gap: 1230,
        main: 120,
        goalTotal: 90,
        progress: 0,
        stuck: 30,
        recovery: 30,
        unannotated: 60,
      );
      final beforeDraft = (await t.runAsync(app.snapshot))!;
      await ordinary(
        t,
        app,
        '2026-10-01 04:00',
        '2026-10-01 05:00',
        goal: goal,
        state: RhythmState.progress,
        draft: true,
      );
      expect(await t.runAsync(app.snapshot), beforeDraft);
      await inspect(
        t,
        app,
        accounted: 210,
        unknown: 30,
        gap: 1230,
        main: 120,
        progress: 0,
        stuck: 30,
        recovery: 30,
      );
      await textTap(t, '记录活动');
      await textTap(t, '放弃草稿');
      await textTap(t, '记录睡眠');
      await fill(t, '2026-10-01 04:00', '2026-10-01 05:00', nap: true);
      await sleep.tapText(t, '保留草稿并返回');
      expect(await t.runAsync(app.snapshot), beforeDraft);
      await inspect(
        t,
        app,
        accounted: 210,
        unknown: 30,
        gap: 1230,
        main: 120,
        nap: 0,
      );
      await textTap(t, '记录睡眠');
      await sleep.tapText(t, '放弃草稿');

      for (final state in [
        RhythmState.progress,
        RhythmState.stuck,
        null,
        RhythmState.recovery,
      ]) {
        await ledgerEdit(t, LedgerFactType.timeBlock, first);
        await stateTap(t, state);
        await textTap(t, '保存更正');
        await back(t);
        await inspect(
          t,
          app,
          accounted: 210,
          unknown: 30,
          gap: 1230,
          main: 120,
          goalTotal: 90,
          progress: state == RhythmState.progress ? 60 : 0,
          stuck: state == RhythmState.stuck ? 90 : 30,
          recovery: state == RhythmState.recovery ? 90 : 30,
          unannotated: state == null ? 60 : 0,
        );
      }
      await ledgerEdit(t, LedgerFactType.timeBlock, first);
      await time(t, '结束时间', '2026-10-01 01:30');
      await textTap(t, '保存更正');
      await back(t);
      await inspect(
        t,
        app,
        accounted: 180,
        unknown: 30,
        gap: 1260,
        goalTotal: 60,
        recovery: 60,
      );
      await textTap(t, '打开日账本');
      final tile = find.byKey(
        ValueKey((type: LedgerFactType.timeBlock, id: unknownId)),
      );
      await tap(t, find.descendant(of: tile, matching: find.byTooltip('删除记录')));
      await textTap(t, '删除记录');
      await back(t);
      await inspect(
        t,
        app,
        accounted: 150,
        unknown: 0,
        gap: 1290,
        goalTotal: 60,
        recovery: 60,
      );
      await ledgerEdit(t, LedgerFactType.sleepSession, sleepId);
      await fill(t, '2026-10-01 23:00', '2026-10-02 01:00', approxStart: true);
      await sleep.tapText(t, '保存更正');
      await back(t);
      await inspect(t, app, accounted: 150, unknown: 0, gap: 1290, main: 0);
      await homeDate(t, '2026-10-02');
      await inspect(t, app, accounted: 60, unknown: 0, gap: 660, main: 120);
      await ledgerEdit(t, LedgerFactType.sleepSession, sleepId);
      await sleep.tapText(t, '删除睡眠');
      await sleep.tapText(t, '确认删除');
      await back(t);
      await inspect(t, app, accounted: 0, unknown: 0, gap: 720, main: 0);
      await homeDate(t, '2026-10-01');
      final napId = await createSleep(
        t,
        app,
        '2026-10-01 02:30',
        '2026-10-01 03:00',
        nap: true,
      );
      await inspect(
        t,
        app,
        accounted: 120,
        unknown: 0,
        gap: 1320,
        main: 0,
        nap: 30,
        recovery: 60,
      );
      await ledgerEdit(t, LedgerFactType.sleepSession, napId);
      await sleep.tapText(t, '删除睡眠');
      await sleep.tapText(t, '确认删除');
      await back(t);
      await textTap(t, '打开目标');
      await goalAction(t, goal, '改名');
      await enter(t, 'goal-rename-name', '新目标名');
      await textTap(t, '保存名称');
      await goalAction(t, goal, '归档目标');
      await back(t);
      final finalView = await inspect(
        t,
        app,
        accounted: 90,
        unknown: 0,
        gap: 1350,
        main: 0,
        nap: 0,
        goalTotal: 60,
        progress: 0,
        stuck: 30,
        recovery: 60,
        unannotated: 0,
      );
      expect(finalView.goalSummaries.single.name, '新目标名');
      expect(finalView.goalSummaries.single.isArchived, isTrue);
      expect(original.goalSummaries.single.name, '同名目标 🐾');
      expect(original.accountedDuration.milliseconds, 210 * minute);
      expect(
        (await t.runAsync(app.snapshot))!['daily_reviews'],
        originalReviews,
      );
      await app.reopen(t);
      await homeDate(t, '2026-10-01');
      final reopened = await inspect(
        t,
        app,
        accounted: 90,
        unknown: 0,
        gap: 1350,
        main: 0,
        goalTotal: 60,
        recovery: 60,
      );
      expect(signature(reopened), signature(finalView));
    },
  );

  testWidgets(
    'current-day UI save retry and summary route return refresh without repeated writes or stale snapshot',
    (t) async {
      final app = await SummaryApp.start(t);
      // Capture the app-composed real editor route, then return it over the summary
      // to exercise didPopNext without inventing a new product editing entry.
      await textTap(t, '打开日账本');
      final ledgerPage = t.widget<DayLedgerPage>(find.byType(DayLedgerPage));
      await back(t);
      app.reads.arm = true;
      await textTap(t, '记录活动');
      await enter(t, 'activity', '刚才');
      await textTap(t, '记得做了什么');
      await time(t, '开始时间', '2026-10-02 10:00');
      await time(t, '结束时间', '2026-10-02 11:00');
      await textTap(t, '开始准确');
      await textTap(t, '结束准确');
      await textTap(t, '保存到账本');
      expect(find.textContaining('已保存'), findsWidgets);
      expect(find.text('保存到账本'), findsNothing);
      final committed = (await t.runAsync(app.snapshot))!;
      final writes = app.writes.count;
      await textTap(t, '继续清理并刷新');
      expect(await t.runAsync(app.snapshot), committed);
      expect(app.writes.count, writes);
      app.reads.arm = false;
      app.reads.failReads = false;
      await textTap(t, '继续清理并刷新');
      expect(app.reads.blockInserts, 1);
      await textTap(t, '打开基础摘要');
      await check(t, app, accounted: 60, unknown: 0, gap: 660);
      final old = summaryController(t).view!;
      final nav = Navigator.of(t.element(find.byType(DaySummaryPage)));
      nav.push<void>(MaterialPageRoute(builder: (_) => ledgerPage));
      await t.pumpAndSettle();
      final id = committed['time_blocks']!.single['id']! as String;
      await tap(
        t,
        find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id))),
      );
      await stateTap(t, RhythmState.progress);
      await textTap(t, '保存更正');
      await back(t); // Actual editor -> ledger -> summary route return.
      await check(t, app, accounted: 60, unknown: 0, gap: 660, progress: 60);
      expect(old.rhythmSummary.progressDuration.hasRecords, isFalse);
      app.clock = DateTime(2026, 10, 2, 13);
      app.reads.failReads = true;
      await textTap(t, '刷新摘要');
      expect(summaryController(t).status, DayLedgerStatus.failed);
      expect(summaryController(t).view, isNull);
      expect(find.byType(SleepSummaryView), findsNothing);
      expect(find.byType(GoalRhythmSummaryView), findsNothing);
      expect(find.text('摘要读取失败，请重试。'), findsOneWidget);
      final beforeRetry = (await t.runAsync(app.snapshot))!;
      final writeCount = app.writes.count;
      await textTap(t, '重试读取');
      expect(summaryController(t).status, DayLedgerStatus.failed);
      app.reads.failReads = false;
      await textTap(t, '重试读取');
      await check(t, app, accounted: 60, unknown: 0, gap: 720, progress: 60);
      expect(app.writes.count, writeCount);
      expect(await t.runAsync(app.snapshot), beforeRetry);
      expect(app.reads.blockInserts, 1);
    },
  );
}
