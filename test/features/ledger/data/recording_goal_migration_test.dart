import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';

const goal = '00000000-0000-4000-8000-000000000001';
const block = '00000000-0000-4000-8000-000000000002';
final date = CivilDate(year: 2026, month: 10, day: 1);
final edit = RecordingDraftContext.edit(date: date, timeBlockId: block);

class LegacyDrafts extends GeneratedDatabase {
  LegacyDrafts(super.executor, this.version);
  final int version;
  @override
  int get schemaVersion => version;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''CREATE TABLE recording_drafts (
 context_key TEXT NOT NULL PRIMARY KEY, entry TEXT NOT NULL,
 year INTEGER NOT NULL, month INTEGER NOT NULL, day INTEGER NOT NULL,
 time_block_id TEXT, gap_start INTEGER, gap_end INTEGER,
 title TEXT, started_at INTEGER, ended_at INTEGER,
 start_precision TEXT NOT NULL, end_precision TEXT NOT NULL,
 knowledge_state TEXT
)''');
      if (version >= 2) {
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN note TEXT',
        );
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN note_provided INTEGER NOT NULL DEFAULT 0 CHECK(note_provided IN (0,1))',
        );
      }
      if (version >= 3) {
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN goal_id TEXT',
        );
        await customStatement(
          'ALTER TABLE recording_drafts ADD COLUMN goal_provided INTEGER NOT NULL DEFAULT 0 CHECK(goal_provided IN (0,1))',
        );
      }
    },
  );
}

void main() {
  test('failed v2-to-current migration rolls back first ALTER and preserves old draft for retry', () async {
    final dir = await Directory.systemTemp.createTemp(
      'goal_migration_failure_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/drafts.sqlite');
    var legacy = LegacyDrafts(NativeDatabase(file), 2);
    await legacy.customStatement(
      "INSERT INTO recording_drafts (context_key,entry,year,month,day,title,start_precision,end_precision) VALUES ('new:2026:10:1','ordinary',2026,10,1,'未完成','exact','approximate')",
    );
    await legacy.customStatement(
      'ALTER TABLE recording_drafts ADD COLUMN goal_provided INTEGER',
    );
    await legacy.close();
    await expectLater(
      DriftRecordingDraftStore.open(NativeDatabase(file)),
      throwsA(isA<RecordingDraftStorageException>()),
    );
    legacy = LegacyDrafts(NativeDatabase(file), 2);
    expect(
      (await legacy.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      2,
    );
    expect(
      (await legacy.customSelect('PRAGMA table_info(recording_drafts)').get())
          .map((r) => r.data['name']),
      isNot(contains('goal_id')),
    );
    await legacy.customStatement(
      'ALTER TABLE recording_drafts DROP COLUMN goal_provided',
    );
    await legacy.close();
    final store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    expect(
      (await store.read(RecordingDraftContext.newEntry(date: date)))!.title,
      '未完成',
    );
    await store.close();
  });
}
