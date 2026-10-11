import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import '../support/ledger_date_selection.dart';
import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 路由与日期：首页入口继承浏览日期；缺口操作刷新向导时间轴。
void main() {
  final day1 = CivilDate(year: 2026, month: 10, day: 1);

  Future<AppDatabase> openApp(WidgetTester tester, DateTime clock) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final recording = (await tester.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    final sleepDrafts = (await tester.runAsync(
      () => DriftSleepDraftStore.open(NativeDatabase.memory()),
    ))!;
    final openings = (await tester.runAsync(
      () => DriftSleepOpeningStore.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await tester.runAsync(
      () => DriftReviewDraftStore.open(NativeDatabase.memory()),
    ))!;
    final preferences = (await tester.runAsync(
      () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      final repo = DriftLedgerRepository(db);
      await repo.createTimeBlock(
        id: flowId(1),
        startedAt: DateTime(2026, 10, 1, 9).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 1, 10).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '十月一日的活动',
        now: 1,
      );
      await repo.createTimeBlock(
        id: flowId(2),
        startedAt: DateTime(2026, 10, 2, 8).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2, 9).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '十月二日的活动',
        now: 1,
      );
      await DriftReviewRepository(db).create(
        id: flowId(9),
        date: day1,
        tomorrowFirstStepText: '十月的第一步',
        now: 2,
      );
    });
    await tester.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => recording,
        openSleepDrafts: () async => sleepDrafts,
        openSleepOpenings: () async => openings,
        openReviewDrafts: () async => drafts,
        openPreferences: () async => preferences,
        now: () => clock,
      ),
    );
    await settleNative(tester);
    return db;
  }

  testWidgets('review entry inherits the home browsing date', (t) async {
    await openApp(t, DateTime(2026, 10, 2, 20));
    await tapText(t, '打开按日复盘');
    expect(find.text('10月2日'), findsWidgets);
    expect(find.text('整理今天'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('review-back')));
    await settleNative(t);
    await selectLedgerDate(t, '2026-10-01');
    await tapText(t, '打开按日复盘');
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    expect(find.text('十月的第一步'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('marking a gap as unknown refreshes the wizard timeline', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    final gapsBefore = find.text('未记录').evaluate().length;
    expect(gapsBefore, greaterThan(0));
    await t.tap(find.text('想不起来').first);
    await settleNative(t);
    expect(find.text('这段时间已记为想不起来。'), findsOneWidget);
    expect(find.text('未记录').evaluate().length, gapsBefore - 1);
    final blocks = await t.runAsync(
      () => h.db
          .customSelect('SELECT knowledge_state FROM time_blocks ORDER BY id')
          .get(),
    );
    expect(
      blocks!.map((row) => row.data['knowledge_state']).contains('unknown'),
      isTrue,
    );
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
