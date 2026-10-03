import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/derived_duration.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/summary_formatting.dart';

DerivedDuration _duration(int milliseconds, {bool approximate = false}) =>
    DerivedDuration(milliseconds: milliseconds, hasApproximation: approximate);
SummaryDuration _summary(int milliseconds, {bool approximate = false}) =>
    SummaryDuration.fromRecords([
      _duration(milliseconds, approximate: approximate),
    ]);
String _id(int n) => '12345678-1234-4abc-8123-${n.toString().padLeft(12, '0')}';

void main() {
  test('Q-021：所有缺失项用确定文案，不显示实际活动为零', () {
    final empty = SummaryDuration.fromRecords([]);
    final expected = {
      SummaryDurationKind.mainSleep: '尚未记录主睡眠',
      SummaryDurationKind.nap: '尚未记录小睡',
      SummaryDurationKind.progress: '未记录推进',
      SummaryDurationKind.stuck: '未记录卡住',
      SummaryDurationKind.recovery: '未记录恢复',
      SummaryDurationKind.unannotated: '没有未标记节奏的记录',
    };
    for (final entry in expected.entries) {
      expect(formatSummaryDuration(empty, kind: entry.key), entry.value);
    }
  });

  test('Q-021：每类有记录的微小时长不同于缺失，近似提示独立', () {
    for (final kind in SummaryDurationKind.values) {
      for (final milliseconds in [1, 20000, 29999]) {
        expect(
          formatSummaryDuration(_summary(milliseconds), kind: kind),
          '少于 1 分钟',
        );
        expect(
          formatSummaryDuration(
            _summary(milliseconds, approximate: true),
            kind: kind,
          ),
          '约少于 1 分钟',
        );
      }
    }
  });

  test('Q-017：复用最终分钟四舍五入，半分钟边界不使用截断', () {
    for (final (milliseconds, expected) in [
      (29999, '少于 1 分钟'),
      (30000, '1 分钟'),
      (30001, '1 分钟'),
      (59999, '1 分钟'),
      (60000, '1 分钟'),
      (89999, '1 分钟'),
      (90000, '2 分钟'),
      (90001, '2 分钟'),
      (5400000, '90 分钟'),
    ]) {
      for (final approximate in [false, true]) {
        final duration = _summary(milliseconds, approximate: approximate);
        expect(
          formatSummaryDuration(duration, kind: SummaryDurationKind.mainSleep),
          '${approximate ? '约' : ''}$expected',
        );
        expect(duration.milliseconds, milliseconds);
      }
    }
  });

  test('多个小值先由投影汇总后格式化，不累加单条舍入分钟', () {
    final exact = SummaryDuration.fromRecords([
      _duration(20000),
      _duration(20000),
    ]);
    final approximate = SummaryDuration.fromRecords([
      _duration(20000),
      _duration(20000, approximate: true),
    ]);
    expect(
      formatSummaryDuration(exact, kind: SummaryDurationKind.progress),
      '1 分钟',
    );
    expect(
      formatSummaryDuration(approximate, kind: SummaryDurationKind.progress),
      '约1 分钟',
    );
    final roundsDown = SummaryDuration.fromRecords([
      _duration(30000),
      _duration(30000),
    ]);
    expect(
      formatSummaryDuration(roundsDown, kind: SummaryDurationKind.nap),
      '1 分钟',
    );
    expect(exact.milliseconds, 40000);
  });

  test('覆盖及 Gap 的真零是数值零，正时长舍入零仍显示微小时长', () {
    expect(formatDerivedDuration(_duration(0)), '0 分钟');
    expect(formatDerivedDuration(_duration(0, approximate: true)), '0 分钟');
    expect(formatDerivedDuration(_duration(1)), '少于 1 分钟');
    expect(formatDerivedDuration(_duration(1, approximate: true)), '约少于 1 分钟');
    expect(formatDerivedDuration(_duration(60000)), '1 分钟');
  });

  test('空日投影：睡眠、节奏和目标各自缺失，零窗口 Gap 无缺口', () {
    final view = projectDayLedgerView(
      date: CivilDate(year: 2026, month: 9, day: 22),
      relation: LedgerDateRelation.today,
      dayStartedAt: 0,
      nextDayStartedAt: Duration.millisecondsPerDay,
      now: 0,
      timeBlocks: [],
      windowSleepSessions: [],
      annotations: [],
      sleepSummaryCandidates: [],
      goals: [],
    );
    expect(
      formatSummaryDuration(
        view.sleepSummary.mainSleep.totalDuration,
        kind: SummaryDurationKind.mainSleep,
      ),
      '尚未记录主睡眠',
    );
    expect(
      formatSummaryDuration(
        view.sleepSummary.nap.totalDuration,
        kind: SummaryDurationKind.nap,
      ),
      '尚未记录小睡',
    );
    expect(
      formatSummaryDuration(
        view.rhythmSummary.progressDuration,
        kind: SummaryDurationKind.progress,
      ),
      '未记录推进',
    );
    expect(goalSummariesEmptyMessage(view.goalSummaries), '这段时间还没有目标相关记录');
    expect(formatDerivedDuration(view.unresolvedDuration), '0 分钟');
    expect(formatDerivedDuration(view.accountedDuration), '0 分钟');
    expect(formatDerivedDuration(view.unknownDuration), '0 分钟');
  });

  test('真实混合投影：精度、存在性和全局/目标范围不相互污染', () {
    final goal = Goal.create(id: _id(100), name: '学习', now: 0);
    TimeBlock block(
      int n,
      int start,
      int end, {
      bool approximate = false,
      bool linked = true,
    }) => TimeBlock(
      id: _id(n),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.exact,
      endPrecision: approximate
          ? TimePrecision.approximate
          : TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '学习',
      goalId: linked ? goal.id : null,
      createdAt: 0,
      updatedAt: 0,
    );
    final progress = block(1, 0, 20000, approximate: true);
    final unmarked = block(2, 20000, 40000);
    final recovery = block(3, 40000, 100000, linked: false);
    final sleep = SleepSession(
      id: _id(4),
      startedAt: 100000,
      endedAt: 120000,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.nap,
      createdAt: 0,
      updatedAt: 0,
    );
    RhythmAnnotation annotation(TimeBlock source, RhythmState state) =>
        RhythmAnnotation(
          id: source.id,
          timeBlockId: source.id,
          state: state,
          createdAt: 0,
          updatedAt: 0,
        );
    final view = projectDayLedgerView(
      date: CivilDate(year: 2026, month: 9, day: 22),
      relation: LedgerDateRelation.today,
      dayStartedAt: 0,
      nextDayStartedAt: Duration.millisecondsPerDay,
      now: 180000,
      timeBlocks: [progress, unmarked, recovery],
      windowSleepSessions: [sleep],
      annotations: [
        annotation(progress, RhythmState.progress),
        annotation(recovery, RhythmState.recovery),
      ],
      sleepSummaryCandidates: [sleep],
      goals: [goal],
    );
    final item = view.goalSummaries.single;
    expect(goalSummariesEmptyMessage(view.goalSummaries), isNull);
    expect(formatDerivedDuration(item.totalDuration.duration), '约1 分钟');
    expect(
      formatSummaryDuration(
        item.progressDuration,
        kind: SummaryDurationKind.progress,
      ),
      '约少于 1 分钟',
    );
    expect(
      formatSummaryDuration(
        item.stuckDuration,
        kind: SummaryDurationKind.stuck,
      ),
      '未记录卡住',
    );
    expect(
      formatSummaryDuration(
        item.recoveryDuration,
        kind: SummaryDurationKind.recovery,
      ),
      '未记录恢复',
    );
    expect(
      formatSummaryDuration(
        item.unannotatedDuration,
        kind: SummaryDurationKind.unannotated,
      ),
      '少于 1 分钟',
    );
    expect(
      formatSummaryDuration(
        view.rhythmSummary.recoveryDuration,
        kind: SummaryDurationKind.recovery,
      ),
      '1 分钟',
    );
    expect(
      formatSummaryDuration(
        view.sleepSummary.mainSleep.totalDuration,
        kind: SummaryDurationKind.mainSleep,
      ),
      '尚未记录主睡眠',
    );
    expect(
      formatSummaryDuration(
        view.sleepSummary.nap.totalDuration,
        kind: SummaryDurationKind.nap,
      ),
      '少于 1 分钟',
    );
    expect(formatDerivedDuration(view.accountedDuration), '约2 分钟');
    expect(formatDerivedDuration(view.unresolvedDuration), '1 分钟');
    expect(view.accountedDuration.milliseconds, 120000);
    expect(item.totalDuration.milliseconds, 40000);
  });
}
