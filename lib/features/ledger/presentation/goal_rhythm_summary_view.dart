import 'package:flutter/material.dart';

import '../domain/projection/goal_rhythm_summary.dart';
import 'summary_formatting.dart';

/// 仅展示同一日窗口的既有投影；目标恢复是全局恢复的子集。
class GoalRhythmSummaryView extends StatelessWidget {
  const GoalRhythmSummaryView({
    super.key,
    required this.goals,
    required this.rhythm,
  });

  final List<GoalSummary> goals;
  final RhythmSummary rhythm;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('目标时间（账本窗口）', style: Theme.of(context).textTheme.titleMedium),
      if (goalSummariesEmptyMessage(goals) case final message?) Text(message),
      for (final goal in goals)
        Card(
          key: ValueKey('summary-goal-${goal.goalId}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: Theme.of(context).textTheme.titleSmall),
                if (goal.isArchived) const Text('已归档'),
                Text(
                  '目标相关：${formatDerivedDuration(goal.totalDuration.duration)}',
                ),
                Text(
                  '明确推进：${formatSummaryDuration(goal.progressDuration, kind: SummaryDurationKind.progress)}',
                ),
                Text(
                  '明确卡住：${formatSummaryDuration(goal.stuckDuration, kind: SummaryDurationKind.stuck)}',
                ),
                Text(
                  '目标内恢复：${formatSummaryDuration(goal.recoveryDuration, kind: SummaryDurationKind.recovery)}',
                ),
                Text(
                  '未标记节奏：${formatSummaryDuration(goal.unannotatedDuration, kind: SummaryDurationKind.unannotated)}',
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text('全局节奏（账本窗口）', style: Theme.of(context).textTheme.titleMedium),
      Text(
        '全局推进：${formatSummaryDuration(rhythm.progressDuration, kind: SummaryDurationKind.progress)}',
      ),
      Text(
        '全局卡住：${formatSummaryDuration(rhythm.stuckDuration, kind: SummaryDurationKind.stuck)}',
      ),
      Text(
        '全局恢复：${formatSummaryDuration(rhythm.recoveryDuration, kind: SummaryDurationKind.recovery)}',
      ),
      const Text('全局节奏包含无目标的记录；目标内恢复已包含在全局恢复中。'),
    ],
  );
}
