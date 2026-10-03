import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_repository.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/data/review_mapping.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review_correction.dart';
import 'package:time_pet_ledger/features/review/domain/review_repository.dart';

const reviewId = '00000000-0000-4000-8000-000000000001';
const secondId = '00000000-0000-4000-8000-000000000002';
const thirdId = '00000000-0000-4000-8000-000000000003';
CivilDate day(int year, int month, int day) =>
    CivilDate(year: year, month: month, day: day);
final historical = day(2024, 2, 28);
Future<List<Map<String, Object?>>> reviewRows(AppDatabase db) async => [
  for (final row
      in await db.customSelect('SELECT * FROM daily_reviews ORDER BY id').get())
    row.data,
];

final reviewRepositoryChecks = <String, Future<void> Function(AppDatabase)>{
  'historical dates and all fields round trip; next civil day is derived':
      (db) async {
        final repo = DriftReviewRepository(db);
        final goals = DriftGoalRepository(db);
        await goals.create(id: thirdId, name: '目标', now: 1);
        expect(await repo.findByDate(historical), isNull);
        final saved = await repo.create(
          id: reviewId,
          date: historical,
          tomorrowFirstStepText: '  打开文件\n写一句  ',
          summary: ' 概述 ',
          reflection: ' 反思 ',
          tomorrowFirstStepGoalId: thirdId,
          now: -123,
        );
        final read = (await repo.findByDate(historical))!;
        expect(read.id, saved.id);
        expect(read.date, historical);
        expect(read.summary, '概述');
        expect(read.reflection, '反思');
        expect(read.tomorrowFirstStep.text, '打开文件\n写一句');
        expect(read.tomorrowFirstStep.goalId, thirdId);
        expect(read.tomorrowFirstStep.intendedDate, day(2024, 2, 29));
        expect(read.createdAt, -123);
        expect(read.updatedAt, -123);
        final rows = await reviewRows(db);
        expect(
          rows.single.keys,
          unorderedEquals([
            'id',
            'review_date',
            'summary',
            'reflection',
            'tomorrow_first_step_text',
            'tomorrow_first_step_goal_id',
            'created_at',
            'updated_at',
          ]),
        );
        expect(rows.single['review_date'], '2024-02-28');
        for (final date in [
          day(2024, 2, 29),
          day(2023, 12, 31),
          day(1900, 2, 28),
          day(0, 12, 31),
          day(-1, 12, 31),
          day(10000, 1, 1),
        ]) {
          await repo.update(id: reviewId, date: date, now: 55);
          expect((await repo.findByDate(date))!.date, date);
        }
        final yearEnd = await repo.update(
          id: reviewId,
          date: day(2023, 12, 31),
          now: 56,
        );
        expect(yearEnd.tomorrowFirstStep.intendedDate, day(2024, 1, 1));
        expect(yearEnd.createdAt, -123);
      },
  'optional fields clear explicitly; normalized no-op does not issue UPDATE':
      (db) async {
        final repo = DriftReviewRepository(db);
        await repo.create(
          id: reviewId,
          date: historical,
          tomorrowFirstStepText: '下一步',
          now: 10,
        );
        var read = (await repo.findByDate(historical))!;
        expect(read.summary, isNull);
        expect(read.reflection, isNull);
        expect(read.tomorrowFirstStep.goalId, isNull);
        await db.customStatement(
          "CREATE TRIGGER reject_review_update BEFORE UPDATE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'no update'); END",
        );
        read = await repo.update(
          id: reviewId,
          now: 20,
          tomorrowFirstStepText: ' 下一步 ',
          summary: (value: '  '),
        );
        expect(read.updatedAt, 10);
        await db.customStatement('DROP TRIGGER reject_review_update');
        read = await repo.update(
          id: reviewId,
          now: -10,
          summary: (value: '概述'),
          reflection: (value: '反思'),
          tomorrowFirstStepText: '另一步',
        );
        expect(read.updatedAt, -10);
        expect(read.createdAt, 10);
        await repo.update(
          id: reviewId,
          now: 30,
          summary: (value: null),
          reflection: (value: null),
        );
        read = (await repo.findByDate(historical))!;
        expect(read.summary, isNull);
        expect(read.reflection, isNull);
        expect(read.tomorrowFirstStep.text, '另一步');
      },
  'same-date creation and date correction reject without overwriting':
      (db) async {
        final repo = DriftReviewRepository(db);
        await repo.create(
          id: reviewId,
          date: historical,
          tomorrowFirstStepText: '一',
          now: 1,
        );
        await repo.create(
          id: secondId,
          date: day(2024, 3, 1),
          tomorrowFirstStepText: '二',
          now: 2,
        );
        final before = await reviewRows(db);
        await expectLater(
          repo.create(
            id: thirdId,
            date: historical,
            tomorrowFirstStepText: '三',
            now: 3,
          ),
          throwsA(
            isA<DailyReviewDateConflict>().having(
              (e) => e.existingReview.id,
              'id',
              reviewId,
            ),
          ),
        );
        await expectLater(
          repo.create(
            id: reviewId,
            date: day(2020, 1, 1),
            tomorrowFirstStepText: '重复',
            now: 3,
          ),
          throwsA(isA<ReviewAlreadyExistsException>()),
        );
        await expectLater(
          repo.update(
            id: secondId,
            date: historical,
            summary: (value: '不得部分保存'),
            now: 4,
          ),
          throwsA(isA<DailyReviewDateConflict>()),
        );
        await expectLater(
          repo.update(id: thirdId, now: 5),
          throwsA(isA<ReviewNotFoundException>()),
        );
        await expectLater(
          repo.update(id: reviewId, tomorrowFirstStepText: ' ', now: 6),
          throwsArgumentError,
        );
        expect(await reviewRows(db), before);
        final moved = await repo.update(
          id: reviewId,
          date: day(2025, 1, 1),
          now: 7,
        );
        expect(await repo.findByDate(historical), isNull);
        expect(moved.id, reviewId);
        expect(moved.createdAt, 1);
        expect(moved.tomorrowFirstStep.intendedDate, day(2025, 1, 2));
      },
  'Goal reference rules, archive retention and foreign key restriction':
      (db) async {
        final repo = DriftReviewRepository(db);
        final goals = DriftGoalRepository(db);
        await goals.create(id: thirdId, name: '目标', now: 1);
        await repo.create(
          id: reviewId,
          date: historical,
          tomorrowFirstStepText: '一步',
          tomorrowFirstStepGoalId: thirdId,
          now: 2,
        );
        expect(
          await goals.delete(id: thirdId, now: 3),
          GoalDeleteResult.archived,
        );
        await expectLater(
          db.customStatement('DELETE FROM goals WHERE id = ?', [thirdId]),
          throwsA(anything),
        );
        await repo.update(id: reviewId, now: 4, summary: (value: '已有归档关联保留'));
        expect(
          (await repo.findByDate(historical))!.tomorrowFirstStep.goalId,
          thirdId,
        );
        final before = await reviewRows(db);
        await expectLater(
          repo.create(
            id: secondId,
            date: day(2024, 3, 1),
            tomorrowFirstStepText: '一步',
            tomorrowFirstStepGoalId: thirdId,
            now: 5,
          ),
          throwsArgumentError,
        );
        await expectLater(
          repo.update(
            id: reviewId,
            now: 6,
            tomorrowFirstStepGoalId: (value: secondId),
          ),
          throwsArgumentError,
        );
        expect(await reviewRows(db), before);
        await repo.update(
          id: reviewId,
          now: 7,
          tomorrowFirstStepGoalId: (value: null),
        );
        await expectLater(
          repo.update(
            id: reviewId,
            now: 8,
            tomorrowFirstStepGoalId: (value: thirdId),
          ),
          throwsArgumentError,
        );
        await goals.restore(id: thirdId, now: 9);
        await repo.update(
          id: reviewId,
          now: 10,
          tomorrowFirstStepGoalId: (value: thirdId),
        );
        await repo.delete(reviewId);
        expect(
          await goals.delete(id: thirdId, now: 11),
          GoalDeleteResult.deleted,
        );
      },
  'constraint and mid-statement failures roll back all review fields': (db) async {
    final repo = DriftReviewRepository(db);
    await db.customStatement(
      "CREATE TRIGGER fail_review_insert AFTER INSERT ON daily_reviews BEGIN UPDATE daily_reviews SET summary = 'partial'; SELECT RAISE(FAIL, 'injected'); END",
    );
    await expectLater(
      repo.create(
        id: reviewId,
        date: historical,
        tomorrowFirstStepText: '一步',
        now: 1,
      ),
      throwsA(isA<ReviewStorageException>()),
    );
    expect(await reviewRows(db), isEmpty);
    await db.customStatement('DROP TRIGGER fail_review_insert');
    await repo.create(
      id: reviewId,
      date: historical,
      tomorrowFirstStepText: '一步',
      now: 1,
    );
    final before = await reviewRows(db);
    await db.customStatement(
      "CREATE TRIGGER fail_review_update AFTER UPDATE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'injected'); END",
    );
    await expectLater(
      repo.update(
        id: reviewId,
        date: day(2025, 1, 1),
        summary: (value: 'changed'),
        tomorrowFirstStepText: '二',
        now: 2,
      ),
      throwsA(isA<ReviewStorageException>()),
    );
    expect(await reviewRows(db), before);
    await db.customStatement('DROP TRIGGER fail_review_update');
    await db.customStatement(
      "CREATE TRIGGER fail_review_delete AFTER DELETE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'injected'); END",
    );
    await expectLater(
      repo.delete(reviewId),
      throwsA(isA<ReviewStorageException>()),
    );
    expect(await reviewRows(db), before);
    await db.customStatement('DROP TRIGGER fail_review_delete');
    // Force a genuine FK failure after repository validation, inside the write.
    await db.customStatement(
      "CREATE TRIGGER fail_review_fk AFTER UPDATE ON daily_reviews BEGIN UPDATE daily_reviews SET tomorrow_first_step_goal_id = '$thirdId' WHERE id = NEW.id; END",
    );
    await expectLater(
      repo.update(id: reviewId, summary: (value: 'changed'), now: 3),
      throwsA(isA<ReviewStorageException>()),
    );
    expect(await reviewRows(db), before);
    await db.customStatement('DROP TRIGGER fail_review_fk');
  },
  'delete is idempotent and leaves ledger facts intact': (db) async {
    final repo = DriftReviewRepository(db);
    await db.customStatement(
      "INSERT INTO sleep_sessions (id,started_at,ended_at,start_precision,end_precision,sleep_type,created_at,updated_at) VALUES (?,1,2,'exact','exact','nap',1,1)",
      [reviewId],
    );
    final facts = (await db.customSelect('SELECT * FROM sleep_sessions').get())
        .map((r) => r.data)
        .toList();
    await repo.create(
      id: reviewId,
      date: historical,
      tomorrowFirstStepText: '一步',
      now: 1,
    );
    await repo.delete(reviewId);
    await repo.delete(reviewId);
    expect(await repo.findByDate(historical), isNull);
    expect(
      (await db.customSelect('SELECT * FROM sleep_sessions').get())
          .map((r) => r.data)
          .toList(),
      facts,
    );
  },
  'concurrent same-date requests admit exactly one review': (db) async {
    final repo = DriftReviewRepository(db);
    Future<Object> attempt(String id) async {
      try {
        return await repo.create(
          id: id,
          date: historical,
          tomorrowFirstStepText: '一步',
          now: 1,
        );
      } catch (e) {
        return e;
      }
    }

    final results = await Future.wait([attempt(reviewId), attempt(secondId)]);
    expect(results.whereType<DailyReviewDateConflict>(), hasLength(1));
    expect(await reviewRows(db), hasLength(1));
  },
  'corrupt stored fields fail rather than normalize or replace': (db) async {
    final repo = DriftReviewRepository(db);
    await repo.create(
      id: reviewId,
      date: historical,
      tomorrowFirstStepText: '一步',
      now: 1,
    );
    final original = (await reviewRows(db)).single;
    for (final entry in <String, Object>{
      'summary': ' trim ',
      'tomorrow_first_step_text': ' ',
      'created_at': 1.5,
      'tomorrow_first_step_goal_id': 'invalid',
    }.entries) {
      // FK remains enabled; malformed FK is tested in raw mapping instead.
      if (entry.key == 'tomorrow_first_step_goal_id') {
        expect(
          () => reviewFromDatabase({...original, entry.key: entry.value}),
          throwsA(isA<ReviewDataException>()),
        );
      } else {
        await db.customStatement(
          'UPDATE daily_reviews SET ${entry.key} = ? WHERE id = ?',
          [entry.value, reviewId],
        );
        await expectLater(
          repo.findByDate(historical),
          throwsA(isA<ReviewDataException>()),
        );
        await db.customStatement(
          'UPDATE daily_reviews SET ${entry.key} = ? WHERE id = ?',
          [original[entry.key], reviewId],
        );
      }
    }
    for (final date in ['2024-02-30', '2024-2-28', '02024-02-28', 'nonsense']) {
      expect(
        () => reviewFromDatabase({...original, 'review_date': date}),
        throwsA(isA<ReviewDataException>()),
      );
    }
    expect(await reviewRows(db), [original]);
  },
};
