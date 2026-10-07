import '../support/root_navigation.dart';

import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_recording_entry.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import '../support/app_recording_navigation.dart' show tap, textTap;
import '../support/activity_recorder.dart';
import 'day_ledger_editing_flow_test.dart' show controller, ledgerView;
import 'day_ledger_resolution_flow_test.dart' show BlockReadFailure;
import 'recording_goal_flow_test.dart' show disposeApp;
import 'support/checked_sleep_opening.dart';

const hour = Duration.millisecondsPerHour;

class ClearFailure extends QueryInterceptor {
  bool fail = false;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (fail && sql.startsWith('DELETE FROM recording_drafts')) {
      throw StateError('test draft cleanup failure');
    }
    return executor.runCustom(sql, args);
  }
}

// Both stores are real SQLite files. Reopen disposes the entire bootstrap,
// including its repositories/controllers, and reconstructs them from disk.
class ClosureApp {
  ClosureApp(this.dir);
  final Directory dir;
  final reads = BlockReadFailure();
  final clear = ClearFailure();
  late AppDatabase db;
  late DriftRecordingDraftStore drafts;
  DateTime clock = DateTime(2026, 10, 2, 12);
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  DriftGoalRepository get goals => DriftGoalRepository(db);

  Future<void> connect() async {
    db = await AppDatabase.open(
      NativeDatabase(File('${dir.path}/facts.sqlite')).interceptWith(reads),
    );
    drafts = await DriftRecordingDraftStore.open(
      NativeDatabase(File('${dir.path}/drafts.sqlite')).interceptWith(clear),
    );
  }

  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
        openSleepDrafts: () =>
            DriftSleepDraftStore.open(NativeDatabase.memory()),
        openSleepOpenings: () => openCheckedSleepOpening(clock),
        openPreferences: () =>
            DriftAppPreferencesStore.open(NativeDatabase.memory()),
        now: () => clock,
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> reopen(WidgetTester t) async {
    await disposeApp(t);
    await t.runAsync(connect);
    await mount(t);
  }

  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  };

  static Future<ClosureApp> open(WidgetTester t) async {
    final app = (await t.runAsync(() async {
      final app = ClosureApp(
        await Directory.systemTemp.createTemp('goal_rhythm_closure_'),
      );
      await app.connect();
      return app;
    }))!;
    addTearDown(() async {
      await app.db.close();
      await app.drafts.close();
      await app.dir.delete(recursive: true);
    });
    await app.mount(t);
    return app;
  }
}

Future<void> back(WidgetTester t) async {
  await backFromPage(t);
  await t.pumpAndSettle();
}

Future<String> createGoal(WidgetTester t, ClosureApp app) async {
  final before = (await t.runAsync(app.goals.listActive))!;
  await tap(t, find.byKey(const ValueKey('goal-new')));
  await t.enterText(
    find.byKey(const ValueKey('goal-name-input')),
    '  同名目标 🐾  ',
  );
  await textTap(t, '保存目标');
  final after = (await t.runAsync(app.goals.listActive))!;
  // Return to the goal list so a second create starts from the same place.
  await back(t);
  return after.singleWhere((g) => !before.any((b) => b.id == g.id)).id;
}

Future<void> chooseGoal(WidgetTester t, String id) async {
  await textTap(t, '选择目标');
  await tap(t, find.byKey(ValueKey('goal-option-$id')));
}

/// Opens a goal from the list and runs a lifecycle action from its detail.
Future<void> goalAction(WidgetTester t, String id, String action) async {
  await tap(t, find.byKey(ValueKey('goal-open-$id')));
  final button = switch (action) {
    '归档目标' => const ValueKey('goal-archive'),
    '恢复目标' => const ValueKey('goal-restore'),
    _ => const ValueKey('goal-delete'),
  };
  await tap(t, find.byKey(button));
  if (action == '归档目标' || action == '删除目标') {
    await textTap(t, '确认归档');
  } else {
    await t.pumpAndSettle();
  }
}

Future<void> fill(WidgetTester t, {String? goal}) async {
  // Selecting a rhythm advances automatically; then title, then time.
  await recorderRhythm(t, RhythmState.progress);
  await recorderTitle(t, '  写作 🐾  ');
  await recorderToTime(t);
  await recorderTime(t, '开始时间', '2026-10-02 10:00');
  await recorderTime(t, '结束时间', '2026-10-02 11:00');
  if (goal != null) await recorderChooseGoal(t, goal);
  await recorderDetail(t, 'continuation-hint', '  从第二段接上\n检查字段 🐾  ');
}

RecordingDraftContext context(WidgetTester t) => t
    .widget<ActivityRecordingEntry>(find.byType(ActivityRecordingEntry))
    .context;

Future<void> edit(WidgetTester t, String id) =>
    tap(t, find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id))));

void main() {
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning,
  );
  testWidgets(
    'file-backed bootstrap closes the optional Goal/rhythm/lifecycle loop and preserves old fields',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '记录活动');
      await recorderAdvance(t);
      await recorderTap(t, 'activity-unknown');
      await recorderAdvance(t);
      await recorderTime(t, '开始时间', '2026-10-02 08:00');
      await recorderTime(t, '结束时间', '2026-10-02 09:00');
      await textTap(t, '保存到账本');
      var rows = (await t.runAsync(app.snapshot))!;
      expect(rows['goals'], isEmpty);
      expect(rows['rhythm_annotations'], isEmpty);
      final unknownId = rows['time_blocks']!.single['id']! as String;
      final unknown = (await t.runAsync(
        () => app.repo.readTimeBlock(unknownId),
      ))!;
      expect(unknown.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
      expect(unknown.timeBlock.goalId, isNull);
      expect(unknown.timeBlock.startPrecision, TimePrecision.approximate);
      expect(unknown.timeBlock.endPrecision, TimePrecision.approximate);

      await textTap(t, '打开目标');
      expect(find.text('还没有目标。'), findsOneWidget);
      final unusedGoal = await createGoal(t, app);
      final goal = await createGoal(t, app);
      expect(goal, isNot(unusedGoal));
      await back(t);
      await textTap(t, '记录活动');
      await fill(t, goal: goal);
      await recorderDetail(t, 'activity-note', '原备注');
      final draftContext = context(t);
      await recorderKeep(t);
      rows = (await t.runAsync(app.snapshot))!;
      final beforeSave = rows;
      final raw = (await t.runAsync(() => app.drafts.read(draftContext)))!;
      expect(raw.goalId, goal);
      expect(raw.annotationIntent, RecordingAnnotationIntent.add);
      expect(raw.continuationHint, '  从第二段接上\n检查字段 🐾  ');
      await app.reopen(t);
      expect(await t.runAsync(app.snapshot), beforeSave);
      await textTap(t, '记录活动');
      expect(find.text('已恢复上次输入'), findsOneWidget);
      await recorderOpenDetails(t);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('continuation-hint')))
            .controller!
            .text,
        raw.continuationHint,
      );
      await recorderTap(t, 'activity-details-apply');
      await recorderAdvanceTimed(t);
      await textTap(t, '保存到账本');
      expect(await t.runAsync(() => app.drafts.read(draftContext)), isNull);
      rows = (await t.runAsync(app.snapshot))!;
      final blockId =
          rows['time_blocks']!.singleWhere((r) => r['id'] != unknownId)['id']!
              as String;
      final saved = (await t.runAsync(() => app.repo.readTimeBlock(blockId)))!;
      expect(saved.timeBlock.goalId, goal);
      expect(saved.annotation!.id, raw.annotationId);
      expect(saved.annotation!.continuationHint, '从第二段接上\n检查字段 🐾');
      expect(saved.timeBlock.createdAt, app.clock.millisecondsSinceEpoch);

      // Existing fields outside this core UI are legacy facts, not new fields
      // or Should Have controls. Editing state/hint must retain them.
      await t.runAsync(
        () => app.repo.updateTimeBlock(
          id: blockId,
          now: app.clock.millisecondsSinceEpoch,
          categoryId: (value: '原分类'),
          annotation: const EditAnnotation(
            stuckReasonCode: (value: StuckReasonCode.unclearNextStep),
            stuckReasonText: (value: '原原因'),
            recoveryMethod: (value: RecoveryMethod.walk),
            recoveryQuality: (value: RecoveryQuality.partlyRecovered),
          ),
        ),
      );
      rows = (await t.runAsync(app.snapshot))!;
      final factBefore = rows['time_blocks'];
      await textTap(t, '打开日账本');
      var view = controller(t).view!;
      expect(view.accountedDuration.milliseconds, 2 * hour);
      expect(view.unknownDuration.milliseconds, hour);
      expect(view.goalSummaries.single.goalId, goal);
      expect(view.goalSummaries.single.progressDuration.milliseconds, hour);
      expect(view.goalSummaries.single.totalDuration.hasApproximation, isTrue);
      app.clock = DateTime(2026, 10, 2, 12, 1);
      await edit(t, blockId);
      await recorderRhythm(t, RhythmState.stuck);
      await recorderToTime(t);
      await recorderDetail(t, 'continuation-hint', '换个例子再试');
      await textTap(t, '保存更正');
      rows = (await t.runAsync(app.snapshot))!;
      expect(rows['time_blocks'], factBefore);
      final changed = (await t.runAsync(
        () => app.repo.readTimeBlock(blockId),
      ))!;
      expect(changed.annotation!.id, saved.annotation!.id);
      expect(changed.annotation!.createdAt, saved.annotation!.createdAt);
      expect(changed.annotation!.updatedAt, app.clock.millisecondsSinceEpoch);
      expect(
        changed.annotation!.stuckReasonCode,
        StuckReasonCode.unclearNextStep,
      );
      expect(changed.annotation!.stuckReasonText, '原原因');
      expect(changed.annotation!.recoveryMethod, RecoveryMethod.walk);
      expect(
        changed.annotation!.recoveryQuality,
        RecoveryQuality.partlyRecovered,
      );
      view = controller(t).view!;
      expect(view.rhythmSummary.progressDuration.hasRecords, isFalse);
      expect(view.rhythmSummary.stuckDuration.milliseconds, hour);
      expect(view.goalSummaries.single.stuckDuration.milliseconds, hour);
      expect(find.text('接续点：换个例子再试'), findsOneWidget);
      final beforeNoop = rows;
      app.clock = DateTime(2026, 10, 2, 12, 2);
      await edit(t, blockId);
      await textTap(t, '保存更正');
      expect(await t.runAsync(app.snapshot), beforeNoop);

      await back(t);
      await textTap(t, '打开目标');
      await goalAction(t, goal, '归档目标');
      await back(t);
      await textTap(t, '打开日账本');
      expect(controller(t).view!.goalSummaries.single.isArchived, isTrue);
      expect(find.text('目标：同名目标 🐾（已归档）'), findsOneWidget);
      await edit(t, blockId);
      expect(find.text('同名目标 🐾（已归档）'), findsOneWidget);
      await recorderRhythm(t, null);
      await recorderToTime(t);
      await textTap(t, '保存更正');
      view = controller(t).view!;
      expect(view.accountedDuration.milliseconds, 2 * hour);
      expect(view.goalSummaries.single.unannotatedDuration.milliseconds, hour);
      expect(view.rhythmSummary.stuckDuration.hasRecords, isFalse);
      rows = (await t.runAsync(app.snapshot))!;
      expect(rows['rhythm_annotations'], isEmpty);
      expect(rows['time_blocks'], factBefore);
      await back(t);
      await textTap(t, '打开目标');
      await textTap(t, '查看已归档目标');
      await goalAction(t, goal, '恢复目标');
      await back(t);
      await back(t);
      final finalRows = (await t.runAsync(app.snapshot))!;
      await app.reopen(t);
      expect(await t.runAsync(app.snapshot), finalRows);
      await textTap(t, '打开日账本');
      expect(controller(t).view!.goalSummaries.single.isArchived, isFalse);
      expect(
        controller(t).view!.goalSummaries.single.totalDuration.milliseconds,
        hour,
      );
      expect(finalRows['sleep_sessions'], isEmpty);
      expect(finalRows['daily_reviews'], isEmpty);
      await disposeApp(t);
    },
  );

  testWidgets(
    'real annotation SQL failure rolls back create and combined edit; UI retries retained drafts',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '打开目标');
      final goal = await createGoal(t, app);
      await back(t);
      await textTap(t, '记录活动');
      await fill(t, goal: goal);
      final draftContext = context(t);
      final before = (await t.runAsync(app.snapshot))!;
      await t.runAsync(
        () => app.db.customStatement(
          "CREATE TRIGGER fail_annotation AFTER INSERT ON rhythm_annotations BEGIN SELECT RAISE(ABORT, 'test'); END",
        ),
      );
      await textTap(t, '保存到账本');
      expect(find.byType(ActivityRecordingEntry), findsOneWidget);
      expect(await t.runAsync(app.snapshot), before);
      expect(find.text('正式保存失败，当前输入仍保留，请重试。'), findsOneWidget);
      final draft = (await t.runAsync(() => app.drafts.read(draftContext)))!;
      expect(draft.goalId, goal);
      expect(draft.rhythmState, RhythmState.progress);
      expect(draft.title, '  写作 🐾  ');
      await t.runAsync(
        () => app.db.customStatement('DROP TRIGGER fail_annotation'),
      );
      await textTap(t, '保存到账本');
      var rows = (await t.runAsync(app.snapshot))!;
      final id = rows['time_blocks']!.single['id']! as String;
      expect(rows['rhythm_annotations'], hasLength(1));
      expect(await t.runAsync(() => app.drafts.read(draftContext)), isNull);
      await textTap(t, '打开日账本');
      await edit(t, id);
      final editContext = context(t);
      await recorderRhythm(t, RhythmState.recovery);
      await recorderAdvance(t);
      await recorderTitle(t, '更正后的活动');
      await recorderToTime(t);
      await recorderDetail(t, 'continuation-hint', '恢复后接着写');
      app.clock = DateTime(2026, 10, 2, 12, 1);
      await t.runAsync(
        () => app.db.customStatement(
          "CREATE TRIGGER fail_annotation AFTER UPDATE ON rhythm_annotations BEGIN SELECT RAISE(ABORT, 'test'); END",
        ),
      );
      await textTap(t, '保存更正');
      expect(await t.runAsync(app.snapshot), rows);
      expect(find.text('正式保存失败，当前输入仍保留，请重试。'), findsOneWidget);
      final editDraft = (await t.runAsync(() => app.drafts.read(editContext)))!;
      expect(editDraft.title, '更正后的活动');
      expect(editDraft.rhythmState, RhythmState.recovery);
      expect(editDraft.annotationIntent, RecordingAnnotationIntent.edit);
      expect(await t.runAsync(() => app.drafts.read(draftContext)), isNull);
      await t.runAsync(
        () => app.db.customStatement('DROP TRIGGER fail_annotation'),
      );
      await textTap(t, '返回');
      await app.reopen(t);
      await textTap(t, '打开日账本');
      expect(
        controller(t).view!.rhythmSummary.progressDuration.milliseconds,
        hour,
      );
      await edit(t, id);
      expect(find.text('已恢复上次输入'), findsOneWidget);
      await recorderAdvance(t);
      await recorderAdvance(t);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '更正后的活动',
      );
      await recorderToTime(t);
      await textTap(t, '保存更正');
      final read = (await t.runAsync(() => app.repo.readTimeBlock(id)))!;
      expect(read.timeBlock.title, '更正后的活动');
      expect(
        read.timeBlock.createdAt,
        DateTime(2026, 10, 2, 12).millisecondsSinceEpoch,
      );
      expect(read.timeBlock.updatedAt, app.clock.millisecondsSinceEpoch);
      expect(read.annotation!.id, draft.annotationId);
      expect(read.annotation!.state, RhythmState.recovery);
      rows = (await t.runAsync(app.snapshot))!;
      expect(rows['time_blocks'], hasLength(1));
      expect(rows['rhythm_annotations'], hasLength(1));
      expect(await t.runAsync(() => app.drafts.read(editContext)), isNull);
      final view = controller(t).view!;
      expect(view.accountedDuration.milliseconds, hour);
      expect(view.goalSummaries.single.recoveryDuration.milliseconds, hour);
      expect(view.rhythmSummary.progressDuration.hasRecords, isFalse);
      await disposeApp(t);
    },
  );

  testWidgets(
    'committed Goal/annotation survives cleanup plus refresh failure and full bootstrap reopen without duplicate insert',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '打开目标');
      final goal = await createGoal(t, app);
      await back(t);
      await textTap(t, '记录活动');
      await fill(t, goal: goal);
      final draftContext = context(t);
      final draft = (await t.runAsync(() => app.drafts.read(draftContext)))!;
      app.reads.arm = true;
      app.clear.fail = true;
      await textTap(t, '保存到账本');
      expect(find.textContaining('已正式保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.textContaining('本地收尾失败，旧草稿仍可能显示'), findsOneWidget);
      expect(find.textContaining('账本刷新失败，记录已保存'), findsOneWidget);
      expect(find.text('保存到账本'), findsNothing);
      final committed = (await t.runAsync(app.snapshot))!;
      expect(committed['time_blocks'], hasLength(1));
      expect(committed['rhythm_annotations']!.single['id'], draft.annotationId);
      expect(app.reads.blockInserts, 1);
      await textTap(t, '继续清理并刷新');
      expect(await t.runAsync(app.snapshot), committed);
      expect(app.reads.blockInserts, 1);
      expect(await t.runAsync(() => app.drafts.read(draftContext)), isNotNull);
      // Reads must be available to identify the committed draft on restart.
      // Cleanup still fails, leaving the recovered form visibly committed.
      app.reads.arm = false;
      app.reads.failReads = false;
      await app.reopen(t);
      await textTap(t, '记录活动');
      expect(find.textContaining('已正式保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('保存到账本'), findsNothing);
      expect(await t.runAsync(app.snapshot), committed);
      app.clear.fail = false;
      app.clock = DateTime(2026, 10, 2, 12, 2);
      await textTap(t, '继续清理并刷新');
      expect(find.byType(ActivityRecordingEntry), findsNothing);
      expect(await t.runAsync(() => app.drafts.read(draftContext)), isNull);
      expect(await t.runAsync(app.snapshot), committed);
      expect(app.reads.blockInserts, 1);
      await textTap(t, '打开日账本');
      final view = ledgerView(t);
      expect(view.goalSummaries.single.goalId, goal);
      expect(view.goalSummaries.single.progressDuration.milliseconds, hour);
      await disposeApp(t);
    },
  );
}
