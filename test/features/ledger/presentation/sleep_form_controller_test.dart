import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_time_input.dart';

final sleepContext = SleepDraftContext.newEntry(
  date: CivilDate(year: 2026, month: 9, day: 29),
);

class FormSleepStore implements SleepDraftStore {
  SleepDraft? value;
  bool failRead = false, failSave = false, failClear = false;
  Completer<void>? readGate, writeGate;
  int reads = 0, saves = 0, clears = 0;
  @override
  Future<SleepDraft?> read(SleepDraftContext context) async {
    reads++;
    await readGate?.future;
    if (failRead) throw StateError('private SQL');
    return value;
  }

  @override
  Future<void> save(SleepDraft draft) async {
    saves++;
    await writeGate?.future;
    if (failSave) throw StateError('private SQL');
    value = draft;
  }

  @override
  Future<void> clear(SleepDraftContext context) async {
    clears++;
    if (failClear) throw StateError('private SQL');
    value = null;
  }
}

SleepFormController model(FormSleepStore store) =>
    SleepFormController(context: sleepContext, store: store);
void fill(SleepFormController c) {
  c.setType(SleepType.mainSleep);
  c.setStartedAtInput('2026-09-28 23:50');
  c.setEndedAtInput('2026-09-29 07:40');
  c.setPrecision(start: TimePrecision.approximate, end: TimePrecision.exact);
}

void main() {
  test(
    'manual sleep entry retains type/note without restoring old times',
    () async {
      final store = FormSleepStore();
      final first = model(store);
      await first.initialize();
      fill(first);
      first.setNote('手动补记');
      await first.flush();
      first.dispose();
      final second = SleepFormController(
        context: sleepContext,
        store: store,
        loadSuggestion: () async => const ManualTimeEntry(),
      );
      await second.initialize();
      expect((second.startedAt, second.endedAt), (null, null));
      expect(second.startedAtInput, isEmpty);
      expect(second.endedAtInput, isEmpty);
      expect(second.type, SleepType.mainSleep);
      expect(second.note, '手动补记');
      await second.flush();
      expect(store.value!.startedAt, isNull);
      second.dispose();
    },
  );

  test(
    'fresh sleep endpoints replace cached times and keep type/note',
    () async {
      final store = FormSleepStore();
      final first = model(store);
      await first.initialize();
      fill(first);
      first.setNote('昼夜颠倒');
      await first.flush();
      first.dispose();
      final second = SleepFormController(
        context: sleepContext,
        store: store,
        loadSuggestion: () async => const DirectTimeSuggestion(
          RecordingTimeInput(startedAt: 1000000, endedAt: 2800000),
        ),
      );
      await second.initialize();
      expect((second.startedAt, second.endedAt), (1000000, 2800000));
      expect(second.type, SleepType.mainSleep);
      expect(second.note, '昼夜颠倒');
      expect(second.startPrecision, TimePrecision.approximate);
      expect(await second.flush(), isTrue);
      expect(store.value!.endedAt, 2800000);
      second.setEndedAtInput('2026-09-29 19:40');
      await second.initialize();
      expect(second.endedAtInput, '2026-09-29 19:40');
      await second.flush();
      second.dispose();
    },
  );

  test(
    'incomplete text, type and independent precision restore without inference',
    () async {
      final store = FormSleepStore();
      final first = model(store);
      await first.initialize();
      expect(first.type, isNull);
      expect(first.startPrecision, isNull);
      expect(first.endPrecision, isNull);
      first.setStartedAtInput(' 2026-09-');
      first.setEndedAtInput('2026-09-29 07:40');
      first.setType(SleepType.nap);
      first.setPrecision(end: TimePrecision.exact);
      expect(await first.flush(), isTrue);
      first.dispose();
      final second = model(store);
      await second.initialize();
      expect(second.restored, isTrue);
      expect(second.startedAtInput, ' 2026-09-');
      expect(second.startedAt, isNull);
      expect(second.endedAtInput, '2026-09-29 07:40');
      expect(second.type, SleepType.nap);
      expect(second.startPrecision, isNull);
      expect(second.endPrecision, TimePrecision.exact);
      second.setStartedAtInput('2026-09-28 23:50');
      await second.initialize();
      expect(second.startedAtInput, '2026-09-28 23:50');
      expect(store.reads, 2); // no repeated restore over current user input
      await second.flush();
      second.dispose();
    },
  );

  test('read is exclusive, read failure never overwrites existing draft, retry restores', () async {
    final store = FormSleepStore()
      ..readGate = Completer<void>()
      ..failRead = true;
    final c = model(store);
    final loading = c.initialize();
    c.setType(SleepType.nap);
    expect(store.saves, 0);
    store.readGate!.complete();
    await loading;
    c.setStartedAtInput('2026-09-29 07:00');
    expect(c.loadError, isNotNull);
    expect(store.saves, 0);
    store.failRead = false;
    await c.initialize();
    fill(c);
    expect(await c.flush(), isTrue);
    c.dispose();
  });

  test('cross-day and unbounded positive intervals; changes preserve precision and chosen type', () async {
    final c = model(FormSleepStore());
    await c.initialize();
    fill(c);
    expect(c.valid, isTrue);
    expect(
      c.endedAt! - c.startedAt!,
      const Duration(hours: 7, minutes: 50).inMilliseconds,
    );
    c.setType(SleepType.nap);
    c.setEndedAtInput('2026-09-28 23:50');
    expect(c.timeError, isNotNull);
    c.setEndedAtInput('2026-09-28 20:00');
    expect(c.timeError, isNotNull);
    c.setStartedAtInput('1900-01-01 00:00');
    c.setEndedAtInput('2200-01-01 00:00');
    expect(c.valid, isTrue);
    expect(c.type, SleepType.nap);
    expect(c.startPrecision, TimePrecision.approximate);
    expect(c.endPrecision, TimePrecision.exact);
    c.setEndedAtInput('');
    expect(c.valid, isFalse);
    await c.flush();
    c.dispose();
  });

  test(
    'serialized autosave and discard cannot resurrect queued input',
    () async {
      final store = FormSleepStore()..writeGate = Completer<void>();
      final c = model(store);
      await c.initialize();
      c.setStartedAtInput('old');
      c.setStartedAtInput('new');
      final discard = c.discard();
      await Future<void>.delayed(Duration.zero);
      expect(store.saves, 1);
      expect(store.clears, 0);
      c.setStartedAtInput('ignored while discarding');
      store.writeGate!.complete();
      expect(await discard, isTrue);
      expect(store.saves, 2);
      expect(store.value, isNull);
      expect(store.clears, 1);
      expect(c.editable, isFalse);
      c.dispose();
    },
  );

  test('save/clear failures preserve input and retry succeeds', () async {
    final store = FormSleepStore()..failSave = true;
    final c = model(store);
    await c.initialize();
    fill(c);
    expect(await c.flush(), isFalse);
    expect(c.startedAtInput, '2026-09-28 23:50');
    expect(c.storageError, contains('保存失败'));
    store.failSave = false;
    expect(await c.retrySave(), isTrue);
    store.failClear = true;
    expect(await c.discard(), isFalse);
    expect(store.value!.type, SleepType.mainSleep);
    expect(c.storageError, contains('无法放弃'));
    store.failClear = false;
    expect(await c.discard(), isTrue);
    c.dispose();
  });

  test(
    'editing seeds full fact only if no saved draft, without mutating original',
    () async {
      final original = SleepSession(
        id: '00000000-0000-4000-8000-000000000001',
        startedAt: 123,
        endedAt: 456,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        createdAt: 1,
        updatedAt: 1,
      );
      final context = SleepDraftContext.edit(
        date: sleepContext.date,
        sleepSessionId: original.id,
      );
      final store = FormSleepStore();
      var c = SleepFormController(
        context: context,
        store: store,
        original: original,
      );
      await c.initialize();
      expect(c.startedAt, 123); // original milliseconds are not rounded on open
      c.setStartedAtInput('');
      c.setType(SleepType.nap);
      await c.flush();
      c.dispose();
      c = SleepFormController(
        context: context,
        store: store,
        original: original,
      );
      await c.initialize();
      expect(
        c.startedAt,
        isNull,
      ); // incomplete restored field isn't overwritten by original
      expect(c.type, SleepType.nap);
      expect(original.startedAt, 123);
      expect(original.type, SleepType.mainSleep);
      expect(original.updatedAt, 1);
      c.dispose();
    },
  );

  test(
    'minute parsing rejects invalid dates/seconds and preserves minute input',
    () {
      for (final bad in [
        '',
        '2026-02-30 10:00',
        '2026-09-29 24:00',
        '2026-09-29 10:60',
        '2026-09-29 10:00:01',
      ]) {
        expect(parseSleepTime(bad), isNull);
      }
      expect(
        formatSleepTime(parseSleepTime('2024-02-29 01:02')),
        '2024-02-29 01:02',
      );
    },
  );
}
