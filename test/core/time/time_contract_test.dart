import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';

void main() {
  test('Q-017：包含开始、不包含结束，相接区间不重复包含端点', () {
    for (final (instant, expected) in [
      (999, false),
      (1000, true),
      (1001, true),
      (1999, true),
      (2000, false),
    ]) {
      expect(
        containsInstant(startedAt: 1000, endedAt: 2000, instant: instant),
        expected,
      );
    }
    expect(
      containsInstant(startedAt: 2000, endedAt: 3000, instant: 2000),
      isTrue,
    );
  });

  test('零区间和反向区间明确拒绝', () {
    for (final end in [1000, 999]) {
      expect(
        () => intervalMilliseconds(startedAt: 1000, endedAt: end),
        throwsArgumentError,
      );
      expect(
        () => containsInstant(startedAt: 1000, endedAt: end, instant: 1000),
        throwsArgumentError,
      );
    }
  });

  test('毫秒分辨率保留，不量化为 UI 分钟或限制到 epoch 之后', () {
    expect(intervalMilliseconds(startedAt: -1, endedAt: 0), 1);
    expect(intervalMilliseconds(startedAt: 123, endedAt: 60124), 60001);
  });

  test('跨日事实按绝对时间计算，不拆分或固定为自然日时长', () {
    final start = DateTime.utc(2026, 9, 24, 23, 50).millisecondsSinceEpoch;
    final end = DateTime.utc(2026, 9, 25, 7, 40).millisecondsSinceEpoch;
    expect(intervalMilliseconds(startedAt: start, endedAt: end), 28200000);
  });

  test('最终展示才四舍五入，半分钟临界点不丢失', () {
    for (final (milliseconds, minutes) in [
      (0, 0),
      (29999, 0),
      (30000, 1),
      (30001, 1),
      (60000, 1),
      (89999, 1),
      (90000, 2),
    ]) {
      expect(roundedDisplayMinutes(milliseconds), minutes);
    }
    expect(() => roundedDisplayMinutes(-1), throwsArgumentError);
  });

  test('毫秒先求和再舍入，避免每条记录舍入造成累计误差', () {
    final first = intervalMilliseconds(startedAt: 0, endedAt: 20000);
    final second = intervalMilliseconds(startedAt: 20000, endedAt: 40000);
    expect(roundedDisplayMinutes(first + second), 1);
    expect(roundedDisplayMinutes(first) + roundedDisplayMinutes(second), 0);
  });
}
