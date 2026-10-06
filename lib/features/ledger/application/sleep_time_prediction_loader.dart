import 'dart:math' as math;

import '../../../core/time/civil_date.dart';
import '../domain/ledger_repository.dart';
import '../domain/projection/reconciliation_window.dart';
import '../domain/sleep_learning_store.dart';
import '../domain/sleep_prediction.dart';
import '../domain/sleep_type.dart';
import 'recording_ledger_loader.dart';

final class SleepTimePredictions {
  const SleepTimePredictions({required this.mainSleep, required this.nap});
  final SleepPredictionOrigin mainSleep;
  final SleepPredictionOrigin nap;
  SleepPredictionOrigin forType(SleepType type) =>
      type == SleepType.mainSleep ? mainSleep : nap;
}

final class SleepTimePredictionLoader {
  const SleepTimePredictionLoader({
    required this.repository,
    required this.resolveDate,
    required this.calendar,
  });
  final LedgerRepository repository;
  final RecordingDateResolver resolveDate;
  final SleepPredictionCalendar calendar;

  Future<SleepTimePredictions> load({
    required CivilDate date,
    required int now,
    SleepLearningStore? learning,
  }) async {
    final context = resolveDate(date: date, now: now);
    final history = await repository.readSleepHistory(now: now);
    final feedback = await learning?.readSleepFeedback() ?? [];
    // Query complete occupancy over every possible wake-day placement, including
    // long historical durations. Midnight is not a real sleep boundary.
    var start = context.dayStartedAt - 2 * 86400000;
    var end = context.nextDayStartedAt;
    for (final sleep in history) {
      final duration = sleep.endedAt - sleep.startedAt;
      for (final shift in [-1, 0]) {
        final candidate = calendar.startForWakeDate(
          date,
          calendar.phaseOf(sleep.startedAt),
          duration,
          shift,
        );
        start = math.min(start, candidate);
        end = math.max(end, candidate + duration);
      }
    }
    final facts = await repository.readRecordingContext(
      startedAt: start,
      endedAt: end,
    );
    SleepPredictionOrigin prediction(SleepType type) => predictSleep(
      date: date,
      now: now,
      isToday: context.relation == LedgerDateRelation.today,
      type: type,
      calendar: calendar,
      history: history,
      feedback: feedback,
      facts: facts,
    );
    return SleepTimePredictions(
      mainSleep: prediction(SleepType.mainSleep),
      nap: prediction(SleepType.nap),
    );
  }
}
