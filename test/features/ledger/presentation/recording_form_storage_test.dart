import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

void main() {
  test(
    'form autosaves incomplete input to disk without changing formal facts',
    () async {
      final dir = await Directory.systemTemp.createTemp('recording_form_');
      addTearDown(() => dir.delete(recursive: true));
      final db = await AppDatabase.open(
        NativeDatabase(File('${dir.path}/facts.sqlite')),
      );
      addTearDown(db.close);
      await DriftLedgerRepository(db).createTimeBlock(
        id: '00000000-0000-4000-8000-000000000001',
        startedAt: 10,
        endedAt: 20,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '原事实',
        now: 1,
      );
      Future<List<Object?>> snapshot() async => [
        for (final table in [
          'time_blocks',
          'sleep_sessions',
          'rhythm_annotations',
          'goals',
          'daily_reviews',
        ])
          (await db.customSelect('SELECT * FROM $table').get())
              .map((r) => r.data)
              .toList(),
      ];
      final before = await snapshot();
      final file = File('${dir.path}/drafts.sqlite');
      var store = await DriftRecordingDraftStore.open(NativeDatabase(file));
      final context = RecordingDraftContext.newEntry(
        date: CivilDate(year: 2026, month: 9, day: 28),
      );
      var c = RecordingFormController(
        context: context,
        store: store,
        loadSuggestion: () async => const ManualTimeEntry(),
      );
      await c.initialize();
      c.setTitle('  还未完成\n');
      c.setNote('  笔记\n第二行  ');
      c.setKnowledge(BlockKnowledgeState.known);
      c.setTime(start: 5, end: null);
      c.setPrecision(end: TimePrecision.exact);
      expect(await c.flush(), isTrue);
      expect(await snapshot(), before);
      c.dispose();
      await store.close();
      store = await DriftRecordingDraftStore.open(NativeDatabase(file));
      c = RecordingFormController(
        context: context,
        store: store,
        loadSuggestion: () async => throw StateError('restored input must win'),
      );
      await c.initialize();
      expect(c.title, '  还未完成\n');
      expect(c.note, '  笔记\n第二行  ');
      expect(c.time.endedAt, isNull);
      expect(c.time.endPrecision, TimePrecision.exact);
      expect(c.restored, isTrue);
      expect(await c.discard(), isTrue);
      expect(await snapshot(), before);
      c.dispose();
      await store.close();
      store = await DriftRecordingDraftStore.open(NativeDatabase(file));
      expect(await store.read(context), isNull);
      await store.close();
    },
  );
}
