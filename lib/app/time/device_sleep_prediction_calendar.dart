import '../../core/time/civil_date.dart';
import '../../features/ledger/domain/sleep_prediction.dart';

final class DeviceSleepPredictionCalendar implements SleepPredictionCalendar {
  const DeviceSleepPredictionCalendar();
  @override
  int phaseOf(int instant) {
    final local = DateTime.fromMillisecondsSinceEpoch(instant);
    return ((local.hour * 60 + local.minute) * 60 + local.second) * 1000 +
        local.millisecond;
  }

  @override
  int offsetMinutes(int instant) =>
      DateTime.fromMillisecondsSinceEpoch(instant).timeZoneOffset.inMinutes;

  @override
  int instantOnDate(CivilDate date, int phase, int dayShift) => DateTime(
    date.year,
    date.month,
    date.day + dayShift,
    0,
    0,
    0,
    phase,
  ).millisecondsSinceEpoch;

  @override
  int startForWakeDate(CivilDate date, int phase, int duration, int dayShift) {
    final wakeDate = DateTime(date.year, date.month, date.day + dayShift);
    final precedingDays = (phase + duration) ~/ 86400000;
    var start = DateTime(
      wakeDate.year,
      wakeDate.month,
      wakeDate.day - precedingDays,
      0,
      0,
      0,
      phase,
    );
    // Duration is actual elapsed time; calendar progress preserves DST dates.
    for (var i = 0; i < 4; i++) {
      final end = DateTime.fromMillisecondsSinceEpoch(
        start.millisecondsSinceEpoch + duration,
      );
      final comparison = DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).compareTo(DateTime.utc(wakeDate.year, wakeDate.month, wakeDate.day));
      if (comparison == 0) return start.millisecondsSinceEpoch;
      start = DateTime(
        start.year,
        start.month,
        start.day + (comparison > 0 ? -1 : 1),
        0,
        0,
        0,
        phase,
      );
    }
    throw StateError('Cannot place sleep interval on selected wake date.');
  }
}
