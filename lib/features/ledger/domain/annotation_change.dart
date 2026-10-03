import '../../../core/identity/entity_id.dart';
import 'rhythm_details.dart';
import 'rhythm_state.dart';

/// 解释操作是显式意图，仅随所属 TimeBlock 经 LedgerRepository 保存。
sealed class AnnotationChange {
  const AnnotationChange();
}

final class KeepAnnotation extends AnnotationChange {
  const KeepAnnotation();
}

final class AddAnnotation extends AnnotationChange {
  const AddAnnotation({
    required this.id,
    required this.state,
    this.stuckReasonCode,
    this.stuckReasonText,
    this.recoveryMethod,
    this.recoveryQuality,
    this.continuationHint,
  });
  final EntityId id;
  final RhythmState state;
  final StuckReasonCode? stuckReasonCode;
  final String? stuckReasonText;
  final RecoveryMethod? recoveryMethod;
  final RecoveryQuality? recoveryQuality;
  final String? continuationHint;
}

/// 省略字段表示保留；(value: null) 表示明确清空，不因状态切换清空。
final class EditAnnotation extends AnnotationChange {
  const EditAnnotation({
    this.state,
    this.stuckReasonCode,
    this.stuckReasonText,
    this.recoveryMethod,
    this.recoveryQuality,
    this.continuationHint,
  });
  final RhythmState? state;
  final ({StuckReasonCode? value})? stuckReasonCode;
  final ({String? value})? stuckReasonText;
  final ({RecoveryMethod? value})? recoveryMethod;
  final ({RecoveryQuality? value})? recoveryQuality;
  final ({String? value})? continuationHint;
}

final class RemoveAnnotation extends AnnotationChange {
  const RemoveAnnotation();
}
