import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../application/day_ledger_loader.dart';
import '../application/recording_entry_editor.dart';
import '../domain/projection/ledger_segment.dart';
import '../application/recording_ledger_loader.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/recording_draft_store.dart';
import 'day_ledger_controller.dart';
import 'day_ledger_timeline.dart';
import 'recording_form.dart';

String _dateText(CivilDate date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class DayLedgerPage extends StatefulWidget {
  const DayLedgerPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.routeObserver,
    this.initialDate,
    this.reviewEntry,
    this.gapEntry,
    this.factEntry,
    this.recordingEditor,
  });
  final DayLedgerLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final RouteObserver<ModalRoute<void>> routeObserver;
  final CivilDate? initialDate;
  final Widget Function(CivilDate)? reviewEntry;
  final Widget Function(RecordingDraftContext, UnresolvedSpan)? gapEntry;
  final Widget Function(CivilDate, LedgerSegment)? factEntry;
  final RecordingEntryEditor? recordingEditor;

  @override
  State<DayLedgerPage> createState() => _DayLedgerPageState();
}

class _DayLedgerPageState extends State<DayLedgerPage>
    with WidgetsBindingObserver, RouteAware {
  late final controller = DayLedgerController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: widget.initialDate,
  );
  final dateText = TextEditingController();
  bool invalidDate = false;
  bool openingEntry = false;
  ModalRoute<void>? route;
  bool deleting = false;
  String? deleteError;
  ({RecordingDraftContext context, RecordingDeleteCommitted result})?
  pendingDelete;
  bool get busy => openingEntry || deleting || pendingDelete != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  void _refresh() {
    if (invalidDate) return;
    controller.refresh();
    final date = controller.date;
    if (date != null) dateText.text = _dateText(date);
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
    if (!openingEntry && !deleting) _refresh();
  }

  Future<void> _openReview() async {
    final date = controller.date;
    final entry = widget.reviewEntry;
    if (busy || invalidDate || date == null || entry == null) return;
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
    controller.dispose();
    dateText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('日账本')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: dateText,
            decoration: InputDecoration(
              labelText: '账本日期',
              hintText: 'YYYY-MM-DD',
              errorText: invalidDate ? '请输入有效日期 YYYY-MM-DD。' : null,
            ),
            onChanged: (text) {
              final date = parseRecordingDate(text);
              setState(() => invalidDate = date == null);
              if (date == null) {
                controller.invalidate();
              } else {
                controller.select(date);
              }
            },
          ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => invalidDate = false);
                  controller.select(null);
                  final date = controller.date;
                  if (date != null) dateText.text = _dateText(date);
                },
                child: const Text('今天'),
              ),
              OutlinedButton(
                onPressed: invalidDate ? null : _refresh,
                child: const Text('刷新账本'),
              ),
              if (widget.reviewEntry != null)
                FilledButton(
                  onPressed: invalidDate || busy || controller.date == null
                      ? null
                      : _openReview,
                  child: const Text('打开此日复盘'),
                ),
            ],
          ),
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
            Text('日期：${_dateText(controller.view!.date)}'),
            if (controller.status == DayLedgerStatus.ready)
              const Text('日账本已读取。'),
            DayLedgerTimeline(
              view: controller.view!,
              onEditFact: widget.factEntry == null || busy ? null : _openFact,
              onDeleteTimeBlock: widget.recordingEditor == null || busy
                  ? null
                  : _deleteTimeBlock,
              onFillGap: widget.gapEntry == null || busy ? null : _openGap,
            ),
          ],
        ],
      ),
    ),
  );
}
