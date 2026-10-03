import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_repository.dart';

const firstId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const activeId = '00000000-0000-4000-8000-000000000003';

void main() {
  test(
    'archived management query keeps same-name identities and excludes active',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftGoalRepository(db);
      expect(await repo.listArchived(), isEmpty);
      for (final id in [firstId, secondId, activeId]) {
        await repo.create(id: id, name: '同名', now: 1);
      }
      await repo.archive(id: firstId, now: 2);
      await repo.archive(id: secondId, now: 3);
      final archived = await repo.listArchived();
      expect(archived.map((g) => g.id), [firstId, secondId]);
      expect(archived.map((g) => g.name), everyElement('同名'));
      expect(archived.map((g) => g.createdAt), everyElement(1));
      expect(archived.map((g) => g.updatedAt), [2, 3]);
      expect(archived.map((g) => g.archivedAt), [2, 3]);
      expect((await repo.listActive()).single.id, activeId);
      await repo.restore(id: firstId, now: 4);
      expect((await repo.listArchived()).single.id, secondId);
      expect((await repo.listActive()).map((g) => g.id), [firstId, activeId]);
    },
  );

  test(
    'archived data/read failures are explicit and never an empty result',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      final repo = DriftGoalRepository(db);
      try {
        await repo.create(id: firstId, name: '目标', now: 1);
        await repo.archive(id: firstId, now: 2);
        await db.customStatement("UPDATE goals SET name = '' WHERE id = ?", [
          firstId,
        ]);
        await expectLater(
          repo.listArchived(),
          throwsA(isA<GoalDataException>()),
        );
      } finally {
        await db.close();
      }
      await expectLater(
        repo.listArchived(),
        throwsA(isA<GoalStorageException>()),
      );
    },
  );
}
