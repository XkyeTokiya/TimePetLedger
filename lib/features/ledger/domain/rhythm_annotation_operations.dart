import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/core/time/timestamps.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';

import 'rhythm_annotation.dart';
import 'rhythm_association.dart';
import 'rhythm_details.dart';
import 'rhythm_state.dart';
import 'time_block.dart';

/// 一份 TimeBlock 上最多一份解释的待保存关系结果（RH-001、Q-013）。
/// timeBlock 始终为输入对象，字段与元数据都不改变。
/// changed 只表示解释内容或关系发生变化，不代表保存成功。
typedef RhythmAnnotationOperationResult = ({
  TimeBlock timeBlock,
  RhythmAnnotation? annotation,
  bool changed,
});

/// 为已有 TimeBlock 添加解释，不覆盖已有解释（Q-013）。
///
/// existing 为调用方读取的该事实当前解释，null 表示尚无解释。
/// id、state、now 由调用方明确提供，不生成身份或自动判断节奏。
/// 目标归属已在 TimeBlock 中存在，添加解释不算新增 Goal 关联。
/// data 须在同一事务中读取当前关系、核验唯一性并提交；仅在成功后
/// 发布本结果，失败保留原关系。本函数不查询、不保存或更正时间事实。
RhythmAnnotationOperationResult addRhythmAnnotation({
  required TimeBlock timeBlock,
  required RhythmAnnotation? existing,
  required Goal? goal,
  required EntityId id,
  required RhythmState state,
  required InstantMilliseconds now,
  StuckReasonCode? stuckReasonCode,
  String? stuckReasonText,
  RecoveryMethod? recoveryMethod,
  RecoveryQuality? recoveryQuality,
  String? continuationHint,
}) {
  if (existing != null) {
    throw StateError('Q-013: 已有解释，请改用编辑');
  }
  final timestamps = timestampsForCreation(now: now);
  final annotation = RhythmAnnotation(
    id: id,
    timeBlockId: timeBlock.id,
    state: state,
    createdAt: timestamps.createdAt,
    updatedAt: timestamps.updatedAt,
    stuckReasonCode: stuckReasonCode,
    stuckReasonText: stuckReasonText,
    recoveryMethod: recoveryMethod,
    recoveryQuality: recoveryQuality,
    continuationHint: continuationHint,
  );
  validateRhythmAssociation(
    annotation: annotation,
    timeBlock: timeBlock,
    goal: goal,
    isNewGoalAssociation: false,
  );
  return (timeBlock: timeBlock, annotation: annotation, changed: true);
}

/// 编辑既有解释，不改身份、所属事实或 createdAt（Q-005、Q-013、Q-018）。
///
/// 三种 state 可任意双向更正；未提供的细节和接续点均保持原值，
/// 不适用字段只由 applicable getter 隐藏，不因切换而清空。
/// 可空字段使用记录参数区分保留和清空，例如省略 stuckReasonText
/// 表示保留，stuckReasonText: (value: null) 表示显式清空。
/// 规范化后无变化时返回原解释，保留 updatedAt。
///
/// 当前时间仅用于有实际变化的待保存值，成功提交前不得发布结果。
/// 数据完整性与原子提交职责同 addRhythmAnnotation。
RhythmAnnotationOperationResult editRhythmAnnotation({
  required TimeBlock timeBlock,
  required RhythmAnnotation? existing,
  required Goal? goal,
  required InstantMilliseconds now,
  RhythmState? state,
  ({StuckReasonCode? value})? stuckReasonCode,
  ({String? value})? stuckReasonText,
  ({RecoveryMethod? value})? recoveryMethod,
  ({RecoveryQuality? value})? recoveryQuality,
  ({String? value})? continuationHint,
}) {
  if (existing == null) {
    throw StateError('Q-013: 尚无解释，请先添加');
  }
  final candidate = RhythmAnnotation(
    id: existing.id,
    timeBlockId: existing.timeBlockId,
    state: state ?? existing.state,
    createdAt: existing.createdAt,
    updatedAt: now,
    stuckReasonCode: stuckReasonCode == null
        ? existing.stuckReasonCode
        : stuckReasonCode.value,
    stuckReasonText: stuckReasonText == null
        ? existing.stuckReasonText
        : stuckReasonText.value,
    recoveryMethod: recoveryMethod == null
        ? existing.recoveryMethod
        : recoveryMethod.value,
    recoveryQuality: recoveryQuality == null
        ? existing.recoveryQuality
        : recoveryQuality.value,
    continuationHint: continuationHint == null
        ? existing.continuationHint
        : continuationHint.value,
  );
  validateRhythmAssociation(
    annotation: candidate,
    timeBlock: timeBlock,
    goal: goal,
    isNewGoalAssociation: false,
  );
  final changed =
      candidate.state != existing.state ||
      candidate.stuckReasonCode != existing.stuckReasonCode ||
      candidate.stuckReasonText != existing.stuckReasonText ||
      candidate.recoveryMethod != existing.recoveryMethod ||
      candidate.recoveryQuality != existing.recoveryQuality ||
      candidate.continuationHint != existing.continuationHint;
  return (
    timeBlock: timeBlock,
    annotation: changed ? candidate : existing,
    changed: changed,
  );
}

/// 移除解释关系，保留原事实；无解释时幂等成功（Q-013）。
///
/// 仅接收该 TimeBlock 的原解释，不允许移除其他事实的解释。
/// 不引入 neutral / removed 状态、不保留历史版本，也不刷新事实时间戳。
/// 不新增或修改目标引用，因此不需要 Goal 查询。data 成功提交前须
/// 保留原关系；返回 null 仅是本次明确 remove 操作的待保存结果。
RhythmAnnotationOperationResult removeRhythmAnnotation({
  required TimeBlock timeBlock,
  required RhythmAnnotation? existing,
}) {
  if (existing != null && existing.timeBlockId != timeBlock.id) {
    throw ArgumentError.value(
      existing.timeBlockId,
      'existing',
      'RH-001: Annotation must belong to this TimeBlock',
    );
  }
  return (timeBlock: timeBlock, annotation: null, changed: existing != null);
}
