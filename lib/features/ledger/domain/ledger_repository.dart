import '../../../core/identity/entity_id.dart';
import '../../../core/time/time_contract.dart';
import 'annotation_change.dart';
import 'block_knowledge_state.dart';
import 'ledger_conflicts.dart';
import 'sleep_type.dart';
import 'time_precision.dart';
import 'rhythm_annotation.dart';
import 'sleep_session.dart';
import 'time_block.dart';

/// 账本的受控存取边界；身份、窗口和取时均由调用方显式提供。
abstract interface class LedgerRepository {
  /// 返回与 [startedAt, endedAt) 有正时长交集的两类完整事实及其解释。
  /// 相接不算相交；空窗口返回空集合，反向窗口抛 ArgumentError。
  /// 全部集合来自同一数据库事务，不裁剪、过滤 Goal 或推断节奏。
  Future<LedgerSnapshot> readWindow({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  });

  /// 窗口内完整事实及两侧最近的真实记录，跨自然日寻找边界。
  /// 空窗口可用于查询时点邻居；不把午夜或查询窗口端点当成事实。
  Future<List<LedgerFactInterval>> readRecordingContext({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  });

  /// Complete, finished sleep facts, newest first. The prediction model selects
  /// its bounded training window after distinguishing independent/weak evidence.
  Future<List<SleepSession>> readSleepHistory({
    required InstantMilliseconds now,
  });

  /// 同一事务读取 W 的事实与醒来日期的完整睡眠候选。
  /// 日边界由设备日期适配显式提供，候选 endedAt ∈ [dayStart, nextDay)。
  /// W 必须位于该日内，可为空；空 W 仍查询摘要并暴露读取失败。
  Future<SleepLedgerSnapshot> readSleepContext({
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required InstantMilliseconds dayStartedAt,
    required InstantMilliseconds nextDayStartedAt,
  });

  /// 按身份读取完整原始 TimeBlock 与可选解释；缺失返回 null。
  /// 编辑不从日窗口切片重建源事实。
  Future<TimeBlockWriteResult?> readTimeBlock(EntityId id);

  /// 按身份读取完整原始睡眠；缺失返回 null，不从日切片重建事实。
  Future<SleepSession?> readSleepSession(EntityId id);

  /// 创建事实及可选解释；只在整个事务提交后返回。重复身份不覆盖。
  Future<TimeBlockWriteResult> createTimeBlock({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required BlockKnowledgeState knowledgeState,
    required InstantMilliseconds now,
    String? title,
    EntityId? goalId,
    String? categoryId,
    String? note,
    AddAnnotation? annotation,
  });

  /// 更正事务内读取的当前事实；省略可空字段保留，(value: null) 清空。
  /// 解释默认保留，单独编辑解释也使用此入口，不接受所属事实 id 更改。
  Future<TimeBlockWriteResult> updateTimeBlock({
    required EntityId id,
    required InstantMilliseconds now,
    InstantMilliseconds? startedAt,
    InstantMilliseconds? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    BlockKnowledgeState? knowledgeState,
    ({String? value})? title,
    ({EntityId? value})? goalId,
    ({String? value})? categoryId,
    ({String? value})? note,
    AnnotationChange annotation = const KeepAnnotation(),
  });

  Future<SleepSession> createSleepSession({
    required EntityId id,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
    required TimePrecision startPrecision,
    required TimePrecision endPrecision,
    required SleepType type,
    required InstantMilliseconds now,
    String? note,
  });

  Future<SleepSession> updateSleepSession({
    required EntityId id,
    required InstantMilliseconds now,
    InstantMilliseconds? startedAt,
    InstantMilliseconds? endedAt,
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
    SleepType? type,
    ({String? value})? note,
  });

  /// 删除缺失事实幂等完成；删除 TimeBlock 同时删除其解释，不触及复盘。
  Future<void> deleteTimeBlock(EntityId id);
  Future<void> deleteSleepSession(EntityId id);
}

typedef TimeBlockWriteResult = ({
  TimeBlock timeBlock,
  RhythmAnnotation? annotation,
});

/// 保留全部冲突身份与完整区间，供调用方提示并手动调整。
class LedgerConflictException implements Exception {
  LedgerConflictException(Iterable<LedgerFactInterval> conflicts)
    : conflicts = List.unmodifiable(conflicts);
  final List<LedgerFactInterval> conflicts;
  @override
  String toString() => 'Ledger facts overlap.';
}

class LedgerFactNotFoundException implements Exception {
  const LedgerFactNotFoundException(this.reference);
  final LedgerFactReference reference;
  @override
  String toString() => 'Ledger fact no longer exists.';
}

class LedgerFactAlreadyExistsException implements Exception {
  const LedgerFactAlreadyExistsException(this.reference);
  final LedgerFactReference reference;
  @override
  String toString() => 'Ledger fact identity already exists.';
}

enum AnnotationOperationFailure { alreadyExists, notFound }

class LedgerAnnotationOperationException implements Exception {
  const LedgerAnnotationOperationException(this.reason);
  final AnnotationOperationFailure reason;
  @override
  String toString() =>
      'Annotation operation is not valid for the current relation.';
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
  String toString() => 'Ledger storage operation failed.';
}

/// 窗口事实与完整摘要候选来自同一读取视图，两个集合不可互相替代。
final class SleepLedgerSnapshot {
  SleepLedgerSnapshot({
    required this.windowFacts,
    required Iterable<SleepSession> sleepSummaryCandidates,
  }) : sleepSummaryCandidates = List.unmodifiable(sleepSummaryCandidates);

  final LedgerSnapshot windowFacts;
  final List<SleepSession> sleepSummaryCandidates;
}
