import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show QueryInterceptor, QueryExecutor, TransactionExecutor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../../../../integration_test/support/ledger_read_contract.dart'
    show
        insertLedgerRow,
        blockRow,
        sleepRow,
        annotationRow,
        ledgerId,
        secondLedgerId,
        hour;

const reviewId = '00000000-0000-4000-8000-000000000009';

class ReviewReadTrace extends QueryInterceptor {
  bool enabled = false;
  String? failTable;
  final readers = <QueryExecutor>[];
  final sqlReads = <String>[];
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (enabled) {
      readers.add(executor);
      sqlReads.add(sql);
      if (failTable != null && sql.contains('FROM $failTable')) {
        throw StateError('private SQL detail');
      }
    }
    return executor.runSelect(sql, args);
  }
}

void main() {
  test('real read snapshot preserves identity, optional text, original archived Goal and review after facts change', () async {
    final trace = ReviewReadTrace();
    final db = await AppDatabase.open(
      NativeDatabase.memory().interceptWith(trace),
    );
    addTearDown(db.close);
    final date = CivilDate(year: 2025, month: 12, day: 31);
    final start = DateTime(2025, 12, 31).millisecondsSinceEpoch;
    final now = DateTime(2026, 10, 2).millisecondsSinceEpoch;
    final goals = DriftGoalRepository(db);
    await goals.create(id: ledgerId, name: '原目标', now: 1);
    final reviews = DriftReviewRepository(db);
    final original = await reviews.create(
      id: reviewId,
      date: date,
      tomorrowFirstStepText: '打开设计图\n先补字段',
      summary: '原概述',
      reflection: '用户的反思',
      tomorrowFirstStepGoalId: ledgerId,
      now: 2,
    );
    await goals.archive(id: ledgerId, now: 3);
    await insertLedgerRow(db, 'time_blocks', {
      ...blockRow(start: start + 8 * hour, end: start + 9 * hour),
      'goal_id': ledgerId,
    });
    await insertLedgerRow(
      db,
      'sleep_sessions',
      sleepRow(id: secondLedgerId, start: start - hour, end: start + 7 * hour),
    );
    await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
    final rawBefore =
        (await db.customSelect('SELECT * FROM daily_reviews').get())
            .single
            .data;
    trace.enabled = true;
    final loader = createReviewContextLoader(db);
    final loaded = await loader.load(date: date, now: now);
    trace.enabled = false;
    expect(loaded.review!.id, original.id);
    expect(loaded.review!.date, date);
    expect(
      loaded.review!.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2026, month: 1, day: 1),
    );
    expect(
      loaded.review!.tomorrowFirstStep.text,
      original.tomorrowFirstStep.text,
    );
    expect(loaded.review!.createdAt, 2);
    expect(loaded.review!.updatedAt, 2);
    expect(loaded.firstStepGoal!.status, GoalStatus.archived);
    expect(loaded.firstStepGoal!.name, '原目标');
    expect(loaded.ledger.accountedDuration.milliseconds, 8 * hour);
    expect(
      loaded.ledger.sleepSummary.mainSleep.totalDuration.milliseconds,
      8 * hour,
    );
    expect(loaded.ledger.goalSummaries.single.isArchived, isTrue);
    expect(trace.sqlReads.any((s) => s.contains('daily_reviews')), isTrue);
    expect(trace.sqlReads.any((s) => s.contains('goals')), isTrue);
    expect(trace.readers, isNotEmpty);
    expect(trace.readers.every((e) => e is TransactionExecutor), isTrue);
    await db.customStatement('DELETE FROM time_blocks');
    await goals.rename(id: ledgerId, name: '改名目标', now: 4);
    final refreshed = await loader.load(date: date, now: now);
    expect(refreshed.ledger.accountedDuration.milliseconds, 7 * hour);
    expect(refreshed.firstStepGoal!.name, '改名目标');
    expect(refreshed.review!.summary, original.summary);
    expect(refreshed.review!.reflection, original.reflection);
    expect(
      (await db.customSelect('SELECT * FROM daily_reviews').get()).single.data,
      rawBefore,
    );
  });

  test('null is distinct from review, ledger and Goal failures; retry remains read-only', () async {
    final trace = ReviewReadTrace();
    final db = await AppDatabase.open(
      NativeDatabase.memory().interceptWith(trace),
    );
    addTearDown(db.close);
    final date = CivilDate(year: 2024, month: 2, day: 29);
    final now = DateTime(2026, 10, 2).millisecondsSinceEpoch;
    final loader = createReviewContextLoader(db);
    final absent = await loader.load(date: date, now: now);
    expect(absent.review, isNull);
    expect(absent.firstStepGoal, isNull);
    expect(absent.ledger.segments, isEmpty);
    await DriftGoalRepository(db).create(id: ledgerId, name: '只有复盘引用', now: 1);
    await DriftReviewRepository(db).create(
      id: reviewId,
      date: date,
      tomorrowFirstStepText: '用户下一步',
      tomorrowFirstStepGoalId: ledgerId,
      now: 2,
    );
    final rawBefore =
        (await db.customSelect('SELECT * FROM daily_reviews').get())
            .single
            .data;
    trace.enabled = true;
    for (final table in ['daily_reviews', 'sleep_sessions', 'goals']) {
      trace.failTable = table;
      await expectLater(
        loader.load(date: date, now: now),
        throwsA(isA<Exception>()),
      );
      trace.failTable = null;
      final recovered = await loader.load(date: date, now: now);
      expect(recovered.review!.id, reviewId);
      expect(recovered.review!.summary, isNull);
      expect(recovered.review!.reflection, isNull);
      expect(
        recovered.review!.tomorrowFirstStep.intendedDate,
        CivilDate(year: 2024, month: 3, day: 1),
      );
      expect(recovered.firstStepGoal!.id, ledgerId);
    }
    trace.enabled = false;
    expect(
      (await db.customSelect('SELECT * FROM daily_reviews').get()).single.data,
      rawBefore,
    );
    expect(await db.customSelect('SELECT * FROM time_blocks').get(), isEmpty);
  });

  test('outer transaction protects review, facts and Goal from a second connection; refresh reads committed changes', () async {
    final dir = await Directory.systemTemp.createTemp('review_snapshot_');
    final file = File('${dir.path}/facts.sqlite');
    final writer = await AppDatabase.open(NativeDatabase(file));
    final gate = _ReviewGate();
    final reader = await AppDatabase.open(
      NativeDatabase(file).interceptWith(gate),
    );
    addTearDown(() async {
      await reader.close();
      await writer.close();
      await dir.delete(recursive: true);
    });
    final date = CivilDate(year: 2025, month: 12, day: 31);
    final start = DateTime(2025, 12, 31).millisecondsSinceEpoch;
    await DriftGoalRepository(writer)
        .create(id: ledgerId, name: 'before', now: 1);
    await DriftReviewRepository(writer).create(
      id: reviewId,
      date: date,
      reflection: 'before',
      tomorrowFirstStepText: 'before',
      tomorrowFirstStepGoalId: ledgerId,
      now: 2,
    );
    await insertLedgerRow(writer, 'time_blocks', {
      ...blockRow(start: start, end: start + hour),
      'goal_id': ledgerId,
    });
    Future<void> change() => writer.transaction(() async {
      await writer.customStatement(
        "UPDATE daily_reviews SET reflection = 'after', tomorrow_first_step_text = 'after'",
      );
      await writer.customStatement("UPDATE goals SET name = 'after'");
      await writer.customStatement(
        'UPDATE time_blocks SET ended_at = ended_at + 3600000',
      );
    });
    gate.enabled = true;
    final loader = createReviewContextLoader(reader);
    final pending = loader.load(date: date, now: start + 2 * hour);
    try {
      await gate.read.future.timeout(const Duration(seconds: 5));
      await expectLater(
        change(),
        throwsA(
          predicate<Object>((e) => e.toString().contains('database is locked')),
        ),
      );
    } finally {
      gate.release.complete();
    }
    final before = await pending;
    expect(before.review!.reflection, 'before');
    expect(before.review!.tomorrowFirstStep.text, 'before');
    expect(before.firstStepGoal!.name, 'before');
    expect(before.ledger.goalSummaries.single.name, 'before');
    expect(before.ledger.accountedDuration.milliseconds, hour);
    await change();
    final after = await loader.load(date: date, now: start + 2 * hour);
    expect(after.review!.reflection, 'after');
    expect(after.firstStepGoal!.name, 'after');
    expect(after.ledger.accountedDuration.milliseconds, 2 * hour);
  });

  test(
    'device calendar DST windows do not change stored date or next civil day',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      for (final sample in [(3, 8, 23), (11, 1, 25)]) {
        final date = CivilDate(year: 2026, month: sample.$1, day: sample.$2);
        await DriftReviewRepository(db).create(
          id: reviewId,
          date: date,
          tomorrowFirstStepText: '用户下一步',
          now: 1,
        );
        final loaded = await createReviewContextLoader(db)
            .load(date: date, now: DateTime(2027).millisecondsSinceEpoch);
        final hours = Platform.environment['TZ'] == 'America/New_York'
            ? sample.$3
            : 24;
        expect(loaded.ledger.window.milliseconds, hours * hour);
        expect(loaded.review!.date, date);
        expect(
          loaded.review!.tomorrowFirstStep.intendedDate,
          CivilDate(year: 2026, month: sample.$1, day: sample.$2 + 1),
        );
        await DriftReviewRepository(db).delete(reviewId);
      }
    },
  );

  for (final pair in [
    (
      CivilDate(year: 2023, month: 2, day: 28),
      CivilDate(year: 2023, month: 3, day: 1),
    ),
    (
      CivilDate(year: 2024, month: 2, day: 28),
      CivilDate(year: 2024, month: 2, day: 29),
    ),
    (
      CivilDate(year: 2026, month: 4, day: 30),
      CivilDate(year: 2026, month: 5, day: 1),
    ),
  ]) {
    test(
      'stored civil boundary ${pair.$1.year}-${pair.$1.month}-${pair.$1.day}',
      () async {
        final db = await AppDatabase.open(NativeDatabase.memory());
        addTearDown(db.close);
        await DriftReviewRepository(db).create(
          id: reviewId,
          date: pair.$1,
          tomorrowFirstStepText: '第一步',
          now: 1,
        );
        final loaded = await createReviewContextLoader(db).load(
          date: pair.$1,
          now: DateTime(2026, 10, 2).millisecondsSinceEpoch,
        );
        expect(loaded.review!.date, pair.$1);
        expect(loaded.review!.tomorrowFirstStep.intendedDate, pair.$2);
      },
    );
  }
}

class _ReviewGate extends QueryInterceptor {
  bool enabled = false;
  final read = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(sql, args);
    if (enabled && sql.contains('FROM daily_reviews')) {
      enabled = false;
      read.complete();
      await release.future;
    }
    return rows;
  }
}
