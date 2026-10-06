import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_overview.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';

import '../../../support/ledger_date_selection.dart';
import '../../../support/rendered_text_contrast.dart';
import 'day_ledger_controller_test.dart' show emptyFacts;
import 'day_ledger_timeline_layout_test.dart' show sample;
import 'day_ledger_page_test.dart' show dateLabel;

const captureKey = ValueKey('overview-capture');

DayLedgerFacts mixedFacts({bool longText = false}) {
  final view = sample(longText: longText);
  final blocks = view.segments.whereType<TimeBlockSegment>().toList();
  return DayLedgerFacts(
    ledger: SleepLedgerSnapshot(
      windowFacts: LedgerSnapshot(
        timeBlocks: blocks.map((part) => part.source),
        sleepSessions: view.segments.whereType<SleepSessionSegment>().map(
          (part) => part.source,
        ),
        annotations: blocks.map((part) => part.annotation).nonNulls,
      ),
      sleepSummaryCandidates: [
        ...view.sleepSummary.mainSleep.records,
        ...view.sleepSummary.nap.records,
      ],
    ),
    goals: [
      for (final goal in view.goalSummaries)
        Goal.create(id: goal.goalId, name: goal.name, now: 1),
    ],
  );
}

Future<void> screenshot(WidgetTester tester, String name) async {
  final directory = Platform.environment['UI_T03_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> mountPage(WidgetTester tester, String state, double scale) async {
  final observer = RouteObserver<ModalRoute<void>>();
  final date = CivilDate(
    year: 2026,
    month: 10,
    day: state == 'future'
        ? 4
        : state == 'today' || state == 'midnight'
        ? 3
        : 2,
  );
  final loader = DayLedgerLoader(
    resolveDate: resolveDeviceRecordingDate,
    readFacts: (_) {
      if (state == 'loading') return Completer<DayLedgerFacts>().future;
      if (state == 'failure') return Future.error(StateError('secret detail'));
      return Future.value(
        state == 'mixed' || state == 'long'
            ? mixedFacts(longText: state == 'long')
            : emptyFacts(),
      );
    },
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: timeLedgerTheme.copyWith(
        textTheme: timeLedgerTheme.textTheme.apply(
          fontFamily: Platform.environment['UI_T03_FONT_PATH'] == null
              ? null
              : 'OverviewCapture',
          fontFamilyFallback: const ['OverviewEmoji'],
        ),
      ),
      navigatorObservers: [observer],
      builder: (context, child) => RepaintBoundary(
        key: captureKey,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: DayLedgerPage(
        loader: loader,
        now: () => DateTime(
          2026,
          10,
          3,
          state == 'midnight' ? 0 : 12,
        ).millisecondsSinceEpoch,
        dateOfInstant: deviceDateOfInstant,
        routeObserver: observer,
        initialDate: date,
        gapEntry: (_, _) => const Scaffold(body: Text('原Gap入口')),
        factEntry: (_, _) => const Scaffold(body: Text('原事实入口')),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  if (state != 'loading') await tester.pumpAndSettle();
}

Future<void> checkContrast(WidgetTester tester) async {
  final sdk = await textContrastGuideline.evaluate(tester);
  if (!sdk.passed) {
    debugPrint('UI-T03 SDK text contrast sampling limitation: ${sdk.reason}');
  }
  await expectLater(
    tester,
    meetsGuideline(const RenderedTextContrast(captureKey: captureKey)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final entry in [
      ('UI_T03_FONT_PATH', 'OverviewCapture'),
      ('UI_T03_EMOJI_FONT_PATH', 'OverviewEmoji'),
    ]) {
      final path = Platform.environment[entry.$1];
      if (path == null) continue;
      final loader = FontLoader(entry.$2)
        ..addFont(File(path).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('header states width $width scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          for (final state in [
            'mixed',
            'long',
            'empty',
            'today',
            'midnight',
            'future',
            'loading',
            'failure',
          ]) {
            await tester.pumpWidget(const SizedBox.shrink());
            await mountPage(tester, state, scale);
            expect(tester.takeException(), isNull, reason: state);
            for (final label in ['前一天', '后一天']) {
              final size = tester.getSize(find.byTooltip(label));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await checkContrast(tester);
            if (state == 'loading' || state == 'failure') {
              expect(find.byType(DayLedgerOverview), findsNothing);
              expect(find.text('已交代'), findsNothing);
            }
            if (state == 'future') expect(find.text('补记'), findsNothing);
            if ((width == 360 && scale == 1) || (width == 320 && scale == 2)) {
              await screenshot(tester, '$state-${width.toInt()}-scale-$scale');
            }
            if (state == 'long') {
              await tester.scrollUntilVisible(
                find.byType(DayLedgerTimeline),
                250,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              final lastGap = find
                  .widgetWithText(LedgerGapTimelineTile, '补记')
                  .last;
              await Scrollable.ensureVisible(
                tester.element(lastGap),
                alignment: .5,
              );
              await tester.pumpAndSettle();
              expect(lastGap.hitTestable(), findsOneWidget);
              final button = find.descendant(
                of: lastGap,
                matching: find.byType(OutlinedButton),
              );
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              expect(tester.takeException(), isNull);
            }
          }
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets(
    'narrow large date dialogs scroll, invalid/manual/cancel/keyboard preserve selection',
    (tester) async {
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mountPage(tester, 'empty', 2);
      final semantics = tester.ensureSemantics();
      try {
        await tester.tap(find.byKey(const ValueKey('ledger-date-picker')));
        await tester.pumpAndSettle();
        await screenshot(tester, 'calendar-320-scale-2');
        // UI-06：48px 触控格在 320 宽放不下整周，仍保留横向滚动；360 宽
        // 收紧边距后整周可见（见下面 width 360 断言）。
        final horizontal = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        expect(horizontal, findsOneWidget);
        await tester.drag(horizontal, const Offset(-200, 0));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        final calendarContent = find.text('已选 2026-10-04');
        await Scrollable.ensureVisible(
          tester.element(calendarContent),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(calendarContent.hitTestable(), findsOneWidget);
        await screenshot(tester, 'calendar-scrolled-320-scale-2');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await checkContrast(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(dateLabel('2026-10-02'), findsOneWidget);
        await openManualLedgerDate(tester);
        await tester.enterText(find.byType(TextField), '2026-02-30');
        await tester.tap(find.text('确认日期'));
        await tester.pumpAndSettle();
        expect(find.text('请输入有效日期 YYYY-MM-DD。'), findsOneWidget);
        await screenshot(tester, 'manual-error-320-scale-2');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await checkContrast(tester);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(dateLabel('2026-10-02'), findsOneWidget);
        await selectLedgerDate(tester, '10000-01-01');
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(dateLabel('10000-01-01'), findsOneWidget);
        await selectLedgerDate(tester, '-0001-12-31');
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(dateLabel('-0001-12-31'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
