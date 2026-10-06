import '../../../core/time/time_contract.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/reconciliation_window.dart';
import '../domain/time_precision.dart';

/// 尚未确认的时间输入，不是正式事实；允许未填完或暂时无效的起止。
/// 保存时仍须执行领域和原子冲突校验。精度只能由显式选择改变。
final class RecordingTimeInput {
  const RecordingTimeInput({
    this.startedAt,
    this.endedAt,
    this.startPrecision = TimePrecision.approximate,
    this.endPrecision = TimePrecision.approximate,
  });

  final InstantMilliseconds? startedAt;
  final InstantMilliseconds? endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;

  RecordingTimeInput withTimes({
    required InstantMilliseconds? startedAt,
    required InstantMilliseconds? endedAt,
  }) => RecordingTimeInput(
    startedAt: startedAt,
    endedAt: endedAt,
    startPrecision: startPrecision,
    endPrecision: endPrecision,
  );

  RecordingTimeInput withPrecisions({
    TimePrecision? startPrecision,
    TimePrecision? endPrecision,
  }) => RecordingTimeInput(
    startedAt: startedAt,
    endedAt: endedAt,
    startPrecision: startPrecision ?? this.startPrecision,
    endPrecision: endPrecision ?? this.endPrecision,
  );
}

sealed class RecordingTimeSuggestion {
  const RecordingTimeSuggestion();
}

/// 可修改的直接建议，仍不等于保存事实。
final class DirectTimeSuggestion extends RecordingTimeSuggestion {
  const DirectTimeSuggestion(this.input);
  final RecordingTimeInput input;
}

/// 不预选任何一项；即使只有一个候选也须用户确认。
final class TimeCandidates extends RecordingTimeSuggestion {
  TimeCandidates(Iterable<RecordingTimeInput> candidates)
    : candidates = List.unmodifiable(candidates);
  final List<RecordingTimeInput> candidates;
}

final class ManualTimeEntry extends RecordingTimeSuggestion {
  const ManualTimeEntry();
  RecordingTimeInput get input => const RecordingTimeInput();
}

RecordingTimeInput _prefill(UnresolvedSpan gap) =>
    RecordingTimeInput(startedAt: gap.startedAt, endedAt: gap.endedAt);

/// 使用完整相邻事实初始化活动 / 睡眠，不以自然日切片猜端点。
/// [preferClosedGaps] 保留 TIME-01 旧调用兼容；生产睡眠使用独立预测加载器。
/// 普通活动的长尾部沿 TIME-03 取最近一小时。
RecordingTimeSuggestion suggestRecordingTimeFromFacts({
  required LedgerDateRelation relation,
  required int now,
  required int dayStartedAt,
  required int nextDayStartedAt,
  required Iterable<LedgerFactInterval> facts,
  UnresolvedSpan? explicitGap,
  bool preferClosedGaps = false,
}) {
  final ordered = facts.toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  RecordingTimeSuggestion interval(int start, int? end) => DirectTimeSuggestion(
    RecordingTimeInput(
      startedAt: start,
      endedAt: end ?? (now > start + 1800000 ? now : start + 1800000),
    ),
  );
  if (explicitGap != null) {
    LedgerFactInterval? previous;
    LedgerFactInterval? next;
    for (final fact in ordered) {
      if (fact.startedAt < explicitGap.endedAt &&
          fact.endedAt > explicitGap.startedAt) {
        return const ManualTimeEntry(); // 入口缺口已被其他正式记录占用。
      }
      if (fact.endedAt <= explicitGap.startedAt &&
          (previous == null || fact.endedAt > previous.endedAt)) {
        previous = fact;
      }
      if (fact.startedAt >= explicitGap.endedAt &&
          (next == null || fact.startedAt < next.startedAt)) {
        next = fact;
      }
    }
    return previous == null
        ? const ManualTimeEntry()
        : interval(previous.endedAt, next?.startedAt);
  }
  if (relation == LedgerDateRelation.future) return const ManualTimeEntry();
  if (preferClosedGaps) {
    for (var i = 1; i < ordered.length; i++) {
      final start = ordered[i - 1].endedAt;
      final end = ordered[i].startedAt;
      if (start < end && start < nextDayStartedAt && end > dayStartedAt) {
        return interval(start, end);
      }
    }
  }
  final anchor = relation == LedgerDateRelation.today ? now : nextDayStartedAt;
  LedgerFactInterval? previous;
  for (final fact in ordered) {
    if (fact.startedAt <= anchor && fact.endedAt > anchor) {
      return const ManualTimeEntry();
    }
    if (fact.endedAt <= anchor &&
        (previous == null || fact.endedAt > previous.endedAt)) {
      previous = fact;
    }
  }
  // Q-037：普通活动在长时间断记后从近期一笔继续，较早空白仍为 Gap。
  // 无前序事实时只使用当前已知对账窗口，不假定窗口之前也没有记录。
  // 在占用检查之后执行，且不将此活动策略用于睡眠或显式 Gap 补记。
  final tailStartedAt = previous?.endedAt ?? dayStartedAt;
  if (relation == LedgerDateRelation.today &&
      !preferClosedGaps &&
      now - tailStartedAt >= const Duration(hours: 5).inMilliseconds) {
    return interval(now - const Duration(hours: 1).inMilliseconds, now);
  }
  if (previous == null) return const ManualTimeEntry();
  // 历史浏览中有后续正式记录时，普通新建不横跨已知事实。
  if (relation == LedgerDateRelation.historical &&
      ordered.any(
        (fact) => fact.startedAt >= previous!.endedAt && fact.startedAt < now,
      )) {
    return const ManualTimeEntry();
  }
  final proposedEnd = now > previous.endedAt + 1800000
      ? now
      : previous.endedAt + 1800000;
  if (ordered.any(
    (fact) =>
        fact.startedAt >= previous!.endedAt && fact.startedAt < proposedEnd,
  )) {
    return const ManualTimeEntry(); // 普通新建的30分钟初值会跨入已知记录。
  }
  return interval(previous.endedAt, null);
}

/// 历史 Q-023 优先表，仅保留供早期样板使用。
/// 当前生产入口使用 [suggestRecordingTimeFromFacts] 的 Q-035 / Q-037 合同。
/// coverage 必须是所选日期全部正式事实的 E3 投影，
/// relation 与其窗口一致（可直接使用 E4-T01 的 context 与 coverage）。
/// explicitGap 表示用户已明确选择的 Gap；不因普通入口分支取消预填。
/// 不读取时钟、重算 Gap、量化时间或继承 Gap 边界的 exact 精度。
RecordingTimeSuggestion suggestRecordingTime({
  required LedgerDateRelation relation,
  required LedgerCoverage coverage,
  UnresolvedSpan? explicitGap,
}) {
  if (explicitGap != null) {
    return DirectTimeSuggestion(_prefill(explicitGap));
  }
  final gaps = coverage.unresolvedSpans;
  if (relation == LedgerDateRelation.future ||
      gaps.isEmpty ||
      coverage.accountedDuration.milliseconds == 0) {
    return const ManualTimeEntry();
  }
  // E3 按时间顺序返回 Gap，今天窗口的结束即调用方提供的 now。
  if (relation == LedgerDateRelation.today &&
      gaps.last.endedAt == coverage.window.endedAt) {
    return DirectTimeSuggestion(_prefill(gaps.last));
  }
  return TimeCandidates(gaps.map(_prefill));
}
