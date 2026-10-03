import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/sleep_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/presentation/summary_formatting.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

Future<void> sleep(
  AppDatabase db,
  int n,
  int start,
  int end, {
  bool nap = false,
}) => insertLedgerRow(db, 'sleep_sessions', {
  ...sleepRow(id: id(n), start: start, end: end),
  'sleep_type': nap ? 'nap' : 'mainSleep',
  'start_precision': 'approximate',
  'end_precision': 'exact',
});

void main() {
  final date = CivilDate(year: 2026, month: 9, day: 29);
  final start = DateTime(2026, 9, 29).millisecondsSinceEpoch;
  final next = DateTime(2026, 9, 30).millisecondsSinceEpoch;

  test(
    'one real transaction supplies window and all wake-date candidates',
    () async {
      final trace = LedgerReadTrace();
      final db = await AppDatabase.open(
        NativeDatabase.memory().interceptWith(trace),
      );
      addTearDown(db.close);
      await sleep(
        db,
        1,
        start - 2 * hour,
        start,
      ); // Midnight, no W intersection.
      await sleep(db, 2, start, start + 7 * hour);
      await sleep(db, 3, start + 10 * hour, start + 12 * hour); // Daytime main.
      await sleep(db, 4, start + 13 * hour, start + 14 * hour, nap: true);
      await sleep(db, 5, start + 15 * hour, start + 17 * hour); // Future end.
      await sleep(db, 6, start + 23 * hour, next); // Next day's summary.
      await sleep(db, 7, start - 4 * hour, start - 3 * hour); // Other wake day.
      await insertLedgerRow(
        db,
        'time_blocks',
        blockRow(start: start + 8 * hour, end: start + 9 * hour),
      );
      await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
      trace.enabled = true;
      final result = await createSleepLedgerLoader(db)
          .load(date: date, now: start + 16 * hour);
      trace.enabled = false;
      expect(trace.readers, hasLength(4));
      expect(trace.readers.first, isA<TransactionExecutor>());
      expect(
        trace.readers.every((r) => identical(r, trace.readers.first)),
        isTrue,
      );
      expect(trace.commits, 1);
      expect(result.facts.windowFacts.sleepSessions.map((s) => s.id), [
        id(2),
        id(3),
        id(4),
        id(5),
      ]);
      expect(result.facts.sleepSummaryCandidates.map((s) => s.id), [
        id(1),
        id(2),
        id(3),
        id(4),
        id(5),
      ]);
      expect(result.sleepSummary.mainSleep.records.map((s) => s.id), [
        id(1),
        id(2),
        id(3),
        id(5),
      ]);
      expect(
        result.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
        13 * hour,
      );
      expect(result.sleepSummary.nap.totalDuration.duration.milliseconds, hour);
      expect(
        result.segments.whereType<TimeBlockSegment>().single.annotation,
        isNotNull,
      );
      expect(result.coverage.accountedDuration.milliseconds, 12 * hour);
      expect(result.coverage.unresolvedDuration.milliseconds, 4 * hour);
      expect(result.recordedMainSleepToday, isTrue);
      for (final item in result.facts.windowFacts.sleepSessions) {
        final candidate = result.facts.sleepSummaryCandidates.singleWhere(
          (s) => s.id == item.id,
        );
        expect(
          (
            item.startedAt,
            item.endedAt,
            item.startPrecision,
            item.endPrecision,
            item.updatedAt,
          ),
          (
            candidate.startedAt,
            candidate.endedAt,
            candidate.startPrecision,
            candidate.endPrecision,
            candidate.updatedAt,
          ),
        );
      }
      expect(
        () => result.facts.sleepSummaryCandidates.clear(),
        throwsUnsupportedError,
      );
      final historical = await createSleepLedgerLoader(db)
          .load(date: date, now: next);
      expect(historical.facts.windowFacts.sleepSessions.last.id, id(6));
      expect(
        historical.sleepSummary.mainSleep.records.map((s) => s.id),
        isNot(contains(id(6))),
      );
      expect(historical.recordedMainSleepToday, isNull);
    },
  );

  test('cross-day full duration and approximation differ from slice', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(db.close);
    await sleep(db, 1, start - hour, start + 7 * hour);
    final result = await createSleepLedgerLoader(db)
        .load(date: date, now: start + 8 * hour);
    expect(
      result.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
      8 * hour,
    );
    expect(
      result.sleepSummary.mainSleep.totalDuration.duration.hasApproximation,
      isTrue,
    );
    expect(result.coverage.accountedDuration.milliseconds, 7 * hour);
    expect(result.coverage.accountedDuration.hasApproximation, isFalse);
  });

  test('nap and future main do not suppress; refresh at end does', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(db.close);
    await sleep(db, 1, start, start + hour, nap: true);
    await sleep(db, 2, start + 2 * hour, start + 4 * hour);
    final loader = createSleepLedgerLoader(db);
    final before = await loader.load(date: date, now: start + 4 * hour - 1);
    expect(before.sleepSummary.mainSleep.totalDuration.hasRecords, isTrue);
    expect(before.recordedMainSleepToday, isFalse);
    final after = await loader.load(date: date, now: start + 4 * hour);
    expect(after.recordedMainSleepToday, isTrue);
    expect(before.recordedMainSleepToday, isFalse);
  });

  test(
    'midnight and future empty windows still read complete summary',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await sleep(db, 1, start - hour, start);
      for (final now in [start - 1, start]) {
        final result = await createSleepLedgerLoader(db)
            .load(date: date, now: now);
        expect(result.segments, isEmpty);
        expect(result.coverage.unresolvedSpans, isEmpty);
        expect(
          result.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
          hour,
        );
        expect(result.recordedMainSleepToday, now == start ? isTrue : isNull);
      }
    },
  );

  test(
    'successful absence is distinct from failed reads even for empty W',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      final loader = createSleepLedgerLoader(db);
      for (final sample in [
        (start - 1, 0),
        (start, 0),
        (start + hour, hour),
        (next, next - start),
      ]) {
        final result = await loader.load(date: date, now: sample.$1);
        expect(result.coverage.unresolvedDuration.milliseconds, sample.$2);
        expect(result.sleepSummary.mainSleep.totalDuration.hasRecords, isFalse);
        expect(
          formatSummaryDuration(
            result.sleepSummary.mainSleep.totalDuration,
            kind: SummaryDurationKind.mainSleep,
          ),
          '尚未记录主睡眠',
        );
      }
      await db.close();
      for (final now in [start - 1, start, next]) {
        await expectLater(
          loader.load(date: date, now: now),
          throwsA(isA<LedgerStorageException>()),
        );
      }
    },
  );

  test('bad summary-only row fails whole read and rolls back', () async {
    final trace = LedgerReadTrace();
    final db = await AppDatabase.open(
      NativeDatabase.memory().interceptWith(trace),
    );
    addTearDown(db.close);
    await insertLedgerRow(db, 'sleep_sessions', {
      ...sleepRow(start: start - hour, end: start),
      'note': ' unnormalized ',
    });
    trace.enabled = true;
    await expectLater(
      createSleepLedgerLoader(db).load(date: date, now: start + hour),
      throwsA(isA<LedgerDataException>()),
    );
    trace.enabled = false;
    expect(trace.commits, 0);
    expect(trace.rollbacks, 1);
  });

  test(
    'query rejects reversed day or window and window outside date',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = DriftLedgerRepository(db);
      for (final bounds in [
        (start, start, next, start),
        (start + 1, start, start, next),
        (start - 1, start, start, next),
        (start, next + 1, start, next),
      ]) {
        await expectLater(
          repository.readSleepContext(
            startedAt: bounds.$1,
            endedAt: bounds.$2,
            dayStartedAt: bounds.$3,
            nextDayStartedAt: bounds.$4,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'real device DST calendar with real database preserves full durations',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      for (final sample in [(3, 8, 23), (11, 1, 25)]) {
        final day = CivilDate(year: 2026, month: sample.$1, day: sample.$2);
        final from = DateTime(
          2026,
          sample.$1,
          sample.$2,
        ).millisecondsSinceEpoch;
        final until = DateTime(
          2026,
          sample.$1,
          sample.$2 + 1,
        ).millisecondsSinceEpoch;
        await sleep(db, sample.$1, from - hour, until - hour);
        final result = await createSleepLedgerLoader(db)
            .load(date: day, now: until);
        expect(
          result.context.nextDayStartedAt - result.context.dayStartedAt,
          sample.$3 * hour,
        );
        expect(
          result.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
          sample.$3 * hour,
        );
        expect(
          result.coverage.accountedDuration.milliseconds,
          (sample.$3 - 1) * hour,
        );
        expect(result.coverage.unresolvedDuration.milliseconds, hour);
      }
    },
    skip: Platform.environment['TZ'] != 'America/New_York',
  );
}
