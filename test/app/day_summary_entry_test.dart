import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import 'support/checked_sleep_opening.dart';

void main() {
  testWidgets(
    'bootstrap opens summary, follows today and excludes preserved draft',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      var clock = DateTime(2026, 9, 30, 12);
      final context = RecordingDraftContext.newEntry(
        date: CivilDate(year: 2026, month: 9, day: 30),
      );
      await tester.runAsync(
        () => drafts.save(
          RecordingDraft(
            context: context,
            title: '只在草稿',
            startedAt: DateTime(2026, 9, 30, 10).millisecondsSinceEpoch,
            endedAt: DateTime(2026, 9, 30, 11).millisecondsSinceEpoch,
            startPrecision: TimePrecision.exact,
            endPrecision: TimePrecision.exact,
            knowledgeState: BlockKnowledgeState.known,
          ),
        ),
      );
      await tester.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 30)),
          now: () => clock,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开基础摘要'));
      await tester.pumpAndSettle();
      expect(find.text('基础摘要'), findsOneWidget);
      expect(find.text('此账本窗口及醒来日期尚无正式记录。'), findsOneWidget);
      expect(find.text('日期：2026-09-30'), findsOneWidget);
      expect(find.text('已交代：0 分钟'), findsOneWidget);
      expect(find.text('其中未知：0 分钟'), findsOneWidget);
      expect(find.text('尚未记录：720 分钟'), findsOneWidget);
      expect(find.text('只在草稿'), findsNothing);
      clock = DateTime(2026, 10, 1, 0, 1);
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('日期：2026-10-01'), findsOneWidget);
      expect(
        (await tester.runAsync(() => drafts.read(context)))!.title,
        '只在草稿',
      );
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ),
        isEmpty,
      );
      final sleep = (await tester.runAsync(
        () => DriftLedgerRepository(db).createSleepSession(
          id: '00000000-0000-4000-8000-000000000001',
          startedAt: DateTime(2026, 9, 30, 23).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          now: 1,
        ),
      ))!;
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('摘要已读取。'), findsOneWidget);
      expect(find.text('此账本窗口及醒来日期尚无正式记录。'), findsNothing);
      expect(find.text('已交代：0 分钟'), findsOneWidget);
      expect(find.text('尚未记录：1 分钟'), findsOneWidget);
      await tester.runAsync(
        () => DriftLedgerRepository(db).createTimeBlock(
          id: '00000000-0000-4000-8000-000000000002',
          startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 1, 0, 0, 20).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.unknown,
          now: 2,
        ),
      );
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      expect(find.text('已交代：约少于 1 分钟'), findsOneWidget);
      expect(find.text('其中未知：约少于 1 分钟'), findsOneWidget);
      expect(find.text('尚未记录：约1 分钟'), findsOneWidget);
      expect(
        (await tester.runAsync(() => drafts.read(context)))!.title,
        '只在草稿',
      );
      final reread = (await tester.runAsync(
        () => DriftLedgerRepository(db).readSleepSession(sleep.id),
      ))!;
      expect(reread.startedAt, sleep.startedAt);
      expect(reread.endedAt, sleep.endedAt);
      expect(reread.startPrecision, TimePrecision.approximate);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    },
  );
}
