import '../../../../core/time/time_contract.dart';

/// 单项非持久化时长；近似仅属于这一项的实际参与边界（Q-014）。
final class DerivedDuration {
  factory DerivedDuration({
    required int milliseconds,
    required bool hasApproximation,
  }) {
    if (milliseconds < 0) {
      throw ArgumentError.value(
        milliseconds,
        'milliseconds',
        'Must be nonnegative',
      );
    }
    return DerivedDuration._(
      milliseconds,
      milliseconds > 0 && hasApproximation,
    );
  }

  const DerivedDuration._(this.milliseconds, this.hasApproximation);

  /// 只累加实际毫秒，近似取正时长参与项的 OR；空集为精确的数值零。
  factory DerivedDuration.sum(Iterable<DerivedDuration> contributions) {
    var milliseconds = 0;
    var hasApproximation = false;
    for (final contribution in contributions) {
      milliseconds += contribution.milliseconds;
      hasApproximation |= contribution.hasApproximation;
    }
    return DerivedDuration._(milliseconds, hasApproximation);
  }

  final int milliseconds;
  final bool hasApproximation;

  /// 仅供最终展示使用，不能将舍入后的结果重新参与汇总（Q-017）。
  int get roundedMinutes => roundedDisplayMinutes(milliseconds);
}

/// 摘要中的存在性独立于展示分钟数；不把缺失解释为没有活动（Q-021）。
final class SummaryDuration {
  const SummaryDuration._({required this.duration, required this.hasRecords});

  /// 输入为调用方已选择的记录贡献，每条记录使用实际参与口径的时长。
  ///
  /// 零时长不构成参与记录；窗口外 / 仅相接的记录不能制造摘要存在性。
  /// 完整睡眠摘要应传完整时长，不能用窗口切片时长替代。
  factory SummaryDuration.fromRecords(Iterable<DerivedDuration> contributions) {
    var hasRecords = false;
    final duration = DerivedDuration.sum(
      contributions.where((contribution) {
        if (contribution.milliseconds == 0) return false;
        hasRecords = true;
        return true;
      }),
    );
    return SummaryDuration._(duration: duration, hasRecords: hasRecords);
  }

  final DerivedDuration duration;
  final bool hasRecords;

  int get milliseconds => duration.milliseconds;
  bool get hasApproximation => duration.hasApproximation;
}
