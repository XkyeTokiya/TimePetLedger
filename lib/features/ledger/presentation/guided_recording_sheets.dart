import 'package:flutter/material.dart';

import '../../goals/domain/goal.dart';
import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import 'recording_form_controller.dart';

typedef RecordingGoalCreator = Future<Goal> Function(String name);

class GuidedGoalChoice {
  const GuidedGoalChoice(this.id, {this.created = false});
  final String id;
  final bool created;
}

Future<GuidedGoalChoice?> showGuidedGoalSheet(
  BuildContext context, {
  required RecordingFormController model,
  RecordingGoalCreator? createGoal,
}) => showModalBottomSheet<GuidedGoalChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .75,
    child: AnimatedBuilder(
      animation: model,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('关联已有目标', style: Theme.of(context).textTheme.titleLarge),
          const Text('这是本笔的时间归属，不会修改常用目标。'),
          if (model.goalsLoading) const LinearProgressIndicator(),
          if (model.goalsError != null) ...[
            Text(model.goalsError!),
            TextButton(onPressed: model.loadGoals, child: const Text('重试读取目标')),
          ] else if (!model.goalsLoading) ...[
            if (model.activeGoals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('还没有可关联的目标。也可以不关联，继续记录。'),
              ),
            for (final goal in model.activeGoals)
              ListTile(
                key: ValueKey('guided-goal-${goal.id}'),
                title: Text(goal.name),
                subtitle:
                    model.activeGoals.where((g) => g.name == goal.name).length >
                        1
                    ? Text(
                        '创建于 ${DateTime.fromMillisecondsSinceEpoch(goal.createdAt)}',
                      )
                    : null,
                trailing: model.goalId == goal.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, GuidedGoalChoice(goal.id)),
              ),
          ],
          if (createGoal != null)
            OutlinedButton.icon(
              onPressed: () async {
                final goal = await showDialog<Goal>(
                  context: context,
                  builder: (_) => _CreateGoalDialog(create: createGoal),
                );
                if (context.mounted && goal != null) {
                  Navigator.pop(
                    context,
                    GuidedGoalChoice(goal.id, created: true),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('创建长期目标'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回填写'),
          ),
        ],
      ),
    ),
  ),
);

class _CreateGoalDialog extends StatefulWidget {
  const _CreateGoalDialog({required this.create});
  final RecordingGoalCreator create;
  @override
  State<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final text = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final goal = await widget.create(text.text);
      if (mounted) Navigator.pop(context, goal);
    } on ArgumentError {
      if (mounted) setState(() => error = '请填写1至200个字符的目标名称。');
    } catch (_) {
      if (mounted) setState(() => error = '目标未创建成功，输入已保留，请重试。');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('创建长期目标'),
      content: TextField(
        key: const ValueKey('guided-goal-name'),
        controller: text,
        readOnly: saving,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(labelText: '目标名称', errorText: error),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: saving ? null : create,
          child: Text(saving ? '正在创建' : '创建并关联'),
        ),
      ],
    ),
  );
}

class GuidedRecordingDetails {
  GuidedRecordingDetails.from(RecordingFormController model)
    : note = model.note,
      hint = model.continuationHint,
      reasonText = model.stuckReasonText,
      reason = model.stuckReasonCode,
      method = model.recoveryMethod,
      quality = model.recoveryQuality;
  String note;
  String hint;
  String reasonText;
  StuckReasonCode? reason;
  RecoveryMethod? method;
  RecoveryQuality? quality;
}

Future<GuidedRecordingDetails?> showGuidedDetailsSheet(
  BuildContext context,
  RecordingFormController model,
) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<GuidedRecordingDetails>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DetailsSheet(
      state: model.rhythmState,
      initial: GuidedRecordingDetails.from(model),
    ),
  );
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({required this.state, required this.initial});
  final RhythmState? state;
  final GuidedRecordingDetails initial;
  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final details = widget.initial;
  late final note = TextEditingController(text: details.note);
  late final hint = TextEditingController(text: details.hint);
  late final reason = TextEditingController(text: details.reasonText);
  bool errors = false;
  @override
  void dispose() {
    note.dispose();
    hint.dispose();
    reason.dispose();
    super.dispose();
  }

  String? error(TextEditingController text) =>
      errors && text.text.trim().runes.length > 2000 ? '最多2000个字符。' : null;

  Widget choices<T>(
    List<T> values,
    T? selected,
    String Function(T) label,
    void Function(T?) update,
  ) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(label(value)),
          selected: selected == value,
          onSelected: (_) =>
              setState(() => update(selected == value ? null : value)),
        ),
    ],
  );

  Widget field(TextEditingController value, String label, String key) =>
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: TextField(
          key: ValueKey(key),
          controller: value,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: label,
            errorText: error(value),
          ),
        ),
      );

  void apply() {
    setState(() => errors = true);
    if (error(note) != null ||
        (widget.state != null && error(hint) != null) ||
        (widget.state == RhythmState.stuck && error(reason) != null)) {
      return;
    }
    details.note = note.text;
    details.hint = hint.text;
    details.reasonText = reason.text;
    Navigator.pop(context, details);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('补充这笔记录', style: Theme.of(context).textTheme.titleLarge),
            const Text('都可以留空。'),
            if (widget.state != null) field(hint, '下次从哪里继续（选填）', 'guided-hint'),
            if (widget.state == RhythmState.stuck) ...[
              const SizedBox(height: 20),
              const Text('卡住原因（选填）'),
              choices(
                StuckReasonCode.values,
                details.reason,
                reasonLabel,
                (value) => details.reason = value,
              ),
              field(reason, '原因说明（选填）', 'guided-reason'),
            ],
            if (widget.state == RhythmState.recovery) ...[
              const SizedBox(height: 20),
              const Text('恢复方式（选填）'),
              choices(
                RecoveryMethod.values,
                details.method,
                methodLabel,
                (value) => details.method = value,
              ),
              const SizedBox(height: 16),
              const Text('恢复感受（选填）'),
              choices(
                RecoveryQuality.values,
                details.quality,
                qualityLabel,
                (value) => details.quality = value,
              ),
            ],
            field(note, '备注（选填）', 'guided-note'),
            const SizedBox(height: 16),
            FilledButton(onPressed: apply, child: const Text('保留补充')),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消补充'),
            ),
          ],
        ),
      ),
    ),
  );
}

String reasonLabel(StuckReasonCode value) => switch (value) {
  StuckReasonCode.taskTooLarge => '任务太大',
  StuckReasonCode.unclearNextStep => '不知道下一步',
  StuckReasonCode.sleepy => '困',
  StuckReasonCode.brainFog => '脑雾',
  StuckReasonCode.anxious => '焦虑',
  StuckReasonCode.interrupted => '被打断',
  StuckReasonCode.unsure => '说不清',
  StuckReasonCode.other => '其他',
};
String methodLabel(RecoveryMethod value) => switch (value) {
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
String qualityLabel(RecoveryQuality value) => switch (value) {
  RecoveryQuality.notRecovered => '没缓过来',
  RecoveryQuality.partlyRecovered => '缓过来一些',
  RecoveryQuality.readyToContinue => '可以继续了',
};
