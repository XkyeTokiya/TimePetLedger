import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_repository.dart';
import 'ledger_mapping.dart';

/// Borrows the app-owned connection; no write API is exposed by E2-T05.
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
          sleepSessions: sleeps.map(
            (row) => sleepSessionFromDatabase(row.data),
          ),
          annotations: annotations.map(
            (row) => rhythmAnnotationFromDatabase(row.data),
          ),
        );
      });
    } on LedgerDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(LedgerStorageException(error), stack);
    }
  }
}
