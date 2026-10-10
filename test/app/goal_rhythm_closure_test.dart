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
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import '../support/app_recording_navigation.dart' show tap, textTap;
import '../support/activity_recorder.dart';
import 'day_ledger_resolution_flow_test.dart' show BlockReadFailure;
import 'recording_goal_flow_test.dart' show disposeApp;
import 'support/checked_sleep_opening.dart';

const hour = Duration.millisecondsPerHour;
final _date = CivilDate(year: 2026, month: 10, day: 2);

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

DayLedgerView? homeView(WidgetTester t) =>
    t.state<HomeShellState>(find.byType(HomeShell)).feed.focusView;

/// 目标选择入口（其他 app 测试复用）：在理解层里点一个目标。
Future<void> chooseGoal(WidgetTester t, String id) async {
  await tap(t, find.byKey(ValueKey('understanding-goal-$id')));
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

Future<void> edit(WidgetTester t, String id) async {
  final shell = t.state<HomeShellState>(find.byType(HomeShell));
  await shell.openDate(_date);
  await t.pumpAndSettle();
  final reference = (type: LedgerFactType.timeBlock, id: id);
  final target = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey && key.value == reference;
  });
  if (target.evaluate().isEmpty) {
    fail('fact node $id not found after jumping to $_date');
  }
  await t.ensureVisible(target.first);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await t.pumpAndSettle();
}

Future<void> main() async {
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning,
  );

  testWidgets(
    'record sheet saves the fact first, then the understanding layer writes goal and rhythm',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '打开目标');
      final goal = await createGoal(t, app);
      await back(t);

      // 事实优先：时间 + 一句话 → 保存记录。
      await textTap(t, '记录活动');
      await recorderTitle(t, '  写作 🐾  ');
      await recorderTime(t, '开始时间', '2026-10-02 10:00');
      await recorderTime(t, '结束时间', '2026-10-02 11:00');
      final panelHeight = t
          .getSize(find.byKey(const ValueKey('sheet-stage-form')))
          .height;
      await recorderSave(t);
      var rows = (await t.runAsync(app.snapshot))!;
      expect(rows['time_blocks'], hasLength(1));
      expect(rows['rhythm_annotations'], isEmpty);
      final blockId = rows['time_blocks']!.single['id']! as String;
      // 同一面板原地进入理解层，不换窗口；理解层沿用记录面板的高度。
      expect(find.byKey(const ValueKey('activity-primary')), findsNothing);
      expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
      expect(find.text('10:00 → 11:00'), findsOneWidget);
      expect(
        t.getSize(find.byKey(const ValueKey('activity-sheet-frame'))).height,
        panelHeight,
      );

      await understandingPickGoal(t, goal);
      expect(find.text('回头看，这段时间整体是什么状态？'), findsOneWidget);
      await understandingPickState(t, RhythmState.stuck);
      // 目标 → 状态 → 补充：面板高度保持不变。
      expect(
        t.getSize(find.byKey(const ValueKey('activity-sheet-frame'))).height,
        panelHeight,
      );
      await understandingOpenReason(t);
      await t.enterText(recorderKey('understanding-reason-text'), '一直改来改去');
      await understandingOpenHint(t);
      await t.enterText(recorderKey('understanding-hint'), ' 从字段关系接上 ');
      await understandingFinish(t);
      expect(
        find.byKey(const ValueKey('activity-understanding')),
        findsNothing,
      );
      // 保存确认改为顶部轻提示：不遮挡底部操作栏，且限制在时间轴区域内。
      expect(find.byKey(const ValueKey('top-toast')), findsOneWidget);
      final toastRect = t.getRect(find.byKey(const ValueKey('top-toast')));
      final surfaceRect = t.getRect(
        find.byKey(const ValueKey('home-reading-surface')),
      );
      expect(toastRect.top, greaterThanOrEqualTo(surfaceRect.top - 1));
      expect(toastRect.bottom, lessThanOrEqualTo(surfaceRect.bottom));

      final saved = (await t.runAsync(() => app.repo.readTimeBlock(blockId)))!;
      expect(saved.timeBlock.goalId, goal);
      expect(saved.timeBlock.knowledgeState, BlockKnowledgeState.known);
      expect(saved.annotation!.state, RhythmState.stuck);
      expect(saved.annotation!.stuckReasonText, '一直改来改去');
      expect(saved.annotation!.continuationHint, '从字段关系接上');

      final view = homeView(t)!;
      expect(view.accountedDuration.milliseconds, hour);
      expect(view.goalSummaries.single.goalId, goal);
      expect(view.goalSummaries.single.stuckDuration.milliseconds, hour);
      expect(view.rhythmSummary.stuckDuration.milliseconds, hour);

      // 更正活动与时间仍走同一记录面板，解释保留。
      await t.runAsync(
        () => app.repo.updateTimeBlock(
          id: blockId,
          now: app.clock.millisecondsSinceEpoch,
          categoryId: (value: '原分类'),
        ),
      );
      await t.pumpAndSettle();
      await edit(t, blockId);
      await tap(t, find.byKey(const ValueKey('fact-detail-edit')));
      expect(find.text('更正记录'), findsWidgets);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '写作 🐾',
      );
      await recorderTitle(t, '更正后的活动');
      await recorderSave(t);
      final changed = (await t.runAsync(
        () => app.repo.readTimeBlock(blockId),
      ))!;
      expect(changed.timeBlock.title, '更正后的活动');
      expect(changed.annotation!.id, saved.annotation!.id);
      expect(changed.annotation!.state, RhythmState.stuck);
      expect(changed.annotation!.continuationHint, '从字段关系接上');

      // 详情里的理解层可以移除解释、保留事实。
      await edit(t, blockId);
      await tap(t, find.byKey(const ValueKey('fact-detail-understanding')));
      await understandingSkipGoal(t);
      // 详情面板里系统返回先退回目标问题，再关闭面板。
      await back(t);
      expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
      await understandingSkipGoal(t);
      await understandingUnsure(t);
      rows = (await t.runAsync(app.snapshot))!;
      expect(rows['rhythm_annotations'], isEmpty);
      expect(rows['time_blocks'], hasLength(1));
      await disposeApp(t);
    },
  );

  testWidgets(
    'understanding write failure keeps the card and retries without touching the fact',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '打开目标');
      final goal = await createGoal(t, app);
      await back(t);
      await textTap(t, '记录活动');
      await recorderTitle(t, '失败重试');
      await recorderTime(t, '开始时间', '2026-10-02 10:00');
      await recorderTime(t, '结束时间', '2026-10-02 11:00');
      await recorderSave(t);
      await understandingPickGoal(t, goal);
      final before = (await t.runAsync(app.snapshot))!;
      await t.runAsync(
        () => app.db.customStatement(
          "CREATE TRIGGER fail_annotation AFTER INSERT ON rhythm_annotations BEGIN SELECT RAISE(ABORT, 'test'); END",
        ),
      );
      await understandingPickState(t, RhythmState.progress);
      expect(find.byKey(const ValueKey('understanding-error')), findsOneWidget);
      expect(await t.runAsync(app.snapshot), before);
      await t.runAsync(
        () => app.db.customStatement('DROP TRIGGER fail_annotation'),
      );
      await understandingPickState(t, RhythmState.progress);
      await understandingFinish(t);
      final rows = (await t.runAsync(app.snapshot))!;
      expect(rows['rhythm_annotations'], hasLength(1));
      expect(
        find.byKey(const ValueKey('activity-understanding')),
        findsNothing,
      );
      await disposeApp(t);
    },
  );

  testWidgets(
    'committed cleanup failure keeps the sheet recoverable and never inserts twice',
    (t) async {
      final app = await ClosureApp.open(t);
      await textTap(t, '记录活动');
      await recorderTitle(t, '收尾失败');
      await recorderTime(t, '开始时间', '2026-10-02 10:00');
      await recorderTime(t, '结束时间', '2026-10-02 11:00');
      app.reads.arm = true;
      await recorderSave(t);
      expect(find.textContaining('账本刷新失败，记录已保存'), findsOneWidget);
      final committed = (await t.runAsync(app.snapshot))!;
      expect(committed['time_blocks'], hasLength(1));
      expect(app.reads.blockInserts, 1);
      app.reads.arm = false;
      app.reads.failReads = false;
      await recorderSave(t);
      expect(find.byKey(const ValueKey('activity-primary')), findsNothing);
      // 收尾成功后同一面板进入理解层；关闭后返回账本。
      expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
      expect(await t.runAsync(app.snapshot), committed);
      expect(app.reads.blockInserts, 1);
      await recorderTap(t, 'understanding-close');
      expect(
        find.byKey(const ValueKey('activity-understanding')),
        findsNothing,
      );
      await disposeApp(t);
    },
  );
}
