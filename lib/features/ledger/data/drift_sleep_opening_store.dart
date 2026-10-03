import 'package:drift/drift.dart';

import '../../../core/time/civil_date.dart';
import '../domain/sleep_opening_store.dart';

/// Owns a separately named interaction-state connection, not the formal ledger.
final class DriftSleepOpeningStore implements SleepOpeningStore {
  DriftSleepOpeningStore._(this._database);
  final _SleepOpeningDatabase _database;

  static Future<DriftSleepOpeningStore> open(QueryExecutor executor) async {
    final database = _SleepOpeningDatabase(executor);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftSleepOpeningStore._(database);
    } catch (error, stack) {
      try {
        await database.close();
      } catch (_) {
        // Preserve the opening failure.
      }
      Error.throwWithStackTrace(SleepOpeningStorageException(error), stack);
    }
  }

  @override
  Future<bool> claim(CivilDate date) async {
    try {
      final changed = await _database.customUpdate(
        'INSERT OR IGNORE INTO sleep_openings (year, month, day) VALUES (?, ?, ?)',
        variables: [
          Variable(date.year),
          Variable(date.month),
          Variable(date.day),
        ],
      );
      return changed == 1;
    } catch (error, stack) {
      Error.throwWithStackTrace(SleepOpeningStorageException(error), stack);
    }
  }

  Future<void> close() => _database.close();
}

class _SleepOpeningDatabase extends GeneratedDatabase {
  _SleepOpeningDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''
CREATE TABLE sleep_openings (
 year INTEGER NOT NULL, month INTEGER NOT NULL, day INTEGER NOT NULL,
 PRIMARY KEY (year, month, day)
)
'''),
    onUpgrade: (_, from, to) =>
        throw StateError('Unsupported sleep opening schema: $from -> $to'),
  );
}
