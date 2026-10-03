import 'package:flutter/material.dart';

import '../../../core/time/time_contract.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';

class GoalRenameDialog extends StatefulWidget {
  const GoalRenameDialog({
    super.key,
    required this.goal,
    required this.repository,
    required this.now,
  });

  final Goal goal;
  final GoalRepository repository;
  final InstantMilliseconds Function() now;

  @override
  State<GoalRenameDialog> createState() => _GoalRenameDialogState();
}

class _GoalRenameDialogState extends State<GoalRenameDialog> {
  late final _name = TextEditingController(text: widget.goal.name);
  bool _saving = false;
  bool _missing = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || _missing) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.rename(
        id: widget.goal.id,
        name: _name.text,
        now: widget.now(),
      );
      if (mounted) Navigator.pop(context, true);
    } on GoalNotFoundException {
      if (mounted) {
        setState(() {
          _missing = true;
          _error = '目标已不存在，无法改名。';
        });
      }
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(
          () => _error = error.name == 'name'
              ? '名称不能为空，去除首尾空白后最多 200 个字符。'
              : '目标改名失败，输入已保留，请重试。',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '目标改名失败，输入已保留，请重试。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('修改目标名称'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('goal-rename-name'),
              controller: _name,
              enabled: !_saving && !_missing,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '目标名称'),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving || _missing ? null : _save,
          child: Text(_saving ? '正在保存名称…' : '保存名称'),
        ),
      ],
    ),
  );
}
