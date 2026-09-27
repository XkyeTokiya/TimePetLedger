import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';

import 'daily_review.dart';

/// 校验调用方解析的 Goal 快照，不查询、不保存、不执行生命周期操作。
/// 构造对象不代表新增关联；历史归档引用可保留（Q-006）。
void validateReviewGoalAssociation({
  required DailyReview review,
  required Goal? goal,
  required bool isNewGoalAssociation,
}) {
  final goalId = review.tomorrowFirstStep.goalId;
  if (goalId == null) return;
  if (goal == null || goal.id != goalId) {
    throw ArgumentError.value(
      goal?.id,
      'goal',
      'Q-006: Referenced Goal must exist and match tomorrowFirstStep.goalId',
    );
  }
  if (isNewGoalAssociation && goal.status == GoalStatus.archived) {
    throw ArgumentError.value(
      goal.id,
      'goal',
      'Q-006: Cannot add an association to an archived Goal',
    );
  }
}
