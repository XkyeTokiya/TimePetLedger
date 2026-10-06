import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../domain/block_knowledge_state.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/projection/goal_rhythm_summary.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';
import '../../domain/rhythm_state.dart';
import '../../domain/sleep_type.dart';
import '../../domain/time_precision.dart';
import '../fact_detail_page.dart';
import '../day_read_scroll.dart';
import '../recording_form.dart' show formatRecordingTime;
import '../recording_rhythm_input.dart' show rhythmInputLabel;
import '../summary_formatting.dart';

/// Row duration follows the reference: "7 小时 20 分" when hours are present,
/// otherwise the domain wording ("40 分钟") is kept as-is.
String _rowDuration(DerivedDuration duration) {
  final text = formatDerivedDuration(duration);
  return text.contains('小时') ? text.replaceFirst('分钟', '分') : text;
}

/// Timeline tab of the rebuilt home.
///
/// Rendered directly from the committed projection ([DayLedgerView]); it does
/// not reuse the previous timeline widgets, which carried a horizontal time bar
/// and tag chips that the confirmed reference does not have.
class HomeTimelineTab extends StatelessWidget {
  const HomeTimelineTab({
    super.key,
    required this.view,
    required this.placeholder,
    this.scrollSession,
    this.active = true,
    this.onEditFact,
    this.onDeleteTimeBlock,
    this.onFillGap,
    this.bottomInset = 0,
  });

  /// The committed projection; null while a reload is in flight.
  final DayLedgerView? view;

  /// Shown only before the first successful load.
  final Widget placeholder;

  /// Shared read-position memory, so returning from an editor keeps the place.
  final DayReadScrollSession? scrollSession;
  final bool active;

  /// 打开编辑器修改这条记录；返回是否提交了正式变更，供详情页决定去留。
  final Future<bool> Function(CivilDate date, LedgerSegment segment)?
  onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate date, UnresolvedSpan gap)? onFillGap;

  /// Extra scroll room below the last row, so a floating card that overlays the
  /// bottom of the timeline never covers a record.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    if (view == null) {
      return DayReadScrollView(
        date: null,
        destination: 'timeline',
        ready: false,
        session: scrollSession,
        active: active,
        padding: const EdgeInsets.all(20),
        children: [placeholder],
      );
    }
    final goals = {for (final goal in view.goalSummaries) goal.goalId: goal};
    // The "today" window ends at "now"; only a true day boundary reads as 24:00.
    final dayEnd = DateTime(
      view.date.year,
      view.date.month,
      view.date.day + 1,
    ).millisecondsSinceEpoch;
    final onEditFact = this.onEditFact;
    final onFillGap = this.onFillGap;
    final rows = <({Object id, int order, Widget tile})>[
      for (final segment in view.segments)
        (
          id: segment.reference,
          order: segment.startedAt,
          tile: _FactRow(
            key: ValueKey(segment.reference),
            segment: segment,
            goal: segment is TimeBlockSegment
                ? goals[segment.source.goalId]
                : null,
            dayEndedAt: dayEnd,
            onEdit: onEditFact == null
                ? null
                : (segment) => onEditFact(view.date, segment),
            onDelete: onDeleteTimeBlock,
          ),
        ),
      for (final gap in view.unresolvedSpans)
        (
          id: (gap.startedAt, gap.endedAt),
          order: gap.startedAt,
          tile: _GapRow(
            key: ValueKey((gap.startedAt, gap.endedAt)),
            gap: gap,
            dayEndedAt: dayEnd,
            onFill: onFillGap == null ? null : () => onFillGap(view.date, gap),
          ),
        ),
    ]..sort((a, b) => a.order.compareTo(b.order));

    // Anchored, non-lazy rows: every record stays mounted and the shared read
    // position is restored after a refresh without re-deriving it from pixels.
    return DayReadScrollView(
      date: view.date,
      destination: 'timeline',
      ready: true,
      session: scrollSession,
      active: active,
      padding: EdgeInsets.only(top: 4, bottom: 24 + bottomInset),
      children: [
        for (final row in rows)
          ReadScrollAnchor(id: row.id, order: row.order, child: row.tile),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    super.key,
    required this.segment,
    required this.dayEndedAt,
    this.goal,
    this.onEdit,
    this.onDelete,
  });

  final LedgerSegment segment;
  final int dayEndedAt;
  final GoalSummary? goal;
  final Future<bool> Function(LedgerSegment segment)? onEdit;
  final ValueChanged<TimeBlockSegment>? onDelete;

  @override
  Widget build(BuildContext context) {
    final details = _details();
    final (title, railColor) = switch (segment) {
      TimeBlockSegment(:final source, :final annotation) => (
        source.knowledgeState == BlockKnowledgeState.unknown
            ? '想不起来'
            : source.title ?? '未命名记录',
        switch ((source.knowledgeState, annotation?.state)) {
          (BlockKnowledgeState.unknown, _) => HomePalette.unknown,
          (_, RhythmState.recovery) => HomePalette.recovery,
          (_, RhythmState.stuck) => HomePalette.accent,
          _ => HomePalette.activity,
        },
      ),
      SleepSessionSegment(:final source) => (
        source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
        HomePalette.sleep,
      ),
    };
    return _TimelineRow(
      startedAt: segment.startedAt,
      endedAt: segment.endedAt,
      dayEndedAt: dayEndedAt,
      duration: segment.duration,
      title: title,
      railColor: railColor,
      details: details,
      onTap: () => _open(context),
      semanticsLabel: '$title，${formatDerivedDuration(segment.duration)}，查看详情',
    );
  }

  /// An unknown fact has no activity to name: the row states the fact ("已交代")
  /// and nothing more. Any half-remembered text stays in the detail sheet under
  /// "原文字" — it is residue, not a title, so it must not read as one here.
  List<Widget> _details() {
    final details = <Widget>[];
    switch (segment) {
      case SleepSessionSegment(:final source):
        if (source.startedAt != segment.startedAt ||
            source.endedAt != segment.endedAt) {
          details.add(
            Text(
              '${formatRecordingTime(source.startedAt)} → '
              '${formatRecordingTime(source.endedAt)}',
            ),
          );
          details.add(
            Text(
              '完整时长 ${formatDerivedDuration(DerivedDuration(milliseconds: source.endedAt - source.startedAt, hasApproximation: source.startPrecision == TimePrecision.approximate || source.endPrecision == TimePrecision.approximate))}',
            ),
          );
        }
      case TimeBlockSegment(:final source, :final annotation):
        if (source.knowledgeState == BlockKnowledgeState.unknown) {
          details.add(const Text('已交代'));
        } else {
          final parts = <String>[
            if (goal != null) '${goal!.name}${goal!.isArchived ? '（已归档）' : ''}',
            if (annotation != null) rhythmInputLabel(annotation.state),
          ];
          if (parts.isNotEmpty) {
            details.add(Text(parts.join(' · ')));
          }
          if (annotation?.continuationHint case final hint?) {
            details.add(Text('接续点：$hint'));
          }
        }
    }
    return details;
  }

  Future<void> _open(BuildContext context) async {
    final seg = segment;
    final onEdit = this.onEdit;
    final action = await showFactDetail(
      context,
      segment: seg,
      goal: goal,
      canEdit: onEdit != null,
      canDelete: onDelete != null && seg is! SleepSessionSegment,
      // 编辑压栈在详情之上：取消 / 保留草稿回详情，提交后才离开详情。
      onEdit: onEdit == null ? null : () => onEdit(seg),
    );
    if (!context.mounted) return;
    switch (action) {
      case LedgerDetailAction.delete:
        if (seg is TimeBlockSegment) {
          onDelete?.call(seg);
        } else {
          onEdit?.call(seg);
        }
      case null:
      case LedgerDetailAction.edit:
        break;
    }
  }
}

/// An unrecorded stretch. The whole row is the target, so the action is a line
/// of text rather than a button — a button's minimum tap box is what made gap
/// rows twice the height of every other row.
class _GapRow extends StatelessWidget {
  const _GapRow({
    super.key,
    required this.gap,
    required this.dayEndedAt,
    this.onFill,
  });

  final UnresolvedSpan gap;
  final int dayEndedAt;
  final VoidCallback? onFill;

  @override
  Widget build(BuildContext context) => _TimelineRow(
    startedAt: gap.startedAt,
    endedAt: gap.endedAt,
    dayEndedAt: dayEndedAt,
    duration: gap.duration,
    title: '尚未记录',
    railColor: HomePalette.gap,
    isGap: true,
    onTap: onFill,
    semanticsLabel:
        '尚未记录，${formatDerivedDuration(gap.duration)}'
        '${onFill == null ? '' : '，补记'}',
    // Not a button: a button's 48px tap target is what made gap rows twice as
    // tall as the records around them. The whole row is already the tap target.
    details: [
      if (onFill != null)
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            '补记',
            style: TextStyle(
              fontFamily: homeSerifFamily,
              fontSize: 13,
              height: 1.5,
              color: HomePalette.accentDeep,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
              decorationColor: HomePalette.accentDeep,
            ),
          ),
        ),
    ],
  );
}

/// One timeline row: stacked boundary times, a rail with a node, then content.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.startedAt,
    required this.endedAt,
    required this.dayEndedAt,
    required this.duration,
    required this.title,
    required this.railColor,
    required this.semanticsLabel,
    this.isGap = false,
    this.details = const [],
    this.onTap,
  });

  final int startedAt;
  final int endedAt;
  final int dayEndedAt;
  final DerivedDuration duration;
  final String title;
  final Color railColor;
  final String semanticsLabel;
  final bool isGap;
  final List<Widget> details;
  final VoidCallback? onTap;

  /// Shared by the rail painter so line and node can never drift apart.
  static const railWidth = 22.0;
  static const railCenter = railWidth / 2;
  static const lineWidth = 1.5;
  static const nodeSize = 11.0;
  static const contentTopPadding = 14.0;
  static const titleLineHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 70,
                child: Padding(
                  // Centres the start time on the title's first line.
                  padding: const EdgeInsets.only(
                    top: contentTopPadding + (titleLineHeight - 19.5) / 2,
                    left: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _boundary(startedAt),
                        style: _timeStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      Text(
                        _boundary(endedAt),
                        style: _timeStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: railWidth,
                child: _Rail(color: railColor, isGap: isGap),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    contentTopPadding,
                    20,
                    contentTopPadding,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: HomePalette.hairline),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: homeSerifFamily,
                                fontSize: 17,
                                height: titleLineHeight / 17,
                                fontWeight: FontWeight.w600,
                                color: HomePalette.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _rowDuration(duration),
                            style: const TextStyle(
                              fontFamily: homeSerifFamily,
                              fontSize: 14,
                              height: titleLineHeight / 14,
                              color: HomePalette.muted,
                            ),
                          ),
                        ],
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontFamily: homeSerifFamily,
                            fontSize: 13,
                            height: 1.5,
                            color: HomePalette.muted,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (final detail in details) detail],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _boundary(int instant) => instant == dayEndedAt
      ? '24:00'
      : formatRecordingTime(instant).split(' ').last;
}

const _timeStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  height: 1.5,
  color: HomePalette.muted,
);

/// Vertical rail spanning the row, with a node on the title line. Line and node
/// are drawn by one painter at one x, so the dashed segment of a gap lines up
/// with the solid segments above and below it.
class _Rail extends StatelessWidget {
  const _Rail({required this.color, required this.isGap});

  final Color color;
  final bool isGap;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.infinite, painter: _RailPainter(color, isGap));
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.color, this.isGap);

  final Color color;
  final bool isGap;

  @override
  void paint(Canvas canvas, Size size) {
    const x = _TimelineRow.railCenter;
    const halfNode = _TimelineRow.nodeSize / 2;
    const nodeCenterY =
        _TimelineRow.contentTopPadding + _TimelineRow.titleLineHeight / 2;

    final line = Paint()
      ..color = isGap ? color : color.withValues(alpha: .55)
      ..strokeWidth = _TimelineRow.lineWidth;
    final nodeTop = nodeCenterY - halfNode;
    final nodeBottom = nodeCenterY + halfNode;

    if (isGap) {
      for (double y = 0; y < size.height; y += 8) {
        final end = math.min(y + 4, size.height);
        if (end <= nodeTop || y >= nodeBottom) {
          canvas.drawLine(Offset(x, y), Offset(x, end), line);
        }
      }
    } else {
      canvas.drawLine(Offset(x, 0), Offset(x, nodeTop), line);
      canvas.drawLine(Offset(x, nodeBottom), Offset(x, size.height), line);
    }

    canvas.drawCircle(
      Offset(x, nodeCenterY),
      halfNode,
      Paint()..color = isGap ? HomePalette.paper : color,
    );
    if (isGap) {
      canvas.drawCircle(
        Offset(x, nodeCenterY),
        halfNode - 1,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      color != oldDelegate.color || isGap != oldDelegate.isGap;
}
