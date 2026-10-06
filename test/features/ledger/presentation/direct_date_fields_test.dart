import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';

import '../../review/presentation/review_context_controller_test.dart'
    show contextFor;
import 'day_ledger_controller_test.dart' show emptyFacts;

void main() {
  final original = CivilDate(year: 2026, month: 12, day: 31);
  final chosen = CivilDate(year: 2027, month: 1, day: 1);
  for (final summary in [true, false]) {
    testWidgets(
      '${summary ? 'summary' : 'review context'} date directly opens calendar, cancels unchanged and confirms selected year/day',
      (t) async {
        final reads = <CivilDate>[];
        final routes = RouteObserver<ModalRoute<void>>();
        final now = DateTime(2027, 1, 2, 12).millisecondsSinceEpoch;
        final page = summary
            ? DaySummaryPage(
                loader: DayLedgerLoader(
                  resolveDate: resolveDeviceRecordingDate,
                  readFacts: (context) async {
                    reads.add(context.window.date);
                    return emptyFacts();
                  },
                ),
                initialDate: original,
                now: () => now,
                dateOfInstant: deviceDateOfInstant,
                routeObserver: routes,
              )
            : ReviewContextPage(
                loader: ReviewContextLoader(
                  readContext: ({required date, required now}) async {
                    reads.add(date);
                    return contextFor(date);
                  },
                ),
                initialDate: original,
                now: () => now,
                dateOfInstant: deviceDateOfInstant,
                routeObserver: routes,
              );
        await t.pumpWidget(
          MaterialApp(
            theme: homeTheme,
            navigatorObservers: [routes],
            home: page,
          ),
        );
        await t.pumpAndSettle();
        final count = reads.length;
        final field = find.byKey(
          ValueKey(summary ? 'summary-date' : 'review-context-date'),
        );
        await t.tap(field);
        await t.pumpAndSettle();
        expect(find.text('2026年12月'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(reads.length, count);
        await t.tap(find.byTooltip('下个月'));
        await t.pumpAndSettle();
        await t.tap(find.text('1').last);
        await t.tap(find.text('取消'));
        await t.pumpAndSettle();
        // 日历关闭后可刷新事实；取消不切换所选日期。
        expect(reads.every((date) => date == original), isTrue);
        await t.tap(field);
        await t.pumpAndSettle();
        expect(find.text('2026年12月'), findsOneWidget);
        await t.tap(find.byTooltip('下个月'));
        await t.pumpAndSettle();
        await t.tap(find.text('1').last);
        await t.tap(find.text('确认日期'));
        await t.pumpAndSettle();
        expect(reads.last, chosen);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('2027-01-01'), findsOneWidget);
      },
    );
  }
}
