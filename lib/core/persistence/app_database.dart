import 'package:drift/drift.dart';

import '../../features/goals/data/goals_table.dart';
import '../../features/ledger/data/rhythm_annotations_table.dart';
import '../../features/ledger/data/sleep_sessions_table.dart';
import '../../features/ledger/data/time_blocks_table.dart';
import '../../features/review/data/daily_reviews_table.dart';

part 'app_database.g.dart';

/// Shared connection; business table definitions remain in feature/data.
@DriftDatabase(
  tables: [Goals, TimeBlocks, RhythmAnnotations, SleepSessions, DailyReviews],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  static Future<AppDatabase> open(QueryExecutor executor) async {
    final database = AppDatabase._(executor);
    try {
      // Drift opens lazily. Do not report success before connection setup runs.
      await database.customSelect('SELECT 1').getSingle();
      return database;
    } catch (error, stackTrace) {
      Object? cleanupError;
      try {
        await database.close();
      } catch (error) {
        cleanupError = error;
      }
      Error.throwWithStackTrace(
        DatabaseOpenException(error, cleanupError: cleanupError),
        stackTrace,
      );
    }
  }

  // Version 1 was the empty E2-T02 infrastructure database.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(migrator.createAll),
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Unsupported database version change: $from -> $to');
      }
      await transaction(migrator.createAll);
    },
    beforeOpen: (_) async {
      // Runs outside migration / business transactions, for each connection.
      await customStatement('PRAGMA foreign_keys = ON');
      final result = await customSelect('PRAGMA foreign_keys').getSingle();
      if (result.read<int>('foreign_keys') != 1) {
        throw StateError('SQLite foreign key enforcement is unavailable.');
      }
    },
  );
}

/// Retains diagnostics for the caller without exposing SQL details to the UI.
class DatabaseOpenException implements Exception {
  const DatabaseOpenException(this.cause, {this.cleanupError});

  final Object cause;
  final Object? cleanupError;

  @override
  String toString() => 'Unable to open local storage.';
}
