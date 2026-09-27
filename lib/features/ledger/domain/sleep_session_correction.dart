import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'ledger_conflicts.dart';
import 'sleep_session.dart';
import 'sleep_type.dart';
import 'time_precision.dart';

typedef SleepSessionCorrectionResult = ({
  SleepSession sleepSession,
  bool changed,
});

/// 携带全部冲突的完整区间，不截断或移动其他事实。
final class SleepSessionCorrectionConflict implements Exception {
  SleepSessionCorrectionConflict(this.conflicts);

  final List<LedgerFactInterval> conflicts;

  @override
  String toString() =>
      'SleepSession correction overlaps ${conflicts.length} facts';
}

/// Q-013、Q-016、Q-018：更正完整睡眠事实，不生成新身份、不按午夜拆分。
///
/// original 为调用方读取的原记录，缺失时拒绝更正；existing 为可能
/// 冲突的两类完整事实，更新仅排除同类型同 id 的旧睡眠。
/// 未提供的字段保留；note: (value: null) 显式清空备注。
///
/// 返回待保存值：有变化时 updatedAt 使用注入的 now，无变化保留原值。
/// data 须在写事务内检查并提交，仅成功后发布结果，失败保留原记录。
/// 不查询、不保存、不更正或删除 DailyReview，不新增生命周期状态。
SleepSessionCorrectionResult correctSleepSession({
  required SleepSession? original,
  required Iterable<LedgerFactInterval> existing,
  required InstantMilliseconds now,
  InstantMilliseconds? startedAt,
  InstantMilliseconds? endedAt,
  TimePrecision? startPrecision,
  TimePrecision? endPrecision,
  SleepType? type,
  ({String? value})? note,
}) {
  if (original == null) throw StateError('Q-013: 记录已不存在');
  final candidate = SleepSession(
    id: original.id,
    createdAt: original.createdAt,
    updatedAt: now,
    startedAt: startedAt ?? original.startedAt,
    endedAt: endedAt ?? original.endedAt,
    startPrecision: startPrecision ?? original.startPrecision,
    endPrecision: endPrecision ?? original.endPrecision,
    type: type ?? original.type,
    note: note == null ? original.note : note.value,
  );
  final interval = LedgerFactInterval.fromSleepSession(candidate);
  final conflicts = findLedgerConflicts(
    candidate: interval,
    existing: existing,
    replacing: interval.reference,
  );
  if (conflicts.isNotEmpty) throw SleepSessionCorrectionConflict(conflicts);
  final changed =
      candidate.startedAt != original.startedAt ||
      candidate.endedAt != original.endedAt ||
      candidate.startPrecision != original.startPrecision ||
      candidate.endPrecision != original.endPrecision ||
      candidate.type != original.type ||
      candidate.note != original.note;
  return (sleepSession: changed ? candidate : original, changed: changed);
}
