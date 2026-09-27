import '../../../core/time/time_contract.dart';
import 'rhythm_annotation.dart';
import 'sleep_session.dart';
import 'time_block.dart';

/// 完整事实读取；窗口由调用方提供，不读取时钟或决定自然日政策。
abstract interface class LedgerRepository {
  /// 返回与 [startedAt, endedAt) 有正时长交集的两类完整事实及其解释。
  /// 相接不算相交；空窗口返回空集合，反向窗口抛 ArgumentError。
  /// 全部集合来自同一数据库事务，不裁剪、过滤 Goal 或推断节奏。
  Future<LedgerSnapshot> readWindow({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  });
}

/// 一次读取的不可变输入集合，不是 DayLedgerView，也不持久化。
final class LedgerSnapshot {
  LedgerSnapshot({
    required Iterable<TimeBlock> timeBlocks,
    required Iterable<SleepSession> sleepSessions,
    required Iterable<RhythmAnnotation> annotations,
  }) : timeBlocks = List.unmodifiable(timeBlocks),
       sleepSessions = List.unmodifiable(sleepSessions),
       annotations = List.unmodifiable(annotations);

  final List<TimeBlock> timeBlocks;
  final List<SleepSession> sleepSessions;
  final List<RhythmAnnotation> annotations;
}

/// 任何一行非法均使整次读取失败，不丢行或替换为 Unknown。
class LedgerDataException implements Exception {
  const LedgerDataException(this.table, this.field);
  final String table;
  final String field;
  @override
  String toString() => 'Stored ledger data is invalid.';
}

class LedgerStorageException implements Exception {
  const LedgerStorageException(this.cause);

  /// 仅供诊断，用户反馈不直接展示底层驱动信息。
  final Object cause;
  @override
  String toString() => 'Ledger read failed.';
}
