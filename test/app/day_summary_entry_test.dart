import '../support/root_navigation.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
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
          openSleepDrafts: emptyLegacySleepDrafts,
          openReviewDrafts: emptyLegacyReviewDrafts,
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 30)),
          now: () => clock,
        ),
      );
      await tester.pumpAndSettle();
      await tapRootAction(tester, '打开基础摘要');
      await tester.pumpAndSettle();
      expect(find.text('当日摘要'), findsOneWidget);
      expect(find.text('此账本窗口及醒来日期尚无正式记录。'), findsOneWidget);
      expect(find.text('9月30日'), findsOneWidget);
      expect(find.textContaining('已交代 0 分钟'), findsOneWidget);
      expect(find.textContaining('尚未记录 12 小时'), findsOneWidget);
      expect(find.text('只在草稿'), findsNothing);
      // 进入后独立管理日期；应用恢复是它的重读路径，不跟随午夜改写所选日。
      clock = DateTime(2026, 10, 1, 0, 1);
      resumeSummary(tester);
      await tester.pumpAndSettle();
      expect(find.text('9月30日'), findsOneWidget);
      expect(find.textContaining('尚未记录 24 小时'), findsOneWidget);
      await tester.runAsync(
        () => DriftLedgerRepository(db).createTimeBlock(
          id: '00000000-0000-4000-8000-000000000002',
          startedAt: DateTime(2026, 9, 30, 10).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 30, 11).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '上午的事',
          now: 2,
        ),
      );
      resumeSummary(tester);
      await tester.pumpAndSettle();
      expect(find.text('此账本窗口及醒来日期尚无正式记录。'), findsNothing);
      expect(find.textContaining('已交代 1 小时'), findsOneWidget);
      expect(find.textContaining('尚未记录 23 小时'), findsOneWidget);
      // 旧版草稿在启动时已被清除，摘要不展示草稿内容。
      expect(find.text('只在草稿'), findsNothing);
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ))!,
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
    },
  );
}

void resumeSummary(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}
