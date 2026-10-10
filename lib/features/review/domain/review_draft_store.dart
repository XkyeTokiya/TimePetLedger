import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';

/// 稳定的草稿入口身份，与正在编辑的复盘日期分开。
final class ReviewDraftContext {
  const ReviewDraftContext.newEntry({required CivilDate date})
    : entryDate = date,
      reviewId = null;

  ReviewDraftContext.edit({required EntityId reviewId})
    : reviewId = requireUuidV4(reviewId),
      entryDate = null;

  final CivilDate? entryDate;
  final EntityId? reviewId;
  bool get isEditing => reviewId != null;
}

/// 未完成输入的完整快照，不是 DailyReview 或部分正式更新指令。
/// 原样保留 null、空白、多行和超长文本；正式提交另行校验。
final class ReviewDraft {
  const ReviewDraft({
    required this.context,
    required this.date,
    this.dateInput,
    this.summary,
    this.reflection,
    this.tomorrowFirstStepText,
    this.tomorrowFirstStepGoalId,
    this.flowStep,
    this.extraFocusIds,
    this.hiddenGapKeys,
    this.stuckPickId,
    this.stuckNone,
    this.stuckReasonText,
    this.stuckReasonForId,
  });

  final ReviewDraftContext context;

  /// 当前解析的日期；未完成 / 无效日期输入可为 null。
  final CivilDate? date;
  final String? dateInput;
  final String? summary;
  final String? reflection;
  final String? tomorrowFirstStepText;

  /// 原目标身份可保留；不在草稿存储中查询目标状态或建立正式外键。
  /// 保存完整快照时 null 表示当前未选择或已清空。
  final EntityId? tomorrowFirstStepGoalId;

  // ----- 四步向导的会话状态（Q-012，REVIEW-R2-14） -----
  // 仅会话快照使用；正式提交构造的草稿不设置这些字段。

  /// 当前向导步骤（1–4），对应 Q-012 的“活动步骤”。
  final int? flowStep;

  /// 手动加入“今天关心过的事情”的记录。
  final List<EntityId>? extraFocusIds;

  /// “先留着”的缺口键（`startedAt:endedAt`）。
  final List<String>? hiddenGapKeys;

  /// 第 3 步选中的卡住记录；与 [stuckNone] 一起还原选择。
  final EntityId? stuckPickId;
  final bool? stuckNone;

  /// “当时卡在哪里”尚未提交的原文及其所属记录。
  final String? stuckReasonText;
  final EntityId? stuckReasonForId;
}

abstract interface class ReviewDraftStore {
  /// null 仅表示无草稿；数据 / 存储失败必须传播。
  Future<ReviewDraft?> read(ReviewDraftContext context);
  Future<void> save(ReviewDraft draft);
  Future<void> clear(ReviewDraftContext context);
}

enum ReviewDraftOperation { open, read, save, clear, close }

class ReviewDraftStorageException implements Exception {
  const ReviewDraftStorageException(this.operation, this.cause);
  final ReviewDraftOperation operation;
  final Object cause;
  @override
  String toString() =>
      'Review draft storage operation failed: ${operation.name}.';
}

class ReviewDraftDataException implements Exception {
  const ReviewDraftDataException();
  @override
  String toString() => 'Stored review draft is invalid.';
}
