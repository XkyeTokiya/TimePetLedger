import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/navigation/ledger_shell.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import '../features/ledger/presentation/day_ledger_overview_layout_test.dart'
    show mixedFacts;

void main() {
  testWidgets('confirmed home sample, details and mobile text matrix', (
    t,
  ) async {
    final fontPath = Platform.environment['HOME_FONT'];
    if (fontPath != null) {
      await t.runAsync(() async {
        await (FontLoader(
              'HomeCapture',
            )..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView)))
            .load();
      });
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetPadding);
    const captureKey = ValueKey('home-sample');
    Future<void> capture(String name) async {
      final directory = Platform.environment['HOME_CAPTURE'];
      if (directory == null) return;
      await t.runAsync(() async {
        final image = await t
            .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File('$directory/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final width in [360.0, 320.0, 412.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        t.view.physicalSize = Size(width, 800);
        final routes = RouteObserver<ModalRoute<void>>();
        await t.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: fontPath == null
                ? timeLedgerTheme
                : timeLedgerTheme.copyWith(
                    textTheme: timeLedgerTheme.textTheme.apply(
                      fontFamily: 'HomeCapture',
                    ),
                  ),
            navigatorObservers: [routes],
            builder: (context, child) => RepaintBoundary(
              key: captureKey,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: LedgerShell(
              reviewSelected: false,
              busy: false,
              onLedger: () {},
              onReview: () {},
              onCreate: () {},
              onMore: () {},
              body: DayLedgerPage(
                embedded: true,
                loader: DayLedgerLoader(
                  resolveDate: resolveDeviceRecordingDate,
                  readFacts: (_) async {
                    final facts = mixedFacts();
                    final original = facts.ledger.windowFacts;
                    final unknown = original.timeBlocks.firstWhere(
                      (b) => b.knowledgeState == BlockKnowledgeState.unknown,
                    );
                    return DayLedgerFacts(
                      goals: facts.goals,
                      ledger: SleepLedgerSnapshot(
                        windowFacts: LedgerSnapshot(
                          timeBlocks: [
                            for (final b in original.timeBlocks)
                              if (b != unknown)
                                b
                              else
                                TimeBlock(
                                  id: b.id,
                                  startedAt: b.startedAt,
                                  endedAt: b.endedAt,
                                  startPrecision: TimePrecision.exact,
                                  endPrecision: TimePrecision.exact,
                                  knowledgeState: BlockKnowledgeState.unknown,
                                  createdAt: b.createdAt,
                                  updatedAt: b.updatedAt,
                                ),
                          ],
                          sleepSessions: original.sleepSessions,
                          annotations: original.annotations.where(
                            (a) => a.timeBlockId != unknown.id,
                          ),
                        ),
                        sleepSummaryCandidates: original.sleepSessions,
                      ),
                    );
                  },
                ),
                now: () => DateTime(2026, 10, 4, 9, 41).millisecondsSinceEpoch,
                dateOfInstant: deviceDateOfInstant,
                routeObserver: routes,
                initialDate: CivilDate(year: 2026, month: 10, day: 2),
                completeSleep: (_, summary) =>
                    SleepSummaryView(summary: summary),
                factEntry: (_, _) => const Scaffold(body: Text('原事实编辑入口')),
                gapEntry: (_, _) => const Scaffold(body: Text('原Gap入口')),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text('日账本已读取。'), findsNothing);
        expect(find.byTooltip('更正完整记录'), findsNothing);
        if (width == 360 && scale == 1) {
          await capture('home-360');
        }
        await t.ensureVisible(find.byType(LedgerFactTimelineTile).first);
        await t.pumpAndSettle();
        await t.tap(find.byType(LedgerFactTimelineTile).first);
        await t.pumpAndSettle();
        expect(find.text('完整睡眠'), findsOneWidget);
        expect(find.text('约10月1日 23:40'), findsOneWidget);
        expect(find.text('00:00–07:20'), findsOneWidget);
        expect(find.text('原事实编辑入口'), findsNothing);
        expect(t.takeException(), isNull);
        if (width == 360 && scale == 1) {
          await capture('sleep-details-360');
        }
        await t.tap(find.text('编辑完整记录'));
        await t.pumpAndSettle();
        expect(find.text('原事实编辑入口'), findsOneWidget);
      }
    }
  });
}
