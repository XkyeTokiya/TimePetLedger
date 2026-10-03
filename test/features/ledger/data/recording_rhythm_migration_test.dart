import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';

import 'recording_goal_migration_test.dart' show LegacyDrafts;
import '../presentation/recording_rhythm_test.dart'
    show Fixture, editContext, newContext, id;

void main() {
  for (final version in [1, 2, 3]) {
    test(
      'v$version file upgrade omits annotation change, keeps hidden source; explicit edit/remove survive reopen',
      () async {
        final dir = await Directory.systemTemp.createTemp('rhythm_upgrade_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/draft.sqlite');
        final old = LegacyDrafts(NativeDatabase(file), version);
        final f = await Fixture.open();
        addTearDown(f.db.close);
        await f.drafts.close();
        await f.source(state: RhythmState.recovery);
        final before = (await f.repo.readTimeBlock(id(8)))!;
        final annotationRow =
            (await f.db
                    .customSelect('SELECT * FROM rhythm_annotations')
                    .getSingle())
                .data;
        await old.customStatement(
          '''INSERT INTO recording_drafts
(context_key,entry,year,month,day,time_block_id,title,started_at,ended_at,start_precision,end_precision,knowledge_state)
VALUES ('edit:${id(8)}','edit',2026,10,1,'${id(8)}','  旧草稿 🐾  ',${before.timeBlock.startedAt},${before.timeBlock.endedAt},'approximate','exact','known')''',
        );
        if (version >= 2) {
          await old.customStatement(
            "UPDATE recording_drafts SET note='  旧备注  ', note_provided=1",
          );
        }
        if (version == 3) {
          await f.goals.create(id: id(1), name: '已有目标', now: 1);
          await old.customStatement(
            "UPDATE recording_drafts SET goal_id='${id(1)}', goal_provided=1",
          );
        }
        await old.close();
        var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        var upgraded = Fixture(f.db, store);
        var c = upgraded.controller(editContext);
        await c.initialize();
        expect(c.title, '  旧草稿 🐾  ');
        expect(c.note, version >= 2 ? '  旧备注  ' : '原备注');
        expect(c.goalProvided, version == 3);
        expect(c.goalId, version == 3 ? id(1) : null);
        expect(c.annotationIntent, RecordingAnnotationIntent.keep);
        expect(c.rhythmState, RhythmState.recovery);
        expect(c.continuationHint, '原接续点');
        expect(c.committed, isNull);
        expect((await store.read(editContext))!.hintProvided, isFalse);
        await c.submit();
        final retained = (await f.repo.readTimeBlock(id(8)))!;
        expect(
          (await f.db
                  .customSelect('SELECT * FROM rhythm_annotations')
                  .getSingle())
              .data,
          annotationRow,
        );
        expect(retained.timeBlock.categoryId, '原分类');
        c.dispose();
        c = upgraded.controller(editContext);
        await c.initialize();
        c.setRhythmState(RhythmState.stuck);
        c.setContinuationHint('  原始接续点\n🐾  ');
        await c.flush();
        c.dispose();
        await store.close();
        store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        upgraded = Fixture(f.db, store);
        c = upgraded.controller(editContext);
        await c.initialize();
        expect(c.annotationIntent, RecordingAnnotationIntent.edit);
        expect(c.rhythmState, RhythmState.stuck);
        expect(c.continuationHint, '  原始接续点\n🐾  ');
        expect(c.committed, isNull);
        expect(
          (await f.db
                  .customSelect('SELECT * FROM rhythm_annotations')
                  .getSingle())
              .data,
          annotationRow,
        );
        await c.submit();
        expect(
          (await f.repo.readTimeBlock(id(8)))!.annotation!.continuationHint,
          '原始接续点\n🐾',
        );
        c.dispose();
        c = upgraded.controller(editContext);
        await c.initialize();
        c.setContinuationHint('  ');
        c.setRhythmState(null);
        await c.flush();
        c.dispose();
        await store.close();
        store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        upgraded = Fixture(f.db, store);
        c = upgraded.controller(editContext);
        await c.initialize();
        expect(c.annotationIntent, RecordingAnnotationIntent.remove);
        expect(c.continuationHint, '  ');
        expect(c.hintProvided, isTrue);
        c.setRhythmState(RhythmState.progress);
        await c.submit();
        final clearedHint = (await f.repo.readTimeBlock(id(8)))!.annotation!;
        expect(clearedHint.continuationHint, isNull);
        expect(clearedHint.stuckReasonText, '原原因');
        expect(clearedHint.recoveryMethod, before.annotation!.recoveryMethod);
        c.dispose();
        await store.close();
        expect(f.db.schemaVersion, 2);
        expect(
          await f.db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
              )
              .get(),
          hasLength(5),
        );
      },
    );
  }
  test('new annotation stable id and raw hint survive file reopen and none/state restoration', () async {
    final dir = await Directory.systemTemp.createTemp('rhythm_new_file_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/draft.sqlite');
    final f = await Fixture.open();
    addTearDown(f.db.close);
    await f.drafts.close();
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    var c = Fixture(f.db, store).controller(newContext);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.unknown);
    c.setRhythmState(RhythmState.stuck);
    c.setContinuationHint('  接续点\n🐾  ');
    await c.flush();
    final stableId = c.annotationId;
    c.dispose();
    await store.close();
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    final restored = await store.read(newContext);
    expect(restored!.annotationId, stableId);
    expect(restored.annotationIntent, RecordingAnnotationIntent.add);
    c = Fixture(f.db, store).controller(newContext);
    await c.initialize();
    expect(c.continuationHint, '  接续点\n🐾  ');
    expect(c.committed, isNull);
    c.setRhythmState(null);
    await c.flush();
    c.dispose();
    await store.close();
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    c = Fixture(f.db, store).controller(newContext);
    await c.initialize();
    expect(c.rhythmState, isNull);
    expect(c.continuationHint, '  接续点\n🐾  ');
    c.setRhythmState(RhythmState.recovery);
    expect(c.annotationId, stableId);
    await c.submit();
    expect(c.committed!.complete, isTrue);
    final saved = (await f.repo.readTimeBlock(c.committed!.timeBlock.id))!;
    expect(saved.annotation!.id, stableId);
    expect(saved.annotation!.state, RhythmState.recovery);
    expect(saved.annotation!.continuationHint, '接续点\n🐾');
    c.dispose();
    await store.close();
  });

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
