import '../support/review_date_picker.dart';
import '../support/ledger_date_selection.dart';
import '../support/root_navigation.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import '../features/review/data/review_draft_store_test.dart'
    show tempFile, mutate;
import '../features/review/presentation/review_form_controller_test.dart'
    show entryDate, entry, reviewId, goalId, activeId;
import 'support/checked_sleep_opening.dart';

Future<Map<String, Object?>> facts(AppDatabase db) async => {
  for (final table in [
    'goals',
    'time_blocks',
    'rhythm_annotations',
    'sleep_sessions',
    'daily_reviews',
  ])
    table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((row) => row.data)
        .toList(),
};

// Let real NativeDatabase continuations run between fake-async frames.
Future<void> settleNative(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text) async {
  if (text == '刷新事实上下文' && find.text(text).evaluate().isEmpty) {
    await tapText(t, '查看当日事实');
  }
  if (['删除复盘', '返回', '重新填写', '重新编辑', '返回复盘读取'].contains(text) &&
      find.text(text).evaluate().isEmpty) {
    await t.tap(find.byTooltip('更多'));
    await settleNative(t);
  }
  if (await tapRootAction(t, text)) {
    await settleNative(t);
    return;
  }
  final finder = find.text(text).last;
  await t.ensureVisible(finder);
  await t.tap(finder);
  await settleNative(t);
}

void main() {
  test('real file reopen restores edited date by original identity and new drafts by entry date; formal five tables unchanged', () async {
    final file = await tempFile();
    final formal = File('${file.parent.path}/facts.sqlite');
    var db = await AppDatabase.open(NativeDatabase(formal));
    var store = await DriftReviewDraftStore.open(NativeDatabase(file));
    var goals = DriftGoalRepository(db);
    var reviews = DriftReviewRepository(db);
    await goals.create(id: goalId, name: '原目标', now: 1);
    await goals.create(id: activeId, name: '可选目标', now: 1);
    final original = await reviews.create(
      id: reviewId,
      date: entryDate,
      summary: '原概述',
      reflection: '原反思\n保留',
      tomorrowFirstStepText: '原下一步',
      tomorrowFirstStepGoalId: goalId,
      now: 2,
    );
    await goals.archive(id: goalId, now: 3);
    final before = await facts(db);
    final edit = ReviewDraftContext.edit(reviewId: reviewId);
    final model = ReviewFormController(
      context: edit,
      store: store,
      original: original,
      goals: goals,
    );
    await model.initialize();
    expect(model.selectedGoal!.name, '原目标');
    expect(model.activeGoals.map((goal) => goal.id), [activeId]);
    model.setDateInput('2024-02-29');
    model.setSummary('');
    model.setReflection('  编辑\n\n😀段落  ');
    model.setFirstStep(' \n ');
    expect(await model.leave(), true);
    model.dispose();
    final otherEntry = ReviewDraftContext.newEntry(
      date: CivilDate(year: 2024, month: 2, day: 29),
    );
    final other = ReviewFormController(context: otherEntry, store: store);
    await other.initialize();
    other.setSummary('独立新建输入');
    other.setDateInput('2025-12-31');
    expect(await other.leave(), true);
    other.dispose();
    expect(await facts(db), before);
    await store.close();
    await db.close();
    db = await AppDatabase.open(NativeDatabase(formal));
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    goals = DriftGoalRepository(db);
    reviews = DriftReviewRepository(db);
    final reopened = ReviewFormController(
      context: edit,
      store: store,
      original: await reviews.findByDate(entryDate),
      goals: goals,
    );
    await reopened.initialize();
    expect(reopened.dateInput, '2024-02-29');
    expect(reopened.intendedDate, CivilDate(year: 2024, month: 3, day: 1));
    expect(reopened.summary, '');
    expect(reopened.reflection, '  编辑\n\n😀段落  ');
    expect(reopened.firstStep, ' \n ');
    expect(reopened.goalId, goalId);
    expect(await facts(db), before);
    expect((await store.read(otherEntry))!.summary, '独立新建输入');
    expect(await reopened.discard(), true);
    expect(await store.read(edit), isNull);
    expect((await store.read(otherEntry))!.summary, '独立新建输入');
    reopened.dispose();
    await store.close();
    await db.close();
  });

  test('real SQLite draft write/clear failures retain disk and current input, controller retries after removing fault', () async {
    final file = await tempFile();
    final store = await DriftReviewDraftStore.open(NativeDatabase(file));
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    model.setSummary('之前输入');
    await model.flush();
    await mutate(
      file,
      (db) => db.customStatement(
        "CREATE TRIGGER fail_write AFTER UPDATE ON review_drafts BEGIN SELECT RAISE(FAIL, 'fault'); END",
      ),
    );
    model.setSummary('当前输入😀\n仍保留');
    expect(await model.leave(), false);
    expect(model.storageError, isNotNull);
    expect(model.summary, '当前输入😀\n仍保留');
    expect((await store.read(entry))!.summary, '之前输入');
    await mutate(file, (db) => db.customStatement('DROP TRIGGER fail_write'));
    expect(await model.retrySave(), true);
    await mutate(
      file,
      (db) => db.customStatement(
        "CREATE TRIGGER fail_clear AFTER DELETE ON review_drafts BEGIN SELECT RAISE(FAIL, 'fault'); END",
      ),
    );
    expect(await model.discard(), false);
    expect((await store.read(entry))!.summary, '当前输入😀\n仍保留');
    await mutate(file, (db) => db.customStatement('DROP TRIGGER fail_clear'));
    expect(await model.discard(), true);
    model.dispose();
    await store.close();
    final reopened = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect(await reopened.read(entry), isNull);
    await reopened.close();
  });

  testWidgets(
    'bootstrap passes real draft session and Goal reads to form; leave and reopen restores raw input while original review remains unchanged',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final db = (await t.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await t.runAsync(
        () => DriftReviewDraftStore.open(NativeDatabase.memory()),
      ))!;
      final clock = DateTime(2026, 10, 2, 12);
      await t.runAsync(() async {
        await DriftGoalRepository(db).create(id: goalId, name: '旧归档目标', now: 1);
        await DriftReviewRepository(db).create(
          id: reviewId,
          date: entryDate,
          reflection: '已存原反思',
          tomorrowFirstStepText: '已存下一步',
          tomorrowFirstStepGoalId: goalId,
          now: 2,
        );
        await DriftGoalRepository(db).archive(id: goalId, now: 3);
      });
      final before = await t.runAsync(() => facts(db));
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => recording,
          openReviewDrafts: () async => drafts,
          openSleepOpenings: () => openCheckedSleepOpening(clock),
          now: () => clock,
        ),
      );
      await settleNative(t);
      await tapText(t, '打开按日复盘');
      await tapText(t, '填写复盘');
      await tapText(t, '再写几句 ＋');
      await t.enterText(
        find.byKey(const ValueKey('review-reflection')),
        '当天独立草稿',
      );
      await settleNative(t);
      await tapText(t, '返回');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await selectLedgerDate(t, '2025-12-31');
      await settleNative(t);
      await tapText(t, '编辑复盘草稿');
      expect(find.text('下一步目标：旧归档目标（已归档）'), findsOneWidget);
      await tapText(t, '再写几句 ＋');
      await t.enterText(
        find.byKey(const ValueKey('review-reflection')),
        '未提交的\n反思😀',
      );
      await settleNative(t);
      await changeReviewDate(t, '2024-02-29');
      await settleNative(t);
      await tapText(t, '返回');
      expect(find.text('已存原反思'), findsOneWidget);
      await tapText(t, '编辑复盘草稿');
      expect(
        t.widget<ReviewForm>(find.byType(ReviewForm)).controller.restored,
        isTrue,
      );
      expect(
        t.widget<ReviewForm>(find.byType(ReviewForm)).controller.dateInput,
        '2024-02-29',
      );
      await tapText(t, '再写几句 ＋');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-reflection')))
            .controller!
            .text,
        '未提交的\n反思😀',
      );
      expect(await t.runAsync(() => facts(db)), before);
      await t.runAsync(
        () => DriftLedgerRepository(db).createTimeBlock(
          id: '00000000-0000-4000-8000-000000000055',
          startedAt: DateTime(2024, 2, 29, 8).millisecondsSinceEpoch,
          endedAt: DateTime(2024, 2, 29, 9).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '外部事实更正',
          now: 4,
        ),
      );
      await tapText(t, '刷新事实上下文');
      expect(find.text('已交代：1 小时'), findsOneWidget);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-reflection')))
            .controller!
            .text,
        '未提交的\n反思😀',
      );
      expect(
        (await t.runAsync(() => facts(db)))!['daily_reviews'],
        before!['daily_reviews'],
      );
      await tapText(t, '放弃此复盘草稿');
      // UI-17：放弃前先确认。
      await tapText(t, '放弃草稿');
      expect(find.byType(ReviewForm), findsNothing);
      expect(
        await t.runAsync(
          () => drafts.read(ReviewDraftContext.edit(reviewId: reviewId)),
        ),
        isNull,
      );
      expect(
        (await t.runAsync(
          () => drafts.read(
            ReviewDraftContext.newEntry(
              date: CivilDate(year: 2026, month: 10, day: 2),
            ),
          ),
        ))!.reflection,
        '当天独立草稿',
      );
      await t.pumpWidget(const SizedBox());
      await settleNative(t);
      await t.runAsync(() async {
        await drafts.close();
        await recording.close();
        await db.close();
      });
    },
  );
}
