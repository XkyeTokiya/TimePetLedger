import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 删除：确认 / 取消、失败保留、会话快照清理与事实保留。
void main() {
  Future<int> rowCount(WidgetTester t, ReviewFlowHarness h) async =>
      (await t.runAsync(
        () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
      ))!.length;

  Future<void> openDeleteDialog(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-delete')));
    await settleNative(t);
  }

  testWidgets('delete removes only the review and returns to the wizard', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        now: 10,
      ),
    );
    await h.openPage(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    await openDeleteDialog(t);
    expect(find.text('删除这次回顾？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-delete-confirm')));
    await settleNative(t);
    expect(find.text('已删除这次回顾；当天的记录保留。'), findsOneWidget);
    expect(find.text('整理今天'), findsOneWidget);
    expect(await rowCount(t, h), 0);
    final blocks = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM time_blocks').get(),
    );
    expect(blocks!.length, 1);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('cancel keeps the review', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        now: 10,
      ),
    );
    await h.openPage(t);
    await openDeleteDialog(t);
    await t.tap(find.text('取消'));
    await settleNative(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    expect(await rowCount(t, h), 1);
    await h.close(t);
  });

  testWidgets('delete failure keeps the review; retry succeeds', (t) async {
    final h = ReviewFlowHarness();
    late FlakyReviewRepository flaky;
    await h.open(t, wrapReviews: (base) => flaky = FlakyReviewRepository(base));
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        now: 10,
      ),
    );
    await h.openPage(t);
    await openDeleteDialog(t);
    flaky.failDelete = true;
    await t.tap(find.byKey(const ValueKey('review-delete-confirm')));
    await settleNative(t);
    expect(find.text('删除失败，请重试。'), findsOneWidget);
    expect(await rowCount(t, h), 1);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    flaky.failDelete = false;
    await openDeleteDialog(t);
    await t.tap(find.byKey(const ValueKey('review-delete-confirm')));
    await settleNative(t);
    expect(await rowCount(t, h), 0);
    await h.close(t);
  });

  testWidgets('delete clears the edit session snapshot', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        now: 10,
      ),
    );
    await h.openPage(t);
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settleNative(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '未完成的修改');
    await settleNative(t);
    await h.close(t);
    final editContext = ReviewDraftContext.edit(reviewId: flowId(500));
    expect(await t.runAsync(() => h.drafts.read(editContext)), isNotNull);

    await h.openPage(t);
    await openDeleteDialog(t);
    await t.tap(find.byKey(const ValueKey('review-delete-confirm')));
    await settleNative(t);
    expect(await t.runAsync(() => h.drafts.read(editContext)), isNull);
    await h.close(t);
  });
}
