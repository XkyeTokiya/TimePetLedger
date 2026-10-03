import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

const hour = Duration.millisecondsPerHour;
final date = CivilDate(year: 2026, month: 9, day: 30);
final start = DateTime(2026, 9, 30).millisecondsSinceEpoch;
final next = DateTime(2026, 10, 1).millisecondsSinceEpoch;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
TimeBlock block(
  int n,
  int from,
  int to, {
  bool unknown = false,
  String? title = '活动',
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => TimeBlock(
  id: id(n),
  startedAt: from,
  endedAt: to,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: title,
  createdAt: 1,
  updatedAt: 2,
);
SleepSession sleep(
  int n,
  int from,
  int to, {
  SleepType type = SleepType.mainSleep,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => SleepSession(
  id: id(n),
  startedAt: from,
  endedAt: to,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
  createdAt: 1,
  updatedAt: 2,
);
DayLedgerView project({
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
  LedgerDateRelation relation = LedgerDateRelation.today,
  int? now,
  int? dayStart,
  int? dayEnd,
  CivilDate? selectedDate,
}) => projectDayLedgerView(
  date: selectedDate ?? date,
  relation: relation,
  dayStartedAt: dayStart ?? start,
  nextDayStartedAt: dayEnd ?? next,
  now: now ?? start + 13 * hour,
  timeBlocks: blocks,
  windowSleepSessions: sleeps,
  annotations: [],
  sleepSummaryCandidates: sleeps,
  goals: [],
);
Future<void> show(WidgetTester tester, DayLedgerView view) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: DayLedgerTimeline(view: view)),
      ),
    ),
  );
  await tester.pump();
}

String subtitle(WidgetTester tester, Finder row) => tester
    .widget<Text>(find.descendant(of: row, matching: find.byType(Text)).last)
    .data!;
Finder fact(DayLedgerView view, int index) =>
    find.byKey(ValueKey(view.segments[index].reference));

void main() {
  testWidgets(
    'mixed timeline distinguishes knowledgeState, sleep types and all gaps, sorts without duplicates and retains namespaced references',
    (tester) async {
      final known = block(1, start + 8 * hour, start + 9 * hour, title: '想不起来');
      final unknown = block(
        2,
        start + 9 * hour,
        start + 10 * hour,
        unknown: true,
        title: '外出办事',
        endPrecision: TimePrecision.approximate,
      );
      final activity = block(
        3,
        start + 11 * hour + hour ~/ 2,
        start + 12 * hour,
      );
      // Same ID across the two formal fact types is legal; UI must keep both.
      final mainSleep = sleep(1, start + hour, start + 7 * hour);
      final nap = sleep(
        2,
        start + 11 * hour,
        start + 11 * hour + hour ~/ 2,
        type: SleepType.nap,
      );
      final view = project(
        blocks: [activity, unknown, known],
        sleeps: [nap, mainSleep],
      );
      await show(tester, view);
      expect(find.text('已知'), findsNWidgets(2));
      expect(find.text('想不起来'), findsOneWidget);
      expect(find.text('未知 · 想不起来'), findsOneWidget);
      expect(find.text('外出办事'), findsOneWidget);
      expect(find.text('主睡眠'), findsOneWidget);
      expect(find.text('小睡'), findsOneWidget);
      expect(find.text('尚未记录'), findsNWidgets(4));
      final rows = tester
          .widgetList<Widget>(
            find.byWidgetPredicate(
              (w) => w is LedgerFactTimelineTile || w is LedgerGapTimelineTile,
            ),
          )
          .toList();
      final starts = rows
          .map(
            (row) => switch (row) {
              LedgerFactTimelineTile(:final segment) => segment.startedAt,
              LedgerGapTimelineTile(:final gap) => gap.startedAt,
              _ => throw StateError('unexpected row'),
            },
          )
          .toList();
      expect(
        starts,
        [
          0,
          1,
          7,
          8,
          9,
          10,
          11,
          11.5,
          12,
        ].map((h) => start + (h * hour).toInt()).toList(),
      );
      final facts = rows
          .whereType<LedgerFactTimelineTile>()
          .map((row) => row.segment)
          .toList();
      expect(facts.map((s) => s.reference).toSet(), hasLength(5));
      expect(facts[0].reference, (
        type: LedgerFactType.sleepSession,
        id: known.id,
      ));
      expect(facts[1].reference, (
        type: LedgerFactType.timeBlock,
        id: known.id,
      ));
      expect((facts[1] as TimeBlockSegment).source, same(known));
      expect((facts[2] as TimeBlockSegment).source, same(unknown));
      expect(find.byType(ListTile), findsNWidgets(9));
      expect(
        subtitle(tester, find.byType(LedgerGapTimelineTile).at(2)),
        '约${formatRecordingTime(start + 10 * hour)} → ${formatRecordingTime(start + 11 * hour)}\n约60 分钟',
      );
      expect(unknown.endedAt, start + 10 * hour);
      expect(unknown.endPrecision, TimePrecision.approximate);
    },
  );

  testWidgets(
    'cross-day slices show only window contribution and ignore clipped approximation; adjacent facts introduce no gap',
    (tester) async {
      final main = sleep(
        1,
        start - hour,
        start + 7 * hour,
        startPrecision: TimePrecision.approximate,
      );
      final activity = block(
        1,
        start + 7 * hour,
        next + hour,
        endPrecision: TimePrecision.approximate,
      );
      final view = project(
        blocks: [activity],
        sleeps: [main],
        now: start + 12 * hour,
      );
      await show(tester, view);
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      expect(
        subtitle(tester, fact(view, 0)),
        '${formatRecordingTime(start)} → ${formatRecordingTime(start + 7 * hour)}\n420 分钟',
      );
      expect(
        subtitle(tester, fact(view, 1)),
        '${formatRecordingTime(start + 7 * hour)} → ${formatRecordingTime(start + 12 * hour)}\n300 分钟',
      );
      expect(find.textContaining('约'), findsNothing);
      expect(main.startedAt, start - hour);
      expect(main.startPrecision, TimePrecision.approximate);
      expect(activity.endedAt, next + hour);
      expect(
        (tester.widget<LedgerFactTimelineTile>(fact(view, 0)).segment
                as SleepSessionSegment)
            .source,
        same(main),
      );
      final historical = project(
        blocks: [activity],
        sleeps: [main],
        relation: LedgerDateRelation.historical,
        now: next + hour,
      );
      await show(tester, historical);
      expect(
        subtitle(tester, fact(historical, 1)),
        '${formatRecordingTime(start + 7 * hour)} → ${formatRecordingTime(next)}\n1020 分钟',
      );
      expect(historical.segments[1].endPrecision, TimePrecision.exact);
    },
  );

  testWidgets(
    'exactly equal approximate boundaries stay approximate and propagate only into adjacent gap',
    (tester) async {
      final activity = block(
        1,
        start,
        start + hour,
        startPrecision: TimePrecision.approximate,
      );
      final view = project(blocks: [activity], now: start + 2 * hour);
      await show(tester, view);
      expect(
        subtitle(tester, fact(view, 0)),
        '约${formatRecordingTime(start)} → ${formatRecordingTime(start + hour)}\n约60 分钟',
      );
      expect(
        subtitle(tester, find.byType(LedgerGapTimelineTile)),
        '${formatRecordingTime(start + hour)} → ${formatRecordingTime(start + 2 * hour)}\n60 分钟',
      );
      final equalEnd = project(
        blocks: [
          block(
            1,
            start,
            start + 2 * hour,
            endPrecision: TimePrecision.approximate,
          ),
        ],
        now: start + 2 * hour,
      );
      await show(tester, equalEnd);
      expect(
        subtitle(tester, fact(equalEnd, 0)),
        '${formatRecordingTime(start)} → 约${formatRecordingTime(start + 2 * hour)}\n约120 分钟',
      );
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
    },
  );

  testWidgets(
    'all-empty history and today each show full actual gap; future and midnight show none',
    (tester) async {
      for (final sample in [
        (LedgerDateRelation.historical, next + hour, 1440),
        (LedgerDateRelation.today, start + 13 * hour, 780),
        (LedgerDateRelation.future, start - hour, 0),
        (LedgerDateRelation.today, start, 0),
      ]) {
        final view = project(relation: sample.$1, now: sample.$2);
        await show(tester, view);
        expect(find.byType(LedgerFactTimelineTile), findsNothing);
        expect(
          find.text('尚未记录'),
          sample.$3 == 0 ? findsNothing : findsOneWidget,
        );
        expect(find.text('未知 · 想不起来'), findsNothing);
        expect(find.textContaining('补'), findsNothing);
        if (sample.$3 > 0) {
          expect(
            subtitle(tester, find.byType(LedgerGapTimelineTile)),
            endsWith('\n${sample.$3} 分钟'),
          );
        }
      }
    },
  );

  testWidgets(
    'sub-minute facts and gaps display positive existence and independent approximation',
    (tester) async {
      final view = project(
        blocks: [
          block(
            1,
            start,
            start + 10000,
            unknown: true,
            title: null,
            endPrecision: TimePrecision.approximate,
          ),
        ],
        now: start + 20000,
      );
      await show(tester, view);
      expect(find.text('未知 · 想不起来'), findsOneWidget);
      expect(subtitle(tester, fact(view, 0)), endsWith('\n约少于 1 分钟'));
      expect(
        subtitle(tester, find.byType(LedgerGapTimelineTile)),
        endsWith('\n约少于 1 分钟'),
      );
      expect(find.textContaining('0 分钟'), findsNothing);
      final exact = project(
        sleeps: [sleep(1, start, start + 10000, type: SleepType.nap)],
        now: start + 20000,
      );
      await show(tester, exact);
      expect(subtitle(tester, fact(exact, 0)), endsWith('\n少于 1 分钟'));
      expect(
        subtitle(tester, find.byType(LedgerGapTimelineTile)),
        endsWith('\n少于 1 分钟'),
      );
    },
  );

  testWidgets(
    'two dates keep one original cross-day source and distinct window slices',
    (tester) async {
      final source = sleep(1, next - 10 * 60000, next + 7 * hour + 40 * 60000);
      final previous = project(
        sleeps: [source],
        relation: LedgerDateRelation.historical,
        now: next + 8 * hour,
      );
      await show(tester, previous);
      expect(
        subtitle(tester, fact(previous, 0)),
        '${formatRecordingTime(next - 10 * 60000)} → ${formatRecordingTime(next)}\n10 分钟',
      );
      final following = project(
        sleeps: [source],
        selectedDate: CivilDate(year: 2026, month: 10, day: 1),
        dayStart: next,
        dayEnd: DateTime(2026, 10, 2).millisecondsSinceEpoch,
        now: next + 8 * hour,
      );
      await show(tester, following);
      expect(
        subtitle(tester, fact(following, 0)),
        '${formatRecordingTime(next)} → ${formatRecordingTime(source.endedAt)}\n460 分钟',
      );
      expect(
        previous.segments.single.reference,
        following.segments.single.reference,
      );
      expect(
        (following.segments.single as SleepSessionSegment).source,
        same(source),
      );
      expect(source.startedAt, next - 10 * 60000);
      expect(source.endedAt, next + 7 * hour + 40 * 60000);
    },
  );

  testWidgets(
    'real device 23/25-hour windows retain actual gap duration and next midnight label',
    (tester) async {
      for (final sample in [(3, 8, 23), (11, 1, 25)]) {
        final from = DateTime(
          2026,
          sample.$1,
          sample.$2,
        ).millisecondsSinceEpoch;
        final to = DateTime(
          2026,
          sample.$1,
          sample.$2 + 1,
        ).millisecondsSinceEpoch;
        final view = project(
          dayStart: from,
          dayEnd: to,
          selectedDate: CivilDate(year: 2026, month: sample.$1, day: sample.$2),
          relation: LedgerDateRelation.historical,
        );
        await show(tester, view);
        final hours = Platform.environment['TZ'] == 'America/New_York'
            ? sample.$3
            : 24;
        expect(
          subtitle(tester, find.byType(LedgerGapTimelineTile)),
          '${formatRecordingTime(from)} → ${formatRecordingTime(to)}\n${hours * 60} 分钟',
        );
      }
    },
    skip: ![
      'America/New_York',
      'Asia/Shanghai',
    ].contains(Platform.environment['TZ']),
  );
}
