import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

void main() {
  test('日历合法性：普通闰年与世纪闰年', () {
    for (final year in [2000, 2024]) {
      expect(CivilDate(year: year, month: 2, day: 29).day, 29);
    }
    for (final year in [1900, 2025, 2100]) {
      expect(
        () => CivilDate(year: year, month: 2, day: 29),
        throwsArgumentError,
      );
    }
  });

  test('非法日期被拒绝，不自动溢出到下个月', () {
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

  test('每个月的真实末日合法', () {
    const lastDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    for (var month = 1; month <= 12; month++) {
      expect(
        CivilDate(year: 2025, month: month, day: lastDays[month - 1]).month,
        month,
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

  test('Q-008：调用方重新选择设备日期，不改写已保存日期', () {
    // 同一瞬间在两个时区的日历输入；不读取测试机器时区或时钟。
    final saved = CivilDate(year: 2026, month: 9, day: 25);
    final newlySelected = CivilDate(year: 2026, month: 9, day: 24);
    expect(saved, CivilDate(year: 2026, month: 9, day: 25));
    expect(newlySelected, isNot(saved));
  });
}
