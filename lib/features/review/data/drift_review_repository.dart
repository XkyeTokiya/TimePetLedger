import 'package:drift/drift.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../../goals/data/goal_mapping.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_repository.dart';
import '../domain/daily_review.dart';
import '../domain/daily_review_correction.dart';
import '../domain/review_goal_association.dart';
import '../domain/review_repository.dart';
import '../domain/tomorrow_first_step.dart';
import 'review_mapping.dart';

/// 借用 app 管理的连接；在同一写事务中读取当前对象、日期及 Goal 后保存。
final class DriftReviewRepository implements ReviewRepository {
  DriftReviewRepository(this._database);
  final AppDatabase _database;

  @override
  Future<DailyReview?> findByDate(CivilDate date) =>
      _guard(() => _byDate(date));

  Future<DailyReview?> _byDate(CivilDate date) =>
      _one('review_date', reviewDateToDatabase(date));
  Future<DailyReview?> _one(String column, String value) async {
    final row = await _database
        .customSelect(
          'SELECT * FROM daily_reviews WHERE $column = ?',
          variables: [Variable(value)],
          readsFrom: {_database.dailyReviews},
        )
        .getSingleOrNull();
    return row == null ? null : reviewFromDatabase(row.data);
  }

  Future<Goal?> _goal(EntityId? id) async {
    if (id == null) return null;
    final row = await _database
        .customSelect(
          'SELECT * FROM goals WHERE id = ?',
          variables: [Variable(id)],
          readsFrom: {_database.goals},
        )
        .getSingleOrNull();
    try {
      return row == null ? null : goalFromDatabase(row.data);
    } on GoalDataException {
      throw const ReviewDataException();
    }
  }

  @override
  Future<DailyReview> create({
    required EntityId id,
    required CivilDate date,
    required String tomorrowFirstStepText,
    required InstantMilliseconds now,
    String? summary,
    String? reflection,
    EntityId? tomorrowFirstStepGoalId,
  }) => _guard(
    () => _database.transaction(() async {
      final review = DailyReview(
        id: id,
        date: date,
        summary: summary,
        reflection: reflection,
        tomorrowFirstStep: TomorrowFirstStep(
          reviewDate: date,
          text: tomorrowFirstStepText,
          goalId: tomorrowFirstStepGoalId,
        ),
        createdAt: now,
        updatedAt: now,
      );
      if (await _one('id', id) != null) throw ReviewAlreadyExistsException(id);
      final existing = await _byDate(date);
      if (existing != null) throw DailyReviewDateConflict(existing);
      validateReviewGoalAssociation(
        review: review,
        goal: await _goal(tomorrowFirstStepGoalId),
        isNewGoalAssociation: true,
      );
      await _database
          .into(_database.dailyReviews)
          .insert(reviewToDatabase(review));
      return review;
    }),
  );

  @override
  Future<DailyReview> update({
    required EntityId id,
    required InstantMilliseconds now,
    CivilDate? date,
    ({String? value})? summary,
    ({String? value})? reflection,
    String? tomorrowFirstStepText,
    ({EntityId? value})? tomorrowFirstStepGoalId,
  }) => _guard(
    () => _database.transaction(() async {
      requireUuidV4(id);
      final original = await _one('id', id);
      if (original == null) throw ReviewNotFoundException(id);
      final existing = await _byDate(date ?? original.date);
      final result = correctDailyReview(
        original: original,
        existing: [?existing],
        goal: await _goal(
          tomorrowFirstStepGoalId == null
              ? original.tomorrowFirstStep.goalId
              : tomorrowFirstStepGoalId.value,
        ),
        now: now,
        date: date,
        summary: summary,
        reflection: reflection,
        tomorrowFirstStepText: tomorrowFirstStepText,
        tomorrowFirstStepGoalId: tomorrowFirstStepGoalId,
      );
      if (result.changed) {
        await (_database.update(_database.dailyReviews)
              ..where((row) => row.id.equals(id)))
            .write(reviewToDatabase(result.review));
      }
      return result.review;
    }),
  );

  @override
  Future<void> delete(EntityId id) => _guard(
    () => _database.transaction(() async {
      requireUuidV4(id);
      await (_database.delete(
        _database.dailyReviews,
      )..where((row) => row.id.equals(id))).go();
    }),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ArgumentError {
      rethrow;
    } on ReviewAlreadyExistsException {
      rethrow;
    } on ReviewNotFoundException {
      rethrow;
    } on DailyReviewDateConflict {
      rethrow;
    } on ReviewDataException {
      rethrow;
    } catch (error, stack) {
      Error.throwWithStackTrace(ReviewStorageException(error), stack);
    }
  }
}
