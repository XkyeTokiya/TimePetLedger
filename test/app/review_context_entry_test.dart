import '../support/ledger_date_selection.dart';
import '../support/root_navigation.dart';

import 'dart:async';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';

import '../features/review/application/review_context_loader_test.dart'
    show ReviewReadTrace, reviewId;
import '../features/review/presentation/review_context_controller_test.dart'
    show contextFor;
import 'support/checked_sleep_opening.dart';

const goalId = '00000000-0000-4000-8000-000000000001';
const blockId = '00000000-0000-4000-8000-000000000002';

Future<void> tapText(WidgetTester t, String text) async {
  if (await tapRootAction(t, text)) {
    return;
  }
  final finder = find.text(text);
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'direct bootstrap review entry, absent vs failed retry, stored historical text and archived reference survive fact refresh',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final trace = ReviewReadTrace();
      final db = (await t.runAsync(
        () => AppDatabase.open(NativeDatabase.memory().interceptWith(trace)),
      ))!;
      final drafts = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final clock = DateTime(2026, 10, 2, 12);
      final historical = CivilDate(year: 2025, month: 12, day: 31);
      await t.runAsync(() async {
        final goals = DriftGoalRepository(db);
        await goals.create(id: goalId, name: '历史目标', now: 1);
        await DriftReviewRepository(db).create(
          id: reviewId,
          date: historical,
          tomorrowFirstStepText: '用户亲自填写的第一步',
          summary: '原概述',
          reflection: '原反思\n保留段落',
          tomorrowFirstStepGoalId: goalId,
          now: 2,
        );
        await goals.archive(id: goalId, now: 3);
      });
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          openSleepOpenings: () => openCheckedSleepOpening(clock),
          now: () => clock,
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, '打开按日复盘');
      expect(find.text('日账本'), findsOneWidget);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(find.text('未填写反思'), findsNothing);
      expect(find.text('明天第一步'), findsNothing);
      expect(find.text('原反思\n保留段落'), findsNothing);
      expect(find.text('当天事实上下文：2026-10-02'), findsOneWidget);
      trace.enabled = true;
      trace.failTable = 'daily_reviews';
      await tapText(t, '刷新复盘上下文');
      expect(find.text('复盘上下文读取失败，请重试。'), findsOneWidget);
      expect(find.text('这一天尚无复盘。'), findsNothing);
      expect(find.textContaining('private SQL'), findsNothing);
      trace.failTable = null;
      await tapText(t, '重试读取');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await selectLedgerDate(t, '2025-12-31');
      await t.pumpAndSettle();
      expect(find.text('已有复盘'), findsOneWidget);
      expect(find.text('已存复盘日期：2025-12-31'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-01'), findsOneWidget);
      expect(find.text('第一步目标：历史目标（已归档）'), findsOneWidget);
      expect(find.text('原反思\n保留段落'), findsOneWidget);
      final rawBefore = (await t.runAsync(
        () => db.customSelect('SELECT * FROM daily_reviews').get(),
      ))!.single.data;
      await t.runAsync(() async {
        await DriftGoalRepository(db).rename(id: goalId, name: '历史新名字', now: 4);
        await DriftLedgerRepository(db).createTimeBlock(
          id: blockId,
          startedAt: DateTime(2025, 12, 31, 8).millisecondsSinceEpoch,
          endedAt: DateTime(2025, 12, 31, 9).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '当前事实',
          now: 5,
        );
      });
      await tapText(t, '刷新复盘上下文');
      expect(find.text('已交代：1 小时'), findsOneWidget);
      expect(find.text('第一步目标：历史新名字（已归档）'), findsOneWidget);
      expect(find.text('原概述'), findsOneWidget);
      expect(find.text('原反思\n保留段落'), findsOneWidget);
      expect(
        (await t.runAsync(
          () => db.customSelect('SELECT * FROM daily_reviews').get(),
        ))!.single.data,
        rawBefore,
      );
      await openManualLedgerDate(t);
      await t.enterText(find.widgetWithText(TextField, '账本日期'), '2025-02-30');
      await t.tap(find.text('确认日期'));
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      expect(find.text('请输入有效日期 YYYY-MM-DD。'), findsOneWidget);
      expect(find.text('已有复盘'), findsOneWidget);
      await tapText(t, '取消');
      await tapText(t, '今天');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
    },
  );

  testWidgets(
    'fast date entry suppresses stale success/failure and failed reads can be retried',
    (t) async {
      final requests =
          <({CivilDate date, Completer<ReviewContext> response})>[];
      final date = CivilDate(year: 2024, month: 2, day: 29);
      await t.pumpWidget(
        MaterialApp(
          home: ReviewContextPage(
            loader: ReviewContextLoader(
              readContext: ({required date, required now}) {
                final response = Completer<ReviewContext>();
                requests.add((date: date, response: response));
                return response.future;
              },
            ),
            now: () => DateTime(2026, 10, 2).millisecondsSinceEpoch,
            dateOfInstant: deviceDateOfInstant,
            initialDate: date,
            routeObserver: RouteObserver<ModalRoute<void>>(),
          ),
        ),
      );
      await t.pump();
      await selectLedgerDate(t, '2025-12-31');
      await t.pump();
      requests[1].response.complete(
        contextFor(requests[1].date, existing: true),
      );
      await t.pumpAndSettle();
      requests[0].response.complete(contextFor(date));
      await t.pumpAndSettle();
      expect(find.text('已存复盘日期：2025-12-31'), findsOneWidget);
      expect(find.text('下一自然日：2026-01-01'), findsOneWidget);
      expect(find.text('未填写概述'), findsOneWidget);
      expect(find.text('未填写反思'), findsOneWidget);
      await selectLedgerDate(t, '2024-02-29');
      await t.pump();
      await selectLedgerDate(t, '2024-03-01');
      await t.pump();
      requests[3].response.complete(contextFor(requests[3].date));
      await t.pumpAndSettle();
      requests[2].response.completeError(StateError('stale failure'));
      await t.pumpAndSettle();
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(find.text('复盘上下文读取失败，请重试。'), findsNothing);
      await t.ensureVisible(find.text('刷新复盘上下文'));
      await t.tap(find.text('刷新复盘上下文'));
      await t.pump();
      requests[4].response.completeError(StateError('current failure'));
      await t.pumpAndSettle();
      expect(find.text('复盘上下文读取失败，请重试。'), findsOneWidget);
      await t.tap(find.text('重试读取'));
      await t.pump();
      requests[5].response.complete(
        contextFor(requests[5].date, existing: true),
      );
      await t.pumpAndSettle();
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      expect(find.text('已存复盘日期：2024-03-01'), findsOneWidget);
      expect(find.text('下一自然日：2024-03-02'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
