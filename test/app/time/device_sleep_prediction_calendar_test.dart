import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_sleep_prediction_calendar.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_prediction.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';

void main() {
  const calendar = DeviceSleepPredictionCalendar();
  for (final day in [DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
    test(
      'cold sleep keeps wall-clock endpoints across ${day.month} transition',
      () {
        final now = DateTime(day.year, day.month, day.day, 6, 54);
        final expectedStart = DateTime(day.year, day.month, day.day - 1, 23);
        final expectedEnd = DateTime(day.year, day.month, day.day, 7);
        final p = predictSleep(
          date: CivilDate(year: day.year, month: day.month, day: day.day),
          now: now.millisecondsSinceEpoch,
          isToday: true,
          type: SleepType.mainSleep,
          calendar: calendar,
          history: [],
          feedback: [],
          facts: [],
        );
        expect(p.startedAt, expectedStart.millisecondsSinceEpoch);
        expect(p.endedAt, expectedEnd.millisecondsSinceEpoch);
        expect(
          p.endedAt - p.startedAt,
          expectedEnd.difference(expectedStart).inMilliseconds,
        );
      },
    );
  }
  test(
    'nap at a repeated local hour is based on the absolute current instant',
    () {
      final now = DateTime.utc(2026, 11, 1, 6, 10).millisecondsSinceEpoch;
      final local = DateTime.fromMillisecondsSinceEpoch(now);
      final p = predictSleep(
        date: CivilDate(year: local.year, month: local.month, day: local.day),
        now: now,
        isToday: true,
        type: SleepType.nap,
        calendar: calendar,
        history: [],
        feedback: [],
        facts: [],
      );
      expect(p.endedAt, now);
      expect(p.startedAt, now - 1800000);
    },
  );
}
