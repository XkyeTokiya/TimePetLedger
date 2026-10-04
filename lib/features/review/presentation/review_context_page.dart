import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal_status.dart';
import '../../goals/domain/goal_repository.dart';
import '../domain/review_draft_store.dart';
import 'review_form.dart';
import 'review_form_controller.dart';
import 'review_facts_view.dart';
import '../../ledger/presentation/recording_form.dart' show parseRecordingDate;
import '../application/review_context_loader.dart';
import '../application/review_entry_saver.dart';
import 'review_context_controller.dart';
import '../../ledger/presentation/day_date_selection.dart';
import '../../ledger/presentation/day_read_scroll.dart';
import '../../ledger/presentation/day_ledger_date_dialog.dart';
import '../../ledger/presentation/ledger_date_header.dart';

String _dateText(CivilDate date) =>
    '${date.year < 0 ? '-' : ''}${date.year.abs().toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class ReviewContextPage extends StatefulWidget {
  const ReviewContextPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.initialDate,
    required this.routeObserver,
    this.selection,
    this.embedded = false,
    this.active = true,
    this.scrollSession,
    this.onInteraction,
    this.drafts,
    this.saver,
    this.goals,
  });

  final DayDateSelection? selection;
  final bool embedded;
  final bool active;
  final DayReadScrollSession? scrollSession;
  final ValueChanged<bool>? onInteraction;
  final ReviewDraftStore? drafts;
  final ReviewEntrySaver? saver;
  final GoalRepository? goals;
  final ReviewContextLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;
  final CivilDate initialDate;
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  State<ReviewContextPage> createState() => _ReviewContextPageState();
}

class _ReviewContextPageState extends State<ReviewContextPage>
    with WidgetsBindingObserver, RouteAware {
  late final controller = ReviewContextController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: widget.initialDate,
  );
  late final dateText = TextEditingController(
    text: _dateText(widget.initialDate),
  );
  bool invalidDate = false;
  bool openingEntry = false;
  ModalRoute<void>? route;

  void _refresh() {
    if (!widget.active || invalidDate) return;
    if (widget.selection case final selection?) {
      controller.selectedDate =
          selection.date ?? widget.dateOfInstant(widget.now());
      dateText.text = _dateText(controller.selectedDate);
    }
    controller.refresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.selection?.addListener(_selectionChanged);
    _refresh();
  }

  void _selectionChanged() {
    invalidDate = false;
    _refresh();
  }

  @override
  void didUpdateWidget(ReviewContextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _refresh();
  }

  void _select(CivilDate? date) {
    if (widget.selection case final selection?) {
      selection.select(date);
    } else {
      controller.select(date ?? widget.dateOfInstant(widget.now()));
    }
  }

  Future<void> _chooseDate({bool manual = false}) async {
    if (openingEntry) return;
    widget.onInteraction?.call(true);
    setState(() => openingEntry = true);
    try {
      final date = await showDayLedgerDateDialog(
        context,
        controller.selectedDate,
        manual: manual,
      );
      if (mounted && date != null) _select(date);
    } finally {
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
      }
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
    dateText.dispose();
    super.dispose();
  }

  Future<void> _openForm(ReviewContext loaded) async {
    if (openingEntry) return;
    widget.onInteraction?.call(true);
    setState(() => openingEntry = true);
    final review = loaded.review;
    final form = ReviewFormController(
      context: review == null
          ? ReviewDraftContext.newEntry(date: loaded.ledger.date)
          : ReviewDraftContext.edit(reviewId: review.id),
      store: widget.drafts!,
      entrySaver: widget.saver,
      original: review,
      originalGoal: loaded.firstStepGoal,
      goals: widget.goals,
    );
    try {
      final savedDate = await Navigator.of(context).push<CivilDate>(
        MaterialPageRoute<CivilDate>(
          builder: (_) => ReviewForm(
            controller: form,
            loader: widget.loader,
            now: widget.now,
            dateOfInstant: widget.dateOfInstant,
          ),
        ),
      );
      if (savedDate != null && mounted) {
        setState(() {
          invalidDate = false;
          dateText.text = _dateText(savedDate);
        });
        _select(savedDate);
      }
    } finally {
      await form.flush();
      form.dispose();
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded ? null : AppBar(title: const Text('按日复盘')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => DayReadScrollView(
        date: controller.selectedDate,
        destination: 'review',
        session: widget.scrollSession,
        active: widget.active,
        ready: controller.context != null,
        children: [
          if (widget.embedded) ...[
            LedgerDateHeader(
              date: controller.selectedDate,
              today: widget.dateOfInstant(widget.now()),
              followToday: widget.selection?.date == null,
              busy: openingEntry,
              onChoose: () => _chooseDate(),
              onSelect: _select,
            ),
            TextButton(
              onPressed: openingEntry ? null : () => _chooseDate(manual: true),
              child: const Text('手动输入日期'),
            ),
          ] else
            TextField(
              controller: dateText,
              decoration: InputDecoration(
                labelText: '复盘日期 YYYY-MM-DD',
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
                  dateText.text = _dateText(controller.selectedDate);
                },
                child: const Text('今天'),
              ),
              OutlinedButton(
                onPressed: invalidDate ? null : _refresh,
                child: const Text('刷新复盘上下文'),
              ),
            ],
          ),
          if (controller.status == ReviewReadStatus.loading)
            const Center(child: CircularProgressIndicator()),
          if (controller.status == ReviewReadStatus.failed) ...[
            const Text('复盘上下文读取失败，请重试。'),
            TextButton(onPressed: _refresh, child: const Text('重试读取')),
          ],
          if (controller.context case final loaded?) ...[
            if (loaded.review case final review?) ...[
              ReadScrollAnchor(
                id: review.id,
                order: 0,
                child: Text('已存复盘日期：${_dateText(review.date)}'),
              ),
              const Text('已有复盘'),
              const Text('当天概述'),
              Text(review.summary ?? '未填写概述'),
              const Text('反思'),
              Text(review.reflection ?? '未填写反思'),
              Text('下一自然日：${_dateText(review.tomorrowFirstStep.intendedDate)}'),
              const Text('明天第一步'),
              ReadScrollAnchor(
                id: (review.id, 'step'),
                order: 1,
                child: Text(review.tomorrowFirstStep.text),
              ),
              if (loaded.firstStepGoal case final goal?)
                Text(
                  '第一步目标：${goal.name}${goal.status == GoalStatus.archived ? '（已归档）' : ''}',
                ),
            ] else
              const Text('这一天尚无复盘。'),
            const SizedBox(height: 16),
            if (widget.drafts != null)
              FilledButton(
                onPressed: openingEntry ? null : () => _openForm(loaded),
                child: Text(loaded.review == null ? '填写复盘' : '编辑复盘草稿'),
              ),
            ReadScrollAnchor(
              id: 'facts',
              order: 2,
              child: ReviewFactsView(ledger: loaded.ledger),
            ),
          ],
        ],
      ),
    ),
  );
}
