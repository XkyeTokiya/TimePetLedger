import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';

import 'recording_goal_migration_test.dart' show LegacyDrafts;
import '../../../support/recording_draft_fixture.dart' show editContext;

void main() {
  test('failed v3-to-v4 migration rolls back first ALTER and retains raw draft for retry', () async {
    final dir = await Directory.systemTemp.createTemp(
      'rhythm_upgrade_failure_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/draft.sqlite');
    var old = LegacyDrafts(NativeDatabase(file), 3);
    await old.customStatement(
      "INSERT INTO recording_drafts (context_key,entry,year,month,day,title,start_precision,end_precision) VALUES ('new:2026:10:1','ordinary',2026,10,1,'  尚未提交  ','exact','approximate')",
    );
    await old.customStatement(
      'ALTER TABLE recording_drafts ADD COLUMN annotation_id TEXT',
    );
    await old.close();
    await expectLater(
      DriftRecordingDraftStore.open(NativeDatabase(file)),
      throwsA(isA<RecordingDraftStorageException>()),
    );
    old = LegacyDrafts(NativeDatabase(file), 3);
    expect(
      (await old.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      3,
    );
    expect(
      (await old.customSelect('PRAGMA table_info(recording_drafts)').get()).map(
        (row) => row.data['name'],
      ),
      isNot(contains('annotation_intent')),
    );
    await old.customStatement(
      'ALTER TABLE recording_drafts DROP COLUMN annotation_id',
    );
    await old.close();
    final store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    expect(
      (await store.read(
        RecordingDraftContext.newEntry(date: editContext.date),
      ))!.title,
      '  尚未提交  ',
    );
    await store.close();
  });
}
