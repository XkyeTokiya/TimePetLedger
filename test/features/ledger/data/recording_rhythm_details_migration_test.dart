import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';

import 'recording_goal_migration_test.dart' show LegacyDrafts;
import '../presentation/recording_rhythm_test.dart' as support;

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
  test('v4 edit with previous state/hint intent preserves omitted details, then explicit clear survives file reopen', () async {
    final dir = await Directory.systemTemp.createTemp('details_v4_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/draft.sqlite');
    final old = LegacyDetails(NativeDatabase(file));
    final f = await support.Fixture.open();
    addTearDown(f.db.close);
    await f.drafts.close();
    await f.source(state: RhythmState.stuck);
    await old.customStatement(
      '''INSERT INTO recording_drafts
(context_key,entry,year,month,day,time_block_id,title,started_at,ended_at,start_precision,end_precision,knowledge_state,note,note_provided,annotation_intent,rhythm_state,continuation_hint,hint_provided)
VALUES ('edit:${support.id(8)}','edit',2026,10,1,'${support.id(8)}','原活动',${support.start},${support.end},'approximate','exact','known','原备注',1,'edit','recovery','  旧接续点 🐾  ',1)''',
    );
    await old.close();
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    final draft = (await store.read(support.editContext))!;
    expect([
      draft.stuckReasonCodeProvided,
      draft.stuckReasonTextProvided,
      draft.recoveryMethodProvided,
      draft.recoveryQualityProvided,
    ], everyElement(isFalse));
    var c = support.Fixture(f.db, store).controller(support.editContext);
    await c.initialize();
    expect(c.rhythmState, RhythmState.recovery);
    expect(c.stuckReasonText, '原原因');
    expect(c.recoveryMethod, RecoveryMethod.walk);
    expect(c.committed, isNull);
    expect(await c.submit(), isNotNull);
    final a = (await f.repo.readTimeBlock(support.id(8)))!.annotation!;
    expect(a.stuckReasonCode, StuckReasonCode.unclearNextStep);
    expect(a.stuckReasonText, '原原因');
    expect(a.recoveryMethod, RecoveryMethod.walk);
    expect(a.recoveryQuality, RecoveryQuality.partlyRecovered);
    expect(a.continuationHint, '旧接续点 🐾');
    c.dispose();
    c = support.Fixture(f.db, store).controller(support.editContext);
    await c.initialize();
    c.setRecoveryMethod(null);
    c.setRecoveryQuality(RecoveryQuality.readyToContinue);
    c.setRhythmState(RhythmState.stuck);
    c.setStuckReasonCode(null);
    c.setStuckReasonText('');
    await c.flush();
    c.dispose();
    await store.close();
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    c = support.Fixture(f.db, store).controller(support.editContext);
    await c.initialize();
    expect(c.stuckReasonCode, isNull);
    expect(c.stuckReasonText, '');
    expect(c.recoveryMethod, isNull);
    expect(c.recoveryQuality, RecoveryQuality.readyToContinue);
    expect(c.committed, isNull);
    expect(await c.submit(), isNotNull);
    final cleared = (await f.repo.readTimeBlock(support.id(8)))!.annotation!;
    expect(cleared.stuckReasonText, isNull);
    expect(cleared.recoveryMethod, isNull);
    expect(cleared.recoveryQuality, RecoveryQuality.readyToContinue);
    c.dispose();
    await store.close();
  });

  test('new oversized raw details and stable annotation id survive file reopen; discard clears only draft', () async {
    final dir = await Directory.systemTemp.createTemp('details_raw_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/draft.sqlite');
    final f = await support.Fixture.open();
    addTearDown(f.db.close);
    await f.drafts.close();
    var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    var c = support.Fixture(f.db, store).controller(support.newContext);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.unknown);
    c.setRhythmState(RhythmState.stuck);
    c.setStuckReasonCode(StuckReasonCode.unsure);
    final raw = '  ${'🐾' * 2001}\n  ';
    c.setStuckReasonText(raw);
    c.setRhythmState(RhythmState.recovery);
    c.setRecoveryMethod(RecoveryMethod.breakDownTask);
    c.setRecoveryQuality(RecoveryQuality.notRecovered);
    final stable = c.annotationId;
    await c.flush();
    c.dispose();
    await store.close();
    store = await DriftRecordingDraftStore.open(NativeDatabase(file));
    c = support.Fixture(f.db, store).controller(support.newContext);
    await c.initialize();
    expect(c.annotationId, stable);
    expect(c.stuckReasonText, raw);
    expect(c.stuckReasonCode, StuckReasonCode.unsure);
    expect(c.recoveryMethod, RecoveryMethod.breakDownTask);
    expect(c.recoveryQuality, RecoveryQuality.notRecovered);
    expect(await c.submit(), isNull);
    expect(await c.discard(), isTrue);
    expect(await store.read(support.newContext), isNull);
    expect(
      (await f.repo.readWindow(
        startedAt: support.start,
        endedAt: support.end,
      )).timeBlocks,
      isEmpty,
    );
    c.dispose();
    await store.close();
  });

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
