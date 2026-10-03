import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

final formContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2026, month: 9, day: 28),
);

class FormDraftStore implements RecordingDraftStore {
  RecordingDraft? value;
  bool failRead = false, failSave = false, failClear = false;
  Completer<void>? gate;
  int saves = 0, clears = 0;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) async {
    if (failRead) throw StateError('private path');
    return value;
  }

  @override
  Future<void> save(RecordingDraft draft) async {
    saves++;
    await gate?.future;
    if (failSave) throw StateError('private SQL');
    value = draft;
  }

  @override
  Future<void> clear(RecordingDraftContext context) async {
    clears++;
    if (failClear) throw StateError('private SQL');
    value = null;
  }
}

RecordingFormController controller(FormDraftStore store) =>
    RecordingFormController(
      context: formContext,
      store: store,
      loadSuggestion: () async => const ManualTimeEntry(),
    );

void main() {
  test(
    'restore precedes suggestions, retains incomplete title/time and precision',
    () async {
      final store = FormDraftStore();
      final first = controller(store);
      await first.initialize();
      first.setTitle('  未完成\n');
      first.setNote('  并行\n活动  ');
      first.setKnowledge(BlockKnowledgeState.unknown);
      first.setTime(start: 200, end: null);
      first.setPrecision(start: TimePrecision.exact);
      expect(await first.flush(), isTrue);
      first.dispose();
      final restored = RecordingFormController(
        context: formContext,
        store: store,
        loadSuggestion: () async => throw StateError('must not load'),
      );
      await restored.initialize();
      expect(restored.restored, isTrue);
      expect(restored.title, '  未完成\n');
      expect(restored.note, '  并行\n活动  ');
      expect(restored.time.startedAt, 200);
      expect(restored.time.endedAt, isNull);
      expect(restored.time.startPrecision, TimePrecision.exact);
      expect(restored.time.endPrecision, TimePrecision.approximate);
      restored.dispose();
    },
  );
  test('read failure blocks writes and does not replace old draft', () async {
    final store = FormDraftStore()..failRead = true;
    final c = controller(store);
    await c.initialize();
    c.setTitle('不能写入');
    expect(c.loadError, isNotNull);
    expect(store.saves, 0);
    store.failRead = false;
    await c.initialize();
    c.setTitle('恢复后输入');
    expect(await c.flush(), isTrue);
    c.dispose();
  });
  test(
    'queued autosaves cannot finish out of order; discard waits then clears',
    () async {
      final store = FormDraftStore()..gate = Completer<void>();
      final c = controller(store);
      await c.initialize();
      c.setTitle('旧');
      c.setTitle('新');
      final discarded = c.discard();
      await Future<void>.delayed(Duration.zero);
      expect(store.saves, 1);
      expect(store.clears, 0);
      store.gate!.complete();
      expect(await discarded, isTrue);
      expect(store.saves, 2);
      expect(store.clears, 1);
      expect(store.value, isNull);
      c.dispose();
    },
  );
  test('save and clear failures keep input visible and retryable', () async {
    final store = FormDraftStore()..failSave = true;
    final c = controller(store);
    await c.initialize();
    c.setTitle('仍保留');
    expect(await c.flush(), isFalse);
    expect(c.storageError, contains('保存失败'));
    expect(c.title, '仍保留');
    store.failSave = false;
    expect(await c.retrySave(), isTrue);
    store.failClear = true;
    expect(await c.discard(), isFalse);
    expect(store.value!.title, '仍保留');
    expect(c.storageError, contains('无法放弃'));
    store.failClear = false;
    expect(await c.discard(), isTrue);
    c.dispose();
  });
  test(
    'known title uses trim and Unicode code points, unknown requires no name',
    () async {
      final c = controller(FormDraftStore());
      await c.initialize();
      c.setKnowledge(BlockKnowledgeState.known);
      c.setTitle(' \n ');
      expect(c.titleError, isNotNull);
      c.setTitle('🐾' * 200);
      expect(c.titleError, isNull);
      c.setTitle('🐾' * 201);
      expect(c.titleError, isNotNull);
      c.setKnowledge(BlockKnowledgeState.unknown);
      c.setTitle('');
      c.setTime(start: -1000000000000, end: 9000000000000);
      expect(c.valid, isTrue);
      c.setPrecision(end: TimePrecision.exact);
      c.setTime(start: 300, end: 200);
      expect(c.timeError, isNotNull);
      expect(c.time.endPrecision, TimePrecision.exact);
      await c.flush();
      c.dispose();
    },
  );

  test(
    'optional note accepts blank, preserves raw draft, and enforces 2000 runes',
    () async {
      final store = FormDraftStore();
      final c = controller(store);
      await c.initialize();
      c.setKnowledge(BlockKnowledgeState.unknown);
      c.setTime(start: 1, end: 2);
      expect(c.noteError, isNull);
      expect(c.valid, isTrue);
      c.setNote('🐾' * 2000);
      expect(c.noteError, isNull);
      c.setNote('🐾' * 2001);
      expect(c.noteError, isNotNull);
      expect(c.valid, isFalse);
      expect(await c.flush(), isTrue);
      expect(store.value!.note, '🐾' * 2001);
      expect(store.value!.noteProvided, isTrue);
      c.setNote(' \n ');
      expect(c.noteError, isNull);
      expect(await c.flush(), isTrue);
      c.dispose();
    },
  );
}
