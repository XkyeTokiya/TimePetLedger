import '../domain/projection/derived_duration.dart';
import '../domain/projection/goal_rhythm_summary.dart';

/// 仅用于选择 Q-021 缺失文案，不是领域分类或持久化值。
enum SummaryDurationKind {
  mainSleep,
  nap,
  progress,
  stuck,
  recovery,
  unannotated,
}

/// 接收已汇总的单项投影；存在性独立于最终舍入分钟数。
String formatSummaryDuration(
  SummaryDuration summary, {
  required SummaryDurationKind kind,
}) {
  if (!summary.hasRecords) {
    return switch (kind) {
      SummaryDurationKind.mainSleep => '尚未记录主睡眠',
      SummaryDurationKind.nap => '尚未记录小睡',
      SummaryDurationKind.progress => '未记录推进',
      SummaryDurationKind.stuck => '未记录卡住',
      SummaryDurationKind.recovery => '未记录恢复',
      SummaryDurationKind.unannotated => '没有未标记节奏的记录',
    };
  }
  return formatDerivedDuration(summary.duration);
}

/// 覆盖、Unknown、Gap 或已有记录的时长展示，不从数值推断活动缺失。
///
/// 零值显示 0 分钟（Gap 为无缺口）；只有实际正时长舍入为零时使用
/// “少于 1 分钟”。普通时长统一显示分钟；仅复用最终舍入结果，
/// 不查询、切片或汇总事实，不从其他摘要借用近似标志。
String formatDerivedDuration(DerivedDuration duration) {
  final minutes = duration.roundedMinutes;
  final text = duration.milliseconds > 0 && minutes == 0
      ? '少于 1 分钟'
      : '$minutes 分钟';
  return duration.hasApproximation ? '约$text' : text;
}

/// null 表示无需空列表提示；有目标但缺少某项节奏时由单项函数表达。
String? goalSummariesEmptyMessage(List<GoalSummary> summaries) =>
    summaries.isEmpty ? '这段时间还没有目标相关记录' : null;
