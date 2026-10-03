import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/sleep_summary.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';

import '../features/ledger/presentation/sleep_form_test.dart'
    show tapText, enter;

void main() {
  testWidgets(
    'assembled app saves one cross-day fact, clears file draft and updates summaries/coverage for both days and nap',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('sleep_submit_'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/drafts.sqlite');
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final ordinary = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      var nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      final context = SleepDraftContext.newEntry(
        date: CivilDate(year: 2026, month: 9, day: 29),
      );
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => ordinary,
          openSleepDrafts: () async => nextStore,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '查看记录');
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      await tapText(tester, '记录睡眠');
      await tapText(tester, '主睡眠');
      await enter(tester, 'sleep-start', '2026-09-28 23:50');
      await enter(tester, 'sleep-end', '2026-09-29 07:40');
      await tapText(tester, '入睡大约');
      await tapText(tester, '醒来准确');
      await tapText(tester, '确认并保存到账本');
      expect(find.text('已交代 460 分钟'), findsOneWidget);
      expect(find.text('待补记 260 分钟'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('约470 分钟'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('约470 分钟'), findsOneWidget);
      expect(
        find.text('约2026-09-28 23:50 → 2026-09-29 07:40 · 完整时长 约470 分钟'),
        findsOneWidget,
      );
      expect(find.text('尚未记录小睡'), findsOneWidget);
      final rows = (await tester.runAsync(
        () => db.customSelect('SELECT * FROM sleep_sessions').get(),
      ))!;
      expect(rows, hasLength(1));
      expect(
        rows.single.data['started_at'],
        DateTime(2026, 9, 28, 23, 50).millisecondsSinceEpoch,
      );
      nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      expect(await tester.runAsync(() => nextStore.read(context)), isNull);
      await tapText(tester, '记录睡眠');
      await tapText(tester, '小睡');
      await enter(tester, 'sleep-start', '2026-09-29 07:40');
      await enter(tester, 'sleep-end', '2026-09-29 08:00');
      await tapText(tester, '入睡准确');
      await tapText(tester, '醒来准确');
      await tapText(tester, '确认并保存到账本');
      expect(find.text('已交代 480 分钟'), findsOneWidget);
      expect(find.text('待补记 240 分钟'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('20 分钟'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('20 分钟'), findsOneWidget);
      expect(
        find.text('2026-09-29 07:40 → 2026-09-29 08:00 · 完整时长 20 分钟'),
        findsOneWidget,
      );
      expect(find.text('尚未记录小睡'), findsNothing);
      for (final table in [
        'time_blocks',
        'rhythm_annotations',
        'goals',
        'daily_reviews',
      ]) {
        expect(
          await tester.runAsync(
            () => db.customSelect('SELECT * FROM $table').get(),
          ),
          isEmpty,
        );
      }
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM sleep_sessions').get(),
        ),
        hasLength(2),
      );
      final verify = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      expect(await tester.runAsync(() => verify.read(context)), isNull);
      await tester.runAsync(verify.close);
      final dateField = find.widgetWithText(TextField, '查看日期');
      await tester.ensureVisible(dateField);
      await tester.enterText(dateField, '2026-09-28');
      await tester.pumpAndSettle();
      await tapText(tester, '查看记录');
      expect(find.text('已交代 约10 分钟'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'summary displays every complete main sleep and nap, including sub-minute duration without calling it missing',
    (tester) async {
      final day = DateTime(2026, 9, 29).millisecondsSinceEpoch;
      SleepSession sleep(
        int id,
        int start,
        int end,
        SleepType type,
        TimePrecision startPrecision,
      ) => SleepSession(
        id: '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
        startedAt: start,
        endedAt: end,
        startPrecision: startPrecision,
        endPrecision: TimePrecision.exact,
        type: type,
        createdAt: 1,
        updatedAt: 1,
      );
      final summary = projectSleepSummary(
        sleepSessions: [
          sleep(
            1,
            day - 3600000,
            day,
            SleepType.mainSleep,
            TimePrecision.exact,
          ),
          sleep(
            2,
            day + 3600000,
            day + 7200000,
            SleepType.mainSleep,
            TimePrecision.approximate,
          ),
          sleep(
            3,
            day + 7200000,
            day + 7200001,
            SleepType.nap,
            TimePrecision.exact,
          ),
        ],
        dayStartedAt: day,
        nextDayStartedAt: DateTime(2026, 9, 30).millisecondsSinceEpoch,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SleepSummaryView(summary: summary)),
        ),
      );
      expect(find.text('约120 分钟'), findsOneWidget);
      expect(find.text('少于 1 分钟'), findsOneWidget);
      expect(find.textContaining('完整时长'), findsNWidgets(3));
      expect(find.textContaining('尚未记录'), findsNothing);
      expect(
        find.textContaining('2026-09-28 23:00 → 2026-09-29 00:00'),
        findsOneWidget,
      );
    },
  );
}
