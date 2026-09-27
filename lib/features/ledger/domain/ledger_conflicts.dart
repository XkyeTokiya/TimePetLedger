import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

import 'sleep_session.dart';
import 'time_block.dart';

/// 主要事实的身份命名空间，不是 TimeBlock 的活动分类。
enum LedgerFactType { timeBlock, sleepSession }

typedef LedgerFactReference = ({LedgerFactType type, EntityId id});

/// 用于冲突判定的完整事实区间；不持久化，也不替代原领域对象。
///
/// 仅从已校验的事实构造，不裁剪到自然日、不舍入毫秒。
final class LedgerFactInterval {
  LedgerFactInterval.fromTimeBlock(TimeBlock block)
    : reference = (type: LedgerFactType.timeBlock, id: block.id),
      startedAt = block.startedAt,
      endedAt = block.endedAt;

  LedgerFactInterval.fromSleepSession(SleepSession sleep)
    : reference = (type: LedgerFactType.sleepSession, id: sleep.id),
      startedAt = sleep.startedAt,
      endedAt = sleep.endedAt;

  final LedgerFactReference reference;
  final InstantMilliseconds startedAt;
  final InstantMilliseconds endedAt;
}

/// 返回与候选存在正时长交集的已有完整区间（LEDGER-004、Q-017）。
///
/// 按输入顺序返回全部冲突，不要求输入排序。精度、已知性、目标、
/// 睡眠类型都不豁免冲突。不修改输入、不查询、不合并或修正事实。
///
/// 新增时不传 replacing，即使 id 相同也不自动排除。原地更新时须
/// 显式传入候选的类型和身份，仅排除同类型同 id 的旧记录。
/// 调用方负责提供完整已有事实；存储层仍须在写事务内检查并写入，
/// 本函数不保证查询完整性、身份唯一性或并发写入的原子性。
List<LedgerFactInterval> findLedgerConflicts({
  required LedgerFactInterval candidate,
  required Iterable<LedgerFactInterval> existing,
  LedgerFactReference? replacing,
}) {
  if (replacing != null && replacing != candidate.reference) {
    throw ArgumentError.value(
      replacing,
      'replacing',
      'An update must preserve the candidate fact type and identity',
    );
  }
  return List.unmodifiable([
    for (final interval in existing)
      if (interval.reference != replacing &&
          interval.startedAt < candidate.endedAt &&
          interval.endedAt > candidate.startedAt)
        interval,
  ]);
}
