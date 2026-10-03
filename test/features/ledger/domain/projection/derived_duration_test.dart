import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/derived_duration.dart';

void main() {
  DerivedDuration duration(int milliseconds, {bool approximate = false}) =>
      DerivedDuration(
        milliseconds: milliseconds,
        hasApproximation: approximate,
      );

  test('Q-014 / Q-021：空参与集为零，不引入近似，也不声称存在记录', () {
    final total = DerivedDuration.sum([]);
    final summary = SummaryDuration.fromRecords([]);
    expect(total.milliseconds, 0);
    expect(total.hasApproximation, isFalse);
    expect(summary.milliseconds, 0);
    expect(summary.hasApproximation, isFalse);
    expect(summary.hasRecords, isFalse);
  });

  test('Q-014：零时长没有近似来源，也不成为摘要参与记录', () {
    final zero = duration(0, approximate: true);
    expect(zero.hasApproximation, isFalse);
    final summary = SummaryDuration.fromRecords([zero]);
    expect(summary.hasRecords, isFalse);
    expect(summary.milliseconds, 0);
    expect(summary.hasApproximation, isFalse);
    final total = DerivedDuration.sum([zero, duration(123)]);
    expect(total.milliseconds, 123);
    expect(total.hasApproximation, isFalse);
  });

  test('Q-014：各项独立汇总，仅传播自身正时长贡献的近似', () {
    final exact = duration(60001);
    final approximate = duration(29999, approximate: true);
    final mixed = SummaryDuration.fromRecords([exact, approximate]);
    final exactOnly = SummaryDuration.fromRecords([exact]);
    expect(mixed.milliseconds, 90000);
    expect(mixed.hasRecords, isTrue);
    expect(mixed.hasApproximation, isTrue);
    expect(exactOnly.milliseconds, 60001);
    expect(exactOnly.hasRecords, isTrue);
    expect(exactOnly.hasApproximation, isFalse);
    expect(exact.hasApproximation, isFalse);
  });

  test('Q-017：先汇总毫秒再最终舍入，不逐条舍入', () {
    final first = duration(20000);
    final second = duration(20000, approximate: true);
    final sum = DerivedDuration.sum([first, second]);
    expect(first.roundedMinutes + second.roundedMinutes, 0);
    expect(sum.milliseconds, 40000);
    expect(sum.roundedMinutes, 1);
    expect(sum.hasApproximation, isTrue);
    expect(duration(30000).roundedMinutes, 1);
  });

  test('Q-021：正时长舍入为零仍存在，实际毫秒和近似分别保留', () {
    for (final milliseconds in [1, 29999]) {
      for (final approximate in [false, true]) {
        final result = SummaryDuration.fromRecords([
          duration(milliseconds, approximate: approximate),
        ]);
        expect(result.hasRecords, isTrue);
        expect(result.milliseconds, milliseconds);
        expect(result.duration.roundedMinutes, 0);
        expect(result.hasApproximation, approximate);
      }
    }
  });

  test('摘要只迭代输入一次，支持调用方惰性提供贡献', () {
    var iterations = 0;
    Iterable<DerivedDuration> records() sync* {
      iterations++;
      yield duration(20000);
      yield duration(10000, approximate: true);
    }

    final result = SummaryDuration.fromRecords(records());
    expect(iterations, 1);
    expect(result.hasRecords, isTrue);
    expect(result.milliseconds, 30000);
    expect(result.hasApproximation, isTrue);
  });

  test('拒绝负派生时长', () {
    expect(() => duration(-1), throwsArgumentError);
  });
}
