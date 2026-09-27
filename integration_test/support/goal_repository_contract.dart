import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';

const goalId = '00000000-0000-4000-8000-000000000001';
const otherGoalId = '00000000-0000-4000-8000-000000000002';
const _missingId = '00000000-0000-4000-8000-000000000003';
const _now = 1790467200123;

Map<String, Object?> goalFields(Goal goal) => {
  'id': goal.id,
  'name': goal.name,
  'status': goal.status,
  'createdAt': goal.createdAt,
  'updatedAt': goal.updatedAt,
  'archivedAt': goal.archivedAt,
};

Future<void> _linkBlock(AppDatabase db) => db.customStatement(
  'INSERT INTO time_blocks (id, started_at, ended_at, start_precision, '
  'end_precision, knowledge_state, title, goal_id, created_at, updated_at) '
  "VALUES (?, 10, 20, 'approximate', 'exact', 'known', '写论文', ?, 30, 30)",
  [goalId, goalId],
);
Future<void> _linkReview(AppDatabase db) => db.customStatement(
  'INSERT INTO daily_reviews (id, review_date, tomorrow_first_step_text, '
  'tomorrow_first_step_goal_id, created_at, updated_at) '
  "VALUES (?, '2026-09-27', '继续写论文', ?, 30, 30)",
  [goalId, goalId],
);

Future<List<Map<String, Object?>>> _facts(AppDatabase db) async => [
  for (final table in [
    'time_blocks',
    'rhythm_annotations',
    'sleep_sessions',
    'daily_reviews',
  ])
    for (final row
        in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
      {'table': table, ...row.data},
];

final goalRepositoryChecks = <String, Future<void> Function(AppDatabase)>{
  'create/read round trip, duplicate identity and normalized names':
      (db) async {
        final GoalRepository repo = DriftGoalRepository(db);
        expect(await repo.findById(goalId), isNull);
        expect(await repo.listActive(), isEmpty);
        final created = await repo.create(
          id: goalId,
          name: '  论文\n 第一章  ',
          now: _now,
        );
        expect(created.name, '论文\n 第一章');
        expect(created.status, GoalStatus.active);
        expect(created.createdAt, _now);
        expect(created.updatedAt, _now);
        expect(created.archivedAt, isNull);
        expect(goalFields((await repo.findById(goalId))!), goalFields(created));
        expect((await repo.listActive()).map(goalFields), [
          goalFields(created),
        ]);
        await expectLater(
          repo.create(id: goalId, name: '覆盖', now: _now + 1),
          throwsA(isA<GoalAlreadyExistsException>()),
        );
        expect(goalFields((await repo.findById(goalId))!), goalFields(created));
        await repo.create(id: otherGoalId, name: created.name, now: 0);
        expect(await repo.listActive(), hasLength(2));
        for (final invalid in ['', ' \t\n ', List.filled(201, '😀').join()]) {
          await expectLater(
            repo.create(id: _missingId, name: invalid, now: 0),
            throwsArgumentError,
          );
          await expectLater(
            repo.rename(id: goalId, name: invalid, now: 1),
            throwsArgumentError,
          );
        }
        await expectLater(
          repo.create(id: 'bad', name: '合法名称', now: 0),
          throwsArgumentError,
        );
        expect(await repo.findById(_missingId), isNull);
        expect(goalFields((await repo.findById(goalId))!), goalFields(created));
        final renamed = await repo.rename(
          id: goalId,
          name: List.filled(200, '😀').join(),
          now: -1,
        );
        expect(renamed.name.runes.length, 200);
        expect(
          renamed.updatedAt,
          -1,
        ); // Clock rollback is not silently corrected.
        expect(renamed.createdAt, _now);
        await repo.rename(
          id: goalId,
          name: created.name,
          now: 5,
        ); // Duplicate allowed.
        expect(await repo.listActive(), hasLength(2));
      },
  'rename and lifecycle preserve metadata; no-op requests do not write':
      (db) async {
        final repo = DriftGoalRepository(db);
        await repo.create(id: goalId, name: '论文', now: _now);
        final archived = await repo.archive(id: goalId, now: _now + 1);
        expect(archived.archivedAt, _now + 1);
        expect(archived.updatedAt, _now + 1);
        expect(await repo.listActive(), isEmpty);
        expect((await repo.findById(goalId))!.status, GoalStatus.archived);
        final renamed = await repo.rename(
          id: goalId,
          name: '  新论文  ',
          now: _now + 2,
        );
        expect(renamed.name, '新论文');
        expect(renamed.createdAt, _now);
        expect(renamed.archivedAt, _now + 1);
        expect(renamed.updatedAt, _now + 2);
        await db.customStatement(
          "CREATE TEMP TRIGGER forbid_noop BEFORE UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'unexpected update'); END",
        );
        expect(
          goalFields(await repo.archive(id: goalId, now: _now + 99)),
          goalFields(renamed),
        );
        expect(
          goalFields(
            await repo.rename(id: goalId, name: ' 新论文 ', now: _now + 99),
          ),
          goalFields(renamed),
        );
        await db.customStatement('DROP TRIGGER forbid_noop');
        final restored = await repo.restore(id: goalId, now: 0);
        expect(restored.archivedAt, isNull);
        expect(restored.updatedAt, 0);
        expect(restored.createdAt, _now);
        expect(await repo.listActive(), hasLength(1));
        await db.customStatement(
          "CREATE TEMP TRIGGER forbid_noop BEFORE UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'unexpected update'); END",
        );
        expect(
          goalFields(await repo.restore(id: goalId, now: 100)),
          goalFields(restored),
        );
        await db.customStatement('DROP TRIGGER forbid_noop');
      },
  'both reference types independently turn delete into archive': (db) async {
    final repo = DriftGoalRepository(db);
    await repo.create(id: goalId, name: '论文', now: _now);
    await _linkBlock(db);
    await db.customStatement(
      'INSERT INTO rhythm_annotations (id, time_block_id, state, created_at, updated_at) '
      "VALUES (?, ?, 'progress', 30, 30)",
      [goalId, goalId],
    );
    var facts = await _facts(db);
    expect(
      await repo.delete(id: goalId, now: _now + 1),
      GoalDeleteResult.archived,
    );
    expect(await _facts(db), facts);
    expect(await repo.listActive(), isEmpty);
    final archived = (await repo.findById(goalId))!;
    expect(archived.archivedAt, _now + 1);
    expect(
      await repo.delete(id: goalId, now: _now + 99),
      GoalDeleteResult.archived,
    );
    expect(goalFields((await repo.findById(goalId))!), goalFields(archived));
    await repo.rename(id: goalId, name: '更名论文', now: _now + 2);
    expect(await _facts(db), facts);
    await repo.restore(id: goalId, now: _now + 3);
    await _linkReview(db);
    // Both links protect references, then the review alone must also suffice.
    facts = await _facts(db);
    expect(
      await repo.delete(id: goalId, now: _now + 4),
      GoalDeleteResult.archived,
    );
    expect(await _facts(db), facts);
    await db.customStatement(
      'DELETE FROM time_blocks',
    ); // Approved block/annotation cascade.
    await repo.restore(id: goalId, now: _now + 5);
    facts = await _facts(db);
    expect(
      await repo.delete(id: goalId, now: _now + 6),
      GoalDeleteResult.archived,
    );
    expect(await _facts(db), facts);
    expect((await repo.findById(goalId))!.name, '更名论文');
    expect((await repo.findById(goalId))!.archivedAt, _now + 6);
  },
  'unreferenced delete removes only its Goal; missing operations stay explicit':
      (db) async {
        final repo = DriftGoalRepository(db);
        await repo.create(id: goalId, name: '保留目标', now: 1);
        await _linkBlock(db);
        await _linkReview(db);
        await repo.create(id: otherGoalId, name: '删除目标', now: 2);
        final facts = await _facts(db);
        expect(
          await repo.delete(id: otherGoalId, now: 3),
          GoalDeleteResult.deleted,
        );
        expect(await repo.findById(otherGoalId), isNull);
        expect(await _facts(db), facts);
        expect((await repo.findById(goalId))!.status, GoalStatus.active);
        expect(
          await repo.delete(id: otherGoalId, now: 4),
          GoalDeleteResult.notFound,
        );
        for (final operation in [
          () => repo.rename(id: otherGoalId, name: '不存在', now: 5),
          () => repo.archive(id: otherGoalId, now: 5),
          () => repo.restore(id: otherGoalId, now: 5),
        ]) {
          await expectLater(operation(), throwsA(isA<GoalNotFoundException>()));
        }
        expect(await repo.findById(otherGoalId), isNull);
      },
  'failed mutations roll back actual SQLite changes and preserve facts': (db) async {
    final repo = DriftGoalRepository(db);
    final original = await repo.create(id: goalId, name: '论文', now: 1);
    await _linkBlock(db);
    await _linkReview(db);
    final facts = await _facts(db);
    // AFTER + FAIL deliberately leaves the statement's earlier work pending;
    // the repository transaction must roll it back. Foreign keys stay enabled.
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_update AFTER UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'injected failure'); END",
    );
    for (final operation in [
      () => repo.rename(id: goalId, name: '不应提交', now: 2),
      () => repo.archive(id: goalId, now: 2),
      () => repo.delete(id: goalId, now: 2),
    ]) {
      await expectLater(operation(), throwsA(isA<GoalStorageException>()));
      expect(goalFields((await repo.findById(goalId))!), goalFields(original));
      expect(await _facts(db), facts);
    }
    await db.customStatement('DROP TRIGGER fail_update');
    final archived = await repo.archive(id: goalId, now: 3);
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_restore AFTER UPDATE ON goals BEGIN SELECT RAISE(FAIL, 'injected failure'); END",
    );
    await expectLater(
      repo.restore(id: goalId, now: 4),
      throwsA(isA<GoalStorageException>()),
    );
    expect(goalFields((await repo.findById(goalId))!), goalFields(archived));
    await db.customStatement('DROP TRIGGER fail_restore');
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_insert AFTER INSERT ON goals BEGIN SELECT RAISE(FAIL, 'injected failure'); END",
    );
    await expectLater(
      repo.create(id: otherGoalId, name: '失败创建', now: 4),
      throwsA(isA<GoalStorageException>()),
    );
    expect(await repo.findById(otherGoalId), isNull);
    await db.customStatement('DROP TRIGGER fail_insert');
    final other = await repo.create(id: otherGoalId, name: '独立目标', now: 5);
    await db.customStatement(
      "CREATE TEMP TRIGGER fail_delete AFTER DELETE ON goals BEGIN SELECT RAISE(FAIL, 'injected failure'); END",
    );
    await expectLater(
      repo.delete(id: otherGoalId, now: 6),
      throwsA(isA<GoalStorageException>()),
    );
    expect(goalFields((await repo.findById(otherGoalId))!), goalFields(other));
    expect(await _facts(db), facts);
    await db.customStatement('DROP TRIGGER fail_delete');
    expect(
      await repo.delete(id: otherGoalId, now: 7),
      GoalDeleteResult.deleted,
    );
  },
  'concurrent rename and archive read current state inside write transactions':
      (db) async {
        final repo = DriftGoalRepository(db);
        await repo.create(id: goalId, name: '原名', now: 1);
        await Future.wait([
          repo.rename(id: goalId, name: '新名', now: 2),
          repo.archive(id: goalId, now: 3),
        ]);
        final current = (await repo.findById(goalId))!;
        expect(current.name, '新名');
        expect(current.status, GoalStatus.archived);
        expect(current.archivedAt, 3);
        expect(current.createdAt, 1);
      },
  'malformed stored values fail explicitly without rewriting rows': (db) async {
    final repo = DriftGoalRepository(db);
    await repo.create(id: goalId, name: '论文', now: 1);
    for (final invalid in [1.5, 'not-an-integer']) {
      await db.customStatement('UPDATE goals SET created_at = ?', [invalid]);
      await expectLater(
        repo.findById(goalId),
        throwsA(isA<GoalDataException>()),
      );
      await expectLater(repo.listActive(), throwsA(isA<GoalDataException>()));
      await expectLater(
        repo.rename(id: goalId, name: '不能静默修复', now: 2),
        throwsA(isA<GoalDataException>()),
      );
      expect(
        (await db.customSelect('SELECT created_at FROM goals').getSingle())
            .data['created_at'],
        invalid,
      );
    }
    await db.customStatement(
      "UPDATE goals SET created_at = 1, name = '  未规范化  '",
    );
    await expectLater(repo.findById(goalId), throwsA(isA<GoalDataException>()));
    await db.customStatement("UPDATE goals SET name = ''");
    await expectLater(repo.findById(goalId), throwsA(isA<GoalDataException>()));
  },
};
