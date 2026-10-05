import 'package:flutter/material.dart';

import '../domain/goal.dart';

/// Returns only a committed goal. Association remains owned by the caller.
Future<Goal?> showGoalCreateSheet(
  BuildContext context,
  Future<Goal> Function(String) create,
) => showModalBottomSheet<Goal>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _GoalCreateSheet(create: create),
);

class _GoalCreateSheet extends StatefulWidget {
  const _GoalCreateSheet({required this.create});
  final Future<Goal> Function(String) create;
  @override
  State<_GoalCreateSheet> createState() => _GoalCreateSheetState();
}

class _GoalCreateSheetState extends State<_GoalCreateSheet> {
  final name = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    final value = name.text.trim();
    if (value.isEmpty || value.runes.length > 200) {
      setState(() => error = '请填写 1–200 个字符的目标名称');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final goal = await widget.create(value);
      if (mounted) Navigator.pop(context, goal);
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '创建失败，名称已保留，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '创建目标',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '取消创建目标',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('new-goal-name'),
                controller: name,
                readOnly: busy,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: '目标名称',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? '创建中' : '创建并关联'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
