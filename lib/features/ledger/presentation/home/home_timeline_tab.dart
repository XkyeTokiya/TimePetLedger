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
import '../day_ledger_date_dialog.dart' show adjacentLedgerDate;
import '../day_read_scroll.dart';
import '../fact_detail_page.dart';
import '../recording_form.dart' show formatRecordingTime;
import '../recording_rhythm_input.dart' show rhythmInputLabel;
import '../summary_formatting.dart';
import 'ledger_feed_controller.dart';

/// Row duration follows the reference: "7 小时 20 分" when hours are present,
/// otherwise the domain wording ("40 分钟") is kept as-is.
String _rowDuration(DerivedDuration duration) {
  final text = formatDerivedDuration(duration);
  return text.contains('小时') ? text.replaceFirst('分钟', '分') : text;
}

String ledgerDayText(CivilDate date) => '${date.month}月${date.day}日';

String ledgerWeekdayText(CivilDate date, CivilDate today) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final index = DateTime.utc(date.year, date.month, date.day).weekday - 1;
  final weekday = index >= 0 && index < names.length ? names[index] : '所选日期';
  if (date == today) return '$weekday · 今天';
  if (date == adjacentLedgerDate(today, -1)) return '$weekday · 昨天';
  return weekday;
}

/// 首页跨日期连续时间轴。
///
/// 每天仍直接读取该日已提交的 [DayLedgerView]：不在午夜拆分事实、不重复
/// 统计；跨日事实在两天各显示自己的切片，点击仍打开同一完整事实。
/// 日期分隔置于每一天之前，滚动时吸顶显示当前浏览日期。
class HomeTimelineTab extends StatefulWidget {
  const HomeTimelineTab({
    super.key,
    required this.controller,
    required this.frame,
    required this.today,
    this.onPositioned,
    this.active = true,
    this.onEditFact,
    this.onDeleteTimeBlock,
    this.onFillGap,
    this.onDayTap,
    this.bottomInset = 0,
  });

  final LedgerFeedController controller;
  final LedgerFeedFrame frame;
  final VoidCallback? onPositioned;
  final CivilDate today;

  /// 首页是当前阅读面时才记录阅读位置；压在编辑器 / 浮层下时为 false。
  final bool active;

  /// 打开编辑器修改这条记录；返回是否提交了正式变更，供详情页决定去留。
  final Future<bool> Function(CivilDate date, LedgerSegment segment)?
  onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate date, UnresolvedSpan gap)? onFillGap;

  /// 点击日期分隔打开该日日历。
  final void Function(CivilDate date)? onDayTap;

  /// Extra scroll room below the last row, so a floating card that overlays the
  /// bottom of the timeline never covers a record.
  final double bottomInset;

  @override
  State<HomeTimelineTab> createState() => HomeTimelineTabState();
}

/// 日期分隔锚点：让滚动、吸顶提示与阅读位置都指向同一个自然日。
final class DayAnchor {
  const DayAnchor(this.date);
  final CivilDate date;

  @override
  bool operator ==(Object other) => other is DayAnchor && other.date == date;

  @override
  int get hashCode => date.hashCode;
}

/// 当前阅读位置：锚点身份 + 相对滚动区顶部的偏移。
final class _FeedPosition {
  const _FeedPosition(this.id, this.order, this.top, this.pixels);
  final Object? id;
  final int? order;
  final double top;
  final double pixels;
}

class HomeTimelineTabState extends State<HomeTimelineTab> {
  static const horizontalPadding = 20.0;
  static const compactPadding = 16.0;

  final _scroll = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  final _lastDayKey = GlobalKey();
  _FeedPosition? _lastVisible;
  CivilDate? _visibleDay;
  bool _sticky = false;
  bool _restoring = false;
  int _restoredVersion = -1;
  bool _layoutQueued = false;
  bool _positioned = false;
  CivilDate? _pendingReveal;
  bool _extendRequested = false;
  Size? _layoutSize;
  double _bottomFill = 0;

  double get _padding => MediaQuery.sizeOf(context).width < 370
      ? compactPadding
      : horizontalPadding;

  bool get _current =>
      widget.frame.version == widget.controller.dataVersion &&
      widget.frame.endDate == widget.controller.endDate;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _acceptFrame();
  }

  @override
  void didUpdateWidget(HomeTimelineTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.frame.version != _restoredVersion) {
      _acceptFrame();
    } else if (widget.active && !oldWidget.active) {
      _requestLayout(restore: true);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _acceptFrame() {
    _restoredVersion = widget.frame.version;
    if (!_current || widget.frame.status != LedgerFeedStatus.ready) return;
    _pendingReveal = widget.controller.takeRevealRequest();
    if (_pendingReveal != null) _visibleDay = _pendingReveal;
    _requestLayout(restore: true);
  }

  /// 一次布局只安排一次校正；显式定位优先，普通刷新才恢复旧阅读锚点。
  void _requestLayout({bool restore = false}) {
    if (restore) _restoring = true;
    if (_layoutQueued) return;
    _layoutQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutQueued = false;
      if (!mounted || !_current || !_scroll.hasClients) return;
      if (!widget.active) {
        _restoring = false;
        return;
      }
      if (_syncBottomFill()) {
        _requestLayout();
        return;
      }
      var moved = false;
      if (_pendingReveal case final date?) {
        final entry = _dayEntries()
            .where((item) => item.$1 == date)
            .firstOrNull;
        if (entry != null) moved = _jumpTo(_scroll.offset + entry.$2);
      } else if (_restoring) {
        moved = _restorePosition();
      }
      if (moved) {
        // jumpTo后的锚点坐标要等下一次布局，不能用旧坐标反写顶部焦点。
        _requestLayout();
        return;
      }
      _pendingReveal = null;
      _restoring = false;
      final firstPosition = !_positioned;
      if (firstPosition) setState(() => _positioned = true);
      _lastVisible = _capture();
      _syncVisibleDay();
      widget.onPositioned?.call();
      _extendWhenAtStart();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  double _viewportTop() {
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox) return 0;
    return viewport.localToGlobal(Offset.zero).dy;
  }

  bool _jumpTo(double target) {
    if (!_scroll.hasClients) return false;
    final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((clamped - _scroll.offset).abs() < .5) return false;
    _scroll.jumpTo(clamped);
    return true;
  }

  /// 全部锚点，按构建顺序（即时间顺序）。
  List<({Object id, int order, RenderBox box})> _anchors() {
    final result = <({Object id, int order, RenderBox box})>[];
    void visit(Element element) {
      if (element.widget case final ReadScrollAnchor anchor) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          result.add((id: anchor.id, order: anchor.order, box: render));
        }
      }
      element.visitChildren(visit);
    }

    _viewport.currentContext?.visitChildElements(visit);
    return result;
  }

  List<(CivilDate, double)> _dayEntries() {
    final viewportTop = _viewportTop();
    return [
      for (final anchor in _anchors())
        if (anchor.id case final DayAnchor day)
          (day.date, anchor.box.localToGlobal(Offset.zero).dy - viewportTop),
    ];
  }

  _FeedPosition? _capture() {
    if (!_scroll.hasClients) return null;
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final item in _anchors()) {
      final y = item.box.localToGlobal(Offset.zero).dy - top;
      if (y + item.box.size.height > 0 && y < viewport.size.height) {
        return _FeedPosition(item.id, item.order, y, _scroll.offset);
      }
    }
    return _FeedPosition(null, null, 0, _scroll.offset);
  }

  void _onScroll() {
    if (!mounted || !_current || _restoring || !_positioned || !widget.active) {
      return;
    }
    _requestLayout();
  }

  /// 顶部日期提示与当前浏览日期保持一致：取滚动区顶部所属的自然日。
  void _syncVisibleDay() {
    if (!_current ||
        _restoring ||
        !_positioned ||
        !widget.active ||
        !_scroll.hasClients) {
      return;
    }
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    CivilDate? active;
    var dividerAboveTop = false;
    for (final anchor in _anchors()) {
      if (anchor.id case final DayAnchor day) {
        final y = anchor.box.localToGlobal(Offset.zero).dy - top;
        if (y <= 1) {
          active = day.date;
          dividerAboveTop = y < -1;
        } else if (active == null) {
          active = day.date;
          dividerAboveTop = false;
          break;
        }
      }
    }
    if (active == null) return;
    if (active != _visibleDay || dividerAboveTop != _sticky) {
      setState(() {
        _visibleDay = active;
        _sticky = dividerAboveTop;
      });
    }
    widget.controller.noteFocus(active);
  }

  /// 读到窗口最早一天仍继续向上时，向前装载更早的自然日。
  void _extendWhenAtStart() {
    if (!_current || _restoring || !widget.active || !_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels > 0.5) {
      _extendRequested = false;
      return;
    }
    if (_extendRequested) return;
    _extendRequested = true;
    widget.controller.extendEarlier();
  }

  bool _restorePosition() {
    final saved = _lastVisible;
    if (saved == null) return false;
    final anchors = _anchors();
    final exact = anchors.where((item) => item.id == saved.id).firstOrNull;
    ({Object id, int order, RenderBox box})? target = exact;
    if (target == null && anchors.isNotEmpty && saved.order != null) {
      final sorted = [...anchors]
        ..sort(
          (a, b) => (a.order - saved.order!).abs().compareTo(
            (b.order - saved.order!).abs(),
          ),
        );
      target = sorted.first;
    }
    if (target != null) {
      final delta =
          target.box.localToGlobal(Offset.zero).dy - _viewportTop() - saved.top;
      return _jumpTo(_scroll.offset + delta);
    }
    return false;
  }

  /// 末尾留白：让最后一天的日期分隔也能滚到阅读区顶部（与显式跳转一致）。
  bool _syncBottomFill() {
    if (!mounted || !_scroll.hasClients) return false;
    final box = _lastDayKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final viewport = _scroll.position.viewportDimension;
    final needed = (viewport - box.size.height).clamp(0.0, 4000.0);
    if ((needed - _bottomFill).abs() > 1) {
      setState(() => _bottomFill = needed);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final frame = widget.frame;
    if (frame.status == LedgerFeedStatus.idle ||
        frame.status == LedgerFeedStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (frame.status == LedgerFeedStatus.failed) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('账本读取失败。'),
            TextButton(
              onPressed: controller.refresh,
              child: const Text('重试读取'),
            ),
          ],
        ),
      );
    }
    final dates = frame.dates;
    final day = _visibleDay ?? frame.focusDate;
    return Visibility(
      visible: _positioned,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              if (_layoutSize != null &&
                  _layoutSize != size &&
                  _current &&
                  widget.active &&
                  !_restoring) {
                _requestLayout(restore: true);
              }
              _layoutSize = size;
              return SingleChildScrollView(
                key: _viewport,
                controller: _scroll,
                padding: EdgeInsets.only(
                  bottom: 24 + widget.bottomInset + _bottomFill,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final date in dates)
                      _DayBlock(
                        key: date == dates.last
                            ? _lastDayKey
                            : ValueKey(date.hashCode),
                        date: date,
                        today: widget.today,
                        view: frame.viewFor(date),
                        padding: _padding,
                        onDayTap: widget.onDayTap,
                        onEditFact: widget.onEditFact,
                        onDeleteTimeBlock: widget.onDeleteTimeBlock,
                        onFillGap: widget.onFillGap,
                      ),
                  ],
                ),
              );
            },
          ),
          if (_sticky)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _StickyDayBar(
                key: const ValueKey('home-sticky-day'),
                date: day,
                today: widget.today,
                onTap: widget.onDayTap == null
                    ? null
                    : () => widget.onDayTap!(day),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一天：日期分隔 + 已排序的事实 / 缺口行。
class _DayBlock extends StatelessWidget {
  const _DayBlock({
    super.key,
    required this.date,
    required this.today,
    required this.view,
    required this.padding,
    this.onDayTap,
    this.onEditFact,
    this.onDeleteTimeBlock,
    this.onFillGap,
  });

  final CivilDate date;
  final CivilDate today;
  final DayLedgerView? view;
  final double padding;
  final void Function(CivilDate date)? onDayTap;
  final Future<bool> Function(CivilDate date, LedgerSegment segment)?
  onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate date, UnresolvedSpan gap)? onFillGap;

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    final rows = <({Object id, int order, Widget tile})>[];
    if (view != null) {
      final goals = {for (final goal in view.goalSummaries) goal.goalId: goal};
      // The "today" window ends at "now"; only a true day boundary reads 24:00.
      final dayEnd = DateTime(
        view.date.year,
        view.date.month,
        view.date.day + 1,
      ).millisecondsSinceEpoch;
      final onEditFact = this.onEditFact;
      final onFillGap = this.onFillGap;
      for (final segment in view.segments) {
        rows.add((
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
        ));
      }
      for (final gap in view.unresolvedSpans) {
        rows.add((
          id: (gap.startedAt, gap.endedAt),
          order: gap.startedAt,
          tile: _GapRow(
            key: ValueKey((gap.startedAt, gap.endedAt)),
            gap: gap,
            dayEndedAt: dayEnd,
            onFill: onFillGap == null ? null : () => onFillGap(view.date, gap),
          ),
        ));
      }
      rows.sort((a, b) => a.order.compareTo(b.order));
    }
    final divider = _DayDivider(
      date: date,
      today: today,
      padding: padding,
      onTap: onDayTap == null ? null : () => onDayTap!(date),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReadScrollAnchor(
          id: DayAnchor(date),
          order: _dayOrder(date),
          child: divider,
        ),
        if (rows.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(padding + 70, 6, padding, 18),
            child: const Text(
              '这一天还没有记录。',
              style: TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 14,
                height: 1.5,
                color: HomePalette.muted,
              ),
            ),
          )
        else
          for (final row in rows)
            ReadScrollAnchor(id: row.id, order: row.order, child: row.tile),
      ],
    );
  }
}

int _dayOrder(CivilDate date) {
  // 仅用于阅读位置回退排序，不参与领域计算。
  return DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch;
}

/// 日期分隔：明确的自然日边界，可点击打开该日日历。
class _DayDivider extends StatelessWidget {
  const _DayDivider({
    required this.date,
    required this.today,
    required this.padding,
    this.onTap,
  });

  final CivilDate date;
  final CivilDate today;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 6, padding, 4),
      child: Row(
        children: [
          InkWell(
            key: ValueKey('day-divider-${date.year}-${date.month}-${date.day}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            // 日期分隔是打开日历的入口：文字保持紧凑，可点区域不低于 48。
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        ledgerDayText(date),
                        style: TextStyle(
                          fontFamily: homeSerifFamily,
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? HomePalette.accentDeep
                              : HomePalette.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ledgerWeekdayText(date, today),
                        style: const TextStyle(
                          fontFamily: homeSerifFamily,
                          fontSize: 12,
                          height: 1.2,
                          color: HomePalette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

/// 吸顶日期提示：日期分隔滚出顶部后继续说明下方记录属于哪一天。
class _StickyDayBar extends StatelessWidget {
  const _StickyDayBar({
    super.key,
    required this.date,
    required this.today,
    this.onTap,
  });

  final CivilDate date;
  final CivilDate today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: HomePalette.paper,
    child: InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: HomePalette.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
          child: Row(
            children: [
              Text(
                ledgerDayText(date),
                style: const TextStyle(
                  fontFamily: homeSerifFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HomePalette.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ledgerWeekdayText(date, today),
                style: const TextStyle(
                  fontFamily: homeSerifFamily,
                  fontSize: 12,
                  color: HomePalette.muted,
                ),
              ),
              const Spacer(),
              const Icon(Icons.expand_more, size: 18, color: HomePalette.muted),
            ],
          ),
        ),
      ),
    ),
  );
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
            _FullSleepDuration(
              text: formatDerivedDuration(
                DerivedDuration(
                  milliseconds: source.endedAt - source.startedAt,
                  hasApproximation:
                      source.startPrecision == TimePrecision.approximate ||
                      source.endPrecision == TimePrecision.approximate,
                ),
              ),
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
    final horizontal = MediaQuery.sizeOf(context).width < 370 ? 16.0 : 20.0;
    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
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
                    padding: EdgeInsets.only(
                      top: contentTopPadding + (titleLineHeight - 19.5) / 2,
                      left: horizontal,
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
                    padding: EdgeInsets.fromLTRB(
                      0,
                      contentTopPadding,
                      horizontal,
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
                        _TimelineHeading(
                          title: title,
                          duration: _rowDuration(duration),
                          availableWidth:
                              constraints.maxWidth -
                              70 -
                              railWidth -
                              12 -
                              horizontal,
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
      ),
    );
  }

  String _boundary(int instant) => instant == dayEndedAt
      ? '24:00'
      : formatRecordingTime(instant).split(' ').last;
}

/// 标题和时长按真实字体宽度排列，不在窄屏 / 大字下互相挤压。
class _TimelineHeading extends StatelessWidget {
  const _TimelineHeading({
    required this.title,
    required this.duration,
    required this.availableWidth,
  });

  final String title;
  final String duration;
  final double availableWidth;

  static const titleStyle = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 17,
    height: _TimelineRow.titleLineHeight / 17,
    fontWeight: FontWeight.w600,
    color: HomePalette.ink,
  );
  static const durationStyle = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 14,
    height: _TimelineRow.titleLineHeight / 14,
    color: HomePalette.muted,
  );

  double _width(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title, style: titleStyle);
    final durationText = Text(duration, style: durationStyle);
    if (_width(context, title, titleStyle) +
            _width(context, duration, durationStyle) +
            8 <=
        availableWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: titleText),
          const SizedBox(width: 8),
          durationText,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        titleText,
        Align(alignment: Alignment.centerRight, child: durationText),
      ],
    );
  }
}

/// 数字与单位一起移动到下一行，避免“分钟”被拆成独立字。
class _FullSleepDuration extends StatelessWidget {
  const _FullSleepDuration({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final matches = RegExp(r'\d+ (?:小时|分钟)').allMatches(text);
    final parts = text.startsWith('少于')
        ? [text]
        : [for (final match in matches) match.group(0)!];
    return Semantics(
      label: '完整时长 $text',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 4,
          children: [
            const Text('完整时长'),
            for (final part in parts) Text(part, softWrap: false),
          ],
        ),
      ),
    );
  }
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
