import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'sleep_type.dart';
import 'time_precision.dart';

/// 独立的完整睡眠事实（SL-001–SL-003、SL-005）。
///
/// 跨日不拆分；类型与两端精度独立，不引入睡眠生命周期状态。
/// 构造只校验单对象，不读取时钟或执行保存、重叠检查、日投影。
final class SleepSession {
  SleepSession({
    required EntityId id,
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    String? note,
  }) : id = requireUuidV4(id),
       note = _normalizeNote(note) {
    intervalMilliseconds(startedAt: startedAt, endedAt: endedAt);
  }

  final EntityId id;

  /// UTC epoch 毫秒，保留原始严格正半开区间 [startedAt, endedAt)。
  final InstantMilliseconds startedAt;
  final InstantMilliseconds endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;
  final SleepType type;

  /// 可选长文本；清理首尾空白，保留内部格式（MODEL-002、Q-015）。
  final String? note;

  /// 调用方显式提供的元数据，不从事实边界推导（Q-018）。
  final InstantMilliseconds createdAt;
  final InstantMilliseconds updatedAt;
}

String? _normalizeNote(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.runes.length > 2000) {
    throw ArgumentError.value(
      value,
      'note',
      'MODEL-002: Must not exceed 2000 Unicode code points',
    );
  }
  return normalized;
}
