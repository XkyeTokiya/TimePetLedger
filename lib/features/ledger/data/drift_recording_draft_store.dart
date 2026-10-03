import 'package:drift/drift.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/recording_draft_store.dart';
import '../domain/time_precision.dart';
import '../domain/rhythm_state.dart';
import '../domain/rhythm_details.dart';

/// Owns a dedicated draft connection. Never pass the formal AppDatabase executor.
final class DriftRecordingDraftStore implements RecordingDraftStore {
  DriftRecordingDraftStore._(this._database);
  final _RecordingDraftDatabase _database;

  static Future<DriftRecordingDraftStore> open(QueryExecutor executor) async {
    final database = _RecordingDraftDatabase(executor);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftRecordingDraftStore._(database);
    } catch (error, stack) {
      try {
        await database.close();
      } catch (_) {
        // Preserve the opening failure; no usable store is returned.
      }
      Error.throwWithStackTrace(
        RecordingDraftStorageException(RecordingDraftOperation.open, error),
        stack,
      );
    }
  }

  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) =>
      _run(RecordingDraftOperation.read, () async {
        final rows = await _database
            .customSelect(
              'SELECT * FROM recording_drafts WHERE context_key = ?',
              variables: [Variable(_key(context))],
            )
            .get();
        if (rows.isEmpty) return null;
        try {
          final result = _decode(rows.single.data);
          if (_key(result.context) != _key(context)) {
            throw const RecordingDraftDataException();
          }
          return result;
        } catch (_) {
          throw const RecordingDraftDataException();
        }
      });

  @override
  Future<void> save(RecordingDraft draft) =>
      _run(RecordingDraftOperation.save, () async {
        final c = draft.context;
        // One statement is atomic: a failed update retains the previous draft.
        await _database.customStatement(
          '''
INSERT INTO recording_drafts (
 context_key, entry, year, month, day, time_block_id, gap_start, gap_end,
 title, started_at, ended_at, start_precision, end_precision, knowledge_state,
 note, note_provided, goal_id, goal_provided,
 annotation_intent, annotation_id, rhythm_state, continuation_hint, hint_provided,
 stuck_reason_code, stuck_reason_code_provided, stuck_reason_text, stuck_reason_text_provided, recovery_method, recovery_method_provided, recovery_quality, recovery_quality_provided
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(context_key) DO UPDATE SET
 entry=excluded.entry, year=excluded.year, month=excluded.month, day=excluded.day,
 time_block_id=excluded.time_block_id, gap_start=excluded.gap_start,
 gap_end=excluded.gap_end, title=excluded.title, started_at=excluded.started_at,
 ended_at=excluded.ended_at, start_precision=excluded.start_precision,
 end_precision=excluded.end_precision, knowledge_state=excluded.knowledge_state,
 note=excluded.note, note_provided=excluded.note_provided,
 goal_id=excluded.goal_id, goal_provided=excluded.goal_provided,
 annotation_intent=excluded.annotation_intent, annotation_id=excluded.annotation_id,
 rhythm_state=excluded.rhythm_state, continuation_hint=excluded.continuation_hint,
 hint_provided=excluded.hint_provided,
 stuck_reason_code=excluded.stuck_reason_code, stuck_reason_code_provided=excluded.stuck_reason_code_provided,
 stuck_reason_text=excluded.stuck_reason_text, stuck_reason_text_provided=excluded.stuck_reason_text_provided,
 recovery_method=excluded.recovery_method, recovery_method_provided=excluded.recovery_method_provided,
 recovery_quality=excluded.recovery_quality, recovery_quality_provided=excluded.recovery_quality_provided
''',
          [
            _key(c),
            c.entry.name,
            c.date.year,
            c.date.month,
            c.date.day,
            c.timeBlockId,
            c.gapStartedAt,
            c.gapEndedAt,
            draft.title,
            draft.startedAt,
            draft.endedAt,
            draft.startPrecision.name,
            draft.endPrecision.name,
            draft.knowledgeState?.name,
            draft.note,
            draft.noteProvided ? 1 : 0,
            draft.goalId,
            draft.goalProvided ? 1 : 0,
            draft.annotationIntent.name,
            draft.annotationId,
            draft.rhythmState?.name,
            draft.continuationHint,
            draft.hintProvided ? 1 : 0,
            draft.stuckReasonCode?.name,
            draft.stuckReasonCodeProvided ? 1 : 0,
            draft.stuckReasonText,
            draft.stuckReasonTextProvided ? 1 : 0,
            draft.recoveryMethod?.name,
            draft.recoveryMethodProvided ? 1 : 0,
            draft.recoveryQuality?.name,
            draft.recoveryQualityProvided ? 1 : 0,
          ],
        );
      });

  @override
  Future<void> clear(RecordingDraftContext context) => _run(
    RecordingDraftOperation.clear,
    () => _database.customStatement(
      'DELETE FROM recording_drafts WHERE context_key = ?',
      [_key(context)],
    ),
  );

  Future<void> close() => _run(RecordingDraftOperation.close, _database.close);

  Future<T> _run<T>(
    RecordingDraftOperation operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on RecordingDraftDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(
        RecordingDraftStorageException(operation, error),
        stack,
      );
    }
  }
}

String _key(RecordingDraftContext c) => switch (c.entry) {
  RecordingDraftEntry.edit => 'edit:${c.timeBlockId}',
  RecordingDraftEntry.ordinary =>
    'new:${c.date.year}:${c.date.month}:${c.date.day}',
  RecordingDraftEntry.gap =>
    'gap:${c.date.year}:${c.date.month}:${c.date.day}:${c.gapStartedAt}:${c.gapEndedAt}',
};

RecordingDraft _decode(Map<String, Object?> row) {
  final date = CivilDate(
    year: row['year'] as int,
    month: row['month'] as int,
    day: row['day'] as int,
  );
  final entry = RecordingDraftEntry.values.byName(row['entry'] as String);
  final context = switch (entry) {
    RecordingDraftEntry.ordinary => RecordingDraftContext.newEntry(date: date),
    RecordingDraftEntry.gap => RecordingDraftContext.gap(
      date: date,
      startedAt: row['gap_start'] as int,
      endedAt: row['gap_end'] as int,
    ),
    RecordingDraftEntry.edit => RecordingDraftContext.edit(
      date: date,
      timeBlockId: row['time_block_id'] as String,
    ),
  };
  if (row['time_block_id'] != context.timeBlockId ||
      row['gap_start'] != context.gapStartedAt ||
      row['gap_end'] != context.gapEndedAt) {
    throw const RecordingDraftDataException();
  }
  return RecordingDraft(
    context: context,
    title: row['title'] as String?,
    startedAt: row['started_at'] as int?,
    endedAt: row['ended_at'] as int?,
    startPrecision: TimePrecision.values.byName(
      row['start_precision'] as String,
    ),
    endPrecision: TimePrecision.values.byName(row['end_precision'] as String),
    knowledgeState: row['knowledge_state'] == null
        ? null
        : BlockKnowledgeState.values.byName(row['knowledge_state'] as String),
    note: row['note'] as String?,
    noteProvided: (row['note_provided'] as int) == 1,
    goalId: row['goal_id'] == null
        ? null
        : requireUuidV4(row['goal_id'] as String),
    goalProvided: (row['goal_provided'] as int) == 1,
    annotationIntent: RecordingAnnotationIntent.values.byName(
      row['annotation_intent'] as String,
    ),
    annotationId: row['annotation_id'] == null
        ? null
        : requireUuidV4(row['annotation_id'] as String),
    rhythmState: row['rhythm_state'] == null
        ? null
        : RhythmState.values.byName(row['rhythm_state'] as String),
    continuationHint: row['continuation_hint'] as String?,
    hintProvided: (row['hint_provided'] as int) == 1,
    stuckReasonCode: row['stuck_reason_code'] == null
        ? null
        : StuckReasonCode.values.byName(row['stuck_reason_code'] as String),
    stuckReasonCodeProvided: (row['stuck_reason_code_provided'] as int) == 1,
    stuckReasonText: row['stuck_reason_text'] == null
        ? null
        : row['stuck_reason_text'] as String,
    stuckReasonTextProvided: (row['stuck_reason_text_provided'] as int) == 1,
    recoveryMethod: row['recovery_method'] == null
        ? null
        : RecoveryMethod.values.byName(row['recovery_method'] as String),
    recoveryMethodProvided: (row['recovery_method_provided'] as int) == 1,
    recoveryQuality: row['recovery_quality'] == null
        ? null
        : RecoveryQuality.values.byName(row['recovery_quality'] as String),
    recoveryQualityProvided: (row['recovery_quality_provided'] as int) == 1,
  );
}

/// Dedicated SQL-only database, with no generated tables or formal fact schema.
class _RecordingDraftDatabase extends GeneratedDatabase {
  _RecordingDraftDatabase(super.executor);
  @override
  int get schemaVersion => 5;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''
CREATE TABLE recording_drafts (
 context_key TEXT NOT NULL PRIMARY KEY,
 entry TEXT NOT NULL CHECK(entry IN ('ordinary','gap','edit')),
 year INTEGER NOT NULL, month INTEGER NOT NULL, day INTEGER NOT NULL,
 time_block_id TEXT, gap_start INTEGER, gap_end INTEGER,
 title TEXT, started_at INTEGER, ended_at INTEGER,
 start_precision TEXT NOT NULL CHECK(start_precision IN ('exact','approximate')),
 end_precision TEXT NOT NULL CHECK(end_precision IN ('exact','approximate')),
 knowledge_state TEXT CHECK(knowledge_state IN ('known','unknown')),
 note TEXT, note_provided INTEGER NOT NULL DEFAULT 0
   CHECK(note_provided IN (0,1)),
 goal_id TEXT, goal_provided INTEGER NOT NULL DEFAULT 0
   CHECK(goal_provided IN (0,1)),
 annotation_intent TEXT NOT NULL DEFAULT 'keep'
   CHECK(annotation_intent IN ('keep','add','edit','remove')),
 annotation_id TEXT, rhythm_state TEXT
   CHECK(rhythm_state IN ('progress','stuck','recovery')),
 continuation_hint TEXT, hint_provided INTEGER NOT NULL DEFAULT 0
   CHECK(hint_provided IN (0,1)),
 stuck_reason_code TEXT CHECK(stuck_reason_code IN ('taskTooLarge','unclearNextStep','sleepy','brainFog','anxious','interrupted','unsure','other')), stuck_reason_code_provided INTEGER NOT NULL DEFAULT 0 CHECK(stuck_reason_code_provided IN (0,1)),
 stuck_reason_text TEXT, stuck_reason_text_provided INTEGER NOT NULL DEFAULT 0 CHECK(stuck_reason_text_provided IN (0,1)),
 recovery_method TEXT CHECK(recovery_method IN ('walk','meal','shower','empty','entertainment','switchTask','breakDownTask','askForHelp','other')), recovery_method_provided INTEGER NOT NULL DEFAULT 0 CHECK(recovery_method_provided IN (0,1)),
 recovery_quality TEXT CHECK(recovery_quality IN ('notRecovered','partlyRecovered','readyToContinue')), recovery_quality_provided INTEGER NOT NULL DEFAULT 0 CHECK(recovery_quality_provided IN (0,1))
)
'''),
    onUpgrade: (_, from, to) => transaction(() async {
      if (from < 1 || from > 4 || to != 5) {
        throw StateError('Unsupported draft schema: $from -> $to');
      }
      if (from == 1) {
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN note TEXT',
        );
        await customStatement('''
ALTER TABLE recording_drafts ADD COLUMN note_provided INTEGER NOT NULL DEFAULT 0
  CHECK(note_provided IN (0,1))
''');
      }
      if (from <= 2) {
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN goal_id TEXT',
        );
        await customStatement('''
ALTER TABLE recording_drafts ADD COLUMN goal_provided INTEGER NOT NULL DEFAULT 0
  CHECK(goal_provided IN (0,1))
''');
      }
      if (from <= 3) {
        await customStatement('''
ALTER TABLE recording_drafts ADD COLUMN annotation_intent TEXT NOT NULL DEFAULT 'keep'
 CHECK(annotation_intent IN ('keep','add','edit','remove'))
''');
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN annotation_id TEXT',
        );
        await customStatement('''
ALTER TABLE recording_drafts ADD COLUMN rhythm_state TEXT
 CHECK(rhythm_state IN ('progress','stuck','recovery'))
''');
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN continuation_hint TEXT',
        );
        await customStatement('''
ALTER TABLE recording_drafts ADD COLUMN hint_provided INTEGER NOT NULL DEFAULT 0
 CHECK(hint_provided IN (0,1))
''');
      }
      await customStatement(
        "ALTER TABLE recording_drafts ADD COLUMN stuck_reason_code TEXT CHECK(stuck_reason_code IN ('taskTooLarge','unclearNextStep','sleepy','brainFog','anxious','interrupted','unsure','other'))",
      );
      await customStatement(
        'ALTER TABLE recording_drafts ADD COLUMN stuck_reason_code_provided INTEGER NOT NULL DEFAULT 0 CHECK(stuck_reason_code_provided IN (0,1))',
      );
      await customStatement(
        "ALTER TABLE recording_drafts ADD COLUMN stuck_reason_text TEXT",
      );
      await customStatement(
        'ALTER TABLE recording_drafts ADD COLUMN stuck_reason_text_provided INTEGER NOT NULL DEFAULT 0 CHECK(stuck_reason_text_provided IN (0,1))',
      );
      await customStatement(
        "ALTER TABLE recording_drafts ADD COLUMN recovery_method TEXT CHECK(recovery_method IN ('walk','meal','shower','empty','entertainment','switchTask','breakDownTask','askForHelp','other'))",
      );
      await customStatement(
        'ALTER TABLE recording_drafts ADD COLUMN recovery_method_provided INTEGER NOT NULL DEFAULT 0 CHECK(recovery_method_provided IN (0,1))',
      );
      await customStatement(
        "ALTER TABLE recording_drafts ADD COLUMN recovery_quality TEXT CHECK(recovery_quality IN ('notRecovered','partlyRecovered','readyToContinue'))",
      );
      await customStatement(
        'ALTER TABLE recording_drafts ADD COLUMN recovery_quality_provided INTEGER NOT NULL DEFAULT 0 CHECK(recovery_quality_provided IN (0,1))',
      );
    }),
  );
}
