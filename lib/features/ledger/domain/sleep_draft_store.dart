import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import 'sleep_type.dart';
import 'sleep_prediction.dart';
import 'time_precision.dart';

/// 输入上下文，不是 SleepSession 的生命周期状态。
final class SleepDraftContext {
  const SleepDraftContext.newEntry({required this.date})
    : sleepSessionId = null;

  SleepDraftContext.edit({required this.date, required EntityId sleepSessionId})
    : sleepSessionId = requireUuidV4(sleepSessionId);

  final CivilDate date;
  final EntityId? sleepSessionId;
  bool get isEditing => sleepSessionId != null;
}

/// 未完成输入 DTO，不是正式睡眠；不校验正区间或替用户选择类型 / 精度。
final class SleepDraft {
  const SleepDraft({
    required this.context,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.type,
    this.startedAtInput,
    this.endedAtInput,
    this.note,
    this.noteProvided = false,
    this.predictionOrigin,
  });

  final SleepDraftContext context;
  final InstantMilliseconds? startedAt;
  final InstantMilliseconds? endedAt;
  final TimePrecision? startPrecision;
  final TimePrecision? endPrecision;
  final SleepType? type;

  /// 原始文本（含未完成 / 无效输入）；null 表示尚未在文本框修改过该端点。
  /// 输入层在文本修改时同步其解析值，无法解析则相应时间点为 null。
  /// 读取层原样保留，不按当前设备时区重新解释已解析的绝对时间。
  final String? startedAtInput;
  final String? endedAtInput;

  /// Raw optional input; false also identifies drafts from before the note
  /// entry existed. An omitted edit must preserve the current formal note.
  final String? note;
  final bool noteProvided;
  final SleepPredictionOrigin? predictionOrigin;
}

abstract interface class SleepDraftStore {
  /// null 仅表示无草稿；存储 / 数据失败不得伪装成无记录。
  Future<SleepDraft?> read(SleepDraftContext context);
  Future<void> save(SleepDraft draft);
  Future<void> clear(SleepDraftContext context);
}

enum SleepDraftOperation { open, read, save, clear, close }

class SleepDraftStorageException implements Exception {
  const SleepDraftStorageException(this.operation, this.cause);
  final SleepDraftOperation operation;
  final Object cause;
  @override
  String toString() =>
      'Sleep draft storage operation failed: ${operation.name}.';
}

class SleepDraftDataException implements Exception {
  const SleepDraftDataException();
  @override
  String toString() => 'Stored sleep draft is invalid.';
}
