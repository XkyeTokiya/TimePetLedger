/// 不含时刻或时区的公历日期（Q-008）。
///
/// 调用方按当前设备时区选择年月日后显式传入；本值不读取设备时区，
/// 也不转换为 UTC 零点。已保存的日期不会随设备时区变化而改写。
final class CivilDate {
  CivilDate({required this.year, required this.month, required this.day}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Must be between 1 and 12');
    }
    final leapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    final daysInMonth = switch (month) {
      2 => leapYear ? 29 : 28,
      4 || 6 || 9 || 11 => 30,
      _ => 31,
    };
    if (day < 1 || day > daysInMonth) {
      throw ArgumentError.value(day, 'day', 'Invalid day for year and month');
    }
  }

  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
