import '../support/ledger_date_selection.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

const hour = Duration.millisecondsPerHour;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  testWidgets(
    'real facts render as one day timeline and re-slice across dates without writes or duplicates',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      addTearDown(() => tester.runAsync(db.close));
      final repository = DriftLedgerRepository(db);
      final start = DateTime(2026, 9, 30).millisecondsSinceEpoch;
      final next = DateTime(2026, 10, 1).millisecondsSinceEpoch;
      await tester.runAsync(() async {
        await repository.createSleepSession(
          id: id(1),
          startedAt: start - hour,
          endedAt: start + 7 * hour,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          note: '完整跨日睡眠',
          now: 1,
        );
        await repository.createTimeBlock(
          id: id(1),
          startedAt: start + 7 * hour,
          endedAt: start + 8 * hour,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.unknown,
          title: '有标题的未知',
          now: 1,
        );
        await repository.createTimeBlock(
          id: id(2),
          startedAt: start + 8 * hour,
          endedAt: start + 9 * hour,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '想不起来',
          now: 1,
        );
        await repository.createSleepSession(
          id: id(2),
          startedAt: start + 10 * hour,
          endedAt: start + 10 * hour + hour ~/ 2,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        );
        await repository.createTimeBlock(
          id: id(3),
          startedAt: start + 12 * hour,
          endedAt: next + hour,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.known,
          title: '跨日工作',
          note: '保留完整区间',
          now: 1,
        );
      });
      final blocksBefore = (await tester.runAsync(
        () => db.customSelect('SELECT * FROM time_blocks ORDER BY id').get(),
      ))!.map((row) => row.data).toList();
      final sleepsBefore = (await tester.runAsync(
        () => db.customSelect('SELECT * FROM sleep_sessions ORDER BY id').get(),
      ))!.map((row) => row.data).toList();
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: createDayLedgerLoader(db),
            now: () => start + 13 * hour,
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已知'), findsNothing);
      expect(find.text('已交代'), findsWidgets);
      expect(find.text('有标题的未知'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DayLedgerTimeline),
          matching: find.text('想不起来'),
        ),
        findsNWidgets(2),
      );
      expect(find.text('主睡眠'), findsOneWidget);
      expect(find.text('小睡'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DayLedgerTimeline),
          matching: find.text('尚未记录'),
        ),
        findsNWidgets(2),
      );
      expect(find.byType(LedgerFactTimelineTile), findsNWidgets(5));
      expect(
        find.byTooltip(
          '${formatRecordingTime(start + 12 * hour)} → ${formatRecordingTime(start + 13 * hour)}',
        ),
        findsOneWidget,
      );
      final workRow = find.byKey(
        ValueKey((type: LedgerFactType.timeBlock, id: id(3))),
      );
      expect(
        find.descendant(of: workRow, matching: find.text('1小时')),
        findsOneWidget,
      );
      expect(find.text('完整约8小时'), findsOneWidget);
      expect(
        find.text('入睡 约${formatRecordingTime(start - hour)}'),
        findsNothing,
      );
      expect(
        find.text('醒来 ${formatRecordingTime(start + 7 * hour)}'),
        findsNothing,
      );
      final initialSleep = tester
          .widgetList<LedgerFactTimelineTile>(
            find.byType(LedgerFactTimelineTile),
          )
          .first
          .segment;
      final initialWork = tester
          .widgetList<LedgerFactTimelineTile>(
            find.byType(LedgerFactTimelineTile),
          )
          .last
          .segment;
      await selectLedgerDate(tester, '2026-09-29');
      await tester.pumpAndSettle();
      expect(find.byType(LedgerFactTimelineTile), findsOneWidget);
      expect(find.text('主睡眠'), findsOneWidget);
      final previousSlice = tester
          .widget<LedgerFactTimelineTile>(find.byType(LedgerFactTimelineTile))
          .segment;
      expect(previousSlice.reference, initialSleep.reference);
      expect(
        (previousSlice as SleepSessionSegment).source.startedAt,
        start - hour,
      );
      expect(previousSlice.source.endedAt, start + 7 * hour);
      expect(previousSlice.endedAt, start);
      await selectLedgerDate(tester, '2026-10-01');
      await tester.pumpAndSettle();
      // Tomorrow W is empty even when a cross-day source already occupies it.
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      expect(find.textContaining('补记'), findsNothing);
      await selectLedgerDate(tester, '2026-09-30');
      await tester.pumpAndSettle();
      final currentWork = tester
          .widgetList<LedgerFactTimelineTile>(
            find.byType(LedgerFactTimelineTile),
          )
          .last
          .segment;
      expect(currentWork.reference, initialWork.reference);
      expect((currentWork as TimeBlockSegment).source.endedAt, next + hour);
      expect(currentWork.source.endPrecision, TimePrecision.approximate);
      expect(currentWork.endedAt, start + 13 * hour);
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks ORDER BY id').get(),
        ))!.map((row) => row.data).toList(),
        blocksBefore,
      );
      expect(
        (await tester.runAsync(
          () =>
              db.customSelect('SELECT * FROM sleep_sessions ORDER BY id').get(),
        ))!.map((row) => row.data).toList(),
        sleepsBefore,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
