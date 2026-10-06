import '../core/persistence/app_database.dart';
import '../core/time/civil_date.dart';
import '../features/goals/data/drift_goal_repository.dart';
import '../features/ledger/data/drift_ledger_repository.dart';
import '../features/ledger/domain/annotation_change.dart';
import '../features/ledger/domain/block_knowledge_state.dart';
import '../features/ledger/domain/rhythm_details.dart';
import '../features/ledger/domain/rhythm_state.dart';
import '../features/ledger/domain/sleep_type.dart';
import '../features/ledger/domain/time_precision.dart';
import '../features/review/data/drift_review_repository.dart';

/// Development-only demo data, written straight into the real database.
///
/// Dates are relative to "today" so the ledger is populated on first launch.
/// Idempotent: it only seeds when the ledger is empty, so reloading the page
/// never duplicates facts. Remove this file and its call in `main.dart` when
/// the demo data is no longer wanted.
Future<void> seedDemoDataIfEmpty(AppDatabase database) async {
  final rows = await database
      .customSelect('SELECT COUNT(*) AS c FROM time_blocks')
      .getSingle();
  if (rows.read<int>('c') > 0) return;

  final today = _midnight(DateTime.now());
  final day1 = today.subtract(const Duration(days: 1));
  final day2 = today.subtract(const Duration(days: 2));

  int at(DateTime day, int hour, int minute) =>
      day.add(Duration(hours: hour, minutes: minute)).millisecondsSinceEpoch;

  const goalId = '00000000-0000-4000-8000-0000000000a0';
  final goals = DriftGoalRepository(database);
  final ledger = DriftLedgerRepository(database);

  // 演示目标的创建时间取演示窗口内的一天，避免 1970 这类夹具时间戳。
  await goals.create(id: goalId, name: '毕业设计', now: at(day2, 9, 0));

  // Two nights of sleep so both the day-before (full reference-like day) and
  // today (this morning's slice) show a main sleep.
  await ledger.createSleepSession(
    id: '00000000-0000-4000-8000-0000000000b1',
    startedAt: at(day2, 23, 40),
    endedAt: at(day1, 7, 20),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: 2,
  );
  await ledger.createSleepSession(
    id: '00000000-0000-4000-8000-0000000000b2',
    startedAt: at(day1, 23, 40),
    endedAt: at(today, 7, 20),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: 3,
  );

  // Day-1 activities, laid out to mirror the confirmed reference.
  await ledger.createTimeBlock(
    id: '00000000-0000-4000-8000-0000000000c1',
    startedAt: at(day1, 7, 20),
    endedAt: at(day1, 8, 0),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '早餐',
    now: 4,
  );
  await ledger.createTimeBlock(
    id: '00000000-0000-4000-8000-0000000000c2',
    startedAt: at(day1, 8, 0),
    endedAt: at(day1, 10, 0),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '设计首页',
    goalId: goalId,
    annotation: const AddAnnotation(
      id: '00000000-0000-4000-8000-0000000000d1',
      state: RhythmState.progress,
      continuationHint: '先画补记弹层',
    ),
    now: 5,
  );
  await ledger.createTimeBlock(
    id: '00000000-0000-4000-8000-0000000000c3',
    startedAt: at(day1, 10, 0),
    endedAt: at(day1, 10, 30),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.approximate,
    knowledgeState: BlockKnowledgeState.unknown,
    title: '只记得出门办事',
    goalId: goalId,
    now: 6,
  );
  await ledger.createTimeBlock(
    id: '00000000-0000-4000-8000-0000000000c4',
    startedAt: at(day1, 11, 0),
    endedAt: at(day1, 11, 30),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '散步',
    annotation: const AddAnnotation(
      id: '00000000-0000-4000-8000-0000000000d2',
      state: RhythmState.recovery,
      recoveryMethod: RecoveryMethod.walk,
      recoveryQuality: RecoveryQuality.readyToContinue,
    ),
    now: 7,
  );

  // This morning, after last night's sleep.
  await ledger.createTimeBlock(
    id: '00000000-0000-4000-8000-0000000000c5',
    startedAt: at(today, 7, 20),
    endedAt: at(today, 7, 50),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '早餐',
    now: 8,
  );

  await DriftReviewRepository(database).create(
    id: '00000000-0000-4000-8000-0000000000e1',
    date: CivilDate(year: day1.year, month: day1.month, day: day1.day),
    tomorrowFirstStepText: '先画补记弹层',
    summary: '首页信息结构基本确定，补记入口还需要再打磨。',
    reflection: '把注意力放在最想改的那一处，明天继续。',
    tomorrowFirstStepGoalId: goalId,
    now: 9,
  );
}

DateTime _midnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);
