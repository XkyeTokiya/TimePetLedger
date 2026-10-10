import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';
import '../day_ledger_date_dialog.dart' show adjacentLedgerDate;
import '../day_read_scroll.dart';
import 'home_day_axis.dart';
import 'home_reading_state.dart';
import 'home_timeline_geometry.dart';
import 'ledger_feed_controller.dart';

String ledgerDayText(CivilDate date) => '${date.month}月${date.day}日';

String ledgerWeekdayText(CivilDate date, CivilDate today) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final index = DateTime.utc(date.year, date.month, date.day).weekday - 1;
  final weekday = index >= 0 && index < names.length ? names[index] : '所选日期';
  if (date == today) return '$weekday · 今天';
  if (date == adjacentLedgerDate(today, -1)) return '$weekday · 昨天';
  return weekday;
}

/// A continuous feed with a temporal reading anchor, independent of facts and
/// Gap identities. Every day consumes its already committed projection.
class HomeTimelineTab extends StatefulWidget {
  const HomeTimelineTab({
    super.key,
    required this.controller,
    required this.frame,
    required this.today,
    required this.reading,
    this.onPositioned,
    this.active = true,
    this.onEditFact,
    this.onEditUnderstanding,
    this.onDeleteTimeBlock,
    this.onFillGap,
    this.onDayTap,
    this.allowUserReading,
    this.interactionController,
    this.a11yFactor = 1,
  });
  final LedgerFeedController controller;
  final LedgerFeedFrame frame;
  final CivilDate today;
  final HomeReadingState reading;
  final VoidCallback? onPositioned;
  final bool active;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditFact;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditUnderstanding;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate, UnresolvedSpan)? onFillGap;
  final void Function(CivilDate)? onDayTap;
  final bool Function()? allowUserReading;
  final HomeTimelineInteractionController? interactionController;
  final double a11yFactor;
  @override
  State<HomeTimelineTab> createState() => HomeTimelineTabState();
}

/// 只暴露首页外壳需要的最小控制：快捷区开始打开时立即停止时间线惯性。
final class HomeTimelineInteractionController {
  VoidCallback? _stop;

  void stop() => _stop?.call();

  void _attach(VoidCallback stop) => _stop = stop;

  void _detach(VoidCallback stop) {
    if (_stop == stop) _stop = null;
  }
}

final class DayAnchor {
  const DayAnchor(this.date);
  final CivilDate date;
  @override
  bool operator ==(Object other) => other is DayAnchor && other.date == date;
  @override
  int get hashCode => date.hashCode;
}

final class _AxisAnchor {
  const _AxisAnchor(this.date, this.geometry, this.endedAt);
  final CivilDate date;
  final HomeTimelineGeometry geometry;
  final int endedAt;
}

enum _ReadDirection { fingerUp, fingerDown }

class HomeTimelineTabState extends State<HomeTimelineTab> {
  final _scroll = _TemporalScrollController();
  final _viewport = GlobalKey();
  final _lastDayKey = GlobalKey();
  final _axisViewport = HomeAxisViewport();
  HomeReadPosition? _lastVisible;
  HomeReadPosition? get _origin => widget.reading.origin;
  CivilDate? _pendingReveal;
  bool _resetReveal = false;
  bool _restoring = false;
  bool _layoutQueued = false;
  bool _positioned = false;
  bool _extendRequested = false;
  bool _extendLaterRequested = false;
  bool _userScrolling = false;
  _ReadDirection? _readDirection;
  int _restoredVersion = -1;
  Size? _layoutSize;
  double _bottomFill = 0;
  bool _passActive = false;
  List<({Object id, RenderBox box})>? _passAnchors;
  final _dayCache = <CivilDate, _CachedDay>{};

  HomeReadPosition? get readingPosition => _lastVisible;
  HomeReadPosition? get readingOrigin => _origin;
  bool get _current =>
      widget.frame.version == widget.controller.dataVersion &&
      widget.frame.endDate == widget.controller.endDate;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.reading.addListener(_onHeaderChanged);
    widget.interactionController?._attach(_stopMotion);
    _acceptFrame();
  }

  @override
  void didUpdateWidget(HomeTimelineTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reading != widget.reading) {
      oldWidget.reading.removeListener(_onHeaderChanged);
      widget.reading.addListener(_onHeaderChanged);
    }
    if (oldWidget.interactionController != widget.interactionController) {
      oldWidget.interactionController?._detach(_stopMotion);
      widget.interactionController?._attach(_stopMotion);
    }
    if (widget.controller != oldWidget.controller ||
        widget.frame.version != _restoredVersion) {
      _acceptFrame();
    } else if ((widget.active && !oldWidget.active) ||
        oldWidget.a11yFactor != widget.a11yFactor) {
      _requestLayout(restore: true);
    }
  }

  @override
  void dispose() {
    widget.interactionController?._detach(_stopMotion);
    widget.reading.removeListener(_onHeaderChanged);
    _scroll.dispose();
    _axisViewport.dispose();
    super.dispose();
  }

  void _stopMotion() {
    if (_scroll.hasClients) _scroll.stopMotion();
  }

  void _onHeaderChanged() {
    if (_current && widget.active) _requestLayout(restore: true);
  }

  void _acceptFrame() {
    _restoredVersion = widget.frame.version;
    if (!_current || widget.frame.status != LedgerFeedStatus.ready) return;
    _pendingReveal = widget.controller.takeRevealRequest();
    _resetReveal =
        _pendingReveal != null && widget.controller.revealResetsReading;
    if (!_userScrolling) _readDirection = null;
    _requestLayout(restore: true);
  }

  void _requestLayout({bool restore = false}) {
    if (restore) _restoring = true;
    if (_layoutQueued) return;
    _layoutQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutQueued = false;
      _passActive = true;
      try {
        _runLayoutPass();
      } finally {
        _passActive = false;
        _passAnchors = null;
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _runLayoutPass() {
    if (!mounted || !_current || !_scroll.hasClients) {
      // 本次恢复无法执行：清掉恢复标记，避免后续滚动更新被 _restoring 抑制。
      _restoring = false;
      return;
    }
    if (!widget.active) {
      _restoring = false;
      return;
    }
    if (_resetReveal) {
      _resetReveal = false;
      widget.reading.reset();

      _requestLayout(restore: true);
      return;
    }
    if (_syncBottomFill()) {
      _requestLayout();
      return;
    }
    var moved = false;
    if (_pendingReveal case final date?) {
      final entry = _axisEntries()
          .where((entry) => entry.anchor.date == date)
          .firstOrNull;
      if (entry != null) {
        final view = widget.frame.viewFor(date)!;
        final axisY = entry.box.localToGlobal(Offset.zero).dy - _viewportTop();
        final geometry = entry.anchor.geometry;
        final double targetY;
        if (date == widget.today && !view.window.isEmpty) {
          // Leave the same-read "now" marker near the bottom, with room for
          // its label. Small windows still start at their real midnight.
          targetY =
              (geometry.y(view.window.endedAt) -
                      _scroll.position.viewportDimension +
                      40)
                  .clamp(0.0, double.infinity);
        } else if (view.segments.isNotEmpty) {
          targetY = geometry.y(view.segments.first.startedAt) - 8;
        } else {
          targetY = -8;
        }
        moved = _jumpTo(_scroll.offset + axisY + targetY);
      }
    } else if (_restoring) {
      moved = _restorePosition();
    }
    if (moved) {
      _requestLayout();
      return;
    }

    _pendingReveal = null;
    _restoring = false;
    if (!_positioned) setState(() => _positioned = true);
    _lastVisible = _capture();
    widget.reading.rememberOrigin(_lastVisible);
    _syncAxisViewport();
    _syncVisibleDay();
    if (!_userScrolling) _readDirection = null;
    widget.onPositioned?.call();
    _extendWhenAtStart();
    _extendWhenAtEnd();
  }

  double _viewportTop() {
    final box = _viewport.currentContext?.findRenderObject();
    return box is RenderBox ? box.localToGlobal(Offset.zero).dy : 0;
  }

  /// Publishes the visible band in scroll-content coordinates. Scroll updates
  /// call it synchronously so axis labels use the geometry of the frame that
  /// is about to be painted, not the position of the previous frame.
  void _syncAxisViewport() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _axisViewport.update(
      position.pixels,
      position.pixels + position.viewportDimension,
    );
  }

  bool _jumpTo(double target, {bool compensate = false}) {
    final clamped = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if ((clamped - _scroll.offset).abs() < .1) return false;
    if (compensate) {
      _scroll.compensateTo(clamped);
    } else {
      _scroll.jumpTo(clamped);
    }
    return true;
  }

  List<({Object id, RenderBox box})> _anchors() {
    final source = _passActive
        ? (_passAnchors ??= _walkAnchors())
        : _walkAnchors();
    return [
      for (final entry in source)
        if (entry.box.attached && entry.box.hasSize) entry,
    ];
  }

  List<({Object id, RenderBox box})> _walkAnchors() {
    final result = <({Object id, RenderBox box})>[];
    void visit(Element element) {
      if (element.widget case final ReadScrollAnchor anchor) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.attached && box.hasSize) {
          result.add((id: anchor.id, box: box));
        }
        // Home anchors terminate at a day divider or axis. Facts below the
        // axis are not anchors and need not be walked on every pointer frame.
        return;
      }
      element.visitChildren(visit);
    }

    _viewport.currentContext?.visitChildElements(visit);
    return result;
  }

  List<({_AxisAnchor anchor, RenderBox box})> _axisEntries() => [
    for (final entry in _anchors())
      if (entry.id case final _AxisAnchor axis) (anchor: axis, box: entry.box),
  ];
  HomeReadPosition? _capture() {
    final viewportTop = _viewportTop();
    final breakpoint = _scroll.position.viewportDimension;
    HomeReadPosition? nearest;
    for (final entry in _axisEntries()) {
      final top = entry.box.localToGlobal(Offset.zero).dy - viewportTop;
      final geometry = entry.anchor.geometry;
      final end = entry.anchor.endedAt;
      final temporalHeight = geometry.y(end);
      if (top > breakpoint) break;
      if (top + entry.box.size.height > 0) {
        final y = (breakpoint - top).clamp(0.0, temporalHeight);
        nearest = HomeReadPosition(
          entry.anchor.date,
          geometry.instant(y).clamp(geometry.startedAt, end),
          top + y - breakpoint,
        );
        if (top + temporalHeight >= breakpoint) return nearest;
      }
    }
    return nearest ?? _lastVisible;
  }

  double? _positionY(HomeReadPosition? saved) {
    if (saved == null) return null;
    final entry = _axisEntries()
        .where((entry) => entry.anchor.date == saved.date)
        .firstOrNull;
    if (entry == null) return null;
    // Restoration clamps only to the updated window. Reading origin remains
    // the original instant, so changing today's end cannot redefine distance.
    return entry.box.localToGlobal(Offset.zero).dy -
        _viewportTop() +
        entry.anchor.geometry.y(saved.instant) -
        _scroll.position.viewportDimension;
  }

  bool _restorePosition() {
    final saved = _lastVisible;
    if (saved == null) return false;
    final entry = _axisEntries()
        .where((entry) => entry.anchor.date == saved.date)
        .firstOrNull;
    if (entry == null) return false;
    final clamped = saved.instant.clamp(
      entry.anchor.geometry.startedAt,
      entry.anchor.endedAt,
    );
    final y = _positionY(
      HomeReadPosition(saved.date, clamped, saved.relativeY),
    );
    return y != null &&
        _jumpTo(_scroll.offset + y - saved.relativeY, compensate: true);
  }

  void _onScroll() {
    _syncAxisViewport();
    if (mounted && _current && !_restoring && _positioned && widget.active) {
      _requestLayout();
    }
  }

  bool _notification(ScrollNotification notification) {
    if (!_current || !widget.active || !_positioned) return false;
    if (_pendingReveal != null) {
      // 定位尚未完成时不推进阅读状态，但仍维护用户滚动的开始 / 结束簿记，
      // 避免这段时间内开始的手势丢失 beginUserRead / endUserRead。
      if (notification is ScrollStartNotification &&
          notification.dragDetails != null) {
        _userScrolling = true;
        _readDirection = null;
        widget.reading.beginUserRead();
      } else if (notification is ScrollEndNotification) {
        _userScrolling = false;
        widget.reading.endUserRead();
      }
      return false;
    }
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _userScrolling = true;
      _readDirection = null;
      widget.reading.beginUserRead();
    }
    if (notification is ScrollUpdateNotification &&
        _userScrolling &&
        (widget.allowUserReading?.call() ?? true) &&
        notification.metrics.pixels >= notification.metrics.minScrollExtent &&
        notification.metrics.pixels <= notification.metrics.maxScrollExtent &&
        (notification.scrollDelta?.abs() ?? 0) > 0) {
      final delta = notification.scrollDelta!;
      if (notification.dragDetails != null) {
        _readDirection = delta > 0
            ? _ReadDirection.fingerUp
            : _ReadDirection.fingerDown;
      }
      final direction = _readDirection;
      if (direction != null) {
        widget.reading.updateUserRead(
          fingerUp: direction == _ReadDirection.fingerUp,
          distance: delta.abs(),
        );
      }
      // A finger can move again before the header compensation frame. Keep
      // that real movement rather than restoring the previous frame over it.
      if (_restoring) _lastVisible = _capture();
      _requestLayout();
    }
    if (notification is ScrollEndNotification) {
      _userScrolling = false;
      widget.reading.endUserRead();
      _requestLayout();
    }
    return false;
  }

  void _syncVisibleDay() {
    if (!_current || _restoring || !_positioned || !widget.active) return;
    // 显式导航已经由 controller 提交目标日期；布局、转场或测试用 jumpTo
    // 不得反向改写它。只有真实阅读手势及其同次惯性推进顶部日期。
    if (!_userScrolling && _readDirection == null) return;
    CivilDate? date;
    final viewportTop = _viewportTop();
    for (final entry in _anchors()) {
      if (entry.id case final DayAnchor day) {
        final y = entry.box.localToGlobal(Offset.zero).dy - viewportTop;
        // 顶部日期与回展共用日期横线穿过时间轴窗口上沿的断点。
        // 横线只在窗口底部露头时不得提前切日或回展。
        if (y <= 1) {
          date = day.date;
        } else {
          date ??= day.date;
          break;
        }
      }
    }
    if (date != null && date != widget.controller.focusDate) {
      widget.controller.noteFocus(date);
      if (_readDirection == _ReadDirection.fingerUp) {
        widget.reading.expandForDayDividerAtTop();
      }
    }
  }

  void _extendWhenAtStart() {
    if (!_current || _restoring || !widget.active) return;
    if (_scroll.position.pixels > .5) {
      _extendRequested = false;
      return;
    }
    if (_extendRequested) return;
    _extendRequested = true;
    unawaited(
      widget.controller.extendEarlier().then((extended) {
        // 装载失败或本次未执行时解除闩锁，下一次到达顶部可以重试。
        if (!extended && mounted) _extendRequested = false;
      }),
    );
  }

  /// 向下滚动到已装载末端后继续向后装载，直到导航上限（今天或手选未来
  /// 上限）；不改变浏览日期与阅读位置。
  void _extendWhenAtEnd() {
    if (!_current || _restoring || !widget.active) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - .5) {
      _extendLaterRequested = false;
      return;
    }
    if (_extendLaterRequested) return;
    _extendLaterRequested = true;
    unawaited(
      widget.controller.extendLater(widget.today).then((extended) {
        // 装载失败或已到上限时解除闩锁，下一次到达末端可以重试。
        if (!extended && mounted) _extendLaterRequested = false;
      }),
    );
  }

  bool _syncBottomFill() {
    final box = _lastDayKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final needed = (_scroll.position.viewportDimension - box.size.height).clamp(
      0.0,
      4000.0,
    );
    if ((needed - _bottomFill).abs() < .5) return false;
    setState(() => _bottomFill = needed);
    return true;
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: widget.controller.refresh,
              child: const Text('重试读取'),
            ),
          ],
        ),
      );
    }
    const padding = TimeLedgerSpacing.md;
    return Visibility(
      visible: _positioned,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: LayoutBuilder(
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
          _pruneDayCache(frame.dates);
          return NotificationListener<ScrollNotification>(
            onNotification: _notification,
            child: SingleChildScrollView(
              key: _viewport,
              controller: _scroll,
              padding: EdgeInsets.only(bottom: 24 + _bottomFill),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final date in frame.dates)
                    if (frame.viewFor(date) case final view?)
                      _cachedDay(date, view, date == frame.dates.last, padding),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _day(CivilDate date, DayLedgerView view, double padding, Key key) {
    final geometry = HomeTimelineGeometry(
      startedAt: view.window.startedAt,
      a11yFactor: widget.a11yFactor,
    );
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReadScrollAnchor(
          id: DayAnchor(date),
          order: view.window.startedAt,
          child: _DayDivider(
            date: date,
            today: widget.today,
            padding: padding,
            onTap: widget.onDayTap == null
                ? null
                : () => widget.onDayTap!(date),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: ReadScrollAnchor(
            id: _AxisAnchor(date, geometry, view.window.endedAt),
            order: view.window.startedAt,
            child: HomeDayAxis(
              view: view,
              geometry: geometry,
              viewport: _axisViewport,
              isToday: date == widget.today,
              isCurrent: () => _current && widget.active,
              onEditFact: widget.onEditFact,
              onEditUnderstanding: widget.onEditUnderstanding,
              onDeleteTimeBlock: widget.onDeleteTimeBlock,
              onFillGap: widget.onFillGap,
            ),
          ),
        ),
      ],
    );
  }

  /// 按天复用已建子树：尺寸变化（如顶部收放）只重排不重建；
  /// 数据、几何、回调或"末日归属"变化时重建该天。
  Widget _cachedDay(
    CivilDate date,
    DayLedgerView view,
    bool isLast,
    double padding,
  ) {
    final cached = _dayCache[date];
    if (cached != null &&
        identical(cached.view, view) &&
        cached.isLast == isLast &&
        cached.a11yFactor == widget.a11yFactor &&
        cached.today == widget.today &&
        cached.onEditFact == widget.onEditFact &&
        cached.onEditUnderstanding == widget.onEditUnderstanding &&
        cached.onDeleteTimeBlock == widget.onDeleteTimeBlock &&
        cached.onFillGap == widget.onFillGap) {
      return cached.widget;
    }
    final built = _day(
      date,
      view,
      padding,
      isLast ? _lastDayKey : ValueKey(date),
    );
    _dayCache[date] = _CachedDay(
      view: view,
      isLast: isLast,
      a11yFactor: widget.a11yFactor,
      today: widget.today,
      onEditFact: widget.onEditFact,
      onEditUnderstanding: widget.onEditUnderstanding,
      onDeleteTimeBlock: widget.onDeleteTimeBlock,
      onFillGap: widget.onFillGap,
      widget: built,
    );
    return built;
  }

  void _pruneDayCache(List<CivilDate> dates) {
    if (_dayCache.length <= dates.length) return;
    final live = dates.toSet();
    _dayCache.removeWhere((date, _) => !live.contains(date));
  }
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
    final colors = Theme.of(context).colorScheme;
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
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        ledgerDayText(date),
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: isToday ? colors.primary : colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ledgerWeekdayText(date, today),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: colors.onSurfaceVariant,
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

/// Layout compensation must not cancel an in-progress touch drag. Ordinary
/// jumpTo is reserved for explicit positioning. Ballistic motion is restarted
/// from the compensated position with its existing velocity.
class _TemporalScrollController extends ScrollController {
  _TemporalScrollController() : super(keepScrollOffset: false);
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TemporalScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
  void compensateTo(double value) =>
      (position as _TemporalScrollPosition).compensateTo(value);
  void stopMotion() => (position as _TemporalScrollPosition).stopMotion();
}

class _TemporalScrollPosition extends ScrollPositionWithSingleContext {
  _TemporalScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
  }) : super(initialPixels: 0, keepScrollOffset: false);
  void compensateTo(double value) {
    final ballistic = activity is BallisticScrollActivity;
    final velocity = activity?.velocity ?? 0;
    forcePixels(value);
    if (ballistic) goBallistic(velocity);
  }

  void stopMotion() => goIdle();
}

/// 单日子树缓存条目；任一输入变化即重建该天。
class _CachedDay {
  const _CachedDay({
    required this.view,
    required this.isLast,
    required this.a11yFactor,
    required this.today,
    required this.onEditFact,
    required this.onEditUnderstanding,
    required this.onDeleteTimeBlock,
    required this.onFillGap,
    required this.widget,
  });

  final DayLedgerView view;
  final bool isLast;
  final double a11yFactor;
  final CivilDate today;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditFact;
  final Future<bool> Function(CivilDate, LedgerSegment)? onEditUnderstanding;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate, UnresolvedSpan)? onFillGap;
  final Widget widget;
}
