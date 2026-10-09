import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../application/day_ledger_loader.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';
import '../day_ledger_date_dialog.dart';
import 'home_coverage_line.dart';
import 'home_day_header.dart';
import 'home_ledger_style.dart';
import 'home_feed_transition.dart';
import 'home_reading_state.dart';
import 'home_timeline_tab.dart';
import 'ledger_feed_controller.dart';

/// 首页外壳：菜单 / 侧边栏、当前浏览日期、当日覆盖与跨日期连续时间轴。
///
/// 首页只保留时间账本；摘要与每日复盘改为侧边栏中的独立页面。顶部日期
/// 与覆盖统计始终对应当前浏览日期，跨日滚动、滑动切日与日历跳转共用同一
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
  });

  final DayLedgerLoader ledgerLoader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;

  /// 首页首次打开时对应的自然日（跟随时为设备今天）。
  final CivilDate initialDate;
  final bool busy;

  /// 侧边栏入口；为空时不显示对应项。
  final VoidCallback? onGoals;
  final VoidCallback? onSettings;
  final VoidCallback onOpenSummary;
  final VoidCallback onOpenReview;
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

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  late final LedgerFeedController feed;
  final reading = HomeReadingState();
  final _scaffold = GlobalKey<ScaffoldState>();
  Offset? _dragStart;
  Offset _dragDelta = Offset.zero;
  final _pointers = <int>{};
  int? _dragPointer;

  /// 侧边栏打开时的左边缘 / 右边缘保留区，避免与抽屉和系统返回手势冲突。
  static const _edgeGuard = 32.0;

  CivilDate? _lastToday;

  /// 顶部日期代表的当前浏览日期；记录入口与摘要 / 复盘入口都沿用它。
  CivilDate get browsingDate => feed.focusDate;

  @override
  void initState() {
    super.initState();
    feed = LedgerFeedController(
      loader: widget.ledgerLoader,
      now: widget.now,
      dateOfInstant: widget.dateOfInstant,
      initialDate: widget.initialDate,
    );
    _lastToday = _today();
    _showDate(widget.initialDate);
  }

  @override
  void dispose() {
    feed.dispose();
    reading.dispose();
    super.dispose();
  }

  CivilDate _today() => widget.dateOfInstant(widget.now());

  Widget _timeline(CivilDate today) {
    return HomeFeedTransition(
      key: const ValueKey('home-timeline-transition'),
      frame: feed.captureFrame(),
      builder: (frame, positioned) => HomeTimelineTab(
        key: ValueKey(frame.endDate),
        controller: feed,
        frame: frame,
        onPositioned: positioned,
        today: today,
        active: widget.active && !widget.busy,
        onEditFact: widget.onEditFact,
        onDeleteTimeBlock: widget.onDeleteTimeBlock,
        onFillGap: widget.onFillGap,
        onDayTap: (date) => _chooseDate(initial: date),
        reading: reading,
        a11yFactor: _timelineA11yFactor(),
        allowUserReading: () => _pointers.length <= 1,
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
      text: const TextSpan(text: '尚未记录', style: HomeLedgerStyle.state),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final unreadable = stateLine.height > 24;
    stateLine.dispose();
    return unreadable ? 1.25 : 1;
  }

  /// 侧边栏：时间账本 / 当日摘要 / 每日复盘 + 我的目标 / 设置。
  Widget _menuDrawer() {
    final entries = <({Widget destination, VoidCallback? action})>[
      (
        destination: const NavigationDrawerDestination(
          key: ValueKey('menu-ledger'),
          icon: Icon(Icons.list_alt_outlined),
          label: Text('时间账本'),
        ),
        action: null,
      ),
      (
        destination: const NavigationDrawerDestination(
          key: ValueKey('menu-summary'),
          icon: Icon(Icons.donut_small_outlined),
          label: Text('当日摘要'),
        ),
        action: widget.onOpenSummary,
      ),
      (
        destination: const NavigationDrawerDestination(
          key: ValueKey('menu-review'),
          icon: Icon(Icons.menu_book_outlined),
          label: Text('每日复盘'),
        ),
        action: widget.onOpenReview,
      ),
      if (widget.onGoals case final onGoals?)
        (
          destination: const NavigationDrawerDestination(
            key: ValueKey('menu-goals'),
            icon: Icon(Icons.flag_outlined),
            label: Text('我的目标'),
          ),
          action: onGoals,
        ),
      if (widget.onSettings case final onSettings?)
        (
          destination: const NavigationDrawerDestination(
            key: ValueKey('menu-settings'),
            icon: Icon(Icons.settings_outlined),
            label: Text('设置'),
          ),
          action: onSettings,
        ),
    ];
    return NavigationDrawer(
      key: const ValueKey('home-drawer'),
      selectedIndex: 0,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        entries[index].action?.call();
      },
      children: [for (final entry in entries) entry.destination],
    );
  }

  /// 日历 / 前后一天 / 滑动切日 / 回到今天共用：目标日成为浏览日期与窗口末端。
  Future<void> _showDate(CivilDate date, {bool resetReading = true}) async {
    final today = _today();
    if (await feed.showDate(date, resetReading: resetReading)) {
      _lastToday = today;
    }
  }

  /// 显式跳到某一天；日历、滑动切日与“回到今天”共用同一规则。
  Future<void> openDate(CivilDate date) => _showDate(date);

  Future<void> _refresh() async {
    final today = _today();
    if (await feed.refresh()) _lastToday = today;
  }

  /// 编辑记录返回后的数据刷新；跨过午夜且原来跟随今天时回到新的今天。
  Future<void> refresh() async {
    final today = _today();
    final following = _lastToday != null && feed.focusDate == _lastToday;
    if (following && feed.focusDate != today) {
      await _showDate(today, resetReading: false);
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
      await _showDate(_today());
    } else if (selected != null) {
      await _showDate(selected);
    }
  }

  Future<void> _shiftDay(int direction) {
    final target = adjacentLedgerDate(feed.navigationDate, direction);
    return _showDate(target);
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length != 1 || widget.busy) {
      _cancelDrag();
      return;
    }
    final width = MediaQuery.sizeOf(context).width;
    final x = event.position.dx;
    if (x < _edgeGuard || x > width - _edgeGuard) {
      _cancelDrag();
      return;
    }
    _dragPointer = event.pointer;
    _dragStart = event.position;
    _dragDelta = Offset.zero;
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
    if (event.pointer == _dragPointer) _cancelDrag();
  }

  void _cancelDrag() {
    _dragPointer = null;
    _dragStart = null;
    _dragDelta = Offset.zero;
  }

  void _dragEnd(DragEndDetails details) {
    final started = _dragStart != null;
    final dx = _dragDelta.dx;
    final dy = _dragDelta.dy;
    _cancelDrag();
    if (!started || widget.busy) return;
    // 明确的横向意图才切日，轻微斜滑不会误触记录或换日。
    if (dx.abs() < 64 || dx.abs() <= dy.abs() * 1.6) return;
    _shiftDay(dx < 0 ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final today = _today();
    return Theme(
      data: homeTheme,
      child: Scaffold(
        key: _scaffold,
        drawer: _menuDrawer(),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => ListenableBuilder(
              listenable: Listenable.merge([feed, reading]),
              builder: (context, _) {
                final progress = reading.progress;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * .6,
                      ),
                      child: SingleChildScrollView(
                        key: const ValueKey('home-header-scroll'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (progress < 1)
                              HomeTopBar(
                                busy: widget.busy,
                                onToday: feed.focusDate == today
                                    ? null
                                    : () => _showDate(today),
                                onMenu: () =>
                                    _scaffold.currentState?.openDrawer(),
                              ),
                            ?widget.banner,
                            HomeDateTitle(
                              date: feed.focusDate,
                              today: today,
                              busy: widget.busy,
                              progress: progress,
                              onMenu: () =>
                                  _scaffold.currentState?.openDrawer(),
                              onChooseDate: _chooseDate,
                              onShiftDay: _shiftDay,
                              onToday: () => _showDate(today),
                            ),
                            if (feed.focusView case final view?)
                              HomeCoverageLine(
                                view: view,
                                progress: progress,
                                onTap: widget.busy
                                    ? null
                                    : widget.onOpenSummary,
                              ),
                            if (feed.refreshFailed)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
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
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _pointerDown,
                        onPointerMove: _recordPointerPosition,
                        onPointerUp: _pointerUp,
                        onPointerCancel: _pointerCancel,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: _dragEnd,
                          onHorizontalDragCancel: _cancelDrag,
                          child: _timeline(today),
                        ),
                      ),
                    ),
                    if (widget.floatingCard != null && progress < 1)
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
            ),
          ),
        ),
        bottomNavigationBar: _HomeBottomBar(
          busy: widget.busy,
          onRecordSleep: widget.onRecordSleep,
          onRecordActivity: widget.onRecordActivity,
        ),
      ),
    );
  }
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
    color: HomePalette.paper,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: HomePalette.hairline)),
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
                    textStyle: HomeLedgerStyle.button,
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
                    textStyle: HomeLedgerStyle.button,
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
        text: TextSpan(text: label, style: HomeLedgerStyle.button),
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
