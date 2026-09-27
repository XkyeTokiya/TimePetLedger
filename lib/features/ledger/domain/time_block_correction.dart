import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';

import 'block_knowledge_state.dart';
import 'ledger_conflicts.dart';
import 'rhythm_annotation.dart';
import 'rhythm_association.dart';
import 'time_block.dart';
import 'time_precision.dart';

/// 待保存的更正结果；annotation 始终保留输入的原解释，不新增或移除。
typedef TimeBlockCorrectionResult = ({
  TimeBlock timeBlock,
  RhythmAnnotation? annotation,
  bool changed,
});

/// 保留所有冲突身份与区间，供调用方提示，不自动调整已有事实。
final class TimeBlockCorrectionConflict implements Exception {
  TimeBlockCorrectionConflict(this.conflicts);

  final List<LedgerFactInterval> conflicts;

  @override
  String toString() =>
      'TimeBlock correction overlaps ${conflicts.length} facts';
}

/// Q-003、Q-013：更正已存在事实，不生成新身份或修改解释。
///
/// original / annotation 是调用方读取的原事实及其可选解释；original
/// 为 null 时拒绝更正。goal 是结果 goalId 对应的当前目标快照。
/// existing 必须包含可能冲突的两类完整事实；只排除原 TimeBlock 身份。
///
/// 未提供的字段保持原值。可空字段以记录参数区分保留与显式清空：
/// 例如省略 note 表示保留，note: (value: null) 表示清空。
/// 文本规范化后比较业务字段，无变化保留原对象及 updatedAt。
///
/// 结果为待保存值，changed 时 updatedAt 使用注入的 now。data 必须在
/// 写事务内提供一致上下文并保存；仅成功后发布结果，失败保留原事实。
/// 本函数不查询、不持久化、不编辑 / 删除 annotation 或 DailyReview。
TimeBlockCorrectionResult correctTimeBlock({
  required TimeBlock? original,
  required RhythmAnnotation? annotation,
  required Goal? goal,
  required Iterable<LedgerFactInterval> existing,
  required InstantMilliseconds now,
  BlockKnowledgeState? knowledgeState,
  InstantMilliseconds? startedAt,
  InstantMilliseconds? endedAt,
  TimePrecision? startPrecision,
  TimePrecision? endPrecision,
  ({String? value})? title,
  ({EntityId? value})? goalId,
  ({String? value})? categoryId,
  ({String? value})? note,
}) {
  if (original == null) {
    throw StateError('Q-013: 记录已不存在');
  }
  final candidate = TimeBlock(
    id: original.id,
    createdAt: original.createdAt,
    updatedAt: now,
    knowledgeState: knowledgeState ?? original.knowledgeState,
    startedAt: startedAt ?? original.startedAt,
    endedAt: endedAt ?? original.endedAt,
    startPrecision: startPrecision ?? original.startPrecision,
    endPrecision: endPrecision ?? original.endPrecision,
    title: title == null ? original.title : title.value,
    goalId: goalId == null ? original.goalId : goalId.value,
    categoryId: categoryId == null ? original.categoryId : categoryId.value,
    note: note == null ? original.note : note.value,
  );
  final newGoalAssociation = candidate.goalId != original.goalId;
  if (annotation != null) {
    validateRhythmAssociation(
      annotation: annotation,
      timeBlock: candidate,
      goal: goal,
      isNewGoalAssociation: newGoalAssociation,
    );
  } else if (candidate.goalId != null) {
    // 无解释也须核验目标归属，不为复用解释校验而虚构 annotation。
    if (goal == null || goal.id != candidate.goalId) {
      throw ArgumentError.value(goal?.id, 'goal', 'Referenced Goal must match');
    }
    if (newGoalAssociation && goal.status == GoalStatus.archived) {
      throw ArgumentError.value(goal.id, 'goal', 'Cannot add an archived Goal');
    }
  }

  final interval = LedgerFactInterval.fromTimeBlock(candidate);
  final conflicts = findLedgerConflicts(
    candidate: interval,
    existing: existing,
    replacing: interval.reference,
  );
  if (conflicts.isNotEmpty) throw TimeBlockCorrectionConflict(conflicts);

  final changed =
      candidate.knowledgeState != original.knowledgeState ||
      candidate.startedAt != original.startedAt ||
      candidate.endedAt != original.endedAt ||
      candidate.startPrecision != original.startPrecision ||
      candidate.endPrecision != original.endPrecision ||
      candidate.title != original.title ||
      candidate.goalId != original.goalId ||
      candidate.categoryId != original.categoryId ||
      candidate.note != original.note;
  return (
    timeBlock: changed ? candidate : original,
    annotation: annotation,
    changed: changed,
  );
}
