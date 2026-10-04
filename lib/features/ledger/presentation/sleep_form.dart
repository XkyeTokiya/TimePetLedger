import 'package:flutter/material.dart';

import '../../../core/widgets/editor_body.dart';
import '../domain/projection/derived_duration.dart';
import 'summary_formatting.dart';
import 'editor_time_page.dart';
import 'recording_optional_section.dart';

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
  bool showErrors = false;

  Future<void> _times() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<EditorTimes>(
      MaterialPageRoute(
        builder: (_) => EditorTimePage(
          date: model.context.date,
          sleep: true,
          initial: (
            start: start.text,
            end: end.text,
            startPrecision: model.startPrecision,
            endPrecision: model.endPrecision,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    start.text = result.start;
    end.text = result.end;
    model.setStartedAtInput(result.start);
    model.setEndedAtInput(result.end);
    model.setPrecision(start: result.startPrecision, end: result.endPrecision);
  }

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
    setState(() {});
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => showErrors = true);
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
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              if (value == '删除睡眠') {
                _delete();
              } else if (value == '放弃草稿') {
                _leave(discard: true);
              } else {
                _leave();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: !exiting && !model.submitting,
                value: '保留草稿并返回',
                child: const Text('保留草稿并返回'),
              ),
              if (!model.postCommit)
                PopupMenuItem(
                  enabled: model.editable,
                  value: '放弃草稿',
                  child: const Text('放弃草稿'),
                ),
              if (model.context.isEditing &&
                  model.entryEditor != null &&
                  !model.postCommit)
                PopupMenuItem(
                  enabled: model.editable,
                  value: '删除睡眠',
                  child: const Text('删除睡眠'),
                ),
            ],
          ),
        ],
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
              child: EditorBody(
                status: model.postCommit
                    ? '已保存'
                    : model.storageError != null
                    ? '草稿未保留'
                    : model.saving
                    ? '正在保留…'
                    : model.context.isEditing
                    ? '原记录未改变'
                    : '尚未正式保存',
                action: FilledButton(
                  onPressed: model.finishPending
                      ? () => _submit(finish: true)
                      : model.postCommit
                      ? _leave
                      : !model.missingOriginal &&
                            model.editable &&
                            (model.context.isEditing
                                ? model.entryEditor != null
                                : model.entrySaver != null)
                      ? _submit
                      : null,
                  child: Text(
                    model.finishPending
                        ? '继续清理并刷新'
                        : model.postCommit
                        ? '返回账本'
                        : model.submitting
                        ? '正在保存…'
                        : model.context.isEditing
                        ? '保存更正'
                        : '确认并保存到账本',
                  ),
                ),
                children: [
                  const Text('完整睡眠'),
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
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        onTap: model.editable ? _times : null,
                        title: Text(
                          '${isStart ? '入睡' : '醒来'}${parseSleepTime((isStart ? start : end).text) == null ? '' : ' · ${(isStart ? start : end).text.split(' ').first}'}',
                        ),
                        subtitle: Text(
                          '${(isStart ? model.startPrecision : model.endPrecision) == TimePrecision.approximate ? '约 ' : ''}${(isStart ? start : end).text.isEmpty
                              ? '选择${isStart ? '入睡' : '醒来'}时间'
                              : parseSleepTime((isStart ? start : end).text) != null
                              ? (isStart ? start : end).text.split(' ').last
                              : (isStart ? start : end).text}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 32,
                                color: isStart
                                    ? Theme.of(context).colorScheme.secondary
                                    : null,
                              ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ],
                  if (parseSleepTime(start.text) != null &&
                      parseSleepTime(end.text) != null &&
                      parseSleepTime(end.text)! > parseSleepTime(start.text)!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '完整时长  ${formatDerivedDuration(DerivedDuration(milliseconds: parseSleepTime(end.text)! - parseSleepTime(start.text)!, hasApproximation: model.startPrecision == TimePrecision.approximate || model.endPrecision == TimePrecision.approximate))}',
                      ),
                    ),
                  OutlinedButton(
                    onPressed: model.editable ? _times : null,
                    child: const Text('调整入睡与醒来'),
                  ),
                  if (showErrors && model.type == null) const Text('请选择睡眠类型。'),
                  if (showErrors &&
                      (model.startPrecision == null ||
                          model.endPrecision == null))
                    const Text('请分别确认入睡与醒来时间的精度。'),
                  if (showErrors && model.timeError != null)
                    Text(model.timeError!),
                  const SizedBox(height: 16),
                  RecordingOptionalSection(
                    id: 'sleep-note',
                    title: '备注',
                    summary: recordingDetailPreview(model.note),
                    hasContent: model.note.isNotEmpty,
                    hasError: showErrors && model.noteError != null,
                    enabled: model.editable,
                    child: TextField(
                      key: const ValueKey('sleep-note'),
                      controller: note,
                      enabled: model.editable,
                      onChanged: model.setNote,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: '备注',
                        errorText: model.noteError,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (model.submitError != null) Text(model.submitError!),
                  for (final conflict in model.conflicts)
                    Text(
                      '${conflict.reference.type == LedgerFactType.timeBlock ? '普通记录' : '睡眠记录'} ${conflict.reference.id}：${formatSleepTime(conflict.startedAt)} → ${formatSleepTime(conflict.endedAt)}',
                    ),
                  if (model.committedMessage != null)
                    Text(model.committedMessage!),
                  if (model.storageError != null && !model.postCommit) ...[
                    Text(model.storageError!),
                    TextButton(
                      onPressed: model.retrySave,
                      child: const Text('重试保存草稿'),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
