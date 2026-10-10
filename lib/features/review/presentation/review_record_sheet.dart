import 'package:flutter/material.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal.dart';
import '../../ledger/domain/rhythm_annotation.dart';
import '../../ledger/domain/rhythm_state.dart';
import '../../ledger/domain/time_block.dart';
import '../../ledger/presentation/activity/goal_picker.dart';
import '../../ledger/presentation/recording_time_picker.dart';

/// 复盘中查看 / 修改一条记录的底部面板。
///
/// 只提供改名、改时间、关联 / 取消目标与删除；每项改动立即写入，
/// 失败在面板内提示重试。节奏解释仍走复盘第 2 步。
Future<void> showReviewRecordSheet(
  BuildContext context, {
  required CivilDate date,
  required TimeBlock block,
  required RhythmAnnotation? annotation,
  required String? goalName,
  required Future<List<Goal>> Function() loadGoals,
  Future<Goal> Function(String name)? createGoal,
  required Future<void> Function(EntityId? goalId) onLinkGoal,
  required Future<void> Function(String title) onRename,
  required Future<void> Function(int startedAt, int endedAt) onRetime,
  required Future<void> Function() onDelete,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _ReviewRecordSheet(
    date: date,
    block: block,
    annotation: annotation,
    goalName: goalName,
    loadGoals: loadGoals,
    createGoal: createGoal,
    onLinkGoal: onLinkGoal,
    onRename: onRename,
    onRetime: onRetime,
    onDelete: onDelete,
  ),
);

class _ReviewRecordSheet extends StatefulWidget {
  const _ReviewRecordSheet({
    required this.date,
    required this.block,
    required this.annotation,
    required this.goalName,
    required this.loadGoals,
    required this.createGoal,
    required this.onLinkGoal,
    required this.onRename,
    required this.onRetime,
    required this.onDelete,
  });

  final CivilDate date;
  final TimeBlock block;
  final RhythmAnnotation? annotation;
  final String? goalName;
  final Future<List<Goal>> Function() loadGoals;
  final Future<Goal> Function(String name)? createGoal;
  final Future<void> Function(EntityId? goalId) onLinkGoal;
  final Future<void> Function(String title) onRename;
  final Future<void> Function(int startedAt, int endedAt) onRetime;
  final Future<void> Function() onDelete;

  @override
  State<_ReviewRecordSheet> createState() => _ReviewRecordSheetState();
}

class _ReviewRecordSheetState extends State<_ReviewRecordSheet> {
  late final _title = TextEditingController(text: widget.block.title ?? '');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String get _stateLabel => switch (widget.annotation?.state) {
    RhythmState.progress => '推进',
    RhythmState.stuck => '卡住',
    RhythmState.recovery => '恢复',
    null => '不判断',
  };

  Future<void> _run(Future<void> Function() action, {String? failure}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure ?? error.toString();
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final value = isStart ? widget.block.startedAt : widget.block.endedAt;
    final range = ledgerClockRangeFor(
      startedAt: widget.block.startedAt,
      endedAt: widget.block.endedAt,
      isStart: isStart,
      entryDate: widget.date,
    );
    final result = await showRecordingTimePicker(
      context,
      value: value,
      date: widget.date,
      first: range.first,
      last: range.last,
    );
    if (!mounted || result == null || result == value) return;
    await _run(
      () => widget.onRetime(
        isStart ? result : widget.block.startedAt,
        isStart ? widget.block.endedAt : result,
      ),
      failure: '时间没有改成功；先后与其他记录仍按原样保留。',
    );
  }

  Future<void> _linkGoal() async {
    final goal = await showProgressGoalPicker(
      context,
      loadGoals: widget.loadGoals,
      createGoal: widget.createGoal,
      title: '关联目标',
      guidance: '推进中的记录必须有目标；其他状态可以随时取消。',
    );
    if (!mounted || goal == null) return;
    await _run(() => widget.onLinkGoal(goal.id), failure: '目标没有关联成功，请重试。');
  }

  Future<void> _unlinkGoal() =>
      _run(() => widget.onLinkGoal(null), failure: '取消关联失败：推进中的记录必须有目标。');

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后这段时间会回到未记录；节奏解释一并移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('review-record-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
    }, failure: '删除失败，请重试。');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('review-record-sheet'),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.block.knowledgeState.name == 'unknown'
                ? '想不起来'
                : (widget.block.title ?? '未写内容'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${_clock(widget.block.startedAt)} – ${_clock(widget.block.endedAt)}'
            ' · $_stateLabel',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('review-record-title'),
            controller: _title,
            enabled: !_busy,
            decoration: const InputDecoration(labelText: '这段时间在做什么？'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: const ValueKey('review-record-save-title'),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => widget.onRename(_title.text),
                      failure: '名称没有保存成功，请重试。',
                    ),
              child: const Text('保存名称'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('review-record-start'),
                  onPressed: _busy ? null : () => _pickTime(isStart: true),
                  child: Text('开始 ${_clock(widget.block.startedAt)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('review-record-end'),
                  onPressed: _busy ? null : () => _pickTime(isStart: false),
                  child: Text('结束 ${_clock(widget.block.endedAt)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.goalName == null ? '未关联目标' : '目标：${widget.goalName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              TextButton(
                key: const ValueKey('review-record-goal'),
                onPressed: _busy ? null : _linkGoal,
                child: Text(widget.goalName == null ? '关联目标' : '更改目标'),
              ),
              if (widget.goalName != null)
                TextButton(
                  key: const ValueKey('review-record-unlink'),
                  onPressed: _busy ? null : _unlinkGoal,
                  child: const Text('取消关联'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              key: const ValueKey('review-record-error'),
              style: TextStyle(fontSize: 13, color: colors.error),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('review-record-delete'),
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: const Text('删除这条记录'),
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(int value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}
