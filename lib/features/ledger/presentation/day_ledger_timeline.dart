import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/block_knowledge_state.dart';
import '../domain/projection/derived_duration.dart';
import '../domain/projection/goal_rhythm_summary.dart';
import '../domain/projection/day_ledger_view.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart';
import 'summary_formatting.dart';
import 'day_read_scroll.dart';
import 'day_ledger_fact_details.dart';
import 'recording_rhythm_input.dart' show rhythmInputLabel;

String _boundary(int instant, TimePrecision precision) =>
    formatRecordingTime(instant);

String _compactDuration(DerivedDuration value) {
  final text = formatDerivedDuration(value).replaceAll(' ', '');
  return text.contains('小时') ? text.replaceAll('分钟', '分') : text;
}

/// 只合排现有切片和 Gap，不计算、筛选或持久化事实。
class DayLedgerTimeline extends StatelessWidget {
  const DayLedgerTimeline({
    super.key,
    required this.view,
    this.onFillGap,
    this.onEditFact,
    this.onDeleteTimeBlock,
    this.onDetailsVisibilityChanged,
  });

  final DayLedgerView view;
  final ValueChanged<UnresolvedSpan>? onFillGap;
  final ValueChanged<LedgerSegment>? onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final ValueChanged<bool>? onDetailsVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    // Metadata comes from the same committed snapshot, keyed by identity.
    final goals = {for (final goal in view.goalSummaries) goal.goalId: goal};
    final rows = <({int start, Widget tile})>[
      for (final segment in view.segments)
        (
          start: segment.startedAt,
          tile: ReadScrollAnchor(
            id: segment.reference,
            order: segment.startedAt,
            child: LedgerFactTimelineTile(
              key: ValueKey(segment.reference),
              segment: segment,
              onDetailsVisibilityChanged: onDetailsVisibilityChanged,
              goal: segment is TimeBlockSegment
                  ? goals[segment.source.goalId]
                  : null,
              onEdit: onEditFact == null ? null : () => onEditFact!(segment),
              onDelete: segment is TimeBlockSegment && onDeleteTimeBlock != null
                  ? () => onDeleteTimeBlock!(segment)
                  : null,
            ),
          ),
        ),
      for (final gap in view.unresolvedSpans)
        (
          start: gap.startedAt,
          tile: ReadScrollAnchor(
            id: (gap.startedAt, gap.endedAt),
            order: gap.startedAt,
            child: LedgerGapTimelineTile(
              gap: gap,
              onFill: onFillGap == null ? null : () => onFillGap!(gap),
            ),
          ),
        ),
    ]..sort((left, right) => left.start.compareTo(right.start));
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final row in rows) row.tile],
        ),
      ),
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
    this.onDetailsVisibilityChanged,
  });

  final LedgerSegment segment;
  final GoalSummary? goal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onDetailsVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, icon, color, status) = switch (segment) {
      TimeBlockSegment(:final source) => (
        source.knowledgeState == BlockKnowledgeState.unknown
            ? '想不起来'
            : source.title!,
        source.knowledgeState == BlockKnowledgeState.unknown
            ? Icons.help_outline
            : Icons.article_outlined,
        source.knowledgeState == BlockKnowledgeState.unknown
            ? colors.tertiary
            : colors.primary,
        source.knowledgeState == BlockKnowledgeState.unknown ? '已交代' : null,
      ),
      SleepSessionSegment(:final source) => (
        source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
        Icons.bedtime_outlined,
        colors.secondary,
        null,
      ),
    };
    final annotation = switch (segment) {
      TimeBlockSegment(:final annotation) => annotation,
      SleepSessionSegment() => null,
    };
    return _TimelineRow(
      startedAt: segment.startedAt,
      endedAt: segment.endedAt,
      startPrecision: segment.startPrecision,
      endPrecision: segment.endPrecision,
      duration: segment.duration,
      title: title,
      icon: icon,
      color: color,
      onTap: () async {
        onDetailsVisibilityChanged?.call(true);
        final action = await showLedgerFactDetails(
          context,
          segment: segment,
          goal: goal,
          canEdit: onEdit != null,
          canDelete: onDelete != null && segment is! SleepSessionSegment,
        );
        if (!context.mounted) return;
        onDetailsVisibilityChanged?.call(false);
        switch (action) {
          case LedgerDetailAction.edit:
            onEdit?.call();
          case LedgerDetailAction.delete:
            if (segment is SleepSessionSegment) {
              onEdit?.call();
            } else {
              onDelete?.call();
            }
          case null:
            break;
        }
      },
      details: [
        if (segment case TimeBlockSegment(:final source))
          if (source.knowledgeState == BlockKnowledgeState.unknown &&
              source.title != null)
            Text(source.title!),
        if (segment case SleepSessionSegment(:final source))
          if (source.startedAt != segment.startedAt ||
              source.endedAt != segment.endedAt) ...[
            Text(
              '当日时长${source.startedAt != segment.startedAt || source.endedAt != segment.endedAt ? ' · 跨日睡眠' : ''}',
            ),
            Text(
              '完整${_compactDuration(DerivedDuration(milliseconds: source.endedAt - source.startedAt, hasApproximation: source.startPrecision == TimePrecision.approximate || source.endPrecision == TimePrecision.approximate))}',
            ),
          ],
        if (status != null || goal != null || annotation != null)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (status != null) Text(status),
              if (goal case final selected?)
                _TimelineTag(
                  '${selected.name}${selected.isArchived ? '（已归档）' : ''}',
                  color: colors.onSurfaceVariant,
                ),
              if (annotation != null)
                _TimelineTag(
                  rhythmInputLabel(annotation.state),
                  color: colors.primary,
                ),
            ],
          ),
      ],
    );
  }
}

/// Gap 没有事实身份，也没有 Unknown 的持久化语义。
class LedgerGapTimelineTile extends StatelessWidget {
  const LedgerGapTimelineTile({super.key, required this.gap, this.onFill});

  final UnresolvedSpan gap;
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _TimelineRow(
      startedAt: gap.startedAt,
      endedAt: gap.endedAt,
      startPrecision: gap.startPrecision,
      endPrecision: gap.endPrecision,
      duration: gap.duration,
      title: '尚未记录',
      icon: Icons.add_circle_outline,
      color: colors.onSurfaceVariant,
      isGap: true,
      onTap: onFill,
      actions: [
        if (onFill != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: colors.primary,
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
              side: BorderSide(color: colors.primary),
            ),
            onPressed: onFill,
            child: const Text('补记'),
          ),
      ],
    );
  }
}

class _TimelineTag extends StatelessWidget {
  const _TimelineTag(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.duration,
    required this.title,
    required this.icon,
    required this.color,
    this.isGap = false,
    this.onTap,
    this.details = const [],
    this.actions = const [],
  });

  final int startedAt;
  final int endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;
  final DerivedDuration duration;
  final String title;
  final IconData icon;
  final Color color;
  final bool isGap;
  final VoidCallback? onTap;
  final List<Widget> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final timeStyle = TextStyle(
      fontSize: 13,
      color: colors.onSurfaceVariant,
      height: 1.5,
    );
    // Every row reserves the same width, including an approximate endpoint.
    // Measure with the inherited font and scaler so large text never clips.
    final measure = TextPainter(
      text: TextSpan(
        text: '00:00',
        style: DefaultTextStyle.of(context).style.merge(timeStyle),
      ),
      textScaler: scaler,
      textDirection: Directionality.of(context),
    )..layout();
    final timeWidth = math.max(54.0, measure.width.ceilToDouble());
    measure.dispose();
    final range =
        '${_boundary(startedAt, startPrecision)} → '
        '${_boundary(endedAt, endPrecision)}';
    final heading = Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
      ),
    );
    final durationText = Text(
      key: const ValueKey('slice-duration'),
      _compactDuration(duration),
      textAlign: TextAlign.left,
      style: const TextStyle(fontSize: 14, height: 24 / 14),
    );
    return Semantics(
      label:
          '$title，$range，${formatDerivedDuration(duration)}，${isGap ? '补记' : '查看详情'}',
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('timeline-rail'),
                  painter: _TimelineRail(
                    x: timeWidth + 12,
                    color: color,
                    background: theme.scaffoldBackgroundColor,
                    isGap: isGap,
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: timeWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Tooltip(
                      key: const ValueKey('slice-range'),
                      message: range,
                      child: Semantics(
                        label: range,
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final boundary in [
                              (startedAt, startPrecision),
                              (endedAt, endPrecision),
                            ])
                              Text(
                                formatRecordingTime(boundary.$1)
                                    .split(' ')
                                    .last,
                                style: timeStyle,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colors.outlineVariant),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final durationMeasure = TextPainter(
                              text: TextSpan(
                                text: _compactDuration(duration),
                                style: DefaultTextStyle.of(context).style
                                    .merge(durationText.style),
                              ),
                              textDirection: Directionality.of(context),
                              textScaler: scaler,
                            )..layout();
                            final durationWidth = durationMeasure.width
                                .ceilToDouble();
                            durationMeasure.dispose();
                            if (isGap ||
                                constraints.maxWidth - durationWidth - 8 <
                                    scaler.scale(68)) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  heading,
                                  const SizedBox(height: 6),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [durationText, ...actions],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: heading),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: durationWidth,
                                  child: durationText,
                                ),
                              ],
                            );
                          },
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.5,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final detail in details)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: detail,
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (!isGap && actions.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(spacing: 4, children: actions),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The rail fills each row, including padding, so it stays joined as text wraps.
class _TimelineRail extends CustomPainter {
  const _TimelineRail({
    required this.x,
    required this.color,
    required this.background,
    required this.isGap,
  });
  final double x;
  final Color color;
  final Color background;
  final bool isGap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    if (isGap) {
      for (double y = 0; y < size.height; y += 10) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 5, size.height)),
          paint,
        );
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    canvas.drawCircle(Offset(x, 28), 8, Paint()..color = background);
    canvas.drawCircle(
      Offset(x, 28),
      6,
      paint..style = isGap ? PaintingStyle.stroke : PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TimelineRail oldDelegate) =>
      x != oldDelegate.x ||
      color != oldDelegate.color ||
      background != oldDelegate.background ||
      isGap != oldDelegate.isGap;
}
