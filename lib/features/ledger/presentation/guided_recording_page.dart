import 'package:flutter/material.dart';

import '../../goals/domain/goal_status.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/projection/derived_duration.dart';
import '../domain/rhythm_state.dart';
import 'guided_recording_sheets.dart';
import 'recording_time_picker.dart';
import 'recording_form_controller.dart';
import 'sleep_time_input.dart';
import 'summary_formatting.dart';

enum RecordingInputMode { guided, form }

/// Navigation belongs to presentation, never to TimeBlock or RecordingDraft.
class GuidedRecordingNavigation extends ChangeNotifier {
  int step = 0;
  int? returnTo;
  void editAnswer(int value) {
    if (value < step) returnTo = step;
    step = value;
    notifyListeners();
  }

  void next() {
    step = returnTo ?? (step + 1).clamp(0, 2);
    returnTo = null;
    notifyListeners();
  }

  void previous() {
    step = (step - 1).clamp(0, 2);
    returnTo = null;
    notifyListeners();
  }
}

/// Fresh presentation; both input modes share the existing input/save session.
class GuidedRecordingPage extends StatefulWidget {
  const GuidedRecordingPage({
    super.key,
    required this.model,
    required this.navigation,
    required this.onSaved,
    required this.onExit,
    this.mode = RecordingInputMode.guided,
    this.createGoal,
  });
  final RecordingFormController model;
  final GuidedRecordingNavigation navigation;
  final RecordingInputMode mode;
  final RecordingGoalCreator? createGoal;
  final VoidCallback onSaved;
  final VoidCallback onExit;
  @override
  State<GuidedRecordingPage> createState() => _GuidedRecordingPageState();
}

class _GuidedRecordingPageState extends State<GuidedRecordingPage> {
  RecordingFormController get model => widget.model;
  GuidedRecordingNavigation get flow => widget.navigation;
  late final title = TextEditingController(text: model.title);
  final scroll = ScrollController();
  bool errors = false;
  bool leaving = false;

  @override
  void initState() {
    super.initState();
    model.addListener(changed);
    flow.addListener(navigated);
  }

  void changed() {
    if (title.text != model.title) title.text = model.title;
    if (mounted) setState(() {});
  }

  void navigated() {
    FocusScope.of(context).unfocus();
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() => errors = false);
  }

  @override
  void dispose() {
    model.removeListener(changed);
    flow.removeListener(navigated);
    title.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> goal() async {
    FocusScope.of(context).unfocus();
    final choice = await showGuidedGoalSheet(
      context,
      model: model,
      createGoal: widget.createGoal,
    );
    if (!mounted || choice == null) return;
    if (choice.created) {
      await model.associateCreatedGoal(choice.id);
    } else {
      model.selectGoal(choice.id);
    }
  }

  Future<void> time({bool isStart = true, bool isDate = false}) async {
    final picker = isDate ? showRecordingDatePicker : showRecordingTimePicker;
    final value = await picker(
      context,
      value: isStart ? model.time.startedAt : model.time.endedAt,
      date: model.context.date,
    );
    if (!mounted || value == null) return;
    model.setTime(
      start: isStart ? value : model.time.startedAt,
      end: isStart ? model.time.endedAt : value,
    );
  }

  Future<void> details() async {
    final result = await showGuidedDetailsSheet(context, model);
    if (!mounted || result == null) return;
    model.setNote(result.note);
    if (model.rhythmState != null) model.setContinuationHint(result.hint);
    if (model.rhythmState == RhythmState.stuck) {
      model.setStuckReasonCode(result.reason);
      model.setStuckReasonText(result.reasonText);
    }
    if (model.rhythmState == RhythmState.recovery) {
      model.setRecoveryMethod(result.method);
      model.setRecoveryQuality(result.quality);
    }
  }

  void next() {
    if (flow.step == 1 && model.titleError != null) {
      setState(() => errors = true);
      return;
    }
    flow.next();
  }

  Future<void> save() async {
    if (!model.editable) return;
    if (model.titleError != null && widget.mode == RecordingInputMode.guided) {
      flow.editAnswer(1);
    }
    setState(() => errors = true);
    if (!model.valid) return;
    FocusScope.of(context).unfocus();
    await model.submit();
    if (!mounted) return;
    if (model.committed?.complete == true) {
      widget.onSaved();
    } else if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  Future<void> finish() async {
    await model.retryFinish();
    if (mounted && model.committed?.complete == true) widget.onSaved();
  }

  Future<void> leave() async {
    if (leaving || model.submitting || model.discarding) return;
    leaving = true;
    FocusScope.of(context).unfocus();
    final okay = await model.flush();
    leaving = false;
    if (mounted && okay) widget.onExit();
  }

  Future<void> discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('放弃这份草稿？'),
        content: const Text('未保存的内容将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续填写'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃草稿'),
          ),
        ],
      ),
    );
    if (yes == true && mounted && await model.discard() && mounted) {
      widget.onExit();
    }
  }

  Widget message(String text, {Widget? action}) => Card.filled(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(text), ?action],
      ),
    ),
  );
  Widget question(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 20),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );

  Widget goalBar() => Card.outlined(
    key: const ValueKey('guided-goal-bar'),
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('关联目标', style: Theme.of(context).textTheme.labelLarge),
          Text(
            model.goalId == null
                ? '尚未关联'
                : model.selectedGoal?.name ?? '目标信息暂不可用',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (model.selectedGoal?.status == GoalStatus.archived)
            const Text('已归档 · 保留本笔原关联'),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: model.editable ? goal : null,
                icon: const Icon(Icons.flag_outlined),
                label: Text(model.goalId == null ? '关联目标' : '更换'),
              ),
              if (model.goalId != null)
                TextButton(
                  onPressed: model.editable ? model.clearGoal : null,
                  child: const Text('取消关联'),
                ),
            ],
          ),
          if (model.goalsLoading) const LinearProgressIndicator(),
          if (model.goalsError != null) ...[
            Text(model.goalsError!),
            TextButton(onPressed: model.loadGoals, child: const Text('重试读取目标')),
          ],
        ],
      ),
    ),
  );

  Widget rhythmQuestion() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      question('这段时间，节奏怎么样？'),
      for (final state in RhythmState.values)
        Card.outlined(
          margin: const EdgeInsets.only(bottom: 12),
          color: model.rhythmState == state
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: InkWell(
            key: ValueKey('guided-rhythm-${state.name}'),
            borderRadius: BorderRadius.circular(12),
            onTap: model.editable
                ? () => model.setRhythmState(
                    model.rhythmState == state ? null : state,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(switch (state) {
                    RhythmState.progress => Icons.arrow_forward,
                    RhythmState.stuck => Icons.pause,
                    RhythmState.recovery => Icons.spa_outlined,
                  }),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guidedRhythmLabel(state),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(switch (state) {
                          RhythmState.progress => '确认这件事向前走了一点',
                          RhythmState.stuck => '想推进，但遇到了阻力',
                          RhythmState.recovery => '让自己缓一缓，能够继续',
                        }),
                      ],
                    ),
                  ),
                  if (model.rhythmState == state)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.check),
                    ),
                ],
              ),
            ),
          ),
        ),
      const Text('也可以直接继续。再次点击可取消选择。'),
    ],
  );

  Widget activityQuestion() {
    final unknown = model.knowledgeState == BlockKnowledgeState.unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        question(switch (model.rhythmState) {
          RhythmState.progress => '这段推进了什么？',
          RhythmState.stuck => '刚才在做哪件事时卡住了？',
          RhythmState.recovery => '这段怎么休息的？',
          null => '这段主要做了什么？',
        }),
        if (!unknown || model.titleError != null)
          TextField(
            key: const ValueKey('guided-activity'),
            controller: title,
            readOnly: !model.editable,
            minLines: 3,
            maxLines: 6,
            onChanged: model.setTitle,
            decoration: InputDecoration(
              hintText: '几个字也可以',
              errorText: errors ? model.titleError : null,
            ),
          ),
        if (unknown)
          const Card.filled(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('想不起来也可以记下这段时间。'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('guided-unknown'),
            onPressed: model.editable
                ? () {
                    FocusScope.of(context).unfocus();
                    model.setKnowledge(
                      unknown
                          ? BlockKnowledgeState.known
                          : BlockKnowledgeState.unknown,
                    );
                  }
                : null,
            icon: Icon(unknown ? Icons.edit_outlined : Icons.help_outline),
            label: Text(unknown ? '重新填写' : '想不起来'),
          ),
        ),
      ],
    );
  }

  Widget answerSummary() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (flow.step > 0)
        ActionChip(
          key: const ValueKey('guided-edit-rhythm'),
          label: Text('节奏：${guidedRhythmLabel(model.rhythmState)}'),
          onPressed: model.editable ? () => flow.editAnswer(0) : null,
        ),
      if (flow.step > 1)
        ActionChip(
          key: const ValueKey('guided-edit-activity'),
          label: Text(
            model.knowledgeState == BlockKnowledgeState.unknown
                ? '事项：想不起来'
                : '事项：${model.title}',
          ),
          onPressed: model.editable ? () => flow.editAnswer(1) : null,
        ),
    ],
  );

  Widget timeQuestion() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      question(
        model.time.startedAt == null || model.time.endedAt == null
            ? '这段是什么时候？'
            : '是这段时间吗？',
      ),
      if (model.candidates.isNotEmpty) ...[
        const Text('选择尚未记录的区间，或自行调整。'),
        for (final candidate in model.candidates)
          Card.outlined(
            child: ListTile(
              title: Text(
                '${formatSleepTime(candidate.startedAt)}\n${formatSleepTime(candidate.endedAt)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: model.editable
                  ? () => model.chooseCandidate(candidate)
                  : null,
            ),
          ),
      ],
      for (final isStart in [true, false])
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: RecordingEndpointFields(
              label: isStart ? '开始' : '结束',
              keyPrefix: isStart ? 'guided-start' : 'guided-end',
              value: isStart ? model.time.startedAt : model.time.endedAt,
              enabled: model.editable,
              onDate: () => time(isStart: isStart, isDate: true),
              onTime: () => time(isStart: isStart),
              precision: isStart
                  ? model.time.startPrecision
                  : model.time.endPrecision,
              onPrecision: (precision) => model.setPrecision(
                start: isStart ? precision : null,
                end: isStart ? null : precision,
              ),
            ),
          ),
        ),
      if (model.timeError == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '共 ${formatDerivedDuration(DerivedDuration(milliseconds: model.time.endedAt! - model.time.startedAt!, hasApproximation: true))}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      if (errors && model.timeError != null)
        Text(
          model.timeError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: model.editable ? details : null,
        icon: const Icon(Icons.notes_outlined),
        label: const Text('补充这笔记录'),
      ),
      if (model.rhythmState != null && model.continuationHint.trim().isNotEmpty)
        Text('接续点：${model.continuationHint}'),
      if (model.rhythmState == RhythmState.stuck &&
          model.stuckReasonCode != null)
        Text('原因：${reasonLabel(model.stuckReasonCode!)}'),
      if (model.rhythmState == RhythmState.stuck &&
          model.stuckReasonText.isNotEmpty)
        Text(model.stuckReasonText),
      if (model.rhythmState == RhythmState.recovery &&
          model.recoveryMethod != null)
        Text('恢复方式：${methodLabel(model.recoveryMethod!)}'),
      if (model.rhythmState == RhythmState.recovery &&
          model.recoveryQuality != null)
        Text('恢复感受：${qualityLabel(model.recoveryQuality!)}'),
      if (model.note.isNotEmpty) Text('备注：${model.note}'),
      if (errors &&
          (model.hintError ?? model.reasonError ?? model.noteError) != null)
        Text(
          '${model.hintError ?? model.reasonError ?? model.noteError} 请在补充中修改；保留的卡住原因可返回节奏选择卡住后修改。',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );

  Widget feedback() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.storageError != null)
        message(
          model.storageError!,
          action: TextButton(
            onPressed: model.editable ? model.retrySave : null,
            child: const Text('重试保留草稿'),
          ),
        ),
      if (model.submitError != null) message(model.submitError!),
      for (final conflict in model.conflicts)
        message(
          '已有记录：${formatSleepTime(conflict.startedAt)} — ${formatSleepTime(conflict.endedAt)}',
        ),
      if (model.committed != null)
        message(
          model.committed!.complete
              ? '已保存记录。'
              : '记录已经保存。${model.committed!.draftCleared ? '' : '草稿清理未完成。'}${model.committed!.refreshed == null ? '账本刷新未完成。' : ''}重试只会完成收尾。',
        ),
    ],
  );

  Widget footer() {
    final committed = model.committed != null;
    final button = FilledButton(
      key: const ValueKey('guided-primary'),
      onPressed: model.submitting
          ? null
          : committed
          ? (model.committed!.complete ? null : finish)
          : !model.editable
          ? null
          : model.conflicts.isNotEmpty
          ? time
          : widget.mode == RecordingInputMode.form || flow.step == 2
          ? save
          : next,
      child: Text(
        model.submitting
            ? '正在保存'
            : committed
            ? '重试收尾'
            : model.conflicts.isNotEmpty
            ? '调整时间'
            : widget.mode == RecordingInputMode.form || flow.step == 2
            ? '保存记录'
            : flow.returnTo != null
            ? '返回时间确认'
            : '继续',
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.mode == RecordingInputMode.guided &&
                flow.step > 0 &&
                !committed)
              TextButton(
                onPressed: model.editable ? flow.previous : null,
                child: const Text('上一步'),
              ),
            button,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: model.submitting ? null : leave,
          tooltip: '保留草稿并退出',
          icon: const Icon(Icons.close),
        ),
        title: const Text('记录活动'),
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (_) => discard(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'discard',
                enabled: model.editable || model.missingOriginal,
                child: const Text('放弃草稿'),
              ),
            ],
          ),
        ],
      ),
      body: model.loading
          ? const Center(child: CircularProgressIndicator())
          : model.loadError != null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(model.loadError!),
                if (!model.missingOriginal)
                  FilledButton(
                    onPressed: model.initialize,
                    child: const Text('重试读取'),
                  ),
                if (model.missingOriginal)
                  TextButton(onPressed: discard, child: const Text('清理失效草稿')),
                if (model.storageError != null) Text(model.storageError!),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (widget.mode == RecordingInputMode.guided)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${flow.step + 1} / 3 · ${['节奏', '事项', '时间'][flow.step]}',
                            key: const ValueKey('guided-step'),
                          ),
                        ),
                      goalBar(),
                      feedback(),
                      if (widget.mode == RecordingInputMode.guided) ...[
                        if (flow.step > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: answerSummary(),
                          ),
                        switch (flow.step) {
                          0 => rhythmQuestion(),
                          1 => activityQuestion(),
                          _ => timeQuestion(),
                        },
                      ] else ...[
                        rhythmQuestion(),
                        activityQuestion(),
                        timeQuestion(),
                      ],
                    ],
                  ),
                ),
                footer(),
              ],
            ),
    ),
  );
}

String guidedRhythmLabel(RhythmState? state) => switch (state) {
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '休息',
  null => '未选择',
};
