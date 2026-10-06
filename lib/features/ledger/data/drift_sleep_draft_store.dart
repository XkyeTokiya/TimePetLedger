import 'package:drift/drift.dart';

import '../../../core/time/civil_date.dart';
import '../domain/sleep_draft_store.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';

/// Owns a dedicated sleep-draft executor, never a formal/ordinary-draft connection.
final class DriftSleepDraftStore implements SleepDraftStore {
  DriftSleepDraftStore._(this._database);
  final _SleepDraftDatabase _database;

  static Future<DriftSleepDraftStore> open(QueryExecutor executor) async {
    final database = _SleepDraftDatabase(executor);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftSleepDraftStore._(database);
    } catch (error, stack) {
      try {
        await database.close();
      } catch (_) {
        // Retain the opening failure.
      }
      Error.throwWithStackTrace(
        SleepDraftStorageException(SleepDraftOperation.open, error),
        stack,
      );
    }
  }

  @override
  Future<SleepDraft?> read(SleepDraftContext context) =>
      _run(SleepDraftOperation.read, () async {
        final rows = await _database
            .customSelect(
              'SELECT * FROM sleep_drafts WHERE context_key = ?',
              variables: [Variable(_key(context))],
            )
            .get();
        if (rows.isEmpty) return null;
        try {
          final result = _decode(rows.single.data);
          if (_key(result.context) != _key(context)) {
            throw const SleepDraftDataException();
          }
          return result;
        } catch (_) {
          throw const SleepDraftDataException();
        }
      });

  @override
  Future<void> save(SleepDraft draft) =>
      _run(SleepDraftOperation.save, () async {
        final c = draft.context;
        // One atomic statement; failure leaves the preceding committed draft intact.
        await _database.customStatement(
          '''
INSERT INTO sleep_drafts (
 context_key, year, month, day, sleep_session_id, started_at, ended_at,
 start_precision, end_precision, sleep_type, started_at_input, ended_at_input,
 note, note_provided
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(context_key) DO UPDATE SET
 year=excluded.year, month=excluded.month, day=excluded.day,
 sleep_session_id=excluded.sleep_session_id, started_at=excluded.started_at,
 ended_at=excluded.ended_at, start_precision=excluded.start_precision,
 end_precision=excluded.end_precision, sleep_type=excluded.sleep_type,
 started_at_input=excluded.started_at_input, ended_at_input=excluded.ended_at_input,
 note=excluded.note, note_provided=excluded.note_provided
''',
          [
            _key(c),
            c.date.year,
            c.date.month,
            c.date.day,
            c.sleepSessionId,
            draft.startedAt,
            draft.endedAt,
            draft.startPrecision?.name,
            draft.endPrecision?.name,
            draft.type?.name,
            draft.startedAtInput,
            draft.endedAtInput,
            draft.note,
            draft.noteProvided ? 1 : 0,
          ],
        );
      });

  @override
  Future<void> clear(SleepDraftContext context) => _run(
    SleepDraftOperation.clear,
    () => _database.customStatement(
      'DELETE FROM sleep_drafts WHERE context_key = ?',
      [_key(context)],
    ),
  );

  Future<void> close() => _run(SleepDraftOperation.close, _database.close);

  /// 高级设置数据概况：现存草稿数（Q-034）。
  Future<int> countAll() => _run(SleepDraftOperation.read, () async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS c FROM sleep_drafts')
        .getSingle();
    return row.read<int>('c');
  });

  /// 高级设置清空：删除全部草稿，不影响正式事实。
  Future<void> clearAll() => _run(
    SleepDraftOperation.clear,
    () => _database.customStatement('DELETE FROM sleep_drafts'),
  );

  Future<T> _run<T>(
    SleepDraftOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on SleepDraftDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(
        SleepDraftStorageException(operation, error),
        stack,
      );
    }
  }
}

String _key(SleepDraftContext context) => context.isEditing
    ? 'edit:${context.sleepSessionId}'
    : 'new:${context.date.year}:${context.date.month}:${context.date.day}';

SleepDraft _decode(Map<String, Object?> row) {
  final date = CivilDate(
    year: row['year'] as int,
    month: row['month'] as int,
    day: row['day'] as int,
  );
  final id = row['sleep_session_id'] as String?;
  return SleepDraft(
    context: id == null
        ? SleepDraftContext.newEntry(date: date)
        : SleepDraftContext.edit(date: date, sleepSessionId: id),
    startedAt: row['started_at'] as int?,
    endedAt: row['ended_at'] as int?,
    startPrecision: row['start_precision'] == null
        ? null
        : TimePrecision.values.byName(row['start_precision'] as String),
    endPrecision: row['end_precision'] == null
        ? null
        : TimePrecision.values.byName(row['end_precision'] as String),
    type: row['sleep_type'] == null
        ? null
        : SleepType.values.byName(row['sleep_type'] as String),
    startedAtInput: row['started_at_input'] as String?,
    endedAtInput: row['ended_at_input'] as String?,
    note: row['note'] as String?,
    noteProvided: switch (row['note_provided']) {
      0 => false,
      1 => true,
      _ => throw const SleepDraftDataException(),
    },
  );
}

class _SleepDraftDatabase extends GeneratedDatabase {
  _SleepDraftDatabase(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''
CREATE TABLE sleep_drafts (
 context_key TEXT NOT NULL PRIMARY KEY,
 year INTEGER NOT NULL, month INTEGER NOT NULL, day INTEGER NOT NULL,
 sleep_session_id TEXT, started_at INTEGER, ended_at INTEGER,
 start_precision TEXT CHECK(start_precision IN ('exact','approximate')),
 end_precision TEXT CHECK(end_precision IN ('exact','approximate')),
 sleep_type TEXT CHECK(sleep_type IN ('mainSleep','nap')),
 started_at_input TEXT, ended_at_input TEXT,
 note TEXT, note_provided INTEGER NOT NULL DEFAULT 0 CHECK(note_provided IN (0,1))
)
'''),
    onUpgrade: (_, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Unsupported sleep draft schema: $from -> $to');
      }
      await transaction(() async {
        await customStatement('ALTER TABLE sleep_drafts ADD COLUMN note TEXT');
        await customStatement('''
ALTER TABLE sleep_drafts ADD COLUMN note_provided INTEGER NOT NULL DEFAULT 0
  CHECK(note_provided IN (0,1))
''');
      });
    },
  );
}
