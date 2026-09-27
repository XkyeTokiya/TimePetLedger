import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';

import 'daily_review.dart';
import 'review_goal_association.dart';
import 'tomorrow_first_step.dart';

typedef DailyReviewCorrectionResult = ({DailyReview review, bool changed});

/// 目标日期已有其他复盘；调用方可显示该冲突，不自动覆盖。
final class DailyReviewDateConflict implements Exception {
  DailyReviewDateConflict(this.existingReview);

  final DailyReview existingReview;

  @override
  String toString() =>
      'DR-001: Review date is occupied by ${existingReview.id}';
}

/// Q-001、Q-013、Q-018：只更正复盘内容，保留身份和创建时间。
///
/// original 为原复盘，缺失时拒绝更正。existing 为调用方提供的可能
/// 占用目标日期的复盘快照；同 id 的旧记录排除，其他记录不得覆盖。
/// goal 是结果下一步 goalId 对应的当前目标快照，不执行查询。
///
/// 未提供字段保留；summary / reflection / tomorrowFirstStepGoalId
/// 用 (value: null) 显式清空。下一步文字必需，空白不能用于移除下一步。
/// intendedDate 总是从结果 date 的下一自然日派生，不接受独立输入。
///
/// 返回待保存值；规范化后无变化则保留原对象和 updatedAt。
/// data 须在事务内核验同日唯一与引用并提交，成功后才发布结果。
/// 本函数不接收、查询或改写睡眠、TimeBlock、解释、统计或复盘状态。
DailyReviewCorrectionResult correctDailyReview({
  required DailyReview? original,
  required Iterable<DailyReview> existing,
  required Goal? goal,
  required InstantMilliseconds now,
  CivilDate? date,
  ({String? value})? summary,
  ({String? value})? reflection,
  String? tomorrowFirstStepText,
  ({EntityId? value})? tomorrowFirstStepGoalId,
}) {
  if (original == null) throw StateError('Q-013: 记录已不存在');
  final correctedDate = date ?? original.date;
  final originalStep = original.tomorrowFirstStep;
  final step = TomorrowFirstStep(
    reviewDate: correctedDate,
    text: tomorrowFirstStepText ?? originalStep.text,
    goalId: tomorrowFirstStepGoalId == null
        ? originalStep.goalId
        : tomorrowFirstStepGoalId.value,
  );
  final candidate = DailyReview(
    id: original.id,
    date: correctedDate,
    createdAt: original.createdAt,
    updatedAt: now,
    summary: summary == null ? original.summary : summary.value,
    reflection: reflection == null ? original.reflection : reflection.value,
    tomorrowFirstStep: step,
  );
  validateReviewGoalAssociation(
    review: candidate,
    goal: goal,
    isNewGoalAssociation: step.goalId != originalStep.goalId,
  );
  for (final review in existing) {
    if (review.id != original.id && review.date == candidate.date) {
      throw DailyReviewDateConflict(review);
    }
  }
  final changed =
      candidate.date != original.date ||
      candidate.summary != original.summary ||
      candidate.reflection != original.reflection ||
      step.text != originalStep.text ||
      step.goalId != originalStep.goalId;
  return (review: changed ? candidate : original, changed: changed);
}
