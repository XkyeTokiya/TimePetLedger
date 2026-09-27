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
  test('SL-001、SL-002：跨日保存完整独立事实及身份、元数据', () {
    final start = DateTime.utc(2026, 9, 21, 23, 50).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 22, 7, 40).millisecondsSinceEpoch;
    final sleep = _sleep(startedAt: start, endedAt: end);
    expect(sleep.id, _id);
    expect(sleep.startedAt, start);
    expect(sleep.endedAt, end);
    expect(sleep.createdAt, 5005);
    expect(sleep.updatedAt, 6006);
    expect(sleep.note, isNull);
  });

  test('SL-003：两种类型均支持独立起止精度，无类型时长阈值', () {
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

  test('SL-005、Q-016：所有类型和精度组合均拒绝零时长与反向区间', () {
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
  });

  test('Q-016：允许遥远历史、未来、毫秒正区间和长区间', () {
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

  test('MODEL-002：可选 note 的 null、空串与纯空白统一为空', () {
    for (final note in [null, '', '  ', '\t\n\r', '\u3000']) {
      expect(_sleep(note: note).note, isNull);
    }
  });

  test('MODEL-002：note 清理首尾，保留内部空格、换行和段落', () {
    expect(_sleep(note: '\n 第一段  内容\n\n第二段\t内容 \t').note, '第一段  内容\n\n第二段\t内容');
  });

  test('Q-015：清理后最多 2000 码点，支持补充平面字符并拒绝超限', () {
    for (final character in ['记', '😀']) {
      final note = character * 2000;
      expect(_sleep(note: ' $note\n').note, note);
      expect(() => _sleep(note: '$note$character'), throwsArgumentError);
    }
  });

  test('Q-015：组合字符按码点而非字素簇计数，不改写原文', () {
    final note = 'e\u0301' * 1000;
    expect(_sleep(note: note).note, note);
    expect(() => _sleep(note: '${note}e'), throwsArgumentError);
  });

  test('Q-018：拒绝非法身份', () {
    expect(() => _sleep(id: 'not-a-uuid'), throwsArgumentError);
  });
}
