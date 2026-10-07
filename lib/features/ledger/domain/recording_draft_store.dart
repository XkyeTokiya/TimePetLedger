import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import 'block_knowledge_state.dart';
import 'time_precision.dart';
import 'rhythm_state.dart';
import 'rhythm_details.dart';

/// 草稿存取的入口标识，不是正式事实的生命周期状态。
enum RecordingDraftEntry { ordinary, gap, edit }

/// Draft write intent, distinct from the three formal RhythmState values.
enum RecordingAnnotationIntent { keep, add, edit, remove }

final class RecordingDraftContext {
  const RecordingDraftContext.newEntry({required this.date})
    : entry = RecordingDraftEntry.ordinary,
      timeBlockId = null,
      gapStartedAt = null,
      gapEndedAt = null;

  RecordingDraftContext.gap({
    required this.date,
    required int startedAt,
    required int endedAt,
  }) : entry = RecordingDraftEntry.gap,
       timeBlockId = null,
       gapStartedAt = startedAt,
       gapEndedAt = endedAt {
    intervalMilliseconds(startedAt: startedAt, endedAt: endedAt);
  }

  RecordingDraftContext.edit({
    required this.date,
    required EntityId timeBlockId,
  }) : entry = RecordingDraftEntry.edit,
       timeBlockId = requireUuidV4(timeBlockId),
       gapStartedAt = null,
       gapEndedAt = null;

  final RecordingDraftEntry entry;
  final CivilDate date;
  final EntityId? timeBlockId;

  /// 原入口区间，不随用户修改输入时间而改变；不代表当前仍存在该 Gap。
  final InstantMilliseconds? gapStartedAt;
  final InstantMilliseconds? gapEndedAt;
}

/// 专用存取 DTO，不是 TimeBlock 或 presentation 的交互状态。
/// 原样保留未完成输入，不 trim、限长或校验输入区间；正式提交另行校验。
/// 未展示的正式字段不从草稿覆盖，编辑关联仅由 context.timeBlockId 指定。
final class RecordingDraft {
  const RecordingDraft({
    required this.context,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.knowledgeState,
    this.note,
    this.noteProvided = false,
    this.goalId,
    this.goalProvided = false,
    this.annotationIntent = RecordingAnnotationIntent.keep,
    this.annotationId,
    this.rhythmState,
    this.continuationHint,
    this.hintProvided = false,
    this.stuckReasonCode,
    this.stuckReasonCodeProvided = false,
    this.stuckReasonText,
    this.stuckReasonTextProvided = false,
    this.recoveryMethod,
    this.recoveryMethodProvided = false,
    this.recoveryQuality,
    this.recoveryQualityProvided = false,
    this.presentationStep = 0,
  });

  final RecordingDraftContext context;
  final String? title;
  final InstantMilliseconds? startedAt;
  final InstantMilliseconds? endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;
  final BlockKnowledgeState? knowledgeState;

  /// Raw optional input. False also identifies a draft saved before the note
  /// entry existed, so an old edit does not clear its source note on upgrade.
  final String? note;
  final bool noteProvided;

  /// False means retain the source association (including legacy drafts).
  /// True with null is an explicit clear; a non-null value selects by id.
  final EntityId? goalId;
  final bool goalProvided;

  /// Legacy drafts keep the current relation. Add carries a stable local id;
  /// remove is explicit and never represented by a fourth RhythmState.
  final RecordingAnnotationIntent annotationIntent;
  final EntityId? annotationId;
  final RhythmState? rhythmState;
  final String? continuationHint;
  final bool hintProvided;

  /// Per-field presence distinguishes legacy omission from explicit clearing.
  final StuckReasonCode? stuckReasonCode;
  final bool stuckReasonCodeProvided;
  final String? stuckReasonText;
  final bool stuckReasonTextProvided;
  final RecoveryMethod? recoveryMethod;
  final bool recoveryMethodProvided;
  final RecoveryQuality? recoveryQuality;
  final bool recoveryQualityProvided;

  /// 仅用于当前会话恢复活动问答位置，不属于任何正式领域状态。
  final int presentationStep;
}

/// 仅普通输入的独立本机存储；不查询或写入正式事实，不校验重叠。
abstract interface class RecordingDraftStore {
  /// null 仅表示该上下文没有草稿。失败抛显式异常，不返回空值兜底。
  Future<RecordingDraft?> read(RecordingDraftContext context);
  Future<void> save(RecordingDraft draft);
  Future<void> clear(RecordingDraftContext context);
}

enum RecordingDraftOperation { open, read, save, clear, close }

class RecordingDraftStorageException implements Exception {
  const RecordingDraftStorageException(this.operation, this.cause);
  final RecordingDraftOperation operation;
  final Object cause;
  @override
  String toString() =>
      'Recording draft storage operation failed: ${operation.name}.';
}

class RecordingDraftDataException implements Exception {
  const RecordingDraftDataException();
  @override
  String toString() => 'Stored recording draft is invalid.';
}
