import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:time_pet_ledger/app/bootstrap/sleep_entry.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/session_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';

final sleepContext = SleepDraftContext.newEntry(
  date: CivilDate(year: 2026, month: 9, day: 29),
);

void main() {
  testWidgets('same-session re-entry asks before restoring sleep input', (
    tester,
  ) async {
    final store = SessionSleepDraftStore();
    Widget host() => MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SleepEntry(
                  context: sleepContext,
                  store: store,
                  loadSuggestion: () async => const DirectTimeSuggestion(
                    RecordingTimeInput(startedAt: 1000, endedAt: 2000),
                  ),
                ),
              ),
            ),
            child: const Text('记录睡眠'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(host());
    await tester.tap(find.text('记录睡眠'));
    await tester.pumpAndSettle();
    final first = tester
        .widget<SleepRecordingPage>(find.byType(SleepRecordingPage))
        .controller;
    first.setNote('保留备注');
    await tester.runAsync(first.flush);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('记录睡眠'));
    await tester.pumpAndSettle();
    expect(find.text('继续上次填写？'), findsOneWidget);
    final second = tester
        .widget<SleepRecordingPage>(find.byType(SleepRecordingPage))
        .controller;
    expect(second.restored, isFalse);
    expect(second.note, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, '继续填写'));
    await tester.pumpAndSettle();
    expect(second.restored, isTrue);
    expect(second.note, '保留备注');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('uses the app-owned session store', (tester) async {
    final store = SessionSleepDraftStore();
    await tester.pumpWidget(
      MaterialApp(
        home: SleepEntry(context: sleepContext, store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SleepRecordingPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
