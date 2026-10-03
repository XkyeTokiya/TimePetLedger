import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

import 'recording_form_controller_test.dart' show FormDraftStore, formContext;

class GatedRepository implements LedgerRepository {
  GatedRepository(this.inner);
  final LedgerRepository inner;
  final gate = Completer<void>();
  int creates = 0;
  bool fail = false;

  @override
  Future<TimeBlockWriteResult> createTimeBlock({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required BlockKnowledgeState knowledgeState,
    required InstantMilliseconds now,
    String? title,
    EntityId? goalId,
    String? categoryId,
    String? note,
    AddAnnotation? annotation,
  }) async {
    creates++;
    await gate.future;
    if (fail) throw const LedgerStorageException('private SQL');
    return inner.createTimeBlock(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      knowledgeState: knowledgeState,
      now: now,
      title: title,
      goalId: goalId,
      categoryId: categoryId,
      note: note,
      annotation: annotation,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> runSubmission({required bool fail}) async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(db.close);
    final actual = DriftLedgerRepository(db);
    final repository = GatedRepository(actual)..fail = fail;
    final store = FormDraftStore();
    final loader = RecordingLedgerLoader(
      repository: actual,
      resolveDate: resolveDeviceRecordingDate,
    );
    final c = RecordingFormController(
      context: formContext,
      store: store,
      loadSuggestion: () async => const ManualTimeEntry(),
      entrySaver: RecordingEntrySaver(
        repository: repository,
        drafts: store,
        refresh: loader.load,
        newId: () => '00000000-0000-4000-8000-000000000001',
        now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      ),
    );
    addTearDown(c.dispose);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.known);
    c.setTitle('写作');
    c.setTime(
      start: DateTime(2026, 9, 28, 10).millisecondsSinceEpoch,
      end: DateTime(2026, 9, 28, 11).millisecondsSinceEpoch,
    );
    final first = c.submit();
    expect(c.submitting, isTrue);
    expect(await c.submit(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(repository.creates, 1);
    repository.gate.complete();
    final view = await first;
    expect(repository.creates, 1);
    if (fail) {
      expect(view, isNull);
      expect(c.committed, isNull);
      expect(c.submitError, contains('正式保存失败'));
      expect(store.value!.title, '写作');
      expect(
        (await actual.readWindow(
          startedAt: DateTime(2026, 9, 28, 9).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 28, 12).millisecondsSinceEpoch,
        )).timeBlocks,
        isEmpty,
      );
    } else {
      expect(view, isNotNull);
      expect(c.committed!.complete, isTrue);
      expect(store.value, isNull);
      expect(await c.submit(), isNull);
      expect(repository.creates, 1);
    }
  }

  test('duplicate taps and later submit never create a second fact', () async {
    await runSubmission(fail: false);
  });

  test('formal write failure keeps draft and does not claim success', () async {
    await runSubmission(fail: true);
  });

  test(
    'reopened committed draft is locked and cleaned without a new create',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db);
      final store = FormDraftStore()..failClear = true;
      final loader = RecordingLedgerLoader(
        repository: repository,
        resolveDate: resolveDeviceRecordingDate,
      );
      var ids = 0;
      final saver = RecordingEntrySaver(
        repository: repository,
        drafts: store,
        refresh: loader.load,
        newId: () {
          ids++;
          return '00000000-0000-4000-8000-000000000001';
        },
        now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      );
      RecordingFormController controller() => RecordingFormController(
        context: formContext,
        store: store,
        loadSuggestion: () async => const ManualTimeEntry(),
        entrySaver: saver,
      );
      final first = controller();
      await first.initialize();
      first.setKnowledge(BlockKnowledgeState.known);
      first.setTitle('写作');
      first.setTime(
        start: DateTime(2026, 9, 28, 10).millisecondsSinceEpoch,
        end: DateTime(2026, 9, 28, 11).millisecondsSinceEpoch,
      );
      expect(await first.submit(), isNull);
      expect(first.committed!.draftCleared, isFalse);
      first.dispose();
      store.failClear = false;
      final reopened = controller();
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.committed!.complete, isTrue);
      expect(reopened.editable, isFalse);
      expect(store.value, isNull);
      expect(ids, 1);
      expect(
        (await repository.readWindow(
          startedAt: DateTime(2026, 9, 28, 9).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 28, 12).millisecondsSinceEpoch,
        )).timeBlocks,
        hasLength(1),
      );
    },
  );
}
