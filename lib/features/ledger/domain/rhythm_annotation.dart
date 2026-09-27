import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'rhythm_details.dart';
import 'rhythm_state.dart';

/// 依附于 TimeBlock 的用户解释，不持有独立时间或 Goal（RH-001–008）。
///
/// 构造执行单对象校验；关联上下文另由 validateRhythmAssociation 校验。
/// 保留所有细节；纯关系操作见 rhythm_annotation_operations.dart。
/// 本对象不自动分类、不查询或保存。
final class RhythmAnnotation {
  RhythmAnnotation({
    required EntityId id,
    required EntityId timeBlockId,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.stuckReasonCode,
    String? stuckReasonText,
    this.recoveryMethod,
    this.recoveryQuality,
    String? continuationHint,
  }) : id = requireUuidV4(id),
       timeBlockId = _requireTimeBlockId(timeBlockId),
       stuckReasonText = _normalizeText(stuckReasonText, 'stuckReasonText'),
       continuationHint = _normalizeText(continuationHint, 'continuationHint');

  final EntityId id;
  final EntityId timeBlockId;
  final RhythmState state;
  final InstantMilliseconds createdAt;
  final InstantMilliseconds updatedAt;

  /// 原始细节用于保留用户输入；使用时取下方 applicable 字段（Q-005）。
  final StuckReasonCode? stuckReasonCode;
  final String? stuckReasonText;
  final RecoveryMethod? recoveryMethod;
  final RecoveryQuality? recoveryQuality;

  /// 三种状态均适用的可选长文本，不表示明天第一步。
  final String? continuationHint;

  StuckReasonCode? get applicableStuckReasonCode =>
      state == RhythmState.stuck ? stuckReasonCode : null;
  String? get applicableStuckReasonText =>
      state == RhythmState.stuck ? stuckReasonText : null;
  RecoveryMethod? get applicableRecoveryMethod =>
      state == RhythmState.recovery ? recoveryMethod : null;
  RecoveryQuality? get applicableRecoveryQuality =>
      state == RhythmState.recovery ? recoveryQuality : null;
}

EntityId _requireTimeBlockId(EntityId value) {
  try {
    return requireUuidV4(value);
  } on ArgumentError {
    throw ArgumentError.value(value, 'timeBlockId', 'Q-018: Must be a UUID v4');
  }
}

String? _normalizeText(String? value, String field) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.runes.length > 2000) {
    throw ArgumentError.value(
      value,
      field,
      'MODEL-002: Must not exceed 2000 Unicode code points',
    );
  }
  return normalized;
}
