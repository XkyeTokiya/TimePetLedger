import '../../../../core/identity/entity_id.dart';
import '../../../../core/time/time_contract.dart';
import '../ledger_conflicts.dart';
import '../rhythm_annotation.dart';
import '../sleep_session.dart';
import '../time_block.dart';
import '../time_precision.dart';
import 'derived_duration.dart';
import 'reconciliation_window.dart';

/// 非持久化的正时长事实切片；源事实仍完整保留（SL-002、LEDGER-003）。
sealed class LedgerSegment {
  const LedgerSegment._(this._bounds);

  final _SliceBounds _bounds;

  LedgerFactReference get reference;
  InstantMilliseconds get startedAt => _bounds.startedAt;
  InstantMilliseconds get endedAt => _bounds.endedAt;

  /// 切片实际使用的边界精度；窗口替换的边界为 exact（Q-014）。
  TimePrecision get startPrecision => _bounds.startPrecision;
  TimePrecision get endPrecision => _bounds.endPrecision;

  DerivedDuration get duration => DerivedDuration(
    milliseconds: intervalMilliseconds(startedAt: startedAt, endedAt: endedAt),
    hasApproximation:
        startPrecision == TimePrecision.approximate ||
        endPrecision == TimePrecision.approximate,
  );
}

/// 内容、Goal、已知性和原始精度来自 source，解释只依附这一条 TimeBlock。
final class TimeBlockSegment extends LedgerSegment {
  const TimeBlockSegment._(super.bounds, this.source, this.annotation)
    : super._();

  final TimeBlock source;
  final RhythmAnnotation? annotation;

  @override
  LedgerFactReference get reference =>
      (type: LedgerFactType.timeBlock, id: source.id);
}

/// 睡眠类型、备注及完整起止来自 source，不附加 RhythmAnnotation。
final class SleepSessionSegment extends LedgerSegment {
  const SleepSessionSegment._(super.bounds, this.source) : super._();

  final SleepSession source;

  @override
  LedgerFactReference get reference =>
      (type: LedgerFactType.sleepSession, id: source.id);
}

/// 将两类完整事实裁剪到显式窗口，返回按起点排序的不可修改集合。
///
/// 输入应为合法、不重叠、同类型身份唯一的事实快照；不去重、合并或
/// 修复重叠。annotation 按 timeBlockId 匹配，不成为独立片段；输入中
/// 不贡献切片的记录及其解释不会产生输出。重复解释引用拒绝而不覆盖。
/// 不读取时钟、不改变输入集合或源对象，不对毫秒进行舍入。
List<LedgerSegment> projectLedgerSegments({
  required ReconciliationWindow window,
  required Iterable<TimeBlock> timeBlocks,
  required Iterable<SleepSession> sleepSessions,
  required Iterable<RhythmAnnotation> annotations,
}) {
  final byTimeBlock = <EntityId, RhythmAnnotation>{};
  for (final annotation in annotations) {
    if (byTimeBlock.containsKey(annotation.timeBlockId)) {
      throw ArgumentError('RH-001: At most one annotation per TimeBlock');
    }
    byTimeBlock[annotation.timeBlockId] = annotation;
  }

  final segments = <LedgerSegment>[];
  if (window.isEmpty) return List.unmodifiable(segments);
  for (final block in timeBlocks) {
    final bounds = _clip(
      window: window,
      startedAt: block.startedAt,
      endedAt: block.endedAt,
      startPrecision: block.startPrecision,
      endPrecision: block.endPrecision,
    );
    if (bounds != null) {
      segments.add(TimeBlockSegment._(bounds, block, byTimeBlock[block.id]));
    }
  }
  for (final sleep in sleepSessions) {
    final bounds = _clip(
      window: window,
      startedAt: sleep.startedAt,
      endedAt: sleep.endedAt,
      startPrecision: sleep.startPrecision,
      endPrecision: sleep.endPrecision,
    );
    if (bounds != null) {
      segments.add(SleepSessionSegment._(bounds, sleep));
    }
  }
  segments.sort((left, right) => left.startedAt.compareTo(right.startedAt));
  return List.unmodifiable(segments);
}

typedef _SliceBounds = ({
  InstantMilliseconds startedAt,
  InstantMilliseconds endedAt,
  TimePrecision startPrecision,
  TimePrecision endPrecision,
});

_SliceBounds? _clip({
  required ReconciliationWindow window,
  required InstantMilliseconds startedAt,
  required InstantMilliseconds endedAt,
  required TimePrecision startPrecision,
  required TimePrecision endPrecision,
}) {
  final cutStart = startedAt < window.startedAt;
  final cutEnd = endedAt > window.endedAt;
  final start = cutStart ? window.startedAt : startedAt;
  final end = cutEnd ? window.endedAt : endedAt;
  if (start >= end) return null;
  return (
    startedAt: start,
    endedAt: end,
    startPrecision: cutStart ? TimePrecision.exact : startPrecision,
    endPrecision: cutEnd ? TimePrecision.exact : endPrecision,
  );
}
