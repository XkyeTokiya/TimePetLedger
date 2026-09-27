import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/data/goal_mapping.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_repository.dart';

import '../../../../integration_test/support/goal_repository_contract.dart';

void main() {
  for (final check in goalRepositoryChecks.entries) {
    test(check.key, () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await check.value(db);
    });
  }
  test('file reopen preserves every archived Goal field', () async {
    final directory = await Directory.systemTemp.createTemp(
      'goal_repository_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.sqlite');
    final first = await AppDatabase.open(NativeDatabase(file));
    final repo = DriftGoalRepository(first);
    await repo.create(id: goalId, name: '论文', now: 1790467200123);
    await repo.archive(id: goalId, now: 1790467201123);
    final expected = await repo.rename(
      id: goalId,
      name: '更名论文',
      now: 1790467202123,
    );
    await first.close();
    final reopened = await AppDatabase.open(NativeDatabase(file));
    addTearDown(reopened.close);
    final reader = DriftGoalRepository(reopened);
    expect(goalFields((await reader.findById(goalId))!), goalFields(expected));
    expect(await reader.listActive(), isEmpty);
  });
  test('unknown persisted status is a data error, never a default', () {
    expect(
      () => goalFromDatabase({
        'id': goalId,
        'name': '论文',
        'status': 'ACTIVE',
        'created_at': 1,
        'updated_at': 1,
        'archived_at': null,
      }),
      throwsA(isA<GoalDataException>()),
    );
  });
  test(
    'closed connection reports storage failure instead of missing data',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      final repo = DriftGoalRepository(db);
      await db.close();
      await expectLater(
        repo.findById(goalId),
        throwsA(isA<GoalStorageException>()),
      );
      await expectLater(
        repo.create(id: goalId, name: '论文', now: 1),
        throwsA(isA<GoalStorageException>()),
      );
    },
  );
}
