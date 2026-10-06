import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/app/time/device_sleep_prediction_calendar.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_time_prediction_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final date = CivilDate(year: 2026, month: 10, day: 7);
void main() {
  late AppDatabase db;
  late DriftLedgerRepository repo;
  late DriftSleepDraftStore drafts;
  late SleepTimePredictionLoader loader;
  setUp(() async {
    db = await AppDatabase.open(NativeDatabase.memory());
    drafts = await DriftSleepDraftStore.open(NativeDatabase.memory());
    repo = DriftLedgerRepository(db);
    loader = SleepTimePredictionLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
      calendar: const DeviceSleepPredictionCalendar(),
    );
  });
  tearDown(() async {
    await drafts.close();
    await db.close();
  });
  Future<void> block(int n, int start, int end) => repo
      .createTimeBlock(
        id: id(n),
        startedAt: start,
        endedAt: end,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.unknown,
        now: at(7, 6, 54),
      )
      .then((_) {});
  test('screenshot context initializes cache, keeps old gaps, and records feedback after commit', () async {
    await block(1, at(4, 21), at(4, 22, 13));
    final context = SleepDraftContext.newEntry(date: date);
    await drafts.save(
      SleepDraft(
        context: context,
        startedAt: at(4, 22, 13),
        endedAt: at(7, 6, 54),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        note: '保留备注',
        noteProvided: true,
      ),
    );
    var now = at(7, 6, 54);
    var loads = 0;
    final ledger = SleepLedgerLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
    );
    final saver = SleepEntrySaver(
      repository: repo,
      drafts: drafts,
      learning: drafts,
      offsetMinutes: const DeviceSleepPredictionCalendar().offsetMinutes,
      refresh: ledger.load,
      newId: () => id(3),
      now: () => now,
    );
    final c = SleepFormController(
      context: context,
      store: drafts,
      entrySaver: saver,
      loadPredictions: () {
        loads++;
        return loader.load(date: date, now: now, learning: drafts);
      },
    );
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.loadError, isNull);
    expect((c.startedAt, c.endedAt), (at(6, 23), at(7, 7)));
    expect(c.note, '保留备注');
    expect(await c.flush(), isTrue);
    final cached = (await drafts.read(context))!;
    expect((cached.startedAt, cached.endedAt), (at(6, 23), at(7, 7)));
    expect(cached.predictionOrigin!.startedAt, at(6, 23));
    expect(await drafts.readSleepFeedback(), isEmpty);
    expect((await repo.readSleepHistory(now: now)), isEmpty);
    now = at(7, 12);
    await c.initialize();
    expect(loads, 1);
    expect(c.endedAt, at(7, 7));
    final view = await c.submit();
    expect(view, isNotNull);
    expect(c.submitError, isNull);
    expect(view!.facts.windowFacts.sleepSessions.single.id, id(3));
    expect(view.coverage.unknownDuration.milliseconds, 0);
    final feedback = (await drafts.readSleepFeedback()).single;
    expect((feedback.startedAt, feedback.endedAt), (at(6, 23), at(7, 7)));
    expect(await drafts.read(context), isNull);
    final past = await ledger.load(
      date: CivilDate(year: 2026, month: 10, day: 5),
      now: now,
    );
    expect(past.coverage.unresolvedSpans.single.startedAt, at(5, 0));
    expect(past.coverage.unresolvedSpans.single.endedAt, at(6, 0));
  });
  test('type switch uses the fixed entry snapshot; manual endpoints then remain intact', () async {
    var now = at(7, 15, 20);
    var loads = 0;
    final c = SleepFormController(
      context: SleepDraftContext.newEntry(date: date),
      store: drafts,
      loadPredictions: () {
        loads++;
        return loader.load(date: date, now: now, learning: drafts);
      },
    );
    addTearDown(c.dispose);
    await c.initialize();
    now = at(7, 18);
    c.setType(SleepType.nap);
    expect((c.startedAt, c.endedAt), (at(7, 14, 50), at(7, 15, 20)));
    c.setType(SleepType.mainSleep);
    expect((c.startedAt, c.endedAt), (at(6, 23), at(7, 7)));
    c.setTime(start: at(6, 10), end: at(7, 14));
    c.setType(SleepType.nap);
    expect((c.startedAt, c.endedAt), (at(6, 10), at(7, 14)));
    expect(c.valid, isTrue);
    expect(loads, 1);
    expect(await c.flush(), isTrue);
  });
  test('full history learns daytime sleep after a long break, excludes future observations', () async {
    for (var i = 0; i < 8; i++) {
      await repo.createSleepSession(
        id: id(i + 1),
        startedAt: at(-50 + i, 10),
        endedAt: at(-50 + i, 18),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        now: at(7, 12),
      );
    }
    await repo.createSleepSession(
      id: id(99),
      startedAt: at(8, 23),
      endedAt: at(9, 7),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      type: SleepType.mainSleep,
      now: at(7, 12),
    );
    expect(await repo.readSleepHistory(now: at(7, 19)), hasLength(8));
    final p = await loader.load(date: date, now: at(7, 19), learning: drafts);
    expect(
      (p.mainSleep.startedAt, p.mainSleep.endedAt),
      (at(7, 10), at(7, 18)),
    );
  });
  test('post-commit feedback failure preserves draft and recovers without another formal write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sleep_prediction_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/drafts.sqlite');
    final store = await DriftSleepDraftStore.open(NativeDatabase(file));
    var storeClosed = false;
    addTearDown(() async {
      if (!storeClosed) await store.close();
    });
    final context = SleepDraftContext.newEntry(date: date);
    var writes = 0;
    final ledger = SleepLedgerLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
    );
    SleepEntrySaver saver(DriftSleepDraftStore s) => SleepEntrySaver(
      repository: repo,
      drafts: s,
      learning: s,
      offsetMinutes: const DeviceSleepPredictionCalendar().offsetMinutes,
      refresh: ledger.load,
      now: () => at(7, 12),
      newId: () {
        writes++;
        return id(30);
      },
    );
    final c = SleepFormController(
      context: context,
      store: store,
      entrySaver: saver(store),
      loadPredictions: () =>
          loader.load(date: date, now: at(7, 12), learning: store),
    );
    await c.initialize();
    c.setType(SleepType.mainSleep);
    await c.flush();
    final probe = _Probe(NativeDatabase(file));
    await probe.customStatement(
      "CREATE TRIGGER reject_feedback BEFORE INSERT ON sleep_learning_feedback BEGIN SELECT RAISE(ABORT,'test'); END",
    );
    expect(await c.submit(), isNull);
    expect(c.committed, isNotNull);
    expect(c.committed!.draftCleared, isFalse);
    expect(await store.read(context), isNotNull);
    expect(await store.readSleepFeedback(), isEmpty);
    c.dispose();
    await store.close();
    storeClosed = true;
    await probe.customStatement('DROP TRIGGER reject_feedback');
    await probe.close();
    final reopened = await DriftSleepDraftStore.open(NativeDatabase(file));
    addTearDown(reopened.close);
    var predictions = 0;
    final recovery = SleepFormController(
      context: context,
      store: reopened,
      entrySaver: saver(reopened),
      loadPredictions: () {
        predictions++;
        return loader.load(date: date, now: at(7, 12), learning: reopened);
      },
    );
    addTearDown(recovery.dispose);
    await recovery.initialize();
    expect(recovery.committed!.complete, isTrue);
    expect(predictions, 0);
    expect(writes, 1);
    expect((await repo.readSleepHistory(now: at(7, 12))), hasLength(1));
    expect((await reopened.readSleepFeedback()).single.sleepId, id(30));
    expect(await reopened.read(context), isNull);
    await reopened.clearAll();
    expect(await reopened.readSleepFeedback(), isEmpty);
  });
  test('storage failure is not treated as an empty history or successful prediction', () async {
    await db.close();
    await expectLater(
      loader.load(date: date, now: at(7, 12), learning: drafts),
      throwsA(isA<LedgerStorageException>()),
    );
  });
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
