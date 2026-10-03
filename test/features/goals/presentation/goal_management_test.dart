import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/presentation/goals_page.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 9, day: 30);
const renameField = ValueKey('goal-rename-name');
const archivedNotice = '目标已有记录引用，已归档；记录与引用保留，可在已归档目标中恢复。';

class ManagementQueries extends QueryInterceptor {
  bool failLists = false;
  bool failAfterCommit = false;
  bool _wroteGoal = false;
  int updates = 0;
  int deletes = 0;
  Completer<void>? updateGate;
  Completer<void>? listGate;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (sql.contains('FROM goals WHERE status')) {
      await listGate?.future;
      if (failLists) throw StateError('test list failure');
    }
    return executor.runSelect(sql, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (sql.contains('goals')) {
      updates++;
      await updateGate?.future;
      final result = await executor.runUpdate(sql, args);
      _wroteGoal = true;
      return result;
    }
    return executor.runUpdate(sql, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runDelete(sql, args);
    if (sql.contains('goals')) {
      deletes++;
      _wroteGoal = true;
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (_wroteGoal && failAfterCommit) failLists = true;
    _wroteGoal = false;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    _wroteGoal = false;
    await inner.rollback();
  }
}

class Harness {
  Harness(this.db, this.queries);
  final AppDatabase db;
  final ManagementQueries queries;
  int now = 100;
  DriftGoalRepository get repo => DriftGoalRepository(db);
  Future<Goal> goal(int n) async => (await repo.findById(id(n)))!;
  Future<void> show(WidgetTester tester, {bool archived = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GoalsPage(
          repository: repo,
          newId: () => id(99),
          now: () => now,
          archived: archived,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<Harness> open(WidgetTester tester) async {
  final queries = ManagementQueries();
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory().interceptWith(queries)),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  return Harness(db, queries);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> action(WidgetTester tester, int n, String action) async {
  await tap(tester, find.byKey(ValueKey('goal-actions-${id(n)}')));
  await tap(tester, find.text(action));
}

Future<void> rename(WidgetTester tester, int n, String text) async {
  await action(tester, n, '改名');
  await tester.enterText(find.byKey(renameField), text);
  await tap(tester, find.text('保存名称'));
}

Future<void> remove(WidgetTester tester, int n) async {
  await action(tester, n, '删除目标');
  await tap(tester, find.text('确认删除'));
}

Future<List<List<Map<String, Object?>>>> facts(AppDatabase db) async => [
  for (final table in [
    'time_blocks',
    'sleep_sessions',
    'rhythm_annotations',
    'daily_reviews',
  ])
    (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((r) => r.data)
        .toList(),
];
Future<void> linkBlock(Harness h, int n) =>
    DriftLedgerRepository(h.db).createTimeBlock(
      id: id(10 + n),
      startedAt: DateTime(2026, 9, 30, n).millisecondsSinceEpoch,
      endedAt: DateTime(2026, 9, 30, n + 1).millisecondsSinceEpoch,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
      knowledgeState: BlockKnowledgeState.known,
      title: '历史活动',
      goalId: id(n),
      now: 1,
    );
Future<void> linkReview(Harness h, int n) => DriftReviewRepository(h.db).create(
  id: id(20 + n),
  date: date,
  tomorrowFirstStepText: '留下的下一步',
  reflection: '保留原文',
  tomorrowFirstStepGoalId: id(n),
  now: 1,
);

void main() {
  testWidgets(
    'rename allows same name and history resolves current metadata without rewriting facts',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        await h.repo.create(id: id(1), name: '旧名', now: 1);
        await h.repo.create(id: id(2), name: '同名', now: 2);
        await linkBlock(h, 1);
        await linkReview(h, 1);
      });
      final before = await tester.runAsync(() => facts(h.db));
      await h.show(tester);
      await rename(tester, 1, '  同名  ');
      expect(find.text('同名'), findsNWidgets(2));
      final goal = (await tester.runAsync(() => h.goal(1)))!;
      expect(
        (goal.id, goal.createdAt, goal.updatedAt, goal.archivedAt),
        (id(1), 1, 100, null),
      );
      expect(await tester.runAsync(() => facts(h.db)), before);
      final view = (await tester.runAsync(
        () => createDayLedgerLoader(h.db).load(
          date: date,
          now: DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
        ),
      ))!;
      expect(view.goalSummaries.single.name, '同名');
      final review = (await tester.runAsync(
        () => DriftReviewRepository(h.db).findByDate(date),
      ))!;
      expect(review.tomorrowFirstStep.goalId, id(1));
      expect(
        (await tester.runAsync(
          () => h.repo.findById(review.tomorrowFirstStep.goalId!),
        ))!.name,
        '同名',
      );
      h.now = 200;
      final updates = h.queries.updates;
      await rename(tester, 1, ' 同名 ');
      expect(h.queries.updates, updates);
      expect((await tester.runAsync(() => h.goal(1)))!.updatedAt, 100);
    },
  );

  testWidgets(
    'archive management restores active selection, preserves create input and handles repeated states',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
      await h.show(tester);
      await tester.enterText(find.byKey(const ValueKey('goal-name')), '尚未提交');
      // Simulate a state change after the visible active list was loaded.
      await tester.runAsync(() => h.repo.archive(id: id(1), now: 50));
      final updates = h.queries.updates;
      await action(tester, 1, '归档目标');
      expect(h.queries.updates, updates);
      expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, 50);
      expect(find.text('尚未创建目标。'), findsOneWidget);
      await tap(tester, find.text('查看已归档目标'));
      expect(find.text('已归档'), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-name')), findsNothing);
      h.now = 150;
      await rename(tester, 1, '归档后改名');
      final archived = (await tester.runAsync(() => h.goal(1)))!;
      expect((archived.updatedAt, archived.archivedAt), (150, 50));
      await tester.runAsync(() => h.repo.restore(id: id(1), now: 160));
      final restoredUpdates = h.queries.updates;
      h.now = 200;
      await action(tester, 1, '恢复目标');
      expect(h.queries.updates, restoredUpdates);
      expect(find.text('暂无已归档目标。'), findsOneWidget);
      expect((await tester.runAsync(() => h.goal(1)))!.updatedAt, 160);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('归档后改名'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('goal-name')))
            .controller!
            .text,
        '尚未提交',
      );
      expect(
        (await tester.runAsync(h.repo.listActive))!.single.archivedAt,
        isNull,
      );
    },
  );

  testWidgets('UI archive and restore write injected metadata exactly once', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
    await h.show(tester);
    await action(tester, 1, '归档目标');
    expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, 100);
    expect((await tester.runAsync(() => h.goal(1)))!.updatedAt, 100);
    await tap(tester, find.text('查看已归档目标'));
    h.now = 200;
    await action(tester, 1, '恢复目标');
    final restored = (await tester.runAsync(() => h.goal(1)))!;
    expect(
      (restored.createdAt, restored.updatedAt, restored.archivedAt),
      (1, 200, null),
    );
    expect(h.queries.updates, 2);
    expect((await tester.runAsync(h.repo.listActive))!.single.id, id(1));
  });

  testWidgets(
    'delete feedback distinguishes block/review references, physical removal and missing',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        for (var n = 1; n <= 3; n++) {
          await h.repo.create(id: id(n), name: '目标$n', now: 1);
        }
        await linkBlock(h, 1);
        await linkReview(h, 2);
      });
      final before = await tester.runAsync(() => facts(h.db));
      await h.show(tester);
      await action(tester, 3, '删除目标');
      await tap(tester, find.text('取消'));
      expect(await tester.runAsync(() => h.repo.findById(id(3))), isNotNull);
      for (final n in [1, 2]) {
        await remove(tester, n);
        expect(find.text(archivedNotice), findsOneWidget);
        expect((await tester.runAsync(() => h.goal(n)))!.archivedAt, 100);
        expect(await tester.runAsync(() => facts(h.db)), before);
      }
      await remove(tester, 3);
      expect(find.text('目标已删除。'), findsOneWidget);
      expect(await tester.runAsync(() => h.repo.findById(id(3))), isNull);
      expect(await tester.runAsync(() => facts(h.db)), before);
      await tap(tester, find.text('查看已归档目标'));
      await remove(tester, 1);
      expect(find.text(archivedNotice), findsOneWidget);
      expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, 100);
      // Leave a stale UI row, then remove its references and delete externally.
      await tester.runAsync(() async {
        await DriftLedgerRepository(h.db).deleteTimeBlock(id(11));
        await h.repo.delete(id: id(1), now: 200);
      });
      await remove(tester, 1);
      expect(find.text('目标已不存在。'), findsOneWidget);
      expect(find.text('目标已删除。'), findsNothing);
    },
  );

  testWidgets(
    'rename domain/storage failure keeps input, retry succeeds, missing never recreates',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '原名', now: 1));
      await h.show(tester);
      await rename(tester, 1, ' \n\t ');
      expect(find.text('名称不能为空，去除首尾空白后最多 200 个字符。'), findsOneWidget);
      await tester.runAsync(
        () => h.db.customStatement(
          "CREATE TEMP TRIGGER fail_name AFTER UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'test failure'); END",
        ),
      );
      await tester.enterText(find.byKey(renameField), '  保留输入  ');
      await tap(tester, find.text('保存名称'));
      expect(find.text('目标改名失败，输入已保留，请重试。'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(renameField)).controller!.text,
        '  保留输入  ',
      );
      expect((await tester.runAsync(() => h.goal(1)))!.name, '原名');
      expect((await tester.runAsync(() => h.goal(1)))!.updatedAt, 1);
      await tester.runAsync(
        () => h.db.customStatement('DROP TRIGGER fail_name'),
      );
      await tap(tester, find.text('保存名称'));
      expect(find.text('保留输入'), findsOneWidget);
      await action(tester, 1, '改名');
      await tester.runAsync(() => h.repo.delete(id: id(1), now: 200));
      await tester.enterText(find.byKey(renameField), '不得重建');
      await tap(tester, find.text('保存名称'));
      expect(find.text('目标已不存在，无法改名。'), findsOneWidget);
      expect(await tester.runAsync(h.repo.listActive), isEmpty);
      await tap(tester, find.text('取消'));
    },
  );

  testWidgets(
    'archive/restore/delete failures roll back and never report success',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
      await h.show(tester);
      await tester.runAsync(
        () => h.db.customStatement(
          "CREATE TEMP TRIGGER fail_state AFTER UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'test failure'); END",
        ),
      );
      await action(tester, 1, '归档目标');
      expect(find.text('目标操作失败，请重试。'), findsOneWidget);
      expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, isNull);
      await tester.runAsync(
        () => h.db.customStatement('DROP TRIGGER fail_state'),
      );
      await action(tester, 1, '归档目标');
      await tap(tester, find.text('查看已归档目标'));
      await tester.runAsync(
        () => h.db.customStatement(
          "CREATE TEMP TRIGGER fail_state AFTER UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'test failure'); END",
        ),
      );
      await action(tester, 1, '恢复目标');
      expect(find.text('目标操作失败，请重试。'), findsOneWidget);
      expect(find.text('目标已恢复，可重新用于时间归属。'), findsNothing);
      expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, 100);
      await tester.runAsync(
        () => h.db.customStatement('DROP TRIGGER fail_state'),
      );
      await tester.runAsync(
        () => h.db.customStatement(
          "CREATE TEMP TRIGGER fail_delete AFTER DELETE ON goals BEGIN SELECT RAISE(FAIL, 'test failure'); END",
        ),
      );
      await remove(tester, 1);
      expect(find.text('目标操作失败，请重试。'), findsOneWidget);
      expect(find.text('目标已删除。'), findsNothing);
      expect(await tester.runAsync(() => h.repo.findById(id(1))), isNotNull);
      await tester.runAsync(
        () => h.db.customStatement('DROP TRIGGER fail_delete'),
      );
      await remove(tester, 1);
      expect(find.text('目标已删除。'), findsOneWidget);
    },
  );

  testWidgets(
    'committed management actions with read failure only retry reads',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
      await h.show(tester);
      h.queries.failAfterCommit = true;
      await rename(tester, 1, '改名成功');
      expect(find.text('目标名称已保存。'), findsOneWidget);
      expect(find.text('目标列表读取失败，请重试读取。'), findsOneWidget);
      h.queries.failLists = false;
      await tap(tester, find.text('重试读取目标'));
      expect(h.queries.updates, 1);
      await action(tester, 1, '归档目标');
      expect(find.text('目标已归档，可在已归档目标中恢复。'), findsOneWidget);
      expect(find.text('目标操作失败，请重试。'), findsNothing);
      h.queries.failLists = false;
      await tap(tester, find.text('重试读取目标'));
      expect(h.queries.updates, 2);
      await tap(tester, find.text('查看已归档目标'));
      await action(tester, 1, '恢复目标');
      expect(find.text('目标已恢复，可重新用于时间归属。'), findsOneWidget);
      h.queries.failLists = false;
      await tap(tester, find.text('重试读取目标'));
      expect(h.queries.updates, 3);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await remove(tester, 1);
      expect(find.text('目标已删除。'), findsOneWidget);
      expect(find.text('目标列表读取失败，请重试读取。'), findsOneWidget);
      h.queries.failLists = false;
      await tap(tester, find.text('重试读取目标'));
      expect(h.queries.deletes, 1);
    },
  );

  testWidgets(
    'pending management action blocks duplicate callbacks and refresh',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
      await h.show(tester);
      final menuFinder = find.byKey(ValueKey('goal-actions-${id(1)}'));
      final dynamic menu = tester.widget(menuFinder);
      final archiveItem = menu
          .itemBuilder(tester.element(menuFinder))
          .whereType<PopupMenuItem<dynamic>>()
          .singleWhere((item) => (item.child as Text).data == '归档目标');
      final refresh = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '刷新目标'))
          .onPressed!;
      h.queries.updateGate = Completer<void>();
      menu.onSelected!(archiveItem.value);
      menu.onSelected!(archiveItem.value);
      refresh();
      await tester.pump();
      expect(
        tester.widget<PopupMenuButton<dynamic>>(menuFinder).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('goal-name')))
            .enabled,
        isFalse,
      );
      h.queries.updateGate!.complete();
      await tester.pumpAndSettle();
      expect(h.queries.updates, 1);
      expect((await tester.runAsync(() => h.goal(1)))!.archivedAt, 100);
    },
  );

  testWidgets(
    'stale archive and restore show missing object without recreation',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() => h.repo.create(id: id(1), name: '目标', now: 1));
      await h.show(tester);
      await tester.runAsync(() => h.repo.delete(id: id(1), now: 2));
      await action(tester, 1, '归档目标');
      expect(find.text('目标已不存在，请刷新目标列表。'), findsOneWidget);
      expect(find.text('目标已归档，可在已归档目标中恢复。'), findsNothing);
      await tester.runAsync(() async {
        await h.repo.create(id: id(2), name: '归档目标', now: 1);
        await h.repo.archive(id: id(2), now: 2);
      });
      await tap(tester, find.text('查看已归档目标'));
      await tester.runAsync(() => h.repo.delete(id: id(2), now: 3));
      await action(tester, 2, '恢复目标');
      expect(find.text('目标已不存在，请刷新目标列表。'), findsOneWidget);
      expect(await tester.runAsync(h.repo.listActive), isEmpty);
      expect(await tester.runAsync(h.repo.listArchived), isEmpty);
    },
  );

  testWidgets(
    'archived page loading/error is distinct from empty and retries',
    (tester) async {
      final h = await open(tester);
      await h.show(tester);
      h.queries.listGate = Completer<void>();
      await tester.tap(find.text('查看已归档目标'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('正在读取目标…'), findsOneWidget);
      expect(find.text('暂无已归档目标。'), findsNothing);
      h.queries.failLists = true;
      h.queries.listGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('目标列表读取失败，请重试读取。'), findsOneWidget);
      expect(find.text('暂无已归档目标。'), findsNothing);
      h.queries.failLists = false;
      await tap(tester, find.text('重试读取目标'));
      expect(find.text('暂无已归档目标。'), findsOneWidget);
    },
  );
}
