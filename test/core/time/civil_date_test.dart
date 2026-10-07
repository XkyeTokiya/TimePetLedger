import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

void main() {
  test('日历构造同时守住闰年和月日边界', () {
    for (final year in [2000, 2024]) {
      expect(CivilDate(year: year, month: 2, day: 29).day, 29);
    }
    for (final year in [1900, 2025, 2100]) {
      expect(
        () => CivilDate(year: year, month: 2, day: 29),
        throwsArgumentError,
      );
    }
    for (final (month, day) in [
      (0, 1),
      (13, 1),
      (1, 0),
      (1, 32),
      (2, 30),
      (4, 31),
      (6, 31),
      (9, 31),
      (11, 31),
    ]) {
      expect(
        () => CivilDate(year: 2024, month: month, day: day),
        throwsArgumentError,
      );
    }
  });

  test('自然日期按年月日相等，与时间点不同', () {
    final date = CivilDate(year: 2026, month: 9, day: 25);
    final sameDate = CivilDate(year: 2026, month: 9, day: 25);
    expect(date, sameDate);
    expect({date, sameDate}, hasLength(1));
    expect(date, isNot(CivilDate(year: 2026, month: 9, day: 24)));
    expect(date, isNot(DateTime.utc(2026, 9, 25).millisecondsSinceEpoch));
  });
}
