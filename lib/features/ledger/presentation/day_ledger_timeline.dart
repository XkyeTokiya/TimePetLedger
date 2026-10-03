import 'package:flutter/material.dart';

import '../domain/block_knowledge_state.dart';
import '../domain/projection/goal_rhythm_summary.dart';
import '../domain/projection/day_ledger_view.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart';
import 'summary_formatting.dart';
import 'recording_rhythm_input.dart' show rhythmInputLabel;

String _boundary(int instant, TimePrecision precision) =>
    '${precision == TimePrecision.approximate ? '约' : ''}${formatRecordingTime(instant)}';

/// 只合排现有切片和 Gap，不计算、筛选或持久化事实。
class DayLedgerTimeline extends StatelessWidget {
  const DayLedgerTimeline({
    super.key,
    required this.view,
    this.onFillGap,
    this.onEditFact,
    this.onDeleteTimeBlock,
  });

  final DayLedgerView view;
  final ValueChanged<UnresolvedSpan>? onFillGap;
  final ValueChanged<LedgerSegment>? onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;

  @override
  Widget build(BuildContext context) {
    // Metadata comes from the same committed snapshot, keyed by identity.
    final goals = {for (final goal in view.goalSummaries) goal.goalId: goal};
    final rows = <({int start, Widget tile})>[
      for (final segment in view.segments)
        (
          start: segment.startedAt,
          tile: LedgerFactTimelineTile(
            key: ValueKey(segment.reference),
            segment: segment,
            goal: segment is TimeBlockSegment
                ? goals[segment.source.goalId]
                : null,
            onEdit: onEditFact == null ? null : () => onEditFact!(segment),
            onDelete: segment is TimeBlockSegment && onDeleteTimeBlock != null
                ? () => onDeleteTimeBlock!(segment)
                : null,
          ),
        ),
      for (final gap in view.unresolvedSpans)
        (
          start: gap.startedAt,
          tile: LedgerGapTimelineTile(
            gap: gap,
            onFill: onFillGap == null ? null : () => onFillGap!(gap),
          ),
        ),
    ]..sort((left, right) => left.start.compareTo(right.start));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final row in rows) row.tile],
    );
  }
}

/// 操作携带原事实身份；展示边界仍仅为当前窗口切片。
class LedgerFactTimelineTile extends StatelessWidget {
  const LedgerFactTimelineTile({
    super.key,
    required this.segment,
    this.goal,
    this.onEdit,
    this.onDelete,
  });

  final LedgerSegment segment;
  final GoalSummary? goal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final (label, icon, title) = switch (segment) {
      TimeBlockSegment(:final source) => (
        source.knowledgeState == BlockKnowledgeState.unknown
            ? '未知 · 想不起来'
            : '已知',
        source.knowledgeState == BlockKnowledgeState.unknown
            ? Icons.help_outline
            : Icons.article_outlined,
        source.title,
      ),
      SleepSessionSegment(:final source) => (
        source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
        Icons.bedtime_outlined,
        null,
      ),
    };
    final annotation = switch (segment) {
      TimeBlockSegment(:final annotation) => annotation,
      SleepSessionSegment() => null,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        onTap: onEdit,
        trailing: onEdit == null && onDelete == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: '更正完整记录',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: '删除记录',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(label), if (title != null) Text(title)],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_boundary(segment.startedAt, segment.startPrecision)} → '
              '${_boundary(segment.endedAt, segment.endPrecision)}\n'
              '${formatDerivedDuration(segment.duration)}',
            ),
            if (goal case final selected?)
              Text('目标：${selected.name}${selected.isArchived ? '（已归档）' : ''}'),
            if (annotation != null) ...[
              Text('节奏：${rhythmInputLabel(annotation.state)}'),
              if (annotation.continuationHint case final hint?)
                Text('接续点：$hint'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gap 没有事实身份，也没有 Unknown 的持久化语义。
class LedgerGapTimelineTile extends StatelessWidget {
  const LedgerGapTimelineTile({super.key, required this.gap, this.onFill});

  final UnresolvedSpan gap;
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: const Text('尚未记录'),
      onTap: onFill,
      trailing: onFill == null
          ? null
          : TextButton(onPressed: onFill, child: const Text('补一笔')),
      subtitle: Text(
        '${_boundary(gap.startedAt, gap.startPrecision)} → '
        '${_boundary(gap.endedAt, gap.endPrecision)}\n'
        '${formatDerivedDuration(gap.duration)}',
      ),
    ),
  );
}
