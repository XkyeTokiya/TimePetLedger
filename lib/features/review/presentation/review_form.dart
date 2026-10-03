import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal_status.dart';
import '../application/review_context_loader.dart';
import 'review_context_controller.dart';
import 'review_facts_view.dart';
import 'review_form_controller.dart';

/// Caller owns and disposes the form controller after the route has drained writes.
class ReviewForm extends StatefulWidget {
  const ReviewForm({
    super.key,
    required this.controller,
    required this.loader,
    required this.now,
    required this.dateOfInstant,
  });
  final ReviewFormController controller;
  final ReviewContextLoader loader;
  final int Function() now;
  final CivilDate Function(int) dateOfInstant;

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> with WidgetsBindingObserver {
  ReviewFormController get model => widget.controller;
  late final facts = ReviewContextController(
    loader: widget.loader,
    now: widget.now,
    dateOfInstant: widget.dateOfInstant,
    selectedDate: model.original?.date ?? model.context.entryDate!,
  );
  final date = TextEditingController();
  final summary = TextEditingController();
  final reflection = TextEditingController();
  final step = TextEditingController();
  bool synced = false;
  bool allowPop = false;
  bool closing = false;
  bool confirmingDelete = false;
  CivilDate? factsDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.addListener(_changed);
    facts.addListener(_factsChanged);
    model.initialize();
  }

  void _changed() {
    if (!mounted) return;
    if (!synced && !model.loading && model.loadError == null) {
      date.text = model.dateInput;
      summary.text = model.summary;
      reflection.text = model.reflection;
      step.text = model.firstStep;
      synced = true;
    }
    if (synced && factsDate != model.date) {
      factsDate = model.date;
      if (factsDate == null) {
        facts.invalidate();
      } else {
        facts.select(factsDate!);
      }
    }
    setState(() {});
  }

  void _factsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (synced && model.date != null) facts.refresh();
      model.loadGoals();
    }
  }

  Future<void> _leave({bool discard = false}) async {
    if (closing) return;
    final success = discard ? await model.discard() : await model.leave();
    if (!mounted || !success) return;
    await _pop(model.deleted?.original.date ?? model.committed?.review.date);
  }

  Future<void> _delete() async {
    if (closing ||
        confirmingDelete ||
        !model.editable ||
        model.original == null) {
      return;
    }
    setState(() => confirmingDelete = true);
    var answered = false;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          void answer(bool value) {
            if (answered) return;
            answered = true;
            Navigator.pop(context, value);
          }

          return AlertDialog(
            title: const Text('删除这份复盘？'),
            content: Text(
              '将删除 ${formatReviewDate(model.original!.date)} 的已存复盘和明天第一步，并清理其编辑草稿。当天时间记录和其他复盘保留。',
            ),
            actions: [
              TextButton(
                onPressed: () => answer(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => answer(true),
                child: const Text('确认删除'),
              ),
            ],
          );
        },
      );
      if (!mounted || closing || confirmed != true) return;
      final result = await model.deleteReview();
      if (mounted && result != null) await _pop(result.ledger.date);
    } finally {
      if (mounted) setState(() => confirmingDelete = false);
    }
  }

  Future<void> _submit({bool finish = false}) async {
    if (closing) return;
    final result = finish ? await model.retryFinish() : await model.submit();
    if (!mounted || result == null) return;
    await _pop(result.ledger.date);
  }

  Future<void> _pop(CivilDate? savedDate) async {
    if (closing) return;
    setState(() {
      allowPop = true;
      closing = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(savedDate);
  }

  Future<void> _chooseGoal() async {
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择下一步目标'),
        children: [
          if (model.activeGoals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无可选的活跃目标。'),
            ),
          for (final goal in model.activeGoals)
            ListTile(
              key: ValueKey('review-goal-option-${goal.id}'),
              title: Text(goal.name),
              subtitle:
                  model.activeGoals
                          .where((other) => other.name == goal.name)
                          .length >
                      1
                  ? Text('标识：${goal.id}')
                  : null,
              onTap: () => Navigator.pop(context, goal.id),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (mounted && id != null) model.selectGoal(id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_changed);
    facts.removeListener(_factsChanged);
    facts.dispose();
    date.dispose();
    summary.dispose();
    reflection.dispose();
    step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(model.context.isEditing ? '编辑复盘草稿' : '填写复盘'),
        leading: BackButton(onPressed: _leave),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (model.loading) const LinearProgressIndicator(),
          if (model.loadError case final error?) ...[
            Text(error),
            TextButton(
              onPressed: model.initialize,
              child: const Text('重试读取草稿'),
            ),
          ],
          if (model.restored &&
              model.committed == null &&
              model.deleted == null)
            const Text('已恢复未保存的复盘输入。'),
          Text(
            model.deleted != null
                ? '此复盘已删除。'
                : model.committed != null
                ? '此复盘已正式保存。'
                : '输入自动保留为草稿，尚未正式保存复盘。',
          ),
          TextField(
            key: const ValueKey('review-date'),
            controller: date,
            enabled: model.editable,
            decoration: InputDecoration(
              labelText: '复盘日期 YYYY-MM-DD',
              errorText: synced ? model.dateError : null,
            ),
            onChanged: model.setDateInput,
          ),
          if (model.intendedDate case final next?)
            Text('下一自然日：${formatReviewDate(next)}'),
          TextField(
            key: const ValueKey('review-summary'),
            controller: summary,
            enabled: model.editable,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(
              labelText: '当天概述（可选）',
              errorText: model.summaryError,
            ),
            onChanged: model.setSummary,
          ),
          TextField(
            key: const ValueKey('review-reflection'),
            controller: reflection,
            enabled: model.editable,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(
              labelText: '反思（可选）',
              errorText: model.reflectionError,
            ),
            onChanged: model.setReflection,
          ),
          TextField(
            key: const ValueKey('review-step'),
            controller: step,
            enabled: model.editable,
            minLines: 2,
            maxLines: null,
            decoration: InputDecoration(
              labelText: '明天第一步',
              errorText: synced ? model.firstStepError : null,
            ),
            onChanged: model.setFirstStep,
          ),
          const SizedBox(height: 12),
          Text(
            model.goalId == null
                ? '下一步目标：未关联（可选）'
                : model.selectedGoal == null
                ? '下一步目标：暂不可用（${model.goalId}）'
                : '下一步目标：${model.selectedGoal!.name}${model.selectedGoal!.status == GoalStatus.archived ? '（已归档）' : ''}',
          ),
          if (model.goalsLoading) const LinearProgressIndicator(),
          if (model.goalsError case final error?) ...[
            Text(error),
            TextButton(onPressed: model.loadGoals, child: const Text('重试读取目标')),
          ],
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed:
                    model.editable &&
                        model.goals != null &&
                        !model.goalsLoading &&
                        model.goalsError == null
                    ? _chooseGoal
                    : null,
                child: const Text('选择下一步目标'),
              ),
              TextButton(
                onPressed: model.editable && model.goalId != null
                    ? model.clearGoal
                    : null,
                child: const Text('清空目标关联'),
              ),
            ],
          ),
          if (model.saving) const Text('正在保留草稿…'),
          if (model.storageError case final error?) ...[
            Text(error),
            TextButton(
              onPressed: model.editable ? model.retrySave : null,
              child: const Text('重试保存草稿'),
            ),
          ],
          if (model.submitError case final error?) Text(error),
          if (model.deletedMessage case final message?) ...[
            Text(message),
            FilledButton(
              onPressed: !model.submitting && !closing
                  ? model.deleted!.complete
                        ? () => _pop(model.deleted!.original.date)
                        : () => _submit(finish: true)
                  : null,
              child: Text(model.deleted!.complete ? '返回复盘读取' : '重试删除收尾'),
            ),
          ] else if (model.committedMessage case final message?) ...[
            Text(message),
            FilledButton(
              onPressed: !model.submitting && !closing
                  ? model.committed!.complete
                        ? () => _pop(model.committed!.review.date)
                        : () => _submit(finish: true)
                  : null,
              child: Text(model.committed!.complete ? '返回已存复盘' : '重试复盘收尾'),
            ),
          ] else if (model.entrySaver != null)
            FilledButton(
              onPressed: model.editable && !closing ? _submit : null,
              child: Text(model.context.isEditing ? '保存更正' : '保存复盘'),
            ),
          if (model.context.isEditing &&
              model.entrySaver != null &&
              model.committed == null &&
              model.deleted == null)
            TextButton(
              onPressed: model.editable && !closing && !confirmingDelete
                  ? _delete
                  : null,
              child: const Text('删除复盘'),
            ),
          if (model.submitting) const LinearProgressIndicator(),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed:
                    !model.loading &&
                        !model.discarding &&
                        !model.leaving &&
                        !model.submitting &&
                        !closing
                    ? _leave
                    : null,
                child: Text(
                  model.committed == null && model.deleted == null
                      ? '保留草稿并返回'
                      : '返回复盘读取',
                ),
              ),
              TextButton(
                onPressed: model.editable ? () => _leave(discard: true) : null,
                child: const Text('放弃此复盘草稿'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: synced && model.date != null ? facts.refresh : null,
            child: const Text('刷新事实上下文'),
          ),
          if (facts.status == ReviewReadStatus.loading)
            const LinearProgressIndicator(),
          if (facts.status == ReviewReadStatus.failed)
            const Text('事实上下文读取失败，输入仍保留，请刷新重试。'),
          if (facts.context case final loaded?)
            ReviewFactsView(ledger: loaded.ledger),
        ],
      ),
    ),
  );
}
