import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/time/time_contract.dart';
import '../../../core/identity/entity_id.dart';
import '../../goals/data/goal_mapping.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_repository.dart';
import '../../goals/domain/goal_status.dart';
import '../domain/annotation_change.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/rhythm_annotation.dart';
import '../domain/rhythm_annotation_operations.dart';
import '../domain/sleep_session.dart';
import '../domain/sleep_session_correction.dart';
import '../domain/sleep_type.dart';
import '../domain/time_block.dart';
import '../domain/time_block_correction.dart';
import '../domain/time_precision.dart';
import '../domain/ledger_repository.dart';
import 'ledger_mapping.dart';

/// Borrows the app-owned connection; every mutation uses one write transaction.
final class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(this._database);
  final AppDatabase _database;

  @override
  Future<LedgerSnapshot> readWindow({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  }) async {
    if (startedAt > endedAt) {
      throw ArgumentError('Read window must not be reversed.');
    }
    if (startedAt == endedAt) {
      return LedgerSnapshot(timeBlocks: [], sleepSessions: [], annotations: []);
    }
    try {
      // Drift's current transaction mode is IMMEDIATE. Even though this action
      // only reads, keep one transaction across all queries and full mapping.
      return await _database.transaction(() async {
        return _readWindowFacts(startedAt: startedAt, endedAt: endedAt);
      });
    } on LedgerDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }

  Future<LedgerSnapshot> _readWindowFacts({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  }) async {
    if (startedAt == endedAt) {
      return LedgerSnapshot(timeBlocks: [], sleepSessions: [], annotations: []);
    }
    final bounds = [Variable(endedAt), Variable(startedAt)];
    final blocks = await _database
        .customSelect(
          'SELECT * FROM time_blocks '
          'WHERE started_at < ? AND ended_at > ? ORDER BY started_at, id',
          variables: bounds,
          readsFrom: {_database.timeBlocks},
        )
        .get();
    final sleeps = await _database
        .customSelect(
          'SELECT * FROM sleep_sessions '
          'WHERE started_at < ? AND ended_at > ? ORDER BY started_at, id',
          variables: bounds,
          readsFrom: {_database.sleepSessions},
        )
        .get();
    // Joining the same window avoids an unbounded IN list of block ids.
    final annotations = await _database
        .customSelect(
          'SELECT a.* FROM rhythm_annotations a '
          'JOIN time_blocks t ON t.id = a.time_block_id '
          'WHERE t.started_at < ? AND t.ended_at > ? '
          'ORDER BY t.started_at, t.id',
          variables: bounds,
          readsFrom: {_database.timeBlocks, _database.rhythmAnnotations},
        )
        .get();
    return LedgerSnapshot(
      timeBlocks: blocks.map((row) => timeBlockFromDatabase(row.data)),
      sleepSessions: sleeps.map((row) => sleepSessionFromDatabase(row.data)),
      annotations: annotations.map(
        (row) => rhythmAnnotationFromDatabase(row.data),
      ),
    );
  }

  @override
  Future<SleepLedgerSnapshot> readSleepContext({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required InstantMilliseconds dayStartedAt,
    required InstantMilliseconds nextDayStartedAt,
  }) async {
    intervalMilliseconds(startedAt: dayStartedAt, endedAt: nextDayStartedAt);
    if (startedAt > endedAt ||
        startedAt < dayStartedAt ||
        endedAt > nextDayStartedAt) {
      throw ArgumentError('Read window must be within the supplied day.');
    }
    try {
      return await _database.transaction(() async {
        // Both reads use this transaction, including mapping all candidates.
        // An empty W does not skip the summary query.
        final facts = await _readWindowFacts(
          startedAt: startedAt,
          endedAt: endedAt,
        );
        final rows = await _database
            .customSelect(
              'SELECT * FROM sleep_sessions '
              'WHERE ended_at >= ? AND ended_at < ? ORDER BY started_at, id',
              variables: [Variable(dayStartedAt), Variable(nextDayStartedAt)],
              readsFrom: {_database.sleepSessions},
            )
            .get();
        return SleepLedgerSnapshot(
          windowFacts: facts,
          sleepSummaryCandidates: rows.map(
            (row) => sleepSessionFromDatabase(row.data),
          ),
        );
      });
    } on LedgerDataException {
      rethrow;
    } on LedgerStorageException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }

  @override
  Future<TimeBlockWriteResult?> readTimeBlock(EntityId id) async {
    requireUuidV4(id);
    try {
      return await _database.transaction(() async {
        final block = await _block(id);
        if (block == null) return null;
        return (timeBlock: block, annotation: await _annotation(id));
      });
    } on LedgerDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }

  @override
  Future<SleepSession?> readSleepSession(EntityId id) async {
    requireUuidV4(id);
    try {
      return await _database.transaction(() => _sleep(id));
    } on LedgerDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }

  @override
  Future<TimeBlockWriteResult> createTimeBlock({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required BlockKnowledgeState knowledgeState,
    required InstantMilliseconds now,
    String? title,
    EntityId? goalId,
    String? categoryId,
    String? note,
    AddAnnotation? annotation,
  }) => _write(() async {
    final block = TimeBlock(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      knowledgeState: knowledgeState,
      title: title,
      goalId: goalId,
      categoryId: categoryId,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    if (await _block(id) != null) {
      throw LedgerFactAlreadyExistsException((
        type: LedgerFactType.timeBlock,
        id: id,
      ));
    }
    final goal = await _goal(goalId);
    _validateNewGoal(goalId, goal);
    final interval = LedgerFactInterval.fromTimeBlock(block);
    final conflicts = findLedgerConflicts(
      candidate: interval,
      existing: await _intervals(startedAt, endedAt),
    );
    if (conflicts.isNotEmpty) throw LedgerConflictException(conflicts);
    final explained = _applyAnnotation(
      block,
      null,
      goal,
      annotation ?? const KeepAnnotation(),
      now,
    );
    await _database
        .into(_database.timeBlocks)
        .insert(timeBlockToDatabase(block));
    if (explained.annotation case final a?) {
      await _database
          .into(_database.rhythmAnnotations)
          .insert(rhythmAnnotationToDatabase(a));
    }
    return (timeBlock: block, annotation: explained.annotation);
  });

  @override
  Future<TimeBlockWriteResult> updateTimeBlock({
    required EntityId id,
    required InstantMilliseconds now,
    InstantMilliseconds? startedAt,
    InstantMilliseconds? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    BlockKnowledgeState? knowledgeState,
    ({String? value})? title,
    ({EntityId? value})? goalId,
    ({String? value})? categoryId,
    ({String? value})? note,
    AnnotationChange annotation = const KeepAnnotation(),
  }) => _write(() async {
    requireUuidV4(id);
    final original = await _block(id);
    if (original == null) {
      throw LedgerFactNotFoundException((
        type: LedgerFactType.timeBlock,
        id: id,
      ));
    }
    final existing = await _annotation(id);
    final goal = await _goal(goalId == null ? original.goalId : goalId.value);
    final corrected = correctTimeBlock(
      original: original,
      annotation: existing,
      goal: goal,
      existing: await _intervals(
        startedAt ?? original.startedAt,
        endedAt ?? original.endedAt,
      ),
      now: now,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      knowledgeState: knowledgeState,
      title: title,
      goalId: goalId,
      categoryId: categoryId,
      note: note,
    );
    final explained = _applyAnnotation(
      corrected.timeBlock,
      existing,
      goal,
      annotation,
      now,
    );
    if (corrected.changed) {
      await (_database.update(_database.timeBlocks)
            ..where((row) => row.id.equals(id)))
          .write(timeBlockToDatabase(corrected.timeBlock));
    }
    if (explained.changed) {
      final next = explained.annotation;
      if (next == null) {
        await (_database.delete(
          _database.rhythmAnnotations,
        )..where((row) => row.timeBlockId.equals(id))).go();
      } else if (existing == null) {
        await _database
            .into(_database.rhythmAnnotations)
            .insert(rhythmAnnotationToDatabase(next));
      } else {
        await (_database.update(_database.rhythmAnnotations)
              ..where((row) => row.timeBlockId.equals(id)))
            .write(rhythmAnnotationToDatabase(next));
      }
    }
    return (timeBlock: corrected.timeBlock, annotation: explained.annotation);
  });

  @override
  Future<SleepSession> createSleepSession({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required SleepType type,
    required InstantMilliseconds now,
    String? note,
  }) => _write(() async {
    final sleep = SleepSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: type,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    if (await _sleep(id) != null) {
      throw LedgerFactAlreadyExistsException((
        type: LedgerFactType.sleepSession,
        id: id,
      ));
    }
    final conflicts = findLedgerConflicts(
      candidate: LedgerFactInterval.fromSleepSession(sleep),
      existing: await _intervals(startedAt, endedAt),
    );
    if (conflicts.isNotEmpty) throw LedgerConflictException(conflicts);
    await _database
        .into(_database.sleepSessions)
        .insert(sleepSessionToDatabase(sleep));
    return sleep;
  });

  @override
  Future<SleepSession> updateSleepSession({
    required EntityId id,
    required InstantMilliseconds now,
    InstantMilliseconds? startedAt,
    InstantMilliseconds? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    SleepType? type,
    ({String? value})? note,
  }) => _write(() async {
    requireUuidV4(id);
    final original = await _sleep(id);
    if (original == null) {
      throw LedgerFactNotFoundException((
        type: LedgerFactType.sleepSession,
        id: id,
      ));
    }
    final result = correctSleepSession(
      original: original,
      existing: await _intervals(
        startedAt ?? original.startedAt,
        endedAt ?? original.endedAt,
      ),
      now: now,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: type,
      note: note,
    );
    if (result.changed) {
      await (_database.update(_database.sleepSessions)
            ..where((row) => row.id.equals(id)))
          .write(sleepSessionToDatabase(result.sleepSession));
    }
    return result.sleepSession;
  });

  @override
  Future<void> deleteTimeBlock(EntityId id) => _write(() async {
    requireUuidV4(id);
    // The approved FK cascade removes only this block's annotation.
    await (_database.delete(
      _database.timeBlocks,
    )..where((row) => row.id.equals(id))).go();
  });

  @override
  Future<void> deleteSleepSession(EntityId id) => _write(() async {
    requireUuidV4(id);
    await (_database.delete(
      _database.sleepSessions,
    )..where((row) => row.id.equals(id))).go();
  });

  RhythmAnnotationOperationResult _applyAnnotation(
    TimeBlock block,
    RhythmAnnotation? existing,
    Goal? goal,
    AnnotationChange change,
    int now,
  ) {
    switch (change) {
      case KeepAnnotation():
        return (timeBlock: block, annotation: existing, changed: false);
      case AddAnnotation():
        if (existing != null) {
          throw const LedgerAnnotationOperationException(
            AnnotationOperationFailure.alreadyExists,
          );
        }
        return addRhythmAnnotation(
          timeBlock: block,
          existing: existing,
          goal: goal,
          id: change.id,
          state: change.state,
          now: now,
          stuckReasonCode: change.stuckReasonCode,
          stuckReasonText: change.stuckReasonText,
          recoveryMethod: change.recoveryMethod,
          recoveryQuality: change.recoveryQuality,
          continuationHint: change.continuationHint,
        );
      case EditAnnotation():
        if (existing == null) {
          throw const LedgerAnnotationOperationException(
            AnnotationOperationFailure.notFound,
          );
        }
        return editRhythmAnnotation(
          timeBlock: block,
          existing: existing,
          goal: goal,
          now: now,
          state: change.state,
          stuckReasonCode: change.stuckReasonCode,
          stuckReasonText: change.stuckReasonText,
          recoveryMethod: change.recoveryMethod,
          recoveryQuality: change.recoveryQuality,
          continuationHint: change.continuationHint,
        );
      case RemoveAnnotation():
        return removeRhythmAnnotation(timeBlock: block, existing: existing);
    }
  }

  Future<TimeBlock?> _block(EntityId id) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM time_blocks WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {_database.timeBlocks},
        )
        .getSingleOrNull();
    return row == null ? null : timeBlockFromDatabase(row.data);
  }

  Future<SleepSession?> _sleep(EntityId id) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM sleep_sessions WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {_database.sleepSessions},
        )
        .getSingleOrNull();
    return row == null ? null : sleepSessionFromDatabase(row.data);
  }

  Future<RhythmAnnotation?> _annotation(EntityId blockId) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM rhythm_annotations WHERE time_block_id = ?',
          variables: [Variable(blockId)],
          readsFrom: {_database.rhythmAnnotations},
        )
        .getSingleOrNull();
    return row == null ? null : rhythmAnnotationFromDatabase(row.data);
  }

  Future<Goal?> _goal(EntityId? id) async {
    if (id == null) return null;
    final row = await _database
        .customSelect(
          'SELECT * FROM goals WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {_database.goals},
        )
        .getSingleOrNull();
    try {
      return row == null ? null : goalFromDatabase(row.data);
    } on GoalDataException {
      throw const LedgerDataException('goals', 'domain');
    }
  }

  void _validateNewGoal(EntityId? id, Goal? goal) {
    if (id == null) return;
    if (goal == null || goal.id != id || goal.status != GoalStatus.active) {
      throw ArgumentError.value(
        id,
        'goalId',
        'New association requires an active Goal',
      );
    }
  }

  Future<List<LedgerFactInterval>> _intervals(int start, int end) async {
    final bounds = [Variable(end), Variable(start)];
    final blocks = await _database
        .customSelect(
          'SELECT * FROM time_blocks WHERE started_at < ? AND ended_at > ?',
          variables: bounds,
          readsFrom: {_database.timeBlocks},
        )
        .get();
    final sleeps = await _database
        .customSelect(
          'SELECT * FROM sleep_sessions WHERE started_at < ? AND ended_at > ?',
          variables: bounds,
          readsFrom: {_database.sleepSessions},
        )
        .get();
    return [
      for (final row in blocks)
        LedgerFactInterval.fromTimeBlock(timeBlockFromDatabase(row.data)),
      for (final row in sleeps)
        LedgerFactInterval.fromSleepSession(sleepSessionFromDatabase(row.data)),
    ];
  }

  Future<T> _write<T>(Future<T> Function() operation) async {
    try {
      // Acquires the IMMEDIATE transaction before any fact / Goal / conflict read.
      return await _database.transaction(operation);
    } on TimeBlockCorrectionConflict catch (error) {
      throw LedgerConflictException(error.conflicts);
    } on SleepSessionCorrectionConflict catch (error) {
      throw LedgerConflictException(error.conflicts);
    } on LedgerConflictException {
      rethrow;
    } on LedgerFactNotFoundException {
      rethrow;
    } on LedgerFactAlreadyExistsException {
      rethrow;
    } on LedgerAnnotationOperationException {
      rethrow;
    } on LedgerDataException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }
}
