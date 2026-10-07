import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';

SleepSession _sleep({
  String id = _id,
  int startedAt = 1001,
  int endedAt = 2002,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
  SleepType type = SleepType.mainSleep,
  String? note,
}) => SleepSession(
  id: id,
  startedAt: startedAt,
  endedAt: endedAt,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
  note: note,
  createdAt: 5005,
  updatedAt: 6006,
);

void main() {
  test('SL-001–003/Q-016：睡眠保留完整区间，类型和两端精度互相独立', () {
    final start = DateTime.utc(2026, 9, 21, 23, 50).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 22, 7, 40).millisecondsSinceEpoch;
    final sleep = _sleep(startedAt: start, endedAt: end);
    expect(sleep.id, _id);
    expect(sleep.startedAt, start);
    expect(sleep.endedAt, end);
    expect(sleep.createdAt, 5005);
    expect(sleep.updatedAt, 6006);
    expect(sleep.note, isNull);
    for (final type in SleepType.values) {
      for (final start in TimePrecision.values) {
        for (final end in TimePrecision.values) {
          for (final duration in [1, 3 * Duration.millisecondsPerDay]) {
            final sleep = _sleep(
              type: type,
              startPrecision: start,
              endPrecision: end,
              endedAt: 1001 + duration,
            );
            expect(sleep.type, type);
            expect(sleep.startPrecision, start);
            expect(sleep.endPrecision, end);
            expect(sleep.endedAt - sleep.startedAt, duration);
          }
        }
      }
    }
  });

  test('SL-005/Q-016：区间只拒绝零时长和反向，不偷加年代或长度限制', () {
    for (final type in SleepType.values) {
      for (final start in TimePrecision.values) {
        for (final end in TimePrecision.values) {
          for (final endedAt in [1001, 1000]) {
            expect(
              () => _sleep(
                type: type,
                startPrecision: start,
                endPrecision: end,
                endedAt: endedAt,
              ),
              throwsArgumentError,
            );
          }
        }
      }
    }
    for (final (start, end) in [
      (-2208988800000, -2208988799999),
      (4102444800000, 4102444800001),
      (-2208988800000, 4102444800000),
    ]) {
      final sleep = _sleep(startedAt: start, endedAt: end);
      expect(sleep.startedAt, start);
      expect(sleep.endedAt, end);
    }
  });

  test('MODEL-002/Q-015/Q-018：note 清理、码点上限与实体身份共同校验', () {
    for (final note in [null, '', '  ', '\t\n\r', '\u3000']) {
      expect(_sleep(note: note).note, isNull);
    }
    expect(_sleep(note: '\n 第一段  内容\n\n第二段\t内容 \t').note, '第一段  内容\n\n第二段\t内容');
    for (final character in ['记', '😀']) {
      final note = character * 2000;
      expect(_sleep(note: ' $note\n').note, note);
      expect(() => _sleep(note: '$note$character'), throwsArgumentError);
    }
    final note = 'e\u0301' * 1000;
    expect(_sleep(note: note).note, note);
    expect(() => _sleep(note: '${note}e'), throwsArgumentError);
    expect(() => _sleep(id: 'not-a-uuid'), throwsArgumentError);
  });
}
