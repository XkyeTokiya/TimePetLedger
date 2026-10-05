import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_status.dart';
import '../../goals/presentation/goal_create_sheet.dart';
import '../application/recording_time_suggestion.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/projection/derived_duration.dart';
import '../domain/recording_draft_store.dart';
import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import '../domain/time_precision.dart';
import 'activity_time_sheet.dart';
import 'recording_form_controller.dart';
import 'sleep_time_input.dart';
import 'summary_formatting.dart';

enum ActivityPanel { goal, rhythm }

/// The editor owns layout and focus; the supplied controller owns the draft.
class ActivityEditor extends StatefulWidget {
  const ActivityEditor({
    super.key,
    required this.controller,
    required this.createGoal,
    required this.onExit,
    required this.onSaved,
    this.initialPanel = ActivityPanel.rhythm,
    this.conflictName,
  });
  final RecordingFormController controller;
  final Future<Goal> Function(String) createGoal;
  final VoidCallback onExit;
  final VoidCallback onSaved;
  final ActivityPanel? initialPanel;
  final String Function(LedgerFactInterval)? conflictName;
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  final title = TextEditingController();
  final note = TextEditingController();
  final reason = TextEditingController();
  final hint = TextEditingController();
  final titleFocus = FocusNode();
  final reasonFocus = FocusNode();
  final hintFocus = FocusNode();
  final titleKey = GlobalKey();
  final reasonKey = GlobalKey();
  final hintKey = GlobalKey();
  final noteKey = GlobalKey();
  final scroll = ScrollController();
  ActivityPanel? panel;
  bool errors = false;
  bool leaving = false;
  bool loaded = false;
  RecordingFormController get model => widget.controller;
  ColorScheme get colors => Theme.of(context).colorScheme;
  TextStyle text(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    double height = 1.35,
  }) => TextStyle(
    fontSize: size,
    height: height,
    letterSpacing: 0,
    color: color ?? colors.onSurface,
    fontWeight: weight,
  );

  @override
  void initState() {
    super.initState();
    panel = widget.initialPanel;
    model.addListener(changed);
    model.initialize();
  }

  void changed() {
    if (!mounted) return;
    if (!model.loading && model.loadError == null && !loaded) {
      title.text = model.title;
      note.text = model.note;
      reason.text = model.stuckReasonText;
      hint.text = model.continuationHint;
      loaded = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(changed);
    for (final c in [title, note, reason, hint]) {
      c.dispose();
    }
    for (final f in [titleFocus, reasonFocus, hintFocus]) {
      f.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  Future<void> reveal(GlobalKey key, {FocusNode? focus}) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || key.currentContext == null) return;
    await Scrollable.ensureVisible(key.currentContext!, alignment: .2);
    if (mounted) focus?.requestFocus();
  }

  Future<void> editTime() async {
    FocusScope.of(context).unfocus();
    final value = await showActivityTimeSheet(context, model.time);
    if (!mounted || value == null) return;
    model.setTime(start: value.startedAt, end: value.endedAt);
    model.setPrecision(start: value.startPrecision, end: value.endPrecision);
  }

  Future<void> save() async {
    if (!model.editable) return;
    setState(() => errors = true);
    if (model.titleError != null) {
      await reveal(titleKey, focus: titleFocus);
      return;
    }
    if (model.timeError != null) {
      await editTime();
      return;
    }
    if (model.reasonError != null || model.hintError != null) {
      setState(() => panel = ActivityPanel.rhythm);
      if (model.reasonError != null) {
        model.setRhythmState(RhythmState.stuck);
        await reveal(reasonKey, focus: reasonFocus);
      } else {
        await reveal(hintKey, focus: hintFocus);
      }
      return;
    }
    if (model.noteError != null) {
      await reveal(noteKey);
      return;
    }
    FocusScope.of(context).unfocus();
    await model.submit();
    if (!mounted) return;
    if (model.committed?.complete == true) {
      widget.onSaved();
      return;
    }
    if (model.submitError != null && scroll.hasClients) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> leave() async {
    if (leaving || model.submitting || model.discarding) return;
    leaving = true;
    FocusScope.of(context).unfocus();
    final okay = await model.flush();
    leaving = false;
    if (mounted && okay) widget.onExit();
  }

  Future<void> discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这份草稿？'),
        content: const Text('未保存的修改将被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃草稿'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (await model.discard() && mounted) widget.onExit();
  }

  Future<void> createGoal() async {
    final goal = await showGoalCreateSheet(context, widget.createGoal);
    if (!mounted || goal == null) return;
    await model.associateCreatedGoal(goal.id);
  }

  Widget message(String value, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(value, style: text(14, color: colors.error)),
        ?action,
      ],
    ),
  );
  Widget line() =>
      Divider(height: 1, thickness: 1, color: colors.outlineVariant);
  Widget icon(String name, {double size = 22, Color? color}) => Image.asset(
    'assets/activity_editor/$name.png',
    width: size,
    height: size,
    color: color ?? colors.primary,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );

  Widget memory() => Container(
    decoration: BoxDecoration(
      border: Border.all(color: colors.outlineVariant),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        for (final state in BlockKnowledgeState.values)
          Expanded(
            child: Semantics(
              selected: model.knowledgeState == state,
              button: true,
              child: Material(
                color: model.knowledgeState == state
                    ? colors.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: model.editable
                      ? () {
                          titleFocus.unfocus();
                          model.setKnowledge(state);
                        }
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 38),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (model.knowledgeState == state) ...[
                            icon('check', size: 18, color: colors.onPrimary),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              state == BlockKnowledgeState.known
                                  ? '记得'
                                  : '想不起来',
                              style: text(
                                16,
                                color: model.knowledgeState == state
                                    ? colors.onPrimary
                                    : colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget activity() {
    final unknown =
        model.knowledgeState == BlockKnowledgeState.unknown &&
        model.titleError == null;
    final input = TextField(
      key: const ValueKey('activity-title'),
      controller: title,
      focusNode: titleFocus,
      readOnly: !model.editable || unknown,
      minLines: 1,
      maxLines: 4,
      style: text(27, weight: FontWeight.w500, height: 1.35),
      cursorWidth: 1.5,
      onChanged: model.setTitle,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        hintText: '刚才这段时间在做什么？',
        hintStyle: text(23, color: colors.onSurfaceVariant),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorText: errors ? model.titleError : null,
      ),
    );
    return Container(
      key: titleKey,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.only(top: 19, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('我做了什么', style: text(15, color: colors.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (unknown)
            ExcludeSemantics(
              child: IgnorePointer(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                    child: input,
                  ),
                ),
              ),
            )
          else
            input,
        ],
      ),
    );
  }

  Widget timeSummary() {
    final value = model.time;
    final start = value.startedAt;
    final end = value.endedAt;
    final d = start == null ? null : DateTime.fromMillisecondsSinceEpoch(start);
    final date = d == null
        ? '${model.context.date.month}月${model.context.date.day}日'
        : '${d.month}月${d.day}日';
    final duration = start != null && end != null && end > start
        ? formatDerivedDuration(
            DerivedDuration(
              milliseconds: end - start,
              hasApproximation:
                  value.startPrecision == TimePrecision.approximate ||
                  value.endPrecision == TimePrecision.approximate,
            ),
          ).replaceAll(' ', '')
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(),
        InkWell(
          key: const ValueKey('activity-time-summary'),
          onTap: model.editable ? editTime : null,
          child: Padding(
            padding: EdgeInsets.only(
              top: 17,
              bottom: model.rhythmState == null ? 17 : 9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: text(15, color: colors.onSurfaceVariant)),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final label = activityInterval(value);
                    final interval = Text(
                      label,
                      style: text(26, weight: FontWeight.w500),
                    );
                    if (constraints.maxWidth < 310 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
                        label.length > 19) {
                      return Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          interval,
                          Text(duration, style: text(18)),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(child: interval),
                        Text(duration, style: text(18)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        line(),
        if (model.candidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('选择要补记的时间', style: text(14)),
          for (final candidate in model.candidates)
            OutlinedButton(
              onPressed: model.editable
                  ? () => model.chooseCandidate(candidate)
                  : null,
              child: Text(activityInterval(candidate)),
            ),
        ],
        if (errors && model.timeError != null) message(model.timeError!),
      ],
    );
  }

  Widget section(
    ActivityPanel value,
    String label,
    String symbol, {
    String? summary,
  }) => InkWell(
    key: ValueKey('activity-${value.name}-toggle'),
    onTap: model.editable
        ? () => setState(() => panel = panel == value ? null : value)
        : null,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 47),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            icon(symbol, size: 23),
            const SizedBox(width: 20),
            Text(label, style: text(16)),
            Text(' · 选填', style: text(12, color: colors.onSurfaceVariant)),
            const SizedBox(width: 8),
            Expanded(
              child: summary == null
                  ? const SizedBox()
                  : Text(summary, textAlign: TextAlign.right, style: text(14)),
            ),
            const SizedBox(width: 10),
            icon(
              panel == value ? 'chevron-up' : 'chevron-right',
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );

  Widget goals() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.goalsLoading) const LinearProgressIndicator(),
      if (model.goalsError != null)
        message(
          model.goalsError!,
          action: TextButton(
            onPressed: model.loadGoals,
            child: const Text('重试读取目标'),
          ),
        ),
      if (!model.goalsLoading &&
          model.goalsError == null &&
          model.activeGoals.isEmpty)
        const Text('还没有目标'),
      if (model.selectedGoal?.status == GoalStatus.archived)
        Text('${model.selectedGoal!.name} · 已归档'),
      if (model.goalId != null && model.selectedGoal == null)
        const Text('已保留目标关联，等待读取名称'),
      if (!model.goalsLoading && model.goalsError == null)
        for (final goal in model.activeGoals)
          ListTile(
            key: ValueKey('select-${goal.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(goal.name),
            subtitle:
                model.activeGoals.where((g) => g.name == goal.name).length > 1
                ? Text('编号 ${goal.id.substring(goal.id.length - 4)}')
                : null,
            trailing: Icon(
              model.goalId == goal.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onTap: model.editable ? () => model.selectGoal(goal.id) : null,
          ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: model.editable ? createGoal : null,
            icon: const Icon(Icons.add),
            label: const Text('创建目标'),
          ),
          if (model.goalId != null)
            TextButton(
              onPressed: model.editable ? model.clearGoal : null,
              child: const Text('取消关联'),
            ),
        ],
      ),
    ],
  );

  Widget choice(
    String key,
    String label,
    bool selected,
    VoidCallback change, {
    double fontSize = 14,
    double height = 37,
  }) => Semantics(
    selected: selected,
    button: true,
    child: OutlinedButton(
      key: ValueKey(key),
      onPressed: model.editable ? change : null,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        foregroundColor: selected ? colors.primary : colors.onSurface,
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected) ...[icon('check', size: 16), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              style: text(
                fontSize,
                color: selected ? colors.primary : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget field(
    String label,
    TextEditingController controller,
    ValueChanged<String> change, {
    Key? key,
    FocusNode? focus,
    String? error,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: text(14, color: colors.onSurfaceVariant)),
      const SizedBox(height: 5),
      TextField(
        key: key,
        controller: controller,
        focusNode: focus,
        readOnly: !model.editable,
        minLines: 1,
        maxLines: 4,
        onChanged: change,
        style: text(15, height: 1.5),
        decoration: fieldDecoration(error: error),
      ),
    ],
  );
  InputDecoration fieldDecoration({String? hint, String? error}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      isDense: true,
      filled: false,
      hintText: hint,
      hintStyle: text(16, color: colors.onSurfaceVariant),
      errorText: error,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: border(colors.outlineVariant),
      enabledBorder: border(colors.outlineVariant),
      focusedBorder: border(colors.primary, 1.5),
    );
  }

  Widget rhythm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final state in RhythmState.values) ...[
            if (state != RhythmState.progress) const SizedBox(width: 8),
            Expanded(
              child: choice(
                'rhythm-${state.name}',
                switch (state) {
                  RhythmState.progress => '推进',
                  RhythmState.stuck => '卡住',
                  RhythmState.recovery => '恢复',
                },
                model.rhythmState == state,
                () => model.setRhythmState(
                  model.rhythmState == state ? null : state,
                ),
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
      if (model.rhythmState == RhythmState.stuck) ...[
        const SizedBox(height: 12),
        Text('当时的节奏是', style: text(14, color: colors.onSurfaceVariant)),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, constraints) {
            final labels = [
              '任务太大',
              '不知道下一步',
              '困',
              '脑雾',
              '焦虑',
              '被打断',
              '说不清',
              '其他',
            ];
            Widget item(int i) => choice(
              'stuck-reason-${StuckReasonCode.values[i].name}',
              labels[i],
              model.stuckReasonCode == StuckReasonCode.values[i],
              () => model.setStuckReasonCode(
                model.stuckReasonCode == StuckReasonCode.values[i]
                    ? null
                    : StuckReasonCode.values[i],
              ),
              fontSize: 12,
              height: 33,
            );
            if (constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.15) {
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (var i = 0; i < labels.length; i++) item(i)],
              );
            }
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 24, child: item(0)),
                    const SizedBox(width: 6),
                    Expanded(flex: 35, child: item(1)),
                    const SizedBox(width: 6),
                    Expanded(flex: 17, child: item(2)),
                    const SizedBox(width: 6),
                    Expanded(flex: 19, child: item(3)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 4; i < 8; i++) ...[
                      if (i > 4) const SizedBox(width: 6),
                      Expanded(child: item(i)),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 13),
        field(
          '具体发生了什么 · 选填',
          reason,
          model.setStuckReasonText,
          key: reasonKey,
          focus: reasonFocus,
          error: errors ? model.reasonError : null,
        ),
      ],
      if (model.rhythmState == RhythmState.recovery) ...[
        const SizedBox(height: 12),
        Text('恢复方式 · 选填', style: text(14, color: colors.onSurfaceVariant)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final method in RecoveryMethod.values)
              choice(
                'recovery-${method.name}',
                switch (method) {
                  RecoveryMethod.walk => '散步',
                  RecoveryMethod.meal => '吃饭',
                  RecoveryMethod.shower => '洗澡',
                  RecoveryMethod.empty => '放空',
                  RecoveryMethod.entertainment => '娱乐',
                  RecoveryMethod.switchTask => '切换任务',
                  RecoveryMethod.breakDownTask => '拆小任务',
                  RecoveryMethod.askForHelp => '寻求帮助',
                  RecoveryMethod.other => '其他',
                },
                model.recoveryMethod == method,
                () => model.setRecoveryMethod(
                  model.recoveryMethod == method ? null : method,
                ),
                fontSize: 12,
                height: 33,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('恢复感受 · 选填', style: text(14, color: colors.onSurfaceVariant)),
        const SizedBox(height: 5),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final quality in RecoveryQuality.values)
              choice(
                'quality-${quality.name}',
                switch (quality) {
                  RecoveryQuality.notRecovered => '没缓过来',
                  RecoveryQuality.partlyRecovered => '缓过来一些',
                  RecoveryQuality.readyToContinue => '可以继续了',
                },
                model.recoveryQuality == quality,
                () => model.setRecoveryQuality(
                  model.recoveryQuality == quality ? null : quality,
                ),
                fontSize: 12,
                height: 33,
              ),
          ],
        ),
      ],
      if (model.rhythmState != null) ...[
        const SizedBox(height: 13),
        field(
          '接续点 · 选填',
          hint,
          model.setContinuationHint,
          key: hintKey,
          focus: hintFocus,
          error: errors ? model.hintError : null,
        ),
      ],
    ],
  );

  List<Widget> body() => [
    if (model.submitError != null) message(model.submitError!),
    for (final conflict in model.conflicts)
      Text(
        '${widget.conflictName?.call(conflict) ?? '已有记录'} · ${formatSleepTime(conflict.startedAt)} → ${formatSleepTime(conflict.endedAt)}',
      ),
    memory(),
    activity(),
    timeSummary(),
    section(
      ActivityPanel.goal,
      '目标',
      'target',
      summary: model.selectedGoal?.name,
    ),
    if (panel == ActivityPanel.goal) goals(),
    line(),
    section(ActivityPanel.rhythm, '节奏', 'activity'),
    if (panel == ActivityPanel.rhythm) rhythm(),
    if (model.rhythmState == null ||
        panel != ActivityPanel.rhythm ||
        model.noteError != null) ...[
      const SizedBox(height: 16),
      line(),
      const SizedBox(height: 10),
      Text('补充内容 · 选填', style: text(14, color: colors.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(
        key: noteKey,
        controller: note,
        readOnly: !model.editable,
        minLines: 7,
        maxLines: 12,
        style: text(16, height: 1.3),
        onChanged: model.setNote,
        decoration: fieldDecoration(
          hint: '还有想记下的事',
          error: errors ? model.noteError : null,
        ),
      ),
    ],
  ];

  Widget footer() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.storageError != null)
          message(
            model.storageError!,
            action: TextButton(
              onPressed: model.retrySave,
              child: const Text('重试保留草稿'),
            ),
          ),
        FilledButton(
          key: const ValueKey('activity-save'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
            textStyle: text(18, weight: FontWeight.w500),
          ),
          onPressed: model.editable
              ? (model.conflicts.isNotEmpty ? editTime : save)
              : null,
          child: Text(
            model.submitting
                ? '保存中'
                : model.conflicts.isNotEmpty
                ? '调整当前记录时间'
                : model.context.entry == RecordingDraftEntry.edit
                ? '保存更正'
                : '保存活动',
          ),
        ),
        const SizedBox(height: 17),
        Text(
          model.saving
              ? '正在保留草稿'
              : model.storageError != null
              ? '草稿尚未保留成功'
              : '草稿已保留',
          textAlign: TextAlign.center,
          style: text(13, color: colors.onSurfaceVariant),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      model.context.entry == RecordingDraftEntry.edit
                          ? '更正记录'
                          : model.context.entry == RecordingDraftEntry.gap
                          ? '补记活动'
                          : '记录活动',
                      style: text(20, weight: FontWeight.w500),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 40),
                          alignment: Alignment.centerLeft,
                          foregroundColor: colors.onSurface,
                        ),
                        onPressed: model.submitting ? null : leave,
                        child: Text('取消', style: text(16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (model.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (model.loadError != null) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(model.loadError!),
                        if (model.missingOriginal)
                          TextButton(
                            onPressed: discard,
                            child: const Text('清理更正草稿'),
                          )
                        else
                          TextButton(
                            onPressed: model.initialize,
                            child: const Text('重试读取'),
                          ),
                        if (model.storageError != null)
                          message(model.storageError!),
                        TextButton(onPressed: leave, child: const Text('返回')),
                      ],
                    );
                  }
                  if (model.committed != null) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('记录已保存，仍需完成草稿清理或页面刷新。'),
                        FilledButton(
                          onPressed: model.submitting
                              ? null
                              : () async {
                                  await model.retryFinish();
                                  if (mounted &&
                                      model.committed?.complete == true) {
                                    widget.onSaved();
                                  }
                                },
                          child: Text(model.submitting ? '正在收尾' : '重试收尾'),
                        ),
                      ],
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final inlineFooter =
                          constraints.maxHeight < 400 ||
                          model.storageError != null;
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scroll,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...body(),
                                  if (inlineFooter) footer(),
                                ],
                              ),
                            ),
                          ),
                          if (!inlineFooter) footer(),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String activityInterval(RecordingTimeInput input) {
  if (input.startedAt == null || input.endedAt == null) return '填写开始与结束时间';
  final a = formatSleepTime(input.startedAt);
  final b = formatSleepTime(input.endedAt);
  return a.split(' ').first == b.split(' ').first
      ? '${a.split(' ').last}  →  ${b.split(' ').last}'
      : '$a → $b';
}
