import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _minute = Duration.millisecondsPerMinute;
const _hour = Duration.millisecondsPerHour;
final _day = DateTime.utc(2026, 9, 22).millisecondsSinceEpoch;
final _date = CivilDate(year: 2026, month: 9, day: 22);
String _id(int n) => '12345678-1234-4abc-8123-${n.toString().padLeft(12, '0')}';
Goal _goal(int n) => Goal.create(id: _id(n), name: '同名目标', now: 1);
TimeBlock _block(
  int n,
  int start,
  int end, {
  Goal? goal,
  bool unknown = false,
  bool approximateEnd = false,
}) => TimeBlock(
  id: _id(n),
  startedAt: _day + start,
  endedAt: _day + end,
  startPrecision: TimePrecision.exact,
  endPrecision: approximateEnd
      ? TimePrecision.approximate
      : TimePrecision.exact,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '活动',
  goalId: goal?.id,
  createdAt: 1,
  updatedAt: 2,
);
SleepSession _sleep(
  int n,
  int start,
  int end, {
  SleepType type = SleepType.mainSleep,
  bool approximate = false,
}) => SleepSession(
  id: _id(n),
  startedAt: _day + start,
  endedAt: _day + end,
  startPrecision: approximate ? TimePrecision.approximate : TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  type: type,
  createdAt: 1,
  updatedAt: 2,
);
RhythmAnnotation _annotation(TimeBlock block, RhythmState state) =>
    RhythmAnnotation(
      id: block.id,
      timeBlockId: block.id,
      state: state,
      createdAt: 1,
      updatedAt: 2,
    );
DayLedgerView _view({
  List<TimeBlock> blocks = const [],
  List<SleepSession> windowSleeps = const [],
  List<SleepSession> candidates = const [],
  List<RhythmAnnotation> annotations = const [],
  List<Goal> goals = const [],
  LedgerDateRelation relation = LedgerDateRelation.today,
  int now = 12 * _hour,
  int dayStart = 0,
  int dayEnd = 24 * _hour,
}) => projectDayLedgerView(
  date: _date,
  relation: relation,
  dayStartedAt: _day + dayStart,
  nextDayStartedAt: _day + dayEnd,
  now: _day + now,
  timeBlocks: blocks,
  windowSleepSessions: windowSleeps,
  annotations: annotations,
  sleepSummaryCandidates: candidates,
  goals: goals,
);

void _partitions(DayLedgerView view) {
  expect(
    view.accountedDuration.milliseconds + view.unresolvedDuration.milliseconds,
    view.window.milliseconds,
  );
  expect(
    view.unknownDuration.milliseconds,
    inInclusiveRange(0, view.accountedDuration.milliseconds),
  );
  expect(
    view.accountedDuration.milliseconds,
    view.segments.fold<int>(0, (sum, part) => sum + part.duration.milliseconds),
  );
  for (final goal in view.goalSummaries) {
    expect(
      goal.totalDuration.milliseconds,
      goal.progressDuration.milliseconds +
          goal.stuckDuration.milliseconds +
          goal.recoveryDuration.milliseconds +
          goal.unannotatedDuration.milliseconds,
    );
  }
}

void main() {
  test('DERIVED 手算示例整体平移至 00:00–04:00，210+30=240 分钟', () {
    // 示例只校核公式；整体平移 -8h 以遵守实际 today 从零点开始的合同。
    // 示例未指定睡眠类型，此处夹具明确选 nap，不从原文推断类型。
    final goal = _goal(100);
    final sleep = _sleep(1, 0, _hour, type: SleepType.nap);
    final progress = _block(2, _hour, 2 * _hour, goal: goal);
    final unknown = _block(3, 2 * _hour, 150 * _minute, unknown: true);
    final stuck = _block(4, 3 * _hour, 210 * _minute, goal: goal);
    final recovery = _block(5, 210 * _minute, 4 * _hour);
    final view = _view(
      now: 4 * _hour,
      blocks: [recovery, unknown, stuck, progress],
      windowSleeps: [sleep],
      candidates: [sleep],
      goals: [goal],
      annotations: [
        _annotation(progress, RhythmState.progress),
        _annotation(stuck, RhythmState.stuck),
        _annotation(recovery, RhythmState.recovery),
      ],
    );
    expect(view.date, _date);
    expect(view.accountedDuration.milliseconds, 210 * _minute);
    expect(view.unknownDuration.milliseconds, 30 * _minute);
    expect(view.unresolvedDuration.milliseconds, 30 * _minute);
    expect(view.unresolvedSpans.single.startedAt, _day + 150 * _minute);
    expect(view.unresolvedSpans.single.endedAt, _day + 180 * _minute);
    expect(view.rhythmSummary.progressDuration.milliseconds, 60 * _minute);
    expect(view.rhythmSummary.stuckDuration.milliseconds, 30 * _minute);
    expect(view.rhythmSummary.recoveryDuration.milliseconds, 30 * _minute);
    expect(view.goalSummaries.single.totalDuration.milliseconds, 90 * _minute);
    expect(view.sleepSummary.nap.totalDuration.milliseconds, _hour);
    expect(view.sleepSummary.mainSleep.totalDuration.hasRecords, isFalse);
    _partitions(view);
  });

  test('混合跨日、Unknown、Gap、同名归档目标、未标记及独立近似', () {
    final goal = _goal(100);
    final archived = _goal(101).archive(now: 2);
    final sleep = _sleep(1, -_hour, 7 * _hour, approximate: true);
    final unknown = _block(2, 7 * _hour, 8 * _hour, unknown: true);
    final progress = _block(
      3,
      9 * _hour,
      10 * _hour,
      goal: goal,
      approximateEnd: true,
    );
    final unmarked = _block(4, 11 * _hour, 12 * _hour, goal: goal);
    final stuck = _block(5, 12 * _hour, 13 * _hour, goal: archived);
    final recovery = _block(6, 13 * _hour, 14 * _hour, goal: archived);
    final nap = _sleep(7, 14 * _hour, 15 * _hour, type: SleepType.nap);
    final blocks = [recovery, unknown, unmarked, stuck, progress];
    final sleeps = [nap, sleep];
    final annotations = [
      _annotation(progress, RhythmState.progress),
      _annotation(stuck, RhythmState.stuck),
      _annotation(recovery, RhythmState.recovery),
    ];
    final goals = [archived, goal, _goal(102)];
    final view = _view(
      now: 16 * _hour,
      blocks: blocks,
      windowSleeps: sleeps,
      candidates: sleeps,
      annotations: annotations,
      goals: goals,
    );
    expect(view.accountedDuration.milliseconds, 13 * _hour);
    expect(view.unknownDuration.milliseconds, _hour);
    expect(view.unresolvedDuration.milliseconds, 3 * _hour);
    expect(view.accountedDuration.hasApproximation, isTrue);
    expect(view.unknownDuration.hasApproximation, isFalse);
    expect(view.unresolvedDuration.hasApproximation, isTrue);
    expect(view.unresolvedSpans.map((g) => g.duration.hasApproximation), [
      false,
      true,
      false,
    ]);
    expect(view.sleepSummary.mainSleep.totalDuration.milliseconds, 8 * _hour);
    expect(view.sleepSummary.mainSleep.totalDuration.hasApproximation, isTrue);
    expect(
      view.segments
          .whereType<SleepSessionSegment>()
          .first
          .duration
          .milliseconds,
      7 * _hour,
    );
    expect(view.segments.first.duration.hasApproximation, isFalse);
    expect(view.goalSummaries.map((g) => g.goalId), [archived.id, goal.id]);
    expect(view.goalSummaries.map((g) => g.name), ['同名目标', '同名目标']);
    expect(view.goalSummaries.first.isArchived, isTrue);
    expect(view.goalSummaries.last.unannotatedDuration.milliseconds, _hour);
    expect(
      view.goalSummaries.last.unannotatedDuration.hasApproximation,
      isFalse,
    );
    expect(view.rhythmSummary.recoveryDuration.milliseconds, _hour);
    _partitions(view);
    expect(blocks, [
      same(recovery),
      same(unknown),
      same(unmarked),
      same(stuck),
      same(progress),
    ]);
    expect(sleeps, [same(nap), same(sleep)]);
    expect(view.sleepSummary.mainSleep.records.single, same(sleep));
    expect(
      view.segments.whereType<TimeBlockSegment>().first.source,
      same(unknown),
    );
    expect(sleep.startedAt, _day - _hour);
    expect(progress.endPrecision, TimePrecision.approximate);
    expect(annotations.first.state, RhythmState.progress);
    expect(goals.first, same(archived));
    expect(() => view.segments.clear(), throwsUnsupportedError);
    expect(() => view.unresolvedSpans.clear(), throwsUnsupportedError);
    expect(() => view.goalSummaries.clear(), throwsUnsupportedError);
  });

  test('窗口睡眠与醒来日候选分别供给：午夜摘要和次日醒来切片不混用', () {
    final midnight = _sleep(1, -2 * _hour, 0);
    final crossesNext = _sleep(2, 23 * _hour, 31 * _hour);
    final view = _view(
      relation: LedgerDateRelation.historical,
      windowSleeps: [crossesNext],
      candidates: [midnight, crossesNext],
    );
    expect(view.segments.single.startedAt, _day + 23 * _hour);
    expect(view.accountedDuration.milliseconds, _hour);
    expect(view.sleepSummary.mainSleep.records, [same(midnight)]);
    expect(view.sleepSummary.mainSleep.totalDuration.milliseconds, 2 * _hour);
    _partitions(view);
  });

  test('未来日和今天零点空 W 不阻止独立完整睡眠摘要', () {
    final sleep = _sleep(1, -_hour, 7 * _hour, approximate: true);
    final goal = _goal(100);
    final block = _block(2, 9 * _hour, 10 * _hour, goal: goal);
    for (final relation in [
      LedgerDateRelation.future,
      LedgerDateRelation.today,
    ]) {
      final view = _view(
        relation: relation,
        now: relation == LedgerDateRelation.future ? -1 : 0,
        blocks: [block],
        windowSleeps: [sleep],
        candidates: [sleep],
        goals: [goal],
        annotations: [_annotation(block, RhythmState.progress)],
      );
      expect(view.window.isEmpty, isTrue);
      expect(view.segments, isEmpty);
      expect(view.unresolvedSpans, isEmpty);
      expect(view.goalSummaries, isEmpty);
      expect(view.rhythmSummary.progressDuration.hasRecords, isFalse);
      expect(view.accountedDuration.hasApproximation, isFalse);
      expect(view.sleepSummary.mainSleep.totalDuration.milliseconds, 8 * _hour);
      expect(
        view.sleepSummary.mainSleep.totalDuration.hasApproximation,
        isTrue,
      );
      _partitions(view);
    }
  });

  test('只改有效解释会重算节奏及目标细分，不改变覆盖与 Gap', () {
    final goal = _goal(100);
    final block = _block(1, _hour, 2 * _hour, goal: goal, approximateEnd: true);
    final original = _annotation(block, RhythmState.progress);
    DayLedgerView calculate(List<RhythmAnnotation> annotations) => _view(
      blocks: [block],
      annotations: annotations,
      goals: [goal],
      now: 3 * _hour,
    );
    final before = calculate([original]);
    final after = calculate([_annotation(block, RhythmState.stuck)]);
    final removed = calculate([]);
    expect(before.rhythmSummary.progressDuration.milliseconds, _hour);
    expect(after.rhythmSummary.progressDuration.hasRecords, isFalse);
    expect(after.rhythmSummary.stuckDuration.milliseconds, _hour);
    expect(
      removed.goalSummaries.single.unannotatedDuration.milliseconds,
      _hour,
    );
    for (final view in [after, removed]) {
      expect(
        view.accountedDuration.milliseconds,
        before.accountedDuration.milliseconds,
      );
      expect(
        view.accountedDuration.hasApproximation,
        before.accountedDuration.hasApproximation,
      );
      expect(
        view.unresolvedSpans.map(
          (g) => (g.startedAt, g.endedAt, g.startPrecision, g.endPrecision),
        ),
        before.unresolvedSpans.map(
          (g) => (g.startedAt, g.endedAt, g.startPrecision, g.endPrecision),
        ),
      );
      _partitions(view);
    }
    expect(original.state, RhythmState.progress);
    expect(before.rhythmSummary.stuckDuration.hasRecords, isFalse);
  });

  test('同一事实随 now 推进重投影，裁剪和近似改变，旧结果保持不变', () {
    final goal = _goal(100);
    final block = _block(1, _hour, 3 * _hour, goal: goal, approximateEnd: true);
    final annotations = [_annotation(block, RhythmState.progress)];
    final early = _view(
      blocks: [block],
      goals: [goal],
      annotations: annotations,
      now: 2 * _hour,
    );
    final late = _view(
      blocks: [block],
      goals: [goal],
      annotations: annotations,
      now: 4 * _hour,
    );
    expect(early.accountedDuration.milliseconds, _hour);
    expect(early.accountedDuration.hasApproximation, isFalse);
    expect(late.accountedDuration.milliseconds, 2 * _hour);
    expect(late.accountedDuration.hasApproximation, isTrue);
    expect(late.unresolvedDuration.milliseconds, 2 * _hour);
    expect(late.unresolvedDuration.hasApproximation, isTrue);
    expect(early.segments.single.endedAt, _day + 2 * _hour);
    expect(block.endedAt, _day + 3 * _hour);
    _partitions(early);
    _partitions(late);
  });

  test('显式日界重投影改变日期贡献与醒来归属，23/25 小时空日完整为 Gap', () {
    final sleep = _sleep(1, -10 * _hour, -7 * _hour);
    final utc = _view(
      windowSleeps: [sleep],
      candidates: [sleep],
      relation: LedgerDateRelation.historical,
    );
    final shifted = _view(
      dayStart: -8 * _hour,
      dayEnd: 16 * _hour,
      windowSleeps: [sleep],
      candidates: [sleep],
      relation: LedgerDateRelation.historical,
    );
    expect(utc.sleepSummary.mainSleep.totalDuration.hasRecords, isFalse);
    expect(utc.segments, isEmpty);
    expect(shifted.accountedDuration.milliseconds, _hour);
    expect(
      shifted.sleepSummary.mainSleep.totalDuration.milliseconds,
      3 * _hour,
    );
    _partitions(utc);
    _partitions(shifted);
    for (final hours in [23, 25]) {
      final empty = _view(
        dayEnd: hours * _hour,
        relation: LedgerDateRelation.historical,
      );
      expect(empty.unresolvedDuration.milliseconds, hours * _hour);
      expect(empty.unresolvedSpans, hasLength(1));
      expect(empty.sleepSummary.mainSleep.totalDuration.hasRecords, isFalse);
      _partitions(empty);
    }
  });

  test('继承调用错误：缺 Goal、重复元数据、重复解释及非法日界/now 不静默降级', () {
    final goal = _goal(100);
    final block = _block(1, 0, _hour, goal: goal);
    final annotation = _annotation(block, RhythmState.progress);
    expect(() => _view(blocks: [block]), throwsArgumentError);
    expect(
      () => _view(blocks: [block], goals: [goal, goal]),
      throwsArgumentError,
    );
    expect(
      () => _view(
        blocks: [block],
        goals: [goal],
        annotations: [annotation, annotation],
      ),
      throwsArgumentError,
    );
    expect(() => _view(dayEnd: 0), throwsArgumentError);
    expect(() => _view(now: 24 * _hour), throwsArgumentError);
  });
}
