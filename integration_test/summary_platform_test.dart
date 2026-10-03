import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/goal_rhythm_summary_view.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';
import 'package:time_pet_ledger/features/ledger/presentation/summary_formatting.dart';

import 'goal_rhythm_platform_test.dart'
    as ui
    show tap, tapFinder, visible, waitForUI, enter, time, back, action;
import 'support/schema_contract.dart' show clearSchemaRows;
import 'support/summary_platform_status_native.dart'
    if (dart.library.js_interop) 'support/summary_platform_status_web.dart'
    as platform_status;

const runId = String.fromEnvironment('E8_T06_RUN_ID');
const minute = 60000;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 2);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2000, month: 1, day: 1),
);
int at(int h, [int m = 0, int day = 2]) =>
    DateTime(2026, 10, day, h, m).millisecondsSinceEpoch;

// Fault injection is confined to this test's real platform executor. No mock
// projection or in-memory replacement supplies the application's summary.
class Reads extends QueryInterceptor {
  bool failNext = false;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failNext && sql.contains('sleep_sessions')) {
      failNext = false;
      throw StateError('E8-T06 injected read failure');
    }
    return executor.runSelect(sql, args);
  }
}

class App {
  App(this.db, this.drafts, this.reads);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  final Reads reads;
  late DayLedgerPage ledger;
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  DriftGoalRepository get goals => DriftGoalRepository(db);
  Future<Map<String, List<Map<String, Object?>>>> facts() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  };
}

Future<void> seed(App app) async {
  // Isolated mixed formal fixture, written through production repositories.
  // This is validation setup, not a demo dataset shipped to product users.
  for (var n = 1; n <= 2; n++) {
    await app.goals.create(id: id(n), name: '同名摘要目标 🐾', now: at(12));
  }
  await app.repo.createSleepSession(
    id: id(20),
    startedAt: at(23, 0, 1),
    endedAt: at(7),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: at(12),
  );
  await app.repo.createSleepSession(
    id: id(21),
    startedAt: at(11),
    endedAt: at(11, 15),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    type: SleepType.nap,
    now: at(12),
  );
  final blocks = [
    (n: 10, start: at(7), end: at(8), goal: id(1), state: RhythmState.progress),
    (n: 11, start: at(8), end: at(8, 30), goal: null, state: null),
    (
      n: 12,
      start: at(8, 30),
      end: at(9),
      goal: id(1),
      state: RhythmState.stuck,
    ),
    (
      n: 13,
      start: at(9, 30),
      end: at(10),
      goal: id(1),
      state: RhythmState.recovery,
    ),
    (n: 14, start: at(10), end: at(10, 30), goal: id(1), state: null),
    (
      n: 15,
      start: at(10, 30),
      end: at(11),
      goal: null,
      state: RhythmState.recovery,
    ),
    (n: 16, start: at(11, 15), end: at(11, 30), goal: id(2), state: null),
  ];
  for (final b in blocks) {
    await app.repo.createTimeBlock(
      id: id(b.n),
      startedAt: b.start,
      endedAt: b.end,
      startPrecision: b.n == 12
          ? TimePrecision.approximate
          : TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: b.n == 11
          ? BlockKnowledgeState.unknown
          : BlockKnowledgeState.known,
      title: b.n == 11 ? null : '平台摘要活动 ${b.n}',
      goalId: b.goal,
      annotation: b.state == null
          ? null
          : AddAnnotation(id: id(b.n + 100), state: b.state!),
      now: at(12),
    );
  }
  await app.goals.archive(id: id(2), now: at(12));
}

Future<App> openApp(WidgetTester t, {bool initial = false}) async {
  final reads = Reads();
  final app = App(
    await AppDatabase.open(
      (await connectDatabase('e8_t06_formal_$runId')).interceptWith(reads),
    ),
    await DriftRecordingDraftStore.open(
      await connectDatabase('e8_t06_drafts_$runId'),
    ),
    reads,
  );
  if (initial) {
    expect((await app.facts()).values.every((rows) => rows.isEmpty), isTrue);
    await seed(app);
  }
  await t.pumpWidget(
    AppBootstrap(
      openDatabase: () async => app.db,
      openDrafts: () async => app.drafts,
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e8_t06_sleep_$runId'),
      ),
      openSleepOpenings: () async {
        final store = await DriftSleepOpeningStore.open(
          await connectDatabase('e8_t06_openings_$runId'),
        );
        await store.claim(date);
        return store;
      },
      now: () => DateTime(2026, 10, 2, 12),
    ),
  );
  for (var i = 0; i < 150 && find.text('打开基础摘要').evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await ui.waitForUI(t);
  // Capture the actual assembled ledger entry, with its real form callbacks.
  // Reuse it above summary solely to exercise RouteAware.didPopNext; no new
  // product navigation is introduced by this validation task.
  await ui.tap(t, '打开日账本');
  app.ledger = t.widget<DayLedgerPage>(find.byType(DayLedgerPage));
  await ui.back(t);
  await ui.tap(t, '打开基础摘要');
  return app;
}

DayLedgerController controller(WidgetTester t) =>
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

Future<void> select(WidgetTester t, String value) async {
  final field = find.widgetWithText(TextField, '摘要日期 YYYY-MM-DD');
  await ui.visible(t, field);
  await t.tap(field);
  await t.pumpAndSettle();
  await t.enterText(field, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await ui.waitForUI(t);
}

Future<void> pushLedger(WidgetTester t, App app) async {
  Navigator.of(t.element(find.byType(DaySummaryPage)))
      .push<void>(MaterialPageRoute<void>(builder: (_) => app.ledger));
  await ui.waitForUI(t);
}

Future<void> edit(WidgetTester t, LedgerFactType type, int n) =>
    ui.tapFinder(t, find.byKey(ValueKey((type: type, id: id(n)))));

Future<void> check(
  WidgetTester t, {
  required int accounted,
  required int unknown,
  required int gap,
  required int? main,
  required int? nap,
  int? progress,
  int? stuck,
  String name = '同名摘要目标 🐾',
  bool archived = false,
}) async {
  final c = controller(t);
  final v = c.view!;
  expect(
    c.status,
    v.segments.isEmpty && main == null && nap == null
        ? DayLedgerStatus.empty
        : DayLedgerStatus.ready,
  );
  expect(v.accountedDuration.milliseconds, accounted * minute);
  expect(v.unknownDuration.milliseconds, unknown * minute);
  expect(v.unresolvedDuration.milliseconds, gap * minute);
  expect(
    v.accountedDuration.milliseconds + v.unresolvedDuration.milliseconds,
    v.window.milliseconds,
  );
  expect(
    v.sleepSummary.mainSleep.totalDuration.milliseconds,
    (main ?? 0) * minute,
  );
  expect(v.sleepSummary.mainSleep.totalDuration.hasRecords, main != null);
  expect(v.sleepSummary.nap.totalDuration.milliseconds, (nap ?? 0) * minute);
  expect(v.sleepSummary.nap.totalDuration.hasRecords, nap != null);
  for (final text in [
    '已交代：${formatDerivedDuration(v.accountedDuration)}',
    '其中未知：${formatDerivedDuration(v.unknownDuration)}',
    '尚未记录：${formatDerivedDuration(v.unresolvedDuration)}',
  ]) {
    await ui.visible(t, find.text(text));
    expect(find.text(text), findsOneWidget);
  }
  await ui.visible(t, find.byType(SleepSummaryView));
  final sleep = t.widget<SleepSummaryView>(find.byType(SleepSummaryView));
  expect(identical(sleep.summary, v.sleepSummary), isTrue);
  for (final text in [
    formatSummaryDuration(
      v.sleepSummary.mainSleep.totalDuration,
      kind: SummaryDurationKind.mainSleep,
    ),
    formatSummaryDuration(
      v.sleepSummary.nap.totalDuration,
      kind: SummaryDurationKind.nap,
    ),
  ]) {
    expect(
      find.descendant(
        of: find.byType(SleepSummaryView),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }
  if (main != null) {
    expect(v.sleepSummary.mainSleep.totalDuration.hasApproximation, isTrue);
    expect(find.textContaining('完整时长 约480 分钟'), findsOneWidget);
  }
  await ui.visible(t, find.byType(GoalRhythmSummaryView));
  final widget = t.widget<GoalRhythmSummaryView>(
    find.byType(GoalRhythmSummaryView),
  );
  expect(identical(widget.goals, v.goalSummaries), isTrue);
  expect(identical(widget.rhythm, v.rhythmSummary), isTrue);
  if (progress != null && stuck != null) {
    expect(v.goalSummaries, hasLength(2));
    final a = v.goalSummaries.singleWhere((g) => g.goalId == id(1));
    expect(a.name, name);
    expect(a.isArchived, archived);
    expect(a.totalDuration.milliseconds, (progress + stuck + 60) * minute);
    expect(a.progressDuration.milliseconds, progress * minute);
    expect(a.stuckDuration.milliseconds, stuck * minute);
    expect(a.recoveryDuration.milliseconds, 30 * minute);
    expect(a.unannotatedDuration.milliseconds, 30 * minute);
    expect(a.stuckDuration.hasApproximation, isTrue);
    expect(a.progressDuration.hasApproximation, isFalse);
    final b = v.goalSummaries.singleWhere((g) => g.goalId == id(2));
    expect(b.isArchived, isTrue);
    expect(b.unannotatedDuration.milliseconds, 15 * minute);
    expect(b.progressDuration.hasRecords, isFalse);
    expect(v.rhythmSummary.recoveryDuration.milliseconds, 60 * minute);
    expect(v.rhythmSummary.progressDuration.milliseconds, progress * minute);
    expect(v.rhythmSummary.stuckDuration.milliseconds, stuck * minute);
    expect(v.accountedDuration.hasApproximation, isTrue);
    expect(v.unknownDuration.hasApproximation, isFalse);
  } else {
    expect(v.goalSummaries, isEmpty);
  }
  for (final g in v.goalSummaries) {
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
    expect(
      find.descendant(of: card, matching: find.text('已归档')),
      g.isArchived ? findsOneWidget : findsNothing,
    );
  }
  expect(
    find.text(
      '全局恢复：${formatSummaryDuration(v.rhythmSummary.recoveryDuration, kind: SummaryDurationKind.recovery)}',
    ),
    findsOneWidget,
  );
  final tables = await t
      .widget<DaySummaryPage>(find.byType(DaySummaryPage))
      .loader
      .load(date: v.date, now: at(12));
  expect(
    tables.accountedDuration.milliseconds,
    v.accountedDuration.milliseconds,
  );
  expect(
    tables.sleepSummary.mainSleep.records.map((r) => r.id).toList(),
    v.sleepSummary.mainSleep.records.map((r) => r.id).toList(),
  );
  debugPrint(
    'E8-T06 checked date=${v.date} coverage=$accounted unknown=$unknown gap=$gap main=$main nap=$nap progress=$progress stuck=$stuck',
  );
}

Future<void> mixed(
  WidgetTester t, {
  int progress = 60,
  int stuck = 30,
  bool moved = false,
  bool archived = false,
}) => check(
  t,
  accounted: (moved ? 180 : 600) + progress + stuck - 30,
  unknown: 30,
  gap: (moved ? 540 : 120) - progress - stuck + 30,
  main: moved ? null : 480,
  nap: 15,
  progress: progress,
  stuck: stuck,
  name: archived ? '平台摘要更正目标' : '同名摘要目标 🐾',
  archived: archived,
);

Future<void> retry(WidgetTester t, App app) async {
  final before = await app.facts();
  app.reads.failNext = true;
  await ui.tap(t, '刷新摘要');
  expect(controller(t).status, DayLedgerStatus.failed);
  expect(controller(t).view, isNull);
  expect(find.text('摘要读取失败，请重试。'), findsOneWidget);
  expect(find.byType(GoalRhythmSummaryView), findsNothing);
  await ui.tap(t, '重试读取');
  expect(controller(t).status, DayLedgerStatus.ready);
  expect(await app.facts(), before);
}

Future<void> phase0(WidgetTester t) async {
  final app = await openApp(t, initial: true);
  await mixed(t);
  await select(t, '2026-10-01');
  await check(t, accounted: 60, unknown: 0, gap: 1380, main: null, nap: null);
  await select(t, '2026-10-03');
  await check(t, accounted: 0, unknown: 0, gap: 0, main: null, nap: null);
  await ui.visible(t, find.text('当前账本窗口为空，不产生未记录缺口。'));
  expect(find.text('当前账本窗口为空，不产生未记录缺口。'), findsOneWidget);
  await ui.tap(t, '今天');
  await retry(t, app);
  await mixed(t);
  await pushLedger(t, app);
  await edit(t, LedgerFactType.timeBlock, 10);
  await ui.time(t, '结束时间', '2026-10-02 07:45');
  await ui.tap(t, '保存更正');
  await ui.back(t);
  await mixed(t, progress: 45);
}

Future<void> phase1(WidgetTester t) async {
  final app = await openApp(t);
  await mixed(t, progress: 45);
  final before = await app.facts();
  await pushLedger(t, app);
  await edit(t, LedgerFactType.timeBlock, 12);
  await ui.time(t, '结束时间', '2026-10-02 09:15');
  await ui.tap(t, '保留草稿并返回');
  await ui.back(t);
  expect(await app.facts(), before);
  await mixed(t, progress: 45);
  expect(
    (await app.drafts.read(
      RecordingDraftContext.edit(date: date, timeBlockId: id(12)),
    ))!.endedAt,
    at(9, 15),
  );
}

Future<void> phase2(WidgetTester t) async {
  final app = await openApp(t);
  await mixed(t, progress: 45);
  await pushLedger(t, app);
  await edit(t, LedgerFactType.timeBlock, 12);
  expect(find.text('已恢复上次输入'), findsOneWidget);
  await ui.tap(t, '保存更正');
  await ui.back(t);
  await mixed(t, progress: 45, stuck: 45);
  expect(
    await app.drafts.read(
      RecordingDraftContext.edit(date: date, timeBlockId: id(12)),
    ),
    isNull,
  );
  await ui.back(t);
  await ui.tap(t, '打开目标');
  await ui.action(t, id(1), '改名');
  await ui.enter(t, 'goal-rename-name', '平台摘要更正目标');
  await ui.tap(t, '保存名称');
  await ui.action(t, id(1), '归档目标');
  await ui.back(t);
  await ui.tap(t, '打开基础摘要');
  await mixed(t, progress: 45, stuck: 45, archived: true);
}

Future<void> phase3(WidgetTester t) async {
  final app = await openApp(t);
  await mixed(t, progress: 45, stuck: 45, archived: true);
  await pushLedger(t, app);
  await edit(t, LedgerFactType.sleepSession, 20);
  await ui.enter(t, 'sleep-start', '2026-09-30 23:00');
  await ui.enter(t, 'sleep-end', '2026-10-01 07:00');
  await ui.tap(t, '保存更正');
  await ui.back(t);
  await mixed(t, progress: 45, stuck: 45, moved: true, archived: true);
  await select(t, '2026-10-01');
  await check(t, accounted: 420, unknown: 0, gap: 1020, main: 480, nap: null);
}

Future<void> phase4(WidgetTester t) async {
  final app = await openApp(t);
  await mixed(t, progress: 45, stuck: 45, moved: true, archived: true);
  await retry(t, app);
  await mixed(t, progress: 45, stuck: 45, moved: true, archived: true);
  await select(t, '2026-10-01');
  await check(t, accounted: 420, unknown: 0, gap: 1020, main: 480, nap: null);
  await select(t, '2026-09-29');
  await check(t, accounted: 0, unknown: 0, gap: 1440, main: null, nap: null);
  await select(t, '2026-10-03');
  await check(t, accounted: 0, unknown: 0, gap: 0, main: null, nap: null);
  final facts = await app.facts();
  expect(facts['time_blocks'], hasLength(7));
  expect(facts['sleep_sessions'], hasLength(2));
  expect(facts['rhythm_annotations'], hasLength(4));
  expect(facts['daily_reviews'], isEmpty);
  await clearSchemaRows(app.db);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(runId)) {
    throw StateError('Pass a unique E8_T06_RUN_ID.');
  }
  testWidgets(
    'E8-T06 summary recomputes from facts across actual platform lifecycle',
    (t) async {
      final control = await DriftRecordingDraftStore.open(
        await connectDatabase('e8_t06_control_$runId'),
      );
      try {
        final previous = await control.read(controlContext);
        final phase = previous == null ? 0 : int.parse(previous.title!);
        final phases = [phase0, phase1, phase2, phase3, phase4];
        if (phase < 0 || phase >= phases.length) {
          throw StateError('Run already finished: $phase');
        }
        debugPrint(
          'E8-T06 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
        );
        await phases[phase](t);
        await control.save(
          RecordingDraft(
            context: controlContext,
            title: '${phase + 1}',
            startedAt: null,
            endedAt: null,
            startPrecision: TimePrecision.exact,
            endPrecision: TimePrecision.exact,
            knowledgeState: null,
          ),
        );
        await control.close();
        platform_status.reportSummaryPlatformPhase(phase + 1);
        debugPrint(
          'E8-T06 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
        );
      } catch (_) {
        await control.close();
        rethrow;
      }
    },
  );
}
