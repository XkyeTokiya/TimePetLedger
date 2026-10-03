import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';

void main() {
  final date = CivilDate(year: 2026, month: 9, day: 22);
  // UTC+08 的当地零点；UTC 日期与查询日期不同，不读取运行机器时区。
  final start = DateTime.utc(2026, 9, 21, 16).millisecondsSinceEpoch;
  final end = DateTime.utc(2026, 9, 22, 16).millisecondsSinceEpoch;

  ReconciliationWindow select(LedgerDateRelation relation, int now) =>
      ReconciliationWindow.select(
        date: date,
        relation: relation,
        dayStartedAt: start,
        nextDayStartedAt: end,
        now: now,
      );

  test('Q-009：历史日采用完整当地日，不以 now 作为终点', () {
    final result = select(LedgerDateRelation.historical, end + 123456);
    expect(result.date, date);
    expect(result.startedAt, start);
    expect(result.endedAt, end);
    expect(result.milliseconds, 86400000);
    expect(result.isEmpty, isFalse);
  });

  test('Q-009：今天截至显式 now，保留毫秒，不覆盖未来区域', () {
    final now = start + 54000000 + 123;
    final result = select(LedgerDateRelation.today, now);
    expect(result.startedAt, start);
    expect(result.endedAt, now);
    expect(result.milliseconds, 54000123);
    expect(result.isEmpty, isFalse);
    expect(select(LedgerDateRelation.today, now).endedAt, result.endedAt);
  });

  test('Q-009：今天零点与未来日均为空窗口', () {
    for (final result in [
      select(LedgerDateRelation.today, start),
      select(LedgerDateRelation.future, start - 1),
    ]) {
      expect(result.date, date);
      expect(result.startedAt, start);
      expect(result.endedAt, start);
      expect(result.milliseconds, 0);
      expect(result.isEmpty, isTrue);
    }
    expect(select(LedgerDateRelation.today, start + 1).milliseconds, 1);
  });

  test('Q-008：显式 23 / 25 小时日边界按真实差值计算', () {
    // 美国东部夏令时切换日的当地午夜对应 UTC 时间；不调用时区库。
    for (final (day, dayStart, dayEnd, expected) in [
      (
        CivilDate(year: 2026, month: 3, day: 8),
        DateTime.utc(2026, 3, 8, 5),
        DateTime.utc(2026, 3, 9, 4),
        82800000,
      ),
      (
        CivilDate(year: 2026, month: 11, day: 1),
        DateTime.utc(2026, 11, 1, 4),
        DateTime.utc(2026, 11, 2, 5),
        90000000,
      ),
    ]) {
      for (final relation in LedgerDateRelation.values) {
        final now = switch (relation) {
          LedgerDateRelation.historical => dayEnd.millisecondsSinceEpoch,
          LedgerDateRelation.today => dayEnd.millisecondsSinceEpoch - 1,
          LedgerDateRelation.future => dayStart.millisecondsSinceEpoch - 1,
        };
        final result = ReconciliationWindow.select(
          date: day,
          relation: relation,
          dayStartedAt: dayStart.millisecondsSinceEpoch,
          nextDayStartedAt: dayEnd.millisecondsSinceEpoch,
          now: now,
        );
        expect(result.milliseconds, switch (relation) {
          LedgerDateRelation.historical => expected,
          LedgerDateRelation.today => expected - 1,
          LedgerDateRelation.future => 0,
        });
      }
    }
  });

  test('拒绝非正日边界及不在所提供今天内的 now，不静默修正', () {
    for (final relation in LedgerDateRelation.values) {
      for (final invalidEnd in [start, start - 1]) {
        expect(
          () => ReconciliationWindow.select(
            date: date,
            relation: relation,
            dayStartedAt: start,
            nextDayStartedAt: invalidEnd,
            now: start,
          ),
          throwsArgumentError,
        );
      }
    }
    for (final now in [start - 1, end, end + 1]) {
      expect(() => select(LedgerDateRelation.today, now), throwsArgumentError);
    }
  });
}
