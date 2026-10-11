import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../support/native_flow.dart';
import '../support/review_flow_app.dart';

/// 闭环：整理 → 完成 → Detail → 重新整理 → 删除；事实与解释保留。
void main() {
  Future<void> finish(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('review-next')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-finish')));
    await settleNative(t);
  }

  /// 让保存提示消失，避免遮住底部按钮。
  Future<void> clearToast(WidgetTester t) async {
    await t.pump(const Duration(seconds: 5));
    await settleNative(t);
  }

  Future<void> openReflow(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settleNative(t);
  }

  testWidgets('full loop keeps facts and annotations', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    final goal = await t.runAsync(
      () => h.goals.create(id: flowId(600), name: '闭环目标', now: 1),
    );
    await t.runAsync(() async {
      await h.repo.createTimeBlock(
        id: flowId(12),
        startedAt: h.at(11, 0),
        endedAt: h.at(12, 0),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '推进的记录',
        goalId: goal!.id,
        annotation: AddAnnotation(id: flowId(21), state: RhythmState.progress),
        now: 1,
      );
    });

    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '闭环第一步');
    await settleNative(t);
    await finish(t);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    await clearToast(t);

    await openReflow(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '闭环第二步');
    await settleNative(t);
    await finish(t);
    expect(find.text('今天的回顾已保存。'), findsOneWidget);

    await h.close(t);
    await h.openPage(t);
    expect(find.text('闭环第二步'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-delete')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-delete-confirm')));
    await settleNative(t);

    final reviews = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
    );
    expect(reviews, isEmpty);
    final blocks = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM time_blocks ORDER BY id').get(),
    );
    expect(blocks!.length, 2);
    final annotations = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM rhythm_annotations').get(),
    );
    expect(annotations!.length, 1);
    expect(annotations.single.data['state'], 'progress');
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('leap-day wizard targets March 1', (t) async {
    final h = ReviewFlowHarness(date: CivilDate(year: 2024, month: 2, day: 29));
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '三月第一天');
    await settleNative(t);
    await finish(t);
    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(h.date),
    );
    expect(
      review!.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2024, month: 3, day: 1),
    );
    expect(t.takeException(), isNull);
    await h.close(t);
  });

  testWidgets('overlong next step is rejected and the input stays', (t) async {
    final h = ReviewFlowHarness();
    await h.open(t);
    await h.openPage(t);
    await h.toStepThree(t);
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '😀' * 2001,
    );
    await settleNative(t);
    await finish(t);
    expect(find.text('下一步需要写一句再完成。'), findsOneWidget);
    final rows = await t.runAsync(
      () => h.db.customSelect('SELECT * FROM daily_reviews').get(),
    );
    expect(rows, isEmpty);
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settleNative(t);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('review-next-step')))
          .controller!
          .text
          .runes
          .length,
      2001,
    );
    expect(t.takeException(), isNull);
    await h.close(t);
  });
}
