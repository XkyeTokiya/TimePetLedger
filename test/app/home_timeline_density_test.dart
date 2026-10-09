import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';

void main() {
  testWidgets('14 dense days keep a temporal position through continuous reading', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final date = CivilDate(year: 2026, month: 10, day: 14);
    final watch = Stopwatch()..start();
    await t.pumpWidget(
      MaterialApp(
        theme: homeTheme,
        home: HomeShell(
          ledgerLoader: DayLedgerLoader(
            resolveDate: resolveDeviceRecordingDate,
            readFacts: (context) async => DayLedgerFacts(
              ledger: SleepLedgerSnapshot(
                windowFacts: LedgerSnapshot(
                  timeBlocks: [
                    for (var i = 0; i < 96; i++)
                      TimeBlock(
                        id: '00000000-0000-4000-8000-${(DateTime.fromMillisecondsSinceEpoch(context.dayStartedAt).day * 100 + i).toString().padLeft(12, '0')}',
                        startedAt: context.dayStartedAt + i * 300000,
                        endedAt: context.dayStartedAt + (i + 1) * 300000,
                        startPrecision: TimePrecision.exact,
                        endPrecision: TimePrecision.exact,
                        knowledgeState: i.isEven
                            ? BlockKnowledgeState.known
                            : BlockKnowledgeState.unknown,
                        title: i.isEven ? '短记录$i' : null,
                        createdAt: 1,
                        updatedAt: 1,
                      ),
                  ],
                  sleepSessions: const [],
                  annotations: const [],
                ),
                sleepSummaryCandidates: const [],
              ),
              goals: const [],
            ),
          ),
          now: () => DateTime(2026, 10, 15, 12).millisecondsSinceEpoch,
          dateOfInstant: deviceDateOfInstant,
          initialDate: date,
          busy: false,
          onOpenSummary: (_) {},
          onOpenReview: (_) {},
          onRecordActivity: () {},
          onRecordSleep: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final buildMs = watch.elapsedMilliseconds;
    final shell = t.state<HomeShellState>(find.byType(HomeShell));
    final timeline = t.state<HomeTimelineTabState>(
      find.byType(HomeTimelineTab),
    );
    final before = timeline.readingPosition!.instant;
    final gesture = await t.startGesture(
      t.getCenter(find.byType(HomeTimelineTab)),
    );
    watch.reset();
    for (var i = 0; i < 30; i++) {
      await gesture.moveBy(const Offset(0, -8));
      await t.pump(const Duration(milliseconds: 16));
    }
    final frameMs = watch.elapsedMilliseconds;
    await gesture.up();
    await t.pumpAndSettle();
    expect(shell.feed.focusDate, date);
    expect(timeline.readingPosition!.instant, greaterThan(before));
    expect(t.takeException(), isNull);
    debugPrint(
      'HOME_TIME_DENSITY_DEBUG 14x96 intervals: initial=${buildMs}ms, 30 pointer frames=${frameMs}ms',
    );
  });
}
