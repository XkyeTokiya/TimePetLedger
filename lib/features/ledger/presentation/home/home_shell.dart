import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/theme_text.dart';
import '../../../../core/time/civil_date.dart';
import '../../application/day_ledger_loader.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';
import '../../../settings/domain/app_preferences.dart';
import '../day_ledger_date_dialog.dart';
import 'home_coverage_line.dart';
import 'home_day_header.dart';
import 'home_ledger_style.dart';
import 'home_feed_transition.dart';
import 'home_reading_state.dart';
import 'home_timeline_tab.dart';
import 'ledger_feed_controller.dart';

/// 首页外壳：快捷区、当前浏览日期、当日覆盖与跨日期连续时间轴。
///
/// 首页只保留时间账本；摘要与每日复盘改为快捷区中的独立页面。顶部日期
/// 与覆盖统计始终对应当前浏览日期，跨日滚动、按钮切日与日历跳转共用同一
/// 次日期更新。
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.ledgerLoader,
    required this.now,
    required this.dateOfInstant,
    required this.initialDate,
    required this.busy,
    this.onGoals,
    this.onSettings,
    required this.onOpenSummary,
    required this.onOpenReview,
    required this.onRecordActivity,
    required this.onRecordSleep,
    this.onEditFact,
    this.onDeleteTimeBlock,
    this.onFillGap,
    this.floatingCard,
    this.banner,
    this.active = true,
    this.quickPanelSide = HomeQuickPanelSide.left,
  });

  final DayLedgerLoader ledgerLoader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;

  /// 首页首次打开时对应的自然日（跟随时为设备今天）。
  final CivilDate initialDate;
  final bool busy;

  /// 快捷区入口；为空时不显示对应项。
  final VoidCallback? onGoals;
  final VoidCallback? onSettings;
  final ValueChanged<CivilDate> onOpenSummary;
  final ValueChanged<CivilDate> onOpenReview;
  final VoidCallback onRecordActivity;
  final VoidCallback onRecordSleep;

  final Future<bool> Function(CivilDate date, LedgerSegment segment)?
  onEditFact;
  final ValueChanged<TimeBlockSegment>? onDeleteTimeBlock;
  final void Function(CivilDate date, UnresolvedSpan gap)? onFillGap;

  /// 浮动提示卡（例如建议区域），停在操作栏正上方，不随记录列表滚动。
  final Widget Function(LedgerFeedController controller)? floatingCard;

  /// 可选提示区（例如首次主睡眠检查失败），显示在顶栏与日期之间。
  final Widget? banner;

  /// 首页是否为当前阅读面；压在编辑器或独立页下时为 false。
  final bool active;
  final HomeQuickPanelSide quickPanelSide;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final LedgerFeedController feed;
  late final HomeReadingState reading;
  final _timelineInteraction = HomeTimelineInteractionController();
  late final AnimationController _panel;
  final _menuFocus = FocusNode(debugLabel: 'home-menu');
  final _panelFirstFocus = FocusNode(debugLabel: 'quick-panel-close');
  FocusNode? _focusBeforePanel;
  Offset? _dragStart;
  Offset _dragDelta = Offset.zero;
  double _dragStartProgress = 0;
  double _panelWidth = 0;
  bool _dragAccepted = false;
  bool _panelActionPending = false;

  /// 正在收合 / 展开的目标（0 或 1）；拖动接管时清空。
  /// 纵向滚动等取消手势时沿此目标继续，而不是按当前值弹回最近端。
  double? _panelSettleTarget;
  CivilDate? _panelDate;
  final _pointers = <int>{};
  int? _dragPointer;

  /// 时间轴子树的构建缓存：`busy`（导航中）变化时复用同一实例，
  /// 避免整条账本在路由过渡帧重建；其余输入（帧版本、日期、面板 / 活跃态、
  /// 字号与宽度）变化时照常重建。
  Widget? _timelineCache;
  Object? _timelineCacheKey;

  /// 快捷区的左右边缘保留区，避免与系统返回手势冲突。
  static const _edgeGuard = 32.0;
  static const _intentSlop = 24.0;
  static const _flingVelocity = 400.0;
  static final _panelSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 700,
    ratio: 1,
  );

  CivilDate? _lastToday;

  /// 顶部日期代表的当前浏览日期；记录入口与摘要 / 复盘入口都沿用它。
  CivilDate get browsingDate => _panelDate ?? feed.focusDate;
  double get quickPanelProgress => _panel.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reading = HomeReadingState(vsync: this);
    feed = LedgerFeedController(
      loader: widget.ledgerLoader,
      now: widget.now,
      dateOfInstant: widget.dateOfInstant,
      initialDate: widget.initialDate,
    );
    _panel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _lastToday = _today();
    _showDate(widget.initialDate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    feed.dispose();
    reading.dispose();
    _panel.dispose();
    _menuFocus.dispose();
    _panelFirstFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed ||
        (_dragStart == null && !_panel.isAnimating)) {
      return;
    }
    _panel.stop();
    _panel.value = _panel.value >= .5 ? 1 : 0;
    if (_panel.value == 0) _panelDate = null;
    _cancelDrag();
  }

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quickPanelSide != widget.quickPanelSide) {
      _panel.value = 0;
      _panelDate = null;
    }
  }

  CivilDate _today() => widget.dateOfInstant(widget.now());

  Widget _timeline(CivilDate today) {
    final active = widget.active && _panel.value == 0;
    final a11yFactor = _timelineA11yFactor();
    final key = (
      today,
      feed.endDate,
      feed.dataVersion,
      // status 变化不 bump version；不进键会让首载失败停留在旧帧。
      feed.status,
      active,
      a11yFactor,
      MediaQuery.sizeOf(context).width,
      MediaQuery.textScalerOf(context).scale(14),
    );
    if (_timelineCache != null && _timelineCacheKey == key) {
      return _timelineCache!;
    }
    final frame = feed.captureFrame();
    _timelineCacheKey = key;
    return _timelineCache = HomeFeedTransition(
      key: const ValueKey('home-timeline-transition'),
      frame: frame,
      builder: (frame, positioned) => HomeTimelineTab(
        key: ValueKey(frame.endDate),
        controller: feed,
        frame: frame,
        onPositioned: positioned,
        today: today,
        active: active,
        onEditFact: widget.onEditFact,
        onDeleteTimeBlock: widget.onDeleteTimeBlock,
        onFillGap: widget.onFillGap,
        onDayTap: (date) => _chooseDate(initial: date),
        reading: reading,
        a11yFactor: a11yFactor,
        allowUserReading: () => _pointers.length <= 1,
        interactionController: _timelineInteraction,
      ),
    );
  }

  double _timelineA11yFactor() {
    // A 20-minute state has 24dp at 72dp/h. Measure the current short-state
    // style (now readable at 320dp / 2×) before opting into
    // the single allowed whole-axis enlargement; no scale tiers/min-heights.
    if (MediaQuery.sizeOf(context).width > 320 ||
        MediaQuery.textScalerOf(context)
                .scale(HomeLedgerStyle.state.fontSize!) <
            HomeLedgerStyle.state.fontSize! * 2) {
      return 1;
    }
    final stateLine = TextPainter(
      text: TextSpan(
        text: '尚未记录',
        style: withThemeFont(context, HomeLedgerStyle.state),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final unreadable = stateLine.height > 24;
    stateLine.dispose();
    return unreadable ? 1.25 : 1;
  }

  Widget _quickPanel(CivilDate today) {
    final date = _panelDate ?? feed.focusDate;
    return Material(
      key: const ValueKey('home-quick-panel'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: FocusTraversalGroup(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Align(
              alignment: widget.quickPanelSide == HomeQuickPanelSide.left
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: IconButton(
                key: const ValueKey('home-quick-panel-close'),
                focusNode: _panelFirstFocus,
                tooltip: '关闭快捷区',
                onPressed: () => _settlePanel(false),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.year == today.year
                        ? '${date.month}月${date.day}日'
                        : '${date.year}年${date.month}月${date.day}日',
                    key: const ValueKey('home-quick-panel-date'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ledgerWeekdayText(date, today),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Divider(),
            _panelEntry(
              key: 'menu-summary',
              icon: Icons.donut_small_outlined,
              label: '当日概览',
              action: () => widget.onOpenSummary(date),
            ),
            _panelEntry(
              key: 'menu-review',
              icon: Icons.menu_book_outlined,
              label: '当日复盘',
              action: () => widget.onOpenReview(date),
            ),
            if (date != today)
              _panelEntry(
                key: 'menu-today',
                icon: Icons.today_outlined,
                label: '返回今天',
                action: _returnToToday,
              ),
            const Divider(),
            if (widget.onGoals case final onGoals?)
              _panelEntry(
                key: 'menu-goals',
                icon: Icons.flag_outlined,
                label: '我的目标',
                action: onGoals,
              ),
            if (widget.onSettings case final onSettings?)
              _panelEntry(
                key: 'menu-settings',
                icon: Icons.settings_outlined,
                label: '设置',
                action: onSettings,
              ),
          ],
        ),
      ),
    );
  }

  Widget _panelEntry({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback action,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: ListTile(
      key: ValueKey(key),
      leading: Icon(icon),
      title: Text(label),
      onTap: widget.busy || _panelActionPending
          ? null
          : () => _activatePanelEntry(action),
    ),
  );

  /// 入口直跳：点击立即提交目标页导航，快捷区在路由过渡后同步收拢；
  /// 不再等待收拢完成再进入（用户 2026-10-10 明确要求直接跳转）。
  /// 焦点先同步交还菜单入口，路由接管后再执行收拢动画，避免节外生枝。
  Future<void> _activatePanelEntry(VoidCallback action) async {
    if (_panelActionPending) return;
    setState(() => _panelActionPending = true);
    _restorePanelFocus();
    action();
    try {
      await _settlePanel(false, restoreFocus: false);
    } finally {
      if (mounted) setState(() => _panelActionPending = false);
    }
  }

  /// 关闭收拢时的焦点交还：回到开盖前焦点，否则回到菜单入口。
  void _restorePanelFocus() {
    final previous = _focusBeforePanel;
    _focusBeforePanel = null;
    if (previous != null && previous.canRequestFocus) {
      previous.requestFocus();
    } else {
      _menuFocus.requestFocus();
    }
  }

  /// 普通日期导航：目标日成为浏览日期与窗口末端。
  Future<void> _showDate(CivilDate date, {bool resetReading = true}) async {
    final today = _today();
    if (await feed.showDate(date, resetReading: resetReading)) {
      _lastToday = today;
    }
  }

  Future<void> _showSelectedDate(CivilDate date) async {
    final today = _today();
    if (await feed.showSelectedDate(date, today: today)) _lastToday = today;
  }

  Future<void> _returnToToday() async {
    final today = _today();
    if (await feed.returnToToday(today)) _lastToday = today;
  }

  /// 显式日历跳转；测试 / 宿主调用与真实日历入口使用同一合同。
  Future<void> openDate(CivilDate date) => _showSelectedDate(date);

  Future<void> _refresh() async {
    final today = _today();
    if (await feed.refresh()) _lastToday = today;
  }

  /// 编辑记录返回后的数据刷新；跨过午夜且原来跟随今天时回到新的今天。
  Future<void> refresh() async {
    final today = _today();
    final following = _lastToday != null && feed.focusDate == _lastToday;
    if (following && feed.focusDate != today) {
      if (await feed.returnToToday(today, resetReading: false)) {
        _lastToday = today;
      }
      return;
    }
    await _refresh();
  }

  Future<void> _chooseDate({CivilDate? initial}) async {
    if (widget.busy) return;
    var followToday = false;
    final selected = await showDayLedgerDateDialog(
      context,
      initial ?? feed.focusDate,
      onToday: () => followToday = true,
    );
    if (!mounted) return;
    if (followToday) {
      await _returnToToday();
    } else if (selected != null) {
      await _showSelectedDate(selected);
    }
  }

  Future<void> _shiftDay(int direction) {
    final target = adjacentLedgerDate(feed.navigationDate, direction);
    if (!feed.canNavigateTo(target, _today())) return Future.value();
    return _showDate(target);
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length != 1 || widget.busy) {
      _cancelAndSettle();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final insets = MediaQuery.of(context).systemGestureInsets;
    final x = event.position.dx;
    if (x < math.max(_edgeGuard, insets.left) ||
        x > width - math.max(_edgeGuard, insets.right)) {
      _cancelDrag();
      return;
    }
    _dragPointer = event.pointer;
    _dragStart = event.position;
    _dragDelta = Offset.zero;
    _dragStartProgress = _panel.value;
    _dragAccepted = false;
  }

  void _recordPointerPosition(PointerEvent event) {
    if (event.pointer != _dragPointer || _dragStart == null) return;
    // 水平识别器会过滤接受手势前的垂直位移，原始指针保留真实双轴轨迹。
    _dragDelta = event.position - _dragStart!;
  }

  void _pointerUp(PointerUpEvent event) {
    _recordPointerPosition(event);
    _pointers.remove(event.pointer);
  }

  void _pointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _dragPointer) _cancelAndSettle();
  }

  void _cancelDrag() {
    _dragPointer = null;
    _dragStart = null;
    _dragDelta = Offset.zero;
    _dragStartProgress = _panel.value;
    _dragAccepted = false;
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_dragStart == null || widget.busy || _panelWidth <= 0) return;
    final dx = _dragDelta.dx;
    final dy = _dragDelta.dy;
    if (!_dragAccepted) {
      if (dx.abs() < _intentSlop || dx.abs() < dy.abs() * 1.6) return;
      _dragAccepted = true;
      _timelineInteraction.stop();
      // 只有横向拖动真正成立才接管面板动画：普通触摸不得取消收合，
      // 否则面板会停在半开，遮罩挡住时间轴。
      _panel.stop();
      _panelSettleTarget = null;
      _dragStartProgress = _panel.value;
      if (_dragStartProgress == 0) {
        _focusBeforePanel = FocusManager.instance.primaryFocus;
        _panelDate = feed.focusDate;
      }
    }
    final signed = widget.quickPanelSide == HomeQuickPanelSide.left ? dx : -dx;
    if (_dragStartProgress == 0 && signed <= 0) return;
    final effective = signed == 0
        ? 0.0
        : signed - math.min(signed.abs(), _intentSlop) * signed.sign;
    _panel.value = (_dragStartProgress + effective / _panelWidth).clamp(
      0.0,
      1.0,
    );
  }

  void _dragEnd(DragEndDetails details) {
    final accepted = _dragStart != null && _dragAccepted;
    final velocity = details.primaryVelocity ?? 0;
    final signedVelocity = widget.quickPanelSide == HomeQuickPanelSide.left
        ? velocity
        : -velocity;
    _cancelDrag();
    if (!accepted || widget.busy) return;
    final open = signedVelocity.abs() >= _flingVelocity
        ? signedVelocity > 0
        : _panel.value >= .5;
    unawaited(_settlePanel(open, velocity: signedVelocity / _panelWidth));
  }

  void _cancelAndSettle() {
    // 动画进行中沿原目标收束：收合过程中纵向滚动不应把面板弹回打开。
    final settleTarget = _panel.isAnimating ? _panelSettleTarget : null;
    final open = settleTarget != null ? settleTarget >= .5 : _panel.value >= .5;
    _cancelDrag();
    unawaited(_settlePanel(open));
  }

  Future<void> _settlePanel(
    bool open, {
    double velocity = 0,
    bool restoreFocus = true,
  }) async {
    if (open && _panel.value == 0) {
      _focusBeforePanel = FocusManager.instance.primaryFocus;
      _panelDate = feed.focusDate;
    }
    if (open) _timelineInteraction.stop();
    final target = open ? 1.0 : 0.0;
    _panelSettleTarget = target;
    if (MediaQuery.disableAnimationsOf(context)) {
      _panel.value = target;
    } else {
      try {
        await _panel.animateWith(
          SpringSimulation(_panelSpring, _panel.value, target, velocity),
        );
        _panel.value = target;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted) return;
    if (open) {
      _panelFirstFocus.requestFocus();
    } else {
      _panelDate = null;
      if (restoreFocus) _restorePanelFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _today();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelWidth = math.min(360.0, constraints.maxWidth - 64);
            _panelWidth = panelWidth;
            return AnimatedBuilder(
              animation: Listenable.merge([feed, _panel]),
              builder: (context, _) {
                final panelProgress = _panel.value;
                final panelVisible = panelProgress > 0;
                // 收合动画进行中让指针透传到时间轴：拖动可立即滚动，
                // 点按仍由遮罩（命中路径在前）优先关闭面板。
                final panelClosing =
                    _panel.isAnimating && _panelSettleTarget == 0;
                final offset = panelWidth * panelProgress;
                final signedOffset =
                    widget.quickPanelSide == HomeQuickPanelSide.left
                    ? offset
                    : -offset;
                final nextDate = adjacentLedgerDate(feed.navigationDate, 1);
                final canShiftNext = feed.canNavigateTo(nextDate, today);
                final panelAlignment =
                    widget.quickPanelSide == HomeQuickPanelSide.left
                    ? Alignment.centerLeft
                    : Alignment.centerRight;
                return PopScope(
                  canPop: !panelVisible,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && panelVisible) {
                      unawaited(_settlePanel(false));
                    }
                  },
                  child: Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.escape):
                          DismissIntent(),
                    },
                    child: Actions(
                      actions: {
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (_) {
                            if (panelVisible) unawaited(_settlePanel(false));
                            return null;
                          },
                        ),
                      },
                      child: Stack(
                        children: [
                          Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: _pointerDown,
                            onPointerMove: _recordPointerPosition,
                            onPointerUp: _pointerUp,
                            onPointerCancel: _pointerCancel,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragUpdate: _dragUpdate,
                              onHorizontalDragEnd: _dragEnd,
                              onHorizontalDragCancel: _cancelAndSettle,
                              child: Align(
                                alignment: panelAlignment,
                                child: SizedBox(
                                  width: panelWidth,
                                  height: constraints.maxHeight,
                                  child: IgnorePointer(
                                    ignoring: panelProgress < 1,
                                    child: ExcludeFocus(
                                      excluding: panelProgress < 1,
                                      child: ExcludeSemantics(
                                        excluding: panelProgress < 1,
                                        child: _quickPanel(today),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(signedOffset, 0),
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: _pointerDown,
                              onPointerMove: _recordPointerPosition,
                              onPointerUp: _pointerUp,
                              onPointerCancel: _pointerCancel,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: _dragUpdate,
                                onHorizontalDragEnd: _dragEnd,
                                onHorizontalDragCancel: _cancelAndSettle,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ExcludeFocus(
                                        excluding: panelVisible,
                                        child: ExcludeSemantics(
                                          excluding: panelVisible,
                                          child: Material(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: _homeContent(
                                                    constraints,
                                                    today,
                                                    canShiftNext,
                                                  ),
                                                ),
                                                _HomeBottomBar(
                                                  busy: widget.busy,
                                                  onRecordSleep:
                                                      widget.onRecordSleep,
                                                  onRecordActivity:
                                                      widget.onRecordActivity,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (panelVisible)
                                      Positioned.fill(
                                        child: Semantics(
                                          button: true,
                                          label: '关闭快捷区',
                                          child: GestureDetector(
                                            key: const ValueKey(
                                              'home-quick-panel-scrim',
                                            ),
                                            behavior: panelClosing
                                                ? HitTestBehavior.translucent
                                                : HitTestBehavior.opaque,
                                            onTap: () => _settlePanel(false),
                                            // 收合动画进行时让指针透传到时间轴
                                            //（拖动可立即滚动）；点按仍由本
                                            // GestureDetector 优先处理。
                                            child: IgnorePointer(
                                              ignoring: panelClosing,
                                              child: ColoredBox(
                                                color: Colors.black.withValues(
                                                  alpha: .32 * panelProgress,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _homeContent(
    BoxConstraints constraints,
    CivilDate today,
    bool canShiftNext,
  ) => ListenableBuilder(
    listenable: Listenable.merge([feed, reading]),
    builder: (context, _) {
      final progress = reading.progress;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .6),
            child: SingleChildScrollView(
              key: const ValueKey('home-header-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress < 1)
                    ClipRect(
                      child: Align(
                        heightFactor: 1 - progress,
                        child: Opacity(
                          opacity: 1 - progress,
                          child: IgnorePointer(
                            ignoring: progress > 0,
                            child: ExcludeSemantics(
                              excluding: progress > 0,
                              child: HomeTopBar(
                                busy: widget.busy,
                                side: widget.quickPanelSide,
                                menuFocusNode: _menuFocus,
                                onToday: feed.focusDate == today
                                    ? null
                                    : _returnToToday,
                                onMenu: () => _settlePanel(true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ?widget.banner,
                  HomeDateTitle(
                    date: feed.focusDate,
                    today: today,
                    busy: widget.busy,
                    progress: progress,
                    side: widget.quickPanelSide,
                    menuFocusNode: _menuFocus,
                    canShiftNext: canShiftNext,
                    onMenu: () => _settlePanel(true),
                    onChooseDate: _chooseDate,
                    onShiftDay: _shiftDay,
                    onToday: _returnToToday,
                  ),
                  if (feed.focusView case final view?)
                    HomeCoverageLine(
                      view: view,
                      progress: progress,
                      onTap: widget.busy
                          ? null
                          : () => widget.onOpenSummary(feed.focusDate),
                    ),
                  if (feed.refreshFailed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '账本刷新失败，当前仍显示上一次读取结果。',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.busy ? null : _refresh,
                            child: const Text('重试读取'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            key: const ValueKey('home-reading-surface'),
            child: _timeline(today),
          ),
          if (widget.floatingCard != null &&
              feed.focusDate == today &&
              progress < 1)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .25,
              ),
              child: SingleChildScrollView(
                child: ClipRect(
                  child: Align(
                    heightFactor: 1 - progress,
                    child: IgnorePointer(
                      ignoring: progress > 0,
                      child: ExcludeSemantics(
                        excluding: progress > 0,
                        child: widget.floatingCard!(feed),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _HomeBottomBar extends StatelessWidget {
  const _HomeBottomBar({
    required this.busy,
    required this.onRecordSleep,
    required this.onRecordActivity,
  });

  final bool busy;
  final VoidCallback onRecordSleep;
  final VoidCallback onRecordActivity;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('home-record-sleep'),
                  onPressed: busy ? null : onRecordSleep,
                  style: OutlinedButton.styleFrom(
                    textStyle: withThemeFont(context, HomeLedgerStyle.button),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const _RecordButtonContents(
                    icon: Icons.bedtime_outlined,
                    label: '记录睡眠',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('home-record-activity'),
                  onPressed: busy ? null : onRecordActivity,
                  style: FilledButton.styleFrom(
                    textStyle: withThemeFont(context, HomeLedgerStyle.button),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const _RecordButtonContents(
                    icon: Icons.edit_outlined,
                    label: '记录一笔',
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

class _RecordButtonContents extends StatelessWidget {
  const _RecordButtonContents({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final measure = TextPainter(
        text: TextSpan(
          text: label,
          style: withThemeFont(context, HomeLedgerStyle.button),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final showIcon = constraints.maxWidth >= measure.width + 24;
      measure.dispose();
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      );
    },
  );
}
