import '../../core/persistence/app_database.dart';
import '../../features/goals/data/drift_goal_repository.dart';
import '../../features/review/application/review_context_loader.dart';
import '../../features/review/data/drift_review_repository.dart';
import 'day_ledger.dart';

ReviewContextLoader createReviewContextLoader(AppDatabase database) {
  final reviews = DriftReviewRepository(database);
  final goals = DriftGoalRepository(database);
  final ledger = createDayLedgerLoader(database);
  return ReviewContextLoader(
    readContext: ({required date, required now}) => database.transaction(
      () async {
        final review = await reviews.findByDate(date);
        final view = await ledger.load(date: date, now: now);
        final goalId = review?.tomorrowFirstStep.goalId;
        final goal = goalId == null ? null : await goals.findById(goalId);
        if (goalId != null && goal == null) {
          throw StateError('Missing referenced review Goal.');
        }
        return ReviewContext(ledger: view, review: review, firstStepGoal: goal);
      },
    ),
  );
}
