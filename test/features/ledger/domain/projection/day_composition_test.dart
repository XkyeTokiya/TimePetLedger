import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_composition.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const minute = 60000;

TimeBlock _block(
  int number,
  int start,
  int end, {
  bool unknown = false,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => TimeBlock(
  id: '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}',
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '活动',
  createdAt: 1,
  updatedAt: 1,
);

SleepSession _sleep(
  int start,
  int end, {
  TimePrecision startPrecision = TimePrecision.exact,
}) => SleepSession(
  id: '00000000-0000-4000-8000-000000009999',
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: TimePrecision.exact,
  type: SleepType.mainSleep,
  createdAt: 1,
  updatedAt: 1,
);

DayComposition _compose({
  int end = 100 * minute,
  LedgerDateRelation relation = LedgerDateRelation.historical,
  int? now,
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
}) {
  final window = ReconciliationWindow.select(
    date: CivilDate(year: 2026, month: 10, day: 2),
    relation: relation,
    dayStartedAt: 0,
    nextDayStartedAt: end,
    now: now ?? end,
  );
  final segments = projectLedgerSegments(
    window: window,
    timeBlocks: blocks,
    sleepSessions: sleeps,
    annotations: const [],
  );
  return projectDayComposition(
    coverage: projectLedgerCoverage(window: window, segments: segments),
    segments: segments,
  );
}

void main() {
  test('four mutually exclusive parts sum to the reconciliation window', () {
    final composition = _compose(
      end: 240 * minute,
      sleeps: [_sleep(0, 60 * minute)],
      blocks: [
        _block(1, 60 * minute, 120 * minute),
        _block(2, 120 * minute, 150 * minute, unknown: true),
        _block(3, 180 * minute, 240 * minute),
      ],
    );
    expect(composition.sleep.milliseconds, 60 * minute);
    expect(composition.knownActivity.milliseconds, 120 * minute);
    expect(composition.unknown.milliseconds, 30 * minute);
    expect(composition.gap.milliseconds, 30 * minute);
    final total =
        composition.sleep.milliseconds +
        composition.knownActivity.milliseconds +
        composition.unknown.milliseconds +
        composition.gap.milliseconds;
    expect(total, 240 * minute);
  });

  test('unknown is a subset of accounted, gap stays out of accounted', () {
    final composition = _compose(
      end: 100 * minute,
      blocks: [
        _block(1, 0, 40 * minute, unknown: true),
        _block(2, 40 * minute, 60 * minute),
      ],
    );
    final accounted =
        composition.sleep.milliseconds +
        composition.knownActivity.milliseconds +
        composition.unknown.milliseconds;
    expect(accounted, 60 * minute);
    expect(composition.gap.milliseconds, 40 * minute);
  });

  test('approximation is independent for known, unknown and derived gap', () {
    final composition = _compose(
      end: 100 * minute,
      blocks: [
        _block(
          1,
          20 * minute,
          40 * minute,
          startPrecision: TimePrecision.approximate,
        ),
        _block(2, 60 * minute, 80 * minute, unknown: true),
      ],
    );
    expect(composition.knownActivity.hasApproximation, isTrue);
    expect(composition.unknown.hasApproximation, isFalse);
    expect(composition.gap.hasApproximation, isTrue);
    expect(composition.sleep.hasApproximation, isFalse);
  });

  test('empty window yields all-zero parts without records', () {
    final composition = _compose(
      end: 24 * 60 * minute,
      now: 0,
      relation: LedgerDateRelation.today,
    );
    expect(composition.sleep.milliseconds, 0);
    expect(composition.knownActivity.milliseconds, 0);
    expect(composition.unknown.milliseconds, 0);
    expect(composition.gap.milliseconds, 0);
  });
}
