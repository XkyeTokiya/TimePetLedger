import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review_correction.dart';

import 'schema_contract.dart';

const _goal = '00000000-0000-4000-8000-000000000001';
const _block = '00000000-0000-4000-8000-000000000002';
const _unknown = '00000000-0000-4000-8000-000000000003';
const _annotation = '00000000-0000-4000-8000-000000000004';
const _review = '00000000-0000-4000-8000-000000000005';
const _other = '00000000-0000-4000-8000-000000000006';
// UTC midnight 2024-02-29; explicit milliseconds, not current device time.
const _midnight = 1709164800000;
const _now = 1790467200123;
final _date = CivilDate(year: 2024, month: 2, day: 28);
final _nextDate = CivilDate(year: 2024, month: 3, day: 1);

/// All fixture writes use the approved repositories. Each factory call must
/// open a fresh executor against the same isolated durable store.
Future<void> verifyFullPersistence(Future<AppDatabase> Function() open) async {
  AppDatabase? current;
  try {
    var db = current = await open();
    await _boundary(db);
    final goals = DriftGoalRepository(db);
    final ledger = DriftLedgerRepository(db);
    final reviews = DriftReviewRepository(db);
    await goals.create(id: _goal, name: '写作 🐾', now: _now);
    await ledger.createSleepSession(
      id: _block,
      startedAt: _midnight - 3600001,
      endedAt: _midnight + 3600002,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      note: '跨日睡眠',
      now: _now + 1,
    );
    await ledger.createTimeBlock(
      id: _block,
      startedAt: _midnight + 3600002,
      endedAt: _midnight + 3660003,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
      knowledgeState: BlockKnowledgeState.known,
      title: '写一段',
      goalId: _goal,
      categoryId: 'reserved-category',
      note: '保留\n两行',
      now: _now + 2,
      annotation: const AddAnnotation(
        id: _annotation,
        state: RhythmState.stuck,
        stuckReasonCode: StuckReasonCode.unclearNextStep,
        stuckReasonText: '从哪里开始',
        recoveryMethod: RecoveryMethod.walk,
        recoveryQuality: RecoveryQuality.partlyRecovered,
        continuationHint: '下一段的线索',
      ),
    );
    // Unknown is a stored fact; the interval before it remains only a gap.
    await ledger.createTimeBlock(
      id: _unknown,
      startedAt: _midnight + 3720004,
      endedAt: _midnight + 3780005,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      knowledgeState: BlockKnowledgeState.unknown,
      now: _now + 3,
    );
    await reviews.create(
      id: _review,
      date: _date,
      summary: '当天概述',
      reflection: '我的反思\n不由统计改写',
      tomorrowFirstStepText: '打开提纲',
      tomorrowFirstStepGoalId: _goal,
      now: _now + 4,
    );
    await goals.archive(id: _goal, now: _now + 5);
    await ledger.updateTimeBlock(
      id: _block,
      now: _now + 6,
      annotation: const EditAnnotation(state: RhythmState.recovery),
    );
    await ledger.updateSleepSession(
      id: _block,
      now: _now + 7,
      note: (value: '更正后的跨日睡眠'),
    );
    await reviews.update(id: _review, now: _now + 8, summary: (value: '更正概述'));
    final expected = await _snapshot(db);
    final rawExpected = await _raw(db);
    expect((await goals.findById(_goal))!.status, GoalStatus.archived);
    final original = await ledger.readWindow(
      startedAt: _midnight,
      endedAt: _midnight + 4000000,
    );
    expect(original.timeBlocks, hasLength(2));
    expect(original.sleepSessions.single.startedAt, _midnight - 3600001);
    expect(original.annotations.single.stuckReasonText, '从哪里开始');
    expect(original.annotations.single.state, RhythmState.recovery);
    expect(
      (await reviews.findByDate(_date))!.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2024, month: 2, day: 29),
    );

    // Failed operations must remain absent after closure, not just in this connection.
    await expectLater(
      ledger.updateTimeBlock(id: _unknown, startedAt: _midnight, now: _now + 9),
      throwsA(isA<LedgerConflictException>()),
    );
    await expectLater(
      reviews.create(
        id: _other,
        date: _date,
        tomorrowFirstStepText: '不得覆盖',
        now: _now + 9,
      ),
      throwsA(isA<DailyReviewDateConflict>()),
    );
    // Duplicate annotation PK fails after the new TimeBlock INSERT and rolls it back.
    await expectLater(
      ledger.createTimeBlock(
        id: _other,
        startedAt: _midnight + 4000000,
        endedAt: _midnight + 4000100,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        now: _now + 9,
        annotation: const AddAnnotation(
          id: _annotation,
          state: RhythmState.recovery,
        ),
      ),
      throwsA(isA<LedgerStorageException>()),
    );
    expect(await _raw(db), rawExpected);
    await db.close();
    current = null;
    await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);

    db = current = await open();
    await _boundary(db);
    expect(await _snapshot(db), expected);
    expect(await _raw(db), rawExpected);
    final reopenedLedger = DriftLedgerRepository(db);
    final reopenedGoals = DriftGoalRepository(db);
    final reopenedReviews = DriftReviewRepository(db);
    expect(await reopenedGoals.listActive(), isEmpty);
    // Foreign keys are re-enabled for this new connection, not just the first.
    await expectLater(
      db.customStatement('DELETE FROM goals WHERE id = ?', [_goal]),
      throwsA(anything),
    );
    await reopenedLedger.updateTimeBlock(
      id: _block,
      now: _now + 20,
      annotation: const RemoveAnnotation(),
    );
    await reopenedLedger.deleteTimeBlock(_unknown);
    await reopenedGoals.restore(id: _goal, now: _now + 21);
    await reopenedReviews.update(
      id: _review,
      date: _nextDate,
      now: _now + 22,
      reflection: (value: null),
      tomorrowFirstStepGoalId: (value: null),
    );
    final changed = await _snapshot(db);
    final changedRaw = await _raw(db);
    await db.close();
    current = null;

    db = current = await open();
    await _boundary(db);
    expect(await _snapshot(db), changed);
    expect(await _raw(db), changedRaw);
    final last = await DriftLedgerRepository(
      db,
    ).readWindow(startedAt: _midnight - 4000000, endedAt: _midnight + 5000000);
    expect(last.timeBlocks, hasLength(1));
    expect(last.annotations, isEmpty);
    expect(last.sleepSessions, hasLength(1));
    expect(await DriftReviewRepository(db).findByDate(_date), isNull);
    final review = (await DriftReviewRepository(db).findByDate(_nextDate))!;
    expect(review.createdAt, _now + 4);
    expect(review.updatedAt, _now + 22);
    expect(
      review.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2024, month: 3, day: 2),
    );
    expect(review.reflection, isNull);
    expect(review.tomorrowFirstStep.goalId, isNull);
    expect((await DriftGoalRepository(db).findById(_goal))!.archivedAt, isNull);
  } finally {
    final db = current;
    if (db != null) {
      try {
        await clearSchemaRows(db);
      } finally {
        await db.close();
      }
    }
  }
}

Future<void> _boundary(AppDatabase db) async {
  // Read-only existing check asserts exact tables, all columns, indexes and no views/triggers.
  await schemaChecks['five tables expose only the specified columns, nullability and indexes']!(
    db,
  );
  expect(
    (await db.customSelect('PRAGMA foreign_keys').getSingle())
        .data['foreign_keys'],
    1,
  );
  expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  expect(
    (await db.customSelect('PRAGMA integrity_check').getSingle())
        .data
        .values
        .single,
    'ok',
  );
}

Future<List<Map<String, Object?>>> _raw(AppDatabase db) async => [
  for (final table in [
    'goals',
    'time_blocks',
    'rhythm_annotations',
    'sleep_sessions',
    'daily_reviews',
  ])
    for (final row
        in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
      {'table': table, ...row.data},
];

/// Compare all domain fields explicitly; do not use the persistence encoders as
/// an expected-value oracle. This also checks derived intendedDate after reopen.
Future<Map<String, Object?>> _snapshot(AppDatabase db) async {
  final goal = (await DriftGoalRepository(db).findById(_goal))!;
  final ledger = await DriftLedgerRepository(db)
      .readWindow(startedAt: _midnight - 4000000, endedAt: _midnight + 5000000);
  final reviews = DriftReviewRepository(db);
  final review =
      await reviews.findByDate(_date) ?? (await reviews.findByDate(_nextDate))!;
  return {
    'goal': [
      goal.id,
      goal.name,
      goal.status,
      goal.createdAt,
      goal.updatedAt,
      goal.archivedAt,
    ],
    'blocks': [
      for (final b in ledger.timeBlocks)
        [
          b.id,
          b.startedAt,
          b.endedAt,
          b.startPrecision,
          b.endPrecision,
          b.knowledgeState,
          b.title,
          b.goalId,
          b.categoryId,
          b.note,
          b.createdAt,
          b.updatedAt,
        ],
    ],
    'sleep': [
      for (final s in ledger.sleepSessions)
        [
          s.id,
          s.startedAt,
          s.endedAt,
          s.startPrecision,
          s.endPrecision,
          s.type,
          s.note,
          s.createdAt,
          s.updatedAt,
        ],
    ],
    'annotations': [
      for (final a in ledger.annotations)
        [
          a.id,
          a.timeBlockId,
          a.state,
          a.stuckReasonCode,
          a.stuckReasonText,
          a.recoveryMethod,
          a.recoveryQuality,
          a.continuationHint,
          a.createdAt,
          a.updatedAt,
        ],
    ],
    'review': [
      review.id,
      review.date,
      review.summary,
      review.reflection,
      review.tomorrowFirstStep.text,
      review.tomorrowFirstStep.goalId,
      review.tomorrowFirstStep.intendedDate,
      review.createdAt,
      review.updatedAt,
    ],
  };
}
