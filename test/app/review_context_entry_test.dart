import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 入口与读取：向导 / Detail 分流、读取失败重试、归档目标引用。
void main() {
  testWidgets('no review opens the wizard; a stored review opens Detail', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    expect(find.text('整理今天'), findsOneWidget);
    await h.close(t);

    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '已存的下一步',
        now: 2,
      ),
    );
    await h.openPage(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    expect(find.text('已存的下一步'), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('read failure shows retry and recovers', (t) async {
    final h = ReviewFlowHarness();
    var fail = true;
    await h.open(
      t,
      wrapLoader: (base) => ReviewContextLoader(
        readContext: ({required date, required now}) {
          if (fail) throw StateError('private SQL');
          return base.load(date: date, now: now);
        },
      ),
    );
    await h.openPage(t);
    expect(find.text('复盘读取失败，请重试。'), findsOneWidget);
    fail = false;
    await t.tap(find.text('重试'));
    await settleNative(t);
    expect(find.text('整理今天'), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('archived next-step goal shows as 已归档 in the wizard', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    final goal = await t.runAsync(
      () => h.goals.create(id: flowId(600), name: '会归档的目标', now: 1),
    );
    await t.runAsync(
      () => DriftReviewRepository(h.db).create(
        id: flowId(500),
        date: h.date,
        tomorrowFirstStepText: '继续写',
        tomorrowFirstStepGoalId: goal!.id,
        now: 2,
      ),
    );
    await t.runAsync(() => h.goals.archive(id: goal!.id, now: 3));

    await h.openPage(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settleNative(t);
    await h.toStepThree(t);
    expect(find.text('目标：已归档'), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
