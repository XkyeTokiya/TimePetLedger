import '../../../core/time/civil_date.dart';

/// 录制与日期选择共用的时间文本格式（原 recording_form.dart 顶层函数）。
String formatRecordingTime(int? value) {
  if (value == null) return '未填写';
  final d = DateTime.fromMillisecondsSinceEpoch(value);
  String two(int n) => n.toString().padLeft(2, '0');
  final year =
      '${d.year < 0 ? '-' : ''}${d.year.abs().toString().padLeft(4, '0')}';
  return '$year-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

CivilDate? parseRecordingDate(String value) {
  final m = RegExp(r'^(-?\d{4,6})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (m == null) return null;
  try {
    return CivilDate(
      year: int.parse(m.group(1)!),
      month: int.parse(m.group(2)!),
      day: int.parse(m.group(3)!),
    );
  } on ArgumentError {
    return null;
  }
}
