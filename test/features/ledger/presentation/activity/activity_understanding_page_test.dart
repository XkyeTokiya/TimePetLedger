import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_understanding_page.dart';

import '../../../../app/review_form_entry_test.dart' show settleNative;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final start = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 1, 11).millisecondsSinceEpoch;

class CardFixture {
  CardFixture(this.db);
  final AppDatabase db;
  late final repo = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  int ids = 500;
  int nowMs = end + 1;
  bool closed = false;
  final notices = <String>[];
  List<Goal> goalList = const [];
  late final service = ActivityUnderstandingService(
    repository: repo,
    now: () => nowMs,
    newId: () => id(ids++),
  );

  static Future<CardFixture> open() async =>
      CardFixture(await AppDatabase.open(NativeDatabase.memory()));

  Future<void> close() => db.close();

  Future<Goal> goal() async =>
      goals.create(id: id(1), name: '毕业设计', now: nowMs);

  Future<void> seed({
    bool unknown = false,
    bool withAnnotation = false,
    bool withGoal = false,
    String? hint,
  }) async {
    // Q-004（2026-10-11）：progress 解释必须挂在有 Goal 的事实上。
    if (withGoal) {
      await goals.create(id: id(9), name: '目标', now: nowMs);
    }
    await repo.createTimeBlock(
      id: id(8),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      knowledgeState: unknown
          ? BlockKnowledgeState.unknown
          : BlockKnowledgeState.known,
      title: unknown ? null : '原活动',
      goalId: withGoal ? id(9) : null,
      now: 1,
      annotation: withAnnotation
          ? AddAnnotation(
              id: id(7),
              state: RhythmState.progress,
              continuationHint: hint,
            )
          : null,
    );
  }

  Widget app(
    String recordId, {
    ActivityUnderstandingMode mode = ActivityUnderstandingMode.afterSave,
    Future<Goal> Function(String name)? createGoal,
  }) => MaterialApp(
    theme: homeTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: ActivityUnderstandingPage(
          key: const ValueKey('card-under-test'),
          mode: mode,
          recordId: recordId,
          service: service,
          loadGoals: () async => goalList,
          createGoal: createGoal,
          onWrote: () async {},
          onNotice: notices.add,
          onClose: () => closed = true,
        ),
      ),
    ),
  );
}

Future<CardFixture> open(WidgetTester t) async {
  final fixture = (await t.runAsync(CardFixture.open))!;
  addTearDown(fixture.close);
  return fixture;
}

Future<void> tapCard(WidgetTester t, String value) async {
  final target = find.byKey(ValueKey(value));
  expect(target, findsWidgets, reason: 'missing $value');
  await t.ensureVisible(target.first);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await settleNative(t);
}

Future<void> typeCard(WidgetTester t, String value, String text) async {
  await t.enterText(find.byKey(ValueKey(value)), text);
  await settleNative(t);
}

void main() {
  testWidgets('after-save card writes goal, state and folded details', (
    t,
  ) async {
    final f = await open(t);
    final goal = (await t.runAsync(f.goal))!;
    f.goalList = [goal];
    await t.runAsync(f.seed);
    await t.pumpWidget(f.app(id(8)));
    await settleNative(t);

    expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
    await tapCard(t, 'understanding-goal-${goal.id}');
    expect(find.text('回头看，这段时间整体是什么状态？'), findsOneWidget);
    await tapCard(t, 'understanding-state-stuck');
    expect(
      find.byKey(const ValueKey('understanding-reason-text')),
      findsNothing,
    );
    await tapCard(t, 'understanding-fold-reason');
    await typeCard(t, 'understanding-reason-text', '一直改来改去');
    await tapCard(t, 'understanding-fold-hint');
    await typeCard(t, 'understanding-hint', '从字段关系接上');
    await tapCard(t, 'understanding-finish');

    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.timeBlock.goalId, goal.id);
    expect(stored.annotation!.state, RhythmState.stuck);
    expect(stored.annotation!.stuckReasonText, '一直改来改去');
    expect(stored.annotation!.continuationHint, '从字段关系接上');
    expect(f.closed, isTrue);
    expect(f.notices, contains('已更新。'));
  });

  testWidgets('unsure writes nothing and keeps the fact intact', (t) async {
    final f = await open(t);
    await t.runAsync(f.seed);
    await t.pumpWidget(f.app(id(8)));
    await settleNative(t);
    await tapCard(t, 'understanding-skip-goal');
    await tapCard(t, 'understanding-state-unsure');
    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.annotation, isNull);
    expect(stored.timeBlock.goalId, isNull);
    expect(f.closed, isTrue);
    expect(f.notices.last, contains('已跳过判断'));
  });

  testWidgets('edit mode changes the state and keeps retained fields', (
    t,
  ) async {
    final f = await open(t);
    await t.runAsync(
      () => f.seed(withAnnotation: true, withGoal: true, hint: '原接续点'),
    );
    await t.pumpWidget(f.app(id(8), mode: ActivityUnderstandingMode.edit));
    await settleNative(t);
    await tapCard(t, 'understanding-skip-goal');
    await tapCard(t, 'understanding-state-stuck');
    await tapCard(t, 'understanding-finish');
    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.annotation!.state, RhythmState.stuck);
    expect(stored.annotation!.id, id(7));
    expect(stored.annotation!.continuationHint, '原接续点');
  });

  testWidgets(
    'progress without goal asks for a goal and cancel keeps no write',
    (t) async {
      final f = await open(t);
      final goal = (await t.runAsync(f.goal))!;
      f.goalList = [goal];
      await t.runAsync(f.seed);
      await t.pumpWidget(f.app(id(8)));
      await settleNative(t);

      await tapCard(t, 'understanding-skip-goal');
      await tapCard(t, 'understanding-state-progress');
      // Q-004（2026-10-11）：无目标点“推进”先询问目标；取消不改变任何东西。
      expect(
        find.byKey(const ValueKey('progress-goal-picker')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('progress-goal-cancel')));
      await settleNative(t);
      final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
      expect(stored.annotation, isNull);
      expect(stored.timeBlock.goalId, isNull);
      expect(find.text('回头看，这段时间整体是什么状态？'), findsOneWidget);
    },
  );

  testWidgets('choosing a goal in the prompt links it and records progress', (
    t,
  ) async {
    final f = await open(t);
    final goal = (await t.runAsync(f.goal))!;
    f.goalList = [goal];
    await t.runAsync(f.seed);
    await t.pumpWidget(f.app(id(8)));
    await settleNative(t);

    await tapCard(t, 'understanding-skip-goal');
    await tapCard(t, 'understanding-state-progress');
    await t.tap(find.byKey(ValueKey('progress-goal-option-${goal.id}')));
    await settleNative(t);
    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.timeBlock.goalId, goal.id);
    expect(stored.annotation!.state, RhythmState.progress);
    expect(find.textContaining('已选：推进'), findsOneWidget);
  });

  testWidgets('the prompt can create a new goal and link it to progress', (
    t,
  ) async {
    final f = await open(t);
    f.goalList = const [];
    await t.runAsync(f.seed);
    await t.pumpWidget(
      f.app(
        id(8),
        createGoal: (name) => f.goals.create(id: id(555), name: name, now: 1),
      ),
    );
    await settleNative(t);

    await tapCard(t, 'understanding-skip-goal');
    await tapCard(t, 'understanding-state-progress');
    await tapCard(t, 'progress-goal-new');
    await t.enterText(find.byKey(const ValueKey('progress-goal-name')), '整理生活');
    await tapCard(t, 'progress-goal-create');
    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.timeBlock.goalId, id(555));
    expect(stored.annotation!.state, RhythmState.progress);
  });

  testWidgets('failed write shows an inline error and retries', (t) async {
    final f = await open(t);
    final goal = (await t.runAsync(f.goal))!;
    f.goalList = [goal];
    await t.runAsync(f.seed);
    await t.pumpWidget(f.app(id(8)));
    await settleNative(t);
    await tapCard(t, 'understanding-goal-${goal.id}');
    await t.runAsync(
      () => f.db.customStatement(
        "CREATE TRIGGER fail_annotation AFTER INSERT ON rhythm_annotations BEGIN SELECT RAISE(ABORT, 'test'); END",
      ),
    );
    await tapCard(t, 'understanding-state-progress');
    expect(find.byKey(const ValueKey('understanding-error')), findsOneWidget);
    final before = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(before.annotation, isNull);
    await t.runAsync(
      () => f.db.customStatement('DROP TRIGGER fail_annotation'),
    );
    await tapCard(t, 'understanding-state-progress');
    await tapCard(t, 'understanding-finish');
    final after = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(after.annotation!.state, RhythmState.progress);
  });
}
