/// Local device time for the sleep input only; no clock or inferred interval.
String formatSleepTime(int? value) {
  if (value == null) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(value);
  String two(int n) => n.toString().padLeft(2, '0');
  final year =
      '${d.year < 0 ? '-' : ''}${d.year.abs().toString().padLeft(4, '0')}';
  return '$year-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

/// Minute input; reject invalid calendar rollover and nonexistent local times.
/// No history/future business bounds or duration threshold.
int? parseSleepTime(String input) {
  final match = RegExp(r'^(-?\d{4,6})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$')
      .firstMatch(input.trim());
  if (match == null) return null;
  final p = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
  try {
    final d = DateTime(p[0], p[1], p[2], p[3], p[4]);
    if (d.year != p[0] ||
        d.month != p[1] ||
        d.day != p[2] ||
        d.hour != p[3] ||
        d.minute != p[4]) {
      return null;
    }
    return d.millisecondsSinceEpoch;
  } on ArgumentError {
    return null;
  }
}
