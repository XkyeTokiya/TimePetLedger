import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../features/goals/domain/goal.dart';
import '../../application/activity_understanding.dart';
import '../../application/recording_entry_editor.dart';
import '../../application/recording_entry_saver.dart';
import '../../application/recording_time_suggestion.dart';
import '../../domain/block_knowledge_state.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/recording_draft_store.dart';
import '../../domain/time_block.dart';
import '../../domain/time_precision.dart';
import '../recording_form.dart' show formatRecordingTime;
import '../recording_form_controller.dart';
import '../recording_time_picker.dart';
import '../sleep_time_input.dart';
import '../summary_formatting.dart';
import 'activity_sheet_frame.dart';
import 'activity_understanding_page.dart';

/// 记录面板的提交结果：事实与来源（新建 / 更正）。
class ActivityQuickSheetResult {
  const ActivityQuickSheetResult({
    required this.timeBlock,
    required this.isEdit,
  });

  final TimeBlock timeBlock;
  final bool isEdit;
}

/// 从底部打开记录面板（Q-047 事实优先：时间 → 做了什么 → 保存）。
///
/// 面板复用 [RecordingFormController] 的输入、校验、草稿与提交合同；
/// 新建保存成功后不换窗口，同一面板原地切换到保存后理解层
/// （目标 → 状态 → 折叠补充），完成或关闭后再返回账本。
Future<ActivityQuickSheetResult?> showActivityQuickSheet(
  BuildContext context, {
  required RecordingDraftContext entryContext,
  required RecordingDraftStore store,
  required Future<RecordingTimeSuggestion> Function() loadSuggestion,
  RecordingEntrySaver? entrySaver,
  RecordingEntryEditor? entryEditor,
  ActivityUnderstandingService? understanding,
  Future<List<Goal>> Function()? loadGoals,
}) => showModalBottomSheet<ActivityQuickSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  enableDrag: false,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => ActivityQuickSheet(
    entryContext: entryContext,
    store: store,
    loadSuggestion: loadSuggestion,
    entrySaver: entrySaver,
    entryEditor: entryEditor,
    understanding: understanding,
    loadGoals: loadGoals,
  ),
);

class ActivityQuickSheet extends StatefulWidget {
  const ActivityQuickSheet({
    super.key,
    required this.entryContext,
    required this.store,
    required this.loadSuggestion,
    this.entrySaver,
    this.entryEditor,
    this.understanding,
    this.loadGoals,
  });

  final RecordingDraftContext entryContext;
  final RecordingDraftStore store;
  final Future<RecordingTimeSuggestion> Function() loadSuggestion;
  final RecordingEntrySaver? entrySaver;
  final RecordingEntryEditor? entryEditor;

  /// 保存后理解层的写入服务；为空时保存后直接关闭面板。
  final ActivityUnderstandingService? understanding;
  final Future<List<Goal>> Function()? loadGoals;

  @override
  State<ActivityQuickSheet> createState() => _ActivityQuickSheetState();
}

enum _SheetStage { form, understanding }

class _ActivityQuickSheetState extends State<ActivityQuickSheet> {
  late final RecordingFormController model;
  late final TextEditingController _title;
  bool _showErrors = false;
  bool _allowPop = false;
  bool _exiting = false;
  bool _recoveryPromptShown = false;
  _SheetStage _stage = _SheetStage.form;
  TimeBlock? _block;
  double? _understandingHeight;
  final _understandingKey = GlobalKey<ActivityUnderstandingPageState>();

  bool get _editing => widget.entryContext.entry == RecordingDraftEntry.edit;

  @override
  void initState() {
    super.initState();
    model = RecordingFormController(
      context: widget.entryContext,
      store: widget.store,
      loadSuggestion: widget.loadSuggestion,
      entrySaver: widget.entrySaver,
      entryEditor: widget.entryEditor,
    );
    _title = TextEditingController(text: model.title);
    model.addListener(_changed);
    model.initialize();
  }

  void _changed() {
    if (_title.text != model.title) _title.text = model.title;
    if (mounted) setState(() {});
    if (model.pendingRecovery != null && !_recoveryPromptShown) {
      _recoveryPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _chooseRecovery());
    }
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    model.dispose();
    _title.dispose();
    super.dispose();
  }

  // ----- 时间 -----

  Future<void> _time({required bool isStart, bool isDate = false}) async {
    final value = isStart ? model.time.startedAt : model.time.endedAt;
    final int? result;
    if (isDate) {
      result = await showRecordingDatePicker(
        context,
        value: value,
        date: widget.entryContext.date,
      );
    } else {
      final range = ledgerClockRangeFor(
        startedAt: model.time.startedAt,
        endedAt: model.time.endedAt,
        isStart: isStart,
        entryDate: widget.entryContext.date,
      );
      result = await showRecordingTimePicker(
        context,
        value: value,
        date: widget.entryContext.date,
        first: range.first,
        last: range.last,
      );
    }
    if (!mounted || result == null) return;
    model.setTime(
      start: isStart ? result : model.time.startedAt,
      end: isStart ? model.time.endedAt : result,
    );
  }

  Future<void> _duration() async {
    final start = model.time.startedAt;
    final end = model.time.endedAt;
    if (start == null && end == null) return;
    final result = await showRecordingDurationPicker(
      context,
      startedAt: start,
      endedAt: end,
      // 只有一端时用时长补齐另一端；两端都有时是调整。
      title: start != null && end != null ? '调整时长' : '选择时长',
    );
    if (!mounted || result == null) return;
    model.setTime(start: result.start, end: result.end);
  }

  // ----- 提交 -----

  Future<void> _save() async {
    if (!model.editable || _exiting) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    if (!model.valid) return;
    _rememberFormHeight();
    await model.submit();
    if (!mounted) return;
    final committed = model.committed;
    if (committed != null && committed.complete) _afterCommit();
  }

  /// 记住记录面板当前高度（扣除键盘占位），供保存后的理解层共用。
  ///
  /// 在提交前记录，避免把提交后的“已保存”提示高度算进去。
  void _rememberFormHeight() {
    final size = context.size;
    if (size == null) return;
    _understandingHeight =
        size.height - MediaQuery.viewInsetsOf(context).bottom;
  }

  /// 事实成立之后：新建且 known 时原地进入理解层，其余直接关闭面板。
  void _afterCommit() {
    final committed = model.committed;
    if (committed == null || !committed.complete) return;
    final canUnderstand =
        !_editing &&
        committed.timeBlock.knowledgeState == BlockKnowledgeState.known &&
        widget.understanding != null &&
        widget.loadGoals != null;
    if (!canUnderstand) {
      unawaited(_complete());
      return;
    }
    _rememberFormHeight();
    setState(() {
      _block = committed.timeBlock;
      _stage = _SheetStage.understanding;
    });
  }

  Future<void> _complete() async {
    final committed = model.committed;
    if (committed == null || !committed.complete) return;
    _allowPop = true;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(
      ActivityQuickSheetResult(
        timeBlock: committed.timeBlock,
        isEdit: _editing,
      ),
    );
  }

  void _closeUnderstanding() => unawaited(_complete());

  Future<void> _finish() async {
    final refreshed = await model.retryFinish();
    if (mounted && refreshed != null) _afterCommit();
  }

  Future<void> _leave() async {
    if (_exiting || model.submitting || model.discarding) return;
    // 理解层内：系统返回 / 鼠标后退先退回上一问，首步才收起面板。
    if (_stage == _SheetStage.understanding) {
      if (_understandingKey.currentState?.handleBack() == true) return;
      await _complete();
      return;
    }
    if (model.committed != null) {
      if (model.committed!.complete) {
        await _complete();
      } else {
        await _finish();
      }
      return;
    }
    setState(() => _exiting = true);
    final okay = await model.flush();
    if (!mounted) return;
    if (!okay) {
      final leaveAnyway = await _confirmLeaveWithoutRecovery();
      if (!mounted) return;
      if (!leaveAnyway) {
        setState(() => _exiting = false);
        return;
      }
    }
    _allowPop = true;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(null);
  }

  Future<void> _restart() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_editing ? '重新编辑？' : '重新填写？'),
        content: const Text('本次尚未正式保存的修改将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续填写'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_editing ? '重新编辑' : '重新填写'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await model.restartInput();
  }

  Future<void> _chooseRecovery() async {
    if (!mounted || model.pendingRecovery == null) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_editing ? '继续上次修改？' : '继续上次填写？'),
        content: const Text('这个入口还有本次使用期间未完成的内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_editing ? '重新编辑' : '重新填写'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续填写'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      await model.resumePendingInput();
    } else {
      await model.restartInput();
    }
  }

  Future<bool> _confirmLeaveWithoutRecovery() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('本次填写暂时无法保留'),
          content: const Text('仍然离开可能丢失最近的修改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续填写'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然离开'),
            ),
          ],
        ),
      ) ??
      false;

  // ----- 构建 -----

  ColorScheme get _colors => Theme.of(context).colorScheme;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      // 只保留新一帧：旧内容立即移除，避免交叉淡化时两套内容同时参与
      // 布局与绘制（含模糊层）造成的卡顿。
      layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
      child: _stage == _SheetStage.understanding
          ? _understandingStage()
          : _formStage(),
    ),
  );

  /// 保存后理解层：目标 / 状态 / 补充共用同一高度（记录面板当时的高度，
  /// 不压缩高的、只把矮的补齐），阶段切换与保存这一步窗口都不跳动。
  Widget _understandingStage() => ActivitySheetFrame(
    key: const ValueKey('activity-sheet-frame'),
    height: _understandingHeight,
    child: SingleChildScrollView(
      key: const ValueKey('sheet-stage-understanding'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: KeyedSubtree(
        key: const ValueKey('activity-understanding'),
        child: ActivityUnderstandingPage(
          key: _understandingKey,
          mode: ActivityUnderstandingMode.afterSave,
          recordId: _block!.id,
          fact: _block,
          service: widget.understanding!,
          loadGoals: widget.loadGoals!,
          onClose: _closeUnderstanding,
        ),
      ),
    ),
  );

  /// 记录表单：首个面板按内容取高（不套固定视口），键盘弹出时整体上移。
  Widget _formStage() => Padding(
    key: const ValueKey('sheet-stage-form'),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (model.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (model.loadError != null)
            _loadFailure()
          else
            ..._form(),
        ],
      ),
    ),
  );

  bool get _canRestart =>
      model.editable && model.committed == null && model.hasUserChanges;

  Widget _header() => Row(
    children: [
      Expanded(
        child: Text(
          _editing ? '更正记录' : '记录一笔',
          key: const ValueKey('activity-sheet-title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (_canRestart)
        IconButton(
          key: const ValueKey('activity-reset'),
          onPressed: _exiting ? null : _restart,
          icon: const Icon(Icons.restart_alt),
          tooltip: _editing ? '重新编辑' : '重新填写',
        ),
      IconButton(
        key: const ValueKey('activity-close'),
        onPressed: model.submitting ? null : _leave,
        icon: const Icon(Icons.close),
        tooltip: '收起',
      ),
    ],
  );

  Widget _loadFailure() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(model.loadError!, style: TextStyle(color: _colors.error)),
      const SizedBox(height: 8),
      if (model.missingOriginal)
        TextButton(onPressed: model.restartInput, child: const Text('清除未完成输入'))
      else
        FilledButton(onPressed: model.initialize, child: const Text('重试读取')),
    ],
  );

  List<Widget> _form() {
    final selected = model.knowledgeState ?? BlockKnowledgeState.known;
    return [
      _endpoint(
        '开始',
        model.time.startedAt,
        'activity-start',
        () => _time(isStart: true),
        () => _time(isStart: true, isDate: true),
      ),
      _endpoint(
        '结束',
        model.time.endedAt,
        'activity-end',
        () => _time(isStart: false),
        () => _time(isStart: false, isDate: true),
      ),
      _durationLine(),
      const SizedBox(height: 4),
      _questionBlockEntry(unknown: selected == BlockKnowledgeState.unknown),
      const SizedBox(height: 6),
      SegmentedButton<BlockKnowledgeState>(
        key: const ValueKey('activity-knowledge'),
        segments: const [
          ButtonSegment(value: BlockKnowledgeState.known, label: Text('记得')),
          ButtonSegment(
            value: BlockKnowledgeState.unknown,
            label: Text('想不起来'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: model.editable
            ? (values) {
                final next = values.first;
                // 切到“想不起来”时收起输入：退出焦点并关闭键盘。
                if (next == BlockKnowledgeState.unknown) {
                  FocusManager.instance.primaryFocus?.unfocus();
                }
                model.setKnowledge(next);
              }
            : null,
      ),
      const SizedBox(height: 10),
      Text(
        '目标与状态可以在保存后按需补充，都不阻挡保存。',
        style: TextStyle(fontSize: 13, color: _colors.onSurfaceVariant),
      ),
      if (model.candidates.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          '这一天还有没记录的区间，可以直接选一段。',
          style: TextStyle(fontSize: 13, color: _colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (final candidate in model.candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: model.editable
                  ? () => model.chooseCandidate(candidate)
                  : null,
              child: Text(
                '${formatRecordingTime(candidate.startedAt)} → '
                '${formatRecordingTime(candidate.endedAt)}',
              ),
            ),
          ),
      ],
      if (_showErrors && model.timeError != null) ...[
        const SizedBox(height: 10),
        Text(
          model.timeError!,
          key: const ValueKey('activity-time-error'),
          style: TextStyle(fontSize: 14, color: _colors.error),
        ),
      ],
      ..._notices(),
      const SizedBox(height: 16),
      _primaryAction(),
    ];
  }

  List<Widget> _notices() {
    final committed = model.committed;
    return [
      if (model.storageError != null) ...[
        const SizedBox(height: 10),
        _notice(model.storageError!, error: true),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: model.editable ? model.retrySave : null,
            child: const Text('重试保留本次填写'),
          ),
        ),
      ],
      if (committed != null) ...[
        const SizedBox(height: 10),
        _notice(
          committed.complete
              ? '记录已保存，可以回到账本了。'
              : '${_editing ? '更正已保存到账本' : '已正式保存到账本'}，请不要再次提交。'
                    '${committed.draftCleared ? '' : '本地收尾未完成；请重试。'}'
                    '${committed.refreshed == null ? '账本刷新失败，记录已保存；请重试刷新。' : ''}',
          success: true,
        ),
      ],
      if (model.submitError != null && model.conflicts.isEmpty) ...[
        const SizedBox(height: 10),
        _notice(model.submitError!, error: true),
      ],
      for (final conflict in model.conflicts) ...[
        const SizedBox(height: 10),
        _notice(
          '已有记录：${formatSleepTime(conflict.startedAt)} — '
          '${formatSleepTime(conflict.endedAt)}',
          error: true,
        ),
      ],
    ];
  }

  Widget _primaryAction() {
    final committed = model.committed;
    final String label = model.submitting
        ? '正在保存'
        : committed != null
        ? (committed.complete ? '记录已保存' : '继续清理并刷新')
        : (_editing ? '保存修改' : '保存记录');
    final VoidCallback? onPressed =
        model.submitting || committed?.complete == true
        ? null
        : committed != null
        ? _finish
        : (model.editable ? _save : null);
    return FilledButton(
      key: const ValueKey('activity-primary'),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Widget _durationLine() {
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
    // 任意一端填好就可以用时长补齐另一端；两端都有才是“调整”。
    final hasEndpoint = start != null || end != null;
    final hint = duration != null
        ? null
        : start != null && end == null
        ? '用时长补上结束'
        : end != null && start == null
        ? '用时长补上开始'
        : '开始和结束可以按大概填写';
    return Padding(
      padding: const EdgeInsets.only(left: 46, top: 6),
      child: Row(
        children: [
          if (duration != null)
            Text(
              duration,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _colors.onSurfaceVariant,
              ),
            )
          else
            Expanded(
              child: Text(
                hint!,
                style: TextStyle(fontSize: 13, color: _colors.onSurfaceVariant),
              ),
            ),
          if (hasEndpoint) ...[
            const SizedBox(width: 8),
            InkWell(
              key: const ValueKey('activity-duration'),
              borderRadius: BorderRadius.circular(8),
              onTap: model.editable ? _duration : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Text(
                  duration != null ? '调整时长' : '选时长',
                  style: TextStyle(fontSize: 13, color: _colors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 问题区（记得 ↔ 想不起来）：真实问题与输入框始终留在原位；
  /// “想不起来”只在其上盖一层磨砂，元素不移动、面板高度不变化。
  Widget _questionBlockEntry({required bool unknown}) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('这段时间大概在做什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('activity'),
              controller: _title,
              readOnly: !model.editable,
              minLines: 3,
              maxLines: 6,
              onChanged: model.setTitle,
              decoration: InputDecoration(
                hintText: '几个字也可以',
                errorText: _showErrors ? model.titleError : null,
              ),
            ),
          ],
        ),
      ),
      if (unknown)
        Positioned.fill(
          child: AbsorbPointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                key: const ValueKey('activity-unknown-mask'),
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: _colors.surface.withValues(alpha: .55)),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _endpoint(
    String name,
    int? value,
    String key,
    VoidCallback onTime,
    VoidCallback onDate,
  ) => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _colors.outlineVariant)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            name,
            style: TextStyle(fontSize: 13, color: _colors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: InkWell(
            key: ValueKey('$key-time'),
            borderRadius: BorderRadius.circular(10),
            onTap: model.editable ? onTime : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.centerLeft,
              child: Text(
                value == null
                    ? '选时间'
                    : formatRecordingTime(value).split(' ').last,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: _colors.onSurface,
                ),
              ),
            ),
          ),
        ),
        TextButton(
          key: ValueKey('$key-date'),
          onPressed: model.editable ? onDate : null,
          child: Text(value == null ? '选日期' : _endpointDate(value)),
        ),
      ],
    ),
  );

  String _endpointDate(int value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    final year = date.year == widget.entryContext.date.year
        ? ''
        : '${date.year}年';
    return '$year${date.month}月${date.day}日';
  }
}

class _SheetNotice extends StatelessWidget {
  const _SheetNotice(this.text, {this.error = false, this.success = false});
  final String text;
  final bool error;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: error ? colors.error : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

Widget _notice(String text, {bool error = false, bool success = false}) =>
    _SheetNotice(text, error: error, success: success);
