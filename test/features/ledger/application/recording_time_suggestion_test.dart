import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

String id(int n) => '12345678-1234-4abc-8123-${n.toString().padLeft(12, '0')}';
TimeBlock block(int start, int end, {bool unknown = false}) => TimeBlock(
  id: id(start),
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '活动',
  createdAt: 1,
  updatedAt: 1,
);
SleepSession sleep(int start, int end) => SleepSession(
  id: id(start),
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  type: SleepType.mainSleep,
  createdAt: 1,
  updatedAt: 1,
);
LedgerCoverage coverage({
  LedgerDateRelation relation = LedgerDateRelation.today,
  int now = 90,
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
}) {
  final window = ReconciliationWindow.select(
    date: CivilDate(year: 2026, month: 9, day: 28),
    relation: relation,
    dayStartedAt: 0,
    nextDayStartedAt: 100,
    now: now,
  );
  return projectLedgerCoverage(
    window: window,
    segments: projectLedgerSegments(
      window: window,
      timeBlocks: blocks,
      sleepSessions: sleeps,
      annotations: [],
    ),
  );
}

void expectInput(RecordingTimeInput input, int? start, int? end) {
  expect((input.startedAt, input.endedAt), (start, end));
  expect(input.startPrecision, TimePrecision.approximate);
  expect(input.endPrecision, TimePrecision.approximate);
}

void main() {
  test(
    'empty today is manual; explicitly choosing the same whole gap prefills',
    () {
      final view = coverage();
      final ordinary = suggestRecordingTime(
        relation: LedgerDateRelation.today,
        coverage: view,
      );
      expectInput((ordinary as ManualTimeEntry).input, null, null);
      final explicit = suggestRecordingTime(
        relation: LedgerDateRelation.today,
        coverage: view,
        explicitGap: view.unresolvedSpans.single,
      );
      expectInput((explicit as DirectTimeSuggestion).input, 0, 90);
      expect(view.accountedDuration.milliseconds, 0);
    },
  );
  test('explicit gap takes priority over the ordinary tail suggestion', () {
    final view = coverage(blocks: [block(20, 40)]);
    final result = suggestRecordingTime(
      relation: LedgerDateRelation.today,
      coverage: view,
      explicitGap: view.unresolvedSpans.first,
    );
    expectInput((result as DirectTimeSuggestion).input, 0, 20);
  });
  test(
    'future, midnight and completely empty historical windows are manual',
    () {
      for (final sample in [
        (LedgerDateRelation.future, 90),
        (LedgerDateRelation.today, 0),
        (LedgerDateRelation.historical, 110),
      ]) {
        final view = coverage(relation: sample.$1, now: sample.$2);
        expectInput(
          (suggestRecordingTime(
            relation: sample.$1,
            coverage: view,
          ) as ManualTimeEntry).input,
          null,
          null,
        );
      }
    },
  );
  test('no gap is manual, including facts that cross now', () {
    final view = coverage(blocks: [block(0, 100)]);
    expect(view.unresolvedSpans, isEmpty);
    expect(
      suggestRecordingTime(relation: LedgerDateRelation.today, coverage: view),
      isA<ManualTimeEntry>(),
    );
  });
  test(
    'today with mixed sleep and unknown suggests only tail ending at now',
    () {
      final view = coverage(
        now: 91,
        sleeps: [sleep(0, 20)],
        blocks: [block(30, 50, unknown: true)],
      );
      final result = suggestRecordingTime(
        relation: LedgerDateRelation.today,
        coverage: view,
      );
      expectInput((result as DirectTimeSuggestion).input, 50, 91);
      expect(view.unknownDuration.milliseconds, 20);
      expect(view.unresolvedSpans, hasLength(2));
    },
  );
  test('sleep alone and unknown alone count as facts, not empty ledger', () {
    for (final view in [
      coverage(sleeps: [sleep(0, 20)]),
      coverage(blocks: [block(0, 20, unknown: true)]),
    ]) {
      expectInput(
        (suggestRecordingTime(
          relation: LedgerDateRelation.today,
          coverage: view,
        ) as DirectTimeSuggestion).input,
        20,
        90,
      );
    }
  });
  test('today without tail offers one gap for confirmation', () {
    final view = coverage(blocks: [block(0, 20), block(30, 100)]);
    final result = suggestRecordingTime(
      relation: LedgerDateRelation.today,
      coverage: view,
    ) as TimeCandidates;
    expectInput(result.candidates.single, 20, 30);
  });
  test('today without tail offers all gaps in order', () {
    final view = coverage(blocks: [block(20, 30), block(40, 90)]);
    final result = suggestRecordingTime(
      relation: LedgerDateRelation.today,
      coverage: view,
    ) as TimeCandidates;
    expectInput(result.candidates[0], 0, 20);
    expectInput(result.candidates[1], 30, 40);
    expect(() => result.candidates.clear(), throwsUnsupportedError);
  });
  test(
    'historical single tail or multiple gaps never automatically select',
    () {
      for (final blocks in [
        [block(0, 20)],
        [block(20, 30)],
      ]) {
        final view = coverage(
          relation: LedgerDateRelation.historical,
          now: 110,
          blocks: blocks,
        );
        final result = suggestRecordingTime(
          relation: LedgerDateRelation.historical,
          coverage: view,
        ) as TimeCandidates;
        expect(result.candidates, hasLength(view.unresolvedSpans.length));
        for (var i = 0; i < result.candidates.length; i++) {
          expectInput(
            result.candidates[i],
            view.unresolvedSpans[i].startedAt,
            view.unresolvedSpans[i].endedAt,
          );
        }
      }
    },
  );
  test(
    'future-only facts do not turn an empty current window into a suggestion',
    () {
      final view = coverage(blocks: [block(95, 100)]);
      expect(
        suggestRecordingTime(
          relation: LedgerDateRelation.today,
          coverage: view,
        ),
        isA<ManualTimeEntry>(),
      );
    },
  );
  test(
    'editing and clearing times preserve independently selected precision',
    () {
      final manual = const ManualTimeEntry().input;
      final filled = manual.withTimes(startedAt: 10, endedAt: 20);
      expectInput(filled, 10, 20);
      final chosen = filled.withPrecisions(startPrecision: TimePrecision.exact);
      final edited = chosen.withTimes(startedAt: 12, endedAt: null);
      expect(edited.startPrecision, TimePrecision.exact);
      expect(edited.endPrecision, TimePrecision.approximate);
      expect((edited.startedAt, edited.endedAt), (12, null));
      final endChosen = edited.withPrecisions(
        endPrecision: TimePrecision.exact,
      );
      expect(endChosen.startPrecision, TimePrecision.exact);
      expect(endChosen.endPrecision, TimePrecision.exact);
      expectInput(manual, null, null);
      expectInput(filled, 10, 20);
    },
  );
  test(
    'prefilled times remain editable without adopting exact gap precision',
    () {
      final view = coverage(blocks: [block(0, 20)]);
      final input = (suggestRecordingTime(
        relation: LedgerDateRelation.today,
        coverage: view,
      ) as DirectTimeSuggestion).input;
      expect(view.unresolvedSpans.single.startPrecision, TimePrecision.exact);
      expectInput(input.withTimes(startedAt: 25, endedAt: 80), 25, 80);
      expectInput(input, 20, 90);
    },
  );
}
