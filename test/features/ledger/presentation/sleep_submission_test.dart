import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import 'sleep_form_controller_test.dart'
    show FormSleepStore, sleepContext, fill;

class SubmissionRepository implements LedgerRepository {
  SubmissionRepository(this.inner);
  final LedgerRepository inner;
  Completer<void>? gate;
  int creates = 0;
  bool failCreate = false, failRecovery = false;
  @override
  Future<LedgerSnapshot> readWindow({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  }) {
    if (failRecovery) throw StateError('private recovery SQL');
    return inner.readWindow(startedAt: startedAt, endedAt: endedAt);
  }

  @override
  Future<SleepSession> createSleepSession({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required SleepType type,
    required InstantMilliseconds now,
    String? note,
  }) async {
    creates++;
    await gate?.future;
    if (failCreate) throw const LedgerStorageException('private SQL');
    return inner.createSleepSession(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      startPrecision: startPrecision,
      endPrecision: endPrecision,
      type: type,
      now: now,
      note: note,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SubmissionHarness {
  SubmissionHarness(this.db) {
    actual = DriftLedgerRepository(db);
    repository = SubmissionRepository(actual);
    loader = SleepLedgerLoader(
      repository: actual,
      resolveDate: resolveDeviceRecordingDate,
    );
    saver = SleepEntrySaver(
      repository: repository,
      drafts: store,
      newId: () => '00000000-0000-4000-8000-000000000001',
      now: () => DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      refresh: ({required date, required now}) async {
        if (failRefresh) throw StateError('private read SQL');
        return loader.load(date: date, now: now);
      },
    );
  }
  final AppDatabase db;
  final store = FormSleepStore();
  late final DriftLedgerRepository actual;
  late final SubmissionRepository repository;
  late final SleepLedgerLoader loader;
  late final SleepEntrySaver saver;
  bool failRefresh = false;
  SleepFormController controller() => SleepFormController(
    context: sleepContext,
    store: store,
    entrySaver: saver,
  );
}

void main() {
  late SubmissionHarness h;
  setUp(() async {
    h = SubmissionHarness(await AppDatabase.open(NativeDatabase.memory()));
  });
  tearDown(() => h.db.close());

  test('submit waits for queued drafts; locks input, discard and duplicate taps until commit', () async {
    final c = h.controller();
    addTearDown(c.dispose);
    await c.initialize();
    h.store.writeGate = Completer<void>();
    fill(c);
    h.repository.gate = Completer<void>();
    final pending = c.submit();
    expect(c.submitting, isTrue);
    expect(c.editable, isFalse);
    expect(await c.submit(), isNull);
    expect(await c.discard(), isFalse);
    c.setType(SleepType.nap);
    expect(c.type, SleepType.mainSleep);
    await Future<void>.delayed(Duration.zero);
    expect(h.repository.creates, 0);
    h.store.writeGate!.complete();
    await c.flush();
    await Future<void>.delayed(Duration.zero);
    expect(h.repository.creates, 1);
    h.repository.gate!.complete();
    final result = await pending;
    expect(result!.coverage.accountedDuration.roundedMinutes, 460);
    expect(result.sleepSummary.mainSleep.records, hasLength(1));
    expect(c.committed!.complete, isTrue);
    expect(h.store.value, isNull);
    expect(await c.submit(), isNull);
    expect(await c.retryFinish(), isNull);
    expect(h.repository.creates, 1);
  });

  test('invalid input, draft failure and formal failure retain inputs without claiming commit', () async {
    final c = h.controller();
    addTearDown(c.dispose);
    await c.initialize();
    expect(await c.submit(), isNull);
    expect(h.repository.creates, 0);
    h.store.failSave = true;
    fill(c);
    expect(await c.submit(), isNull);
    expect(h.repository.creates, 0);
    expect(c.storageError, isNotNull);
    h.store.failSave = false;
    await c.retrySave();
    h.repository.failCreate = true;
    expect(await c.submit(), isNull);
    expect(c.committed, isNull);
    expect(c.submitError, contains('正式保存失败'));
    expect(c.submitError, isNot(contains('private')));
    expect(c.editable, isTrue);
    expect(h.store.value!.endedAt, c.endedAt);
  });

  test('reopening residual draft recognizes the committed fact; recovery read failure blocks input until retry', () async {
    h.store.failClear = true;
    final first = h.controller();
    await first.initialize();
    fill(first);
    expect(await first.submit(), isNull);
    expect(first.committed!.refreshed, isNotNull);
    first.dispose();
    h.repository.failRecovery = true;
    final second = h.controller();
    addTearDown(second.dispose);
    await second.initialize();
    expect(second.loadError, isNotNull);
    expect(second.editable, isFalse);
    expect(await second.submit(), isNull);
    h.repository.failRecovery = false;
    h.store.failClear = false;
    await second.initialize();
    expect(second.committed!.complete, isTrue);
    expect(second.editable, isFalse);
    expect(h.repository.creates, 1);
    expect(h.store.value, isNull);
  });
}
