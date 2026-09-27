import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';

import 'rhythm_annotation.dart';
import 'time_block.dart';

/// 校验明确提供的关联快照（RH-001、Q-004、Q-006），不执行查询。
///
/// timeBlock / goal 为调用方解析的目标；null 表示没有对应对象。
/// isNewGoalAssociation 指本次是否新增 TimeBlock → Goal 归属，
/// 不是是否新添 annotation。已有归档目标的归属允许保留并添加解释。
/// 调用方负责提供真实上下文；持久化外键与一块最多一份留给写入边界。
void validateRhythmAssociation({
  required RhythmAnnotation annotation,
  required TimeBlock? timeBlock,
  required Goal? goal,
  required bool isNewGoalAssociation,
}) {
  if (timeBlock == null || timeBlock.id != annotation.timeBlockId) {
    throw ArgumentError.value(
      timeBlock?.id,
      'timeBlock',
      'RH-001: Annotation requires its referenced TimeBlock',
    );
  }
  if (timeBlock.goalId == null) return;
  if (goal == null || goal.id != timeBlock.goalId) {
    throw ArgumentError.value(
      goal?.id,
      'goal',
      'Q-004: Referenced Goal must exist and match TimeBlock.goalId',
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
