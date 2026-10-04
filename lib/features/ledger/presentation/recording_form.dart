import 'package:flutter/material.dart';

import '../../../core/widgets/editor_body.dart';
import 'editor_time_page.dart';
import 'sleep_time_input.dart';

import 'package:flutter/services.dart';

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
import 'recording_optional_section.dart';

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
  CivilDate? initialDate,
}) => showDialog<int>(
  context: context,
  builder: (_) => _RecordingTimeDialog(
    label: label,
    initial: initial,
    initialDate: initialDate,
  ),
);

class _RecordingTimeDialog extends StatefulWidget {
  const _RecordingTimeDialog({
    required this.label,
    this.initial,
    this.initialDate,
  });
  final String label;
  final int? initial;
  final CivilDate? initialDate;
  @override
  State<_RecordingTimeDialog> createState() => _RecordingTimeDialogState();
}

class _RecordingTimeDialogState extends State<_RecordingTimeDialog> {
  late final text = TextEditingController(
    text: widget.initial == null ? '' : formatRecordingTime(widget.initial),
  );
  String? error;
  final dateFocus = FocusNode();
  final pickerFocus = FocusNode();
  @override
  void dispose() {
    text.dispose();
    dateFocus.dispose();
    pickerFocus.dispose();
    super.dispose();
  }

  DateTime get _base {
    final value = parseRecordingTime(text.text) ?? widget.initial;
    if (value != null) return DateTime.fromMillisecondsSinceEpoch(value);
    final date = widget.initialDate!;
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _pickDate() async {
    final base = _base;
    if (base.year < 1 || base.year > 9999) return;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      // Material's fixed calendar cells clip two-digit days with large text.
      // Use its date input mode rather than reducing the user's font size.
      initialEntryMode: MediaQuery.textScalerOf(context).scale(16) > 20
          ? DatePickerEntryMode.inputOnly
          : DatePickerEntryMode.calendar,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: '选择${widget.label}的日期',
    );
    if (!mounted) return;
    dateFocus.requestFocus();
    if (date == null) return;
    _setPicked(date.year, date.month, date.day, base.hour, base.minute);
  }

  Future<void> _pickTime() async {
    final base = _base;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (!mounted) return;
    pickerFocus.requestFocus();
    if (time == null) return;
    _setPicked(base.year, base.month, base.day, time.hour, time.minute);
  }

  void _setPicked(int year, int month, int day, int hour, int minute) {
    String two(int n) => n.toString().padLeft(2, '0');
    // Keep the chosen civil minute literal. The existing parser rejects a
    // nonexistent local minute instead of DateTime silently normalizing it.
    final y = '${year < 0 ? '-' : ''}${year.abs().toString().padLeft(4, '0')}';
    text.text = '$y-${two(month)}-${two(day)} ${two(hour)}:${two(minute)}';
    setState(
      () => error = parseRecordingTime(text.text) == null
          ? '请选择有效的当地日期和时间。'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.label),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('time-dialog-input'),
          controller: text,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: '年-月-日 时:分',
            hintText: '2026-09-28 14:30',
            errorText: error,
          ),
        ),
        if (widget.initialDate != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                focusNode: dateFocus,
                onPressed: _base.year >= 1 && _base.year <= 9999
                    ? _pickDate
                    : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('选择日期'),
              ),
              TextButton.icon(
                focusNode: pickerFocus,
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule),
                label: const Text('选择时间'),
              ),
            ],
          ),
          const Text('也可手动输入完整日期时间；确认后才应用。'),
        ],
      ],
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
  final titleFocus = FocusNode();
  final noteFocus = FocusNode();
  final goalFocus = FocusNode();
  final startTimeFocus = FocusNode();
  final endTimeFocus = FocusNode();
  final statusKey = GlobalKey();
  final titleKey = GlobalKey();
  final noteKey = GlobalKey();
  final timeKey = GlobalKey();
  bool showErrors = false;
  bool focusErrors = false;
  bool titleVisited = false;
  bool noteVisited = false;
  bool timeVisited = false;
  bool timeExpanded = false;
  bool goalExpanded = false;
  bool rhythmExpanded = false;
  final Map<LedgerFactInterval, Future<String>> conflictLabels = {};

  Future<String> _conflictLabel(LedgerFactInterval conflict) async {
    final fallback = conflict.reference.type == LedgerFactType.timeBlock
        ? '活动'
        : '睡眠';
    final repository =
        model.entrySaver?.repository ?? model.entryEditor?.repository;
    if (repository == null) return fallback;
    try {
      if (conflict.reference.type == LedgerFactType.timeBlock) {
        final block = await repository.readTimeBlock(conflict.reference.id);
        if (block == null) return fallback;
        return block.timeBlock.knowledgeState == BlockKnowledgeState.unknown
            ? '想不起来'
            : block.timeBlock.title ?? fallback;
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? revealedError;
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
    titleFocus.addListener(() {
      if (!titleFocus.hasFocus && mounted) setState(() => titleVisited = true);
    });
    noteFocus.addListener(() {
      if (!noteFocus.hasFocus && mounted) setState(() => noteVisited = true);
    });
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
      setState(() => showErrors = model.restored);
      _revealErrors();
    }
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      _revealErrors();
    }
  }

  void _revealErrors() {
    final committed = model.committed;
    final phaseError =
        model.storageError ??
        (committed != null && !committed.complete
            ? 'committed:${committed.draftCleared}:${committed.refreshed != null}'
            : null) ??
        (model.submitError != null && model.submitError != '请确认活动和时间后再保存。'
            ? model.submitError
            : null);
    final rhythmOnlyError =
        model.titleError == null &&
        model.timeError == null &&
        model.noteError == null &&
        (model.hintError != null || model.reasonError != null);
    final message =
        phaseError ??
        (rhythmOnlyError ? null : model.submitError) ??
        (showErrors
            ? model.titleError ?? model.timeError ?? model.noteError
            : null);
    if (message == null) {
      revealedError = null;
      return;
    }
    if (message == revealedError) return;
    revealedError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = phaseError != null
          ? statusKey
          : showErrors && model.titleError != null
          ? titleKey
          : showErrors && model.timeError != null
          ? timeKey
          : showErrors && model.noteError != null
          ? noteKey
          : statusKey;
      final field = target.currentContext;
      if (field != null) await Scrollable.ensureVisible(field, alignment: .2);
      if (!mounted) return;
      if (focusErrors && target == titleKey) titleFocus.requestFocus();
      if (focusErrors && target == noteKey) noteFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    title.dispose();
    note.dispose();
    continuationHint.dispose();
    stuckReasonText.dispose();
    titleFocus.dispose();
    noteFocus.dispose();
    goalFocus.dispose();
    startTimeFocus.dispose();
    endTimeFocus.dispose();
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      showErrors = true;
      focusErrors = true;
      revealedError = null;
    });
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => timeExpanded = true);
    final value = await editRecordingTime(
      context,
      label: start ? '开始时间' : '结束时间',
      initial: start ? model.time.startedAt : model.time.endedAt,
      initialDate: widget.context.date,
    );
    if (!mounted) return;
    (start ? startTimeFocus : endTimeFocus).requestFocus();
    if (value == null || !model.editable) return;
    setState(() => timeVisited = true);
    model.setTime(
      start: start ? value : model.time.startedAt,
      end: start ? model.time.endedAt : value,
    );
  }

  Future<void> _chooseGoal() async {
    FocusManager.instance.primaryFocus?.unfocus();
    Widget choices(BuildContext sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择目标', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (model.selectedGoal?.status == GoalStatus.archived)
              Text('当前归属：${model.selectedGoal!.name}（已归档，可保留原引用）'),
            _goalChoice(sheet, '', '不关联', null),
            for (final goal in model.activeGoals)
              _goalChoice(sheet, goal.id, goal.name, '标识：${goal.id}'),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
    final String? id;
    if (MediaQuery.sizeOf(context).width < 840) {
      id = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: choices,
      );
    } else {
      id = await showDialog<String>(
        context: context,
        builder: (sheet) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: choices(sheet),
          ),
        ),
      );
    }
    if (!mounted) return;
    goalFocus.requestFocus();
    if (id == '') {
      model.clearGoal();
    } else if (id != null) {
      model.selectGoal(id);
    }
  }

  Widget _goalChoice(
    BuildContext sheet,
    String id,
    String name,
    String? detail,
  ) => Semantics(
    selected: (model.goalId ?? '') == id,
    inMutuallyExclusiveGroup: true,
    child: ListTile(
      key: ValueKey('goal-option-$id'),
      leading: Icon(
        (model.goalId ?? '') == id
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
      ),
      title: Text(name),
      subtitle: detail == null ? null : Text(detail),
      onTap: () => Navigator.pop(sheet, id),
    ),
  );

  Widget _goalSection(BuildContext context) {
    final goal = model.selectedGoal;
    final archived = goal?.status == GoalStatus.archived;
    final retained = model.goalId == model.original?.goalId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('目标归属', style: Theme.of(context).textTheme.titleMedium),
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
                focusNode: goalFocus,
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
              '可在上方修改时间，大约时间也可以保存。',
            ),
          ),
      ],
    );
  }

  Widget _status(BuildContext context) => Container(
    key: statusKey,
    width: double.infinity,
    padding: EdgeInsets.all(model.conflicts.isNotEmpty ? 12 : 16),
    decoration: BoxDecoration(
      color: model.conflicts.isNotEmpty
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surface,
      border: model.conflicts.isNotEmpty
          ? Border.all(color: Theme.of(context).colorScheme.error)
          : null,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (model.restored) const Text('已恢复上次输入'),
        if (model.committed == null && model.submitting)
          Text(
            model.submitting
                ? '正在保存到账本…'
                : model.saving
                ? '正在保留草稿…'
                : widget.context.entry == RecordingDraftEntry.edit
                ? '更正草稿已保留，原记录尚未改变。'
                : '输入作为草稿保留，尚未计入账本。',
          ),
        if (model.submitError != null && model.conflicts.isEmpty)
          Text(
            model.submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        for (final conflict in model.conflicts) ...[
          Text(
            '按当前填写的${model.time.startPrecision == TimePrecision.approximate || model.time.endPrecision == TimePrecision.approximate ? '估算' : ''}时间，${_overlap(conflict)}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          FutureBuilder<String>(
            key: ValueKey(conflict),
            future: conflictLabels.putIfAbsent(
              conflict,
              () => _conflictLabel(conflict),
            ),
            builder: (context, snapshot) => Text(
              '冲突记录：${snapshot.data ?? (conflict.reference.type == LedgerFactType.timeBlock ? '活动' : '睡眠')} · ${formatRecordingTime(conflict.startedAt)} → ${_shortTime(conflict.endedAt)}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入已保留，请调整当前记录时间。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (model.committed case final committed?) ...[
          Text(
            widget.context.entry == RecordingDraftEntry.edit
                ? '更正已保存到账本，请不要再次提交。'
                : '已正式保存到账本，请不要再次提交。',
          ),
          if (!committed.draftCleared)
            Text(
              '草稿清理失败，旧草稿仍可能显示；请重试清理。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (committed.refreshed == null)
            Text(
              '账本刷新失败，记录已保存；请重试刷新。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!committed.complete)
            FilledButton(
              onPressed: model.submitting ? null : _finish,
              child: const Text('继续清理并刷新'),
            ),
        ],
        if (model.storageError != null && model.committed == null) ...[
          Text(
            model.storageError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: model.editable ? model.retrySave : null,
            child: const Text('重试保存草稿'),
          ),
        ],
      ],
    ),
  );

  String get _interval =>
      '${model.time.startPrecision == TimePrecision.approximate ? '约' : ''}${_shortTime(model.time.startedAt)} → '
      '${model.time.endPrecision == TimePrecision.approximate ? '约' : ''}${model.time.startedAt != null && model.time.endedAt != null && formatRecordingTime(model.time.startedAt).split(' ').first == formatRecordingTime(model.time.endedAt).split(' ').first ? formatRecordingTime(model.time.endedAt).split(' ').last : formatRecordingTime(model.time.endedAt)}';

  String _shortTime(int? instant) {
    if (instant == null) return formatRecordingTime(instant);
    final date = DateTime.fromMillisecondsSinceEpoch(instant);
    final day = widget.context.date;
    final text = formatRecordingTime(instant);
    return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day
        ? text.split(' ').last
        : text;
  }

  String get _duration {
    final start = model.time.startedAt;
    final end = model.time.endedAt;
    if (start == null || end == null || end <= start) return '';
    final minutes = (end - start) ~/ 60000;
    final approximate =
        model.time.startPrecision == TimePrecision.approximate ||
        model.time.endPrecision == TimePrecision.approximate;
    return '${approximate ? '约' : ''}${minutes >= 60 ? '${minutes ~/ 60}小时' : ''}${minutes % 60 != 0 || minutes == 0 ? '${minutes % 60}分钟' : ''}';
  }

  String _overlap(LedgerFactInterval conflict) {
    final start = model.time.startedAt! > conflict.startedAt
        ? model.time.startedAt!
        : conflict.startedAt;
    final end = model.time.endedAt! < conflict.endedAt
        ? model.time.endedAt!
        : conflict.endedAt;
    final approximate =
        model.time.startPrecision == TimePrecision.approximate ||
        model.time.endPrecision == TimePrecision.approximate;
    return '重叠区间为${_shortTime(start)}–${_shortTime(end)}${approximate ? '（估算边界）' : ''}。';
  }

  Future<void> _editCurrentTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await Navigator.of(context).push<EditorTimes>(
      MaterialPageRoute(
        builder: (_) => EditorTimePage(
          date: widget.context.date,
          initial: (
            start: formatSleepTime(model.time.startedAt),
            end: formatSleepTime(model.time.endedAt),
            startPrecision: model.time.startPrecision,
            endPrecision: model.time.endPrecision,
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    model.setTime(
      start: parseSleepTime(result.start),
      end: parseSleepTime(result.end),
    );
    model.setPrecision(start: result.startPrecision, end: result.endPrecision);
  }

  Widget _timeSection(BuildContext context) {
    final error = (showErrors || timeVisited) ? model.timeError : null;
    final expanded = timeExpanded || model.timeError != null;
    return Container(
      key: timeKey,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _interval,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      key: const ValueKey('recording-time-summary'),
                    ),
                    if (_duration.isNotEmpty)
                      Text(
                        _duration,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (model.conflicts.isEmpty &&
                  model.time.startedAt != null &&
                  model.time.endedAt != null)
                TextButton.icon(
                  key: const ValueKey('edit-recording-time'),
                  onPressed: model.editable
                      ? () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final result = await Navigator.of(context)
                              .push<EditorTimes>(
                                MaterialPageRoute(
                                  builder: (_) => EditorTimePage(
                                    date: widget.context.date,
                                    initial: (
                                      start: formatSleepTime(
                                        model.time.startedAt,
                                      ),
                                      end: formatSleepTime(model.time.endedAt),
                                      startPrecision: model.time.startPrecision,
                                      endPrecision: model.time.endPrecision,
                                    ),
                                  ),
                                ),
                              );
                          if (!mounted || result == null) return;
                          model.setTime(
                            start: parseSleepTime(result.start),
                            end: parseSleepTime(result.end),
                          );
                          model.setPrecision(
                            start: result.startPrecision,
                            end: result.endPrecision,
                          );
                        }
                      : null,
                  icon: const SizedBox.shrink(),
                  label: Text(expanded ? '收起时间编辑' : '修改时间'),
                ),
            ],
          ),
          if (expanded)
            for (final start in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                focusNode: start ? startTimeFocus : endTimeFocus,
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
                      ? () {
                          setState(() => timeVisited = true);
                          model.setTime(
                            start: start ? null : model.time.startedAt,
                            end: start ? model.time.endedAt : null,
                          );
                        }
                      : null,
                ),
              ),
          if (error != null)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (model.timeError != null)
            const Text('请确认完整的开始与结束时间。'),
          if (expanded) const SizedBox(height: 8),
          if (expanded)
            for (final start in [true, false])
              Wrap(
                spacing: 8,
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
      ),
    );
  }

  Widget _content(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.submitError != null ||
          model.storageError != null ||
          model.committed != null ||
          model.conflicts.isNotEmpty)
        _status(context),
      if (model.conflicts.isEmpty) ...[
        Text(
          '${widget.context.date.month}月${widget.context.date.day}日 · ${widget.context.entry == RecordingDraftEntry.gap
              ? '补记这段时间'
              : widget.context.entry == RecordingDraftEntry.edit
              ? '更正这段时间'
              : '记录这段时间'}',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
      ] else
        const SizedBox(height: 12),
      if (model.knowledgeState != BlockKnowledgeState.unknown ||
          ((showErrors || titleVisited) && model.titleError != null))
        Container(
          key: titleKey,
          constraints: const BoxConstraints(minHeight: 100),
          child: TextField(
            key: const ValueKey('activity'),
            controller: title,
            focusNode: titleFocus,
            readOnly: !model.editable,
            onChanged: model.setTitle,
            minLines: 2,
            maxLines: null,
            style: const TextStyle(fontSize: 20, height: 1.6),
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '刚才这段时间在做什么？',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              errorText: showErrors || titleVisited ? model.titleError : null,
            ),
          ),
        ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final known in BlockKnowledgeState.values)
              Expanded(
                child: ChoiceChip(
                  shape: const RoundedRectangleBorder(),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: model.knowledgeState == known
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  label: Center(
                    child: Text(
                      known == BlockKnowledgeState.known ? '记得' : '想不起来',
                    ),
                  ),
                  selected: model.knowledgeState == known,
                  onSelected: model.editable
                      ? (_) => model.setKnowledge(known)
                      : null,
                ),
              ),
          ],
        ),
      ),
      if (model.knowledgeState == null) const Text('请选择是否记得这段时间的内容。'),
      const SizedBox(height: 16),
      if (model.candidates.isNotEmpty) ...[
        const Text('选择要补记的时间，也可以手动填写：'),
        for (final candidate in model.candidates)
          OutlinedButton(
            onPressed: model.editable
                ? () {
                    setState(() => timeExpanded = false);
                    model.chooseCandidate(candidate);
                  }
                : null,
            child: Text(
              '${formatRecordingTime(candidate.startedAt)} → ${formatRecordingTime(candidate.endedAt)}',
            ),
          ),
        const SizedBox(height: 8),
      ],
      _timeSection(context),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              MediaQuery.textScalerOf(context).scale(16) > 24 ||
              (model.selectedGoal?.name.runes.length ?? 0) > 12;
          Widget entry(
            String id,
            String label,
            bool open,
            VoidCallback toggle,
          ) => OutlinedButton(
            key: ValueKey('$id-toggle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onPressed: model.editable
                ? () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    toggle();
                  }
                : null,
            child: Align(alignment: Alignment.centerLeft, child: Text(label)),
          );
          final entries = [
            if (widget.goals != null)
              entry(
                'recording-goal',
                model.selectedGoal?.name ?? '＋ 目标',
                goalExpanded,
                () => setState(() => goalExpanded = !goalExpanded),
              ),
            entry(
              'recording-rhythm',
              model.rhythmState == null
                  ? '＋ 节奏'
                  : rhythmInputLabel(model.rhythmState),
              rhythmExpanded,
              () => setState(() => rhythmExpanded = !rhythmExpanded),
            ),
          ];
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      entries[i],
                    ],
                  ],
                )
              : Row(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: entries[i]),
                    ],
                  ],
                );
        },
      ),
      if (widget.goals != null &&
          (goalExpanded || model.goalsError != null)) ...[
        const SizedBox(height: 8),
        _goalSection(context),
      ],
      if (rhythmExpanded ||
          (showErrors &&
              (model.hintError != null || model.reasonError != null))) ...[
        const SizedBox(height: 8),
        RecordingRhythmInput(
          model: model,
          hint: continuationHint,
          reason: stuckReasonText,
          showErrors: showErrors,
        ),
      ],
      const SizedBox(height: 8),
      RecordingOptionalSection(
        disclosure: true,
        id: 'recording-note',
        title: '补充内容',
        summary: recordingDetailPreview(model.note),
        hasContent: model.note.isNotEmpty,
        hasError: (showErrors || noteVisited) && model.noteError != null,
        enabled: model.editable,
        child: Container(
          key: noteKey,
          child: TextField(
            key: const ValueKey('note'),
            controller: note,
            focusNode: noteFocus,
            readOnly: !model.editable,
            onChanged: model.setNote,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: '备注内容',
              errorText: showErrors || noteVisited ? model.noteError : null,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _saveAction() => model.conflicts.isNotEmpty
      ? FilledButton(
          onPressed: model.editable ? _editCurrentTime : null,
          child: const Text('调整当前记录时间'),
        )
      : model.committed == null
      ? FilledButton(
          key: const ValueKey('recording-submit'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed:
              (widget.context.entry == RecordingDraftEntry.edit
                  ? model.entryEditor == null
                  : model.entrySaver == null)
              ? null
              : model.editable && !exiting
              ? _submit
              : null,
          child: Text(
            widget.context.entry == RecordingDraftEntry.edit ? '保存更正' : '保存到账本',
          ),
        )
      : TextButton(onPressed: () => _leave(), child: const Text('返回账本'));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _leave},
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 8,
          title: Text(
            widget.context.entry == RecordingDraftEntry.edit
                ? '更正记录'
                : widget.context.entry == RecordingDraftEntry.gap
                ? '补记活动'
                : '记录活动',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          leading: BackButton(onPressed: _leave),
          actions: [
            PopupMenuButton<bool>(
              tooltip: '更多',
              onSelected: (discard) => _leave(discard: discard),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: false,
                  enabled: !exiting && !model.submitting,
                  child: const Text('保留草稿并返回'),
                ),
                if (model.committed == null)
                  PopupMenuItem(
                    value: true,
                    enabled: model.editable,
                    child: const Text('放弃草稿'),
                  ),
              ],
            ),
          ],
        ),
        body: model.loading
            ? const Center(child: CircularProgressIndicator())
            : model.loadError != null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        model.loadError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: _initialize,
                        child: const Text('重试读取'),
                      ),
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
                      if (model.storageError != null)
                        Text(
                          model.storageError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : AbsorbPointer(
                absorbing: exiting || model.discarding || model.submitting,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SafeArea(
                      top: false,
                      child: EditorBody(
                        prototypeSpacing: true,
                        action: _saveAction(),
                        status: model.storageError != null
                            ? '草稿未保留'
                            : model.saving
                            ? '正在保留…'
                            : model.committed != null
                            ? '已保存'
                            : model.knowledgeState == null
                            ? '尚未填写'
                            : '草稿已保留',
                        children: [_content(context)],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
