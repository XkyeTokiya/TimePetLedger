import 'dart:io';
import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

void main() {
  final date = CivilDate(year: 2026, month: 9, day: 30);
  final start = DateTime(2026, 9, 30).millisecondsSinceEpoch;

  test(
    'complete projection uses one real read transaction, keeps original facts',
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
      await insertLedgerRow(db, 'time_blocks', {
        ...blockRow(start: start + 8 * hour, end: start + 10 * hour),
        'goal_id': ledgerId,
      });
      await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
      await insertLedgerRow(
        db,
        'sleep_sessions',
        sleepRow(start: start - hour, end: start + 7 * hour),
      );
      final before = await db.customSelect('SELECT * FROM time_blocks').get();
      trace.enabled = true;
      final view = await createDayLedgerLoader(db)
          .load(date: date, now: start + 9 * hour);
      trace.enabled = false;
      expect(trace.readers, hasLength(5));
      expect(trace.readers.every((r) => r is TransactionExecutor), isTrue);
      expect(
        trace.readers.take(4).every((r) => identical(r, trace.readers.first)),
        isTrue,
      );
      expect(view.accountedDuration.milliseconds, 8 * hour);
      expect(view.unresolvedDuration.milliseconds, hour);
      expect(view.sleepSummary.mainSleep.totalDuration.milliseconds, 8 * hour);
      expect(view.goalSummaries.single.name, '归档目标');
      final facts = await createDayLedgerLoader(db).readFacts(
        resolveDeviceRecordingDate(date: date, now: start + 9 * hour),
      );
      final expected = projectDayLedgerView(
        date: date,
        relation: resolveDeviceRecordingDate(
          date: date,
          now: start + 9 * hour,
        ).relation,
        dayStartedAt: start,
        nextDayStartedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
        now: start + 9 * hour,
        timeBlocks: facts.ledger.windowFacts.timeBlocks,
        windowSleepSessions: facts.ledger.windowFacts.sleepSessions,
        annotations: facts.ledger.windowFacts.annotations,
        sleepSummaryCandidates: facts.ledger.sleepSummaryCandidates,
        goals: facts.goals,
      );
      expect(
        view.goalSummaries.single.totalDuration.milliseconds,
        expected.goalSummaries.single.totalDuration.milliseconds,
      );
      expect(
        facts.ledger.windowFacts.timeBlocks.single.endedAt,
        start + 10 * hour,
      );
      expect(
        facts.ledger.windowFacts.sleepSessions.single.startedAt,
        start - hour,
      );
      expect(
        (await db.customSelect('SELECT * FROM time_blocks').get()).single.data,
        before.single.data,
      );
    },
  );

  test(
    'outer read transaction protects Goal metadata from another connection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'day_ledger_snapshot_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/ledger.sqlite');
      final gate = _GoalReadGate();
      final reader = await AppDatabase.open(
        NativeDatabase(file).interceptWith(gate),
      );
      final writer = await AppDatabase.open(NativeDatabase(file));
      addTearDown(reader.close);
      addTearDown(writer.close);
      await insertLedgerRow(writer, 'goals', {
        'id': ledgerId,
        'name': 'before',
        'status': 'active',
        'created_at': 1,
        'updated_at': 1,
      });
      await insertLedgerRow(writer, 'time_blocks', {
        ...blockRow(start: start, end: start + hour),
        'goal_id': ledgerId,
      });
      await insertLedgerRow(
        writer,
        'sleep_sessions',
        sleepRow(start: start - hour, end: start),
      );
      await insertLedgerRow(writer, 'rhythm_annotations', annotationRow());
      await writer.customStatement('PRAGMA busy_timeout = 0');
      Future<void> change() => writer.transaction(() async {
        await writer.customStatement("UPDATE goals SET name = 'after'");
        await writer.customStatement("UPDATE time_blocks SET title = 'after'");
        await writer.customStatement(
          "UPDATE sleep_sessions SET note = 'after'",
        );
        await writer.customStatement(
          "UPDATE rhythm_annotations SET state = 'stuck'",
        );
      });
      gate.enabled = true;
      final pending = createDayLedgerLoader(reader)
          .load(date: date, now: start + 2 * hour);
      try {
        await gate.read.future.timeout(const Duration(seconds: 5));
        await expectLater(
          change(),
          throwsA(
            predicate<Object>(
              (e) => e.toString().contains('database is locked'),
            ),
          ),
        );
      } finally {
        gate.release.complete();
      }
      final before = await pending;
      expect(before.goalSummaries.single.name, 'before');
      expect(before.rhythmSummary.progressDuration.milliseconds, hour);
      expect(before.sleepSummary.mainSleep.records.single.note, isNull);
      await change();
      final after = await createDayLedgerLoader(reader)
          .load(date: date, now: start + 2 * hour);
      expect(after.goalSummaries.single.name, 'after');
      expect(after.rhythmSummary.stuckDuration.milliseconds, hour);
      expect(after.sleepSummary.mainSleep.records.single.note, 'after');
      expect(before.goalSummaries.single.name, 'before');
    },
  );

  test('empty history, today, future and midnight preserve window semantics; closed storage fails even with empty W', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    final loader = createDayLedgerLoader(db);
    for (final sample in [
      (start + 2 * 24 * hour, 24 * hour),
      (start + 12 * hour, 12 * hour),
      (start - hour, 0),
      (start, 0),
    ]) {
      final view = await loader.load(date: date, now: sample.$1);
      expect(view.unresolvedDuration.milliseconds, sample.$2);
      expect(view.unresolvedSpans.length, sample.$2 == 0 ? 0 : 1);
    }
    await db.close();
    await expectLater(
      loader.load(date: date, now: start - hour),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'controller and real device adapter honor 23/25 hour days and local today',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      var instant = DateTime.utc(2026, 12, 1).millisecondsSinceEpoch;
      final controller = DayLedgerController(
        loader: createDayLedgerLoader(db),
        now: () => instant,
        dateOfInstant: deviceDateOfInstant,
      );
      addTearDown(controller.dispose);
      for (final sample in [(3, 8, 23), (11, 1, 25)]) {
        await controller.select(
          CivilDate(year: 2026, month: sample.$1, day: sample.$2),
        );
        expect(controller.status, DayLedgerStatus.empty);
        final hours = Platform.environment['TZ'] == 'America/New_York'
            ? sample.$3
            : 24;
        expect(controller.view!.unresolvedDuration.milliseconds, hours * hour);
      }
      instant = DateTime.utc(2026, 9, 30, 2).millisecondsSinceEpoch;
      await controller.select(null);
      expect(controller.date, deviceDateOfInstant(instant));
      expect(
        controller.view!.window.startedAt,
        DateTime.fromMillisecondsSinceEpoch(instant)
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
            .millisecondsSinceEpoch,
      );
    },
    skip: ![
      'America/New_York',
      'Asia/Shanghai',
    ].contains(Platform.environment['TZ']),
  );
}

class _GoalReadGate extends QueryInterceptor {
  bool enabled = false;
  final read = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (enabled && !read.isCompleted && statement.contains('FROM goals')) {
      read.complete();
      await release.future;
    }
    return rows;
  }
}
