import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 提交路径：完成向导、空下一步、重复提交保护、冲突与真实存储失败。
void main() {
  Future<int> rowCount(WidgetTester t, ReviewFlowHarness h) async =>
      (await t.runAsync(
        () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
      ))!.length;

  testWidgets('wizard completes a review and Detail shows the next step', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    expect(find.text('整理今天'), findsOneWidget);

    await h.toStepThree(t);
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '明天先写五分钟',
    );
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);

    expect(find.text('今天的回顾已保存。'), findsOneWidget);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    expect(find.text('明天先写五分钟'), findsOneWidget);
    expect(await rowCount(t, h), 1);
    expect(h.drafts.count, 0);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('finish with an empty next step stays on step 3', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(find.text('写下下次的第一步，再完成今天的回顾。'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-next-step')), findsOneWidget);
    expect(await rowCount(t, h), 0);
    await h.close(t);
  });

  testWidgets('busy lock rejects a second finish and creates one review', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    late FlakyReviewRepository flaky;
    await h.open(t, wrapReviews: (base) => flaky = FlakyReviewRepository(base));
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '只写一次');
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    flaky.createGate = Completer<void>();
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('review-finish')))
          .onPressed,
      isNull,
    );
    flaky.createGate!.complete();
    await settleNative(t);
    expect(await rowCount(t, h), 1);
    await h.close(t);
  });

  testWidgets('date-occupied conflict retains the wizard input', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '我的第一步');
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '外部第一步',
        now: 2,
      ),
    );
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(find.text('这一天已有另一份复盘，请刷新后重试。'), findsOneWidget);
    expect(await rowCount(t, h), 1);
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settleNative(t);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('review-next-step')))
          .controller!
          .text,
      '我的第一步',
    );
    await h.close(t);
  });

  testWidgets('formal storage failure keeps input; retry creates once', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    late FlakyReviewRepository flaky;
    await h.open(t, wrapReviews: (base) => flaky = FlakyReviewRepository(base));
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '重试的第一步');
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    flaky.failCreate = true;
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(find.text('复盘保存失败，请重试。'), findsOneWidget);
    expect(await rowCount(t, h), 0);
    flaky.failCreate = false;
    await t.pump(const Duration(seconds: 5));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(await rowCount(t, h), 1);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    await h.close(t);
  });

  testWidgets('goal archived after selection rejects the new review', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    final goal = await t.runAsync(
      () => h.goals.create(id: flowId(600), name: '会归档的目标', now: 1),
    );
    await h.openPage(t);
    await h.toStepThree(t);
    await t.tap(find.byKey(const ValueKey('review-next-step-goal')));
    await settleNative(t);
    await t.tap(find.byKey(ValueKey('progress-goal-option-${goal!.id}')));
    await settleNative(t);
    await t.runAsync(() => h.goals.archive(id: goal.id, now: 3));
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '用归档目标的第一步',
    );
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(find.text('所选目标已不可用，请重新选择。'), findsOneWidget);
    expect(await rowCount(t, h), 0);
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
