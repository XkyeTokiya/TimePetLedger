import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

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
  for (final version in [1, 2]) {
    test(
      'v$version upgrade retains raw input and omitted Goal; select/clear survive file reopen and edit leaves hidden fields',
      () async {
        final dir = await Directory.systemTemp.createTemp('goal_drafts_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/drafts.sqlite');
        final legacy = LegacyDrafts(NativeDatabase(file), version);
        await legacy.customStatement(
          '''INSERT INTO recording_drafts (
context_key,entry,year,month,day,time_block_id,title,started_at,ended_at,start_precision,end_precision,knowledge_state
) VALUES ('edit:$block','edit',2026,10,1,'$block','  旧草稿 🐾  ',10,20,'approximate','exact','unknown')''',
        );
        await legacy.close();
        var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        final old = (await store.read(edit))!;
        expect(old.title, '  旧草稿 🐾  ');
        expect(old.goalId, isNull);
        expect(old.goalProvided, isFalse);
        expect(old.noteProvided, isFalse);
        final db = await AppDatabase.open(NativeDatabase.memory());
        addTearDown(db.close);
        final goals = DriftGoalRepository(db);
        final repo = DriftLedgerRepository(db);
        await goals.create(id: goal, name: '历史', now: 1);
        await repo.createTimeBlock(
          id: block,
          startedAt: 10,
          endedAt: 20,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '原记录',
          goalId: goal,
          categoryId: '原分类',
          note: '原备注',
          annotation: AddAnnotation(
            id: block,
            state: RhythmState.recovery,
            continuationHint: '原解释',
          ),
          now: 1,
        );
        await goals.archive(id: goal, now: 2);
        RecordingFormController controller() {
          final saver = RecordingEntrySaver(
            repository: repo,
            drafts: store,
            refresh: RecordingLedgerLoader(
              repository: repo,
              resolveDate: resolveDeviceRecordingDate,
            ).load,
            newId: () => block,
            now: () => 3,
          );
          return RecordingFormController(
            context: edit,
            store: store,
            goals: goals,
            entryEditor: RecordingEntryEditor(
              repository: repo,
              drafts: store,
              saver: saver,
            ),
            loadSuggestion: () async => const ManualTimeEntry(),
          );
        }

        var c = controller();
        await c.initialize();
        expect(c.goalId, goal);
        expect(c.committed, isNull);
        c.setTitle('旧草稿继续输入');
        await c.flush();
        expect((await store.read(edit))!.goalProvided, isFalse);
        expect((await repo.readTimeBlock(block))!.timeBlock.title, '原记录');
        await c.submit();
        final retained = (await repo.readTimeBlock(block))!;
        expect(retained.timeBlock.goalId, goal);
        expect(retained.timeBlock.note, '原备注');
        expect(retained.timeBlock.categoryId, '原分类');
        expect(retained.annotation!.continuationHint, '原解释');
        c.dispose();
        await goals.restore(id: goal, now: 4);
        c = controller();
        await c.initialize();
        c.setTitle('选择尚未提交');
        c.selectGoal(goal);
        await c.flush();
        c.dispose();
        await store.close();
        store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        expect((await store.read(edit))!.goalId, goal);
        expect((await store.read(edit))!.goalProvided, isTrue);
        c = controller();
        await c.initialize();
        expect(c.committed, isNull);
        c.clearGoal();
        await c.flush();
        c.dispose();
        await store.close();
        store = await DriftRecordingDraftStore.open(NativeDatabase(file));
        expect((await store.read(edit))!.goalProvided, isTrue);
        expect((await store.read(edit))!.goalId, isNull);
        c = controller();
        await c.initialize();
        expect(c.committed, isNull);
        expect(c.goalId, isNull);
        expect((await repo.readTimeBlock(block))!.timeBlock.goalId, goal);
        await c.submit();
        expect((await repo.readTimeBlock(block))!.timeBlock.goalId, isNull);
        c.dispose();
        await store.close();
        expect(db.schemaVersion, 2);
        expect(
          (await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
              )
              .get()),
          hasLength(5),
        );
      },
    );
  }

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
