import '../../../../core/time/civil_date.dart';
import '../../../../core/time/time_contract.dart';
import '../../../goals/domain/goal.dart';
import '../rhythm_annotation.dart';
import '../sleep_session.dart';
import '../time_block.dart';
import 'derived_duration.dart';
import 'goal_rhythm_summary.dart';
import 'ledger_coverage.dart';
import 'ledger_segment.dart';
import 'reconciliation_window.dart';
import 'sleep_summary.dart';

/// 一次自然日投影的不可变结果，不是持久化 Day 或聚合事实源。
final class DayLedgerView {
  const DayLedgerView._({
    required this.segments,
    required this.coverage,
    required this.sleepSummary,
    required this.goalSummaries,
    required this.rhythmSummary,
  });

  final List<LedgerSegment> segments;
  final LedgerCoverage coverage;
  final SleepSummary sleepSummary;
  final List<GoalSummary> goalSummaries;
  final RhythmSummary rhythmSummary;

  ReconciliationWindow get window => coverage.window;
  CivilDate get date => window.date;
  List<UnresolvedSpan> get unresolvedSpans => coverage.unresolvedSpans;
  DerivedDuration get accountedDuration => coverage.accountedDuration;
  DerivedDuration get unknownDuration => coverage.unknownDuration;
  DerivedDuration get unresolvedDuration => coverage.unresolvedDuration;
}

/// 复用既有算法，以同一 W 组装切片、覆盖、目标与全局节奏。
///
/// 调用方提供当前设备时区下 date 的日边界、与今天的关系及显式 now；
/// 不读取设备时区或时钟，日窗口政策沿用 ReconciliationWindow。
///
/// 输入须来自一致、合法、不重叠、同类型身份唯一的正式事实快照：
/// - timeBlocks / windowSleepSessions 覆盖 W 内全部主要事实，不按
///   Goal、节奏或已知性筛选；允许额外窗口外事实，切片只取正交集。
/// - annotations 包含所需 TimeBlock 的当前解释，不是额外时间事实。
/// - sleepSummaryCandidates 包含醒来日期为 date 的全部完整睡眠，
///   包括午夜醒来及 W 外记录；允许其他日期候选，由摘要入口选择。
///   与窗口输入中的同一事实须一致，但两个集合不合并、不重复计时。
/// - goals 提供窗口贡献所引用的完整 Goal 元数据，可含无记录目标。
///
/// 数据查询与快照完整性由调用方保证。本入口不修复、去重或合并
/// 非法输入，沿用子算法的参数错误；不修改输入，不做 I/O 或持久化。
DayLedgerView projectDayLedgerView({
  required CivilDate date,
  required LedgerDateRelation relation,
  required InstantMilliseconds dayStartedAt,
  required InstantMilliseconds nextDayStartedAt,
  required InstantMilliseconds now,
  required Iterable<TimeBlock> timeBlocks,
  required Iterable<SleepSession> windowSleepSessions,
  required Iterable<RhythmAnnotation> annotations,
  required Iterable<SleepSession> sleepSummaryCandidates,
  required Iterable<Goal> goals,
}) {
  final window = ReconciliationWindow.select(
    date: date,
    relation: relation,
    dayStartedAt: dayStartedAt,
    nextDayStartedAt: nextDayStartedAt,
    now: now,
  );
  final segments = projectLedgerSegments(
    window: window,
    timeBlocks: timeBlocks,
    sleepSessions: windowSleepSessions,
    annotations: annotations,
  );
  return DayLedgerView._(
    segments: segments,
    coverage: projectLedgerCoverage(window: window, segments: segments),
    sleepSummary: projectSleepSummary(
      sleepSessions: sleepSummaryCandidates,
      dayStartedAt: dayStartedAt,
      nextDayStartedAt: nextDayStartedAt,
    ),
    goalSummaries: projectGoalSummaries(segments: segments, goals: goals),
    rhythmSummary: projectRhythmSummary(segments: segments),
  );
}
