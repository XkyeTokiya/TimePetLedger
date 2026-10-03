import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/review/application/review_entry_saver.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import 'review_entry_saver_test.dart';

const sourceId = '00000000-0000-4000-8000-000000000020';
const replacementId = '00000000-0000-4000-8000-000000000021';
const otherGoalId = '00000000-0000-4000-8000-000000000022';
final editContext = ReviewDraftContext.edit(reviewId: sourceId);

/// All constraints and writes use real SQLite; count and delay only the call.
class CorrectionReviews extends TracedReviews {
  CorrectionReviews(super.inner);
  int updates = 0;
  Completer<void>? updateGate;
  @override
  Future<DailyReview> update({
    required String id,
    required int now,
    CivilDate? date,
    ({String? value})? summary,
    ({String? value})? reflection,
    String? tomorrowFirstStepText,
    ({String? value})? tomorrowFirstStepGoalId,
  }) async {
    updates++;
    await updateGate?.future;
    return inner.update(
      id: id,
      now: now,
      date: date,
      summary: summary,
      reflection: reflection,
      tomorrowFirstStepText: tomorrowFirstStepText,
      tomorrowFirstStepGoalId: tomorrowFirstStepGoalId,
    );
  }
}

class CorrectionHarness extends ReviewHarness {
  late CorrectionReviews traced;
  late File formalFile;
  @override
  Future<void> open() async {
    await super.open();
    await db.close();
    formalFile = File('${dir.path}/formal.sqlite');
    db = await AppDatabase.open(NativeDatabase(formalFile));
    reviews = traced = CorrectionReviews(DriftReviewRepository(db));
  }

  Future<void> reopen() async {
    await drafts.close();
    await db.close();
    drafts = await DriftReviewDraftStore.open(NativeDatabase(draftFile));
    db = await AppDatabase.open(NativeDatabase(formalFile));
    reviews = traced = CorrectionReviews(DriftReviewRepository(db));
  }
}

Future<DailyReview> seedReview(CorrectionHarness h, {String? goal}) =>
    h.traced.inner.create(
      id: sourceId,
      date: reviewDate,
      summary: '原概述',
      reflection: '原反思',
      tomorrowFirstStepText: '原下一步',
      tomorrowFirstStepGoalId: goal,
      now: 10,
    );

ReviewDraft correction({
  CivilDate? date,
  String? summary = '原概述',
  String? reflection = '原反思',
  String? step = '原下一步',
  String? goal,
}) => input(
  context: editContext,
  date: date,
  summary: summary,
  reflection: reflection,
  step: step,
  goal: goal,
);

Future<List<Map<String, dynamic>>> rows(CorrectionHarness h) async =>
    (await h.db.customSelect('SELECT * FROM daily_reviews ORDER BY id').get())
        .map((row) => row.data)
        .toList();

void main() {
  late CorrectionHarness h;
  setUp(() async {
    h = CorrectionHarness();
    await h.open();
  });
  tearDown(() => h.close());

  test('changed leap date preserves source identity and creation time, rereads new date, clears only edit key', () async {
    final original = await seedReview(h);
    final unrelated = ReviewDraftContext.edit(reviewId: replacementId);
    await h.drafts.save(input(context: unrelated, step: '另一编辑草稿'));
    await h.drafts.save(input(step: '另一新建草稿'));
    final date = CivilDate(year: 2024, month: 2, day: 29);
    final raw = correction(date: date, reflection: '  新反思\n\n  内部段落😀  ');
    await h.drafts.save(raw);
    final result = await h.saver.submit(raw) as ReviewSubmitCommitted;
    expect(result.complete, true);
    expect(result.review.id, original.id);
    expect(result.review.createdAt, 10);
    expect(result.review.updatedAt, h.clock);
    expect(result.review.reflection, '新反思\n\n  内部段落😀');
    expect(
      result.review.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2024, month: 3, day: 1),
    );
    expect(await h.reviews.findByDate(reviewDate), isNull);
    expect(result.refreshed!.review!.id, sourceId);
    expect(result.refreshed!.ledger.date, date);
    expect(await h.drafts.read(editContext), isNull);
    expect(await h.drafts.read(unrelated), isNotNull);
    expect(await h.drafts.read(draftContext), isNotNull);
    expect((await rows(h)).length, 1);
    expect(h.traced.updates, 1);
    expect(h.traced.creates, 0);
    expect(h.ids, 0);
    for (final table in [
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'goals',
    ]) {
      expect(await h.db.customSelect('SELECT * FROM $table').get(), isEmpty);
    }
    expect(
      (await h.db.customSelect('PRAGMA table_info(daily_reviews)').get())
          .length,
      8,
    );
  });

  test(
    'normalized no-change save does not issue SQL UPDATE and keeps updatedAt',
    () async {
      await seedReview(h);
      final raw = correction(
        summary: '  原概述  ',
        reflection: ' 原反思 ',
        step: '\n原下一步\n',
      );
      await h.drafts.save(raw);
      await h.db.customStatement(
        "CREATE TRIGGER no_update BEFORE UPDATE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'must not update'); END",
      );
      final result = await h.saver.submit(raw) as ReviewSubmitCommitted;
      expect(result.complete, true);
      expect(result.review.createdAt, 10);
      expect(result.review.updatedAt, 10);
      expect(h.traced.updates, 1);
      expect(h.traced.creates, 0);
      expect(await h.drafts.read(editContext), isNull);
    },
  );

  test(
    'invalid edit text rejects all fields and retains incomplete raw draft',
    () async {
      await seedReview(h);
      final before = await rows(h);
      final long = List.filled(2001, '😀').join();
      for (final raw in [
        correction(step: '  \n '),
        correction(summary: long),
        correction(reflection: long),
        correction(step: long),
      ]) {
        await h.drafts.save(raw);
        expect(
          (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
          ReviewSubmitFailure.invalidInput,
        );
        expect(await rows(h), before);
        final saved = (await h.drafts.read(editContext))!;
        expect(saved.summary, raw.summary);
        expect(saved.reflection, raw.reflection);
        expect(saved.tomorrowFirstStepText, raw.tomorrowFirstStepText);
      }
      expect(h.traced.creates, 0);
    },
  );

  test('date acquired after edit read rejects whole update and keeps both reviews and raw draft', () async {
    await seedReview(h);
    final date = CivilDate(year: 2024, month: 2, day: 29);
    final raw = correction(date: date, summary: '  不得部分保存  ', reflection: null);
    await h.drafts.save(raw);
    await h.traced.inner.create(
      id: replacementId,
      date: date,
      tomorrowFirstStepText: '竞争者',
      now: 20,
    );
    final before = await rows(h);
    final result = await h.saver.submit(raw) as ReviewSubmitFailed;
    expect(result.reason, ReviewSubmitFailure.dateOccupied);
    expect(await rows(h), before);
    final restored = (await h.drafts.read(editContext))!;
    expect(restored.summary, raw.summary);
    expect(restored.date, date);
    expect(restored.reflection, isNull);
    expect(h.traced.creates, 0);
  });

  test('retained archived Goal allowed, new archive/delete rejected, optional text and Goal explicitly clear', () async {
    final goals = DriftGoalRepository(h.db);
    await goals.create(id: goalId, name: '原目标', now: 1);
    await goals.create(id: otherGoalId, name: '新目标', now: 2);
    await seedReview(h, goal: goalId);
    await goals.archive(id: goalId, now: 3);
    final retained = correction(goal: goalId, step: '保留归档原引用');
    await h.drafts.save(retained);
    expect(
      (await h.saver.submit(
        retained,
      ) as ReviewSubmitCommitted).review.tomorrowFirstStep.goalId,
      goalId,
    );
    final raw = correction(goal: otherGoalId, summary: '  未保存文字  ');
    await h.drafts.save(raw);
    final before = await rows(h);
    await goals.archive(id: otherGoalId, now: 4);
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.invalidGoal,
    );
    await goals.delete(id: otherGoalId, now: 5);
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.invalidGoal,
    );
    expect(await rows(h), before);
    expect(
      (await h.drafts.read(editContext))!.tomorrowFirstStepGoalId,
      otherGoalId,
    );
    final cleared = correction(
      summary: '  \n ',
      reflection: null,
      step: '保留下一步',
    );
    await h.drafts.save(cleared);
    final result = await h.saver.submit(cleared) as ReviewSubmitCommitted;
    expect(result.review.summary, isNull);
    expect(result.review.reflection, isNull);
    expect(result.review.tomorrowFirstStep.goalId, isNull);
    expect(result.review.createdAt, 10);
    expect(h.traced.creates, 0);
  });

  test('deleted source with another same-date review cannot be retargeted or recreated', () async {
    final original = await seedReview(h);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: h.saver,
    );
    await model.initialize();
    model.setReflection('  我的更正\n保留  ');
    await model.flush();
    await h.traced.inner.delete(sourceId);
    await h.traced.inner.create(
      id: replacementId,
      date: reviewDate,
      tomorrowFirstStepText: '其他身份',
      now: 30,
    );
    final before = await rows(h);
    expect(await model.submit(), isNull);
    expect(model.submitError, contains('原复盘已不存在'));
    expect(model.editable, true);
    expect((await h.drafts.read(editContext))!.reflection, model.reflection);
    expect(await rows(h), before);
    expect(h.traced.creates, 0);
    expect(h.ids, 0);
    model.dispose();
  });

  test('real update fault rolls back every field and preserves draft; user retry updates same ID', () async {
    await seedReview(h);
    final raw = correction(
      date: CivilDate(year: 2024, month: 2, day: 29),
      summary: null,
      reflection: '  新文字  ',
      step: '新下一步',
    );
    await h.drafts.save(raw);
    final before = await rows(h);
    await h.db.customStatement(
      "CREATE TRIGGER fail_update AFTER UPDATE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'private SQL'); END",
    );
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.storage,
    );
    expect(await rows(h), before);
    expect((await h.drafts.read(editContext))!.reflection, raw.reflection);
    await h.db.customStatement('DROP TRIGGER fail_update');
    final result = await h.saver.submit(raw) as ReviewSubmitCommitted;
    expect(result.complete, true);
    expect(result.review.id, sourceId);
    expect((await rows(h)).length, 1);
    expect(h.traced.updates, 2);
    expect(h.traced.creates, 0);
  });

  test('real file edit draft reopen preserves clears/date and does not modify source before submission', () async {
    await seedReview(h);
    final raw = correction(
      date: CivilDate(year: 2024, month: 2, day: 29),
      summary: '',
      reflection: null,
      step: '  恢复的下一步  ',
    );
    await h.drafts.save(raw);
    await h.reopen();
    final original = (await h.reviews.findByDate(reviewDate))!;
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: h.saver,
    );
    await model.initialize();
    expect(model.restored, true);
    expect(model.date, raw.date);
    expect(model.summary, '');
    expect(model.reflection, '');
    expect(model.firstStep, raw.tomorrowFirstStepText);
    expect(model.committed, isNull);
    expect((await h.reviews.findByDate(reviewDate))!.reflection, '原反思');
    expect(await h.drafts.read(editContext), isNotNull);
    final result = await model.submit();
    expect(result!.review!.id, sourceId);
    expect(await h.reviews.findByDate(reviewDate), isNull);
    expect(result.review!.summary, isNull);
    expect(result.review!.reflection, isNull);
    expect(h.traced.updates, 1);
    expect(h.traced.creates, 0);
    model.dispose();
  });

  test('duplicate edit clicks freeze input; post-commit clear/read retries never update again', () async {
    final original = await seedReview(h);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: h.saver,
    );
    await model.initialize();
    model.setReflection('已提交更正');
    await model.flush();
    await h.failClear(true);
    h.failRefresh = true;
    h.traced.updateGate = Completer<void>();
    final first = model.submit();
    expect(await model.submit(), isNull);
    model.setReflection('不得覆盖');
    expect(model.reflection, '已提交更正');
    expect(await model.discard(), false);
    expect(await model.leave(), false);
    await Future<void>.delayed(Duration.zero);
    h.traced.updateGate!.complete();
    expect(await first, isNull);
    expect(model.committedMessage, contains('草稿清理和读回失败'));
    final committedAt = model.committed!.review.updatedAt;
    await h.failClear(false);
    h.clock += 1000;
    expect(await model.retryFinish(), isNull);
    expect(model.committed!.draftCleared, true);
    h.failRefresh = false;
    expect(await model.retryFinish(), isNotNull);
    expect((await h.reviews.findByDate(reviewDate))!.updatedAt, committedAt);
    expect(h.traced.updates, 1);
    expect(h.traced.creates, 0);
    expect(await h.drafts.read(editContext), isNull);
    model.dispose();
  });
}
