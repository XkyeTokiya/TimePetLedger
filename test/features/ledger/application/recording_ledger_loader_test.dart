import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/recording_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

void main() {
  final date = CivilDate(year: 2026, month: 9, day: 27);
  final start = DateTime(2026, 9, 27).millisecondsSinceEpoch;
  final next = DateTime(2026, 9, 28).millisecondsSinceEpoch;

  test(
    'real snapshot includes all facts and explanations before E3 coverage',
    () async {
      final trace = LedgerReadTrace();
      final db = await AppDatabase.open(
        NativeDatabase.memory().interceptWith(trace),
      );
      addTearDown(db.close);
      await insertLedgerRow(db, 'goals', {
        'id': ledgerId,
        'name': '归档目标',
        'status': 'archived',
        'created_at': 1,
        'updated_at': 2,
        'archived_at': 2,
      });
      await insertLedgerRow(
        db,
        'sleep_sessions',
        sleepRow(start: start - hour, end: start + 7 * hour),
      );
      await insertLedgerRow(db, 'time_blocks', {
        ...blockRow(start: start + 8 * hour, end: start + 9 * hour),
        'goal_id': ledgerId,
      });
      await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
      await insertLedgerRow(db, 'time_blocks', {
        ...blockRow(
          id: secondLedgerId,
          start: start + 9 * hour,
          end: start + 10 * hour,
        ),
        'knowledge_state': 'unknown',
        'title': null,
      });
      await insertLedgerRow(db, 'sleep_sessions', {
        ...sleepRow(
          id: secondLedgerId,
          start: start + 11 * hour,
          end: start + 12 * hour,
        ),
        'sleep_type': 'nap',
      });
      // Earlier sleeping is outside W and does not enter coverage.
      await insertLedgerRow(
        db,
        'sleep_sessions',
        sleepRow(id: thirdLedgerId, start: start - 3 * hour, end: start - hour),
      );
      await insertLedgerRow(
        db,
        'time_blocks',
        blockRow(
          id: thirdLedgerId,
          start: start + 13 * hour,
          end: start + 15 * hour,
        ),
      );
      final loader = createRecordingLedgerLoader(db);
      trace.enabled = true;
      final result = await loader.load(date: date, now: start + 14 * hour);
      trace.enabled = false;
      expect(trace.readers, hasLength(3));
      expect(trace.readers.first, isA<TransactionExecutor>());
      expect(
        trace.readers.every((r) => identical(r, trace.readers.first)),
        isTrue,
      );
      expect(trace.commits, 1);
      expect(result.facts.timeBlocks, hasLength(3));
      expect(result.facts.sleepSessions, hasLength(2));
      expect(result.facts.annotations, hasLength(1));
      expect(result.facts.sleepSessions.first.startedAt, start - hour);
      expect(result.facts.timeBlocks.last.endedAt, start + 15 * hour);
      expect(
        result.segments.whereType<TimeBlockSegment>().first.annotation,
        isNotNull,
      );
      expect(result.coverage.accountedDuration.milliseconds, 11 * hour);
      expect(result.coverage.unknownDuration.milliseconds, hour);
      expect(result.coverage.unresolvedDuration.milliseconds, 3 * hour);
      expect(
        result.coverage.unresolvedSpans.map((g) => (g.startedAt, g.endedAt)),
        [
          (start + 7 * hour, start + 8 * hour),
          (start + 10 * hour, start + 11 * hour),
          (start + 12 * hour, start + 13 * hour),
        ],
      );
      expect(
        result.coverage.unresolvedSpans.first.startPrecision,
        TimePrecision.approximate,
      );
      expect(result.segments.last.endedAt, start + 14 * hour);
      expect(result.segments.last.endPrecision, TimePrecision.exact);
      expect(() => result.segments.clear(), throwsUnsupportedError);
      // A fresh read after a committed change updates gaps; prior result stays intact.
      await db.customStatement('DELETE FROM time_blocks WHERE id = ?', [
        secondLedgerId,
      ]);
      final refreshed = await loader.load(date: date, now: start + 16 * hour);
      expect(refreshed.coverage.unknownDuration.milliseconds, 0);
      expect(refreshed.coverage.accountedDuration.milliseconds, 11 * hour);
      expect(refreshed.coverage.unresolvedDuration.milliseconds, 5 * hour);
      expect(result.coverage.unknownDuration.milliseconds, hour);
    },
  );

  test(
    'empty ledger succeeds; historical, today, future and zero windows differ',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      final loader = createRecordingLedgerLoader(db);
      for (final sample in [
        (next, next - start),
        (start + hour + 1, hour + 1),
        (start - 1, 0),
        (start, 0),
      ]) {
        final result = await loader.load(date: date, now: sample.$1);
        expect(result.facts.timeBlocks, isEmpty);
        expect(result.coverage.accountedDuration.milliseconds, 0);
        expect(result.coverage.unresolvedDuration.milliseconds, sample.$2);
        expect(
          result.coverage.unresolvedSpans,
          hasLength(sample.$2 == 0 ? 0 : 1),
        );
      }
    },
  );

  test(
    'sleep alone covers time; a midnight wake does not cover this day',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await insertLedgerRow(
        db,
        'sleep_sessions',
        sleepRow(start: start - hour, end: start),
      );
      final loader = createRecordingLedgerLoader(db);
      final before = await loader.load(date: date, now: start + hour);
      expect(before.facts.sleepSessions, isEmpty);
      expect(before.coverage.unresolvedDuration.milliseconds, hour);
      await insertLedgerRow(
        db,
        'sleep_sessions',
        sleepRow(id: secondLedgerId, start: start, end: start + hour),
      );
      final after = await loader.load(date: date, now: start + hour);
      expect(after.coverage.accountedDuration.milliseconds, hour);
      expect(after.coverage.unresolvedSpans, isEmpty);
    },
  );

  test(
    'bad stored data fails whole load, never returns a gap-only fallback',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await insertLedgerRow(db, 'time_blocks', {
        ...blockRow(start: start, end: start + hour),
        'title': '  invalid  ',
      });
      await expectLater(
        createRecordingLedgerLoader(db).load(date: date, now: next),
        throwsA(isA<LedgerDataException>()),
      );
    },
  );

  test(
    'closed storage failure is distinct from successful empty ledger',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      final loader = createRecordingLedgerLoader(db);
      await db.close();
      await expectLater(
        loader.load(date: date, now: next),
        throwsA(isA<LedgerStorageException>()),
      );
    },
  );
}
