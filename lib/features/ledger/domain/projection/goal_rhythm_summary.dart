import '../../../../core/identity/entity_id.dart';
import '../../../goals/domain/goal.dart';
import '../../../goals/domain/goal_status.dart';
import '../rhythm_state.dart';
import 'derived_duration.dart';
import 'ledger_segment.dart';

/// 同一窗口中全部普通事实的明确节奏；包含无 Goal 的记录。
final class RhythmSummary {
  RhythmSummary._(List<TimeBlockSegment> parts)
    : progressDuration = _sumState(parts, RhythmState.progress),
      stuckDuration = _sumState(parts, RhythmState.stuck),
      recoveryDuration = _sumState(parts, RhythmState.recovery);

  final SummaryDuration progressDuration;
  final SummaryDuration stuckDuration;
  final SummaryDuration recoveryDuration;
}

/// 有窗口内正贡献的单个 Goal；按 id 区分，归档不隐藏历史时间（Q-020）。
final class GoalSummary {
  GoalSummary._(Goal goal, List<TimeBlockSegment> parts)
    : goalId = goal.id,
      name = goal.name,
      isArchived = goal.status == GoalStatus.archived,
      totalDuration = SummaryDuration.fromRecords(
        parts.map((part) => part.duration),
      ),
      progressDuration = _sumState(parts, RhythmState.progress),
      stuckDuration = _sumState(parts, RhythmState.stuck),
      recoveryDuration = _sumState(parts, RhythmState.recovery),
      unannotatedDuration = _sumState(parts, null);

  final EntityId goalId;
  final String name;
  final bool isArchived;
  final SummaryDuration totalDuration;
  final SummaryDuration progressDuration;
  final SummaryDuration stuckDuration;
  final SummaryDuration recoveryDuration;

  /// 仅无 annotation 的记录，不用总量减 progress / stuck 推导。
  final SummaryDuration unannotatedDuration;
}

/// 输入为同一窗口的完整合法切片；不查询、不修改切片或覆盖结果。
///
/// 睡眠不计作 recovery；无解释不推断节奏，可选原因 / 恢复细节为空
/// 不排除记录。各项按自身参与集携带存在性与近似（Q-014、Q-021）。
RhythmSummary projectRhythmSummary({
  required Iterable<LedgerSegment> segments,
}) => RhythmSummary._(segments.whereType<TimeBlockSegment>().toList());

/// 按 Goal id 汇总同一窗口的全部切片，返回不可修改的目标列表。
///
/// goals 是调用方提供的完整所需元数据，允许额外无记录目标；不把
/// 元数据当作目标筛选条件。缺失被引用目标或重复 id 是调用输入错误，
/// 拒绝而不生成替代名称、丢弃贡献或选择任意一份元数据。
/// 结果沿用传入 goals 的顺序（工程约定，不定义 UI 排序）。
/// 全局 recovery 与各目标 recovery 是不同观察范围，不再次相加。
List<GoalSummary> projectGoalSummaries({
  required Iterable<LedgerSegment> segments,
  required Iterable<Goal> goals,
}) {
  final byId = <EntityId, Goal>{};
  for (final goal in goals) {
    if (byId.containsKey(goal.id)) {
      throw ArgumentError('Goal metadata must have unique ids');
    }
    byId[goal.id] = goal;
  }

  final contributions = <EntityId, List<TimeBlockSegment>>{};
  for (final part in segments.whereType<TimeBlockSegment>()) {
    final goalId = part.source.goalId;
    if (goalId == null) continue;
    if (!byId.containsKey(goalId)) {
      throw ArgumentError.value(
        goalId,
        'goals',
        'Missing referenced Goal metadata',
      );
    }
    contributions.putIfAbsent(goalId, () => []).add(part);
  }

  return List.unmodifiable([
    for (final goal in byId.values)
      if (contributions[goal.id] case final parts?) GoalSummary._(goal, parts),
  ]);
}

SummaryDuration _sumState(
  Iterable<TimeBlockSegment> parts,
  RhythmState? state,
) => SummaryDuration.fromRecords(
  parts
      .where((part) => part.annotation?.state == state)
      .map((part) => part.duration),
);
