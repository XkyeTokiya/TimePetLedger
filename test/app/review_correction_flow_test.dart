import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 重新整理：更新下一步、身份与创建时间保持、缺失来源与归档目标拒绝。
void main() {
  Future<void> enterReflow(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settleNative(t);
  }

  Future<void> finish(WidgetTester t) async {
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
  }

  testWidgets('reflow updates the next step and keeps identity and createdAt', (
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
    await enterReflow(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '改后的第一步');
    await settleNative(t);
    await finish(t);
    expect(find.text('今天的回顾已保存。'), findsOneWidget);

    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(h.date),
    );
    expect(review!.id, flowId(500));
    expect(review.createdAt, 10);
    expect(review.tomorrowFirstStep.text, '改后的第一步');
    final rows = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
    );
    expect(rows!.length, 1);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('missing source reports and does not recreate', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    final created = await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        now: 10,
      ),
    );
    await h.openPage(t);
    await enterReflow(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '改后的一步');
    await settleNative(t);
    await t.runAsync(() => DriftReviewRepository(h.db).delete(created!.id));
    await finish(t);
    expect(find.text('这份复盘已不存在，请刷新后重试。'), findsOneWidget);
    expect(
      await t.runAsync(() => DriftReviewRepository(h.db).findByDate(h.date)),
      isNull,
    );
    final rows = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
    );
    expect(rows, isEmpty);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('reflow retains an archived goal reference (Q-006)', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    final goal = await t.runAsync(
      () => h.goals.create(id: flowId(600), name: '会归档的目标', now: 1),
    );
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '原来的下一步',
        tomorrowFirstStepGoalId: goal!.id,
        now: 10,
      ),
    );
    await t.runAsync(() => h.goals.archive(id: goal!.id, now: 3));
    await h.openPage(t);
    await enterReflow(t);
    await h.toStepThree(t);
    expect(find.text('目标：已归档'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '改后的一步');
    await settleNative(t);
    await finish(t);
    expect(find.text('今天的回顾已保存。'), findsOneWidget);
    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(h.date),
    );
    expect(review!.tomorrowFirstStep.text, '改后的一步');
    expect(review.tomorrowFirstStep.goalId, goal!.id);
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
