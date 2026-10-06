import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../goals/domain/goal_status.dart';
import '../../domain/block_knowledge_state.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/recording_draft_store.dart';
import '../../domain/rhythm_details.dart';
import '../../domain/rhythm_state.dart';
import '../../domain/time_precision.dart';
import '../recording_form.dart' show formatRecordingTime;
import '../recording_form_controller.dart';
import '../sleep_time_input.dart';
import '../summary_formatting.dart';
import 'activity_sheets.dart';
import '../recording_time_picker.dart';

/// 活动记录页：节奏 → 适用子选项 → 事项 → 时间。
///
/// 独立的新页面，只复用既有 [RecordingFormController] 的草稿、校验、提交、
/// 更正与失败重试合同；不依赖盒子里的旧 RecordingForm / GuidedRecordingPage。
class ActivityRecordingPage extends StatefulWidget {
  const ActivityRecordingPage({super.key, required this.model});

  final RecordingFormController model;

  @override
  State<ActivityRecordingPage> createState() => _ActivityRecordingPageState();
}

class _ActivityRecordingPageState extends State<ActivityRecordingPage> {
  RecordingFormController get model => widget.model;

  late final title = TextEditingController(text: model.title);
  late final reason = TextEditingController(text: model.stuckReasonText);
  final scroll = ScrollController();
  int step = 0;
  bool showErrors = false;
  bool allowPop = false;
  bool exiting = false;

  bool get _hasChildren =>
      model.rhythmState == RhythmState.stuck ||
      model.rhythmState == RhythmState.recovery;

  bool get _editing => model.context.entry == RecordingDraftEntry.edit;

  @override
  void initState() {
    super.initState();
    model.addListener(_changed);
  }

  void _changed() {
    if (title.text != model.title) title.text = model.title;
    if (reason.text != model.stuckReasonText) {
      reason.text = model.stuckReasonText;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    title.dispose();
    reason.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _go(int value) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = value;
      showErrors = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _next() {
    if (step == 2) {
      if (model.titleError != null) {
        setState(() => showErrors = true);
        return;
      }
      _go(3);
      return;
    }
    if (step == 0) {
      _go(_hasChildren ? 1 : 2);
      return;
    }
    _go(step + 1);
  }

  void _previous() {
    if (step == 0) return;
    // 推进没有适用子选项，事项页的上一步直接回到节奏页。
    _go(step == 2 && !_hasChildren ? 0 : step - 1);
  }

  /// 选中节奏即进入下一步；再次点击已选项表示取消，停留在本步确认。
  void _selectRhythm(RhythmState state) {
    if (!model.editable) return;
    final selected = model.rhythmState == state;
    model.setRhythmState(selected ? null : state);
    if (!selected) _go(_hasChildren ? 1 : 2);
  }

  Future<void> _goal() async {
    final choice = await showActivityGoalSheet(context, model: model);
    if (!mounted || choice == null) return;
    if (choice.id == null) {
      model.clearGoal();
    } else {
      model.selectGoal(choice.id!);
    }
  }

  Future<void> _time({bool isStart = true, bool isDate = false}) async {
    final picker = isDate ? showRecordingDatePicker : showRecordingTimePicker;
    final result = await picker(
      context,
      value: isStart ? model.time.startedAt : model.time.endedAt,
      date: model.context.date,
    );
    if (!mounted || result == null) return;
    model.setTime(
      start: isStart ? result : model.time.startedAt,
      end: isStart ? model.time.endedAt : result,
    );
  }

  Future<void> _duration() async {
    final result = await showRecordingDurationPicker(
      context,
      startedAt: model.time.startedAt,
      endedAt: model.time.endedAt,
    );
    if (!mounted || result == null) return;
    model.setTime(start: result.start, end: result.end);
  }

  Future<void> _details() async {
    final rhythm = model.rhythmState;
    final result = await showActivityDetailsSheet(
      context,
      rhythmLabel: rhythm == null ? null : _rhythmLabel(rhythm),
      hint: model.continuationHint,
      note: model.note,
    );
    if (!mounted || result == null) return;
    model.setNote(result.note);
    if (model.rhythmState != null) model.setContinuationHint(result.hint);
  }

  Future<void> _save() async {
    if (!model.editable || exiting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      showErrors = true;
      if (model.titleError != null) step = 2;
    });
    if (!model.valid) return;
    await model.submit();
    if (!mounted) return;
    final committed = model.committed;
    if (committed != null && committed.complete) {
      await _close(committed.refreshed);
    } else if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  Future<void> _finish() async {
    final refreshed = await model.retryFinish();
    if (mounted && refreshed != null) await _close(refreshed);
  }

  Future<void> _close(Object? result) async {
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _leave({bool discard = false}) async {
    if (exiting || model.submitting || model.discarding) return;
    if (model.committed != null) {
      await _close(model.committed!.refreshed);
      return;
    }
    setState(() => exiting = true);
    final okay = discard ? await model.discard() : await model.flush();
    if (!mounted) return;
    if (!okay) {
      setState(() => exiting = false);
      return;
    }
    await _close(null);
  }

  Future<void> _discard() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    if (yes == true && mounted) await _leave(discard: true);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: homeTheme,
    child: PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            key: const ValueKey('activity-exit'),
            onPressed: model.submitting ? null : _leave,
          ),
          title: Text(_editing ? '更正记录' : '记录一笔'),
        ),
        body: model.loading
            ? const Center(child: CircularProgressIndicator())
            : model.loadError != null
            ? _loadFailure()
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _goalBar(),
                        if (model.restored) ...[
                          const SizedBox(height: 12),
                          const Text('已恢复上次输入', style: _restored),
                        ],
                        if (model.storageError != null) ...[
                          const SizedBox(height: 12),
                          _notice(model.storageError!, error: true),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: model.editable
                                  ? model.retrySave
                                  : null,
                              child: const Text('重试保留草稿'),
                            ),
                          ),
                        ],
                        if (_committedNotice() case final notice?) ...[
                          const SizedBox(height: 12),
                          notice,
                        ],
                        if (model.submitError != null &&
                            model.conflicts.isEmpty) ...[
                          const SizedBox(height: 12),
                          _notice(model.submitError!, error: true),
                        ],
                        for (final conflict in model.conflicts) ...[
                          const SizedBox(height: 12),
                          _notice(
                            '已有记录：${formatSleepTime(conflict.startedAt)} — '
                            '${formatSleepTime(conflict.endedAt)}',
                            error: true,
                          ),
                        ],
                        const SizedBox(height: 20),
                        switch (step) {
                          0 => _rhythmStep(),
                          1 => _detailsStep(),
                          2 => _activityStep(),
                          _ => _timeStep(),
                        },
                      ],
                    ),
                  ),
                  _footer(),
                ],
              ),
      ),
    ),
  );

  Widget _loadFailure() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(model.loadError!, style: const TextStyle(color: HomePalette.error)),
      if (model.missingOriginal)
        TextButton(onPressed: _discard, child: const Text('清理失效草稿'))
      else
        FilledButton(onPressed: model.initialize, child: const Text('重试读取')),
      if (model.storageError != null) ...[
        const SizedBox(height: 12),
        Text(model.storageError!),
      ],
    ],
  );

  Widget? _committedNotice() {
    final committed = model.committed;
    if (committed == null) return null;
    if (committed.complete) {
      return _notice('记录已保存，可以回到账本了。', success: true);
    }
    return _notice(
      '${_editing ? '更正已保存到账本' : '已正式保存到账本'}，请不要再次提交。'
      '${committed.draftCleared ? '' : '草稿清理失败，旧草稿仍可能显示；请重试清理。'}'
      '${committed.refreshed == null ? '账本刷新失败，记录已保存；请重试刷新。' : ''}',
      success: true,
    );
  }

  Widget _goalBar() {
    final goal = model.selectedGoal;
    final archived = goal?.status == GoalStatus.archived;
    final name = model.goalId == null ? '暂不关联' : goal?.name ?? '目标信息暂不可用';
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('这笔关联的目标', style: _label),
                InkWell(
                  key: const ValueKey('activity-goal'),
                  onTap: model.editable ? _goal : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: homeTapTarget),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      archived ? '$name（已归档）' : name,
                      style: const TextStyle(
                        fontFamily: homeSerifFamily,
                        fontSize: 20,
                        height: 1.4,
                        color: HomePalette.accentDeep,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dashed,
                        decorationColor: HomePalette.accentDeep,
                        decorationThickness: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (model.goalsLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _rhythmStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('这段时间，\n节奏怎么样？', style: _question),
      const SizedBox(height: 6),
      const Text('可以不选，直接继续。', style: _hint),
      const SizedBox(height: 20),
      for (final state in RhythmState.values)
        _rhythmOption(
          state,
          title: switch (state) {
            RhythmState.progress => '推进',
            RhythmState.stuck => '卡住',
            RhythmState.recovery => '休息',
          },
          description: switch (state) {
            RhythmState.progress => '事情向前走了一点',
            RhythmState.stuck => '想往前，但遇到了阻力',
            RhythmState.recovery => '让自己缓一缓',
          },
        ),
    ],
  );

  Widget _rhythmOption(
    RhythmState state, {
    required String title,
    required String description,
  }) {
    final selected = model.rhythmState == state;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? HomePalette.tint : HomePalette.paper,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected ? HomePalette.accent : HomePalette.hairline,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          key: ValueKey('activity-rhythm-${state.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: model.editable ? () => _selectRhythm(state) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(
                  switch (state) {
                    RhythmState.progress => Icons.trending_up,
                    RhythmState.stuck => Icons.pause_circle_outline,
                    RhythmState.recovery => Icons.spa_outlined,
                  },
                  size: 24,
                  color: HomePalette.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: homeSerifFamily,
                          fontSize: 20,
                          color: HomePalette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(description, style: _hint),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check,
                    size: 20,
                    color: HomePalette.accentDeep,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsStep() {
    final stuck = model.rhythmState == RhythmState.stuck;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(stuck ? '是什么让你卡住了？' : '怎么让自己缓一缓？', style: _question),
        const SizedBox(height: 6),
        const Text('可以不选，直接继续。', style: _hint),
        if (stuck) ...[
          const SizedBox(height: 20),
          ..._choices<StuckReasonCode>(
            StuckReasonCode.values,
            model.stuckReasonCode,
            _reasonLabel,
            model.setStuckReasonCode,
            keyPrefix: 'activity-reason',
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('activity-reason-text'),
            readOnly: !model.editable,
            controller: reason,
            minLines: 2,
            maxLines: 4,
            onChanged: model.setStuckReasonText,
            decoration: InputDecoration(
              labelText: '还有想补充的吗？',
              hintText: '可以留空',
              errorText: showErrors ? model.reasonError : null,
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          const Text('休息方式', style: _fieldLabel),
          const SizedBox(height: 8),
          ..._choices<RecoveryMethod>(
            RecoveryMethod.values,
            model.recoveryMethod,
            _methodLabel,
            model.setRecoveryMethod,
            keyPrefix: 'activity-method',
          ),
          const SizedBox(height: 20),
          const Text('现在感觉怎么样？', style: _fieldLabel),
          const SizedBox(height: 8),
          ..._choices<RecoveryQuality>(
            RecoveryQuality.values,
            model.recoveryQuality,
            _qualityLabel,
            model.setRecoveryQuality,
            keyPrefix: 'activity-quality',
          ),
        ],
      ],
    );
  }

  List<Widget> _choices<T extends Enum>(
    List<T> values,
    T? selected,
    String Function(T) label,
    void Function(T?) change, {
    required String keyPrefix,
  }) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${value.name}'),
            label: Text(label(value)),
            selected: selected == value,
            showCheckmark: true,
            onSelected: model.editable
                ? (_) => change(selected == value ? null : value)
                : null,
            labelStyle: TextStyle(
              fontFamily: homeSerifFamily,
              fontSize: 15,
              color: selected == value
                  ? HomePalette.accentDeep
                  : HomePalette.ink,
            ),
            backgroundColor: HomePalette.paper,
            selectedColor: HomePalette.tint,
            side: BorderSide(
              color: selected == value
                  ? HomePalette.accent
                  : HomePalette.hairline,
            ),
            checkmarkColor: HomePalette.accentDeep,
          ),
      ],
    ),
  ];

  Widget _activityStep() {
    final unknown = model.knowledgeState == BlockKnowledgeState.unknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_activityQuestion(), style: _question),
        const SizedBox(height: 6),
        const Text('几个字就好。', style: _hint),
        const SizedBox(height: 20),
        _knowledgeSegment(unknown),
        const SizedBox(height: 20),
        if (unknown)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
            decoration: BoxDecoration(
              color: HomePalette.paper,
              border: Border.all(color: HomePalette.hairline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_outlined, size: 26, color: HomePalette.muted),
                SizedBox(height: 10),
                Text('想不起来，也可以记下来。', style: _hint),
                SizedBox(height: 4),
                Text('目标和节奏会保留。', style: _hint),
              ],
            ),
          )
        else ...[
          const Text('这段做的事', style: _fieldLabel),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('activity'),
            controller: title,
            readOnly: !model.editable,
            minLines: 3,
            maxLines: 6,
            onChanged: model.setTitle,
            decoration: InputDecoration(
              hintText: '比如：改首页的布局',
              errorText: showErrors ? model.titleError : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text('只写实际做过的事。', style: _hint),
        ],
      ],
    );
  }

  Widget _knowledgeSegment(bool unknown) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        _segmentButton(
          '记得',
          key: const ValueKey('activity-known'),
          selected: !unknown,
          value: BlockKnowledgeState.known,
        ),
        _segmentButton(
          '想不起来',
          key: const ValueKey('activity-unknown'),
          selected: unknown,
          value: BlockKnowledgeState.unknown,
        ),
      ],
    ),
  );

  Widget _segmentButton(
    String label, {
    required Key key,
    required bool selected,
    required BlockKnowledgeState value,
  }) => Expanded(
    child: Material(
      key: key,
      color: selected ? HomePalette.paper : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: model.editable ? () => model.setKnowledge(value) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: homeTapTarget),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: homeSerifFamily,
              fontSize: 16,
              color: selected ? HomePalette.accentDeep : HomePalette.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _timeStep() {
    final start = model.time.startedAt;
    final end = model.time.endedAt;
    final duration = start != null && end != null && end > start
        ? formatDerivedDuration(
            DerivedDuration(
              milliseconds: end - start,
              hasApproximation:
                  model.time.startPrecision == TimePrecision.approximate ||
                  model.time.endPrecision == TimePrecision.approximate,
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          start != null && end != null ? '是这段时间吗？' : '这段是什么时候？',
          style: _question,
        ),
        if (model.candidates.isNotEmpty) ...[
          const SizedBox(height: 6),
          const Text('这一天还有没记录的区间，先选一段。', style: _hint),
          const SizedBox(height: 12),
          for (final candidate in model.candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: model.editable
                    ? () => model.chooseCandidate(candidate)
                    : null,
                child: Text(
                  '${formatRecordingTime(candidate.startedAt)} → ${formatRecordingTime(candidate.endedAt)}',
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        _endpoint(
          '开始',
          start,
          'activity-start',
          () => _time(),
          () => _time(isDate: true),
        ),
        _endpoint(
          '结束',
          end,
          'activity-end',
          () => _time(isStart: false),
          () => _time(isStart: false, isDate: true),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            key: const ValueKey('activity-time-summary'),
            onPressed: model.editable && (start != null || end != null)
                ? _duration
                : null,
            child: Text(
              duration == null ? '调整时长' : '共 $duration',
              style: _hint,
            ),
          ),
        ),
        if (showErrors && model.timeError != null) ...[
          const SizedBox(height: 10),
          Text(
            model.timeError!,
            key: const ValueKey('activity-time-error'),
            style: const TextStyle(
              fontFamily: homeSerifFamily,
              fontSize: 14,
              color: HomePalette.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextButton.icon(
          key: const ValueKey('activity-details'),
          onPressed: model.editable ? _details : null,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('补充这笔记录'),
        ),
      ],
    );
  }

  Widget _endpoint(
    String name,
    int? value,
    String key,
    VoidCallback onTap,
    VoidCallback onDate,
  ) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: HomePalette.hairline)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: _label),
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('$key-time'),
                onTap: model.editable ? onTap : null,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value == null
                        ? '选时间'
                        : formatRecordingTime(value).split(' ').last,
                    style: const TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 32,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: HomePalette.ink,
                    ),
                  ),
                ),
              ),
            ),
            InkWell(
              key: ValueKey('$key-date'),
              onTap: model.editable ? onDate : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerRight,
                child: Text(
                  value == null ? '选日期' : _endpointDate(value),
                  style: _hint,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _endpointDate(int value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final year = date.year == model.context.date.year ? '' : '${date.year}年';
    return '$year${date.month}月${date.day}日';
  }

  String _activityQuestion() => switch (model.rhythmState) {
    RhythmState.progress => '这段推进了什么？',
    RhythmState.stuck => '刚才在做什么时卡住了？',
    RhythmState.recovery => '这段怎么休息的？',
    null => '这段主要做了什么？',
  };

  Widget _footer() {
    final committed = model.committed;
    final conflict = model.conflicts.isNotEmpty;
    final VoidCallback? action = committed != null
        ? (committed.complete ? null : _finish)
        : conflict
        ? (model.editable ? _time : null)
        : !model.editable || model.submitting
        ? null
        : step == 3
        ? _save
        : _next;
    final String label = model.submitting
        ? '正在保存'
        : committed != null
        ? (committed.complete ? '记录已保存' : '继续清理并刷新')
        : conflict
        ? '调整时间'
        : step == 3
        ? (_editing ? '保存更正' : '保存到账本')
        : '继续';
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HomePalette.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (model.editable &&
                committed == null &&
                (model.rhythmState != null ||
                    model.title.isNotEmpty ||
                    model.note.isNotEmpty ||
                    model.continuationHint.isNotEmpty ||
                    model.time.startedAt != null ||
                    model.time.endedAt != null ||
                    _editing ||
                    step > 0)) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('activity-discard'),
                  onPressed: exiting ? null : _discard,
                  child: const Text('放弃草稿'),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                if (step > 0 && committed == null) ...[
                  Expanded(
                    flex: 5,
                    child: OutlinedButton(
                      key: const ValueKey('activity-previous'),
                      onPressed: model.editable ? _previous : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('上一步', maxLines: 1, softWrap: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: step > 0 && committed == null ? 7 : 1,
                  child: FilledButton(
                    key: const ValueKey('activity-primary'),
                    onPressed: action,
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.error = false, this.success = false});
  final String text;
  final bool error;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error
          ? HomePalette.errorSurface
          : success
          ? HomePalette.tint
          : HomePalette.paper,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 14,
        height: 1.5,
        color: error
            ? HomePalette.error
            : success
            ? HomePalette.recovery
            : HomePalette.muted,
      ),
    ),
  );
}

Widget _notice(String text, {bool error = false, bool success = false}) =>
    _Notice(text, error: error, success: success);

String _rhythmLabel(RhythmState state) => switch (state) {
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '休息',
};

String _reasonLabel(StuckReasonCode value) => switch (value) {
  StuckReasonCode.taskTooLarge => '任务太大',
  StuckReasonCode.unclearNextStep => '不知道下一步',
  StuckReasonCode.sleepy => '困',
  StuckReasonCode.brainFog => '脑雾',
  StuckReasonCode.anxious => '焦虑',
  StuckReasonCode.interrupted => '被打断',
  StuckReasonCode.unsure => '说不清',
  StuckReasonCode.other => '其他',
};

String _methodLabel(RecoveryMethod value) => switch (value) {
  RecoveryMethod.walk => '散步',
  RecoveryMethod.meal => '吃饭',
  RecoveryMethod.shower => '洗澡',
  RecoveryMethod.empty => '放空',
  RecoveryMethod.entertainment => '娱乐',
  RecoveryMethod.switchTask => '切换任务',
  RecoveryMethod.breakDownTask => '拆小任务',
  RecoveryMethod.askForHelp => '寻求帮助',
  RecoveryMethod.other => '其他',
};

String _qualityLabel(RecoveryQuality value) => switch (value) {
  RecoveryQuality.notRecovered => '没缓过来',
  RecoveryQuality.partlyRecovered => '缓过来一些',
  RecoveryQuality.readyToContinue => '可以继续了',
};

const _question = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 30,
  height: 1.35,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _hint = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.5,
  color: HomePalette.muted,
);
const _label = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 12,
  color: HomePalette.muted,
);
const _fieldLabel = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 15,
  color: HomePalette.ink,
);
const _restored = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  color: HomePalette.muted,
);
