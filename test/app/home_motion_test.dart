import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_value_transition.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

import '../support/home_feed.dart';
import 'home_feed_flow_test.dart' show openLedger, mountHome, oct1, oct2, at;

Finder get feedMotion => find.byKey(const ValueKey('home-timeline-transition'));
Finder get feedSlides =>
    find.descendant(of: feedMotion, matching: find.byType(SlideTransition));

void main() {
  testWidgets(
    'date transition never publishes intermediate dates, retains old projection and isolates exits',
    (tester) async {
      final db = await openLedger(tester);
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: at(3, 9),
      );
      final observed = <Object>[];
      shell.feed.addListener(() => observed.add(shell.feed.focusDate));
      final semantics = tester.ensureSemantics();
      try {
        await shell.openDate(oct1);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(homeDateTitle(tester), '10月1日');
          expect(coverageText(tester, '已交代'), '8 小时 20 分钟');
        }
        final tabs = tester
            .widgetList<HomeTimelineTab>(find.byType(HomeTimelineTab))
            .toList();
        expect(tabs, hasLength(2));
        expect(tabs.first.frame.endDate, oct2);
        expect(tabs.first.frame.viewFor(oct2)!.segments, isNotEmpty);
        expect(tabs.last.frame.endDate, oct1);
        final positions = tester
            .widgetList<SlideTransition>(feedSlides)
            .map((slide) => slide.position.value.dx.abs());
        expect(positions, hasLength(2));
        expect(positions, everyElement(allOf(greaterThan(0), lessThan(1))));
        expect(find.text('十月二日活动').hitTestable(), findsNothing);
        final labels = <String>[];
        void visit(SemanticsNode node) {
          labels.add(node.label);
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(tester.getSemantics(find.byType(HomeShell)));
        expect(labels.where((label) => label.contains('十月二日活动')), isEmpty);
        expect(labels.where((label) => label.contains('十月一日活动')), isNotEmpty);
        final targetState = tester.state<HomeTimelineTabState>(
          find.byType(HomeTimelineTab).last,
        );
        expect(targetState.readingPosition!.instant, at(1, 0));
        expect(targetState.readingPosition!.relativeY, closeTo(8, 1));
        await tester.pumpAndSettle();
        expect(observed, [oct1]);
        expect(find.byType(HomeTimelineTab), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'next and previous days move in the requested direction and never leave a blank layer',
    (tester) async {
      final db = await openLedger(tester);
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct1,
        now: at(3, 9),
      );
      for (final (date, direction) in [(oct2, 1), (oct1, -1)]) {
        await shell.openDate(date);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final tabs = find.byType(HomeTimelineTab);
          final first = tester.getRect(tabs.first);
          final last = tester.getRect(tabs.last);
          expect(
            direction > 0 ? first.right : last.right,
            closeTo(direction > 0 ? last.left : first.left, 1),
          );
        }
        final slides = tester
            .widgetList<SlideTransition>(
              find.descendant(
                of: feedMotion,
                matching: find.byType(SlideTransition),
              ),
            )
            .toList();
        expect(slides, hasLength(2));
        expect(slides.last.position.value.dx * direction, greaterThan(0));
        expect(slides.first.position.value.dx * direction, lessThan(0));
        await tester.pumpAndSettle();
        expect(shell.feed.focusDate, date);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh preserves timeline state and same-value text stays opaque',
    (tester) async {
      final db = await openLedger(tester);
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: at(3, 9),
      );
      await tester.drag(find.byType(HomeTimelineTab), const Offset(0, -35));
      await tester.pumpAndSettle();
      final state = tester.state<HomeTimelineTabState>(
        find.byType(HomeTimelineTab),
      );
      final scroll = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(HomeTimelineTab),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final offset = scroll.pixels;
      await shell.refresh();
      await tester.pump();
      expect(
        tester.state<HomeTimelineTabState>(find.byType(HomeTimelineTab)),
        same(state),
      );
      final valueFades = find.descendant(
        of: find.byType(HomeValueTransition),
        matching: find.byType(FadeTransition),
      );
      expect(
        tester
            .widgetList<FadeTransition>(valueFades)
            .map((fade) => fade.opacity.value),
        everyElement(1),
      );
      await tester.pumpAndSettle();
      expect(scroll.pixels, closeTo(offset, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick reversal before layout and during motion keeps the latest date',
    (tester) async {
      final db = await openLedger(tester);
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: at(3, 9),
      );
      await shell.openDate(oct1);
      await tester.pump();
      await shell.openDate(oct2);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(homeDateTitle(tester), '10月2日');
      expect(find.byType(HomeTimelineTab), findsOneWidget);
      await shell.openDate(oct1);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await shell.openDate(oct2);
      await tester.pumpAndSettle();
      expect(homeDateTitle(tester), '10月2日');
      expect(coverageText(tester, '已交代'), '1 小时');
      expect(find.byType(HomeTimelineTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion settles without advancing animation time', (
    tester,
  ) async {
    final db = await openLedger(tester);
    final shell = await mountHome(
      tester,
      db,
      initialDate: oct2,
      now: at(3, 9),
      disableAnimations: true,
    );
    await shell.openDate(oct1);
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(homeDateTitle(tester), '10月1日');
    expect(find.byType(HomeTimelineTab), findsOneWidget);
    expect(
      tester
          .widgetList<SlideTransition>(
            find.descendant(
              of: feedMotion,
              matching: find.byType(SlideTransition),
            ),
          )
          .single
          .position
          .value,
      Offset.zero,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-year motion remains stable at 320 with large text', (
    tester,
  ) async {
    final db = await openLedger(tester);
    final shell = await mountHome(tester, db, initialDate: oct2, now: at(3, 9));
    tester.view.physicalSize = const Size(320, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    for (final date in [
      CivilDate(year: 2025, month: 12, day: 31),
      CivilDate(year: 2026, month: 1, day: 1),
    ]) {
      await shell.openDate(date);
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(shell.feed.focusDate, date);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.byType(HomeTimelineTab), findsOneWidget);
    }
  });
}
