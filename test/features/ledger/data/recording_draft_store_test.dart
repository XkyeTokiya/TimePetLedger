import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

const id = '00000000-0000-4000-8000-000000000001';
const otherId = '00000000-0000-4000-8000-000000000002';
final date = CivilDate(year: 2026, month: 9, day: 28);
final ordinary = RecordingDraftContext.newEntry(date: date);

RecordingDraft draft(
  RecordingDraftContext context, {
  String? title = '  未完成\n输入 🐾  ',
  int? start,
  int? end,
  BlockKnowledgeState? state,
  String? note,
  bool noteProvided = false,
}) => RecordingDraft(
  context: context,
  title: title,
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.approximate,
  knowledgeState: state,
  note: note,
  noteProvided: noteProvided,
);
List<Object?> fields(RecordingDraft d) => [
  d.context.entry,
  d.context.date,
  d.context.timeBlockId,
  d.context.gapStartedAt,
  d.context.gapEndedAt,
  d.title,
  d.startedAt,
  d.endedAt,
  d.startPrecision,
  d.endPrecision,
  d.knowledgeState,
  d.note,
  d.noteProvided,
  d.goalId,
  d.goalProvided,
  d.annotationIntent,
  d.annotationId,
  d.rhythmState,
  d.continuationHint,
  d.hintProvided,
  d.stuckReasonCode,
  d.stuckReasonCodeProvided,
  d.stuckReasonText,
  d.stuckReasonTextProvided,
  d.recoveryMethod,
  d.recoveryMethodProvided,
  d.recoveryQuality,
  d.recoveryQualityProvided,
];
Matcher storageFailure(RecordingDraftOperation operation) => throwsA(
  isA<RecordingDraftStorageException>().having(
    (e) => e.operation,
    'operation',
    operation,
  ),
);
Future<Directory> directory() async {
  final d = await Directory.systemTemp.createTemp('recording_draft_test_');
  addTearDown(() => d.delete(recursive: true));
  return d;
}

Future<void> _mutate(File file, Future<void> Function(_SqlProbe) action) async {
  final db = _SqlProbe(NativeDatabase(file));
  try {
    await action(db);
  } finally {
    await db.close();
  }
}

void main() {
  test('durable reopen preserves incomplete raw input and isolated create/edit contexts', () async {
    final dir = await directory();
    final file = File('${dir.path}/drafts.sqlite');
    final contexts = [
      ordinary,
      RecordingDraftContext.newEntry(
        date: CivilDate(year: 2026, month: 9, day: 29),
      ),
      RecordingDraftContext.gap(date: date, startedAt: 10, endedAt: 20),
      RecordingDraftContext.gap(date: date, startedAt: 20, endedAt: 30),
      RecordingDraftContext.edit(date: date, timeBlockId: id),
      RecordingDraftContext.edit(date: date, timeBlockId: otherId),
    ];
    final inputs = [
      draft(contexts[0], start: 15, note: '  原样\n备注 🐾  ', noteProvided: true),
      draft(contexts[1], title: null, end: 25),
      draft(
        contexts[2],
        title: '',
        start: 99,
        end: 1,
        state: BlockKnowledgeState.known,
      ),
      draft(contexts[3], title: ' ' * 250, start: 5, end: 5),
      draft(
        contexts[4],
        start: 0,
        end: 100,
        state: BlockKnowledgeState.unknown,
      ),
      draft(contexts[5], title: '另一条编辑'),
    ];
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect(await store.read(ordinary), isNull);
      for (final input in inputs) {
        await store.save(input);
      }
    } finally {
      await store.close();
    }
    expect(await file.length(), greaterThan(0));
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      for (final input in inputs) {
        expect(fields((await store.read(input.context))!), fields(input));
      }
      // Edit identity is stable when opened from another date; saved entry date survives.
      final otherDate = RecordingDraftContext.edit(
        date: CivilDate(year: 2026, month: 10, day: 1),
        timeBlockId: id,
      );
      expect(fields((await store.read(otherDate))!), fields(inputs[4]));
      await store.clear(contexts[2]);
      await store.clear(contexts[2]);
      await store.save(draft(ordinary, title: '替换当前新建输入', end: 88));
    } finally {
      await store.close();
    }
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect(await store.read(contexts[2]), isNull);
      expect((await store.read(ordinary))!.title, '替换当前新建输入');
      for (final i in [1, 3, 4, 5]) {
        expect(fields((await store.read(contexts[i]))!), fields(inputs[i]));
      }
    } finally {
      await store.close();
    }
  });

  test('v1 draft upgrades in place without losing incomplete input', () async {
    final dir = await directory();
    final file = File('${dir.path}/drafts.sqlite');
    await _mutate(file, (db) async {
      await db.customStatement('''
CREATE TABLE recording_drafts (
 context_key TEXT NOT NULL PRIMARY KEY,
 entry TEXT NOT NULL, year INTEGER NOT NULL, month INTEGER NOT NULL,
 day INTEGER NOT NULL, time_block_id TEXT, gap_start INTEGER, gap_end INTEGER,
 title TEXT, started_at INTEGER, ended_at INTEGER,
 start_precision TEXT NOT NULL, end_precision TEXT NOT NULL,
 knowledge_state TEXT
)
''');
      await db.customStatement('''
INSERT INTO recording_drafts VALUES (
 'new:2026:9:28', 'ordinary', 2026, 9, 28, NULL, NULL, NULL,
 '旧输入', 10, NULL, 'exact', 'approximate', 'known'
)
''');
      await db.customStatement('''
INSERT INTO recording_drafts VALUES (
 'edit:$id', 'edit', 2026, 9, 28, '$id', NULL, NULL,
 '旧编辑', 10, 20, 'exact', 'approximate', 'known'
)
''');
      await db.customStatement('PRAGMA user_version = 1');
    });
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    final old = (await store.read(ordinary))!;
    expect(old.title, '旧输入');
    expect(old.endedAt, isNull);
    expect(old.note, isNull);
    expect(old.noteProvided, isFalse);
    final oldEdit = (await store.read(
      RecordingDraftContext.edit(date: date, timeBlockId: id),
    ))!;
    expect(oldEdit.title, '旧编辑');
    expect(oldEdit.noteProvided, isFalse);
    await store.save(
      draft(ordinary, title: '旧输入', note: '  后补\n备注  ', noteProvided: true),
    );
    await store.close();
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect((await store.read(ordinary))!.note, '  后补\n备注  ');
      expect((await store.read(ordinary))!.noteProvided, isTrue);
    } finally {
      await store.close();
    }
  });

  test('draft writes, reads and clear leave all five populated fact tables unchanged', () async {
    final dir = await directory();
    final db = await AppDatabase.open(
      NativeDatabase(File('${dir.path}/facts.sqlite')),
    );
    addTearDown(db.close);
    final ledger = DriftLedgerRepository(db);
    await DriftGoalRepository(db).create(id: id, name: '目标', now: 1);
    await ledger.createTimeBlock(
      id: id,
      startedAt: 10,
      endedAt: 20,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
      knowledgeState: BlockKnowledgeState.known,
      title: '原记录',
      goalId: id,
      note: '保留正式备注',
      now: 1,
      annotation: const AddAnnotation(id: id, state: RhythmState.progress),
    );
    await ledger.createSleepSession(
      id: id,
      startedAt: 0,
      endedAt: 10,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 1,
    );
    await DriftReviewRepository(db)
        .create(id: id, date: date, tomorrowFirstStepText: '下一步', now: 1);
    final before = await snapshot(db);
    final file = File('${dir.path}/drafts.sqlite');
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    final edit = RecordingDraftContext.edit(date: date, timeBlockId: id);
    try {
      await store.save(draft(edit, title: '未提交更正', start: 0, end: 200));
      await store.save(draft(ordinary, start: 20, end: 200));
      expect(await snapshot(db), before);
      final facts = await ledger.readWindow(startedAt: 0, endedAt: 200);
      expect(facts.timeBlocks.single.title, '原记录');
      expect(facts.timeBlocks.single.endedAt, 20);
      // A formal write overlapping only a draft succeeds: drafts are not conflict facts.
      await ledger.createTimeBlock(
        id: otherId,
        startedAt: 20,
        endedAt: 30,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        now: 2,
      );
      await ledger.deleteTimeBlock(otherId);
      expect(await snapshot(db), before);
      // Existing real facts still cause a conflict regardless of drafts.
      await expectLater(
        ledger.createTimeBlock(
          id: otherId,
          startedAt: 5,
          endedAt: 15,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.unknown,
          now: 2,
        ),
        throwsA(isA<LedgerConflictException>()),
      );
    } finally {
      await store.close();
    }
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect((await store.read(edit))!.title, '未提交更正');
      await store.clear(edit);
      await store.clear(ordinary);
      expect(await snapshot(db), before);
    } finally {
      await store.close();
    }
    await _mutate(file, (probe) async {
      final tables = await probe
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      expect(tables.map((r) => r.data['name']), ['recording_drafts']);
    });
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name='recording_drafts'",
          )
          .get(),
      isEmpty,
    );
  });

  test('real SQLite write and clear errors preserve last committed draft across reopen', () async {
    final dir = await directory();
    final file = File('${dir.path}/drafts.sqlite');
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    await store.save(draft(ordinary));
    await store.close();
    await _mutate(file, (db) async {
      await db.customStatement(
        "CREATE TRIGGER reject_save AFTER UPDATE ON recording_drafts BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await db.customStatement(
        "CREATE TRIGGER reject_clear AFTER DELETE ON recording_drafts BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
    });
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      await expectLater(
        store.save(draft(ordinary, title: '不应覆盖')),
        storageFailure(RecordingDraftOperation.save),
      );
      await expectLater(
        store.clear(ordinary),
        storageFailure(RecordingDraftOperation.clear),
      );
      expect(fields((await store.read(ordinary))!), fields(draft(ordinary)));
    } finally {
      await store.close();
    }
    await _mutate(file, (db) async {
      await db.customStatement('DROP TRIGGER reject_save');
      await db.customStatement('DROP TRIGGER reject_clear');
    });
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect(fields((await store.read(ordinary))!), fields(draft(ordinary)));
      await store.clear(ordinary);
    } finally {
      await store.close();
    }
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    try {
      expect(await store.read(ordinary), isNull);
    } finally {
      await store.close();
    }
  });

  test('closed connection read/save/clear fail explicitly rather than missing/success', () async {
    final dir = await directory();
    final store = await DriftRecordingDraftStore.open(
      NativeDatabase(File('${dir.path}/drafts.sqlite')),
    );
    await store.close();
    await expectLater(
      store.read(ordinary),
      storageFailure(RecordingDraftOperation.read),
    );
    await expectLater(
      store.save(draft(ordinary)),
      storageFailure(RecordingDraftOperation.save),
    );
    await expectLater(
      store.clear(ordinary),
      storageFailure(RecordingDraftOperation.clear),
    );
  });

  test(
    'corrupt stored input is an error and remains available for diagnosis',
    () async {
      final dir = await directory();
      final file = File('${dir.path}/drafts.sqlite');
      var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
      await store.save(draft(ordinary));
      await store.close();
      await _mutate(
        file,
        (db) => db.customStatement(
          "UPDATE recording_drafts SET started_at='invalid'",
        ),
      );
      store = await DriftRecordingDraftStore.open(NativeDatabase(file));
      try {
        await expectLater(
          store.read(ordinary),
          throwsA(isA<RecordingDraftDataException>()),
        );
      } finally {
        await store.close();
      }
      await _mutate(file, (db) async {
        expect(
          (await db
                  .customSelect('SELECT started_at FROM recording_drafts')
                  .getSingle())
              .data['started_at'],
          'invalid',
        );
      });
    },
  );

  test('unusable path and unsupported version refuse opening', () async {
    final dir = await directory();
    await expectLater(
      DriftRecordingDraftStore.open(NativeDatabase(File(dir.path))),
      storageFailure(RecordingDraftOperation.open),
    );
    final file = File('${dir.path}/drafts.sqlite');
    final store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    await store.close();
    await _mutate(file, (db) => db.customStatement('PRAGMA user_version = 6'));
    await expectLater(
      DriftRecordingDraftStore.open(NativeDatabase(file)),
      storageFailure(RecordingDraftOperation.open),
    );
  });
}

Future<Map<String, Object?>> snapshot(AppDatabase db) async => {
  for (final table in [
    'goals',
    'time_blocks',
    'sleep_sessions',
    'rhythm_annotations',
    'daily_reviews',
  ])
    table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((r) => r.data)
        .toList(),
};

/// Raw access only to the isolated test file, for actual SQLite failure fixtures.
class _SqlProbe extends GeneratedDatabase {
  _SqlProbe(super.executor);
  @override
  int get schemaVersion => 5;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
