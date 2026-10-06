import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_prediction.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final date = CivilDate(year: 2026, month: 10, day: 7);

class UtcCalendar implements SleepPredictionCalendar {
  const UtcCalendar();
  @override
  int phaseOf(int instant) => instant % 86400000;
  @override
  int offsetMinutes(int instant) => 0;
  @override
  int instantOnDate(CivilDate date, int phase, int dayShift) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day + dayShift,
      ).millisecondsSinceEpoch +
      phase;
  @override
  int startForWakeDate(CivilDate date, int phase, int duration, int shift) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day + shift - (phase + duration) ~/ 86400000,
      ).millisecondsSinceEpoch +
      phase;
}

SleepSession sample(
  int n,
  int day,
  int hour, {
  int duration = 8 * 3600000,
  int minute = 0,
  SleepType type = SleepType.mainSleep,
}) => SleepSession(
  id: id(n),
  startedAt: at(day, hour, minute),
  endedAt: at(day, hour, minute) + duration,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.approximate,
  type: type,
  createdAt: at(6, 23),
  updatedAt: at(6, 23),
);
LedgerFactInterval occupied(int start, int end) =>
    LedgerFactInterval.fromTimeBlock(
      TimeBlock(
        id: id(900),
        startedAt: start,
        endedAt: end,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.unknown,
        createdAt: 1,
        updatedAt: 1,
      ),
    );
SleepPredictionFeedback unchanged(SleepSession s) => SleepPredictionFeedback(
  sleepId: s.id,
  origin: SleepPredictionOrigin(
    startedAt: s.startedAt,
    endedAt: s.endedAt,
    type: s.type,
  ),
  startedAt: s.startedAt,
  endedAt: s.endedAt,
  startOffsetMinutes: 0,
  endOffsetMinutes: 0,
);
SleepPredictionOrigin prediction({
  List<SleepSession> history = const [],
  List<SleepPredictionFeedback> feedback = const [],
  List<LedgerFactInterval> facts = const [],
  int? now,
  SleepType type = SleepType.mainSleep,
  CivilDate? focus,
  bool isToday = true,
}) => predictSleep(
  date: focus ?? date,
  now: now ?? at(7, 6, 54),
  isToday: isToday,
  type: type,
  calendar: const UtcCalendar(),
  history: history,
  feedback: feedback,
  facts: facts,
);
void main() {
  test(
    'cold start estimates one night and leaves a multi-day gap unclaimed',
    () {
      final p = prediction(facts: [occupied(at(4, 21), at(4, 22, 13))]);
      expect((p.startedAt, p.endedAt), (at(6, 23), at(7, 7)));
    },
  );
  test(
    'nap cold start is the last thirty minutes, independent of main sleep',
    () {
      final p = prediction(type: SleepType.nap, now: at(7, 0, 10));
      expect((p.startedAt, p.endedAt), (at(6, 23, 40), at(7, 0, 10)));
    },
  );
  test(
    'learned daytime sleep selects the latest completed personal interval',
    () {
      final history = [for (var i = 0; i < 8; i++) sample(i + 1, i - 2, 10)];
      final morning = prediction(history: history);
      expect((morning.startedAt, morning.endedAt), (at(6, 10), at(6, 18)));
      final evening = prediction(history: history, now: at(7, 19));
      expect((evening.startedAt, evening.endedAt), (at(7, 10), at(7, 18)));
    },
  );
  test(
    'months without observations do not erase the last personal pattern',
    () {
      final history = [for (var i = 0; i < 8; i++) sample(i + 1, -100 + i, 10)];
      final p = prediction(history: history, now: at(7, 19));
      expect((p.startedAt, p.endedAt), (at(7, 10), at(7, 18)));
    },
  );
  test(
    'midnight neighbors stay near midnight rather than average to midday',
    () {
      final history = [
        for (var i = 0; i < 8; i++)
          sample(i + 1, i - 3, i.isEven ? 23 : 0, minute: i.isEven ? 50 : 10),
      ];
      final p = prediction(history: history, now: at(7, 9));
      final phase = const UtcCalendar().phaseOf(p.startedAt);
      expect(phase < 3600000 || phase > 23 * 3600000, isTrue);
      expect(p.endedAt - p.startedAt, 8 * 3600000);
    },
  );
  test('night/day modes remain actual paired templates', () {
    final history = [
      for (var i = 0; i < 10; i++) sample(i + 1, -10 + i, i.isEven ? 23 : 10),
    ];
    for (final now in [at(7, 8), at(7, 19)]) {
      final p = prediction(history: history, now: now);
      expect(
        const UtcCalendar().phaseOf(p.startedAt),
        isIn([10 * 3600000, 23 * 3600000]),
      );
      expect(p.endedAt - p.startedAt, 8 * 3600000);
    }
  });
  test('one late night does not replace an established night mode', () {
    final history = [
      for (var i = 0; i < 10; i++) sample(i + 1, -6 + i, 23),
      sample(99, 6, 3),
    ];
    final p = prediction(history: history, now: at(7, 12));
    expect(const UtcCalendar().phaseOf(p.startedAt), 23 * 3600000);
  });
  test('main sleep ignores naps and future sleep observations', () {
    final history = [
      for (var i = 0; i < 8; i++)
        sample(i + 1, i - 2, 14, duration: 1800000, type: SleepType.nap),
      sample(90, 8, 10),
    ];
    final p = prediction(history: history);
    expect((p.startedAt, p.endedAt), (at(6, 23), at(7, 7)));
  });
  test('weak predictions alone cannot train their own habit or duration', () {
    final history = [
      for (var i = 0; i < 8; i++)
        sample(i + 1, i - 2, 10, duration: 4 * 3600000),
    ];
    final p = prediction(
      history: history,
      feedback: history.map(unchanged).toList(),
    );
    expect((p.startedAt, p.endedAt), (at(6, 23), at(7, 7)));
  });
  test(
    'one hundred weak nights neither evict nor overwhelm independent day sleep',
    () {
      final strong = [for (var i = 0; i < 5; i++) sample(i + 1, i - 5, 10)];
      final weak = [for (var i = 0; i < 100; i++) sample(i + 20, i, 23)];
      final local = DateTime.utc(2026, 10, 100);
      final p = prediction(
        history: [...strong, ...weak],
        feedback: weak.map(unchanged).toList(),
        now: at(100, 19),
        focus: CivilDate(year: local.year, month: local.month, day: local.day),
      );
      expect((p.startedAt, p.endedAt), (at(100, 10), at(100, 18)));
    },
  );
  test('a real correction changes evidence while deletion removes it', () {
    final history = [for (var i = 0; i < 6; i++) sample(i + 1, i - 2, 10)];
    final feedback = history
        .map(
          (s) => SleepPredictionFeedback(
            sleepId: s.id,
            origin: SleepPredictionOrigin(
              startedAt: at(-2, 23),
              endedAt: at(-1, 7),
              type: s.type,
            ),
            startedAt: at(-2, 23),
            endedAt: at(-1, 7),
            startOffsetMinutes: 0,
            endOffsetMinutes: 0,
          ),
        )
        .toList();
    expect(
      const UtcCalendar().phaseOf(
        prediction(
          history: history,
          feedback: feedback,
          now: at(7, 19),
        ).startedAt,
      ),
      10 * 3600000,
    );
    expect(prediction(feedback: feedback).startedAt, at(6, 23));
  });
  test('history can propose a long sleep without a duration cap', () {
    final history = [
      for (var i = 0; i < 4; i++)
        sample(i + 1, -20 + i * 4, 9, duration: 36 * 3600000),
    ];
    final p = prediction(history: history, now: at(7, 23));
    expect(p.endedAt - p.startedAt, 36 * 3600000);
  });
  test(
    'late activity moves an intact sleep rather than taking the whole gap',
    () {
      final p = prediction(facts: [occupied(at(6, 23), at(7, 3))]);
      expect((p.startedAt, p.endedAt), (at(7, 3), at(7, 11)));
    },
  );
  test(
    'occupied context preserves a complete estimate for manual correction',
    () {
      final p = prediction(facts: [occupied(at(4, 0), at(9, 0))]);
      expect((p.startedAt, p.endedAt), (at(6, 23), at(7, 7)));
      expect(p.endedAt - p.startedAt, 8 * 3600000);
    },
  );
  test(
    'historical and future focus each retain complete wake-date endpoints',
    () {
      for (final day in [3, 10]) {
        final p = prediction(
          focus: CivilDate(year: 2026, month: 10, day: day),
          isToday: false,
        );
        expect((p.startedAt, p.endedAt), (at(day - 1, 23), at(day, 7)));
      }
    },
  );
}
