import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/sleep_summary.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _minute = Duration.millisecondsPerMinute;
const _hour = Duration.millisecondsPerHour;
final _day = DateTime.utc(2026, 9, 22).millisecondsSinceEpoch;
final _next = DateTime.utc(2026, 9, 23).millisecondsSinceEpoch;

SleepSession _sleep(
  int start,
  int end, {
  int id = 1,
  SleepType type = SleepType.mainSleep,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => SleepSession(
  id: '12345678-1234-4abc-8123-${id.toString().padLeft(12, '0')}',
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
  note: '完整事实',
  createdAt: 1,
  updatedAt: 2,
);

SleepSummary _summary(List<SleepSession> records) => projectSleepSummary(
  sleepSessions: records,
  dayStartedAt: _day,
  nextDayStartedAt: _next,
);

bool _recorded(List<SleepSession> records, int now) =>
    hasRecordedMainSleepToday(
      sleepSessions: records,
      dayStartedAt: _day,
      nextDayStartedAt: _next,
      now: now,
    );

List<LedgerSegment> _segments(List<SleepSession> records, int now) =>
    projectLedgerSegments(
      window: ReconciliationWindow.select(
        date: CivilDate(year: 2026, month: 9, day: 22),
        relation: LedgerDateRelation.today,
        dayStartedAt: _day,
        nextDayStartedAt: _next,
        now: now,
      ),
      timeBlocks: [],
      sleepSessions: records,
      annotations: [],
    );

void main() {
  test('Q-010：所有分段主睡眠和白天主睡眠纳入，不计清醒；小睡单列', () {
    final first = _sleep(_day - _hour, _day + 3 * _hour);
    final second = _sleep(_day + 4 * _hour, _day + 7 * _hour, id: 2);
    final daytime = _sleep(_day + 10 * _hour, _day + 12 * _hour, id: 3);
    final nap = _sleep(
      _day + 13 * _hour,
      _day + 13 * _hour + 20 * _minute,
      id: 4,
      type: SleepType.nap,
    );
    final nap2 = _sleep(
      _day + 15 * _hour,
      _day + 15 * _hour + 10 * _minute,
      id: 5,
      type: SleepType.nap,
      endPrecision: TimePrecision.approximate,
    );
    final input = [nap2, daytime, second, nap, first];
    final result = _summary(input);
    expect(result.mainSleep.records, [
      same(first),
      same(second),
      same(daytime),
    ]);
    expect(result.mainSleep.totalDuration.milliseconds, 9 * _hour);
    expect(result.mainSleep.totalDuration.hasRecords, isTrue);
    expect(result.mainSleep.totalDuration.hasApproximation, isFalse);
    expect(result.nap.records, [same(nap), same(nap2)]);
    expect(result.nap.totalDuration.milliseconds, 30 * _minute);
    expect(result.nap.totalDuration.hasApproximation, isTrue);
    expect(input, [
      same(nap2),
      same(daytime),
      same(second),
      same(nap),
      same(first),
    ]);
    expect(first.startedAt, _day - _hour);
    expect(first.note, '完整事实');
    expect(() => result.mainSleep.records.clear(), throwsUnsupportedError);
    expect(() => result.nap.records.clear(), throwsUnsupportedError);
  });

  test('Q-010：零点醒来纳入、次日零点排除，零点空 W 仍有完整摘要', () {
    final midnight = _sleep(_day - 2 * _hour, _day);
    final previous = _sleep(_day - 4 * _hour, _day - 3 * _hour, id: 2);
    final next = _sleep(_next - _hour, _next, id: 3);
    final records = [previous, midnight, next];
    expect(_summary(records).mainSleep.records, [same(midnight)]);
    expect(_summary(records).mainSleep.totalDuration.milliseconds, 2 * _hour);
    expect(_segments(records, _day), isEmpty);
    expect(_segments([midnight], _day + _hour), isEmpty);
    expect(_recorded(records, _day), isTrue);
  });

  test('SL-004：仅 nap、未来结束主睡眠、其他日主睡眠均未满足已记录', () {
    final nap = _sleep(_day, _day + _hour, type: SleepType.nap);
    final future = _sleep(_day + 2 * _hour, _day + 4 * _hour, id: 2);
    final previous = _sleep(_day - 2 * _hour, _day - _hour, id: 3);
    expect(_recorded([nap], _day + _hour), isFalse);
    expect(_recorded([future], _day + 3 * _hour), isFalse);
    expect(_recorded([previous], _day + _hour), isFalse);
    expect(_recorded([nap, future, previous], _day + 3 * _hour), isFalse);
    expect(_summary([future]).mainSleep.totalDuration.hasRecords, isTrue);
    expect(_recorded([future], future.endedAt - 1), isFalse);
    expect(_recorded([future], future.endedAt), isTrue);
    expect(_recorded([future], future.endedAt + 1), isTrue);
  });

  test('SL-004：任一已结束主睡眠即可，未来记录不遮蔽它', () {
    final completed = _sleep(_day, _day + _hour);
    final future = _sleep(_day + 2 * _hour, _day + 3 * _hour, id: 2);
    expect(_recorded([future, completed], _day + _hour), isTrue);
    expect(
      _summary([future, completed]).mainSleep.totalDuration.milliseconds,
      2 * _hour,
    );
  });

  test('Q-021：空输入或无匹配，主睡眠与小睡独立表达缺失', () {
    for (final records in <List<SleepSession>>[
      [],
      [
        _sleep(
          _day - 2 * _hour,
          _day - _hour,
          startPrecision: TimePrecision.approximate,
        ),
      ],
    ]) {
      final result = _summary(records);
      for (final part in [result.mainSleep, result.nap]) {
        expect(part.records, isEmpty);
        expect(part.totalDuration.hasRecords, isFalse);
        expect(part.totalDuration.milliseconds, 0);
        expect(part.totalDuration.hasApproximation, isFalse);
      }
      expect(_recorded(records, _day), isFalse);
    }
    final napOnly = _summary([_sleep(_day, _day + 1, type: SleepType.nap)]);
    expect(napOnly.mainSleep.totalDuration.hasRecords, isFalse);
    expect(napOnly.nap.totalDuration.hasRecords, isTrue);
    expect(napOnly.nap.totalDuration.duration.roundedMinutes, 0);
  });

  test('Q-010、Q-014：23:50–07:40 完整约 7h50 与日切片精确 7h40', () {
    final sleep = _sleep(
      _day - 10 * _minute,
      _day + 7 * _hour + 40 * _minute,
      startPrecision: TimePrecision.approximate,
    );
    final full = _summary([sleep]).mainSleep.totalDuration;
    final slice = _segments([sleep], sleep.endedAt).single;
    expect(full.milliseconds, 470 * _minute);
    expect(full.hasApproximation, isTrue);
    expect(slice.duration.milliseconds, 460 * _minute);
    expect(slice.duration.hasApproximation, isFalse);
    expect(sleep.startPrecision, TimePrecision.approximate);
  });

  test('Q-014：完整时长保留两端精度，跨 now 裁掉的结束近似只影响摘要', () {
    for (final start in TimePrecision.values) {
      for (final end in TimePrecision.values) {
        final sleep = _sleep(
          _day + _hour,
          _day + 3 * _hour,
          startPrecision: start,
          endPrecision: end,
        );
        final full = _summary([sleep]).mainSleep.totalDuration;
        expect(
          full.hasApproximation,
          start == TimePrecision.approximate ||
              end == TimePrecision.approximate,
        );
        expect(full.milliseconds, 2 * _hour);
        final slice = _segments([sleep], _day + 2 * _hour).single;
        expect(slice.duration.milliseconds, _hour);
        expect(
          slice.duration.hasApproximation,
          start == TimePrecision.approximate,
        );
      }
    }
  });

  test('Q-017、Q-021：按毫秒汇总再舍入，不因微小时长丢失记录', () {
    final records = [
      _sleep(_day, _day + 20000, startPrecision: TimePrecision.approximate),
      _sleep(_day + 30000, _day + 50000, id: 2),
    ];
    final tiny = _summary([records.first]).mainSleep.totalDuration;
    expect(tiny.hasRecords, isTrue);
    expect(tiny.duration.roundedMinutes, 0);
    expect(tiny.hasApproximation, isTrue);
    final total = _summary(records).mainSleep.totalDuration;
    expect(total.milliseconds, 40000);
    expect(total.duration.roundedMinutes, 1);
  });

  test('Q-008：显式 UTC 与 UTC+8 日边界改变醒来归属，不改事实', () {
    final sleep = _sleep(_day - 10 * _hour, _day - 7 * _hour);
    expect(_summary([sleep]).mainSleep.records, isEmpty);
    final shifted = projectSleepSummary(
      sleepSessions: [sleep],
      dayStartedAt: _day - 8 * _hour,
      nextDayStartedAt: _next - 8 * _hour,
    );
    expect(shifted.mainSleep.records.single, same(sleep));
    expect(shifted.mainSleep.totalDuration.milliseconds, 3 * _hour);
    expect(_recorded([sleep], _day), isFalse);
    expect(
      hasRecordedMainSleepToday(
        sleepSessions: [sleep],
        dayStartedAt: _day - 8 * _hour,
        nextDayStartedAt: _next - 8 * _hour,
        now: _day,
      ),
      isTrue,
    );
    expect(sleep.endedAt, _day - 7 * _hour);
  });

  test('Q-008：23/25 小时日边界及超长完整睡眠不套用固定日长', () {
    for (final hours in [23, 25]) {
      final next = _day + hours * _hour;
      final sleep = _sleep(_day - 50 * _hour, next - 1);
      final excluded = _sleep(next - 1, next, id: 2);
      final result = projectSleepSummary(
        sleepSessions: [excluded, sleep],
        dayStartedAt: _day,
        nextDayStartedAt: next,
      );
      expect(result.mainSleep.records, [same(sleep)]);
      expect(
        result.mainSleep.totalDuration.milliseconds,
        (50 + hours) * _hour - 1,
      );
    }
  });

  test('调用合同：拒绝非递增日边界和不在所提供今天的 now', () {
    for (final next in [_day, _day - 1]) {
      expect(
        () => projectSleepSummary(
          sleepSessions: [],
          dayStartedAt: _day,
          nextDayStartedAt: next,
        ),
        throwsArgumentError,
      );
      expect(
        () => hasRecordedMainSleepToday(
          sleepSessions: [],
          dayStartedAt: _day,
          nextDayStartedAt: next,
          now: _day,
        ),
        throwsArgumentError,
      );
    }
    for (final now in [_day - 1, _next, _next + 1]) {
      expect(() => _recorded([], now), throwsArgumentError);
    }
  });
}
