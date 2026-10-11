import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';

import 'recording_goal_migration_test.dart' show LegacyDrafts;
import '../../../support/recording_draft_fixture.dart' as support;

/// Real v4 input schema, including the previous annotation intent and raw hint.
class LegacyDetails extends LegacyDrafts {
  LegacyDetails(QueryExecutor executor) : super(executor, 4);
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await super.migration.onCreate(m);
      for (final sql in [
        "annotation_intent TEXT NOT NULL DEFAULT 'keep'",
        'annotation_id TEXT',
        'rhythm_state TEXT',
        'continuation_hint TEXT',
        'hint_provided INTEGER NOT NULL DEFAULT 0',
      ]) {
        await customStatement('ALTER TABLE recording_drafts ADD COLUMN $sql');
      }
    },
  );
}

void main() {
  test('v4-to-v5 DDL failure rolls back columns/version and retains input for retry', () async {
    final dir = await Directory.systemTemp.createTemp('details_rollback_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/draft.sqlite');
    var old = LegacyDetails(NativeDatabase(file));
    await old.customStatement(
      "INSERT INTO recording_drafts(context_key,entry,year,month,day,title,start_precision,end_precision) VALUES ('new:2026:10:1','ordinary',2026,10,1,'  保留 🐾  ','exact','approximate')",
    );
    await old.customStatement(
      'ALTER TABLE recording_drafts ADD COLUMN stuck_reason_text TEXT',
    );
    await old.close();
    await expectLater(
      DriftRecordingDraftStore.open(NativeDatabase(file)),
      throwsA(isA<RecordingDraftStorageException>()),
    );
    old = LegacyDetails(NativeDatabase(file));
    expect(
      (await old.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      4,
    );
    expect(
      (await old.customSelect('PRAGMA table_info(recording_drafts)').get()).map(
        (r) => r.data['name'],
      ),
      isNot(contains('stuck_reason_code')),
    );
    expect(
      (await old.customSelect('SELECT title FROM recording_drafts').getSingle())
          .data['title'],
      '  保留 🐾  ',
    );
    await old.customStatement(
      'ALTER TABLE recording_drafts DROP COLUMN stuck_reason_text',
    );
    await old.close();
    final store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    expect((await store.read(support.newContext))!.title, '  保留 🐾  ');
    await store.close();
    final probe = LegacyDrafts(NativeDatabase(file), 5);
    expect(
      (await probe.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      5,
    );
    await probe.close();
  });
}
