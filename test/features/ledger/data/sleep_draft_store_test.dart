import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

final date = CivilDate(year: 2026, month: 9, day: 29);
final context = SleepDraftContext.newEntry(date: date);
SleepDraft draft(
  SleepDraftContext c, {
  int? start,
  int? end,
  SleepType? type,
  String? raw,
  String? note,
}) => SleepDraft(
  context: c,
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: null,
  type: type,
  startedAtInput: raw,
  endedAtInput: '2026-09-',
  note: note,
  noteProvided: note != null,
);
List<Object?> fields(SleepDraft d) => [
  d.context.date,
  d.context.sleepSessionId,
  d.startedAt,
  d.endedAt,
  d.startPrecision,
  d.endPrecision,
  d.type,
  d.startedAtInput,
  d.endedAtInput,
  d.note,
  d.noteProvided,
];
Matcher failure(SleepDraftOperation op) => throwsA(
  isA<SleepDraftStorageException>().having((e) => e.operation, 'operation', op),
);
Future<File> tempFile() async {
  final dir = await Directory.systemTemp.createTemp('sleep_draft_test_');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/sleep.sqlite');
}

Future<void> _mutate(File file, Future<void> Function(_Probe) action) async {
  final probe = _Probe(NativeDatabase(file));
  try {
    await action(probe);
  } finally {
    await probe.close();
  }
}

void main() {
  test('reopen preserves incomplete input, create dates and stable edit identities', () async {
    final file = await tempFile();
    final contexts = [
      context,
      SleepDraftContext.newEntry(
        date: CivilDate(year: 2026, month: 9, day: 30),
      ),
      SleepDraftContext.edit(date: date, sleepSessionId: ledgerId),
      SleepDraftContext.edit(date: date, sleepSessionId: secondLedgerId),
    ];
    final inputs = [
      draft(contexts[0], raw: ' 2026-09- 🐾 '),
      draft(contexts[1], start: 20, end: 10, type: SleepType.nap),
      draft(contexts[2], start: 10, end: 10, type: SleepType.mainSleep),
      SleepDraft(
        context: contexts[3],
        startedAt: null,
        endedAt: 123,
        startPrecision: null,
        endPrecision: TimePrecision.approximate,
        type: null,
      ),
    ];
    var store = await DriftSleepDraftStore.open(NativeDatabase(file));
    expect(await store.read(context), isNull);
    for (final input in inputs) {
      await store.save(input);
    }
    await store.close();
    store = await DriftSleepDraftStore.open(NativeDatabase(file));
    for (final input in inputs) {
      expect(fields((await store.read(input.context))!), fields(input));
    }
    final anotherDate = SleepDraftContext.edit(
      date: CivilDate(year: 2026, month: 10, day: 1),
      sleepSessionId: ledgerId,
    );
    expect(fields((await store.read(anotherDate))!), fields(inputs[2]));
    await store.clear(anotherDate);
    await store.clear(anotherDate);
    await store.save(draft(context, start: 55, type: SleepType.nap));
    await store.close();
    store = await DriftSleepDraftStore.open(NativeDatabase(file));
    try {
      expect(await store.read(contexts[2]), isNull);
      expect((await store.read(context))!.startedAt, 55);
      expect(fields((await store.read(contexts[1]))!), fields(inputs[1]));
      expect(fields((await store.read(contexts[3]))!), fields(inputs[3]));
    } finally {
      await store.close();
    }
  });

  test('sleep draft operations leave populated formal five tables and ordinary drafts unchanged', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(db.close);
    await insertLedgerRow(db, 'goals', {
      'id': ledgerId,
      'name': '目标',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await insertLedgerRow(db, 'time_blocks', blockRow(start: 10, end: 20));
    await insertLedgerRow(db, 'sleep_sessions', sleepRow(start: 0, end: 10));
    await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
    await insertLedgerRow(db, 'daily_reviews', {
      'id': ledgerId,
      'review_date': '2026-09-29',
      'tomorrow_first_step_text': '下一步',
      'created_at': 1,
      'updated_at': 1,
    });
    Future<Object> facts() async => [
      for (final table in [
        'goals',
        'time_blocks',
        'sleep_sessions',
        'rhythm_annotations',
        'daily_reviews',
      ])
        (await db.customSelect('SELECT * FROM $table').get())
            .map((r) => r.data)
            .toList(),
    ];
    final before = await facts();
    final ordinary = await DriftRecordingDraftStore.open(
      NativeDatabase.memory(),
    );
    addTearDown(ordinary.close);
    final ordinaryContext = RecordingDraftContext.newEntry(date: date);
    await ordinary.save(
      RecordingDraft(
        context: ordinaryContext,
        title: '普通草稿',
        startedAt: 20,
        endedAt: null,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: null,
      ),
    );
    final store = await DriftSleepDraftStore.open(
      NativeDatabase(await tempFile()),
    );
    addTearDown(store.close);
    final edit = SleepDraftContext.edit(date: date, sleepSessionId: ledgerId);
    await store.save(draft(edit, start: 0, end: 200));
    await store.save(draft(context, start: 20, end: 200));
    expect(await facts(), before);
    final ledger = DriftLedgerRepository(db);
    final read = await ledger.readSleepContext(
      startedAt: 0,
      endedAt: 200,
      dayStartedAt: 0,
      nextDayStartedAt: 1000,
    );
    expect(read.windowFacts.sleepSessions.single.endedAt, 10);
    expect(read.sleepSummaryCandidates, hasLength(1));
    await ledger.createSleepSession(
      id: secondLedgerId,
      startedAt: 20,
      endedAt: 30,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.nap,
      now: 2,
    );
    await ledger.deleteSleepSession(secondLedgerId);
    await expectLater(
      ledger.createSleepSession(
        id: secondLedgerId,
        startedAt: 5,
        endedAt: 15,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        now: 2,
      ),
      throwsA(isA<LedgerConflictException>()),
    );
    await store.clear(context);
    await store.clear(edit);
    expect(await facts(), before);
    expect((await ordinary.read(ordinaryContext))!.title, '普通草稿');
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE name='sleep_drafts'",
          )
          .get(),
      isEmpty,
    );
  });

  test(
    'real save and clear failure retain last committed draft across reopen',
    () async {
      final file = await tempFile();
      var store = await DriftSleepDraftStore.open(NativeDatabase(file));
      await store.save(draft(context, raw: 'original', note: '  原始\n备注  '));
      await store.close();
      await _mutate(file, (db) async {
        await db.customStatement(
          "CREATE TRIGGER reject_save AFTER UPDATE ON sleep_drafts BEGIN SELECT RAISE(ABORT, 'test'); END",
        );
        await db.customStatement(
          "CREATE TRIGGER reject_clear AFTER DELETE ON sleep_drafts BEGIN SELECT RAISE(ABORT, 'test'); END",
        );
      });
      store = await DriftSleepDraftStore.open(NativeDatabase(file));
      await expectLater(
        store.save(draft(context, raw: 'replace', note: '替换备注')),
        failure(SleepDraftOperation.save),
      );
      await expectLater(
        store.clear(context),
        failure(SleepDraftOperation.clear),
      );
      await store.close();
      await _mutate(file, (db) async {
        await db.customStatement('DROP TRIGGER reject_save');
        await db.customStatement('DROP TRIGGER reject_clear');
      });
      store = await DriftSleepDraftStore.open(NativeDatabase(file));
      expect((await store.read(context))!.startedAtInput, 'original');
      expect((await store.read(context))!.note, '  原始\n备注  ');
      await store.clear(context);
      await store.close();
      store = await DriftSleepDraftStore.open(NativeDatabase(file));
      expect(await store.read(context), isNull);
      await store.close();
    },
  );

  test(
    'corrupt rows fail rather than disappearing or defaulting choices',
    () async {
      for (final mutation in [
        "started_at='bad'",
        "sleep_type='bad'",
        "start_precision='bad'",
        'note_provided=2',
        'month=13',
        "sleep_session_id='bad'",
        "context_key='new:2026:9:29', day=30",
      ]) {
        final file = await tempFile();
        var store = await DriftSleepDraftStore.open(NativeDatabase(file));
        await store.save(draft(context));
        await store.close();
        await _mutate(file, (db) async {
          await db.customStatement('PRAGMA ignore_check_constraints=ON');
          await db.customStatement('UPDATE sleep_drafts SET $mutation');
        });
        store = await DriftSleepDraftStore.open(NativeDatabase(file));
        await expectLater(
          store.read(context),
          throwsA(isA<SleepDraftDataException>()),
        );
        await store.close();
        await _mutate(file, (db) async {
          expect(
            await db.customSelect('SELECT * FROM sleep_drafts').get(),
            hasLength(1),
          );
        });
      }
    },
  );

  test(
    'closed store and unusable path/version expose operation failure',
    () async {
      final file = await tempFile();
      final store = await DriftSleepDraftStore.open(NativeDatabase(file));
      await store.close();
      await expectLater(store.read(context), failure(SleepDraftOperation.read));
      await expectLater(
        store.save(draft(context)),
        failure(SleepDraftOperation.save),
      );
      await expectLater(
        store.clear(context),
        failure(SleepDraftOperation.clear),
      );
      await expectLater(
        DriftSleepDraftStore.open(NativeDatabase(File(file.parent.path))),
        failure(SleepDraftOperation.open),
      );
      await _mutate(
        file,
        (db) => db.customStatement('PRAGMA user_version = 3'),
      );
      await expectLater(
        DriftSleepDraftStore.open(NativeDatabase(file)),
        failure(SleepDraftOperation.open),
      );
    },
  );
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
