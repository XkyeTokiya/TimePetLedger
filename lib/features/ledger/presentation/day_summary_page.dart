import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../application/day_ledger_loader.dart';
import '../domain/projection/derived_duration.dart';
import 'day_ledger_controller.dart';
import 'day_date_selection.dart';
import 'recording_form.dart';
import 'summary_formatting.dart';
import 'sleep_summary_view.dart';
import 'goal_rhythm_summary_view.dart';

/// 摘要与日账本共用完整投影及读取状态；不查询草稿或重新计算摘要。
class DaySummaryPage extends StatefulWidget {
  const DaySummaryPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.routeObserver,
    this.initialDate,
    this.selection,
    this.reviewEntry,
  });

  final DayDateSelection? selection;
  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final CivilDate? initialDate;
  final Widget Function(CivilDate)? reviewEntry;

  @override
  State<DaySummaryPage> createState() => _DaySummaryPageState();
}

class _DaySummaryPageState extends State<DaySummaryPage>
    with WidgetsBindingObserver, RouteAware {
  late final controller = DayLedgerController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: widget.selection?.date ?? widget.initialDate,
  );
  final dateText = TextEditingController();
  bool invalidDate = false;
  bool openingEntry = false;
  ModalRoute<void>? route;

  void _syncDate() {
    final date = controller.date;
    if (date != null) {
      dateText.text =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
  }

  void _refresh() {
    if (invalidDate) return;
    if (widget.selection case final selection?) {
      controller.selectedDate = selection.date;
    }
    controller.refresh();
    _syncDate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.selection?.addListener(_refresh);
    _refresh();
  }

  void _select(CivilDate? date) {
    if (widget.selection case final selection?) {
      selection.select(date);
    } else {
      controller.select(date);
    }
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

  Future<void> _openReview() async {
    final date = controller.date;
    final entry = widget.reviewEntry;
    if (openingEntry || invalidDate || date == null || entry == null) return;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && route?.isCurrent == true) {
      _refresh();
    }
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.selection?.removeListener(_refresh);
    controller.dispose();
    dateText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('基础摘要')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: dateText,
            decoration: InputDecoration(
              labelText: '摘要日期 YYYY-MM-DD',
              errorText: invalidDate ? '请输入有效日期 YYYY-MM-DD。' : null,
            ),
            onChanged: (value) {
              final date = parseRecordingDate(value);
              setState(() => invalidDate = date == null);
              if (date == null) {
                controller.invalidate();
              } else {
                _select(date);
              }
            },
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => invalidDate = false);
                  _select(null);
                  _syncDate();
                },
                child: const Text('今天'),
              ),
              OutlinedButton(
                onPressed: invalidDate ? null : _refresh,
                child: const Text('刷新摘要'),
              ),
              if (widget.reviewEntry != null)
                FilledButton(
                  onPressed:
                      invalidDate || openingEntry || controller.date == null
                      ? null
                      : _openReview,
                  child: const Text('打开此日复盘'),
                ),
            ],
          ),
          if (!invalidDate && controller.date != null)
            Text('日期：${dateText.text}'),
          if (controller.status == DayLedgerStatus.loading)
            const Center(child: CircularProgressIndicator()),
          if (controller.status == DayLedgerStatus.failed) ...[
            const Text('摘要读取失败，请重试。'),
            TextButton(onPressed: _refresh, child: const Text('重试读取')),
          ],
          if (controller.view case final view?) ...[
            Text(
              controller.status == DayLedgerStatus.empty
                  ? '此账本窗口及醒来日期尚无正式记录。'
                  : '摘要已读取。',
            ),
            Text(
              '账本窗口：${formatDerivedDuration(DerivedDuration(milliseconds: view.window.milliseconds, hasApproximation: false))}',
            ),
            const SizedBox(height: 16),
            const Text('账本覆盖'),
            Text('已交代：${formatDerivedDuration(view.accountedDuration)}'),
            Text('其中未知：${formatDerivedDuration(view.unknownDuration)}'),
            const Text('未知已包含在已交代时间中。'),
            Text('尚未记录：${formatDerivedDuration(view.unresolvedDuration)}'),
            if (view.window.isEmpty)
              const Text('当前账本窗口为空，不产生未记录缺口。')
            else if (view.unresolvedDuration.milliseconds == 0)
              const Text('此账本窗口没有未记录缺口。'),
            const SizedBox(height: 16),
            const Text('睡眠背景'),
            const Text('按所选日期的醒来日期汇总完整睡眠；账本覆盖仅计窗口内贡献。'),
            SleepSummaryView(summary: view.sleepSummary),
            const SizedBox(height: 16),
            GoalRhythmSummaryView(
              goals: view.goalSummaries,
              rhythm: view.rhythmSummary,
            ),
          ],
        ],
      ),
    ),
  );
}
