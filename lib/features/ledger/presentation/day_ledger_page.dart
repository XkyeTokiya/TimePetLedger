import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../application/day_ledger_loader.dart';
import '../application/recording_entry_editor.dart';
import '../domain/projection/ledger_segment.dart';
import '../application/recording_ledger_loader.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/recording_draft_store.dart';
import '../domain/projection/sleep_summary.dart';
import 'day_ledger_controller.dart';
import 'day_ledger_date_dialog.dart';
import 'day_ledger_overview.dart';
import 'day_ledger_timeline.dart';
import 'day_date_selection.dart';
import 'day_read_scroll.dart';
import 'ledger_date_header.dart';

class DayLedgerPage extends StatefulWidget {
  const DayLedgerPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.routeObserver,
    this.initialDate,
    this.selection,
    this.embedded = false,
    this.active = true,
    this.scrollSession,
    this.onInteraction,
    this.reviewEntry,
    this.gapEntry,
    this.factEntry,
    this.recordingEditor,
    this.completeSleep,
  });
  final DayDateSelection? selection;
  final bool embedded;
  final bool active;
  final DayReadScrollSession? scrollSession;
  final ValueChanged<bool>? onInteraction;
  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final CivilDate? initialDate;
  final Widget Function(CivilDate)? reviewEntry;
  final Widget Function(RecordingDraftContext, UnresolvedSpan)? gapEntry;
  final Widget Function(CivilDate, LedgerSegment)? factEntry;
  final RecordingEntryEditor? recordingEditor;
  final Widget Function(CivilDate, SleepSummary)? completeSleep;

  @override
  State<DayLedgerPage> createState() => DayLedgerPageState();
}

class DayLedgerPageState extends State<DayLedgerPage>
    with WidgetsBindingObserver, RouteAware {
  late final controller = DayLedgerController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: widget.selection?.date ?? widget.initialDate,
  );
  bool selectingDate = false;
  bool openingEntry = false;
  ModalRoute<void>? route;
  bool deleting = false;
  String? deleteError;
  ({RecordingDraftContext context, RecordingDeleteCommitted result})?
  pendingDelete;
  bool get busy =>
      openingEntry || deleting || pendingDelete != null || selectingDate;

  void refreshFromMenu() {
    if (!busy) _refresh();
  }

  void showDistribution() {
    if (busy || controller.view == null || controller.dateContext == null) {
      return;
    }
    DayLedgerOverview.showExplanation(
      context,
      view: controller.view!,
      dateContext: controller.dateContext!,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.selection?.addListener(_selectionChanged);
    _refresh();
  }

  void _selectionChanged() {
    if (widget.active) _refresh();
  }

  @override
  void didUpdateWidget(DayLedgerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _refresh();
  }

  void _select(CivilDate? date) {
    if (widget.selection case final selection?) {
      selection.select(date);
    } else {
      controller.select(date);
    }
  }

  void _refresh() {
    if (!widget.active) return;
    if (widget.selection case final selection?) {
      controller.selectedDate = selection.date;
    }
    controller.refresh();
  }

  Future<void> _chooseDate({bool manual = false}) async {
    final date = controller.date;
    if (date == null || busy) return;
    widget.onInteraction?.call(true);
    setState(() => selectingDate = true);
    var followToday = false;
    final selected = await showDayLedgerDateDialog(
      context,
      date,
      manual: manual,
      onToday: () {
        followToday = true;
      },
      modeDescription: controller.selectedDate == null ? '跟随今天' : '固定日期',
    );
    if (!mounted) return;
    setState(() => selectingDate = false);
    widget.onInteraction?.call(false);
    if (followToday) {
      _select(null);
    } else if (selected != null) {
      _select(selected);
    } else {
      // 取消不改变选择模式，但回到读取页仍重读；跟随今天可以跨午夜。
      _refresh();
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
    if (!openingEntry && !deleting && !selectingDate) _refresh();
  }

  Future<void> _openReview() async {
    final date = controller.date;
    final entry = widget.reviewEntry;
    if (busy || date == null || entry == null) return;
    widget.onInteraction?.call(true);
    setState(() => openingEntry = true);
    try {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => entry(date)));
    } finally {
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
        _refresh();
      }
    }
  }

  Future<void> _openGap(UnresolvedSpan gap) async {
    final view = controller.view;
    final entry = widget.gapEntry;
    if (busy ||
        entry == null ||
        view == null ||
        !view.unresolvedSpans.contains(gap)) {
      return;
    }
    final draftContext = RecordingDraftContext.gap(
      date: view.date,
      startedAt: gap.startedAt,
      endedAt: gap.endedAt,
    );
    widget.onInteraction?.call(true);
    setState(() {
      openingEntry = true;
      deleteError = null;
    });
    try {
      final committed = await Navigator.of(context).push<RecordingLedger>(
        MaterialPageRoute<RecordingLedger>(
          builder: (_) => entry(draftContext, gap),
        ),
      );
      if (mounted && committed != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存到账本。')));
      }
    } finally {
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
        // 取消也重读；只接收提交状态，不把局部 RecordingLedger 冒充整日投影。
        _refresh();
      }
    }
  }

  Future<void> _openFact(LedgerSegment segment) async {
    final view = controller.view;
    final entry = widget.factEntry;
    if (busy ||
        entry == null ||
        view == null ||
        !view.segments.contains(segment)) {
      return;
    }
    widget.onInteraction?.call(true);
    setState(() {
      openingEntry = true;
      deleteError = null;
    });
    try {
      final committed = await Navigator.of(context).push<Object>(
        MaterialPageRoute<Object>(builder: (_) => entry(view.date, segment)),
      );
      if (mounted && committed != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('记录更改已应用。')));
      }
    } finally {
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
        _refresh();
      }
    }
  }

  Future<void> _deleteTimeBlock(TimeBlockSegment segment) async {
    final view = controller.view;
    final editor = widget.recordingEditor;
    if (busy ||
        editor == null ||
        view == null ||
        !view.segments.contains(segment)) {
      return;
    }
    final draftContext = RecordingDraftContext.edit(
      date: view.date,
      timeBlockId: segment.reference.id,
    );
    widget.onInteraction?.call(true);
    setState(() {
      deleting = true;
      deleteError = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('删除时间记录'),
          content: const Text('删除完整记录时，依附的节奏解释也会删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除记录'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await editor.delete(draftContext);
      if (!mounted) return;
      switch (result) {
        case RecordingDeleteFailed():
          setState(() => deleteError = '删除失败，记录未改变，请重试。');
        case RecordingDeleteCommitted():
          _showDeleteResult(draftContext, result);
      }
    } finally {
      if (mounted) {
        setState(() => deleting = false);
        widget.onInteraction?.call(busy);
        _refresh();
      }
    }
  }

  void _showDeleteResult(
    RecordingDraftContext draftContext,
    RecordingDeleteCommitted result,
  ) {
    setState(() {
      pendingDelete = result.complete
          ? null
          : (context: draftContext, result: result);
      deleteError = result.complete ? null : '记录已删除，但草稿清理或读取失败；请继续清理并刷新。';
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('记录已删除。')));
  }

  Future<void> _finishDelete() async {
    final pending = pendingDelete;
    final editor = widget.recordingEditor;
    if (pending == null || editor == null || deleting) return;
    widget.onInteraction?.call(true);
    setState(() => deleting = true);
    try {
      final result = await editor.finishDelete(
        context: pending.context,
        draftCleared: pending.result.draftCleared,
      );
      if (mounted) _showDeleteResult(pending.context, result);
    } finally {
      if (mounted) {
        setState(() => deleting = false);
        widget.onInteraction?.call(busy);
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
    widget.selection?.removeListener(_selectionChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            actions: [
              PopupMenuButton<String>(
                tooltip: '更多',
                onOpened: () => setState(() => selectingDate = true),
                onCanceled: () => setState(() => selectingDate = false),
                onSelected: (value) {
                  setState(() => selectingDate = false);
                  if (value == '刷新账本') {
                    refreshFromMenu();
                  } else if (value == '时间分布说明') {
                    showDistribution();
                  } else {
                    _openReview();
                  }
                },
                itemBuilder: (_) => [
                  for (final text in [
                    '刷新账本',
                    '时间分布说明',
                    if (widget.reviewEntry != null) '打开此日复盘',
                  ])
                    PopupMenuItem(value: text, child: Text(text)),
                ],
              ),
            ],
            title: Text(
              '日账本',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => DayReadScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        date: controller.date,
        destination: 'ledger',
        session: widget.scrollSession,
        active: widget.active,
        ready: controller.view != null,
        children: [
          if (controller.date != null) _dateHeader(context, controller.date!),
          if (controller.view != null && controller.dateContext != null) ...[
            DayLedgerOverview(
              compact: true,
              view: controller.view!,
              dateContext: controller.dateContext!,
            ),
          ],
          if (deleteError != null) Text(deleteError!),
          if (pendingDelete != null)
            TextButton(
              onPressed: deleting ? null : _finishDelete,
              child: const Text('继续清理并刷新'),
            ),
          if (controller.status == DayLedgerStatus.loading)
            const Center(child: CircularProgressIndicator()),
          if (controller.status == DayLedgerStatus.failed) ...[
            const Text('账本读取失败，请重试。'),
            TextButton(onPressed: _refresh, child: const Text('重试读取')),
          ],
          if (controller.status == DayLedgerStatus.empty)
            const Text('此账本窗口尚无正式记录。'),
          if (controller.view != null) ...[
            DayLedgerTimeline(
              onDetailsVisibilityChanged: (visible) {
                setState(() => openingEntry = visible);
                widget.onInteraction?.call(visible);
              },
              view: controller.view!,
              onEditFact: widget.factEntry == null || busy ? null : _openFact,
              onDeleteTimeBlock: widget.recordingEditor == null || busy
                  ? null
                  : _deleteTimeBlock,
              onFillGap: widget.gapEntry == null || busy ? null : _openGap,
            ),
            if (widget.completeSleep != null) ...[
              ExpansionTile(
                title: const Text('完整睡眠 · 按醒来日期'),
                tilePadding: EdgeInsets.zero,
                children: [
                  widget.completeSleep!(
                    controller.view!.date,
                    controller.view!.sleepSummary,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _dateHeader(BuildContext context, CivilDate date) => LedgerDateHeader(
    compact: true,
    date: date,
    today: widget.dateOfInstant(controller.dateContext?.now ?? widget.now()),
    followToday: controller.selectedDate == null,
    busy: busy,
    onChoose: () => _chooseDate(),
    onSelect: _select,
  );
}
