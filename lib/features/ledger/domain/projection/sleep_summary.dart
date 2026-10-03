import '../../../../core/time/time_contract.dart';
import '../sleep_session.dart';
import '../sleep_type.dart';
import '../time_precision.dart';
import 'derived_duration.dart';

/// 同一醒来日期、同一类型的完整睡眠；原始起止和独立精度来自 records。
final class SleepTypeSummary {
  SleepTypeSummary._(Iterable<SleepSession> sessions)
    : records = List.unmodifiable(sessions) {
    totalDuration = SummaryDuration.fromRecords(
      records.map(
        (sleep) => DerivedDuration(
          milliseconds: intervalMilliseconds(
            startedAt: sleep.startedAt,
            endedAt: sleep.endedAt,
          ),
          hasApproximation:
              sleep.startPrecision == TimePrecision.approximate ||
              sleep.endPrecision == TimePrecision.approximate,
        ),
      ),
    );
  }

  final List<SleepSession> records;
  late final SummaryDuration totalDuration;
}

/// 非持久化完整睡眠摘要；不与日窗口切片时长混用（Q-010）。
final class SleepSummary {
  SleepSummary._(List<SleepSession> records)
    : mainSleep = SleepTypeSummary._(
        records.where((sleep) => sleep.type == SleepType.mainSleep),
      ),
      nap = SleepTypeSummary._(
        records.where((sleep) => sleep.type == SleepType.nap),
      );

  final SleepTypeSummary mainSleep;
  final SleepTypeSummary nap;
}

/// 调用方按当前设备时区提供 D 的零点和次日零点（Q-008）。
///
/// 必须传完整日边界，不传截至 now 的 W；候选为合法、身份唯一且不
/// 重叠的完整事实，允许在 W 外。以 endedAt 落入当地日半开区间选择
/// 全部记录，包括零点醒来和未来结束的记录。只累计每段实际时长。
/// 返回按原始起点排序的不可修改列表；不修改输入、不读取时区或时钟。
SleepSummary projectSleepSummary({
  required Iterable<SleepSession> sleepSessions,
  required InstantMilliseconds dayStartedAt,
  required InstantMilliseconds nextDayStartedAt,
}) {
  intervalMilliseconds(startedAt: dayStartedAt, endedAt: nextDayStartedAt);
  final selected =
      sleepSessions
          .where(
            (sleep) =>
                dayStartedAt <= sleep.endedAt &&
                sleep.endedAt < nextDayStartedAt,
          )
          .toList()
        ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
  return SleepSummary._(selected);
}

/// 只判断今天是否已有结束的主睡眠，不负责首次打开或提醒调度（SL-004）。
///
/// 当地日边界与 now 均显式注入；now 必须属于所提供的今天。
/// nap、其他日期醒来或 endedAt > now 的主睡眠不能满足已记录判定。
bool hasRecordedMainSleepToday({
  required Iterable<SleepSession> sleepSessions,
  required InstantMilliseconds dayStartedAt,
  required InstantMilliseconds nextDayStartedAt,
  required InstantMilliseconds now,
}) {
  if (!containsInstant(
    startedAt: dayStartedAt,
    endedAt: nextDayStartedAt,
    instant: now,
  )) {
    throw ArgumentError.value(now, 'now', 'Must be within the supplied today');
  }
  return sleepSessions.any(
    (sleep) =>
        sleep.type == SleepType.mainSleep &&
        dayStartedAt <= sleep.endedAt &&
        sleep.endedAt <= now,
  );
}
