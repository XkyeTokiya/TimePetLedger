import '../../core/time/civil_date.dart';
import '../../core/time/time_contract.dart';
import '../../features/ledger/application/recording_ledger_loader.dart';
import '../../features/ledger/domain/projection/reconciliation_window.dart';

/// 使用运行时当前设备时区。now 是绝对毫秒时间，不从其 UTC 日期取“今天”。
RecordingDateContext resolveDeviceRecordingDate({
  required CivilDate date,
  required InstantMilliseconds now,
}) {
  final localNow = DateTime.fromMillisecondsSinceEpoch(now);
  // UTC 仅用于比较不含时区的年月日，不作为投影边界。
  final selectedDate = DateTime.utc(date.year, date.month, date.day);
  final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
  final order = selectedDate.compareTo(today);
  return RecordingDateContext(
    date: date,
    relation: order < 0
        ? LedgerDateRelation.historical
        : order > 0
        ? LedgerDateRelation.future
        : LedgerDateRelation.today,
    now: now,
    dayStartedAt: DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch,
    // 日历进位由本地构造器处理，不能给当天时间点加固定 24 小时。
    nextDayStartedAt: DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).millisecondsSinceEpoch,
  );
}

/// Absolute fact boundaries interpreted in the current device timezone.
CivilDate deviceDateOfInstant(InstantMilliseconds instant) {
  final local = DateTime.fromMillisecondsSinceEpoch(instant);
  return CivilDate(year: local.year, month: local.month, day: local.day);
}
