import 'package:flutter/material.dart';

import '../app/theme/time_ledger_theme.dart';
import '../app/time/device_recording_date.dart';
import '../core/time/civil_date.dart';
import '../features/goals/domain/goal.dart';
import '../features/goals/domain/goal_repository.dart';
import '../features/goals/domain/goal_status.dart';
import '../features/ledger/application/recording_entry_editor.dart';
import '../features/ledger/application/recording_entry_saver.dart';
import '../features/ledger/application/recording_ledger_loader.dart';
import '../features/ledger/application/recording_time_suggestion.dart';
import '../features/ledger/domain/annotation_change.dart';
import '../features/ledger/domain/block_knowledge_state.dart';
import '../features/ledger/domain/ledger_conflicts.dart';
import '../features/ledger/domain/ledger_repository.dart';
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/rhythm_annotation.dart';
import '../features/ledger/domain/rhythm_state.dart';
import '../features/ledger/domain/time_block.dart';
import '../features/ledger/domain/time_precision.dart';
import '../features/ledger/presentation/guided_recording_page.dart';
import '../features/ledger/presentation/recording_form_controller.dart';
import '../features/ledger/presentation/sleep_time_input.dart';

String guidedSampleId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int guidedSampleTime(int hour, [int minute = 0, int day = 5]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final guidedSampleDate = CivilDate(year: 2026, month: 10, day: 5);

enum GuidedSampleScenario {
  basic('新建 · 常用目标'),
  noGoal('普通生活 · 无目标'),
  stuck('卡住 · 补充已填'),
  unknown('想不起来'),
  manual('无时间建议'),
  gap('Gap补记'),
  oneCandidate('单个候选'),
  candidates('多个候选'),
  crossDay('跨日更正'),
  restored('恢复未完成输入'),
  archived('归档目标引用'),
  emptyGoals('空目标列表'),
  goalReadFailure('目标读取失败'),
  goalWriteFailure('目标创建失败'),
  goalRefreshFailure('创建后读取失败'),
  conflict('时间冲突'),
  saveFailure('正式保存失败'),
  draftFailure('本次填写保留失败'),
  cleanupFailure('提交后清理失败'),
  refreshFailure('提交后刷新失败'),
  readFailure('未完成输入读取失败'),
  missing('更正源已不存在'),
  discardFailure('失效输入清理失败');

  const GuidedSampleScenario(this.label);
  final String label;
}

/// All sample storage is volatile. Real controller/saver/editor run unchanged.
class GuidedSampleDrafts implements RecordingDraftStore {
  RecordingDraft? value;
  int failedReads = 0, failedWrites = 0, failedClears = 0;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) async {
    if (failedReads-- > 0) throw StateError('fixture read');
    return value;
  }

  @override
  Future<void> save(RecordingDraft draft) async {
    if (failedWrites-- > 0) throw StateError('fixture draft write');
    value = draft;
  }

  @override
  Future<void> clear(RecordingDraftContext context) async {
    if (failedClears-- > 0) throw StateError('fixture clear');
    value = null;
  }
}

class GuidedSampleGoals implements GoalRepository {
  final values = <Goal>[];
  int failedReads = 0, failedWrites = 0;
  bool failAfterCreate = false;
  @override
  Future<List<Goal>> listActive() async {
    if (failedReads-- > 0) throw StateError('fixture goal read');
    return values.where((g) => g.status == GoalStatus.active).toList();
  }

  @override
  Future<List<Goal>> listArchived() async =>
      values.where((g) => g.status == GoalStatus.archived).toList();
  @override
  Future<Goal?> findById(String id) async =>
      values.where((g) => g.id == id).firstOrNull;
  @override
  Future<Goal> create({
    required String id,
    required String name,
    required int now,
  }) async {
    if (failedWrites-- > 0) throw StateError('fixture goal write');
    final goal = Goal.create(id: id, name: name, now: now);
    values.add(goal);
    if (failAfterCreate) {
      failedReads = 1;
      failAfterCreate = false;
    }
    return goal;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Outside recording sample');
}

class GuidedSampleLedger implements LedgerRepository {
  final values = <TimeBlock>[];
  final annotations = <RhythmAnnotation>[];
  int failedWrites = 0, failedReads = 0, writes = 0;
  @override
  Future<LedgerSnapshot> readWindow({
    required int startedAt,
    required int endedAt,
  }) async {
    if (failedReads-- > 0) throw StateError('fixture ledger read');
    return LedgerSnapshot(
      timeBlocks: values.where(
        (b) => b.startedAt < endedAt && b.endedAt > startedAt,
      ),
      sleepSessions: const [],
      annotations: annotations,
    );
  }

  @override
  Future<TimeBlockWriteResult?> readTimeBlock(String id) async {
    final block = values.where((b) => b.id == id).firstOrNull;
    return block == null
        ? null
        : (
            timeBlock: block,
            annotation: annotations
                .where((a) => a.timeBlockId == id)
                .firstOrNull,
          );
  }

  void write(
    TimeBlock block,
    RhythmAnnotation? annotation, {
    bool replacing = false,
  }) {
    if (failedWrites-- > 0) throw StateError('fixture formal write');
    final conflicts = findLedgerConflicts(
      candidate: LedgerFactInterval.fromTimeBlock(block),
      existing: values.map(LedgerFactInterval.fromTimeBlock),
      replacing: replacing
          ? LedgerFactInterval.fromTimeBlock(block).reference
          : null,
    );
    if (conflicts.isNotEmpty) throw LedgerConflictException(conflicts);
    values.removeWhere((b) => b.id == block.id);
    annotations.removeWhere((a) => a.timeBlockId == block.id);
    values.add(block);
    if (annotation != null) {
      annotations.add(annotation);
    }
    writes++;
  }

  RhythmAnnotation fromAdd(AddAnnotation input, TimeBlock block, int now) =>
      RhythmAnnotation(
        id: input.id,
        timeBlockId: block.id,
        state: input.state,
        stuckReasonCode: input.stuckReasonCode,
        stuckReasonText: input.stuckReasonText,
        recoveryMethod: input.recoveryMethod,
        recoveryQuality: input.recoveryQuality,
        continuationHint: input.continuationHint,
        createdAt: now,
        updatedAt: now,
      );
  @override
  Future<TimeBlockWriteResult> createTimeBlock({
    required String id,
    required int startedAt,
    required int endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required BlockKnowledgeState knowledgeState,
    required int now,
    String? title,
    String? goalId,
    String? categoryId,
    String? note,
    AddAnnotation? annotation,
  }) async {
    final block = TimeBlock(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      knowledgeState: knowledgeState,
      title: title,
      goalId: goalId,
      categoryId: categoryId,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    final explanation = annotation == null
        ? null
        : fromAdd(annotation, block, now);
    write(block, explanation);
    return (timeBlock: block, annotation: explanation);
  }

  @override
  Future<TimeBlockWriteResult> updateTimeBlock({
    required String id,
    required int now,
    int? startedAt,
    int? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    BlockKnowledgeState? knowledgeState,
    ({String? value})? title,
    ({String? value})? goalId,
    ({String? value})? categoryId,
    ({String? value})? note,
    AnnotationChange annotation = const KeepAnnotation(),
  }) async {
    final original = await readTimeBlock(id);
    if (original == null) {
      throw LedgerFactNotFoundException((
        type: LedgerFactType.timeBlock,
        id: id,
      ));
    }
    final b = original.timeBlock;
    final block = TimeBlock(
      id: id,
      startedAt: startedAt ?? b.startedAt,
      endedAt: endedAt ?? b.endedAt,
      startPrecision: startPrecision ?? b.startPrecision,
      endPrecision: endPrecision ?? b.endPrecision,
      knowledgeState: knowledgeState ?? b.knowledgeState,
      title: title == null ? b.title : title.value,
      goalId: goalId == null ? b.goalId : goalId.value,
      categoryId: categoryId == null ? b.categoryId : categoryId.value,
      note: note == null ? b.note : note.value,
      createdAt: b.createdAt,
      updatedAt: now,
    );
    var a = original.annotation;
    switch (annotation) {
      case AddAnnotation():
        a = fromAdd(annotation, block, now);
      case RemoveAnnotation():
        a = null;
      case EditAnnotation():
        if (a == null) {
          throw const LedgerAnnotationOperationException(
            AnnotationOperationFailure.notFound,
          );
        }
        a = RhythmAnnotation(
          id: a.id,
          timeBlockId: id,
          state: annotation.state ?? a.state,
          stuckReasonCode: annotation.stuckReasonCode == null
              ? a.stuckReasonCode
              : annotation.stuckReasonCode!.value,
          stuckReasonText: annotation.stuckReasonText == null
              ? a.stuckReasonText
              : annotation.stuckReasonText!.value,
          recoveryMethod: annotation.recoveryMethod == null
              ? a.recoveryMethod
              : annotation.recoveryMethod!.value,
          recoveryQuality: annotation.recoveryQuality == null
              ? a.recoveryQuality
              : annotation.recoveryQuality!.value,
          continuationHint: annotation.continuationHint == null
              ? a.continuationHint
              : annotation.continuationHint!.value,
          createdAt: a.createdAt,
          updatedAt: now,
        );
      case KeepAnnotation():
        break;
    }
    write(block, a, replacing: true);
    return (timeBlock: block, annotation: a);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Outside recording sample');
}

class GuidedSampleSession {
  GuidedSampleSession(this.scenario) {
    if (scenario != GuidedSampleScenario.emptyGoals) {
      goals.values.addAll([
        Goal.create(
          id: guidedSampleId(10),
          name: '备考',
          now: guidedSampleTime(8),
        ),
        Goal.create(
          id: guidedSampleId(11),
          name: '阅读与写作',
          now: guidedSampleTime(8),
        ),
        Goal.create(
          id: guidedSampleId(12),
          name: '阅读与写作',
          now: guidedSampleTime(9),
        ),
        Goal.create(
          id: guidedSampleId(13),
          name: '整理跨学科研究资料并完成一份可以继续写作的阅读笔记',
          now: guidedSampleTime(9),
        ),
      ]);
    }
    final editing = [
      GuidedSampleScenario.crossDay,
      GuidedSampleScenario.archived,
      GuidedSampleScenario.missing,
      GuidedSampleScenario.discardFailure,
    ].contains(scenario);
    context = editing
        ? RecordingDraftContext.edit(
            date: guidedSampleDate,
            timeBlockId: guidedSampleId(1),
          )
        : scenario == GuidedSampleScenario.gap
        ? RecordingDraftContext.gap(
            date: guidedSampleDate,
            startedAt: guidedSampleTime(10, 30),
            endedAt: guidedSampleTime(11, 15),
          )
        : RecordingDraftContext.newEntry(date: guidedSampleDate);
    if (scenario == GuidedSampleScenario.archived) {
      goals.values.add(
        Goal.create(
          id: guidedSampleId(14),
          name: '旧备考目标',
          now: guidedSampleTime(8),
        ).archive(now: guidedSampleTime(9)),
      );
    }
    if (editing &&
        ![
          GuidedSampleScenario.missing,
          GuidedSampleScenario.discardFailure,
        ].contains(scenario)) {
      ledger.values.add(
        TimeBlock(
          id: guidedSampleId(1),
          title: '整理阅读笔记',
          startedAt: guidedSampleTime(23, 40, 4),
          endedAt: guidedSampleTime(0, 25),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          goalId: scenario == GuidedSampleScenario.archived
              ? guidedSampleId(14)
              : null,
          createdAt: guidedSampleTime(8, 0, 4),
          updatedAt: guidedSampleTime(8, 0, 4),
        ),
      );
    }
    if ([
      GuidedSampleScenario.stuck,
      GuidedSampleScenario.unknown,
      GuidedSampleScenario.restored,
      GuidedSampleScenario.missing,
      GuidedSampleScenario.discardFailure,
    ].contains(scenario)) {
      drafts.value = RecordingDraft(
        context: context,
        title: scenario == GuidedSampleScenario.unknown
            ? '保留的事项原文'
            : '理数据库的表关系',
        startedAt: guidedSampleTime(10, 30),
        endedAt: guidedSampleTime(11, 15),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: scenario == GuidedSampleScenario.unknown
            ? BlockKnowledgeState.unknown
            : BlockKnowledgeState.known,
        goalId: scenario == GuidedSampleScenario.restored
            ? guidedSampleId(11)
            : guidedSampleId(10),
        goalProvided: true,
        annotationIntent: RecordingAnnotationIntent.add,
        annotationId: guidedSampleId(30),
        rhythmState: RhythmState.stuck,
        continuationHint: '下次先列出三个小标题。',
        hintProvided: true,
      );
    }
    if (scenario == GuidedSampleScenario.conflict) {
      ledger.values.add(
        TimeBlock(
          id: guidedSampleId(2),
          title: '散步',
          startedAt: guidedSampleTime(11),
          endedAt: guidedSampleTime(11, 30),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          createdAt: guidedSampleTime(12),
          updatedAt: guidedSampleTime(12),
        ),
      );
    }
    if (scenario == GuidedSampleScenario.goalReadFailure) goals.failedReads = 1;
    if (scenario == GuidedSampleScenario.goalWriteFailure) {
      goals.failedWrites = 1;
    }
    if (scenario == GuidedSampleScenario.goalRefreshFailure) {
      goals.failAfterCreate = true;
    }
    if (scenario == GuidedSampleScenario.readFailure) drafts.failedReads = 1;
    if (scenario == GuidedSampleScenario.saveFailure) ledger.failedWrites = 1;
    if ([
      GuidedSampleScenario.cleanupFailure,
      GuidedSampleScenario.discardFailure,
    ].contains(scenario)) {
      drafts.failedClears = 1;
    }
  }
  final GuidedSampleScenario scenario;
  final drafts = GuidedSampleDrafts();
  final goals = GuidedSampleGoals();
  final ledger = GuidedSampleLedger();
  final navigation = GuidedRecordingNavigation();
  late final RecordingDraftContext context;
  String? commonGoalId;
  RecordingInputMode mode = RecordingInputMode.guided;
  int nextId = 100;
  int failedRefreshes = 0;
  RecordingFormController? model;
  late final loader = RecordingLedgerLoader(
    repository: ledger,
    resolveDate: resolveDeviceRecordingDate,
  );
  late final saver = RecordingEntrySaver(
    repository: ledger,
    drafts: drafts,
    refresh: ({required date, required now}) async {
      if (failedRefreshes-- > 0) throw StateError('fixture refresh');
      return loader.load(date: date, now: now);
    },
    newId: () => guidedSampleId(nextId++),
    now: () => guidedSampleTime(12),
  );
  Future<Goal> createGoal(String name) => goals.create(
    id: guidedSampleId(nextId++),
    name: name,
    now: guidedSampleTime(12),
  );

  Future<RecordingFormController> open() async {
    model?.dispose();
    final controller = RecordingFormController(
      context: context,
      store: drafts,
      entrySaver: saver,
      entryEditor: RecordingEntryEditor(
        repository: ledger,
        drafts: drafts,
        saver: saver,
      ),
      goals: goals,
      loadSuggestion: () async {
        if (scenario == GuidedSampleScenario.manual) {
          return const ManualTimeEntry();
        }
        if ([
          GuidedSampleScenario.oneCandidate,
          GuidedSampleScenario.candidates,
        ].contains(scenario)) {
          return TimeCandidates([
            RecordingTimeInput(
              startedAt: guidedSampleTime(8),
              endedAt: guidedSampleTime(9),
            ),
            if (scenario == GuidedSampleScenario.candidates)
              RecordingTimeInput(
                startedAt: guidedSampleTime(10),
                endedAt: guidedSampleTime(11),
              ),
          ]);
        }
        return DirectTimeSuggestion(
          RecordingTimeInput(
            startedAt: guidedSampleTime(10, 30),
            endedAt: guidedSampleTime(11, 15),
          ),
        );
      },
    );
    model = controller;
    await controller.initialize();
    if (controller.editable &&
        !controller.restored &&
        context.entry != RecordingDraftEntry.edit &&
        !controller.goalProvided &&
        commonGoalId != null) {
      controller.selectGoal(commonGoalId!);
    }
    await controller.flush();
    if (scenario == GuidedSampleScenario.draftFailure) drafts.failedWrites = 1;
    if (scenario == GuidedSampleScenario.refreshFailure) failedRefreshes = 1;
    return controller;
  }

  void dispose() {
    model?.dispose();
    navigation.dispose();
  }
}

class GuidedRecordingSample extends StatefulWidget {
  const GuidedRecordingSample({super.key});
  @override
  State<GuidedRecordingSample> createState() => _SampleState();
}

class _SampleState extends State<GuidedRecordingSample> {
  GuidedSampleScenario scenario = GuidedSampleScenario.basic;
  late GuidedSampleSession session = newSession();
  bool editing = false, opening = false;
  String? result;
  GuidedSampleSession newSession() {
    final value = GuidedSampleSession(scenario);
    if (scenario != GuidedSampleScenario.noGoal &&
        scenario != GuidedSampleScenario.emptyGoals) {
      value.commonGoalId = guidedSampleId(10);
    }
    return value;
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  Future<void> open() async {
    setState(() => opening = true);
    await session.open();
    if (mounted) {
      setState(() {
        editing = true;
        opening = false;
        result = null;
      });
    }
  }

  void saved() => setState(() {
    final block = session.model!.committed!.timeBlock;
    result =
        '已写入样板内存：${block.knowledgeState == BlockKnowledgeState.unknown ? '想不起来' : block.title}\n'
        '${formatSleepTime(block.startedAt)} — ${formatSleepTime(block.endedAt)}\n本次写入次数：${session.ledger.writes}';
    editing = false;
  });
  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('样板设置', style: Theme.of(context).textTheme.titleLarge),
              const Text('偏好只保留在当前开发会话。下一次进入生效，未完成输入的原关联优先。'),
              const SizedBox(height: 16),
              const Text('记录方式'),
              for (final mode in RecordingInputMode.values)
                ListTile(
                  title: Text(
                    mode == RecordingInputMode.guided ? '问答引导' : '表单填写',
                  ),
                  leading: Icon(
                    session.mode == mode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => update(() => session.mode = mode),
                ),
              const SizedBox(height: 16),
              const Text('常用目标'),
              ListTile(
                title: const Text('不预选目标'),
                leading: Icon(
                  session.commonGoalId == null ? Icons.check : Icons.remove,
                ),
                onTap: () => update(() => session.commonGoalId = null),
              ),
              for (final goal in session.goals.values.where(
                (g) => g.status == GoalStatus.active,
              ))
                ListTile(
                  title: Text(goal.name),
                  trailing: session.commonGoalId == goal.id
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => update(() => session.commonGoalId = goal.id),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('完成设置'),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => editing
      ? GuidedRecordingPage(
          key: ObjectKey(session.model),
          model: session.model!,
          navigation: session.navigation,
          mode: session.mode,
          createGoal: session.createGoal,
          onSaved: saved,
          onExit: () => setState(() => editing = false),
        )
      : Scaffold(
          appBar: AppBar(
            title: const Text('问答记录样板'),
            actions: [
              IconButton(
                onPressed: settings,
                tooltip: '样板设置',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '节奏 → 事项 → 时间',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text('独立开发入口 · 使用内存数据，刷新后重置。不会写入正式账本。'),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<GuidedSampleScenario>(
                    initialValue: scenario,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '体验场景'),
                    items: [
                      for (final value in GuidedSampleScenario.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                    ],
                    onChanged: opening
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              session.dispose();
                              scenario = value;
                              session = newSession();
                              result = null;
                            });
                          },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '填写方式：${session.mode == RecordingInputMode.guided ? '问答引导' : '表单填写'}',
                  ),
                  Text(
                    '常用目标：${session.goals.values.where((g) => g.id == session.commonGoalId).firstOrNull?.name ?? '未指定'}',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: opening ? null : open,
                    child: Text(
                      opening
                          ? '正在读取'
                          : session.drafts.value != null
                          ? '恢复未完成输入'
                          : '开始体验',
                    ),
                  ),
                  TextButton(
                    onPressed: settings,
                    child: const Text('设置填写方式与常用目标'),
                  ),
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(result!),
                    ),
                ],
              ),
            ),
          ),
        );
}

ThemeData get guidedSampleTheme => timeLedgerTheme;
