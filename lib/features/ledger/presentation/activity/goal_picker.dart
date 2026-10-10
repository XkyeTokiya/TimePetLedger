import 'package:flutter/material.dart';

import '../../../goals/domain/goal.dart';

/// “推进了哪个目标？”底部面板：选择现有目标、新建目标，或取消。
///
/// 活动理解层与每日复盘共用（Q-004 修订：progress 必须关联 Goal）。
/// 返回所选 / 新建的目标；取消或关闭面板返回 null，调用方保持原选择。
Future<Goal?> showProgressGoalPicker(
  BuildContext context, {
  required Future<List<Goal>> Function() loadGoals,
  Future<Goal> Function(String name)? createGoal,
  String title = '推进了哪个目标？',
  String? guidance,
}) => showModalBottomSheet<Goal>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _GoalPickerSheet(
    loadGoals: loadGoals,
    createGoal: createGoal,
    title: title,
    guidance: guidance,
  ),
);

class _GoalPickerSheet extends StatefulWidget {
  const _GoalPickerSheet({
    required this.loadGoals,
    required this.createGoal,
    required this.title,
    required this.guidance,
  });

  final Future<List<Goal>> Function() loadGoals;
  final Future<Goal> Function(String name)? createGoal;
  final String title;
  final String? guidance;

  @override
  State<_GoalPickerSheet> createState() => _GoalPickerSheetState();
}

class _GoalPickerSheetState extends State<_GoalPickerSheet> {
  List<Goal>? _goals;
  String? _error;
  bool _creating = false;
  bool _busy = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _goals = null;
      _error = null;
    });
    try {
      final goals = await widget.loadGoals();
      if (!mounted) return;
      setState(() => _goals = goals);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '目标读取失败，请重试。');
    }
  }

  Future<void> _create() async {
    final create = widget.createGoal;
    if (create == null || _busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '先给目标起个名字。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final goal = await create(name);
      if (mounted) Navigator.of(context).pop(goal);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '新建目标失败，请重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('progress-goal-picker'),
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
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.guidance != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.guidance!,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          if (_goals == null && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_goals == null)
            Row(
              children: [
                Expanded(child: Text(_error!)),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            )
          else ...[
            for (final goal in _goals!) ...[
              Material(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: ValueKey('progress-goal-option-${goal.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy ? null : () => Navigator.of(context).pop(goal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colors.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_goals!.isEmpty && widget.createGoal == null)
              Text(
                '还没有目标；可以先到目标页新建一个。',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            if (widget.createGoal != null) ...[
              const SizedBox(height: 2),
              if (!_creating)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('progress-goal-new'),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _creating = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建目标'),
                  ),
                )
              else ...[
                TextField(
                  key: const ValueKey('progress-goal-name'),
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: '目标名称'),
                  onSubmitted: (_) => _create(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _creating = false),
                      child: const Text('返回选择'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('progress-goal-create'),
                      onPressed: _busy ? null : _create,
                      child: Text(_busy ? '正在创建' : '创建并关联'),
                    ),
                  ],
                ),
              ],
            ],
          ],
          if (_error != null && _goals != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              key: const ValueKey('progress-goal-error'),
              style: TextStyle(fontSize: 13, color: colors.error),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('progress-goal-cancel'),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ),
        ],
      ),
    );
  }
}
