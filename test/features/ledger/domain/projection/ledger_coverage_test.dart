import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

String _id(int value) =>
    '12345678-1234-4abc-8123-${value.abs().toRadixString(16).padLeft(12, '0')}';

TimeBlock _block(
  int start,
  int end, {
  String? id,
  bool unknown = false,
  String? goalId,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => TimeBlock(
  id: id ?? _id(start),
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '普通活动',
  goalId: goalId,
  createdAt: 1,
  updatedAt: 2,
);

SleepSession _sleep(
  int start,
  int end, {
  SleepType type = SleepType.mainSleep,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => SleepSession(
  id: _id(start),
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
  createdAt: 1,
  updatedAt: 2,
);

ReconciliationWindow _window({
  int end = 100,
  LedgerDateRelation relation = LedgerDateRelation.historical,
  int? now,
}) => ReconciliationWindow.select(
  date: CivilDate(year: 2026, month: 9, day: 22),
  relation: relation,
  dayStartedAt: 0,
  nextDayStartedAt: end,
  now: now ?? end,
);

LedgerCoverage _coverage({
  ReconciliationWindow? window,
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
  List<RhythmAnnotation> annotations = const [],
}) {
  final selectedWindow = window ?? _window();
  return projectLedgerCoverage(
    window: selectedWindow,
    segments: projectLedgerSegments(
      window: selectedWindow,
      timeBlocks: blocks,
      sleepSessions: sleeps,
      annotations: annotations,
    ),
  );
}

void _expectPartition(LedgerCoverage result) {
  expect(
    result.accountedDuration.milliseconds +
        result.unresolvedDuration.milliseconds,
    result.window.milliseconds,
  );
  expect(
    result.unknownDuration.milliseconds,
    inInclusiveRange(0, result.accountedDuration.milliseconds),
  );
  expect(
    result.unresolvedSpans.fold<int>(
      0,
      (sum, gap) => sum + gap.duration.milliseconds,
    ),
    result.unresolvedDuration.milliseconds,
  );
  for (final gap in result.unresolvedSpans) {
    expect(gap.startedAt, greaterThanOrEqualTo(result.window.startedAt));
    expect(gap.endedAt, lessThanOrEqualTo(result.window.endedAt));
    expect(gap.duration.milliseconds, greaterThan(0));
  }
}

List<(int, int)> _gaps(LedgerCoverage result) => [
  for (final gap in result.unresolvedSpans) (gap.startedAt, gap.endedAt),
];

void main() {
  test('空窗口无 Gap，三项时长为零且不引入近似', () {
    for (final relation in [
      LedgerDateRelation.today,
      LedgerDateRelation.future,
    ]) {
      final result = _coverage(
        window: _window(relation: relation, now: 0),
        blocks: [_block(-10, 10, startPrecision: TimePrecision.approximate)],
      );
      expect(result.unresolvedSpans, isEmpty);
      for (final duration in [
        result.accountedDuration,
        result.unknownDuration,
        result.unresolvedDuration,
      ]) {
        expect(duration.milliseconds, 0);
        expect(duration.hasApproximation, isFalse);
      }
      _expectPartition(result);
    }
  });

  test('非空窗口无事实时整个窗口为精确 Gap，复用实际 23/25 小时与 now 边界', () {
    for (final window in [
      _window(end: 23 * 3600000),
      _window(end: 25 * 3600000),
      _window(end: 86400000, relation: LedgerDateRelation.today, now: 54000123),
    ]) {
      final result = _coverage(window: window);
      expect(_gaps(result), [(0, window.endedAt)]);
      expect(result.accountedDuration.milliseconds, 0);
      expect(result.unknownDuration.milliseconds, 0);
      expect(result.unresolvedDuration.milliseconds, window.milliseconds);
      expect(result.unresolvedDuration.hasApproximation, isFalse);
      expect(result.unresolvedSpans.single.startPrecision, TimePrecision.exact);
      expect(result.unresolvedSpans.single.endPrecision, TimePrecision.exact);
      _expectPartition(result);
    }
  });

  test('首尾及内部空白全部生成 Gap，不修改输入或返回可变集合', () {
    final window = _window();
    final segments = projectLedgerSegments(
      window: window,
      timeBlocks: [_block(60, 80), _block(20, 40)],
      sleepSessions: [],
      annotations: [],
    ).reversed.toList();
    final result = projectLedgerCoverage(window: window, segments: segments);
    expect(_gaps(result), [(0, 20), (40, 60), (80, 100)]);
    expect(result.accountedDuration.milliseconds, 40);
    expect(result.unresolvedDuration.milliseconds, 60);
    expect(segments.map((part) => part.startedAt), [60, 20]);
    expect(() => result.unresolvedSpans.clear(), throwsUnsupportedError);
    _expectPartition(result);
  });

  test('连续相接事实无零时长 Gap，睡眠和 Unknown 都填补覆盖', () {
    final result = _coverage(
      blocks: [_block(20, 60, unknown: true), _block(60, 100)],
      sleeps: [_sleep(0, 20)],
    );
    expect(result.unresolvedSpans, isEmpty);
    expect(result.accountedDuration.milliseconds, 100);
    expect(result.unknownDuration.milliseconds, 40);
    expect(result.unresolvedDuration.milliseconds, 0);
    _expectPartition(result);
  });

  test('仅 Unknown 也已交代，unknown 是子集而不是另一次覆盖', () {
    final result = _coverage(blocks: [_block(10, 90, unknown: true)]);
    expect(result.accountedDuration.milliseconds, 80);
    expect(result.unknownDuration.milliseconds, 80);
    expect(result.unresolvedDuration.milliseconds, 20);
    expect(_gaps(result), [(0, 10), (90, 100)]);
    _expectPartition(result);
  });

  test('仅睡眠按窗口贡献覆盖，主睡眠和小睡均不计入 Unknown', () {
    for (final type in SleepType.values) {
      final result = _coverage(sleeps: [_sleep(-10, 70, type: type)]);
      expect(result.accountedDuration.milliseconds, 70);
      expect(result.unknownDuration.milliseconds, 0);
      expect(result.unknownDuration.hasApproximation, isFalse);
      expect(_gaps(result), [(70, 100)]);
      _expectPartition(result);
    }
  });

  test('DERIVED 手算例：睡眠/known/unknown/目标/无目标全参与，解释不重复计时', () {
    const minute = 60000;
    final blocks = [
      _block(60 * minute, 120 * minute, goalId: _id(1)),
      _block(120 * minute, 150 * minute, unknown: true),
      _block(180 * minute, 210 * minute, goalId: _id(1)),
      _block(210 * minute, 240 * minute),
    ];
    final annotations = [
      for (final (index, state) in [
        (0, RhythmState.progress),
        (2, RhythmState.stuck),
        (3, RhythmState.recovery),
      ])
        RhythmAnnotation(
          id: _id(index + 1),
          timeBlockId: blocks[index].id,
          state: state,
          createdAt: 1,
          updatedAt: 2,
        ),
    ];
    for (final explanation in [<RhythmAnnotation>[], annotations]) {
      final result = _coverage(
        window: _window(end: 240 * minute),
        blocks: blocks,
        sleeps: [_sleep(0, 60 * minute)],
        annotations: explanation,
      );
      expect(result.accountedDuration.milliseconds, 210 * minute);
      expect(result.unknownDuration.milliseconds, 30 * minute);
      expect(result.unresolvedDuration.milliseconds, 30 * minute);
      expect(_gaps(result), [(150 * minute, 180 * minute)]);
      _expectPartition(result);
    }
  });

  test('Gap 两端只继承相邻事实的对应精度，三项时长各自判断近似', () {
    final result = _coverage(
      blocks: [
        _block(20, 40, startPrecision: TimePrecision.approximate),
        _block(60, 80, unknown: true, endPrecision: TimePrecision.approximate),
      ],
    );
    expect(_gaps(result), [(0, 20), (40, 60), (80, 100)]);
    expect(
      result.unresolvedSpans.map(
        (gap) => (gap.startPrecision, gap.endPrecision),
      ),
      [
        (TimePrecision.exact, TimePrecision.approximate),
        (TimePrecision.exact, TimePrecision.exact),
        (TimePrecision.approximate, TimePrecision.exact),
      ],
    );
    expect(result.unresolvedSpans.map((gap) => gap.duration.hasApproximation), [
      true,
      false,
      true,
    ]);
    expect(result.accountedDuration.hasApproximation, isTrue);
    expect(result.unknownDuration.hasApproximation, isTrue);
    expect(result.unresolvedDuration.hasApproximation, isTrue);
    _expectPartition(result);
  });

  test('内部 Gap 可继承睡眠结束和普通事实开始的任一近似边界', () {
    for (final sleepEnd in TimePrecision.values) {
      for (final blockStart in TimePrecision.values) {
        final result = _coverage(
          sleeps: [_sleep(0, 40, endPrecision: sleepEnd)],
          blocks: [_block(60, 100, startPrecision: blockStart)],
        );
        expect(_gaps(result), [(40, 60)]);
        expect(result.unresolvedSpans.single.startPrecision, sleepEnd);
        expect(result.unresolvedSpans.single.endPrecision, blockStart);
        expect(
          result.unresolvedDuration.hasApproximation,
          sleepEnd == TimePrecision.approximate ||
              blockStart == TimePrecision.approximate,
        );
        expect(result.unknownDuration.hasApproximation, isFalse);
        _expectPartition(result);
      }
    }
  });

  test('全部覆盖但内部边界近似：零缺口保持无近似', () {
    final result = _coverage(
      sleeps: [_sleep(0, 50, endPrecision: TimePrecision.approximate)],
      blocks: [
        _block(
          50,
          100,
          unknown: true,
          startPrecision: TimePrecision.approximate,
        ),
      ],
    );
    expect(result.accountedDuration.hasApproximation, isTrue);
    expect(result.unknownDuration.hasApproximation, isTrue);
    expect(result.unresolvedSpans, isEmpty);
    expect(result.unresolvedDuration.milliseconds, 0);
    expect(result.unresolvedDuration.hasApproximation, isFalse);
    _expectPartition(result);
  });

  test('已有近似覆盖也可有精确非空 Gap，不把全局近似复制到其他项', () {
    final result = _coverage(
      blocks: [
        _block(0, 30, startPrecision: TimePrecision.approximate),
        _block(30, 50, unknown: true),
      ],
    );
    expect(_gaps(result), [(50, 100)]);
    expect(result.accountedDuration.hasApproximation, isTrue);
    expect(result.unknownDuration.hasApproximation, isFalse);
    expect(result.unresolvedDuration.hasApproximation, isFalse);
    _expectPartition(result);
  });

  test('跨日近似被裁掉不传播；今天尾部只截止 now，未来事实不贡献', () {
    final result = _coverage(
      window: _window(relation: LedgerDateRelation.today, now: 70),
      sleeps: [_sleep(-10, 30, startPrecision: TimePrecision.approximate)],
      blocks: [
        _block(
          80,
          100,
          unknown: true,
          startPrecision: TimePrecision.approximate,
        ),
      ],
    );
    expect(_gaps(result), [(30, 70)]);
    expect(result.accountedDuration.milliseconds, 30);
    expect(result.accountedDuration.hasApproximation, isFalse);
    expect(result.unknownDuration.milliseconds, 0);
    expect(result.unknownDuration.hasApproximation, isFalse);
    expect(result.unresolvedDuration.hasApproximation, isFalse);
    _expectPartition(result);
  });

  test('新增/更正/删除后的新快照重算分区，不保留陈旧 Gap 或更改旧输出', () {
    final original = _block(20, 40, unknown: true);
    final filled = _block(40, 60);
    final before = _coverage(blocks: [original]);
    final afterAdd = _coverage(blocks: [original, filled]);
    final afterEdit = _coverage(
      blocks: [
        _block(10, 40, id: original.id),
        filled,
      ],
    );
    final afterDelete = _coverage(blocks: [filled]);
    final afterClear = _coverage();
    expect(
      [
        for (final result in [
          before,
          afterAdd,
          afterEdit,
          afterDelete,
          afterClear,
        ])
          (
            result.accountedDuration.milliseconds,
            result.unknownDuration.milliseconds,
            result.unresolvedDuration.milliseconds,
          ),
      ],
      [(20, 20, 80), (40, 20, 60), (50, 0, 50), (20, 0, 80), (0, 0, 100)],
    );
    expect(_gaps(before), [(0, 20), (40, 100)]);
    expect(_gaps(afterEdit), [(0, 10), (60, 100)]);
    expect(_gaps(afterDelete), [(0, 40), (60, 100)]);
    for (final result in [
      before,
      afterAdd,
      afterEdit,
      afterDelete,
      afterClear,
    ]) {
      _expectPartition(result);
    }
    expect(original.knowledgeState, BlockKnowledgeState.unknown);
    expect(original.startedAt, 20);
  });

  test('16 种合法覆盖组合保持毫秒分区及 Unknown 子集，空槽合并为连续 Gap', () {
    for (var mask = 0; mask < 16; mask++) {
      final blocks = <TimeBlock>[];
      final sleeps = <SleepSession>[];
      var occupied = 0;
      for (var slot = 0; slot < 4; slot++) {
        if (mask & (1 << slot) == 0) continue;
        occupied++;
        final start = slot * 25;
        if (slot == 2) {
          sleeps.add(_sleep(start, start + 25));
        } else {
          blocks.add(_block(start, start + 25, unknown: slot == 1));
        }
      }
      final result = _coverage(blocks: blocks, sleeps: sleeps);
      expect(result.accountedDuration.milliseconds, occupied * 25);
      expect(result.unknownDuration.milliseconds, mask & 2 == 0 ? 0 : 25);
      _expectPartition(result);
      for (var index = 1; index < result.unresolvedSpans.length; index++) {
        expect(
          result.unresolvedSpans[index - 1].endedAt,
          lessThan(result.unresolvedSpans[index].startedAt),
        );
      }
    }
  });
}
