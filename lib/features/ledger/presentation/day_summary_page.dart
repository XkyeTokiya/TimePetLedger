import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../application/day_ledger_loader.dart';
import '../domain/sleep_session.dart';
import 'day_ledger_controller.dart';
import 'day_ledger_date_dialog.dart';
import 'day_page_header.dart';
import 'home/home_summary_tab.dart';

/// 独立「当日摘要」页。
///
/// 从首页进入时继承当时的浏览日期；进入后独立管理日期，返回首页不改变
/// 首页的日期与阅读位置。数据仍来自与时间轴同一次单日投影，不另算统计。
class DaySummaryPage extends StatefulWidget {
  const DaySummaryPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.routeObserver,
    required this.initialDate,
    this.reviewEntry,
    this.onEditSleep,
  });

  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final CivilDate initialDate;

  /// 打开该日复盘的入口；为空时不显示。
  final Widget Function(CivilDate date)? reviewEntry;
  final void Function(CivilDate date, SleepSession sleep)? onEditSleep;

  @override
  State<DaySummaryPage> createState() => _DaySummaryPageState();
}

class _DaySummaryPageState extends State<DaySummaryPage>
    with WidgetsBindingObserver, RouteAware {
  late final controller = DayLedgerController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: widget.initialDate,
  );
  bool openingEntry = false;
  bool selectingDate = false;
  ModalRoute<void>? route;

  CivilDate get _today => widget.dateOfInstant(widget.now());

  void _refresh() => controller.refresh();

  Future<void> _chooseDate() async {
    if (openingEntry || selectingDate) return;
    setState(() => selectingDate = true);
    CivilDate? picked;
    try {
      picked = await showDayLedgerDateDialog(
        context,
        controller.date ?? widget.initialDate,
      );
    } finally {
      // 弹窗关闭即恢复可点，不等待随后的一次读取。
      if (mounted) setState(() => selectingDate = false);
    }
    if (!mounted || picked == null) return;
    await controller.select(picked);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context);
    if (route != current) {
      widget.routeObserver.unsubscribe(this);
      route = current;
      if (current != null) widget.routeObserver.subscribe(this, current);
    }
  }

  @override
  void didPopNext() {
    if (!openingEntry) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && route?.isCurrent == true) {
      _refresh();
    }
  }

  Future<void> _openReview() async {
    final date = controller.date;
    final entry = widget.reviewEntry;
    if (openingEntry || date == null || entry == null) return;
    setState(() => openingEntry = true);
    try {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => entry(date)));
    } finally {
      if (mounted) {
        setState(() => openingEntry = false);
        _refresh();
      }
    }
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('当日摘要')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => DayPageHeader(
              date: controller.date ?? widget.initialDate,
              today: _today,
              busy: openingEntry || selectingDate,
              dateKey: const ValueKey('summary-date'),
              onChoose: _chooseDate,
              onToday: () => controller.select(_today),
            ),
          ),
          Expanded(
            child: HomeSummaryTab(
              controller: controller,
              onEditSleep: widget.onEditSleep == null || controller.date == null
                  ? null
                  : (sleep) => widget.onEditSleep!(controller.date!, sleep),
              onRetry: _refresh,
              footer: widget.reviewEntry == null
                  ? null
                  : TextButton.icon(
                      key: const ValueKey('summary-open-review'),
                      onPressed: openingEntry || controller.date == null
                          ? null
                          : _openReview,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('打开这一天的复盘'),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
