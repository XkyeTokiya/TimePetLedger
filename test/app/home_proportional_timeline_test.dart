import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_day_axis.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_day_header.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_ledger_style.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_reading_state.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_suggestion_card.dart';
import 'package:time_pet_ledger/features/ledger/application/home_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_geometry.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';

import '../support/home_feed.dart';

final date = CivilDate(year: 2026, month: 10, day: 7);
final start = DateTime(2026, 10, 7).millisecondsSinceEpoch;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
TimeBlock block(int n, int from, int to, {bool unknown = false}) => TimeBlock(
  id: id(n),
  startedAt: start + from * 60000,
  endedAt: start + to * 60000,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.exact,
  knowledgeState: unknown
      ? BlockKnowledgeState.unknown
      : BlockKnowledgeState.known,
  title: unknown ? '原文字不作标题' : '活动$n',
  createdAt: 1,
  updatedAt: 1,
);
DayLedgerView project(
  List<TimeBlock> blocks, {
  int hours = 24,
  LedgerDateRelation relation = LedgerDateRelation.historical,
}) => projectDayLedgerView(
  date: date,
  relation: relation,
  dayStartedAt: start,
  nextDayStartedAt: start + hours * 3600000,
  now: start + 18 * 3600000,
  timeBlocks: blocks,
  windowSleepSessions: const [],
  annotations: const [],
  sleepSummaryCandidates: const [],
  goals: const [],
);

const captureKey = ValueKey('proportional-capture');
Future<void> capture(
  WidgetTester t,
  String name, {
  double pixelRatio = 2,
}) async {
  final directory = Platform.environment['HOME_TIME_CAPTURE_DIR'];
  if (directory == null) return;
  await t.runAsync(() async {
    final image = await t
        .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
        .toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<HomeShellState> mount(
  WidgetTester t, {
  double width = 360,
  double scale = 1,
  List<TimeBlock>? blocks,
  bool today = false,
  bool empty = false,
  bool suggestion = false,
  List<TimeBlock> Function()? liveBlocks,
  int Function()? clock,
  bool Function()? fails,
  void Function(CivilDate, Object)? onGap,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 800);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final records =
      blocks ??
      [
        block(1, 600, 660),
        block(2, 660, 720),
        block(3, 740, 780),
        block(4, 780, 860, unknown: true),
        block(5, 860, 980),
      ];
  final sleep = SleepSession(
    id: id(99),
    startedAt: start + 480 * 60000,
    endedAt: start + 600 * 60000,
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    createdAt: 1,
    updatedAt: 1,
  );
  final loader = DayLedgerLoader(
    resolveDate: resolveDeviceRecordingDate,
    readFacts: (_) async {
      if (fails?.call() ?? false) throw StateError('fixture read failure');
      return DayLedgerFacts(
        ledger: SleepLedgerSnapshot(
          windowFacts: LedgerSnapshot(
            timeBlocks: liveBlocks != null
                ? liveBlocks()
                : empty
                ? []
                : records,
            sleepSessions: empty || blocks != null || liveBlocks != null
                ? []
                : [sleep],
            annotations: const [],
          ),
          sleepSummaryCandidates: const [],
        ),
        goals: const [],
      );
    },
  );
  await t.pumpWidget(
    MaterialApp(
      theme: homeTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: HomeShell(
        ledgerLoader: loader,
        now:
            clock ??
            () => today
                ? start + 18 * 3600000
                : start + 24 * 3600000 + 9 * 3600000,
        dateOfInstant: deviceDateOfInstant,
        initialDate: date,
        busy: false,
        onOpenSummary: (_) {},
        onOpenReview: (_) {},
        onRecordActivity: () {},
        onRecordSleep: () {},
        onFillGap: (date, gap) => onGap?.call(date, gap),
        floatingCard: suggestion
            ? (_) => const Padding(
                padding: EdgeInsets.all(12),
                child: HomeSuggestionCard(
                  key: ValueKey('test-suggestion'),
                  suggestion: HomeSuggestion(
                    kind: HomeSuggestionKind.greeting,
                    title: '早上好。',
                  ),
                ),
              )
            : null,
      ),
    ),
  );
  await t.pumpAndSettle();
  return t.state<HomeShellState>(find.byType(HomeShell));
}

HomeTimelineTabState timeline(WidgetTester t) =>
    t.state<HomeTimelineTabState>(find.byType(HomeTimelineTab).last);
ScrollableState scrollable(WidgetTester t) => t.state<ScrollableState>(
  find
      .descendant(
        of: find.byType(HomeTimelineTab).last,
        matching: find.byType(Scrollable),
      )
      .first,
);

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

  test(
    'geometry shares exact boundaries, actual day lengths and half-open hits',
    () {
      final geometry = HomeTimelineGeometry(startedAt: start);
      for (final (minutes, dp) in [
        (20, 24),
        (40, 48),
        (60, 72),
        (80, 96),
        (120, 144),
      ]) {
        expect(geometry.height(start, start + minutes * 60000), dp.toDouble());
      }
      for (final hours in [23, 24, 25]) {
        final view = project([], hours: hours);
        expect(geometry.y(view.window.endedAt), hours * 72);
        final intervals = TimelineInterval.fromView(view);
        expect(geometry.hit(intervals, 0), same(intervals.first));
        expect(geometry.hit(intervals, hours * 72.0), isNull);
        expect(geometry.hit(intervals, -.0001), isNull);
      }
      final intervals = TimelineInterval.fromView(
        project([block(1, 0, 20), block(2, 20, 60)]),
      );
      expect(geometry.hit(intervals, 24), same(intervals[1]));
      expect(geometry.hit(intervals, 24 - .000001), same(intervals[0]));
      expect(
        geometry.hit(
          TimelineInterval.fromView(
            project([], relation: LedgerDateRelation.future),
          ),
          0,
        ),
        isNull,
      );
    },
  );

  test('short clusters use actual dp and stop at long intervals or discontinuities', () {
    final intervals = TimelineInterval.fromView(
      project([
        block(1, 0, 1),
        block(2, 1, 6),
        block(3, 6, 16),
        block(4, 16, 36),
        block(5, 36, 76),
        block(6, 76, 136),
        block(7, 150, 155),
      ]),
    );
    final geometry = HomeTimelineGeometry(startedAt: start);
    final clusters = geometry.shortClusters(intervals);
    expect(clusters.map((cluster) => cluster.length), [4, 2]);
    expect(clusters.last.first.gap, isNotNull);
    final disconnected = [
      TimelineInterval.fact(project([block(1, 0, 5)]).segments.first),
      TimelineInterval.fact(project([block(2, 6, 10)]).segments.first),
    ];
    expect(geometry.shortClusters(disconnected).map((c) => c.length), [1, 1]);
    final exact = TimelineInterval.fact(
      project([
        TimeBlock(
          id: id(10),
          startedAt: start,
          endedAt: start + 1600000,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '边界',
          createdAt: 1,
          updatedAt: 1,
        ),
      ]).segments.first,
    );
    expect(geometry.shortClusters([exact]), isEmpty);
    final enlarged = HomeTimelineGeometry(startedAt: start, a11yFactor: 1.25);
    expect(enlarged.height(start, start + 3600000), 90);
    expect(enlarged.shortClusters([exact]), isEmpty);
  });

  testWidgets('paper-tape header settles both directions without jumping', (
    tester,
  ) async {
    final state = HomeReadingState(vsync: const TestVSync());
    addTearDown(state.dispose);

    state.beginUserRead();
    state.updateUserRead(fingerUp: false, distance: 40);
    expect(state.progress, 0);
    state.updateUserRead(fingerUp: false, distance: 40);
    expect(state.progress, .5);
    state.updateUserRead(fingerUp: false, distance: 40);
    expect(state.state, HomeHeaderState.collapsed);
    state.updateUserRead(fingerUp: true, distance: 200);
    expect(state.state, HomeHeaderState.collapsed);

    state.reset();
    state.beginUserRead();
    state.updateUserRead(fingerUp: false, distance: 50);
    expect(state.progress, .125);
    state.updateUserRead(fingerUp: true, distance: 1);
    expect(state.progress, .125);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(state.progress, allOf(greaterThan(.125), lessThan(1)));
    await tester.pumpAndSettle();
    expect(state.state, HomeHeaderState.collapsed);
    state.expandForDayDividerAtTop();
    expect(state.progress, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(state.progress, allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(state.state, HomeHeaderState.expanded);
    expect(state.progress, 0);
  });

  testWidgets(
    'history starts at first fact; today at same-read now; empty history at midnight',
    (t) async {
      var shell = await mount(t);
      expect(
        timeline(t).readingPosition!.instant,
        greaterThan(start + 480 * 60000 - 400000),
      );
      expect(timeline(t).readingPosition!.relativeY, closeTo(0, .1));
      expect(shell.reading.progress, 0);
      await t.pumpWidget(const SizedBox.shrink());
      shell = await mount(t, today: true);
      expect(timeline(t).readingPosition!.instant, start + 18 * 3600000);
      expect(timeline(t).readingPosition!.relativeY, closeTo(-40, .1));
      expect(shell.reading.progress, 0);
      await t.pumpWidget(const SizedBox.shrink());
      await mount(t, empty: true);
      expect(find.text('00:00'), findsWidgets);
      expect(find.text('尚未记录'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'user reading collapses; program jumps/refresh and crossing a day preserve state; explicit day resets',
    (t) async {
      final shell = await mount(t, suggestion: true, today: true);
      expect(find.byKey(const ValueKey('test-suggestion')), findsOneWidget);
      final origin = timeline(t).readingOrigin!;
      await t.drag(find.byType(HomeTimelineTab), const Offset(0, 170));
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(find.byKey(const ValueKey('test-suggestion')), findsNothing);
      expect(find.byKey(const ValueKey('home-coverage-ratio')), findsNothing);
      expect(coverageText(t, '已交代'), '8 小时');
      final before = timeline(t).readingPosition!;
      await shell.refresh();
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(timeline(t).readingPosition!.instant, before.instant);
      expect(timeline(t).readingOrigin!.instant, origin.instant);
      await t.drag(find.byType(HomeTimelineTab), const Offset(0, 1800));
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(homeDateTitle(t), '10月6日');
      await shell.openDate(date);
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.expanded);
      expect(timeline(t).readingPosition!.instant, start + 18 * 3600000);
      expect(timeline(t).readingPosition!.relativeY, closeTo(-40, .1));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh after a Gap split preserves its interior instant, not a row top',
    (t) async {
      var records = <TimeBlock>[];
      final shell = await mount(t, empty: true, liveBlocks: () => records);
      final position = scrollable(t).position;
      position.jumpTo(position.pixels + 300);
      await t.pumpAndSettle();
      final before = timeline(t).readingPosition!;
      records = [block(50, 240, 260)];
      await shell.refresh();
      await t.pumpAndSettle();
      expect(timeline(t).readingPosition!.instant, before.instant);
      expect(shell.reading.progress, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'adjacent tiny segments open chooser; each remains semantic and keyboard focus returns',
    (t) async {
      final shell = await mount(
        t,
        blocks: [
          block(1, 0, 1),
          block(2, 1, 6),
          block(3, 6, 16, unknown: true),
          block(4, 16, 36),
          block(5, 36, 96),
        ],
      );
      final axis = t.widgetList<HomeDayAxis>(find.byType(HomeDayAxis)).last;
      final items = TimelineInterval.fromView(axis.view);
      final semanticsHandle = t.ensureSemantics();
      try {
        for (final item in items) {
          expect(
            find.byKey(ValueKey(('timeline-semantics', date, item.id))),
            findsOneWidget,
          );
        }
        final target = find.byKey(ValueKey(items.first.id)).last;
        expect(t.getSize(target).height, closeTo(1.2, .0001));
        final focus = t
            .widget<Focus>(
              find.ancestor(of: target, matching: find.byType(Focus)).first,
            )
            .focusNode!;
        focus.requestFocus();
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(find.text('时段选择'), findsOneWidget);
        for (final item in items.take(4)) {
          final row = find.byKey(ValueKey(('time-choice', item.id)));
          expect(t.getSize(row).height, greaterThanOrEqualTo(48));
        }
        expect(find.text('选择'), findsWidgets);
        expect(shell.reading.progress, 0);
        await t.tap(find.byTooltip('关闭'));
        await t.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await t.tapAt(t.getCenter(target));
        await t.pumpAndSettle();
        expect(find.text('时段选择'), findsOneWidget);
        await t.tap(find.byKey(ValueKey(('time-choice', items[2].id))));
        await t.pumpAndSettle();
        expect(find.text('记录详情'), findsOneWidget);
        expect(find.text('原文字不作标题'), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'continuous touch survives compensation and same-day return stays compact',
    (t) async {
      final shell = await mount(t);
      final state = timeline(t);
      final originalOffset = scrollable(t).position.pixels;
      final gesture = await t.startGesture(
        t.getCenter(find.byType(HomeTimelineTab)),
      );
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(timeline(t), same(state));
      expect(shell.reading.state, HomeHeaderState.collapsed);
      await gesture.up();
      await t.pumpAndSettle();
      scrollable(t).position.jumpTo(originalOffset);
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      await t.drag(find.byType(HomeTimelineTab), const Offset(0, -25));
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'isolated short fact goes directly to details and half-open shared pixel chooses later interval',
    (t) async {
      await mount(t, blocks: [block(1, 0, 20), block(2, 20, 80)]);
      final items = TimelineInterval.fromView(
        t.widgetList<HomeDayAxis>(find.byType(HomeDayAxis)).last.view,
      );
      final target = find.byKey(ValueKey(items.first.id)).last;
      expect(t.getSize(target).height, 24);
      expect(find.text('选择'), findsNothing);
      await t.tapAt(t.getCenter(target));
      await t.pumpAndSettle();
      expect(find.text('时段选择'), findsNothing);
      expect(find.text('记录详情'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      final next = find.byKey(ValueKey(items[1].id)).last;
      await t.tapAt(Offset(t.getCenter(next).dx, t.getTopLeft(next).dy));
      await t.pumpAndSettle();
      expect(find.text('活动2'), findsWidgets);
      expect(find.text('记录详情'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'failed explicit date preserves collapsed anchor; successful retry resets it',
    (t) async {
      var fail = false;
      final shell = await mount(t, fails: () => fail);
      await t.drag(find.byType(HomeTimelineTab), const Offset(0, 170));
      await t.pumpAndSettle();
      final before = timeline(t).readingPosition!;
      final origin = timeline(t).readingOrigin!;
      fail = true;
      await shell.openDate(CivilDate(year: 2026, month: 10, day: 6));
      await t.pumpAndSettle();
      expect(shell.feed.refreshFailed, isTrue);
      expect(shell.feed.focusDate, date);
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(timeline(t).readingPosition!.instant, before.instant);
      expect(timeline(t).readingOrigin, same(origin));
      fail = false;
      await shell.refresh();
      await t.pumpAndSettle();
      expect(shell.feed.focusDate.day, 6);
      expect(shell.reading.state, HomeHeaderState.expanded);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic midnight reveal preserves the previous reading origin and collapse lock',
    (t) async {
      var now = start + 18 * 3600000;
      final shell = await mount(t, today: true, clock: () => now);
      shell.reading.beginUserRead();
      shell.reading.updateUserRead(fingerUp: false, distance: 120);
      shell.reading.endUserRead();
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      final origin = timeline(t).readingOrigin;
      now = start + 24 * 3600000 + 30 * 60000;
      await shell.refresh();
      await t.pumpAndSettle();
      expect(shell.feed.focusDate.day, 8);
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(timeline(t).readingOrigin, same(origin));
      await t.drag(find.byType(HomeTimelineTab), const Offset(0, -25));
      await t.pumpAndSettle();
      expect(shell.reading.state, HomeHeaderState.collapsed);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'resize recomputes temporal anchor under the effective scale; short large-text viewport retains controls',
    (t) async {
      final shell = await mount(t, width: 320, scale: 2, empty: true);
      final scroll = scrollable(t).position;
      scroll.jumpTo(scroll.pixels + 300);
      await t.pumpAndSettle();
      final before = timeline(t).readingPosition!;
      t.view.physicalSize = const Size(360, 800);
      await t.pumpAndSettle();
      expect(timeline(t).readingPosition!.instant, closeTo(before.instant, 1));
      expect(shell.reading.progress, 0);
      t.view.physicalSize = const Size(320, 420);
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(HomeTimelineTab)).height, greaterThan(0));
      expect(
        find.byKey(const ValueKey('home-record-sleep')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home-record-activity')).hitTestable(),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'updated projection invalidates stale chooser Gap and W.end never activates a block',
    (t) async {
      var records = [block(1, 0, 20), block(2, 40, 60), block(3, 60, 120)];
      var filled = 0;
      final shell = await mount(
        t,
        liveBlocks: () => records,
        onGap: (_, _) => filled++,
      );
      final items = TimelineInterval.fromView(shell.feed.focusView!);
      final gap = items[1];
      final origin = find.byKey(ValueKey(items.first.id)).last;
      await t.tapAt(t.getCenter(origin));
      await t.pumpAndSettle();
      expect(find.text('时段选择'), findsOneWidget);
      records = [...records, block(9, 20, 40)];
      await shell.refresh();
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey(('time-choice', gap.id))));
      await t.pumpAndSettle();
      expect(filled, 0);
      expect(find.text('记录详情'), findsNothing);
      final lastGap = TimelineInterval.fromView(shell.feed.focusView!).last;
      final position = scrollable(t).position;
      position.jumpTo(position.maxScrollExtent);
      await t.pumpAndSettle();
      final target = find.byKey(ValueKey(lastGap.id)).last;
      await t.tapAt(Offset(t.getCenter(target).dx, t.getBottomLeft(target).dy));
      await t.pumpAndSettle();
      expect(filled, 0);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    '320dp at 2x reads a 20 minute Gap at base scale with the revised short-state style',
    (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final view = project([block(1, 0, 720), block(2, 740, 1440)]);
      final gap = TimelineInterval.fromView(view)
          .singleWhere((i) => i.gap != null);
      final viewport = HomeAxisViewport();
      addTearDown(viewport.dispose);
      for (final factor in [1.0, 1.25]) {
        final geometry = HomeTimelineGeometry(
          startedAt: start,
          a11yFactor: factor,
        );
        final scroll = ScrollController(
          initialScrollOffset: geometry.y(gap.startedAt) - 16,
        );
        await t.pumpWidget(
          MaterialApp(
            theme: homeTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: RepaintBoundary(key: captureKey, child: child!),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                key: ValueKey(factor),
                controller: scroll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: HomeDayAxis(
                    view: view,
                    geometry: geometry,
                    viewport: viewport,
                    isToday: false,
                    isCurrent: () => true,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        viewport.update(
          scroll.offset,
          scroll.offset + scroll.position.viewportDimension,
        );
        await t.pumpAndSettle();
        final stateWord = find.descendant(
          of: find.byKey(ValueKey(gap.id)),
          matching: find.text('尚未记录'),
        );
        expect(stateWord, findsOneWidget);
        final bounds = t.getRect(find.byKey(ValueKey(gap.id)));
        final wordBounds = t.getRect(stateWord);
        expect(wordBounds.top, greaterThanOrEqualTo(bounds.top));
        expect(wordBounds.bottom, lessThanOrEqualTo(bounds.bottom));
        debugPrint(
          'HOME_STATE_LINE: p=${geometry.dpPerHour}, block=${bounds.height}, word=${wordBounds.height}, textScale=2',
        );
        expect(
          geometry.height(gap.startedAt, gap.endedAt),
          factor == 1 ? 24 : 30,
        );
        expect(t.takeException(), isNull);
        await capture(t, 'a11y-${geometry.dpPerHour.toInt()}-320-2');
        await t.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
      }
    },
  );

  testWidgets(
    'information groups align while short states stay centered inside real boundaries',
    (t) async {
      await mount(t);
      final axisFinder = find.byType(HomeDayAxis).last;
      final axis = t.widget<HomeDayAxis>(axisFinder);
      final intervals = TimelineInterval.fromView(axis.view);
      for (final (number, clock) in [(1, '10:00'), (2, '11:00')]) {
        final interval = intervals.singleWhere(
          (i) => i.startedAt == start + (number == 1 ? 600 : 660) * 60000,
        );
        final card = find.byKey(ValueKey(interval.id)).last;
        final bounds = t.getRect(card);
        final tick = find.descendant(
          of: axisFinder,
          matching: find.text(clock),
        );
        expect(t.getCenter(tick).dy, closeTo(bounds.top, .1));
        final title = find.descendant(
          of: card,
          matching: find.text('活动$number'),
        );
        final icon = find.descendant(of: card, matching: find.byType(Icon));
        expect(t.getCenter(title).dy, closeTo(t.getCenter(icon).dy, .1));
        final range = find.descendant(
          of: card,
          matching: find.text('$clock – ${number == 1 ? '11:00' : '12:00'}'),
        );
        final duration = find.descendant(of: card, matching: find.text('1 小时'));
        expect(t.getRect(range).top, greaterThan(bounds.top));
        expect(t.getRect(range).bottom, lessThan(t.getRect(title).top));
        expect(t.getRect(title).bottom, lessThan(t.getRect(duration).top));
        expect(t.getRect(duration).bottom, lessThan(bounds.bottom));
        expect(bounds.height, 72);
      }
      final gap = intervals.singleWhere(
        (i) => i.startedAt == start + 720 * 60000,
      );
      final strip = find.byKey(ValueKey(gap.id)).last;
      final word = find.descendant(of: strip, matching: find.text('尚未记录'));
      final duration = find.descendant(of: strip, matching: find.text('20 分钟'));
      expect(t.getSize(strip).height, 24);
      expect(t.getCenter(word).dy, closeTo(t.getCenter(strip).dy, .5));
      expect(t.getCenter(duration).dy, closeTo(t.getCenter(strip).dy, .5));
      expect(t.getRect(strip).contains(t.getTopLeft(word)), isTrue);
      expect(t.getRect(strip).contains(t.getBottomRight(word)), isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'visual matrix preserves geometry across widths/text scales and both header states',
    (t) async {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          final shell = await mount(
            t,
            width: width,
            scale: scale,
            suggestion: true,
          );
          expect(t.takeException(), isNull);
          final axis = t.widgetList<HomeDayAxis>(find.byType(HomeDayAxis)).last;
          expect(axis.geometry.dpPerHour, 72);
          await capture(t, 'expanded-$width-$scale');
          if (width == 360 && scale == 1) {
            expect(find.text('日账本'), findsOneWidget);
            expect(
              t.getCenter(find.byKey(const ValueKey('home-menu'))).dy,
              lessThan(
                t
                    .getCenter(find.byKey(const ValueKey('ledger-date-picker')))
                    .dy,
              ),
            );
            await capture(t, 'expanded-360-1-logical', pixelRatio: 1);
          }
          await t.drag(find.byType(HomeTimelineTab), const Offset(0, 170));
          await t.pumpAndSettle();
          expect(shell.reading.state, HomeHeaderState.collapsed);
          expect(find.byKey(const ValueKey('home-menu')), findsOneWidget);
          expect(
            find.byKey(const ValueKey('home-record-sleep')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('home-record-activity')).hitTestable(),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          for (final key in [
            'home-menu',
            'home-previous-day',
            'home-next-day',
            'ledger-date-picker',
            'home-back-to-today',
            'home-coverage',
            'home-record-sleep',
            'home-record-activity',
          ]) {
            final control = find.byKey(ValueKey(key));
            expect(control.hitTestable(), findsOneWidget);
            expect(t.getSize(control).width, greaterThanOrEqualTo(48));
            expect(t.getSize(control).height, greaterThanOrEqualTo(48));
          }
          for (final label in ['记录睡眠', '记录一笔']) {
            final paragraph = t.renderObject<RenderParagraph>(find.text(label));
            expect(
              paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: label.length),
              ),
              hasLength(1),
            );
          }
          final viewport = t.getRect(find.byType(HomeTimelineTab));
          final currentTicks = find.descendant(
            of: find.byType(HomeDayAxis).last,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data != '24:00' &&
                  RegExp(r'^\d\d:\d\d$').hasMatch(widget.data ?? ''),
            ),
          );
          for (final element in currentTicks.evaluate()) {
            final bounds = t.getRect(find.byWidget(element.widget));
            expect(bounds.top, greaterThanOrEqualTo(viewport.top));
            expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
          }
          await capture(t, 'collapsed-$width-$scale');
          if (width == 360 && scale == 1) {
            expect(find.text('日账本'), findsNothing);
            final dateRowY = t
                .getCenter(find.byKey(const ValueKey('ledger-date-picker')))
                .dy;
            expect(
              t.getCenter(find.byKey(const ValueKey('home-menu'))).dy,
              closeTo(dateRowY, 1),
            );
            expect(
              t.getCenter(find.byKey(const ValueKey('home-back-to-today'))).dy,
              closeTo(dateRowY, 1),
            );
            await capture(t, 'collapsed-360-1-logical', pixelRatio: 1);
          }
          await t.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'a tall Gap keeps one stable label form through the whole scroll',
    (t) async {
      await mount(t);
      final axisFinder = find.byType(HomeDayAxis).last;
      final axis = t.widget<HomeDayAxis>(axisFinder);
      final intervals = TimelineInterval.fromView(axis.view);
      final gap = intervals.singleWhere(
        (i) => i.gap != null && i.startedAt == start + 980 * 60000,
      );
      final card = find.descendant(
        of: axisFinder,
        matching: find.byKey(ValueKey(gap.id)),
      );
      final word = find.descendant(of: card, matching: find.text('尚未记录'));
      final position = scrollable(t).position;
      final viewport = t.getRect(find.byType(HomeTimelineTab).last);
      // 让长 Gap 顶边停在窗口下沿附近，再逐步上滑，让整段经过视口。
      position.jumpTo(
        (position.pixels + t.getRect(card.last).top - viewport.bottom + 12)
            .clamp(0.0, position.maxScrollExtent),
      );
      await t.pump();
      await t.pump();
      final lineHeight =
          HomeLedgerStyle.state.fontSize! * HomeLedgerStyle.state.height!;
      var sawVisible = false;
      for (var i = 0; i < 100; i++) {
        position.jumpTo(
          (position.pixels + 8).clamp(0.0, position.maxScrollExtent),
        );
        await t.pump(const Duration(milliseconds: 16));
        final cardRect = t.getRect(card.last);
        if (cardRect.top < viewport.top) break;
        final visible = (viewport.bottom - cardRect.top).clamp(
          0.0,
          cardRect.height,
        );
        if (visible >= lineHeight) {
          // 滚动中标签形态必须只由块高决定，不能在视口边缘退化成
          // 单行 / 紧凑形态而让同一段文字反复变形。
          expect(word, findsOneWidget);
          expect(
            t.widget<Text>(word).style!.fontSize,
            HomeLedgerStyle.title.fontSize,
          );
          sawVisible = true;
        }
      }
      expect(sawVisible, isTrue);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'today weekday joins the date line and removes the extra header row',
    (t) async {
      await mount(t, width: 600, today: true);
      final date = find.byKey(const ValueKey('home-date-title')).last;
      final weekday = find.descendant(
        of: find.byType(HomeDateTitle).last,
        matching: find.text('周三 · 今天'),
      );
      expect(date, findsOneWidget);
      expect(weekday, findsOneWidget);
      final dateRect = t.getRect(date);
      final weekRect = t.getRect(weekday);
      // 同一行：垂直投影相交，星期在日期右侧。
      expect(weekRect.top, lessThan(dateRect.bottom));
      expect(weekRect.bottom, greaterThan(dateRect.top));
      expect(weekRect.left, greaterThanOrEqualTo(dateRect.right));
      expect(find.byKey(const ValueKey('home-back-to-today')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'weekday falls back below the date when the line cannot fit both',
    (t) async {
      await mount(t, width: 320, scale: 2, today: true);
      final date = find.byKey(const ValueKey('home-date-title')).last;
      final weekday = find.descendant(
        of: find.byType(HomeDateTitle).last,
        matching: find.text('周三 · 今天'),
      );
      expect(date, findsOneWidget);
      final dateRect = t.getRect(date);
      final weekRect = t.getRect(weekday);
      expect(weekRect.top, greaterThanOrEqualTo(dateRect.bottom));
      expect(t.takeException(), isNull);
    },
  );
}
