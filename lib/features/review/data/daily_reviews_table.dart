import 'package:drift/drift.dart';

import '../../goals/data/goals_table.dart';

@DataClassName('DailyReviewRow')
@TableIndex(
  name: 'idx_daily_reviews_first_step_goal',
  columns: {#tomorrowFirstStepGoalId},
)
class DailyReviews extends Table {
  TextColumn get id => text()();
  // CivilDate (YYYY-MM-DD), not a UTC midnight or a persisted Day entity.
  TextColumn get reviewDate => text().unique()();
  TextColumn get summary => text().nullable()();
  TextColumn get reflection => text().nullable()();
  TextColumn get tomorrowFirstStepText => text()();
  TextColumn get tomorrowFirstStepGoalId => text().nullable().references(
    Goals,
    #id,
    onDelete: KeyAction.restrict,
    onUpdate: KeyAction.restrict,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
