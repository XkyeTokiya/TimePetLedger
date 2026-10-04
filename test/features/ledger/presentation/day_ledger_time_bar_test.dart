import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_overview.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_time_bar.dart';

import 'day_ledger_timeline_layout_test.dart' show sample, dayStart, dayEnd, id;

RecordingDateContext contextFor(CivilDate date, {int? now}) =>
    resolveDeviceRecordingDate(
      date: date,
      now:
          now ??
          DateTime(
            date.year,
            date.month,
            date.day + 1,
            12,
          ).millisecondsSinceEpoch,
    );

DayLedgerView emptyView(
  RecordingDateContext context, {
  List<TimeBlock> blocks = const [],
}) => projectDayLedgerView(
  date: context.window.date,
  relation: context.relation,
  dayStartedAt: context.dayStartedAt,
  nextDayStartedAt: context.nextDayStartedAt,
  now: context.now,
  timeBlocks: blocks,
  windowSleepSessions: [],
  annotations: [],
  sleepSummaryCandidates: [],
  goals: [],
);

Future<void> mount(
  WidgetTester tester,
  DayLedgerView view,
  RecordingDateContext context,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: timeLedgerTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DayLedgerOverview(view: view, dateContext: context),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'repeated midnight labels retain both offsets, including the day boundary',
    () {
      final context = RecordingDateContext(
        date: CivilDate(year: 2026, month: 11, day: 1),
        relation: LedgerDateRelation.historical,
        dayStartedAt: DateTime.utc(2026, 11, 1, 4).millisecondsSinceEpoch,
        nextDayStartedAt: DateTime.utc(2026, 11, 2, 5).millisecondsSinceEpoch,
        now: DateTime.utc(2026, 11, 2, 12).millisecondsSinceEpoch,
      );
      final midnight = dayLedgerTimeTicks(context)
          .where((tick) => tick.label.startsWith('00:00'))
          .toList();
      expect(midnight.map((tick) => tick.label), [
        '00:00 (UTC-04:00)',
        '00:00 (UTC-05:00)',
      ]);
      expect(midnight.first.instant, context.dayStartedAt);
      expect(midnight.last.instant - midnight.first.instant, 3600000);
    },
    skip: Platform.environment['TZ'] != 'America/Havana',
  );
  testWidgets(
    'selected figure uses all projected facts and gaps, Unknown is a subset',
    (tester) async {
      final view = sample();
      final context = contextFor(view.date);
      await mount(tester, view, context);
      expect(view.accountedDuration.roundedMinutes, 660);
      expect(view.unknownDuration.roundedMinutes, 30);
      expect(view.unresolvedDuration.roundedMinutes, 780);
      expect(find.text('约11 小时'), findsOneWidget);
      expect(find.text('约13 小时'), findsOneWidget);
      expect(find.textContaining('其中想不起来：约30 分钟'), findsOneWidget);
      final bar = tester.getRect(find.byKey(const ValueKey('day-time-bar')));
      expect(bar.height, 16);
      final parts = [
        ('bar-sleepSession:${id(1)}', 0, 440),
        ('bar-timeBlock:${id(1)}', 440, 480),
        ('bar-timeBlock:${id(2)}', 480, 600),
        ('bar-timeBlock:${id(3)}', 600, 630),
        ('bar-gap-${dayStart + 630 * 60000}', 630, 660),
        ('bar-timeBlock:${id(4)}', 660, 690),
        ('bar-gap-${dayStart + 690 * 60000}', 690, 1440),
      ];
      for (final (key, start, end) in parts) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(
          rect.left - bar.left,
          closeTo(bar.width * start * 60000 / (dayEnd - dayStart), .001),
        );
        expect(
          rect.width,
          closeTo(
            bar.width * (end - start) * 60000 / (dayEnd - dayStart),
            .001,
          ),
        );
      }
      expect(find.byKey(const ValueKey('bar-not-yet')), findsNothing);
    },
  );

  testWidgets(
    'one millisecond remains fractional; empty today/future is neutral and not Gap',
    (tester) async {
      final date = CivilDate(year: 2026, month: 10, day: 3);
      final start = DateTime(2026, 10, 3).millisecondsSinceEpoch;
      final context = contextFor(date, now: start + 60000);
      final block = TimeBlock(
        id: id(90),
        startedAt: start + 1,
        endedAt: start + 2,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
        title: '微小记录',
        createdAt: 0,
        updatedAt: 0,
      );
      final view = emptyView(context, blocks: [block]);
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester, view, context);
        final bar = tester.getRect(find.byKey(const ValueKey('day-time-bar')));
        final part = tester.getRect(
          find.byKey(ValueKey('bar-timeBlock:${block.id}')),
        );
        expect(part.width, greaterThan(0));
        expect(part.width, lessThan(1));
        expect(
          part.width,
          closeTo(bar.width / (context.nextDayStartedAt - start), 1e-9),
        );
        expect(
          find.bySemanticsLabel(RegExp('^全天时间分布.*约少于 1 分钟.*')),
          findsOneWidget,
        );
        final neutral = tester.getRect(
          find.byKey(const ValueKey('bar-not-yet')),
        );
        expect(
          neutral.left - bar.left,
          closeTo(bar.width * 60000 / (context.nextDayStartedAt - start), .001),
        );
        for (final now in [start, start - 1]) {
          final emptyContext = contextFor(date, now: now);
          final empty = emptyView(emptyContext);
          await mount(tester, empty, emptyContext);
          expect(empty.unresolvedSpans, isEmpty);
          expect(empty.accountedDuration.milliseconds, 0);
          expect(
            tester.getSize(find.byKey(const ValueKey('bar-not-yet'))).width,
            tester.getSize(find.byKey(const ValueKey('day-time-bar'))).width,
          );
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('DST uses 23/25 hour coordinates and repeated clock offsets', (
    tester,
  ) async {
    for (final (date, hours, sixPosition) in [
      (CivilDate(year: 2026, month: 3, day: 8), 23, 5),
      (CivilDate(year: 2026, month: 11, day: 1), 25, 7),
    ]) {
      final context = contextFor(date);
      final ticks = dayLedgerTimeTicks(context);
      expect(context.nextDayStartedAt - context.dayStartedAt, hours * 3600000);
      final six = ticks.singleWhere((tick) => tick.label == '06:00');
      expect(six.instant - context.dayStartedAt, sixPosition * 3600000);
      final repeated = ticks
          .where((tick) => tick.label.startsWith('01:00'))
          .toList();
      if (hours == 25) {
        expect(repeated.map((tick) => tick.label), [
          '01:00 (UTC-04:00)',
          '01:00 (UTC-05:00)',
        ]);
        expect(repeated.last.instant - repeated.first.instant, 3600000);
      } else {
        expect(ticks.where((tick) => tick.label.startsWith('02:00')), isEmpty);
      }
      final block = TimeBlock(
        id: id(80),
        startedAt: context.dayStartedAt,
        endedAt: six.instant,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '至六点',
        createdAt: 0,
        updatedAt: 0,
      );
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester, emptyView(context, blocks: [block]), context);
        final barWidth = tester
            .getSize(find.byKey(const ValueKey('day-time-bar')))
            .width;
        expect(
          tester
              .getSize(find.byKey(ValueKey('bar-timeBlock:${block.id}')))
              .width,
          closeTo(barWidth * sixPosition / hours, .001),
        );
        if (hours == 25) {
          expect(
            find.bySemanticsLabel(RegExp('.*UTC-04:00.*UTC-05:00.*')),
            findsOneWidget,
          );
        }
      } finally {
        semantics.dispose();
      }
    }
  }, skip: Platform.environment['TZ'] != 'America/New_York');
}
