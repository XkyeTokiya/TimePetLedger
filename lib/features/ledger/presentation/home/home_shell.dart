import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../application/day_ledger_loader.dart';
import '../day_date_selection.dart';
import '../day_ledger_controller.dart';
import '../day_ledger_date_dialog.dart';
import '../day_ledger_overview.dart';
import 'home_coverage_line.dart';
import 'home_day_header.dart';

/// Rebuilt home chrome (confirmed reference):
/// menu · large serif date · coverage line · 时间线 / 摘要 / 复盘 tabs ·
/// 记录睡眠 / 记录一笔. Hosts the existing real timeline and review pages and
/// shares one reading controller with the coverage header.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.selection,
    required this.ledgerLoader,
    required this.now,
    required this.dateOfInstant,
    required this.timeline,
    required this.summary,
    required this.review,
    required this.busy,
    required this.onMenu,
    required this.onRecordActivity,
    required this.onRecordSleep,
    this.reviewEnabled = true,
    this.banner,
    this.floatingCard,
  });

  final DayDateSelection selection;
  final DayLedgerLoader ledgerLoader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final Widget Function(DayLedgerController controller, bool active) timeline;
  final Widget Function(DayLedgerController controller, bool active) summary;
  final Widget Function(bool active) review;

  /// 浮动提示卡（例如已保存的复盘），停在操作栏正上方，不随记录列表滚动。
  final Widget Function(DayLedgerController controller)? floatingCard;
  final bool reviewEnabled;
  final bool busy;
  final VoidCallback onMenu;
  final VoidCallback onRecordActivity;
  final VoidCallback onRecordSleep;

  /// 可选提示区（例如首次主睡眠检查失败），显示在顶栏与日期之间。
  final Widget? banner;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  late final DayLedgerController controller;

  @override
  void initState() {
    super.initState();
    controller = DayLedgerController(
      loader: widget.ledgerLoader,
      now: widget.now,
      dateOfInstant: widget.dateOfInstant,
      selectedDate: widget.selection.date,
    );
    widget.selection.addListener(_onSelectionChanged);
    tabs.addListener(_onTabChanged);
    controller.refresh();
  }

  void _onSelectionChanged() => controller.select(widget.selection.date);

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  /// 菜单入口：重读当前日期账本。
  void refreshFromMenu() {
    if (widget.busy) return;
    controller.refresh();
  }

  /// 复盘卡入口：切到复盘标签。
  void openReviewTab() {
    if (mounted) tabs.animateTo(2);
  }

  /// 菜单入口：打开时间分布说明（只读当前投影）。
  void showDistribution() {
    final view = controller.view;
    final dateContext = controller.dateContext;
    if (widget.busy || view == null || dateContext == null) return;
    DayLedgerOverview.showExplanation(
      context,
      view: view,
      dateContext: dateContext,
    );
  }

  Future<void> _chooseDate() async {
    final date = controller.date;
    if (date == null || widget.busy) return;
    var followToday = false;
    final selected = await showDayLedgerDateDialog(
      context,
      date,
      onToday: () => followToday = true,
      modeDescription: widget.selection.date == null ? '跟随今天' : '固定日期',
    );
    if (!mounted) return;
    if (followToday) {
      widget.selection.select(null);
    } else if (selected != null) {
      widget.selection.select(selected);
    } else {
      controller.refresh();
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    tabs.removeListener(_onTabChanged);
    tabs.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.dateOfInstant(widget.now());
    final onTimeline = tabs.index == 0;
    // Ambient app theme (dark) still owns the pages that were not rebuilt.
    final appTheme = Theme.of(context);
    return Theme(
      data: homeTheme,
      child: PopScope(
        canPop: onTimeline,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) tabs.animateTo(0);
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Short viewports drop the header coverage; the summary tab keeps it.
                final tight = constraints.maxHeight < 520;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeTopBar(
                            busy: widget.busy,
                            onMenu: widget.onMenu,
                            onChooseDate: _chooseDate,
                          ),
                          ?widget.banner,
                          ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) {
                              final date = controller.date;
                              final view = controller.view;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (date != null)
                                    HomeDateTitle(
                                      date: date,
                                      today: today,
                                      busy: widget.busy,
                                      onChooseDate: _chooseDate,
                                      compact: tight,
                                    ),
                                  if (!tight && view != null)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        10,
                                        20,
                                        6,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          HomeCoverageLine(view: view),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              TextButton(
                                                key: const ValueKey(
                                                  'home-distribution',
                                                ),
                                                onPressed: widget.busy
                                                    ? null
                                                    : showDistribution,
                                                child: const Text('时间分布说明'),
                                              ),
                                              const Spacer(),
                                              TextButton(
                                                key: const ValueKey(
                                                  'home-refresh',
                                                ),
                                                onPressed: widget.busy
                                                    ? null
                                                    : refreshFromMenu,
                                                child: const Text('刷新账本'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.5,
                      child: TabBar(
                        controller: tabs,
                        tabs: const [
                          Tab(key: ValueKey('home-tab-timeline'), text: '时间线'),
                          Tab(key: ValueKey('home-tab-summary'), text: '摘要'),
                          Tab(key: ValueKey('home-tab-review'), text: '复盘'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity < -200 && tabs.index < 2) {
                                  tabs.animateTo(tabs.index + 1);
                                } else if (velocity > 200 && tabs.index > 0) {
                                  tabs.animateTo(tabs.index - 1);
                                }
                              },
                              child: IndexedStack(
                                index: tabs.index,
                                children: [
                                  Offstage(
                                    offstage: tabs.index != 0,
                                    child: widget.timeline(
                                      controller,
                                      tabs.index == 0,
                                    ),
                                  ),
                                  Offstage(
                                    offstage: tabs.index != 1,
                                    child: widget.summary(
                                      controller,
                                      tabs.index == 1,
                                    ),
                                  ),
                                  Offstage(
                                    offstage: tabs.index != 2,
                                    child: widget.reviewEnabled
                                        ? Theme(
                                            data: appTheme,
                                            child: widget.review(
                                              tabs.index == 2,
                                            ),
                                          )
                                        : const _PlaceholderTab('复盘留待后续设计。'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Floats above the action bar without joining the
                          // timeline's scroll extent, so it never pushes the
                          // action bar off screen or changes the reading
                          // surface's viewport (which would move the anchor).
                          if (widget.floatingCard != null && tabs.index == 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: MediaQuery.withClampedTextScaling(
                                maxScaleFactor: 1.3,
                                child: ListenableBuilder(
                                  listenable: controller,
                                  builder: (context, _) =>
                                      widget.floatingCard!(controller),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomNavigationBar: _HomeBottomBar(
            busy: widget.busy,
            onRecordSleep: widget.onRecordSleep,
            onRecordActivity: widget.onRecordActivity,
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: Theme.of(context).textTheme.bodyMedium));
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
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Material(
      color: HomePalette.paper,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HomePalette.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: OutlinedButton.icon(
                    key: const ValueKey('home-record-sleep'),
                    onPressed: busy ? null : onRecordSleep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.bedtime_outlined, size: 20),
                    label: const Text('记录睡眠', maxLines: 1, softWrap: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: FilledButton.icon(
                    key: const ValueKey('home-record-activity'),
                    onPressed: busy ? null : onRecordActivity,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('记录一笔', maxLines: 1, softWrap: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
