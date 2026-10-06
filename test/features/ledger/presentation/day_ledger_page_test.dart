import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_overview.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_day_header.dart';
import 'package:time_pet_ledger/features/ledger/presentation/ledger_date_header.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_date_dialog.dart';

import '../../../support/ledger_date_selection.dart';

import 'day_ledger_controller_test.dart' show emptyFacts;

Finder dateLabel(String date) => find.byWidgetPredicate(
  (w) =>
      (w is LedgerDateHeader && ledgerDateText(w.date) == date) ||
      (w is HomeDateTitle && ledgerDateText(w.date) == date),
);
Finder dateMode(bool following) => find.byWidgetPredicate(
  (w) => w is LedgerDateHeader && w.followToday == following,
);
Future<void> refresh(WidgetTester t) async {
  await t.tap(find.byTooltip('更多'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text('刷新账本'));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> today(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('ledger-date-picker')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text('今天'));
}

void main() {
  testWidgets(
    'calendar cancel does not apply; picked today stays fixed until Today restores following',
    (tester) async {
      var instant = DateTime(2026, 9, 30, 23, 59).millisecondsSinceEpoch;
      var reads = 0;
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: DayLedgerLoader(
              resolveDate: resolveDeviceRecordingDate,
              readFacts: (_) async {
                reads++;
                return emptyFacts();
              },
            ),
            now: () => instant,
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ledger-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('29'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(dateMode(true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ledger-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认日期'));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(dateMode(false), findsOneWidget);
      instant = DateTime(2026, 10, 1, 0, 1).millisecondsSinceEpoch;
      await refresh(tester);
      await tester.pumpAndSettle();
      expect(dateLabel('2026-09-30'), findsOneWidget);
      expect(dateMode(false), findsOneWidget);
      await today(tester);
      await tester.pumpAndSettle();
      expect(dateLabel('2026-10-01'), findsOneWidget);
      expect(find.text('截至 00:01'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ledger-date-picker')));
      await tester.pumpAndSettle();
      instant = DateTime(2026, 10, 2, 0, 1).millisecondsSinceEpoch;
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(dateLabel('2026-10-02'), findsOneWidget);
      expect(dateMode(true), findsOneWidget);
      await selectLedgerDate(tester, '2000-03-01');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('前一天'));
      await tester.pumpAndSettle();
      expect(dateLabel('2000-02-29'), findsOneWidget);
      await tester.tap(find.byTooltip('后一天'));
      await tester.pumpAndSettle();
      expect(dateLabel('2000-03-01'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh clears old header values through loading and failure before retry',
    (tester) async {
      final requests = <Completer<DayLedgerFacts>>[];
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: DayLedgerLoader(
              resolveDate: resolveDeviceRecordingDate,
              readFacts: (_) {
                final request = Completer<DayLedgerFacts>();
                requests.add(request);
                return request.future;
              },
            ),
            now: () => DateTime(2026, 10, 3, 12).millisecondsSinceEpoch,
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
          ),
        ),
      );
      requests[0].complete(emptyFacts());
      await tester.pumpAndSettle();
      expect(find.text('已交代'), findsOneWidget);
      expect(find.text('截至 12:00'), findsOneWidget);
      await refresh(tester);
      await tester.pump();
      expect(find.byType(DayLedgerOverview), findsNothing);
      expect(find.text('截至 12:00'), findsNothing);
      requests[1].completeError(StateError('private SQL'));
      await tester.pump();
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.byType(DayLedgerOverview), findsNothing);
      expect(find.text('已交代'), findsNothing);
      expect(find.textContaining('private SQL'), findsNothing);
      await tester.tap(find.text('重试读取'));
      await tester.pump();
      requests[2].complete(emptyFacts());
      await tester.pumpAndSettle();
      expect(find.text('已交代'), findsOneWidget);
    },
  );
  testWidgets(
    'loading, empty, failure and retry are distinct; fast selection rejects old response',
    (tester) async {
      final requests = <Completer<DayLedgerFacts>>[];
      final loader = DayLedgerLoader(
        resolveDate: resolveDeviceRecordingDate,
        readFacts: (_) {
          final pending = Completer<DayLedgerFacts>();
          requests.add(pending);
          return pending.future;
        },
      );
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: loader,
            now: () => DateTime(2026, 9, 30, 12).millisecondsSinceEpoch,
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      requests[0].completeError(StateError('SQL SECRET'));
      await tester.pump();
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.textContaining('SQL SECRET'), findsNothing);
      expect(find.text('此账本窗口尚无正式记录。'), findsNothing);
      await tester.tap(find.text('重试读取'));
      await tester.pump();
      requests[1].complete(emptyFacts());
      await tester.pump();
      expect(find.text('此账本窗口尚无正式记录。'), findsNothing);
      await selectLedgerDate(tester, '2026-09-28');
      await tester.pump();
      await selectLedgerDate(tester, '2026-10-01');
      await tester.pump();
      requests[3].complete(emptyFacts());
      await tester.pump();
      requests[2].complete(emptyFacts());
      await tester.pump();
      expect(dateLabel('2026-10-01'), findsOneWidget);
      expect(dateLabel('2026-09-28'), findsNothing);
      await openManualLedgerDate(tester);
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.tap(find.text('确认日期'));
      await tester.pump();
      expect(find.text('请输入有效日期 YYYY-MM-DD。'), findsOneWidget);
      expect(requests, hasLength(4));
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(dateLabel('2026-10-01'), findsOneWidget);
    },
  );

  testWidgets(
    'return, resume, refresh and today reacquire context across midnight',
    (tester) async {
      var instant = DateTime(2026, 9, 30, 23, 59).millisecondsSinceEpoch;
      var reads = 0;
      final loader = DayLedgerLoader(
        resolveDate: resolveDeviceRecordingDate,
        readFacts: (_) async {
          reads++;
          return emptyFacts();
        },
      );
      final observer = RouteObserver<ModalRoute<void>>();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: loader,
            now: () => instant,
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(dateLabel('2026-09-30'), findsOneWidget);
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('other page')),
        ),
      );
      await tester.pumpAndSettle();
      instant = DateTime(2026, 10, 1, 0, 1).millisecondsSinceEpoch;
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(dateLabel('2026-10-01'), findsOneWidget);
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 3);
      await refresh(tester);
      await tester.pumpAndSettle();
      expect(reads, 4);
      await selectLedgerDate(tester, '2026-09-29');
      await tester.pumpAndSettle();
      await today(tester);
      await tester.pumpAndSettle();
      expect(dateLabel('2026-10-01'), findsOneWidget);
    },
  );
}
