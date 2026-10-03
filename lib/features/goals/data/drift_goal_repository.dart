import 'package:drift/drift.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/time/time_contract.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import 'goal_mapping.dart';

/// Borrows the app-owned database; it neither opens nor closes connections.
final class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this._database);
  final AppDatabase _database;

  @override
  Future<List<Goal>> listActive() => _guard(() async {
    final rows = await _database
        .customSelect(
          "SELECT * FROM goals WHERE status = 'active' ORDER BY id",
          readsFrom: {_database.goals},
        )
        .get();
    return List.unmodifiable(rows.map((row) => goalFromDatabase(row.data)));
  });

  @override
  Future<List<Goal>> listArchived() => _guard(() async {
    final rows = await _database
        .customSelect(
          "SELECT * FROM goals WHERE status = 'archived' ORDER BY id",
          readsFrom: {_database.goals},
        )
        .get();
    return List.unmodifiable(rows.map((row) => goalFromDatabase(row.data)));
  });

  @override
  Future<Goal?> findById(EntityId id) => _guard(() {
    requireUuidV4(id);
    return _find(id);
  });

  Future<Goal?> _find(EntityId id) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM goals WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {_database.goals},
        )
        .getSingleOrNull();
    return row == null ? null : goalFromDatabase(row.data);
  }

  @override
  Future<Goal> create({
    required EntityId id,
    required String name,
    required InstantMilliseconds now,
  }) => _guard(() async {
    final goal = Goal.create(id: id, name: name, now: now);
    return _database.transaction(() async {
      if (await _find(id) != null) throw GoalAlreadyExistsException(id);
      await _database.into(_database.goals).insert(goalToDatabase(goal));
      return goal;
    });
  });

  @override
  Future<Goal> rename({
    required EntityId id,
    required String name,
    required InstantMilliseconds now,
  }) => _change(id, (goal) => goal.rename(name: name, now: now));

  @override
  Future<Goal> archive({
    required EntityId id,
    required InstantMilliseconds now,
  }) => _change(id, (goal) => goal.archive(now: now));

  @override
  Future<Goal> restore({
    required EntityId id,
    required InstantMilliseconds now,
  }) => _change(id, (goal) => goal.restore(now: now));

  Future<Goal> _change(EntityId id, Goal Function(Goal) change) => _guard(() {
    requireUuidV4(id);
    // Drift 2.35 opens an IMMEDIATE write transaction before this read.
    return _database.transaction(() async {
      final current = await _find(id);
      if (current == null) throw GoalNotFoundException(id);
      final next = change(current);
      if (!identical(next, current)) await _update(next);
      return next;
    });
  });

  Future<void> _update(Goal goal) async {
    final columns = goalToDatabase(goal);
    await (_database.update(
      _database.goals,
    )..where((row) => row.id.equals(goal.id))).write(
      GoalsCompanion(
        name: columns.name,
        status: columns.status,
        updatedAt: columns.updatedAt,
        archivedAt: columns.archivedAt,
      ),
    );
  }

  @override
  Future<GoalDeleteResult> delete({
    required EntityId id,
    required InstantMilliseconds now,
  }) => _guard(() {
    requireUuidV4(id);
    return _database.transaction(() async {
      final current = await _find(id);
      if (current == null) return GoalDeleteResult.notFound;
      final references = await _database
          .customSelect(
            'SELECT EXISTS(SELECT 1 FROM time_blocks WHERE goal_id = ?) OR '
            'EXISTS(SELECT 1 FROM daily_reviews WHERE tomorrow_first_step_goal_id = ?) '
            'AS has_references',
            variables: [Variable(id), Variable(id)],
            readsFrom: {_database.timeBlocks, _database.dailyReviews},
          )
          .getSingle();
      if (references.read<int>('has_references') != 0) {
        final archived = current.archive(now: now);
        if (!identical(archived, current)) await _update(archived);
        return GoalDeleteResult.archived;
      }
      await (_database.delete(
        _database.goals,
      )..where((row) => row.id.equals(id))).go();
      return GoalDeleteResult.deleted;
    });
  });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ArgumentError {
      rethrow;
    } on GoalNotFoundException {
      rethrow;
    } on GoalAlreadyExistsException {
      rethrow;
    } on GoalDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(GoalStorageException(error), stack);
    }
  }
}
