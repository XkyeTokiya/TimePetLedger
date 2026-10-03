import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/goals/presentation/goals_page.dart';

String goalId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
const nameField = ValueKey('goal-name');
const nameError = '名称不能为空，去除首尾空白后最多 200 个字符。';

// All writes and successful reads go through real SQLite and DriftGoalRepository.
// Gates expose in-flight UI states; only active-list SELECTs can be faulted.
class GoalQueries extends QueryInterceptor {
  Completer<void>? readGate;
  Completer<void>? insertGate;
  bool failReads = false;
  bool failAfterCommit = false;
  bool _wroteGoal = false;
  int inserts = 0;
  int listReads = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (sql.contains("status = 'active'")) {
      listReads++;
      await readGate?.future;
      if (failReads) throw StateError('test SQL read failure');
    }
    return executor.runSelect(sql, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (sql.contains('goals')) {
      inserts++;
      await insertGate?.future;
      final result = await executor.runInsert(sql, args);
      _wroteGoal = true;
      return result;
    }
    return executor.runInsert(sql, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (_wroteGoal && failAfterCommit) failReads = true;
    _wroteGoal = false;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    _wroteGoal = false;
    await inner.rollback();
  }
}

Future<AppDatabase> openGoals(
  WidgetTester tester, [
  GoalQueries? queries,
]) async {
  final executor = NativeDatabase.memory();
  final db = (await tester.runAsync(
    () => AppDatabase.open(
      queries == null ? executor : executor.interceptWith(queries),
    ),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  return db;
}

Future<void> showGoals(
  WidgetTester tester,
  AppDatabase db, {
  int Function()? clock,
}) async {
  var identity = 10;
  await tester.pumpWidget(
    MaterialApp(
      home: GoalsPage(
        repository: DriftGoalRepository(db),
        newId: () => goalId(identity++),
        now: clock ?? () => 42,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> create(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(nameField), name);
  await tester.tap(find.text('创建目标'));
  await tester.pumpAndSettle();
}

String input(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(nameField)).controller!.text;

void main() {
  testWidgets('empty, active-only and same-name goals retain independent ids', (
    tester,
  ) async {
    final db = await openGoals(tester);
    final repo = DriftGoalRepository(db);
    await tester.runAsync(() async {
      await repo.create(id: goalId(1), name: '已归档', now: 1);
      await repo.archive(id: goalId(1), now: 2);
    });
    var now = 42;
    await showGoals(tester, db, clock: () => now);
    expect(find.text('尚未创建目标。'), findsOneWidget);
    expect(find.text('已归档'), findsNothing);
    await create(tester, '  学习  Flutter\n章节  ');
    expect(find.text('尚未创建目标。'), findsNothing);
    expect(input(tester), isEmpty);
    now = 99;
    await create(tester, '学习  Flutter\n章节');
    expect(find.text('学习  Flutter\n章节'), findsNWidgets(2));
    expect(find.byKey(ValueKey(goalId(10))), findsOneWidget);
    expect(find.byKey(ValueKey(goalId(11))), findsOneWidget);
    final goals = (await tester.runAsync(repo.listActive))!;
    expect(goals, hasLength(2));
    expect(goals.map((g) => g.status), everyElement(GoalStatus.active));
    expect(goals.map((g) => g.archivedAt), everyElement(isNull));
    expect(goals.map((g) => g.createdAt), [42, 99]);
    expect(goals.map((g) => g.updatedAt), [42, 99]);
    await tester.runAsync(
      () => repo.create(id: goalId(2), name: '外部新增', now: 100),
    );
    await tester.tap(find.text('刷新目标'));
    await tester.pumpAndSettle();
    expect(find.text('外部新增'), findsOneWidget);
  });

  testWidgets(
    'domain rejects blank and 201 code points; accepts trimmed 200 emoji',
    (tester) async {
      final db = await openGoals(tester);
      await showGoals(tester, db);
      for (final name in [' \n\t ', '😀' * 201]) {
        await create(tester, name);
        expect(find.text(nameError), findsOneWidget);
        expect(input(tester), name);
        expect(
          await tester.runAsync(DriftGoalRepository(db).listActive),
          isEmpty,
        );
      }
      final boundary = '😀' * 200;
      await create(tester, '  $boundary  ');
      expect(find.text(nameError), findsNothing);
      final goals = (await tester.runAsync(
        DriftGoalRepository(db).listActive,
      ))!;
      expect(goals.single.name, boundary);
      expect(input(tester), isEmpty);
    },
  );

  testWidgets(
    'SQLite write failure rolls back, preserves raw input and retries once',
    (tester) async {
      final db = await openGoals(tester);
      await tester.runAsync(
        () => db.customStatement('''
      CREATE TEMP TRIGGER reject_goal AFTER INSERT ON goals
      BEGIN SELECT RAISE(FAIL, 'test write failure'); END
    '''),
      );
      await showGoals(tester, db);
      await create(tester, '  重试目标  ');
      expect(find.text('目标保存失败，输入已保留，请重试。'), findsOneWidget);
      expect(find.text('目标已保存。'), findsNothing);
      expect(input(tester), '  重试目标  ');
      expect(
        await tester.runAsync(DriftGoalRepository(db).listActive),
        isEmpty,
      );
      await tester.runAsync(
        () => db.customStatement('DROP TRIGGER reject_goal'),
      );
      await tester.tap(find.text('创建目标'));
      await tester.pumpAndSettle();
      expect(find.text('目标已保存。'), findsOneWidget);
      expect(find.text('重试目标'), findsOneWidget);
      expect(
        (await tester.runAsync(DriftGoalRepository(db).listActive))!,
        hasLength(1),
      );
      expect(input(tester), isEmpty);
    },
  );

  testWidgets(
    'loading and failed reads never render empty; retry keeps input',
    (tester) async {
      final queries = GoalQueries()..readGate = Completer<void>();
      final db = await openGoals(tester, queries);
      await tester.pumpWidget(
        MaterialApp(
          home: GoalsPage(
            repository: DriftGoalRepository(db),
            newId: () => goalId(1),
            now: () => 1,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('正在读取目标…'), findsOneWidget);
      expect(find.text('尚未创建目标。'), findsNothing);
      await tester.enterText(find.byKey(nameField), '读取期间输入');
      queries.failReads = true;
      queries.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('目标列表读取失败，请重试读取。'), findsOneWidget);
      expect(find.text('尚未创建目标。'), findsNothing);
      expect(input(tester), '读取期间输入');
      queries.failReads = false;
      await tester.tap(find.text('重试读取目标'));
      await tester.pumpAndSettle();
      expect(find.text('尚未创建目标。'), findsOneWidget);
      expect(input(tester), '读取期间输入');
    },
  );

  testWidgets('committed creation plus reread failure retries only SELECT', (
    tester,
  ) async {
    final queries = GoalQueries();
    final db = await openGoals(tester, queries);
    await showGoals(tester, db);
    queries.failAfterCommit = true;
    await create(tester, '已经保存');
    expect(find.text('目标已保存。'), findsOneWidget);
    expect(find.text('目标列表读取失败，请重试读取。'), findsOneWidget);
    expect(find.text('目标保存失败，输入已保留，请重试。'), findsNothing);
    expect(find.text('尚未创建目标。'), findsNothing);
    expect(input(tester), isEmpty);
    expect(queries.inserts, 1);
    queries.failReads = false;
    await tester.tap(find.text('重试读取目标'));
    await tester.pumpAndSettle();
    expect(find.text('已经保存'), findsOneWidget);
    expect(
      (await tester.runAsync(DriftGoalRepository(db).listActive))!,
      hasLength(1),
    );
    expect(queries.inserts, 1);
  });

  testWidgets(
    'pending write blocks double submission and preserves submitted input',
    (tester) async {
      final queries = GoalQueries()..insertGate = Completer<void>();
      final db = await openGoals(tester, queries);
      await showGoals(tester, db);
      await tester.enterText(find.byKey(nameField), '一次提交');
      final submit = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '创建目标'))
          .onPressed!;
      final refresh = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '刷新目标'))
          .onPressed!;
      submit();
      submit();
      refresh();
      await tester.pump();
      expect(queries.listReads, 1);
      expect(tester.widget<TextField>(find.byKey(nameField)).enabled, isFalse);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '正在保存目标…'))
            .onPressed,
        isNull,
      );
      queries.insertGate!.complete();
      await tester.pumpAndSettle();
      expect(queries.inserts, 1);
      expect(queries.listReads, 2);
      expect(
        (await tester.runAsync(DriftGoalRepository(db).listActive))!,
        hasLength(1),
      );
    },
  );

  testWidgets('completion after page disposal is safe', (tester) async {
    final queries = GoalQueries()..readGate = Completer<void>();
    final db = await openGoals(tester, queries);
    await tester.pumpWidget(
      MaterialApp(
        home: GoalsPage(
          repository: DriftGoalRepository(db),
          newId: () => goalId(1),
          now: () => 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    queries.readGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
