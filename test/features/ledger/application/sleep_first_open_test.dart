import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/sleep_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_first_open.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

final day = CivilDate(year: 2026, month: 9, day: 30);
final start = DateTime(2026, 9, 30).millisecondsSinceEpoch;
const hour = 3600000;
const sleepId = '00000000-0000-4000-8000-000000000001';

Future<void> addSleep(
  DriftLedgerRepository repo, {
  SleepType type = SleepType.mainSleep,
  int? end,
}) async {
  await repo.createSleepSession(
    id: sleepId,
    startedAt: start - hour,
    endedAt: end ?? start + 7 * hour,
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: type,
    now: 1,
  );
}

void main() {
  late AppDatabase db;
  late DriftSleepOpeningStore openings;
  late DriftLedgerRepository repo;
  late SleepFirstOpenCoordinator coordinator;
  setUp(() async {
    db = await AppDatabase.open(NativeDatabase.memory());
    openings = await DriftSleepOpeningStore.open(NativeDatabase.memory());
    repo = DriftLedgerRepository(db);
    coordinator = SleepFirstOpenCoordinator(
      ledger: createSleepLedgerLoader(db),
      claimOpening: openings.claim,
    );
  });
  tearDown(() async {
    await db.close();
    await openings.close();
  });

  test('first empty opening confirms once; same date never asks again; new natural date does', () async {
    final first = await coordinator.check(date: day, now: start + 12 * hour);
    expect(first.shouldConfirm, isTrue);
    expect(first.ledger.recordedMainSleepToday, isFalse);
    expect(
      (await coordinator.check(
        date: day,
        now: start + 13 * hour,
      )).shouldConfirm,
      isFalse,
    );
    final next = CivilDate(year: 2026, month: 10, day: 1);
    expect(
      (await coordinator.check(
        date: next,
        now: DateTime(2026, 10, 1).millisecondsSinceEpoch,
      )).shouldConfirm,
      isTrue,
    );
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ]) {
      expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
    }
  });

  test(
    'completed main sleep including midnight suppresses first opening',
    () async {
      await addSleep(repo, end: start);
      final first = await coordinator.check(date: day, now: start);
      expect(first.shouldConfirm, isFalse);
      expect(first.ledger.recordedMainSleepToday, isTrue);
      await repo.deleteSleepSession(sleepId);
      final after = await coordinator.check(date: day, now: start + hour);
      expect(after.ledger.recordedMainSleepToday, isFalse);
      expect(after.shouldConfirm, isFalse);
    },
  );

  for (final type in [SleepType.nap, SleepType.mainSleep]) {
    test('$type does not suppress when nap or not yet ended', () async {
      await addSleep(repo, type: type, end: start + 14 * hour);
      final first = await coordinator.check(date: day, now: start + 12 * hour);
      expect(first.shouldConfirm, isTrue);
      expect(first.ledger.recordedMainSleepToday, isFalse);
      final after = await coordinator.check(date: day, now: start + 14 * hour);
      expect(after.ledger.recordedMainSleepToday, type == SleepType.mainSleep);
      expect(after.shouldConfirm, isFalse);
    });
  }

  test('editing type and wake date uses new formal facts without repeated prompting', () async {
    await addSleep(repo);
    expect(
      (await coordinator.check(
        date: day,
        now: start + 12 * hour,
      )).shouldConfirm,
      isFalse,
    );
    await repo.updateSleepSession(id: sleepId, now: 2, type: SleepType.nap);
    var result = await coordinator.check(date: day, now: start + 12 * hour);
    expect(result.ledger.recordedMainSleepToday, isFalse);
    expect(result.shouldConfirm, isFalse);
    await repo.updateSleepSession(
      id: sleepId,
      now: 3,
      type: SleepType.mainSleep,
      startedAt: start - 2 * hour,
      endedAt: start - hour,
    );
    result = await coordinator.check(date: day, now: start + 12 * hour);
    expect(result.ledger.recordedMainSleepToday, isFalse);
    expect(result.shouldConfirm, isFalse);
  });

  test(
    'formal read failure does not claim a date or masquerade as missing sleep',
    () async {
      await addSleep(repo);
      await db.customStatement("PRAGMA ignore_check_constraints = ON");
      await db.customStatement(
        "UPDATE sleep_sessions SET sleep_type = 'broken'",
      );
      await expectLater(
        coordinator.check(date: day, now: start + 12 * hour),
        throwsA(anything),
      );
      await db.customStatement("UPDATE sleep_sessions SET sleep_type = 'nap'");
      expect(
        (await coordinator.check(
          date: day,
          now: start + 12 * hour,
        )).shouldConfirm,
        isTrue,
      );
    },
  );

  test(
    'marker failure propagates and retry can still be the first opening',
    () async {
      var fails = true;
      final retryable = SleepFirstOpenCoordinator(
        ledger: createSleepLedgerLoader(db),
        claimOpening: (date) {
          if (fails) throw StateError('private storage diagnostic');
          return openings.claim(date);
        },
      );
      await expectLater(
        retryable.check(date: day, now: start + hour),
        throwsStateError,
      );
      fails = false;
      expect(
        (await retryable.check(date: day, now: start + hour)).shouldConfirm,
        isTrue,
      );
      expect(
        (await retryable.check(date: day, now: start + hour)).shouldConfirm,
        isFalse,
      );
    },
  );

  test('existing incomplete/new/edit drafts never count as facts and remain untouched', () async {
    final drafts = await DriftSleepDraftStore.open(NativeDatabase.memory());
    addTearDown(drafts.close);
    final newContext = SleepDraftContext.newEntry(date: day);
    final editContext = SleepDraftContext.edit(
      date: day,
      sleepSessionId: sleepId,
    );
    for (final context in [newContext, editContext]) {
      await drafts.save(
        SleepDraft(
          context: context,
          startedAt: null,
          endedAt: null,
          startPrecision: TimePrecision.approximate,
          endPrecision: null,
          type: SleepType.nap,
          startedAtInput: '尚未输入完',
        ),
      );
    }
    final first = await coordinator.check(date: day, now: start + hour);
    expect(first.shouldConfirm, isTrue);
    for (final context in [newContext, editContext]) {
      final draft = await drafts.read(context);
      expect(draft!.startedAtInput, '尚未输入完');
      expect(draft.type, SleepType.nap);
      expect(draft.endPrecision, isNull);
    }
  });

  test('timezone change recomputes today and wake-date membership from unchanged absolute facts', () async {
    final absoluteNow = DateTime.utc(2026, 9, 30, 1).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 29, 18).millisecondsSinceEpoch;
    await repo.createSleepSession(
      id: sleepId,
      startedAt: end - hour,
      endedAt: end,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 1,
    );
    var offset = 0;
    final loader = SleepLedgerLoader(
      repository: repo,
      resolveDate: ({required date, required now}) {
        final from =
            DateTime.utc(
              date.year,
              date.month,
              date.day,
            ).millisecondsSinceEpoch -
            offset * hour;
        final until =
            DateTime.utc(
              date.year,
              date.month,
              date.day + 1,
            ).millisecondsSinceEpoch -
            offset * hour;
        return RecordingDateContext(
          date: date,
          relation: LedgerDateRelation.today,
          now: now,
          dayStartedAt: from,
          nextDayStartedAt: until,
        );
      },
    );
    final changingZone = SleepFirstOpenCoordinator(
      ledger: loader,
      claimOpening: openings.claim,
    );
    expect(
      (await changingZone.check(date: day, now: absoluteNow)).shouldConfirm,
      isTrue,
    );
    offset = -8;
    final westDate = CivilDate(year: 2026, month: 9, day: 29);
    final western = await changingZone.check(date: westDate, now: absoluteNow);
    expect(western.ledger.recordedMainSleepToday, isTrue);
    expect(western.shouldConfirm, isFalse);
    expect((await repo.readSleepSession(sleepId))!.endedAt, end);
    offset = 0;
    expect(
      (await changingZone.check(date: day, now: absoluteNow)).shouldConfirm,
      isFalse,
    );
  });

  test('historical date cannot claim an opening', () async {
    await expectLater(
      coordinator.check(date: day, now: start - 1),
      throwsArgumentError,
    );
    expect(
      (await coordinator.check(date: day, now: start)).shouldConfirm,
      isTrue,
    );
  });

  test('file marker survives close/reopen and concurrent first checks have one winner', () async {
    await openings.close();
    final dir = await Directory.systemTemp.createTemp('sleep_opening_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/openings.sqlite');
    var store = await DriftSleepOpeningStore.open(NativeDatabase(file));
    final claims = await Future.wait([store.claim(day), store.claim(day)]);
    expect(claims.where((first) => first).length, 1);
    await store.close();
    store = await DriftSleepOpeningStore.open(NativeDatabase(file));
    expect(await store.claim(day), isFalse);
    expect(await store.claim(CivilDate(year: 2026, month: 10, day: 1)), isTrue);
    await store.close();
    await expectLater(store.claim(day), throwsA(anything));
  });
  test(
    'real marker write failure leaves date unclaimed; bad storage cannot open',
    () async {
      await openings.close();
      final dir = await Directory.systemTemp.createTemp(
        'sleep_opening_failure_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/markers.sqlite');
      final store = await DriftSleepOpeningStore.open(NativeDatabase(file));
      final probe = _Probe(NativeDatabase(file));
      await probe.customStatement(
        "CREATE TRIGGER reject_opening BEFORE INSERT ON sleep_openings BEGIN SELECT RAISE(ABORT, 'test write failure'); END",
      );
      await expectLater(
        store.claim(day),
        throwsA(isA<SleepOpeningStorageException>()),
      );
      expect(
        await probe.customSelect('SELECT * FROM sleep_openings').get(),
        isEmpty,
      );
      await probe.customStatement('DROP TRIGGER reject_opening');
      expect(await store.claim(day), isTrue);
      await store.close();
      await probe.customStatement('PRAGMA user_version = 2');
      await probe.close();
      await expectLater(
        DriftSleepOpeningStore.open(NativeDatabase(file)),
        throwsA(isA<SleepOpeningStorageException>()),
      );
      await expectLater(
        DriftSleepOpeningStore.open(NativeDatabase(File(dir.path))),
        throwsA(isA<SleepOpeningStorageException>()),
      );
    },
  );
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
