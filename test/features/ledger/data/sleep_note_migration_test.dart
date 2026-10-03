import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

const id = '00000000-0000-4000-8000-000000000001';
final date = CivilDate(year: 2026, month: 9, day: 29);
final newContext = SleepDraftContext.newEntry(date: date);
final editContext = SleepDraftContext.edit(date: date, sleepSessionId: id);

/// The exact pre-note draft schema, opened separately from the v2 store.
class LegacyDrafts extends GeneratedDatabase {
  LegacyDrafts(super.executor);
  @override
  int get schemaVersion => 1;
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
 started_at_input TEXT, ended_at_input TEXT
)
'''),
  );
}

void main() {
  test('second ALTER failure rolls the first column back and can reopen for a retry', () async {
    final dir = await Directory.systemTemp.createTemp('sleep_note_rollback_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/drafts.sqlite');
    final legacy = LegacyDrafts(NativeDatabase(file));
    await legacy.customStatement(
      "INSERT INTO sleep_drafts (context_key, year, month, day, started_at_input) VALUES ('new:2026:9:29', 2026, 9, 29, '原始未完成时间')",
    );
    // A duplicate second column injects a real SQLite DDL failure.
    await legacy.customStatement(
      'ALTER TABLE sleep_drafts ADD COLUMN note_provided INTEGER',
    );
    await legacy.close();
    await expectLater(
      DriftSleepDraftStore.open(NativeDatabase(file)),
      throwsA(isA<SleepDraftStorageException>()),
    );
    final probe = LegacyDrafts(NativeDatabase(file));
    expect(
      (await probe.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      1,
    );
    final columns =
        (await probe.customSelect('PRAGMA table_info(sleep_drafts)').get()).map(
          (r) => r.data['name'],
        );
    expect(columns, isNot(contains('note')));
    expect(columns, contains('note_provided'));
    await probe.customStatement(
      'ALTER TABLE sleep_drafts DROP COLUMN note_provided',
    );
    await probe.close();
    final store = await DriftSleepDraftStore.open(NativeDatabase(file));
    expect((await store.read(newContext))!.startedAtInput, '原始未完成时间');
    expect((await store.read(newContext))!.noteProvided, isFalse);
    await store.close();
  });
  test('v1 to v2 preserves both old contexts and omitted note; raw note and explicit clearing survive reopening', () async {
    final dir = await Directory.systemTemp.createTemp('sleep_note_migration_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/drafts.sqlite');
    final legacy = LegacyDrafts(NativeDatabase(file));
    for (final context in [newContext, editContext]) {
      await legacy.customStatement(
        'INSERT INTO sleep_drafts VALUES (?, 2026, 9, 29, ?, 1001, NULL, ?, ?, ?, ?, ?)',
        [
          context.isEditing ? 'edit:$id' : 'new:2026:9:29',
          context.sleepSessionId,
          'approximate',
          'exact',
          'mainSleep',
          '2026-09-',
          '2026-09-29 07:',
        ],
      );
    }
    await legacy.close();
    var store = await DriftSleepDraftStore.open(NativeDatabase(file));
    for (final context in [newContext, editContext]) {
      final saved = (await store.read(context))!;
      expect(saved.context.date, date);
      expect(saved.context.sleepSessionId, context.sleepSessionId);
      expect(saved.startedAt, 1001);
      expect(saved.endedAt, isNull);
      expect(saved.startedAtInput, '2026-09-');
      expect(saved.endedAtInput, '2026-09-29 07:');
      expect(saved.startPrecision, TimePrecision.approximate);
      expect(saved.endPrecision, TimePrecision.exact);
      expect(saved.type, SleepType.mainSleep);
      expect(saved.note, isNull);
      expect(saved.noteProvided, isFalse);
    }
    final original = SleepSession(
      id: id,
      startedAt: 1001,
      endedAt: 2001,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      createdAt: 1,
      updatedAt: 1,
      note: '原有\n说明',
    );
    var controller = SleepFormController(
      context: editContext,
      store: store,
      original: original,
    );
    await controller.initialize();
    expect(controller.note, original.note);
    controller.setEndedAtInput('2026-09-29 07:40');
    await controller.flush();
    expect((await store.read(editContext))!.noteProvided, isFalse);
    controller.setNote('');
    await controller.flush();
    controller.dispose();
    await store.save(
      SleepDraft(
        context: newContext,
        startedAt: null,
        endedAt: null,
        startPrecision: null,
        endPrecision: null,
        type: null,
        note: '  原始\n说明😀  ',
        noteProvided: true,
      ),
    );
    await store.close();
    store = await DriftSleepDraftStore.open(NativeDatabase(file));
    expect((await store.read(newContext))!.note, '  原始\n说明😀  ');
    controller = SleepFormController(
      context: editContext,
      store: store,
      original: original,
    );
    await controller.initialize();
    expect(controller.note, isEmpty);
    expect(controller.draft.noteProvided, isTrue);
    controller.dispose();
    await store.close();
  });
}
