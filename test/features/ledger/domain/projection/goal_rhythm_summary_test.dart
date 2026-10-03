import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/derived_duration.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/goal_rhythm_summary.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

String _id(int n) =>
    '12345678-1234-4abc-8123-${n.toRadixString(16).padLeft(12, '0')}';
Goal _goal(int n, {String name = '同名目标'}) =>
    Goal.create(id: _id(n), name: name, now: 1);

TimeBlock _block(
  int n,
  int start,
  int end, {
  Goal? goal,
  bool approximate = false,
  bool unknown = false,
}) => TimeBlock(
  id: _id(n),
  startedAt: start,
  endedAt: end,
  startPrecision: approximate ? TimePrecision.approximate : TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '推进或恢复的文字不能替代解释',
  goalId: goal?.id,
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

SleepSession _sleep(int start, int end, SleepType type) => SleepSession(
  id: _id(999),
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  type: type,
  createdAt: 1,
  updatedAt: 2,
);

ReconciliationWindow _window({int end = 100, int? now}) =>
    ReconciliationWindow.select(
      date: CivilDate(year: 2026, month: 9, day: 22),
      relation: now == null
          ? LedgerDateRelation.historical
          : LedgerDateRelation.today,
      dayStartedAt: 0,
      nextDayStartedAt: end,
      now: now ?? end,
    );

List<LedgerSegment> _segments(
  List<TimeBlock> blocks, {
  List<RhythmAnnotation> annotations = const [],
  List<SleepSession> sleeps = const [],
  ReconciliationWindow? window,
}) => projectLedgerSegments(
  window: window ?? _window(),
  timeBlocks: blocks,
  sleepSessions: sleeps,
  annotations: annotations,
);

List<SummaryDuration> _details(GoalSummary goal) => [
  goal.progressDuration,
  goal.stuckDuration,
  goal.recoveryDuration,
  goal.unannotatedDuration,
];

void _expectPartition(GoalSummary goal) {
  expect(
    _details(goal).fold<int>(0, (sum, item) => sum + item.milliseconds),
    goal.totalDuration.milliseconds,
  );
  expect(goal.totalDuration.hasRecords, isTrue);
}

void _expectMissing(SummaryDuration value) {
  expect(value.hasRecords, isFalse);
  expect(value.milliseconds, 0);
  expect(value.hasApproximation, isFalse);
}

void main() {
  test('SOT §18 校正样例：5h 总量、3h30m 推进、40m 卡住、50m 未标记', () {
    const minute = 60000;
    final goal = _goal(100);
    final blocks = [
      _block(1, 570 * minute, 640 * minute, goal: goal),
      _block(2, 640 * minute, 680 * minute, goal: goal),
      _block(3, 800 * minute, 870 * minute, goal: goal),
      _block(4, 900 * minute, 950 * minute, goal: goal),
      _block(5, 1140 * minute, 1210 * minute, goal: goal),
    ];
    final segments = _segments(
      blocks,
      window: _window(end: 1440 * minute),
      annotations: [
        _annotation(blocks[0], RhythmState.progress),
        _annotation(blocks[1], RhythmState.stuck),
        _annotation(blocks[2], RhythmState.progress),
        _annotation(blocks[4], RhythmState.progress),
      ],
    );
    final result = projectGoalSummaries(
      segments: segments,
      goals: [goal],
    ).single;
    expect(result.totalDuration.milliseconds, 300 * minute);
    expect(_details(result).map((item) => item.milliseconds), [
      210 * minute,
      40 * minute,
      0,
      50 * minute,
    ]);
    _expectMissing(result.recoveryDuration);
    _expectPartition(result);
    final global = projectRhythmSummary(segments: segments);
    expect(global.progressDuration.milliseconds, 210 * minute);
    expect(global.stuckDuration.milliseconds, 40 * minute);
    _expectMissing(global.recoveryDuration);
  });

  test('全未标记目标仍显示，不从标题推断 progress 或 recovery', () {
    final goal = _goal(100);
    final segments = _segments([
      _block(1, 0, 20, goal: goal),
      _block(2, 40, 60, goal: goal),
    ]);
    final result = projectGoalSummaries(
      segments: segments,
      goals: [goal],
    ).single;
    expect(result.totalDuration.milliseconds, 40);
    expect(result.unannotatedDuration.milliseconds, 40);
    expect(result.unannotatedDuration.hasRecords, isTrue);
    _expectMissing(result.progressDuration);
    _expectMissing(result.stuckDuration);
    _expectMissing(result.recoveryDuration);
    final global = projectRhythmSummary(segments: segments);
    _expectMissing(global.progressDuration);
    _expectMissing(global.stuckDuration);
    _expectMissing(global.recoveryDuration);
    _expectPartition(result);
  });

  test('全 recovery 目标不算未标记；恢复方式和质量均为空仍计入', () {
    final goal = _goal(100);
    final block = _block(1, 10, 50, goal: goal);
    final segments = _segments(
      [block],
      annotations: [_annotation(block, RhythmState.recovery)],
    );
    final result = projectGoalSummaries(
      segments: segments,
      goals: [goal],
    ).single;
    expect(result.recoveryDuration.milliseconds, 40);
    _expectMissing(result.unannotatedDuration);
    _expectMissing(result.progressDuration);
    _expectMissing(result.stuckDuration);
    expect(
      projectRhythmSummary(segments: segments).recoveryDuration.milliseconds,
      40,
    );
    _expectPartition(result);
  });

  test('无 Goal 的三种节奏照常进入全局，Unknown 和缺少原因不被排除', () {
    final blocks = [
      _block(1, 0, 10),
      _block(2, 10, 30, unknown: true),
      _block(3, 30, 60),
    ];
    final segments = _segments(
      blocks,
      annotations: [
        for (var i = 0; i < 3; i++)
          _annotation(blocks[i], RhythmState.values[i]),
      ],
    );
    final global = projectRhythmSummary(segments: segments);
    expect(
      [
        global.progressDuration.milliseconds,
        global.stuckDuration.milliseconds,
        global.recoveryDuration.milliseconds,
      ],
      [10, 20, 30],
    );
    expect(
      [
        global.progressDuration.hasRecords,
        global.stuckDuration.hasRecords,
        global.recoveryDuration.hasRecords,
      ],
      [true, true, true],
    );
    expect(
      projectGoalSummaries(segments: segments, goals: [_goal(100)]),
      isEmpty,
    );
  });

  test('同名不同 id 分开、归档目标保留标志，无记录目标不占行', () {
    final active = _goal(100);
    final archived = _goal(101).archive(now: 2);
    final unused = _goal(102);
    final segments = _segments([
      _block(1, 0, 10, goal: active),
      _block(2, 20, 50, goal: archived),
    ]);
    final results = projectGoalSummaries(
      segments: segments,
      goals: [archived, unused, active],
    );
    expect(results.map((item) => item.goalId), [archived.id, active.id]);
    expect(results.map((item) => item.name), ['同名目标', '同名目标']);
    expect(results.map((item) => item.isArchived), [true, false]);
    expect(results.map((item) => item.totalDuration.milliseconds), [30, 10]);
    expect(() => results.clear(), throwsUnsupportedError);
    for (final result in results) {
      _expectPartition(result);
    }
  });

  test('窗口外及相接记录不占目标行，空窗口全局各项独立缺失', () {
    final goal = _goal(100);
    final outside = [
      _block(1, -20, 0, goal: goal),
      _block(2, 100, 120, goal: goal),
    ];
    for (final segments in [
      _segments(
        outside,
        annotations: [_annotation(outside[1], RhythmState.progress)],
      ),
      _segments([_block(3, -10, 10, goal: goal)], window: _window(now: 0)),
    ]) {
      expect(projectGoalSummaries(segments: segments, goals: [goal]), isEmpty);
      final global = projectRhythmSummary(segments: segments);
      _expectMissing(global.progressDuration);
      _expectMissing(global.stuckDuration);
      _expectMissing(global.recoveryDuration);
    }
  });

  test('各细分近似独立，总量只聚合自身贡献，不复制全局标志', () {
    final goal = _goal(100);
    for (var approximateIndex = 0; approximateIndex < 4; approximateIndex++) {
      final blocks = [
        for (var i = 0; i < 4; i++)
          _block(
            i + 1,
            i * 20,
            i * 20 + 10,
            goal: goal,
            approximate: i == approximateIndex,
          ),
      ];
      final segments = _segments(
        blocks,
        annotations: [
          for (var i = 0; i < 3; i++)
            _annotation(blocks[i], RhythmState.values[i]),
        ],
      );
      final result = projectGoalSummaries(
        segments: segments,
        goals: [goal],
      ).single;
      expect(result.totalDuration.hasApproximation, isTrue);
      for (var i = 0; i < 4; i++) {
        expect(_details(result)[i].hasRecords, isTrue);
        expect(_details(result)[i].hasApproximation, i == approximateIndex);
      }
      final global = projectRhythmSummary(segments: segments);
      expect(
        [
          global.progressDuration.hasApproximation,
          global.stuckDuration.hasApproximation,
          global.recoveryDuration.hasApproximation,
        ],
        [approximateIndex == 0, approximateIndex == 1, approximateIndex == 2],
      );
      _expectPartition(result);
    }
  });

  test('1 毫秒正贡献仍显示目标及对应细分，其他细分不借用存在性', () {
    final goal = _goal(100);
    for (final state in <RhythmState?>[...RhythmState.values, null]) {
      final block = _block(1, 10, 11, goal: goal, approximate: true);
      final result = projectGoalSummaries(
        segments: _segments(
          [block],
          annotations: [if (state != null) _annotation(block, state)],
        ),
        goals: [goal],
      ).single;
      expect(result.totalDuration.milliseconds, 1);
      expect(result.totalDuration.duration.roundedMinutes, 0);
      final selected = state == null ? 3 : RhythmState.values.indexOf(state);
      for (var i = 0; i < 4; i++) {
        if (i == selected) {
          expect(_details(result)[i].hasRecords, isTrue);
          expect(_details(result)[i].hasApproximation, isTrue);
          expect(_details(result)[i].milliseconds, 1);
        } else {
          _expectMissing(_details(result)[i]);
        }
      }
      _expectPartition(result);
    }
  });

  test('全局恢复包含有/无 Goal，睡眠不算恢复；目标列表筛选不改变账本覆盖', () {
    final goal = _goal(100);
    final blocks = [
      _block(1, 10, 30, goal: goal),
      _block(2, 40, 70, approximate: true),
    ];
    for (final type in SleepType.values) {
      final window = _window();
      final segments = _segments(
        blocks,
        window: window,
        sleeps: [_sleep(80, 100, type)],
        annotations: [
          for (final block in blocks) _annotation(block, RhythmState.recovery),
        ],
      );
      final before = projectLedgerCoverage(window: window, segments: segments);
      final goals = projectGoalSummaries(
        segments: segments,
        goals: [goal, _goal(101)],
      );
      final selected = goals.where((item) => item.goalId == goal.id).toList();
      final global = projectRhythmSummary(segments: segments);
      expect(global.recoveryDuration.milliseconds, 50);
      expect(global.recoveryDuration.hasApproximation, isTrue);
      expect(selected.single.recoveryDuration.milliseconds, 20);
      expect(selected.single.recoveryDuration.hasApproximation, isFalse);
      final after = projectLedgerCoverage(window: window, segments: segments);
      expect(before.accountedDuration.milliseconds, 70);
      expect(
        after.accountedDuration.milliseconds,
        before.accountedDuration.milliseconds,
      );
      expect(after.unresolvedDuration.milliseconds, 30);
      expect(after.unresolvedSpans.map((gap) => (gap.startedAt, gap.endedAt)), [
        (0, 10),
        (30, 40),
        (70, 80),
      ]);
      _expectMissing(global.progressDuration);
      _expectMissing(global.stuckDuration);
    }
  });

  test('只累计窗口内毫秒，裁掉的近似不传播，汇总后才舍入', () {
    final goal = _goal(100);
    final blocks = [
      _block(1, -20000, 20000, goal: goal, approximate: true),
      _block(2, 20000, 80000, goal: goal),
    ];
    final segments = _segments(
      blocks,
      window: _window(end: 100000, now: 40000),
      annotations: [
        for (final block in blocks) _annotation(block, RhythmState.progress),
      ],
    );
    final result = projectGoalSummaries(
      segments: segments,
      goals: [goal],
    ).single;
    expect(result.totalDuration.milliseconds, 40000);
    expect(result.progressDuration.milliseconds, 40000);
    expect(result.progressDuration.duration.roundedMinutes, 1);
    expect(result.progressDuration.hasApproximation, isFalse);
    expect(result.totalDuration.hasApproximation, isFalse);
    _expectPartition(result);
  });

  test('重算采用当前解释与 Goal 元数据，不累计旧解释或更改原对象', () {
    final goal = _goal(100);
    final block = _block(1, 10, 30, goal: goal);
    final before = projectGoalSummaries(
      segments: _segments(
        [block],
        annotations: [_annotation(block, RhythmState.stuck)],
      ),
      goals: [goal],
    ).single;
    final renamed = goal.rename(name: '新名字', now: 3).archive(now: 4);
    final after = projectGoalSummaries(
      segments: _segments(
        [block],
        annotations: [_annotation(block, RhythmState.progress)],
      ),
      goals: [renamed],
    ).single;
    expect(before.stuckDuration.milliseconds, 20);
    expect(after.progressDuration.milliseconds, 20);
    _expectMissing(after.stuckDuration);
    expect(after.name, '新名字');
    expect(after.isArchived, isTrue);
    expect(before.name, '同名目标');
    expect(before.isArchived, isFalse);
    expect(goal.name, '同名目标');
    _expectPartition(after);
  });

  test('缺少被引用 Goal 或重复元数据 id 明确拒绝，不丢弃贡献或任意覆盖', () {
    final goal = _goal(100);
    final segments = _segments([_block(1, 10, 20, goal: goal)]);
    expect(
      () => projectGoalSummaries(segments: segments, goals: []),
      throwsArgumentError,
    );
    expect(
      () => projectGoalSummaries(
        segments: segments,
        goals: [
          goal,
          goal.rename(name: '另一个名字', now: 2),
        ],
      ),
      throwsArgumentError,
    );
  });
}
