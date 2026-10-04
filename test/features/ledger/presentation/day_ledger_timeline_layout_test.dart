import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_coverage.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final dayStart = DateTime(2026, 10, 2).millisecondsSinceEpoch;
final dayEnd = DateTime(2026, 10, 3).millisecondsSinceEpoch;
int at(int minutes) => dayStart + minutes * Duration.millisecondsPerMinute;

DayLedgerView sample({bool longText = false, bool approximateWake = false}) {
  final goal = Goal.create(
    id: id(10),
    name: longText ? List.filled(20, '毕业设计🐾').join() : '毕业设计',
    now: 1,
  );
  return projectDayLedgerView(
    date: CivilDate(year: 2026, month: 10, day: 2),
    relation: LedgerDateRelation.historical,
    dayStartedAt: dayStart,
    nextDayStartedAt: dayEnd,
    now: dayEnd,
    timeBlocks: [
      TimeBlock(
        id: id(1),
        startedAt: at(440),
        endedAt: at(480),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '早餐',
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: id(2),
        startedAt: at(480),
        endedAt: at(600),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: longText ? List.filled(20, '设计首页🐾').join() : '设计首页',
        goalId: goal.id,
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: id(3),
        startedAt: at(600),
        endedAt: at(630),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.unknown,
        title: '只记得出门办事',
        goalId: goal.id,
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: id(4),
        startedAt: at(660),
        endedAt: at(690),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '散步',
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    windowSleepSessions: [
      SleepSession(
        // Same ID as breakfast, different formal fact type.
        id: id(1),
        startedAt: at(-20),
        endedAt: at(440),
        startPrecision: approximateWake
            ? TimePrecision.exact
            : TimePrecision.approximate,
        endPrecision: approximateWake
            ? TimePrecision.approximate
            : TimePrecision.exact,
        type: SleepType.mainSleep,
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    annotations: [
      RhythmAnnotation(
        id: id(20),
        timeBlockId: id(2),
        state: RhythmState.progress,
        continuationHint: longText
            ? '${List.filled(20, '先画补记弹层🐾').join()}\n打开设计稿，继续核对时间轴。'
            : '先画补记弹层',
        createdAt: 1,
        updatedAt: 1,
      ),
      RhythmAnnotation(
        id: id(21),
        timeBlockId: id(3),
        state: RhythmState.stuck,
        continuationHint: '回想路线\n保留原有内容 🐾',
        createdAt: 1,
        updatedAt: 1,
      ),
      RhythmAnnotation(
        id: id(22),
        timeBlockId: id(4),
        state: RhythmState.recovery,
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    sleepSummaryCandidates: [],
    goals: [goal],
  );
}

const captureKey = ValueKey('timeline-capture');
const viewportCaptureKey = ValueKey('timeline-viewport-capture');
Future<void> mount(
  WidgetTester tester,
  DayLedgerView view, {
  double scale = 1,
  ValueChanged<LedgerSegment>? onEdit,
  ValueChanged<TimeBlockSegment>? onDelete,
  ValueChanged<UnresolvedSpan>? onGap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: timeLedgerTheme.copyWith(
        textTheme: timeLedgerTheme.textTheme.apply(
          fontFamily: Platform.environment['UI_T01_FONT_PATH'] == null
              ? null
              : 'TimelineCapture',
          fontFamilyFallback: const ['TimelineEmoji'],
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: viewportCaptureKey,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: captureKey,
              child: DayLedgerTimeline(
                view: view,
                onEditFact: onEdit,
                onDeleteTimeBlock: onDelete,
                onFillGap: onGap,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> capture(
  WidgetTester tester,
  String name, {
  Key key = captureKey,
}) async {
  final directory = Platform.environment['UI_T01_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Optional local fonts make screenshot evidence readable; no font or
    // dependency is added to the production app or required by the test suite.
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final entry in [
      ('UI_T01_FONT_PATH', 'TimelineCapture'),
      ('UI_T01_EMOJI_FONT_PATH', 'TimelineEmoji'),
    ]) {
      final path = Platform.environment[entry.$1];
      if (path == null) continue;
      final loader = FontLoader(entry.$2);
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('mixed and long timeline at width $width, text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          for (final longText in [false, true]) {
            final view = sample(longText: longText);
            await mount(
              tester,
              view,
              scale: scale,
              onEdit: (_) {},
              onDelete: (_) {},
              onGap: (_) {},
            );
            if (width == 360 && scale == 1 && !longText) {
              await capture(tester, 'mixed-360-scale-1');
            }
            if (width == 320 && scale == 2 && longText) {
              await capture(
                tester,
                'long-320-scale-2-viewport',
                key: viewportCaptureKey,
              );
            }
            final rows = find.byWidgetPredicate(
              (w) => w is LedgerFactTimelineTile || w is LedgerGapTimelineTile,
            );
            expect(rows, findsNWidgets(7));
            final ranges = find.byKey(const ValueKey('slice-range'));
            final rails = find.byKey(const ValueKey('timeline-rail'));
            final first = tester.getRect(ranges.first);
            for (var i = 0; i < 7; i++) {
              final rect = tester.getRect(ranges.at(i));
              expect(rect.left, first.left);
              expect(rect.width, first.width);
              final railRect = tester.getRect(rails.at(i));
              expect(railRect.height, tester.getSize(rows.at(i)).height);
              if (i < 6) {
                expect(railRect.bottom, tester.getRect(rails.at(i + 1)).top);
              }
            }
            for (final text in tester.widgetList<Text>(
              find.descendant(
                of: find.byKey(captureKey),
                matching: find.byType(Text),
              ),
            )) {
              expect(text.maxLines, isNull);
              expect(text.overflow, isNull);
            }
            // Check each actionable row after it is brought into the viewport.
            for (var i = 0; i < 7; i++) {
              final action = rows.at(i);
              await tester.ensureVisible(action);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(
                tester.getRect(action).size.shortestSide,
                greaterThanOrEqualTo(48),
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }
            if ((width == 360 && scale == 1 && !longText) ||
                (width == 320 && scale == 2 && longText)) {
              await capture(
                tester,
                longText ? 'long-320-scale-2' : 'mixed-360-scale-1',
              );
            }
            expect(find.text('想不起来'), findsOneWidget);
            expect(find.text('只记得出门办事'), findsOneWidget);
            expect(find.text('完整约7小时40分'), findsOneWidget);
          }
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets(
    'all original actions preserve namespaced sources and the exact Gap instance',
    (tester) async {
      final view = sample();
      LedgerSegment? edited;
      TimeBlockSegment? deleted;
      UnresolvedSpan? filled;
      await mount(
        tester,
        view,
        onEdit: (value) => edited = value,
        onDelete: (value) => deleted = value,
        onGap: (value) => filled = value,
      );
      for (final segment in view.segments) {
        final row = find.byKey(ValueKey(segment.reference));
        await tester.ensureVisible(row);
        edited = null;
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(edited, isNull);
        await tester.tap(find.text('编辑完整记录'));
        await tester.pumpAndSettle();
        expect(edited, same(segment));
        if (segment is TimeBlockSegment) {
          await tester.tap(row);
          await tester.pumpAndSettle();
          await tester.tap(find.text('删除记录'));
          await tester.pumpAndSettle();
          expect(deleted, same(segment));
        } else {
          expect(
            find.descendant(of: row, matching: find.byTooltip('删除记录')),
            findsNothing,
          );
        }
      }
      for (var i = 0; i < view.unresolvedSpans.length; i++) {
        final row = find.byType(LedgerGapTimelineTile).at(i);
        final button = find.descendant(of: row, matching: find.text('补记'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        expect(filled, same(view.unresolvedSpans[i]));
        await tester.ensureVisible(
          find.descendant(of: row, matching: find.text('尚未记录')),
        );
        filled = null;
        await tester.tap(find.descendant(of: row, matching: find.text('尚未记录')));
        expect(filled, same(view.unresolvedSpans[i]));
      }
    },
  );

  testWidgets(
    'approximate wake affects only its retained slice end and complete duration',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final view = sample(approximateWake: true);
      await mount(tester, view);
      final row = find.byKey(ValueKey(view.segments.first.reference));
      expect(
        find.descendant(of: row, matching: find.text('00:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('约07:20')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('约7小时20分')),
        findsOneWidget,
      );
      expect(find.text('完整约7小时40分'), findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('10月1日 23:40'), findsOneWidget);
      expect(find.text('约10月2日 07:20'), findsOneWidget);
      expect(find.text('00:00–约07:20'), findsOneWidget);
      expect(find.text('完整睡眠'), findsOneWidget);
      await capture(tester, 'approximate-wake');
    },
  );
}
