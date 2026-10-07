import 'package:flutter/material.dart';

import '../../../core/widgets/editor_body.dart';
import '../domain/projection/derived_duration.dart';
import 'summary_formatting.dart';
import 'recording_time_picker.dart';
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
  final note = TextEditingController();
  bool allowPop = false;
  bool exiting = false;
  bool showErrors = false;

  Future<void> _time(bool isStart, {bool isDate = false}) async {
    final picker = isDate ? showRecordingDatePicker : showRecordingTimePicker;
    final value = await picker(
      context,
      value: isStart ? model.startedAt : model.endedAt,
      date: model.context.date,
    );
    if (!mounted || value == null) return;
    model.setTime(
      start: isStart ? value : model.startedAt,
      end: isStart ? model.endedAt : value,
    );
    if (model.startPrecision == null || model.endPrecision == null) {
      model.setPrecision(
        start: model.startPrecision ?? TimePrecision.approximate,
        end: model.endPrecision ?? TimePrecision.approximate,
      );
    }
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
    note.text = model.note;
    setState(() {});
  }

  void _changed() {
    if (note.text != model.note) note.text = model.note;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
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

  Future<void> _restart() async {
    if (!model.editable) return;
    final editing = model.context.isEditing;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing ? '重新编辑睡眠？' : '重新填写睡眠？'),
        content: const Text('本次尚未正式保存的修改将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续填写'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(editing ? '重新编辑' : '重新填写'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await model.restartInput();
      if (mounted) setState(() {});
    }
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
              } else if (value == '重新填写') {
                _restart();
              } else {
                _leave();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: !exiting && !model.submitting,
                value: '返回',
                child: const Text('返回'),
              ),
              if (!model.postCommit)
                PopupMenuItem(
                  enabled: model.editable,
                  value: '重新填写',
                  child: const Text('重新填写'),
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
                    child: const Text('清空本次填写'),
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
                    ? '本次填写未保留'
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: RecordingEndpointFields(
                          label: isStart ? '入睡' : '醒来',
                          value: isStart ? model.startedAt : model.endedAt,
                          keyPrefix: isStart ? 'sleep-start' : 'sleep-end',
                          enabled: model.editable,
                          onDate: () => _time(isStart, isDate: true),
                          onTime: () => _time(isStart),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
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
                            onSelected: model.editable
                                ? (_) => model.setPrecision(
                                    start: isStart ? precision : null,
                                    end: isStart ? null : precision,
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ],
                  if (model.startedAt != null &&
                      model.endedAt != null &&
                      model.endedAt! > model.startedAt!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '完整时长  ${formatDerivedDuration(DerivedDuration(milliseconds: model.endedAt! - model.startedAt!, hasApproximation: model.startPrecision == TimePrecision.approximate || model.endPrecision == TimePrecision.approximate))}',
                      ),
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
                      child: const Text('重试保留本次填写'),
                    ),
                  ],
                ],
              ),
            ),
    ),
  );
}
