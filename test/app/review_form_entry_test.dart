import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/data/session_review_draft_store.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 会话边界：未完成输入只留在会话 store，不写正式表；跨 store 实例不恢复。
void main() {
  testWidgets('unfinished input stays in the session store, not in SQLite', (
    t,
  ) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '未完成的第一步',
    );
    await settleNative(t);
    expect(h.drafts.count, 1);
    final rows = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
    );
    expect(rows, isEmpty);
    final blocks = await t.runAsync(
      () => h.db.customSelect('SELECT title FROM time_blocks').get(),
    );
    expect(blocks!.single.data['title'], '写方案');
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('continue restores the input and completes for real', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '继续完成的第一步',
    );
    await settleNative(t);
    await h.close(t);

    await h.openPage(t);
    expect(find.text('继续上次填写？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-recovery-continue')));
    await settleNative(t);
    await t.tap(find.text('下一步'));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(h.date),
    );
    expect(review!.tomorrowFirstStep.text, '继续完成的第一步');
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('a fresh session store starts empty', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '只在本会话');
    await settleNative(t);
    expect(h.drafts.count, 1);
    await h.close(t);

    // 模拟新的应用会话：进程重启 / 网页刷新后不恢复旧输入。
    h.drafts = SessionReviewDraftStore();
    await h.openPage(t);
    expect(find.text('继续上次填写？'), findsNothing);
    expect(find.text('整理今天'), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
