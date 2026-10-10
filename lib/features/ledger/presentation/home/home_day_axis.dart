import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter/services.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../app/theme/semantic_colors.dart';
import '../../../../app/theme/theme_text.dart';
import '../../../../core/time/civil_date.dart';
import '../../domain/block_knowledge_state.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../../domain/projection/goal_rhythm_summary.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';
import '../../domain/sleep_type.dart';
import '../fact_detail_page.dart';
import '../summary_formatting.dart';
import 'home_ledger_style.dart';
import 'home_timeline_geometry.dart';

/// The visible band of the feed viewport in scroll-content coordinates. The
/// feed publishes it on every scroll update, so each axis places its one
/// visual label against the same frame that is about to be painted instead of
/// a previous frame's position.
final class HomeAxisViewport extends ChangeNotifier {
  double top = 0;
  double bottom = 0;
  void update(double nextTop, double nextBottom) {
    if (top == nextTop && bottom == nextBottom) return;
    top = nextTop;
    bottom = nextBottom;
    notifyListeners();
  }
}

class HomeDayAxis extends StatefulWidget {
  const HomeDayAxis({
    super.key,
    required this.view,
    required this.geometry,
    required this.viewport,
    required this.isToday,
    required this.isCurrent,
    this.onEditFact,
    this.onEditUnderstanding,
    this.onDeleteTimeBlock,
    this.onFillGap,
  });
  final DayLedgerView view;
  final HomeTimelineGeometry geometry;
  final HomeAxisViewport viewport;
  final bool isToday;
  final bool Function() isCurrent;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditFact;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditUnderstanding;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate, UnresolvedSpan)? onFillGap;

  @override
  State<HomeDayAxis> createState() => _HomeDayAxisState();
}

class _HomeDayAxisState extends State<HomeDayAxis> {
  final _axisKey = GlobalKey();
  final _focus = <Object, FocusNode>{};
  Object? _hovered;
  Object? _focused;
  Widget? _cachedAxis;
  _AxisMetrics? _metrics;

  @override
  void didUpdateWidget(HomeDayAxis oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.view, oldWidget.view) ||
        widget.geometry.startedAt != oldWidget.geometry.startedAt ||
        widget.geometry.a11yFactor != oldWidget.geometry.a11yFactor ||
        widget.isToday != oldWidget.isToday) {
      _cachedAxis = null;
      _metrics = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedAxis = null;
    _metrics = null;
  }

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _node(Object id) => _focus.putIfAbsent(id, FocusNode.new);

  /// The published scroll band converted to this axis's local coordinates.
  /// Offsets inside the scroll content are stable while the finger moves, so
  /// the conversion stays exact for the frame currently being built.
  ({double top, double bottom}) _visibleBand() {
    final box = _axisKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      final contentTop = _contentOffset(box);
      if (contentTop != null) {
        return (
          top: widget.viewport.top - contentTop,
          bottom: widget.viewport.bottom - contentTop,
        );
      }
      // No scroll viewport ancestor: the published band already is global.
      final top = box.localToGlobal(Offset.zero).dy;
      return (
        top: widget.viewport.top - top,
        bottom: widget.viewport.bottom - top,
      );
    }
    return (top: widget.viewport.top, bottom: widget.viewport.bottom);
  }

  /// Distance from the scroll content's origin to this axis. Measured against
  /// the viewport's direct child so the scrolling paint offset is excluded.
  double? _contentOffset(RenderBox box) {
    RenderObject content = box;
    RenderObject? parent = content.parent;
    while (parent != null && parent is! RenderAbstractViewport) {
      content = parent;
      parent = content.parent;
    }
    if (parent is! RenderAbstractViewport) return null;
    return box.localToGlobal(Offset.zero, ancestor: content).dy;
  }

  TimelineInterval? _currentCandidate(TimelineInterval candidate) {
    if (!mounted || !widget.isCurrent()) return null;
    return TimelineInterval.fromView(widget.view)
        .where(
          (item) =>
              item.id == candidate.id &&
              item.startedAt == candidate.startedAt &&
              item.endedAt == candidate.endedAt,
        )
        .firstOrNull;
  }

  Future<void> _open(TimelineInterval candidate) async {
    final item = _currentCandidate(candidate);
    if (item == null) return;
    if (item.gap case final gap?) {
      widget.onFillGap?.call(widget.view.date, gap);
      return;
    }
    final fact = item.fact!;
    final goal = fact is TimeBlockSegment
        ? widget.view.goalSummaries
              .where((g) => g.goalId == fact.source.goalId)
              .firstOrNull
        : null;
    final action = await showFactDetail(
      context,
      segment: fact,
      goal: goal,
      canEdit: widget.onEditFact != null,
      canDelete: widget.onDeleteTimeBlock != null && fact is TimeBlockSegment,
      onEdit: widget.onEditFact == null
          ? null
          : () => widget.onEditFact!(widget.view.date, fact),
      onEditUnderstanding:
          widget.onEditUnderstanding == null || fact is! TimeBlockSegment
          ? null
          : () => widget.onEditUnderstanding!(widget.view.date, fact),
    );
    if (!mounted) return;
    if (action == LedgerDetailAction.delete && fact is TimeBlockSegment) {
      widget.onDeleteTimeBlock?.call(fact);
    }
  }

  Future<void> _activate(
    TimelineInterval item,
    List<TimelineInterval>? cluster,
  ) async {
    if (!widget.isCurrent()) return;
    final origin = _node(item.id);
    if (cluster == null || cluster.length == 1) {
      await _open(item);
    } else {
      final chosen = await showModalBottomSheet<TimelineInterval>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .5,
          minChildSize: .25,
          maxChildSize: .85,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '时段选择',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              for (final candidate in cluster)
                ListTile(
                  key: ValueKey(('time-choice', candidate.id)),
                  minTileHeight: 48,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: Icon(
                    _icon(candidate),
                    color: _color(
                      candidate,
                      context.semanticColors,
                      Theme.of(context).colorScheme,
                    ),
                  ),
                  title: Text(
                    '${_range(candidate, widget.view)} · ${_title(candidate)}',
                  ),
                  subtitle: Text(
                    '${_type(candidate)} · ${formatDerivedDuration(candidate.duration)}',
                  ),
                  onTap: () => Navigator.pop(context, candidate),
                ),
            ],
          ),
        ),
      );
      if (chosen != null && mounted) await _open(chosen);
    }
    if (!mounted) return;
    if (_currentCandidate(item) != null && origin.context != null) {
      origin.requestFocus();
    } else {
      final first = TimelineInterval.fromView(widget.view).firstOrNull;
      if (first != null) _node(first.id).requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final colors = Theme.of(context).colorScheme;
    final semantics = context.semanticColors;
    final tickStyle = withThemeFont(
      context,
      HomeLedgerStyle.tick.copyWith(color: colors.onSurfaceVariant),
    );
    final geometry = widget.geometry;
    if (view.window.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Text(
          '这一天还没有已发生的时间。',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      );
    }
    final metrics = _metrics ??= _measure(context, view, tickStyle);
    final intervals = metrics.intervals;
    final clusters = metrics.clusters;
    final clusterFor = metrics.clusterFor;
    final height = metrics.height;
    final labelRight = metrics.labelRight;
    final railX = metrics.railX;
    final cardLeft = metrics.cardLeft;
    final tickHeight = metrics.tickHeight;
    final tickLabels = metrics.tickLabels;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: AnimatedBuilder(
        animation: widget.viewport,
        builder: (context, _) {
          final visible = _visibleBand();
          final visibleTop = visible.top;
          final visibleBottom = visible.bottom;
          // Offscreen days keep their individual focus/semantics nodes, but
          // need no label repositioning while another day is being read.
          if (_cachedAxis != null &&
              (visibleBottom <= 0 || visibleTop >= height + 32)) {
            return _cachedAxis!;
          }
          return _cachedAxis = RepaintBoundary(
            child: SizedBox(
              key: _axisKey,
              height: height + 32,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _AxisPainter(
                          geometry: geometry,
                          intervals: intervals,
                          railX: railX,
                          windowEnd: view.window.endedAt,
                          scheme: colors,
                          semantics: semantics,
                        ),
                      ),
                    ),
                  ),
                  for (final (label, top) in tickLabels)
                    // Edge labels disappear as a whole instead of leaving a
                    // clipped half-word under the fixed header / footer.
                    if (top >= visibleTop && top + tickHeight <= visibleBottom)
                      Positioned(
                        top: top,
                        left: 0,
                        width: labelRight,
                        child: ExcludeSemantics(
                          child: Text(
                            label,
                            textAlign: TextAlign.right,
                            style: tickStyle,
                          ),
                        ),
                      ),
                  for (final item in intervals)
                    Positioned(
                      key: ValueKey(('interval-position', view.date, item.id)),
                      top: geometry.y(item.startedAt),
                      height: geometry.height(item.startedAt, item.endedAt),
                      left: cardLeft,
                      right: 0,
                      child: _interval(
                        context,
                        item,
                        clusterFor[item.id],
                        visibleTop,
                        visibleBottom,
                      ),
                    ),
                  for (final cluster in clusters)
                    if (cluster.length >= 2)
                      Positioned(
                        top: geometry.y(cluster.first.startedAt),
                        left: railX + 4,
                        width: 16,
                        height: math.max(
                          geometry.height(
                            cluster.first.startedAt,
                            cluster.last.endedAt,
                          ),
                          24,
                        ),
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  '选择',
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  Positioned(
                    top: height,
                    left: 0,
                    right: 0,
                    height: 32,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          SizedBox(
                            width: labelRight,
                            child: Text(
                              widget.isToday
                                  ? _clock(view.window.endedAt)
                                  : '24:00',
                              textAlign: TextAlign.right,
                              style: tickStyle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Divider(color: colors.primary, height: 1),
                          ),
                          if (widget.isToday)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '现在',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 与可见窗口无关的轴度量：只在数据 / 几何 / 主题字体变化时重算。
  /// 尺寸变化（如顶部收起）只重建可见日的标签层，不重跑这些计算。
  _AxisMetrics _measure(
    BuildContext context,
    DayLedgerView view,
    TextStyle tickStyle,
  ) {
    final geometry = widget.geometry;
    final intervals = TimelineInterval.fromView(view);
    final clusters = geometry.shortClusters(intervals);
    final clusterFor = <Object, List<TimelineInterval>>{
      for (final cluster in clusters)
        if (cluster.length >= 2)
          for (final item in cluster) item.id: cluster,
    };
    final scale = MediaQuery.textScalerOf(context);
    final ticks = _ticks(view).toList();
    var tickWidth = 0.0;
    for (final tick in ticks) {
      final measure = TextPainter(
        text: TextSpan(text: tick.$2, style: tickStyle),
        textDirection: Directionality.of(context),
        textScaler: scale,
      )..layout();
      tickWidth = math.max(tickWidth, measure.width);
      measure.dispose();
    }
    final labelRight = math.max(40.0, (tickWidth / 4).ceil() * 4.0 + 4);
    // Label → 8dp → 4dp tick → 8dp → rail → 24dp → card.
    final railX = labelRight + TimeLedgerSpacing.xs * 2 + 4;
    final cardLeft = railX + TimeLedgerSpacing.xl;
    final tickHeight = scale.scale(HomeLedgerStyle.tick.fontSize!);
    return _AxisMetrics(
      intervals: intervals,
      clusters: clusters,
      clusterFor: clusterFor,
      height: geometry.y(view.window.endedAt),
      labelRight: labelRight,
      railX: railX,
      cardLeft: cardLeft,
      tickHeight: tickHeight,
      tickLabels: [
        for (final tick in ticks)
          (tick.$2, math.max(0.0, geometry.y(tick.$1) - tickHeight / 2)),
      ],
    );
  }

  Widget _interval(
    BuildContext context,
    TimelineInterval item,
    List<TimelineInterval>? cluster,
    double visibleTop,
    double visibleBottom,
  ) {
    final geometry = widget.geometry;
    final height = geometry.height(item.startedAt, item.endedAt);
    final title = _title(item);
    final color = _color(
      item,
      context.semanticColors,
      Theme.of(context).colorScheme,
    );
    final action = cluster != null
        ? '打开时段选择'
        : item.gap != null
        ? '补记'
        : '查看详情';
    final selected = _hovered == item.id || _focused == item.id;
    final semantics =
        '${_range(item, widget.view)}，${_type(item)}，$title，${formatDerivedDuration(item.duration)}，$action';
    return Semantics(
      key: ValueKey(('timeline-semantics', widget.view.date, item.id)),
      label: semantics,
      button: true,
      onTap: () => _activate(item, cluster),
      child: Focus(
        focusNode: _node(item.id),
        includeSemantics: false,
        onFocusChange: (value) {
          _cachedAxis = null;
          setState(
            () => _focused = value
                ? item.id
                : _focused == item.id
                ? null
                : _focused,
          );
          if (value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_node(item.id).hasFocus) return;
              final target = _node(item.id).context;
              final box = target?.findRenderObject();
              if (box is RenderBox && box.hasSize) {
                final top = box.localToGlobal(Offset.zero).dy;
                if (top >= widget.viewport.bottom ||
                    top + box.size.height <= widget.viewport.top) {
                  Scrollable.ensureVisible(
                    target!,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                  );
                }
              }
            });
          }
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _activate(item, cluster);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() {
            _cachedAxis = null;
            _hovered = item.id;
          }),
          onExit: (_) => setState(() {
            _cachedAxis = null;
            _hovered = null;
          }),
          child: ExcludeSemantics(
            child: InkWell(
              key: ValueKey(item.id),
              canRequestFocus: false,
              onTap: () => _activate(item, cluster),
              child: ClipRect(
                child: CustomPaint(
                  painter: _IntervalPainter(
                    color: color,
                    gap: item.gap != null,
                    selected: selected,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = MediaQuery.textScalerOf(context);
                      final mutedStyle = HomeLedgerStyle.metadata.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      );
                      final lineHeight =
                          scale.scale(HomeLedgerStyle.state.fontSize!) *
                          HomeLedgerStyle.state.height!;
                      if (height < HomeTimelineGeometry.textHeight ||
                          height < lineHeight) {
                        return const SizedBox.expand();
                      }
                      final top = geometry.y(item.startedAt);
                      final visibleHeight =
                          (math.min(height, visibleBottom - top) -
                                  math.max(0.0, visibleTop - top))
                              .clamp(0.0, height);
                      // Do not paint a half-clipped word at a viewport edge.
                      // The interval's full semantics/focus remain above.
                      if (visibleHeight > 0 && visibleHeight < lineHeight) {
                        return const SizedBox.expand();
                      }
                      final showIcon =
                          constraints.maxWidth > 160 &&
                          scale.scale(HomeLedgerStyle.title.fontSize!) < 24;
                      final metadataHeight =
                          scale.scale(HomeLedgerStyle.metadata.fontSize!) *
                          HomeLedgerStyle.metadata.height!;
                      final titleHeight = math.max(
                        showIcon ? HomeLedgerStyle.iconSize : 0,
                        scale.scale(HomeLedgerStyle.title.fontSize!) *
                            HomeLedgerStyle.title.height!,
                      );
                      final fullHeight = metadataHeight * 2 + titleHeight + 8;
                      // Label form is a property of the interval: it must
                      // not switch between heights while the feed scrolls,
                      // or the same block visibly changes text, size and
                      // line count every time it crosses a viewport edge.
                      final full = height >= fullHeight + 16;
                      final compactRange =
                          !full && height >= metadataHeight + lineHeight + 20;
                      final labelHeight = full
                          ? fullHeight
                          : compactRange
                          ? metadataHeight + 4 + lineHeight
                          : lineHeight;
                      // One label, clamped to both real boundaries and the
                      // viewport intersection. It never changes the target.
                      final offset = full || compactRange
                          ? (math.max(0.0, visibleTop - top) + 8).clamp(
                              8.0,
                              math.max(8.0, height - labelHeight - 8),
                            )
                          : (visibleHeight == 0
                                    ? (height - labelHeight) / 2
                                    : math.max(0.0, visibleTop - top) +
                                          (visibleHeight - labelHeight) / 2)
                                .clamp(
                                  0.0,
                                  math.max(0.0, height - labelHeight),
                                );
                      final goal = item.fact is TimeBlockSegment
                          ? widget.view.goalSummaries
                                .where(
                                  (g) =>
                                      g.goalId ==
                                      (item.fact as TimeBlockSegment)
                                          .source
                                          .goalId,
                                )
                                .firstOrNull
                          : null;
                      return Stack(
                        children: [
                          Positioned(
                            top: offset.toDouble(),
                            left: 8,
                            right: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (full || compactRange)
                                  Text(
                                    _range(item, widget.view),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mutedStyle,
                                  ),
                                if (full || compactRange)
                                  const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (full && showIcon) ...[
                                      Icon(
                                        _icon(item),
                                        color: color,
                                        size: HomeLedgerStyle.iconSize,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: full
                                            ? HomeLedgerStyle.title
                                            : HomeLedgerStyle.state,
                                      ),
                                    ),
                                    if (!full &&
                                        constraints.maxWidth > scale.scale(150))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          formatDerivedDuration(item.duration),
                                          style: mutedStyle,
                                        ),
                                      ),
                                  ],
                                ),
                                if (full) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    selected
                                        ? action
                                        : '${formatDerivedDuration(item.duration)}${_secondary(item, goal)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mutedStyle,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected &&
                              !full &&
                              compactRange &&
                              height >= labelHeight + 32)
                            Positioned(
                              bottom: 0,
                              left: 8,
                              right: 8,
                              child: Text(
                                action,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _title(TimelineInterval item) => switch (item.fact) {
  TimeBlockSegment(:final source) =>
    source.knowledgeState == BlockKnowledgeState.unknown
        ? '想不起来'
        : source.title ?? '未命名记录',
  SleepSessionSegment(:final source) =>
    source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
  null => '尚未记录',
};
String _type(TimelineInterval item) => switch (item.fact) {
  TimeBlockSegment(:final source) =>
    source.knowledgeState == BlockKnowledgeState.unknown ? '已交代' : '活动',
  SleepSessionSegment() => '睡眠',
  null => '未记录时段',
};
Color _color(
  TimelineInterval item,
  TimeLedgerSemanticColors semantics,
  ColorScheme colors,
) => switch (item.fact) {
  TimeBlockSegment(:final source) =>
    source.knowledgeState == BlockKnowledgeState.unknown
        ? semantics.unknown
        : semantics.activity,
  SleepSessionSegment() => semantics.sleep,
  null => semantics.gap,
};
IconData _icon(TimelineInterval item) => switch (item.fact) {
  TimeBlockSegment(:final source) =>
    source.knowledgeState == BlockKnowledgeState.unknown
        ? Icons.help_outline
        : Icons.edit_outlined,
  SleepSessionSegment() => Icons.bed_outlined,
  null => Icons.radio_button_unchecked,
};
String _secondary(TimelineInterval item, GoalSummary? goal) {
  if (item.fact case TimeBlockSegment(:final source)) {
    if (source.knowledgeState == BlockKnowledgeState.unknown) return ' · 已交代';
    if (goal != null) return ' · ${goal.name}${goal.isArchived ? '（已归档）' : ''}';
  }
  if (item.fact case SleepSessionSegment(:final source)) {
    if (source.startedAt != item.startedAt || source.endedAt != item.endedAt) {
      return ' · 跨日切片';
    }
  }
  return '';
}

String _clock(int instant) {
  final t = DateTime.fromMillisecondsSinceEpoch(instant);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String _range(TimelineInterval item, DayLedgerView view) {
  final end = DateTime(
    view.date.year,
    view.date.month,
    view.date.day + 1,
  ).millisecondsSinceEpoch;
  return '${_clock(item.startedAt)} – ${item.endedAt == end ? '24:00' : _clock(item.endedAt)}';
}

List<(int, String)> _ticks(DayLedgerView view) {
  final instants = <int>[];
  for (var t = view.window.startedAt; t < view.window.endedAt; t += 3600000) {
    instants.add(t);
  }
  final count = <String, int>{};
  for (final t in instants) {
    count.update(_clock(t), (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    for (final t in instants)
      (
        t,
        count[_clock(t)]! > 1
            ? '${_clock(t)} ${DateTime.fromMillisecondsSinceEpoch(t).timeZoneName}'
            : _clock(t),
      ),
  ];
}

class _IntervalPainter extends CustomPainter {
  const _IntervalPainter({
    required this.color,
    required this.gap,
    required this.selected,
  });
  final Color color;
  final bool gap;
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    // The top edge is exactly y(start); only the bottom has an internal seam.
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height - math.min(1.0, size.height / 4),
    );
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
      rounded,
      Paint()..color = color.withValues(alpha: gap ? .015 : .09),
    );
    if (gap) {
      final inset = math.min(.5, math.min(rect.width, rect.height) / 2);
      final path = Path()..addRRect(rounded.deflate(inset));
      final paint = Paint()
        ..color = color.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final metric in path.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 9) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 5, metric.length)),
            paint,
          );
        }
      }
    } else {
      canvas.save();
      canvas.clipRRect(rounded);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 3, size.height),
        Paint()..color = color.withValues(alpha: .45),
      );
      canvas.restore();
    }
    if (selected) {
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_IntervalPainter old) =>
      color != old.color || gap != old.gap || selected != old.selected;
}

class _AxisPainter extends CustomPainter {
  const _AxisPainter({
    required this.geometry,
    required this.intervals,
    required this.railX,
    required this.windowEnd,
    required this.scheme,
    required this.semantics,
  });
  final HomeTimelineGeometry geometry;
  final List<TimelineInterval> intervals;
  final double railX;
  final int windowEnd;
  final ColorScheme scheme;
  final TimeLedgerSemanticColors semantics;
  @override
  void paint(Canvas canvas, Size size) {
    for (var t = geometry.startedAt; t < windowEnd; t += 3600000) {
      final y = geometry.y(t);
      canvas.drawLine(
        Offset(railX - 12, y),
        Offset(railX - 8, y),
        Paint()
          ..color = scheme.outline
          ..strokeWidth = 1,
      );
    }
    for (final item in intervals) {
      final y = geometry.y(item.startedAt);
      final end = geometry.y(item.endedAt);
      final color = _color(item, semantics, scheme);
      final paint = Paint()
        ..color = color.withValues(alpha: .65)
        ..strokeWidth = 1.5;
      if (item.gap != null) {
        for (var d = y; d < end; d += 8) {
          canvas.drawLine(
            Offset(railX, d),
            Offset(railX, math.min(d + 4, end)),
            paint,
          );
        }
      } else {
        canvas.drawLine(Offset(railX, y), Offset(railX, end), paint);
      }
      if (item.fact case TimeBlockSegment(:final source)
          when source.knowledgeState == BlockKnowledgeState.unknown) {
        // A diamond remains distinguishable even when no text fits.
        final path = Path()
          ..moveTo(railX, y - 4)
          ..lineTo(railX + 4, y)
          ..lineTo(railX, y + 4)
          ..lineTo(railX - 4, y)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      } else {
        canvas.drawCircle(
          Offset(railX, y),
          4,
          Paint()..color = item.gap != null ? scheme.surface : color,
        );
        if (item.gap != null) {
          canvas.drawCircle(
            Offset(railX, y),
            4,
            paint..style = PaintingStyle.stroke,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      geometry != old.geometry ||
      intervals != old.intervals ||
      railX != old.railX ||
      windowEnd != old.windowEnd ||
      scheme != old.scheme ||
      semantics != old.semantics;
}

/// 单日轴的静态度量（与可见窗口无关），按数据 / 几何 / 主题失效。
class _AxisMetrics {
  const _AxisMetrics({
    required this.intervals,
    required this.clusters,
    required this.clusterFor,
    required this.height,
    required this.labelRight,
    required this.railX,
    required this.cardLeft,
    required this.tickHeight,
    required this.tickLabels,
  });

  final List<TimelineInterval> intervals;
  final List<List<TimelineInterval>> clusters;
  final Map<Object, List<TimelineInterval>> clusterFor;
  final double height;
  final double labelRight;
  final double railX;
  final double cardLeft;
  final double tickHeight;
  final List<(String, double)> tickLabels;
}
