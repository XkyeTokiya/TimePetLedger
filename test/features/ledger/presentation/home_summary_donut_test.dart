import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_donut_chart.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_summary_tab.dart';

const minute = 60000;
final date = CivilDate(year: 2026, month: 10, day: 2);

String id(int number) =>
    '00000000-0000-4000-8000-${number.toString().padLeft(12, '0')}';

int at(int hour, [int min = 0]) =>
    DateTime(2026, 10, 2, hour, min).millisecondsSinceEpoch;

TimeBlock block(
  int number,
  int start,
  int end, {
  bool unknown = false,
  String? goalId,
  RhythmState? state,
}) => TimeBlock(
  id: id(number),
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? null : '活动',
  goalId: goalId,
  createdAt: 1,
  updatedAt: 1,
);

SleepSession sleep(int start, int end) => SleepSession(
  id: id(99),
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  type: SleepType.mainSleep,
  createdAt: 1,
  updatedAt: 1,
);

DayLedgerFacts facts({
  List<TimeBlock> blocks = const [],
  List<SleepSession> sleeps = const [],
  List<RhythmAnnotation> annotations = const [],
  List<Goal> goals = const [],
}) => DayLedgerFacts(
  ledger: SleepLedgerSnapshot(
    windowFacts: LedgerSnapshot(
      timeBlocks: blocks,
      sleepSessions: sleeps,
      annotations: annotations,
    ),
    sleepSummaryCandidates: sleeps,
  ),
  goals: goals,
);

Future<DayLedgerController> mount(
  WidgetTester tester,
  DayLedgerFacts data, {
  int now = 0,
}) async {
  final loader = DayLedgerLoader(
    resolveDate: resolveFixedDate,
    readFacts: (_) async => data,
  );
  final controller = DayLedgerController(
    loader: loader,
    now: () => now == 0 ? at(15) : now,
    dateOfInstant: (_) => date,
    selectedDate: date,
  );
  addTearDown(controller.dispose);
  await controller.refresh();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: HomeSummaryTab(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

RecordingDateContext resolveFixedDate({
  required CivilDate date,
  required int now,
}) => RecordingDateContext(
  date: date,
  relation: LedgerDateRelation.today,
  now: now,
  dayStartedAt: at(0),
  nextDayStartedAt: at(24),
);

void main() {
  testWidgets('day ring lists four parts and reveals percent on tap', (
    tester,
  ) async {
    // 睡眠 1h + 活动 1h + 想不起来 30m 已交代 = 2h30m；缺口 30m；总 3h.
    await mount(
      tester,
      facts(
        sleeps: [sleep(at(0), at(1))],
        blocks: [
          block(1, at(1), at(2)),
          block(2, at(2), at(2, 30), unknown: true),
        ],
      ),
      now: at(3),
    );
    expect(find.byType(HomeDonutChart), findsOneWidget);
    expect(find.text('一天时间构成'), findsOneWidget);
    expect(find.text('已交代'), findsOneWidget);
    expect(find.text('2 小时 30 分钟'), findsOneWidget);
    expect(find.text('睡眠'), findsOneWidget);
    expect(find.text('活动'), findsOneWidget);
    expect(find.text('想不起来'), findsOneWidget);
    expect(find.text('尚未记录'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('summary-part-sleep')));
    await tester.pumpAndSettle();
    // 睡眠 1h / 总 3h = 33%.
    expect(
      find.byKey(const ValueKey('summary-part-percent-sleep')),
      findsOneWidget,
    );
    expect(find.text('33%'), findsOneWidget);
    expect(find.textContaining('授权'), findsNothing);
  });

  testWidgets(
    'goal ring lists only goals with window contribution and a total',
    (tester) async {
      final goalA = Goal.create(id: id(1), name: '甲目标', now: 1);
      final goalB = Goal.create(id: id(2), name: '乙目标', now: 1);
      await mount(
        tester,
        facts(
          blocks: [
            block(10, at(1), at(3), goalId: goalA.id),
            block(11, at(3), at(4), goalId: goalB.id),
          ],
          goals: [
            goalA,
            goalB,
            Goal.create(id: id(3), name: '无记录', now: 1),
          ],
        ),
        now: at(4),
      );
      expect(find.text('目标时间构成'), findsOneWidget);
      expect(find.text('甲目标'), findsOneWidget);
      expect(find.text('乙目标'), findsOneWidget);
      expect(find.text('无记录'), findsNothing);
      expect(find.text('目标相关'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      await tester.tap(find.byKey(ValueKey('summary-part-${goalA.id}')));
      await tester.pumpAndSettle();
      expect(find.text('67%'), findsOneWidget); // 2h / 3h.
    },
  );

  testWidgets('empty goal list shows the existing missing-record message', (
    tester,
  ) async {
    await mount(tester, facts(blocks: [block(1, at(1), at(2))]), now: at(2));
    expect(find.text('这段时间还没有目标相关记录'), findsOneWidget);
  });

  testWidgets(
    'empty day window shows the fallback instead of a zero composition',
    (tester) async {
      await mount(tester, facts(), now: at(0));
      expect(find.text('一天时间构成'), findsOneWidget);
      expect(find.text('当前窗口暂无可显示的时间构成。'), findsOneWidget);
      expect(find.byKey(const ValueKey('summary-part-sleep')), findsNothing);
      expect(find.text('已交代'), findsNothing);
    },
  );
}
