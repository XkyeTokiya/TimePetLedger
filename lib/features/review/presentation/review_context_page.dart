import 'package:flutter/material.dart';

import '../../../app/theme/home_theme.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal_repository.dart';
import '../../goals/domain/goal_status.dart';
import '../../ledger/presentation/day_ledger_date_dialog.dart';
import '../../ledger/presentation/day_page_header.dart';
import '../../ledger/presentation/day_read_scroll.dart';
import '../application/review_context_loader.dart';
import '../application/review_entry_saver.dart';
import '../domain/review_draft_store.dart';
import 'review_context_controller.dart';
import 'review_facts_view.dart';
import 'review_form.dart';
import 'review_form_controller.dart';

String _dateText(CivilDate date) =>
    '${date.year < 0 ? '-' : ''}${date.year.abs().toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 独立「每日复盘」页。
///
/// 从首页进入时继承当时的浏览日期；进入后独立管理日期，后台刷新、返回与
/// 恢复都不会改写正在阅读或编辑的日期。阅读、填写与保存分别使用既有
/// DailyReview 合同、本机草稿与真实保存动作，不使用演示态保存。
class ReviewContextPage extends StatefulWidget {
  const ReviewContextPage({
    super.key,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
    required this.initialDate,
    required this.routeObserver,
    this.scrollSession,
    this.onInteraction,
    this.drafts,
    this.saver,
    this.goals,
  });

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
  bool openingEntry = false;
  ModalRoute<void>? route;

  CivilDate get _today => widget.dateOfInstant(widget.now());

  void _refresh() => controller.refresh();

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

  Future<void> _chooseDate() async {
    if (openingEntry) return;
    widget.onInteraction?.call(true);
    setState(() => openingEntry = true);
    CivilDate? date;
    try {
      // 页头已提供“回到今天”，日历弹窗保持与既有账本日期弹窗一致的选项。
      date = await showDayLedgerDateDialog(context, controller.selectedDate);
    } finally {
      // 弹窗关闭即恢复可点，不等待随后的一次读取。
      if (mounted) {
        setState(() => openingEntry = false);
        widget.onInteraction?.call(false);
      }
    }
    if (!mounted || date == null) return;
    await controller.select(date);
  }

  @override
  void dispose() {
    widget.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
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
        await controller.select(savedDate);
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
    appBar: AppBar(title: const Text('每日复盘')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayPageHeader(
              date: controller.selectedDate,
              today: _today,
              busy: openingEntry,
              dateKey: const ValueKey('review-context-date'),
              onChoose: _chooseDate,
              onToday: () => controller.select(_today),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: openingEntry ? null : _refresh,
                child: const Text('刷新复盘上下文'),
              ),
            ),
            Expanded(
              child: DayReadScrollView(
                date: controller.selectedDate,
                destination: 'review',
                session: widget.scrollSession,
                ready: controller.context != null,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const Text('这一天，想留下什么？', style: _sectionStyle),
                  const SizedBox(height: 4),
                  const Text(
                    '几句话就好。',
                    style: TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 13,
                      height: 1.5,
                      color: HomePalette.muted,
                    ),
                  ),
                  if (controller.status == ReviewReadStatus.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (controller.status == ReviewReadStatus.failed) ...[
                    const SizedBox(height: 12),
                    const Text('复盘上下文读取失败，请重试。'),
                    TextButton(onPressed: _refresh, child: const Text('重试读取')),
                  ],
                  if (controller.context case final loaded?) ...[
                    const SizedBox(height: 12),
                    if (loaded.review case final review?) ...[
                      ReadScrollAnchor(
                        id: review.id,
                        order: 0,
                        child: Text(
                          '已存复盘日期：${_dateText(review.date)}',
                          style: _metaStyle,
                        ),
                      ),
                      const Text('已有复盘', style: _sectionStyle),
                      const SizedBox(height: 8),
                      const _FactLabel('当天概述'),
                      Text(review.summary ?? '未填写概述'),
                      const SizedBox(height: 10),
                      const _FactLabel('反思'),
                      Text(review.reflection ?? '未填写反思'),
                      const SizedBox(height: 10),
                      Text(
                        '下一自然日：${_dateText(review.tomorrowFirstStep.intendedDate)}',
                        style: _metaStyle,
                      ),
                      const _FactLabel('明天第一步'),
                      ReadScrollAnchor(
                        id: (review.id, 'step'),
                        order: 1,
                        child: Text(review.tomorrowFirstStep.text),
                      ),
                      if (loaded.firstStepGoal case final goal?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '第一步目标：${goal.name}'
                            '${goal.status == GoalStatus.archived ? '（已归档）' : ''}',
                            style: _metaStyle,
                          ),
                        ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('这一天尚无复盘。'),
                      ),
                    if (widget.drafts != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            key: const ValueKey('review-open-form'),
                            onPressed: openingEntry
                                ? null
                                : () => _openForm(loaded),
                            child: Text(
                              loaded.review == null ? '填写复盘' : '编辑复盘',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: const ValueKey('review-facts'),
                      initiallyExpanded: true,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text('回看当天记录', style: _sectionStyle),
                      children: [
                        ReadScrollAnchor(
                          id: 'facts',
                          order: 2,
                          child: ReviewFactsView(ledger: loaded.ledger),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FactLabel extends StatelessWidget {
  const _FactLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: HomePalette.muted,
      ),
    ),
  );
}

const _sectionStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);

const _metaStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  height: 1.5,
  color: HomePalette.muted,
);
