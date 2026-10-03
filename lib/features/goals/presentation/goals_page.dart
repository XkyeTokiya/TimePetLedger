import 'package:flutter/material.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/time_contract.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import 'goal_rename_dialog.dart';

enum _GoalAction { rename, archive, restore, delete }

/// Time ownership and lifecycle UI through the existing domain repository.
class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.repository,
    required this.newId,
    required this.now,
    this.archived = false,
  });

  final GoalRepository repository;
  final EntityId Function() newId;
  final InstantMilliseconds Function() now;
  final bool archived;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final _name = TextEditingController();
  List<Goal>? _goals;
  bool _loading = false;
  bool _saving = false;
  bool _saved = false;
  String? _loadError;
  String? _saveError;
  String? _actionNotice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = null;
      _goals = null;
    });
    try {
      final goals = await (widget.archived
          ? widget.repository.listArchived()
          : widget.repository.listActive());
      if (!mounted) return;
      setState(() => _goals = goals);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = '目标列表读取失败，请重试读取。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
      _actionNotice = null;
    });
    try {
      await widget.repository.create(
        id: widget.newId(),
        name: _name.text,
        now: widget.now(),
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _saveError = error.name == 'name'
              ? '名称不能为空，去除首尾空白后最多 200 个字符。'
              : '目标保存失败，输入已保留，请重试。';
          _saving = false;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = '目标保存失败，输入已保留，请重试。';
          _saving = false;
        });
      }
      return;
    }
    if (!mounted) return;
    // create has committed. A failed reread must only retry reading.
    setState(() {
      _name.clear();
      _saved = true;
    });
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _refresh() async {
    if (_saving) return;
    await _load();
  }

  Future<void> _openArchived() async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
      _actionNotice = null;
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GoalsPage(
          repository: widget.repository,
          newId: widget.newId,
          now: widget.now,
          archived: true,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _rename(Goal goal) async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
      _actionNotice = null;
    });
    final committed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoalRenameDialog(
        goal: goal,
        repository: widget.repository,
        now: widget.now,
      ),
    );
    if (!mounted) return;
    if (committed == true) {
      setState(() => _actionNotice = '目标名称已保存。');
      await _load();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _change(Goal goal, _GoalAction action) async {
    if (_saving || _loading) return;
    setState(() {
      _saving = true;
      _saved = false;
      _saveError = null;
      _actionNotice = null;
    });
    try {
      if (action == _GoalAction.delete) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除目标'),
            content: Text(
              '删除“${goal.name}”？未被记录引用的目标将删除；已有活动或明日第一步引用时会归档，保留记录。',
            ),
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
        if (confirm != true || !mounted) return;
      }
      final now = widget.now();
      final String notice;
      switch (action) {
        case _GoalAction.archive:
          await widget.repository.archive(id: goal.id, now: now);
          notice = '目标已归档，可在已归档目标中恢复。';
        case _GoalAction.restore:
          await widget.repository.restore(id: goal.id, now: now);
          notice = '目标已恢复，可重新用于时间归属。';
        case _GoalAction.delete:
          final result = await widget.repository.delete(id: goal.id, now: now);
          notice = switch (result) {
            GoalDeleteResult.deleted => '目标已删除。',
            GoalDeleteResult.archived => '目标已有记录引用，已归档；记录与引用保留，可在已归档目标中恢复。',
            GoalDeleteResult.notFound => '目标已不存在。',
          };
        case _GoalAction.rename:
          throw StateError('Rename uses its input dialog.');
      }
      if (!mounted) return;
      setState(() => _actionNotice = notice);
      // The operation has committed; read failure only exposes a read retry.
      await _load();
    } on GoalNotFoundException {
      if (mounted) {
        setState(() => _saveError = '目标已不存在，请刷新目标列表。');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = '目标操作失败，请重试。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _goalTile(Goal goal) => ListTile(
    key: ValueKey(goal.id),
    title: Text(goal.name),
    subtitle: widget.archived ? const Text('已归档') : null,
    trailing: PopupMenuButton<_GoalAction>(
      key: ValueKey('goal-actions-${goal.id}'),
      tooltip: '管理目标',
      enabled: !_saving && !_loading,
      onSelected: (action) {
        if (action == _GoalAction.rename) {
          _rename(goal);
        } else {
          _change(goal, action);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: _GoalAction.rename, child: Text('改名')),
        if (widget.archived)
          const PopupMenuItem(value: _GoalAction.restore, child: Text('恢复目标'))
        else
          const PopupMenuItem(value: _GoalAction.archive, child: Text('归档目标')),
        const PopupMenuItem(value: _GoalAction.delete, child: Text('删除目标')),
      ],
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.archived ? '已归档目标' : '目标')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('目标用于记录时间归属。普通活动和睡眠都可以直接记录。'),
        const SizedBox(height: 16),
        if (!widget.archived) ...[
          TextField(
            key: const ValueKey('goal-name'),
            controller: _name,
            enabled: !_saving,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '目标名称'),
            onChanged: (_) => setState(() {
              _saveError = null;
              _saved = false;
              _actionNotice = null;
            }),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving || _loading ? null : _create,
            child: Text(_saving ? '正在保存目标…' : '创建目标'),
          ),
        ],
        if (_saveError != null) Text(_saveError!),
        if (_saved) const Text('目标已保存。'),
        if (_actionNotice != null) Text(_actionNotice!),
        if (!widget.archived)
          OutlinedButton(
            onPressed: _saving || _loading ? null : _openArchived,
            child: const Text('查看已归档目标'),
          ),
        const SizedBox(height: 24),
        Text(widget.archived ? '归档管理' : '当前目标'),
        if (_loading) ...[
          const LinearProgressIndicator(),
          const Text('正在读取目标…'),
        ] else if (_loadError != null) ...[
          Text(_loadError!),
          OutlinedButton(
            onPressed: _saving ? null : _refresh,
            child: const Text('重试读取目标'),
          ),
        ] else ...[
          if (_goals!.isEmpty) Text(widget.archived ? '暂无已归档目标。' : '尚未创建目标。'),
          for (final goal in _goals!) _goalTile(goal),
          OutlinedButton(
            onPressed: _saving ? null : _refresh,
            child: const Text('刷新目标'),
          ),
        ],
      ],
    ),
  );
}
