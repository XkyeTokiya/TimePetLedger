import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'block_knowledge_state.dart';
import 'time_precision.dart';

/// 一段普通时间事实（MODEL-001、TB-001–TB-009）。
///
/// 构造时完成单对象校验与文本规范化。身份、元数据和两端精度均由
/// 调用方显式提供；构造不读取时钟，也不代表已经成功保存。
/// RhythmAnnotation 独立引用本对象，不是构造本对象的前提。
/// Q-003、Q-013 的纯更正操作见 time_block_correction.dart；本对象不执行删除。
final class TimeBlock {
  TimeBlock({
    required EntityId id,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.knowledgeState,
    required this.createdAt,
    required this.updatedAt,
    String? title,
    this.goalId,
    this.categoryId,
    String? note,
  }) : id = requireUuidV4(id),
       title = _normalizeText(title, field: 'title', maxCodePoints: 200),
       note = _normalizeText(note, field: 'note', maxCodePoints: 2000) {
    intervalMilliseconds(startedAt: startedAt, endedAt: endedAt);
    if (knowledgeState == BlockKnowledgeState.known && this.title == null) {
      throw ArgumentError.value(
        title,
        'title',
        'TB-005: known requires a title',
      );
    }
    final goal = goalId;
    if (goal != null) {
      try {
        requireUuidV4(goal);
      } on ArgumentError {
        throw ArgumentError.value(goal, 'goalId', 'Q-018: Must be a UUID v4');
      }
    }
  }

  final EntityId id;

  /// UTC epoch 毫秒，组成严格正半开区间 [startedAt, endedAt)。
  final InstantMilliseconds startedAt;
  final InstantMilliseconds endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;
  final BlockKnowledgeState knowledgeState;

  /// 清理后的短文本；known 非空，unknown 可空或保留描述。
  final String? title;

  /// 可选归属；目标是否存在、是否归档需要关联上下文，留给后续校验。
  final EntityId? goalId;

  /// 可空扩展值，原样保留；当前没有 Category 实体或外键行为。
  final String? categoryId;

  /// 清理后的可选长文本，保留内部空格、换行和段落。
  final String? note;

  /// 调用方提供的元数据，与事实区间无默认对应关系（Q-018）。
  final InstantMilliseconds createdAt;
  final InstantMilliseconds updatedAt;
}

/// MODEL-002 / Q-015：清理后按 Unicode 码点计数，不截断或折叠内部文本。
String? _normalizeText(
  String? value, {
  required String field,
  required int maxCodePoints,
}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.runes.length > maxCodePoints) {
    throw ArgumentError.value(
      value,
      field,
      'MODEL-002: Must not exceed $maxCodePoints Unicode code points',
    );
  }
  return normalized;
}
