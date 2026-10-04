import 'package:flutter/material.dart';

import '../../../core/widgets/editor_body.dart';
import '../../ledger/presentation/recording_optional_section.dart';

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
  final stepFocus = FocusNode();
  final summaryFocus = FocusNode();
  final reflectionFocus = FocusNode();
  bool writing = false;
  bool showErrors = false;
  FocusNode? lastWritingFocus;

  Future<void> _date() async {
    final input = TextEditingController(text: date.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改日期'),
        content: TextField(
          key: const ValueKey('review-date'),
          controller: input,
          enabled: model.editable,
          decoration: InputDecoration(
            labelText: '复盘日期 YYYY-MM-DD',
            errorText: model.dateError,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('应用日期'),
          ),
        ],
      ),
    );
    if (mounted && result != null) {
      date.text = result;
      model.setDateInput(result);
    }
    // The route may still be animating its TextField out.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
  }

  void _focus(FocusNode node) {
    lastWritingFocus = node;
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) {
        Scrollable.ensureVisible(node.context!, alignment: .2);
      }
    });
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.addListener(_changed);
    facts.addListener(_factsChanged);
    model.initialize();
    for (final node in [stepFocus, summaryFocus, reflectionFocus]) {
      node.addListener(_focusChanged);
    }
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
    setState(() {
      showErrors = true;
      if (model.summaryError != null || model.reflectionError != null) {
        writing = true;
      }
    });
    final result = finish ? await model.retryFinish() : await model.submit();
    if (mounted && result == null && model.firstStepError != null) {
      _focus(stepFocus);
    }
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
    stepFocus.dispose();
    summaryFocus.dispose();
    reflectionFocus.dispose();
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
        title: Text(model.context.isEditing ? '编辑复盘' : '填写复盘'),
        leading: BackButton(onPressed: _leave),
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == '删除复盘') {
                _delete();
              } else {
                _leave(discard: value == '放弃此复盘草稿');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled:
                    !model.loading &&
                    !model.discarding &&
                    !model.leaving &&
                    !model.submitting &&
                    !closing,
                value: '保留草稿并返回',
                child: Text(
                  model.committed != null || model.deleted != null
                      ? '返回复盘读取'
                      : '保留草稿并返回',
                ),
              ),
              PopupMenuItem(
                enabled: model.editable,
                value: '放弃此复盘草稿',
                child: const Text('放弃此复盘草稿'),
              ),
              if (model.context.isEditing &&
                  model.entrySaver != null &&
                  model.committed == null &&
                  model.deleted == null)
                PopupMenuItem(
                  enabled: model.editable && !closing && !confirmingDelete,
                  value: '删除复盘',
                  child: const Text('删除复盘'),
                ),
            ],
          ),
        ],
      ),
      body: EditorBody(
        status: model.storageError != null
            ? '草稿未保留'
            : model.saving
            ? '正在保留…'
            : model.committed != null
            ? '已保存'
            : model.deleted != null
            ? '已删除'
            : '尚未正式保存',
        action: FilledButton(
          onPressed: !model.submitting && !closing && model.deleted != null
              ? () => model.deleted!.complete
                    ? _pop(model.deleted!.original.date)
                    : _submit(finish: true)
              : !model.submitting && !closing && model.committed != null
              ? () => model.committed!.complete
                    ? _pop(model.committed!.review.date)
                    : _submit(finish: true)
              : model.editable && !closing && model.entrySaver != null
              ? _submit
              : null,
          child: Text(
            model.deleted != null
                ? (model.deleted!.complete ? '返回复盘读取' : '重试删除收尾')
                : model.committed != null
                ? (model.committed!.complete ? '返回已存复盘' : '重试复盘收尾')
                : model.submitting
                ? '正在保存…'
                : model.context.isEditing
                ? '保存更正'
                : '保存复盘',
          ),
        ),
        accessory:
            stepFocus.hasFocus ||
                summaryFocus.hasFocus ||
                reflectionFocus.hasFocus
            ? Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: stepFocus.hasFocus
                        ? null
                        : () => _focus(
                            reflectionFocus.hasFocus ? summaryFocus : stepFocus,
                          ),
                    child: const Text('上一项'),
                  ),
                  TextButton(
                    onPressed: reflectionFocus.hasFocus
                        ? null
                        : () {
                            setState(() => writing = true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _focus(
                                  stepFocus.hasFocus
                                      ? summaryFocus
                                      : reflectionFocus,
                                );
                              }
                            });
                          },
                    child: const Text('下一项'),
                  ),
                  TextButton(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: const Text('完成'),
                  ),
                ],
              )
            : null,
        children: [
          if (model.loading) const LinearProgressIndicator(),
          if (model.loadError case final error?) ...[
            Text(error),
            TextButton(
              onPressed: model.initialize,
              child: const Text('重试读取草稿'),
            ),
          ],
          Row(
            children: [
              Expanded(child: Text('复盘 · ${model.dateInput}')),
              TextButton(
                onPressed: model.editable ? _date : null,
                child: const Text('修改日期'),
              ),
            ],
          ),
          if (showErrors && model.dateError != null) Text(model.dateError!),
          if (model.intendedDate case final next?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('${next.month}月${next.day}日，先做什么？'),
            ),
          TextField(
            key: const ValueKey('review-step'),
            controller: step,
            focusNode: stepFocus,
            enabled: model.editable,
            minLines: 3,
            maxLines: null,
            style: const TextStyle(fontSize: 20, height: 1.6),
            decoration: InputDecoration(
              hintText: '明天第一步',
              errorText: showErrors ? model.firstStepError : null,
            ),
            onChanged: model.setFirstStep,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: model.editable
                ? () {
                    setState(() => writing = !writing);
                    if (writing) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _focus(summaryFocus);
                      });
                    }
                  }
                : null,
            child: Text(writing ? '收起补充文字' : '再写几句 ＋'),
          ),
          if (!writing &&
              (model.summary.isNotEmpty || model.reflection.isNotEmpty))
            Text(
              recordingDetailPreview('${model.summary}\n${model.reflection}'),
            ),
          if (writing || (showErrors && model.summaryError != null))
            TextField(
              key: const ValueKey('review-summary'),
              controller: summary,
              focusNode: summaryFocus,
              enabled: model.editable,
              minLines: 2,
              maxLines: null,
              decoration: InputDecoration(
                labelText: '当天概述',
                errorText: showErrors ? model.summaryError : null,
              ),
              onChanged: model.setSummary,
            ),
          if (writing || (showErrors && model.reflectionError != null))
            TextField(
              key: const ValueKey('review-reflection'),
              controller: reflection,
              focusNode: reflectionFocus,
              enabled: model.editable,
              minLines: 2,
              maxLines: null,
              decoration: InputDecoration(
                labelText: '反思',
                errorText: showErrors ? model.reflectionError : null,
              ),
              onChanged: model.setReflection,
            ),
          const SizedBox(height: 12),
          if (model.goalId != null)
            Text(
              model.goalId == null
                  ? ''
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
              if (model.goalId != null)
                TextButton(
                  onPressed: model.editable && model.goalId != null
                      ? model.clearGoal
                      : null,
                  child: const Text('清空目标关联'),
                ),
            ],
          ),
          if (model.storageError case final error?) ...[
            Text(error),
            TextButton(
              onPressed: model.editable ? model.retrySave : null,
              child: const Text('重试保存草稿'),
            ),
          ],
          if (model.submitError case final error?) Text(error),
          if (model.deletedMessage case final message?) Text(message),
          if (model.committedMessage case final message?) Text(message),
          if (model.submitting) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('查看当日事实'),
            onExpansionChanged: (open) {
              if (open) {
                lastWritingFocus =
                    [
                      stepFocus,
                      summaryFocus,
                      reflectionFocus,
                    ].where((node) => node.hasFocus).firstOrNull ??
                    lastWritingFocus;
                FocusManager.instance.primaryFocus?.unfocus();
              }
            },
            children: [
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
              TextButton(
                onPressed: () => _focus(lastWritingFocus ?? stepFocus),
                child: const Text('继续写作'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
