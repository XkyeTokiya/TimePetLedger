import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import 'review_context_controller_test.dart' show contextFor;
import 'review_form_controller_test.dart'
    show
        MemoryDrafts,
        ReadGoals,
        entry,
        entryDate,
        draftKey,
        originalReview,
        reviewId;

Future<void> tap(WidgetTester t, String text) async {
  if (['保留草稿并返回', '放弃此复盘草稿'].contains(text)) {
    await t.tap(find.byTooltip('更多'));
    await t.pumpAndSettle();
  }
  if (text == '刷新事实上下文' && find.text(text).evaluate().isEmpty) {
    await tap(t, '查看当日事实');
  }
  final finder = find.text(text).last;
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  if (text != '修改日期' && text != '应用日期') await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String key, String value) async {
  if (key == 'review-date') {
    await tap(t, '修改日期');
  }
  if (['review-summary', 'review-reflection'].contains(key) &&
      find.byKey(ValueKey(key)).evaluate().isEmpty) {
    await tap(t, '再写几句 ＋');
  }
  final field = find.byKey(ValueKey(key));
  await t.ensureVisible(field);
  await t.enterText(field, value);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  if (key == 'review-date') {
    await tap(t, '应用日期');
  }
}

Future<void> host(
  WidgetTester t,
  ReviewFormController model,
  ReviewContextLoader loader,
) async {
  await t.binding.setSurfaceSize(const Size(1000, 1800));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ReviewForm(
                  controller: model,
                  loader: loader,
                  now: () => 1,
                  dateOfInstant: (_) => entryDate,
                ),
              ),
            ),
            child: const Text('打开表单'),
          ),
        ),
      ),
    ),
  );
  await tap(t, '打开表单');
}

String fieldText(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

class DuplicateGoals extends ReadGoals {
  @override
  Future<List<Goal>> listActive() async => [
    active,
    Goal.create(
      id: '00000000-0000-4000-8000-000000000003',
      name: active.name,
      now: 1,
    ),
  ];
}

void main() {
  testWidgets(
    'rapid date edits reject late fact successes/failures without changing raw reflection',
    (t) async {
      final store = MemoryDrafts();
      final model = ReviewFormController(context: entry, store: store);
      final pending = <({String date, Completer<ReviewContext> response})>[];
      final loader = ReviewContextLoader(
        readContext: ({required date, required now}) {
          if (pending.isEmpty && date == entryDate) {
            return Future.value(contextFor(date));
          }
          final response = Completer<ReviewContext>();
          pending.add((date: formatReviewDate(date), response: response));
          return response.future;
        },
      );
      await host(t, model, loader);
      await enter(t, 'review-reflection', '用户原文\n😀');
      await enter(t, 'review-date', '2024-02-28');
      await t.pump();
      await enter(t, 'review-date', '2024-02-29');
      await t.pump();
      expect(pending.map((p) => p.date), ['2024-02-28', '2024-02-29']);
      pending.last.response.complete(
        contextFor(parseReviewDate('2024-02-29')!),
      );
      await t.pumpAndSettle();
      pending.first.response.completeError(StateError('old facts failed'));
      await t.pumpAndSettle();
      await tap(t, '查看当日事实');
      expect(find.text('当天事实上下文：2024-02-29'), findsOneWidget);
      expect(find.textContaining('事实上下文读取失败'), findsNothing);
      expect(fieldText(t, 'review-reflection'), '用户原文\n😀');
      await enter(t, 'review-date', '2026-04-30');
      await t.pump();
      await enter(t, 'review-date', '2026-');
      await t.pump();
      pending.last.response.complete(
        contextFor(parseReviewDate('2026-04-30')!),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('当天事实上下文：'), findsNothing);
      expect(find.textContaining('下一自然日：'), findsNothing);
      await tap(t, '保留草稿并返回');
      expect(store.values[draftKey(entry)]!.dateInput, '2026-');
      model.dispose();
    },
  );

  testWidgets(
    'multiline, Unicode boundaries and optional blank text; context refresh/resume never replaces restored input',
    (t) async {
      final store = MemoryDrafts();
      await store.save(
        ReviewDraft(
          context: entry,
          date: entryDate,
          summary: '草稿\n\n段落😀',
          reflection: '  ',
          tomorrowFirstStepText: '',
        ),
      );
      final model = ReviewFormController(context: entry, store: store);
      var reads = 0;
      var fail = false;
      final loader = ReviewContextLoader(
        readContext: ({required date, required now}) async {
          reads++;
          if (fail) throw StateError('facts');
          return contextFor(date, existing: true);
        },
      );
      await host(t, model, loader);
      expect(model.restored, isTrue);
      await tap(t, '再写几句 ＋');
      expect(fieldText(t, 'review-summary'), '草稿\n\n段落😀');
      expect(model.firstStepError, isNotNull);
      expect(find.text('1月1日，先做什么？'), findsOneWidget);
      await enter(t, 'review-step', '  先做\n\n  一件事 😀  ');
      final within = '  ${'😀' * 2000}  ';
      await enter(t, 'review-summary', within);
      expect(model.summaryError, isNull);
      final over = ' ${within.trim()}界 ';
      await enter(t, 'review-summary', over);
      expect(model.summaryError, contains('最多 2000 个 Unicode'));
      expect(fieldText(t, 'review-summary'), over);
      await enter(t, 'review-summary', '  用户改写\n\n内部段落  ');
      fail = true;
      await tap(t, '刷新事实上下文');
      expect(find.textContaining('事实上下文读取失败'), findsOneWidget);
      expect(fieldText(t, 'review-summary'), '  用户改写\n\n内部段落  ');
      fail = false;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(reads, 3);
      expect(fieldText(t, 'review-step'), '  先做\n\n  一件事 😀  ');
      await tap(t, '保留草稿并返回');
      expect(find.byType(ReviewForm), findsNothing);
      expect(store.values[draftKey(entry)]!.summary, '  用户改写\n\n内部段落  ');
      model.dispose();
    },
  );

  testWidgets(
    'date edit, empty step and ordinary system back preserve one raw draft; reopened entry restores changed date',
    (t) async {
      final store = MemoryDrafts();
      final model = ReviewFormController(context: entry, store: store);
      final loader = ReviewContextLoader(
        readContext: ({required date, required now}) async => contextFor(date),
      );
      await host(t, model, loader);
      await enter(t, 'review-date', '2024-02-29');
      expect(find.text('3月1日，先做什么？'), findsOneWidget);
      await enter(t, 'review-reflection', '多行\n\n😀反思');
      await enter(t, 'review-step', ' \n ');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(ReviewForm), findsNothing);
      expect(store.values.length, 1);
      model.dispose();
      final reopened = ReviewFormController(context: entry, store: store);
      await host(t, reopened, loader);
      expect(reopened.dateInput, '2024-02-29');
      await tap(t, '再写几句 ＋');
      expect(fieldText(t, 'review-step'), ' \n ');
      expect(fieldText(t, 'review-reflection'), '多行\n\n😀反思');
      await tap(t, '放弃此复盘草稿');
      expect(store.values, isEmpty);
      reopened.dispose();
    },
  );

  testWidgets(
    'save failure prevents route exit, retry retains input; discard failure remains and retry clears',
    (t) async {
      final store = MemoryDrafts()..failSave = true;
      final model = ReviewFormController(context: entry, store: store);
      await host(
        t,
        model,
        ReviewContextLoader(
          readContext: ({required date, required now}) async =>
              contextFor(date),
        ),
      );
      await enter(t, 'review-reflection', '失败时仍保留\n输入');
      await tap(t, '保留草稿并返回');
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(fieldText(t, 'review-reflection'), '失败时仍保留\n输入');
      expect(find.textContaining('复盘草稿保存失败'), findsOneWidget);
      store.failSave = false;
      await tap(t, '重试保存草稿');
      store.failClear = true;
      await tap(t, '放弃此复盘草稿');
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(find.textContaining('无法放弃复盘草稿'), findsOneWidget);
      expect(fieldText(t, 'review-reflection'), '失败时仍保留\n输入');
      store.failClear = false;
      await tap(t, '放弃此复盘草稿');
      expect(find.byType(ReviewForm), findsNothing);
      expect(store.values, isEmpty);
      model.dispose();
    },
  );

  testWidgets(
    'archived original visible and immutable, active choices show identity, optional association can clear',
    (t) async {
      final store = MemoryDrafts();
      final goals = DuplicateGoals();
      final original = originalReview();
      final model = ReviewFormController(
        context: ReviewDraftContext.edit(reviewId: reviewId),
        store: store,
        original: original,
        originalGoal: goals.old,
        goals: goals,
      );
      await host(
        t,
        model,
        ReviewContextLoader(
          readContext: ({required date, required now}) async =>
              contextFor(date),
        ),
      );
      expect(find.text('下一步目标：同名（已归档）'), findsOneWidget);
      await enter(t, 'review-date', '2026-04-30');
      expect(find.text('5月1日，先做什么？'), findsOneWidget);
      await tap(t, '选择下一步目标');
      expect(find.text(goals.old.id), findsNothing);
      expect(find.text('标识：${goals.active.id}'), findsOneWidget);
      await tap(t, '标识：${goals.active.id}');
      expect(find.text('下一步目标：同名'), findsOneWidget);
      await tap(t, '清空目标关联');
      expect(model.goalId, isNull);
      expect(original.date, entryDate);
      expect(original.tomorrowFirstStep.goalId, goals.old.id);
      await tap(t, '保留草稿并返回');
      model.dispose();
    },
  );
}
