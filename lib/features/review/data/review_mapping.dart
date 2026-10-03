import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/time/civil_date.dart';
import '../domain/daily_review.dart';
import '../domain/review_repository.dart';
import '../domain/tomorrow_first_step.dart';

/// CivilDate 的文本编码，不转换时区，也不额外限制领域允许的年份。
String reviewDateToDatabase(CivilDate date) {
  final year = date.year < 0
      ? '-${date.year.toString().substring(1).padLeft(4, '0')}'
      : date.year.toString().padLeft(4, '0');
  return '$year-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

CivilDate _date(Object? value) {
  if (value is! String) throw const ReviewDataException();
  final match = RegExp(r'^(-?\d{4,})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw const ReviewDataException();
  final date = CivilDate(
    year: int.parse(match[1]!),
    month: int.parse(match[2]!),
    day: int.parse(match[3]!),
  );
  if (reviewDateToDatabase(date) != value) throw const ReviewDataException();
  return date;
}

DailyReview reviewFromDatabase(Map<String, Object?> row) {
  final id = row['id'];
  final summary = row['summary'];
  final reflection = row['reflection'];
  final text = row['tomorrow_first_step_text'];
  final goal = row['tomorrow_first_step_goal_id'];
  final created = row['created_at'];
  final updated = row['updated_at'];
  if (id is! String ||
      text is! String ||
      created is! int ||
      updated is! int ||
      (summary != null && summary is! String) ||
      (reflection != null && reflection is! String) ||
      (goal != null && goal is! String)) {
    throw const ReviewDataException();
  }
  try {
    final date = _date(row['review_date']);
    final review = DailyReview(
      id: id,
      date: date,
      summary: summary as String?,
      reflection: reflection as String?,
      tomorrowFirstStep: TomorrowFirstStep(
        reviewDate: date,
        text: text,
        goalId: goal as String?,
      ),
      createdAt: created,
      updatedAt: updated,
    );
    if (review.summary != summary ||
        review.reflection != reflection ||
        review.tomorrowFirstStep.text != text) {
      throw const ReviewDataException();
    }
    return review;
  } on ArgumentError {
    throw const ReviewDataException();
  } on FormatException {
    throw const ReviewDataException();
  }
}

DailyReviewsCompanion reviewToDatabase(DailyReview review) =>
    DailyReviewsCompanion(
      id: Value(review.id),
      reviewDate: Value(reviewDateToDatabase(review.date)),
      summary: Value(review.summary),
      reflection: Value(review.reflection),
      tomorrowFirstStepText: Value(review.tomorrowFirstStep.text),
      tomorrowFirstStepGoalId: Value(review.tomorrowFirstStep.goalId),
      createdAt: Value(review.createdAt),
      updatedAt: Value(review.updatedAt),
    );
