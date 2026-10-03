import '../../../../core/time/civil_date.dart';
import '../../../../core/time/time_contract.dart';

/// 调用方按当前设备时区确定的查询日期与今天的关系（Q-008）。
enum LedgerDateRelation { historical, today, future }

/// 非持久化的半开对账窗口；空窗口以 [startedAt, startedAt) 表达。
final class ReconciliationWindow {
  const ReconciliationWindow._({
    required this.date,
    required this.startedAt,
    required this.endedAt,
  });

  /// 调用方提供 date 的当地零点、次日零点及日期关系（Q-009）。
  ///
  /// 不从 UTC 日期猜测当地日期，不读取时区或时钟。日边界必须严格
  /// 递增，日长按实际边界计算。today 的 now 必须在该当地日内；
  /// 不一致的输入拒绝而不静默截断。历史日与未来日不使用 now 截止。
  factory ReconciliationWindow.select({
    required CivilDate date,
    required LedgerDateRelation relation,
    required InstantMilliseconds dayStartedAt,
    required InstantMilliseconds nextDayStartedAt,
    required InstantMilliseconds now,
  }) {
    intervalMilliseconds(startedAt: dayStartedAt, endedAt: nextDayStartedAt);
    if (relation == LedgerDateRelation.today &&
        !containsInstant(
          startedAt: dayStartedAt,
          endedAt: nextDayStartedAt,
          instant: now,
        )) {
      throw ArgumentError.value(now, 'now', 'Must be within the supplied day');
    }
    return ReconciliationWindow._(
      date: date,
      startedAt: dayStartedAt,
      endedAt: switch (relation) {
        LedgerDateRelation.historical => nextDayStartedAt,
        LedgerDateRelation.today => now,
        LedgerDateRelation.future => dayStartedAt,
      },
    );
  }

  final CivilDate date;
  final InstantMilliseconds startedAt;
  final InstantMilliseconds endedAt;

  bool get isEmpty => startedAt == endedAt;

  int get milliseconds => isEmpty
      ? 0
      : intervalMilliseconds(startedAt: startedAt, endedAt: endedAt);
}
