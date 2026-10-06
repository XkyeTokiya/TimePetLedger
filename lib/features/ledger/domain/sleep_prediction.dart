import 'dart:math' as math;

import '../../../core/time/civil_date.dart';
import 'ledger_conflicts.dart';
import 'sleep_session.dart';
import 'sleep_type.dart';

const sleepPredictionVersion = 1;
const _day = 86400000;
const _phaseBandwidth = 90 * 60000;
const _durationBandwidth = 0.25;

/// Device calendar operations are injected; the model has no global clock or zone.
abstract interface class SleepPredictionCalendar {
  int phaseOf(int instant);
  int offsetMinutes(int instant);
  int instantOnDate(CivilDate date, int phase, int dayShift);
  int startForWakeDate(CivilDate date, int phase, int duration, int dayShift);
}

final class SleepPredictionOrigin {
  const SleepPredictionOrigin({
    required this.startedAt,
    required this.endedAt,
    required this.type,
    this.version = sleepPredictionVersion,
  });
  final int startedAt;
  final int endedAt;
  final SleepType type;
  final int version;
}

/// Auxiliary learning evidence, never a fact or a contribution to statistics.
final class SleepPredictionFeedback {
  const SleepPredictionFeedback({
    required this.sleepId,
    required this.origin,
    required this.startedAt,
    required this.endedAt,
    required this.startOffsetMinutes,
    required this.endOffsetMinutes,
  });
  final String sleepId;
  final SleepPredictionOrigin origin;
  final int startedAt;
  final int endedAt;
  final int startOffsetMinutes;
  final int endOffsetMinutes;
}

final class _Sample {
  _Sample(
    this.sleep,
    this.phase,
    this.endPhase,
    this.startWeight,
    this.endWeight,
  );
  final SleepSession sleep;
  final int phase;
  final int endPhase;
  double startWeight;
  double endWeight;
  int get duration => sleep.endedAt - sleep.startedAt;
  bool get independent => startWeight > 0.1 || endWeight > 0.1;
}

final class _Interval {
  const _Interval(this.start, this.end);
  final int start;
  final int end;
  int get duration => end - start;
}

double _circleDistance(int a, int b) {
  final distance = (a - b).abs() % _day;
  return math.min(distance, _day - distance).toDouble();
}

double _kernel(double distance) => math.exp(-0.5 * distance * distance);

/// Joint historical templates preserve distinct night/day modes and durations.
/// Unknown-source legacy samples weigh .5; unchanged model outputs weigh .1.
/// Each endpoint has its own evidence budget, so editing one does not validate both.
SleepPredictionOrigin predictSleep({
  required CivilDate date,
  required int now,
  required bool isToday,
  required SleepType type,
  required SleepPredictionCalendar calendar,
  required Iterable<SleepSession> history,
  required Iterable<SleepPredictionFeedback> feedback,
  required Iterable<LedgerFactInterval> facts,
}) {
  final evidence = {for (final item in feedback) item.sleepId: item};
  final all = <_Sample>[];
  for (final sleep in history) {
    if (sleep.type != type || sleep.endedAt > now) continue;
    final item = evidence[sleep.id];
    double weight(bool start) {
      if (item == null) return 0.5;
      final actual = start ? sleep.startedAt : sleep.endedAt;
      final submitted = start ? item.startedAt : item.endedAt;
      final initial = start ? item.origin.startedAt : item.origin.endedAt;
      return actual != submitted || submitted != initial ? 1 : 0.1;
    }

    int phase(bool start) {
      final instant = start ? sleep.startedAt : sleep.endedAt;
      final submitted = start ? item?.startedAt : item?.endedAt;
      if (item == null || instant != submitted) {
        return calendar.phaseOf(instant);
      }
      final offset = start ? item.startOffsetMinutes : item.endOffsetMinutes;
      return (instant + offset * 60000) % _day;
    }

    all.add(
      _Sample(sleep, phase(true), phase(false), weight(true), weight(false)),
    );
  }
  all.sort((a, b) => b.sleep.endedAt.compareTo(a.sleep.endedAt));
  final independent = all.where((s) => s.independent).toList();
  // Repeated self-predictions must not evict the last independent observations.
  final anchor = independent.isNotEmpty
      ? independent.first.sleep.endedAt
      : all.isNotEmpty
      ? all.first.sleep.endedAt
      : now;
  final oldest = anchor - 56 * _day;
  final samples = independent
      .where((s) => s.sleep.endedAt >= oldest)
      .take(60)
      .toList();
  samples.addAll(
    all
        .where((s) => !s.independent && s.sleep.endedAt >= oldest)
        .take(60 - samples.length),
  );
  for (final sample in samples) {
    final age = math.max(0, anchor - sample.sleep.endedAt) / _day;
    final decay = math.pow(0.5, age / 14).toDouble();
    sample.startWeight *= decay;
    sample.endWeight *= decay;
  }
  double capWeak(bool start) {
    double independentTotal = 0, weakTotal = 0;
    for (final sample in samples) {
      final original = evidence[sample.sleep.id];
      final instant = start ? sample.sleep.startedAt : sample.sleep.endedAt;
      final submitted = start ? original?.startedAt : original?.endedAt;
      final initial = start
          ? original?.origin.startedAt
          : original?.origin.endedAt;
      final weak =
          original != null && instant == submitted && submitted == initial;
      final value = start ? sample.startWeight : sample.endWeight;
      if (weak) {
        weakTotal += value;
      } else {
        independentTotal += value;
      }
    }
    final scale = weakTotal == 0
        ? 1.0
        : math.min(1.0, independentTotal * 0.2 / weakTotal);
    for (final sample in samples) {
      final original = evidence[sample.sleep.id];
      if (original == null) continue;
      final instant = start ? sample.sleep.startedAt : sample.sleep.endedAt;
      final submitted = start ? original.startedAt : original.endedAt;
      final initial = start
          ? original.origin.startedAt
          : original.origin.endedAt;
      if (instant == submitted && submitted == initial) {
        if (start) {
          sample.startWeight *= scale;
        } else {
          sample.endWeight *= scale;
        }
      }
    }
    return independentTotal;
  }

  final independentAmount = math.min(capWeak(true), capWeak(false));
  final defaultDuration = type == SleepType.mainSleep
      ? 8 * 3600000
      : 30 * 60000;
  final defaultPhase = type == SleepType.mainSleep
      ? 23 * 3600000
      : (calendar.phaseOf(now) - defaultDuration) % _day;
  final priorWeight = 2 / (1 + independentAmount);
  double habit(_Interval interval) {
    final phase = calendar.phaseOf(interval.start);
    final endPhase = calendar.phaseOf(interval.end);
    double component(
      int start,
      int end,
      int duration,
      double sw,
      double ew,
      double width,
    ) {
      final s = _kernel(
        _circleDistance(phase, start) / (_phaseBandwidth * width),
      );
      final e = _kernel(
        _circleDistance(endPhase, end) / (_phaseBandwidth * width),
      );
      final d = _kernel(
        math.log(interval.duration / duration) / (_durationBandwidth * width),
      );
      return (sw * s + ew * e) / width +
          math.min(sw, ew) * s * d / (width * width);
    }

    // A broad cold-start component yields to coherent personal observations.
    double score = component(
      defaultPhase,
      (defaultPhase + defaultDuration) % _day,
      defaultDuration,
      priorWeight,
      priorWeight,
      3,
    );
    for (final sample in samples) {
      score += component(
        sample.phase,
        sample.endPhase,
        sample.duration,
        sample.startWeight,
        sample.endWeight,
        1,
      );
    }
    return score;
  }

  final bases = <_Interval>[];
  for (final shift in isToday ? [-1, 0] : [0]) {
    if (type == SleepType.mainSleep) {
      bases.add(
        _Interval(
          calendar.instantOnDate(date, 23 * 3600000, shift - 1),
          calendar.instantOnDate(date, 7 * 3600000, shift),
        ),
      );
    } else {
      final end = isToday && shift == 0
          ? now
          : calendar.instantOnDate(date, calendar.phaseOf(now), shift);
      bases.add(_Interval(end - defaultDuration, end));
    }
  }
  final templates = [
    for (final sample in samples)
      if (sample.startWeight + sample.endWeight > 0)
        (sample.phase, sample.duration),
  ];
  for (final (phase, duration) in templates) {
    for (final shift in isToday ? [-1, 0] : [0]) {
      final start = calendar.startForWakeDate(date, phase, duration, shift);
      bases.add(_Interval(start, start + duration));
    }
  }
  final occupied = facts.toList();
  bool overlaps(_Interval value) =>
      occupied.any((f) => f.startedAt < value.end && f.endedAt > value.start);
  // Keep the full learned duration. Do not manufacture a tiny sleep merely to
  // fit a small free fragment. A conflicting full estimate remains editable.
  final alternatives = <_Interval>[...bases];
  for (final base in bases) {
    for (final fact in occupied.where(
      (f) => f.startedAt < base.end && f.endedAt > base.start,
    )) {
      for (final candidate in [
        _Interval(fact.endedAt, fact.endedAt + base.duration),
        _Interval(fact.startedAt - base.duration, fact.startedAt),
      ]) {
        // Only move within the selected wake-day context (or today's previous one).
        final phase = calendar.phaseOf(candidate.start);
        if ((isToday ? [-1, 0] : [0]).any(
          (shift) =>
              calendar.startForWakeDate(
                date,
                phase,
                candidate.duration,
                shift,
              ) ==
              candidate.start,
        )) {
          alternatives.add(candidate);
        }
      }
    }
  }
  final recent = alternatives.where((i) => !isToday || i.start <= now).toList();
  final free = recent.where((i) => !overlaps(i)).toList();
  final pool = free.isNotEmpty
      ? free
      : recent.isNotEmpty
      ? recent
      : bases;
  double score(_Interval value) {
    final endFocus = isToday
        ? now
        : calendar.startForWakeDate(date, calendar.phaseOf(now), 1, 0) + 1;
    final distance = (value.end - endFocus).abs() / _day;
    return habit(value) / (1 + distance * distance);
  }

  pool.sort((a, b) {
    final order = score(b).compareTo(score(a));
    return order != 0 ? order : b.end.compareTo(a.end);
  });
  final chosen = pool.first;
  return SleepPredictionOrigin(
    startedAt: chosen.start,
    endedAt: chosen.end,
    type: type,
  );
}
