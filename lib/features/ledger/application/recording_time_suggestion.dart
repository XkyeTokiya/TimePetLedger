import '../../../core/time/time_contract.dart';
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

/// Q-023 优先表。coverage 必须是所选日期全部正式事实的 E3 投影，
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
