import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';

const minute = 60000;
final date = CivilDate(year: 2026, month: 10, day: 2);
String id(int number) =>
    '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}';
TimeBlock block(
  int number,
  int start,
  int end, {
  bool unknown = false,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
}) => TimeBlock(
  id: id(number),
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
SleepSession sleep(
  int start,
  int end, {
  TimePrecision startPrecision = TimePrecision.exact,
}) => SleepSession(
  id: id(99),
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: TimePrecision.exact,
  type: SleepType.mainSleep,
  createdAt: 1,
  updatedAt: 1,
);

Future<void> verify(
  WidgetTester tester, {
  required int end,
  required int accounted,
  required int unknown,
  required int gap,
  required List<String> labels,
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
  LedgerDateRelation relation = LedgerDateRelation.historical,
  int? now,
}) async {
  final instant = now ?? end;
  final loader = DayLedgerLoader(
    resolveDate: ({required date, required now}) => RecordingDateContext(
      date: date,
      relation: relation,
      now: now,
      dayStartedAt: 0,
      nextDayStartedAt: end,
    ),
    readFacts: (_) async => DayLedgerFacts(
      ledger: SleepLedgerSnapshot(
        windowFacts: LedgerSnapshot(
          timeBlocks: blocks,
          sleepSessions: sleeps,
          annotations: [],
        ),
        sleepSummaryCandidates: sleeps,
      ),
      goals: [],
    ),
  );
  // 检查同一现有投影的实际毫秒关系，显示舍入后不要求分区相等。
  final view = await loader.load(date: date, now: instant);
  expect(view.accountedDuration.milliseconds, accounted);
  expect(view.unknownDuration.milliseconds, unknown);
  expect(view.unresolvedDuration.milliseconds, gap);
  expect(accounted + gap, view.window.milliseconds);
  expect(unknown, inInclusiveRange(0, accounted));
  final observer = RouteObserver<ModalRoute<void>>();
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      navigatorObservers: [observer],
      home: DaySummaryPage(
        loader: loader,
        now: () => instant,
        dateOfInstant: (_) => date,
        routeObserver: observer,
        initialDate: date,
      ),
    ),
  );
  await tester.pumpAndSettle();
  for (final label in labels) {
    expect(find.text(label), findsOneWidget);
  }
  expect(find.text('未知已包含在已交代时间中。'), findsOneWidget);
  expect(find.textContaining('%'), findsNothing);
  expect(find.text('补一笔'), findsNothing);
}

void main() {
  testWidgets(
    'empty and 23/25 hour days use actual window, today stops at now, future has no gaps',
    (tester) async {
      for (final hours in [23, 25]) {
        await verify(
          tester,
          end: hours * 60 * minute,
          accounted: 0,
          unknown: 0,
          gap: hours * 60 * minute,
          labels: ['已交代：0 分钟', '其中未知：0 分钟', '尚未记录：$hours 小时'],
        );
      }
      await verify(
        tester,
        end: 24 * 60 * minute,
        now: 15 * 60 * minute,
        relation: LedgerDateRelation.today,
        accounted: 0,
        unknown: 0,
        gap: 15 * 60 * minute,
        labels: ['尚未记录：15 小时'],
      );
      for (final relation in [
        LedgerDateRelation.future,
        LedgerDateRelation.today,
      ]) {
        await verify(
          tester,
          end: 24 * 60 * minute,
          now: 0,
          relation: relation,
          accounted: 0,
          unknown: 0,
          gap: 0,
          blocks: [
            block(
              1,
              0,
              minute,
              unknown: true,
              startPrecision: TimePrecision.approximate,
            ),
          ],
          labels: ['已交代：0 分钟', '其中未知：0 分钟', '尚未记录：0 分钟', '当前账本窗口为空，不产生未记录缺口。'],
        );
        expect(find.text('此账本窗口没有未记录缺口。'), findsNothing);
      }
    },
  );

  testWidgets(
    'hand-calculated mixed sleep known Unknown and Gap preserve subset',
    (tester) async {
      await verify(
        tester,
        end: 240 * minute,
        accounted: 210 * minute,
        unknown: 30 * minute,
        gap: 30 * minute,
        sleeps: [sleep(0, 60 * minute)],
        blocks: [
          block(1, 60 * minute, 120 * minute),
          block(2, 120 * minute, 150 * minute, unknown: true),
          block(3, 180 * minute, 240 * minute),
        ],
        labels: ['已交代：3 小时 30 分钟', '其中未知：30 分钟', '尚未记录：30 分钟'],
      );
    },
  );

  testWidgets('full coverage with approximate interior keeps zero Gap exact', (
    tester,
  ) async {
    await verify(
      tester,
      end: 100 * minute,
      accounted: 100 * minute,
      unknown: 50 * minute,
      gap: 0,
      sleeps: [sleep(0, 50 * minute)],
      blocks: [
        block(
          1,
          50 * minute,
          100 * minute,
          unknown: true,
          startPrecision: TimePrecision.approximate,
        ),
      ],
      labels: ['已交代：约1 小时 40 分钟', '其中未知：约50 分钟', '尚未记录：0 分钟', '此账本窗口没有未记录缺口。'],
    );
  });

  testWidgets(
    'approximation is independent for accounted Unknown and remaining Gap',
    (tester) async {
      await verify(
        tester,
        end: 100 * minute,
        accounted: 50 * minute,
        unknown: 20 * minute,
        gap: 50 * minute,
        blocks: [
          block(1, 0, 30 * minute, startPrecision: TimePrecision.approximate),
          block(2, 30 * minute, 50 * minute, unknown: true),
        ],
        labels: ['已交代：约50 分钟', '其中未知：20 分钟', '尚未记录：50 分钟'],
      );
      await verify(
        tester,
        end: 100 * minute,
        accounted: 40 * minute,
        unknown: 20 * minute,
        gap: 60 * minute,
        blocks: [
          block(
            1,
            20 * minute,
            40 * minute,
            startPrecision: TimePrecision.approximate,
          ),
          block(2, 60 * minute, 80 * minute, unknown: true),
        ],
        labels: ['已交代：约40 分钟', '其中未知：20 分钟', '尚未记录：约1 小时'],
      );
    },
  );

  testWidgets(
    'clipping drops approximate source edges and future facts beyond now',
    (tester) async {
      await verify(
        tester,
        end: 100 * minute,
        now: 70 * minute,
        relation: LedgerDateRelation.today,
        accounted: 30 * minute,
        unknown: 0,
        gap: 40 * minute,
        sleeps: [
          sleep(
            -10 * minute,
            30 * minute,
            startPrecision: TimePrecision.approximate,
          ),
        ],
        blocks: [
          block(
            1,
            80 * minute,
            100 * minute,
            unknown: true,
            startPrecision: TimePrecision.approximate,
          ),
        ],
        labels: ['已交代：30 分钟', '其中未知：0 分钟', '尚未记录：40 分钟'],
      );
    },
  );

  testWidgets(
    'positive subminute values and final-sum rounding do not become missing or force display equality',
    (tester) async {
      await verify(
        tester,
        end: 40000,
        accounted: 20000,
        unknown: 20000,
        gap: 20000,
        blocks: [block(1, 0, 20000, unknown: true)],
        labels: ['已交代：少于 1 分钟', '其中未知：少于 1 分钟', '尚未记录：少于 1 分钟'],
      );
      await verify(
        tester,
        end: 40000,
        accounted: 20000,
        unknown: 20000,
        gap: 20000,
        blocks: [
          block(
            1,
            0,
            20000,
            unknown: true,
            endPrecision: TimePrecision.approximate,
          ),
        ],
        labels: ['已交代：约少于 1 分钟', '其中未知：约少于 1 分钟', '尚未记录：约少于 1 分钟'],
      );
      await verify(
        tester,
        end: 70000,
        accounted: 40000,
        unknown: 20000,
        gap: 30000,
        blocks: [block(1, 0, 20000), block(2, 20000, 40000, unknown: true)],
        labels: ['账本窗口：1 分钟', '已交代：1 分钟', '其中未知：少于 1 分钟', '尚未记录：1 分钟'],
      );
    },
  );
}
