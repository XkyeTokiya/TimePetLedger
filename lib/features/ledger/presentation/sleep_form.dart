import 'package:flutter/material.dart';

import '../domain/ledger_conflicts.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';
import 'sleep_form_controller.dart';
import 'sleep_time_input.dart';

/// The caller owns the controller and drains pending writes before closing storage.
class SleepForm extends StatefulWidget {
  const SleepForm({super.key, required this.controller});
  final SleepFormController controller;
  @override
  State<SleepForm> createState() => _SleepFormState();
}

class _SleepFormState extends State<SleepForm> {
  SleepFormController get model => widget.controller;
  final start = TextEditingController();
  final end = TextEditingController();
  final note = TextEditingController();
  bool allowPop = false;
  bool exiting = false;

  @override
  void initState() {
    super.initState();
    model.addListener(_changed);
    _initialize();
  }

  Future<void> _initialize() async {
    await model.initialize();
    if (!mounted) return;
    start.text = model.startedAtInput;
    end.text = model.endedAtInput;
    note.text = model.note;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    start.dispose();
    end.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _leave({bool discard = false}) async {
    if (exiting || model.discarding || model.submitting) return;
    setState(() => exiting = true);
    final success = discard ? await model.discard() : await model.flush();
    if (!mounted) return;
    if (!success) {
      setState(() => exiting = false);
      return;
    }
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除睡眠'),
        content: const Text('删除这次完整睡眠后，相关日期的覆盖和睡眠摘要会重新计算。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await model.delete();
    if (!mounted || result == null) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _submit({bool finish = false}) async {
    final result = finish ? await model.retryFinish() : await model.submit();
    if (!mounted || result == null) return;
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(model.context.isEditing ? '更正睡眠' : '记录睡眠'),
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
                  TextButton(
                    onPressed: () => _leave(discard: true),
                    child: const Text('放弃草稿'),
                  ),
                  if (model.storageError != null) Text(model.storageError!),
                ],
              ),
            )
          : AbsorbPointer(
              absorbing: exiting || model.submitting || model.discarding,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (model.restored) const Text('已恢复上次睡眠输入'),
                  const Text('这次是主睡眠还是小睡？'),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final type in SleepType.values)
                        ChoiceChip(
                          label: Text(
                            type == SleepType.mainSleep ? '主睡眠' : '小睡',
                          ),
                          selected: model.type == type,
                          onSelected: model.editable
                              ? (_) => model.setType(type)
                              : null,
                        ),
                    ],
                  ),
                  for (final isStart in [true, false]) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: ValueKey(isStart ? 'sleep-start' : 'sleep-end'),
                      controller: isStart ? start : end,
                      enabled: model.editable,
                      onChanged: isStart
                          ? model.setStartedAtInput
                          : model.setEndedAtInput,
                      decoration: InputDecoration(
                        labelText: isStart ? '入睡时间' : '醒来时间',
                        hintText: 'YYYY-MM-DD HH:mm',
                        helperText: '当地日期时间，可跨日填写',
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final precision in TimePrecision.values)
                          ChoiceChip(
                            label: Text(
                              '${isStart ? '入睡' : '醒来'}${precision == TimePrecision.exact ? '准确' : '大约'}',
                            ),
                            selected:
                                (isStart
                                    ? model.startPrecision
                                    : model.endPrecision) ==
                                precision,
                            onSelected: !model.editable
                                ? null
                                : (_) => model.setPrecision(
                                    start: isStart ? precision : null,
                                    end: isStart ? null : precision,
                                  ),
                          ),
                      ],
                    ),
                  ],
                  if (model.type == null) const Text('请选择睡眠类型。'),
                  if (model.startPrecision == null ||
                      model.endPrecision == null)
                    const Text('请分别确认入睡与醒来时间的精度。'),
                  if (model.timeError != null) Text(model.timeError!),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('sleep-note'),
                    controller: note,
                    enabled: model.editable,
                    onChanged: model.setNote,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: '备注（可选）',
                      helperText: '可留空，保留内部换行',
                      errorText: model.noteError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!model.postCommit)
                    Text(
                      model.submitting
                          ? '正在保存睡眠…'
                          : model.saving
                          ? '正在保留睡眠草稿…'
                          : '输入自动保留为草稿，尚未计入账本。',
                    ),
                  if (model.submitError != null) Text(model.submitError!),
                  for (final conflict in model.conflicts)
                    Text(
                      '${conflict.reference.type == LedgerFactType.timeBlock ? '普通记录' : '睡眠记录'} ${conflict.reference.id}：${formatSleepTime(conflict.startedAt)} → ${formatSleepTime(conflict.endedAt)}',
                    ),
                  if (model.committedMessage != null)
                    Text(model.committedMessage!),
                  if (model.finishPending)
                    TextButton(
                      onPressed: () => _submit(finish: true),
                      child: const Text('继续清理并刷新'),
                    ),
                  if (model.context.isEditing &&
                      !model.postCommit &&
                      !model.missingOriginal)
                    const Text('原睡眠记录尚未改变。'),
                  if (model.storageError != null && !model.postCommit) ...[
                    Text(model.storageError!),
                    TextButton(
                      onPressed: model.retrySave,
                      child: const Text('重试保存草稿'),
                    ),
                  ],
                  if (!model.postCommit) ...[
                    if (model.context.isEditing
                        ? model.entryEditor != null
                        : model.entrySaver != null)
                      FilledButton(
                        onPressed: model.missingOriginal ? null : _submit,
                        child: Text(
                          model.context.isEditing ? '保存更正' : '确认并保存到账本',
                        ),
                      ),
                    if (model.context.isEditing && model.entryEditor != null)
                      TextButton(
                        onPressed: model.editable ? _delete : null,
                        child: const Text('删除睡眠'),
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
                    TextButton(onPressed: _leave, child: const Text('返回账本')),
                ],
              ),
            ),
    ),
  );
}
