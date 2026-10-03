import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';

import 'day_ledger_controller_test.dart' show emptyFacts;

void main() {
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
      expect(find.text('此账本窗口尚无正式记录。'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '2026-09-28');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '2026-10-01');
      await tester.pump();
      requests[3].complete(emptyFacts());
      await tester.pump();
      requests[2].complete(emptyFacts());
      await tester.pump();
      expect(find.text('日期：2026-10-01'), findsOneWidget);
      expect(find.text('日期：2026-09-28'), findsNothing);
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump();
      expect(find.text('请输入有效日期 YYYY-MM-DD。'), findsOneWidget);
      expect(find.text('日期：2026-10-01'), findsNothing);
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
      expect(find.text('日期：2026-09-30'), findsOneWidget);
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('other page')),
        ),
      );
      await tester.pumpAndSettle();
      instant = DateTime(2026, 10, 1, 0, 1).millisecondsSinceEpoch;
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('日期：2026-10-01'), findsOneWidget);
      expect(reads, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(reads, 3);
      await tester.tap(find.text('刷新账本'));
      await tester.pumpAndSettle();
      expect(reads, 4);
      await tester.enterText(find.byType(TextField), '2026-09-29');
      await tester.pumpAndSettle();
      await tester.tap(find.text('今天'));
      await tester.pumpAndSettle();
      expect(find.text('日期：2026-10-01'), findsOneWidget);
    },
  );
}
