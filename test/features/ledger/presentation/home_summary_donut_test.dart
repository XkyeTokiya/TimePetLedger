import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/derived_duration.dart';
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
const chartCaptureKey = ValueKey('summary-chart-capture');
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
      theme: homeTheme,
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

DonutPart part(
  String id,
  String label,
  int milliseconds,
  Color color, {
  bool dashed = false,
}) => DonutPart(
  id: id,
  label: label,
  color: color,
  duration: DerivedDuration(
    milliseconds: milliseconds,
    hasApproximation: false,
  ),
  dashed: dashed,
);

List<DonutPart> chartParts() => [
  part('sleep', '睡眠', 60 * minute, HomePalette.sleep),
  part('activity', '活动', 60 * minute, HomePalette.activity),
  part('unknown', '想不起来', 30 * minute, HomePalette.unknown),
  part('gap', '尚未记录', 30 * minute, HomePalette.gap, dashed: true),
];

Future<void> mountChart(
  WidgetTester tester,
  List<DonutPart> parts, {
  double width = 360,
  double scale = 1,
  String centerValue = '2 小时 30 分钟',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: homeTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: chartCaptureKey,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: HomeDonutChart(
              parts: parts,
              centerLabel: '已交代',
              centerValue: centerValue,
              semanticsLabel: '一天时间构成：睡眠、活动、想不起来、尚未记录',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> captureChart(WidgetTester tester, String name) async {
  final directory = Platform.environment['SUMMARY_CHART_CAPTURE_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(chartCaptureKey))
        .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(homeSerifFamily)
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf')))
        .load();
  });

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
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(4));
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

  testWidgets('dashed gap preserves its full angular share and tap identity', (
    tester,
  ) async {
    await mountChart(tester, chartParts());
    final data = tester.widget<PieChart>(find.byType(PieChart)).data;
    // 透明短段也属于30分钟Gap，合计不能只算实色部分。
    expect(data.sumValue, closeTo(180 * minute, 0.001));
    expect(data.sections[0].value, 60 * minute);
    expect(data.sections[1].value, 60 * minute);
    expect(data.sections[2].value, 30 * minute);
    expect(
      data.sections.skip(3).fold<double>(0, (sum, slice) => sum + slice.value),
      closeTo(30 * minute, 0.001),
    );
    expect(
      data.sections.skip(3).any((slice) => slice.color == Colors.transparent),
      isTrue,
    );
    final radius = data.centerSpaceRadius + data.sections.first.radius / 2;
    final center = tester.getCenter(find.byType(PieChart));
    // Gap在210°–270°，240°点击经过真实fl_chart命中逻辑。
    await tester.tapAt(center + Offset(-radius / 2, -radius * 0.8660254));
    await tester.pumpAndSettle();
    expect(find.text('17%'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('summary-part-gap')))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('summary-part-gap')));
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
    // 睡眠在270°–390°；圆环点击与图例共用选择。
    await tester.tapAt(center + Offset(radius * 0.8660254, -radius / 2));
    await tester.pumpAndSettle();
    expect(find.text('33%'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('summary-part-sleep')))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'zero activity has a legend but no slice, tiny facts keep weight',
    (tester) async {
      await mountChart(tester, [
        part('sleep', '睡眠', 7 * 60 * minute, HomePalette.sleep),
        part('activity', '活动', 0, HomePalette.activity),
        part('unknown', '想不起来', 76 * minute, HomePalette.unknown),
        part('gap', '尚未记录', 20000, HomePalette.gap, dashed: true),
      ], centerValue: '8 小时 16 分钟');
      final data = tester.widget<PieChart>(find.byType(PieChart)).data;
      expect(data.sections.every((slice) => slice.value > 0), isTrue);
      expect(
        data.sections.any((slice) => slice.color == HomePalette.activity),
        isFalse,
      );
      expect(data.sumValue, closeTo(496 * minute + 20000, 0.001));
      expect(find.text('0 分钟'), findsOneWidget);
      expect(find.text('少于 1 分钟'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('summary-part-activity')));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureChart(tester, 'summary-zero-activity');
    },
  );

  testWidgets('all-zero composition shows the existing empty state', (
    tester,
  ) async {
    await mountChart(tester, [part('sleep', '睡眠', 0, HomePalette.sleep)]);
    expect(find.text('当前窗口暂无可显示的时间构成。'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh follows stable ids and drops a removed goal selection', (
    tester,
  ) async {
    final a = part('a', '甲目标', 60 * minute, HomePalette.activity);
    final b = part('b', '乙目标', 30 * minute, HomePalette.sleep);
    await mountChart(tester, [a, b]);
    await tester.tap(find.byKey(const ValueKey('summary-part-a')));
    await tester.pumpAndSettle();
    expect(find.text('67%'), findsOneWidget);
    await mountChart(tester, [b, a]);
    expect(find.text('67%'), findsOneWidget);
    await mountChart(tester, [b]);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('甲目标'), findsNothing);
    final data = tester.widget<PieChart>(find.byType(PieChart)).data;
    expect(data.sumValue, 30 * minute);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile, wide and large text keep labels and values readable', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 600.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        await mountChart(
          tester,
          chartParts(),
          width: width,
          scale: scale,
          centerValue: '23 小时 59 分钟',
        );
        final chart = tester.getRect(find.byType(PieChart));
        final tile = tester.getRect(
          find.byKey(const ValueKey('summary-part-sleep')),
        );
        if (width < 600 || scale > 1.3) {
          expect(tile.top, greaterThanOrEqualTo(chart.bottom));
        } else {
          expect(tile.left, greaterThan(chart.right));
        }
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('summary-part-unknown')),
        );
        await tester.tap(find.byKey(const ValueKey('summary-part-unknown')));
        await tester.pumpAndSettle();
        expect(find.text('17%'), findsOneWidget);
        final name = tester.getRect(find.text('想不起来'));
        expect(name.height, lessThan(30 * scale));
        expect(name.left, greaterThanOrEqualTo(20));
        expect(name.right, lessThanOrEqualTo(width - 20));
        expect(tester.takeException(), isNull);
        await captureChart(tester, 'summary-$width-scale-$scale');
        // 下一次布局从相同的未选中状态开始。
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('long goal names remain complete with large text', (
    tester,
  ) async {
    const name = '完成个人时间账本的首页设计和跨平台验证，保留完整目标名称';
    await mountChart(
      tester,
      [
        part(
          'goal',
          name,
          23 * 60 * minute + 59 * minute,
          HomePalette.activity,
        ),
      ],
      width: 320,
      scale: 2,
      centerValue: '23 小时 59 分钟',
    );
    expect(find.text(name), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('summary-part-goal')));
    await tester.tap(find.byKey(const ValueKey('summary-part-goal')));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureChart(tester, 'summary-long-goal-scale-2');
  });

  testWidgets('legend keeps accessible selection and native keyboard actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await mountChart(tester, chartParts());
      expect(find.bySemanticsLabel('睡眠 1 小时'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('33%'), findsOneWidget);
      final node = tester.getSemantics(find.bySemanticsLabel('睡眠 1 小时，占 33%'));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(
        node.getSemanticsData().flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    } finally {
      handle.dispose();
    }
  });
}
