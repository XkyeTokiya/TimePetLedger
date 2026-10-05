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
import '../features/ledger/domain/block_knowledge_state.dart';
import '../features/ledger/domain/ledger_conflicts.dart';
import '../features/ledger/domain/ledger_repository.dart';
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/rhythm_details.dart';
import '../features/ledger/domain/rhythm_state.dart';
import '../features/ledger/domain/time_block.dart';
import '../features/ledger/domain/time_precision.dart';
import '../features/ledger/presentation/activity_editor.dart';
import '../features/ledger/presentation/recording_form_controller.dart';

enum ActivitySample {
  simple('精简态'),
  goal('目标态'),
  stuck('卡住态'),
  unknown('想不起来'),
  gap('Gap 补记'),
  edit('跨日更正'),
  manual('无建议手填'),
  oneCandidate('单个候选'),
  candidates('多个候选'),
  restored('草稿优先'),
  emptyGoals('目标为空'),
  goalReadFailure('目标读取失败'),
  goalWriteFailure('创建目标失败'),
  goalRefreshFailure('创建成功后读取失败'),
  archived('归档引用'),
  conflict('时间冲突'),
  saveFailure('保存失败'),
  draftFailure('草稿保留失败'),
  cleanupFailure('提交后清理失败'),
  refreshFailure('提交后刷新失败'),
  missing('更正源已不存在'),
  discardFailure('清理草稿失败'),
  loadFailure('读取失败');

  const ActivitySample(this.label);
  final String label;
}

String sampleId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int sampleTime(int hour, [int minute = 0, int day = 5]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final sampleDate = CivilDate(year: 2026, month: 10, day: 5);

/// Deliberately volatile. No platform database or real application bootstrap.
class SampleDraftStore implements RecordingDraftStore {
  RecordingDraft? value;
  int failedWrites = 0;
  int failedClears = 0;
  int failedReads = 0;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) async {
    if (failedReads > 0) {
      failedReads--;
      throw StateError('sample read');
    }
    return value;
  }

  @override
  Future<void> save(RecordingDraft draft) async {
    if (failedWrites > 0) {
      failedWrites--;
      throw StateError('sample write');
    }
    value = draft;
  }

  @override
  Future<void> clear(RecordingDraftContext context) async {
    if (failedClears > 0) {
      failedClears--;
      throw StateError('sample clear');
    }
    value = null;
  }
}

class SampleGoals implements GoalRepository {
  final List<Goal> values = [];
  int failedReads = 0;
  int failedWrites = 0;
  bool failAfterCreate = false;
  int nextId = 100;
  int created = 0;
  @override
  Future<List<Goal>> listActive() async {
    if (failedReads > 0) {
      failedReads--;
      throw StateError('sample goals read');
    }
    return values.where((g) => g.status == GoalStatus.active).toList();
  }

  @override
  Future<Goal?> findById(String id) async =>
      values.where((g) => g.id == id).firstOrNull;
  @override
  Future<Goal> create({
    required String id,
    required String name,
    required int now,
  }) async {
    if (failedWrites > 0) {
      failedWrites--;
      throw StateError('sample goals write');
    }
    final goal = Goal.create(id: id, name: name, now: now);
    values.add(goal);
    created++;
    if (failAfterCreate) {
      failedReads++;
      failAfterCreate = false;
    }
    return goal;
  }

  Future<Goal> createNamed(String name) =>
      create(id: sampleId(nextId++), name: name, now: sampleTime(12));
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Not part of the activity sample: ${invocation.memberName}',
  );
}

/// Read-only fixture source for existing controller initialization/projection.
class SampleSource implements LedgerRepository {
  TimeBlock? original;
  @override
  Future<TimeBlockWriteResult?> readTimeBlock(String id) async =>
      original?.id == id ? (timeBlock: original!, annotation: null) : null;
  @override
  Future<LedgerSnapshot> readWindow({
    required int startedAt,
    required int endedAt,
  }) async => LedgerSnapshot(
    timeBlocks: const [],
    sleepSessions: const [],
    annotations: const [],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Sample never writes a ledger repository');
}

class ActivitySampleSession {
  ActivitySampleSession(this.sample) {
    final editing = [
      ActivitySample.edit,
      ActivitySample.archived,
      ActivitySample.missing,
      ActivitySample.discardFailure,
    ].contains(sample);
    context = editing
        ? RecordingDraftContext.edit(date: sampleDate, timeBlockId: sampleId(1))
        : sample == ActivitySample.gap
        ? RecordingDraftContext.gap(
            date: sampleDate,
            startedAt: sampleTime(10, 30),
            endedAt: sampleTime(11, 15),
          )
        : RecordingDraftContext.newEntry(date: sampleDate);
    if (sample != ActivitySample.emptyGoals) {
      goals.values.addAll([
        Goal.create(id: sampleId(10), name: '阅读与写作', now: sampleTime(8)),
        Goal.create(id: sampleId(11), name: '阅读与写作', now: sampleTime(9)),
        Goal.create(
          id: sampleId(12),
          name: '整理跨学科研究资料并完成一份可以继续写作的阅读笔记',
          now: sampleTime(9),
        ),
      ]);
    }
    if (sample == ActivitySample.archived) {
      goals.values.add(
        Goal.create(
          id: sampleId(13),
          name: '旧阅读计划',
          now: sampleTime(8),
        ).archive(now: sampleTime(9)),
      );
    }
    if (editing &&
        sample != ActivitySample.missing &&
        sample != ActivitySample.discardFailure) {
      source.original = TimeBlock(
        id: sampleId(1),
        startedAt: sampleTime(23, 40, 4),
        endedAt: sampleTime(0, 25),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '整理阅读笔记',
        goalId: sample == ActivitySample.archived ? sampleId(13) : null,
        createdAt: sampleTime(1),
        updatedAt: sampleTime(1),
      );
    }
    final blank = [
      ActivitySample.gap,
      ActivitySample.manual,
      ActivitySample.oneCandidate,
      ActivitySample.candidates,
      ActivitySample.edit,
      ActivitySample.archived,
    ].contains(sample);
    if (!blank) {
      drafts.value = RecordingDraft(
        context: context,
        title: '整理阅读笔记',
        startedAt: sampleTime(10, 30),
        endedAt: sampleTime(11, 15),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: sample == ActivitySample.unknown
            ? BlockKnowledgeState.unknown
            : BlockKnowledgeState.known,
        goalId: [ActivitySample.goal, ActivitySample.stuck].contains(sample)
            ? sampleId(10)
            : null,
        goalProvided: true,
        annotationIntent: sample == ActivitySample.stuck
            ? RecordingAnnotationIntent.add
            : RecordingAnnotationIntent.keep,
        annotationId: sample == ActivitySample.stuck ? sampleId(20) : null,
        rhythmState: sample == ActivitySample.stuck ? RhythmState.stuck : null,
        stuckReasonCode: sample == ActivitySample.stuck
            ? StuckReasonCode.unclearNextStep
            : null,
        stuckReasonText: sample == ActivitySample.stuck
            ? '资料很多，还没找到组织顺序。'
            : null,
        continuationHint: sample == ActivitySample.stuck ? '下次先列出三个小标题。' : null,
      );
    }
    if (sample == ActivitySample.goalReadFailure) goals.failedReads = 1;
    if (sample == ActivitySample.goalWriteFailure) goals.failedWrites = 1;
    if (sample == ActivitySample.goalRefreshFailure) {
      goals.failAfterCreate = true;
    }
    if (sample == ActivitySample.draftFailure) drafts.failedWrites = 1;
    if (sample == ActivitySample.discardFailure ||
        sample == ActivitySample.cleanupFailure) {
      drafts.failedClears = 1;
    }
    if (sample == ActivitySample.loadFailure) drafts.failedReads = 1;
  }
  final ActivitySample sample;
  final drafts = SampleDraftStore();
  final goals = SampleGoals();
  final source = SampleSource();
  late final RecordingDraftContext context;
  int commits = 0;
  RecordingDraft? simulatedSaved;
  RecordingSubmitCommitted? pendingCommit;
  late final loader = RecordingLedgerLoader(
    repository: source,
    resolveDate: resolveDeviceRecordingDate,
  );
  late final saver = RecordingEntrySaver(
    repository: source,
    drafts: drafts,
    refresh: loader.load,
    newId: () => sampleId(50),
    now: () => sampleTime(12),
  );
  ActivityPanel? get initialPanel =>
      sample == ActivitySample.stuck || sample == ActivitySample.unknown
      ? ActivityPanel.rhythm
      : [
          ActivitySample.goal,
          ActivitySample.emptyGoals,
          ActivitySample.goalReadFailure,
          ActivitySample.goalWriteFailure,
          ActivitySample.goalRefreshFailure,
          ActivitySample.archived,
        ].contains(sample)
      ? ActivityPanel.goal
      : ActivityPanel.rhythm;

  Future<RecordingTimeSuggestion> suggestion() async {
    if (sample == ActivitySample.manual) return const ManualTimeEntry();
    if (sample == ActivitySample.oneCandidate ||
        sample == ActivitySample.candidates) {
      return TimeCandidates([
        RecordingTimeInput(startedAt: sampleTime(8), endedAt: sampleTime(9)),
        if (sample == ActivitySample.candidates)
          RecordingTimeInput(
            startedAt: sampleTime(10),
            endedAt: sampleTime(11),
          ),
      ]);
    }
    return DirectTimeSuggestion(
      RecordingTimeInput(
        startedAt: sampleTime(10, 30),
        endedAt: sampleTime(11, 15),
      ),
    );
  }

  SampleActivityController controller() => SampleActivityController(this);
}

/// Only submission outcomes are simulated. Input, draft and association use the
/// existing controller; no production code depends on this subclass.
class SampleActivityController extends RecordingFormController {
  SampleActivityController(this.session)
    : super(
        context: session.context,
        store: session.drafts,
        loadSuggestion: session.suggestion,
        goals: session.goals,
        entryEditor: RecordingEntryEditor(
          repository: session.source,
          drafts: session.drafts,
          saver: session.saver,
        ),
      );
  final ActivitySampleSession session;
  bool alive = true;
  bool failedSave = false;
  bool failedRefresh = false;
  @override
  Future<void> initialize() async {
    await super.initialize();
    final pending = session.pendingCommit;
    if (alive && pending != null && !pending.complete) {
      committed = pending;
      // A recreated preview must only finish the already simulated submission.
      failedRefresh = true;
      emit();
    }
  }

  void emit() {
    if (alive) notifyListeners();
  }

  @override
  Future<RecordingLedger?> submit() async {
    if (!editable || !valid) return null;
    submitting = true;
    submitError = null;
    emit();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!alive || !await flush()) return null;
      if (session.sample == ActivitySample.saveFailure && !failedSave) {
        failedSave = true;
        submitError = '保存失败，输入和草稿已保留，请重试。';
        return null;
      }
      if (session.sample == ActivitySample.conflict &&
          time.startedAt! < sampleTime(11, 30) &&
          time.endedAt! > sampleTime(11)) {
        conflicts = [
          LedgerFactInterval.fromTimeBlock(
            TimeBlock(
              id: sampleId(99),
              title: '散步',
              startedAt: sampleTime(11),
              endedAt: sampleTime(11, 30),
              startPrecision: TimePrecision.exact,
              endPrecision: TimePrecision.exact,
              knowledgeState: BlockKnowledgeState.known,
              createdAt: 0,
              updatedAt: 0,
            ),
          ),
        ];
        submitError = '时间与散步记录冲突，请调整后再保存。';
        return null;
      }
      session.commits++;
      session.simulatedSaved = session.drafts.value;
      final block = TimeBlock(
        id: original?.id ?? sampleId(50),
        title: title,
        note: note,
        goalId: goalId,
        startedAt: time.startedAt!,
        endedAt: time.endedAt!,
        startPrecision: time.startPrecision,
        endPrecision: time.endPrecision,
        knowledgeState: knowledgeState!,
        createdAt: original?.createdAt ?? sampleTime(12),
        updatedAt: sampleTime(12),
      );
      return await finish(block, false);
    } finally {
      submitting = false;
      emit();
    }
  }

  Future<RecordingLedger?> finish(TimeBlock block, bool cleared) async {
    if (!cleared) {
      try {
        await session.drafts.clear(context);
        cleared = true;
      } catch (_) {
        /* Fixture cleanup failure. */
      }
    }
    RecordingLedger? refreshed;
    if (session.sample == ActivitySample.refreshFailure && !failedRefresh) {
      failedRefresh = true;
    } else {
      refreshed = await session.loader.load(
        date: sampleDate,
        now: sampleTime(12),
      );
    }
    committed = RecordingSubmitCommitted(
      timeBlock: block,
      draftCleared: cleared,
      refreshed: refreshed,
    );
    session.pendingCommit = committed;
    return committed!.complete ? refreshed : null;
  }

  @override
  Future<RecordingLedger?> retryFinish() async {
    if (submitting || committed == null || committed!.complete) return null;
    submitting = true;
    emit();
    try {
      return await finish(committed!.timeBlock, committed!.draftCleared);
    } finally {
      submitting = false;
      emit();
    }
  }

  @override
  void dispose() {
    alive = false;
    super.dispose();
  }
}

class ActivitySampleApp extends StatelessWidget {
  const ActivitySampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RB-01 活动样板',
    debugShowCheckedModeBanner: false,
    theme: timeLedgerTheme,
    home: const _SampleHost(),
  );
}

class _SampleHost extends StatefulWidget {
  const _SampleHost();
  @override
  State<_SampleHost> createState() => _SampleHostState();
}

class _SampleHostState extends State<_SampleHost> {
  late ActivitySampleSession session;
  late SampleActivityController model;
  int revision = 0;
  String? result;
  @override
  void initState() {
    super.initState();
    session = ActivitySampleSession(ActivitySample.simple);
    model = session.controller();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void open({ActivitySample? sample}) {
    model.dispose();
    if (sample != null) session = ActivitySampleSession(sample);
    setState(() {
      model = session.controller();
      revision++;
      result = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<ActivitySample>(
                    isExpanded: true,
                    value: session.sample,
                    items: [
                      for (final sample in ActivitySample.values)
                        DropdownMenuItem(
                          value: sample,
                          child: Text(sample.label),
                        ),
                    ],
                    onChanged: (sample) {
                      if (sample != null) open(sample: sample);
                    },
                  ),
                ),
                IconButton(
                  tooltip: '重开当前样板（保留已应用草稿）',
                  onPressed: () async {
                    await model.flush();
                    if (mounted) open();
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Text('RB-01 · 内存样板 · 保存为模拟结果', textAlign: TextAlign.center),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: result != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(result!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () => open(),
                              child: const Text('重开样板'),
                            ),
                          ],
                        ),
                      )
                    : ActivityEditor(
                        key: ValueKey(revision),
                        controller: model,
                        initialPanel: session.initialPanel,
                        createGoal: session.goals.createNamed,
                        conflictName: (_) => '散步',
                        onExit: () =>
                            setState(() => result = '已离开样板；已应用草稿保留在本次会话'),
                        onSaved: () => setState(
                          () =>
                              result = '模拟保存完成 · ${session.commits} 次\n未写入正式账本',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
