import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal_repository.dart';
import '../../goals/domain/goal_status.dart';
import '../application/recording_entry_saver.dart';
import '../application/recording_entry_editor.dart';
import '../application/recording_ledger_loader.dart';
import '../application/recording_time_suggestion.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/recording_draft_store.dart';
import '../domain/time_precision.dart';
import 'recording_form_controller.dart';
import 'recording_rhythm_input.dart';

String formatRecordingTime(int? value) {
  if (value == null) return '未填写';
  final d = DateTime.fromMillisecondsSinceEpoch(value);
  String two(int n) => n.toString().padLeft(2, '0');
  final year =
      '${d.year < 0 ? '-' : ''}${d.year.abs().toString().padLeft(4, '0')}';
  return '$year-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

CivilDate? parseRecordingDate(String value) {
  final m = RegExp(r'^(-?\d{4,6})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (m == null) return null;
  try {
    return CivilDate(
      year: int.parse(m.group(1)!),
      month: int.parse(m.group(2)!),
      day: int.parse(m.group(3)!),
    );
  } on ArgumentError {
    return null;
  }
}

/// 不设置历史/未来业务界限；严格拒绝构造器的日期进位和不存在的当地时间。
int? parseRecordingTime(String value) {
  final m = RegExp(r'^(-?\d{4,6})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$')
      .firstMatch(value.trim());
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 5; i++) int.parse(m.group(i)!)];
  try {
    final d = DateTime(parts[0], parts[1], parts[2], parts[3], parts[4]);
    if (d.year != parts[0] ||
        d.month != parts[1] ||
        d.day != parts[2] ||
        d.hour != parts[3] ||
        d.minute != parts[4]) {
      return null;
    }
    return d.millisecondsSinceEpoch;
  } on ArgumentError {
    return null;
  }
}

/// 日期时间选择对话框：只有确认的分钟值会应用到表单，取消不修改输入。
Future<int?> editRecordingTime(
  BuildContext context, {
  required String label,
  int? initial,
}) => showDialog<int>(
  context: context,
  builder: (_) => _RecordingTimeDialog(label: label, initial: initial),
);

class _RecordingTimeDialog extends StatefulWidget {
  const _RecordingTimeDialog({required this.label, this.initial});
  final String label;
  final int? initial;
  @override
  State<_RecordingTimeDialog> createState() => _RecordingTimeDialogState();
}

class _RecordingTimeDialogState extends State<_RecordingTimeDialog> {
  late final text = TextEditingController(
    text: widget.initial == null ? '' : formatRecordingTime(widget.initial),
  );
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    content: TextField(
      key: const ValueKey('time-dialog-input'),
      controller: text,
      autofocus: true,
      decoration: InputDecoration(
        labelText: '年-月-日 时:分',
        hintText: '2026-09-28 14:30',
        errorText: error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () {
          final parsed = parseRecordingTime(text.text);
          if (parsed == null) {
            setState(() => error = '请输入有效日期和时间，格式为 YYYY-MM-DD HH:mm。');
            return;
          }
          Navigator.pop(context, parsed);
        },
        child: const Text('确认'),
      ),
    ],
  );
}

class RecordingForm extends StatefulWidget {
  const RecordingForm({
    super.key,
    required this.context,
    required this.store,
    required this.loadSuggestion,
    this.entrySaver,
    this.entryEditor,
    this.goals,
  });
  final RecordingDraftContext context;
  final RecordingDraftStore store;
  final Future<RecordingTimeSuggestion> Function() loadSuggestion;
  final RecordingEntrySaver? entrySaver;
  final RecordingEntryEditor? entryEditor;
  final GoalRepository? goals;
  @override
  State<RecordingForm> createState() => _RecordingFormState();
}

class _RecordingFormState extends State<RecordingForm> {
  late final RecordingFormController model;
  final title = TextEditingController();
  final note = TextEditingController();
  final continuationHint = TextEditingController();
  final stuckReasonText = TextEditingController();
  bool allowPop = false;
  bool exiting = false;
  @override
  void initState() {
    super.initState();
    model = RecordingFormController(
      context: widget.context,
      store: widget.store,
      loadSuggestion: widget.loadSuggestion,
      entrySaver: widget.entrySaver,
      entryEditor: widget.entryEditor,
      goals: widget.goals,
    );
    model.addListener(_changed);
    _initialize();
  }

  Future<void> _initialize() async {
    await model.initialize();
    if (mounted) {
      title.text = model.title;
      note.text = model.note;
      continuationHint.text = model.continuationHint;
      stuckReasonText.text = model.stuckReasonText;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    title.dispose();
    note.dispose();
    continuationHint.dispose();
    stuckReasonText.dispose();
    super.dispose();
  }

  Future<void> _leave({bool discard = false}) async {
    if (exiting) return;
    if (model.submitting) return;
    setState(() => exiting = true);
    final success = model.committed != null
        ? true
        : discard
        ? await model.discard()
        : await model.flush();
    if (!mounted) return;
    if (!success) {
      setState(() => exiting = false);
      return;
    }
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(model.committed?.refreshed);
  }

  Future<void> _submit() async {
    final refreshed = await model.submit();
    if (mounted && refreshed != null) _complete(refreshed);
  }

  Future<void> _finish() async {
    final refreshed = await model.retryFinish();
    if (mounted && refreshed != null) _complete(refreshed);
  }

  Future<void> _complete(RecordingLedger refreshed) async {
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(refreshed);
  }

  Future<void> _time(bool start) async {
    final value = await editRecordingTime(
      context,
      label: start ? '开始时间' : '结束时间',
      initial: start ? model.time.startedAt : model.time.endedAt,
    );
    if (!mounted || value == null || !model.editable) return;
    model.setTime(
      start: start ? value : model.time.startedAt,
      end: start ? model.time.endedAt : value,
    );
  }

  Future<void> _chooseGoal() async {
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择目标'),
        children: [
          for (final goal in model.activeGoals)
            ListTile(
              key: ValueKey('goal-option-${goal.id}'),
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

  Widget _goalSection(BuildContext context) {
    final goal = model.selectedGoal;
    final archived = goal?.status == GoalStatus.archived;
    final retained = model.goalId == model.original?.goalId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('目标归属（可选）'),
        Text(
          model.goalId == null
              ? '未关联目标'
              : goal == null
              ? '当前目标：${model.goalId}（未能读取或已不存在）'
              : '${goal.name}${archived ? '（已归档）' : ''}',
          key: const ValueKey('selected-goal'),
        ),
        if (archived && !retained) const Text('此目标已归档，请重新选择或移除后保存。'),
        if (model.goalsLoading)
          const Text('正在读取目标…')
        else if (model.goalsError != null) ...[
          Text(model.goalsError!),
          TextButton(
            onPressed: model.editable ? model.loadGoals : null,
            child: const Text('重试读取目标'),
          ),
        ] else ...[
          if (model.activeGoals.isEmpty) const Text('暂无可选目标，可直接记录。'),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: model.editable && model.activeGoals.isNotEmpty
                    ? _chooseGoal
                    : null,
                child: const Text('选择目标'),
              ),
              TextButton(
                onPressed: model.editable ? model.loadGoals : null,
                child: const Text('刷新目标'),
              ),
            ],
          ),
        ],
        if (model.goalId != null)
          TextButton(
            onPressed: model.editable ? model.clearGoal : null,
            child: const Text('移除目标归属'),
          ),
        if (model.goalId != null)
          Container(
            key: const ValueKey('goal-time-confirmation'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              '请确认这段目标相关时间大致正确：\n'
              '${model.time.startPrecision == TimePrecision.approximate ? '约 ' : ''}'
              '${formatRecordingTime(model.time.startedAt)} → '
              '${model.time.endPrecision == TimePrecision.approximate ? '约 ' : ''}'
              '${formatRecordingTime(model.time.endedAt)}\n'
              '可在下方修改时间，大约时间也可以保存。',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.context.entry == RecordingDraftEntry.edit ? '更正记录' : '补一笔',
        ),
        leading: BackButton(onPressed: _leave),
      ),
      body: model.loading
          ? const Center(child: CircularProgressIndicator())
          : model.loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(model.loadError!),
                  TextButton(onPressed: _initialize, child: const Text('重试读取')),
                  if (model.missingOriginal) ...[
                    TextButton(
                      onPressed: () => _leave(discard: true),
                      child: const Text('清除编辑草稿并返回'),
                    ),
                    TextButton(
                      onPressed: () => _leave(),
                      child: const Text('返回账本'),
                    ),
                  ],
                  if (model.storageError != null) Text(model.storageError!),
                ],
              ),
            )
          : AbsorbPointer(
              absorbing: exiting || model.discarding || model.submitting,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    key: const ValueKey('activity'),
                    controller: title,
                    readOnly: !model.editable,
                    onChanged: model.setTitle,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: '刚才这段时间在做什么？',
                      errorText: model.titleError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('note'),
                    controller: note,
                    readOnly: !model.editable,
                    onChanged: model.setNote,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: '备注（可选）',
                      errorText: model.noteError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      ChoiceChip(
                        label: const Text('记得做了什么'),
                        selected:
                            model.knowledgeState == BlockKnowledgeState.known,
                        onSelected: model.editable
                            ? (_) =>
                                  model.setKnowledge(BlockKnowledgeState.known)
                            : null,
                      ),
                      ChoiceChip(
                        label: const Text('想不起来'),
                        selected:
                            model.knowledgeState == BlockKnowledgeState.unknown,
                        onSelected: model.editable
                            ? (_) => model.setKnowledge(
                                BlockKnowledgeState.unknown,
                              )
                            : null,
                      ),
                    ],
                  ),
                  if (model.knowledgeState == null)
                    const Text('请选择是否记得这段时间的内容。'),
                  if (model.restored) const Text('已恢复上次输入'),
                  if (widget.goals != null) ...[
                    const SizedBox(height: 12),
                    _goalSection(context),
                  ],
                  if (model.candidates.isNotEmpty) ...[
                    const Text('选择要补记的时间，也可以手动填写：'),
                    for (final candidate in model.candidates)
                      OutlinedButton(
                        onPressed: model.editable
                            ? () => model.chooseCandidate(candidate)
                            : null,
                        child: Text(
                          '${formatRecordingTime(candidate.startedAt)} → ${formatRecordingTime(candidate.endedAt)}',
                        ),
                      ),
                  ],
                  for (final start in [true, false]) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(start ? '开始时间' : '结束时间'),
                      subtitle: Text(
                        formatRecordingTime(
                          start ? model.time.startedAt : model.time.endedAt,
                        ),
                      ),
                      onTap: model.editable ? () => _time(start) : null,
                      trailing: IconButton(
                        tooltip: start ? '清空开始时间' : '清空结束时间',
                        icon: const Icon(Icons.clear),
                        onPressed: model.editable
                            ? () => model.setTime(
                                start: start ? null : model.time.startedAt,
                                end: start ? model.time.endedAt : null,
                              )
                            : null,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final precision in TimePrecision.values)
                          ChoiceChip(
                            label: Text(
                              '${start ? '开始' : '结束'}${precision == TimePrecision.exact ? '准确' : '大约'}',
                            ),
                            selected:
                                (start
                                    ? model.time.startPrecision
                                    : model.time.endPrecision) ==
                                precision,
                            onSelected: model.editable
                                ? (_) => model.setPrecision(
                                    start: start ? precision : null,
                                    end: start ? null : precision,
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ],
                  if (model.timeError != null) Text(model.timeError!),
                  const SizedBox(height: 12),
                  RecordingRhythmInput(
                    model: model,
                    hint: continuationHint,
                    reason: stuckReasonText,
                  ),
                  const SizedBox(height: 16),
                  if (model.committed == null)
                    Text(
                      model.saving
                          ? '正在保留草稿…'
                          : widget.context.entry == RecordingDraftEntry.edit
                          ? '更正草稿已保留，原记录尚未改变。'
                          : '输入作为草稿保留，尚未计入账本。',
                    ),
                  if (model.submitError != null) Text(model.submitError!),
                  for (final conflict in model.conflicts)
                    Text(
                      '冲突记录：${conflict.reference.type == LedgerFactType.timeBlock ? '活动' : '睡眠'} '
                      '${conflict.reference.id} '
                      '${formatRecordingTime(conflict.startedAt)} → ${formatRecordingTime(conflict.endedAt)}',
                    ),
                  if (model.committed case final committed?) ...[
                    Text(
                      widget.context.entry == RecordingDraftEntry.edit
                          ? '更正已保存到账本，请不要再次提交。'
                          : '已正式保存到账本，请不要再次提交。',
                    ),
                    if (!committed.draftCleared)
                      const Text('草稿清理失败，旧草稿仍可能显示；请重试清理。'),
                    if (committed.refreshed == null)
                      const Text('账本刷新失败，记录已保存；请重试刷新。'),
                    if (!committed.complete)
                      FilledButton(
                        onPressed: model.submitting ? null : _finish,
                        child: const Text('继续清理并刷新'),
                      ),
                  ],
                  if (model.storageError != null &&
                      model.committed == null) ...[
                    Text(model.storageError!),
                    TextButton(
                      onPressed: model.retrySave,
                      child: const Text('重试保存草稿'),
                    ),
                  ],
                  if (model.committed == null) ...[
                    FilledButton(
                      onPressed:
                          (widget.context.entry == RecordingDraftEntry.edit
                              ? model.entryEditor == null
                              : model.entrySaver == null)
                          ? null
                          : _submit,
                      child: Text(
                        widget.context.entry == RecordingDraftEntry.edit
                            ? '保存更正'
                            : '确认并保存到账本',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _leave(),
                      child: const Text('保留草稿并返回'),
                    ),
                    TextButton(
                      onPressed: () => _leave(discard: true),
                      child: const Text('放弃草稿'),
                    ),
                  ] else
                    TextButton(
                      onPressed: () => _leave(),
                      child: const Text('返回账本'),
                    ),
                ],
              ),
            ),
    ),
  );
}
