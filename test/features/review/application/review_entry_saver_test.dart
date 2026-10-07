import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/application/review_entry_saver.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/review_repository.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import '../data/review_draft_store_test.dart' show mutate;

final reviewDate = CivilDate(year: 2025, month: 12, day: 31);
final draftContext = ReviewDraftContext.newEntry(date: reviewDate);
const goalId = '00000000-0000-4000-8000-000000000001';

ReviewDraft input({
  ReviewDraftContext? context,
  CivilDate? date,
  String? summary,
  String? reflection,
  String? step = '  打开\n\n  设计图😀  ',
  String? goal,
}) => ReviewDraft(
  context: context ?? draftContext,
  date: date ?? reviewDate,
  summary: summary,
  reflection: reflection,
  tomorrowFirstStepText: step,
  tomorrowFirstStepGoalId: goal,
);

/// Counts create attempts while every authoritative operation uses real SQLite.
class TracedReviews implements ReviewRepository {
  TracedReviews(this.inner);
  final ReviewRepository inner;
  int creates = 0;
  Completer<void>? gate;
  @override
  Future<DailyReview?> findByDate(CivilDate date) => inner.findByDate(date);
  @override
  Future<DailyReview> create({
    required String id,
    required CivilDate date,
    required String tomorrowFirstStepText,
    required int now,
    String? summary,
    String? reflection,
    String? tomorrowFirstStepGoalId,
  }) async {
    creates++;
    await gate?.future;
    return inner.create(
      id: id,
      date: date,
      tomorrowFirstStepText: tomorrowFirstStepText,
      now: now,
      summary: summary,
      reflection: reflection,
      tomorrowFirstStepGoalId: tomorrowFirstStepGoalId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ReviewHarness {
  late AppDatabase db;
  late Directory dir;
  late File draftFile;
  late DriftReviewDraftStore drafts;
  late TracedReviews reviews;
  bool failRefresh = false;
  int refreshes = 0;
  int ids = 0;
  int clock = DateTime(2026, 10, 2, 12).millisecondsSinceEpoch;
  late final saver = ReviewEntrySaver(
    repository: reviews,
    drafts: drafts,
    refresh: refresh,
    newId: () =>
        '00000000-0000-4000-8000-${(500 + ++ids).toString().padLeft(12, '0')}',
    now: () => clock,
  );
  Future<void> open() async {
    dir = await Directory.systemTemp.createTemp('review_submit_');
    draftFile = File('${dir.path}/drafts.sqlite');
    db = await AppDatabase.open(NativeDatabase.memory());
    drafts = await DriftReviewDraftStore.open(NativeDatabase(draftFile));
    reviews = TracedReviews(DriftReviewRepository(db));
  }

  Future<ReviewContext> refresh({
    required CivilDate date,
    required int now,
  }) async {
    refreshes++;
    if (failRefresh) throw StateError('private SQL');
    return createReviewContextLoader(db).load(date: date, now: now);
  }

  Future<void> failClear(bool fail) => mutate(
    draftFile,
    (db) => db.customStatement(
      fail
          ? "CREATE TRIGGER fail_clear AFTER DELETE ON review_drafts BEGIN SELECT RAISE(FAIL, 'fault'); END"
          : 'DROP TRIGGER fail_clear',
    ),
  );
  Future<void> failWrite(bool fail) => db.customStatement(
    fail
        ? "CREATE TRIGGER fail_write AFTER INSERT ON daily_reviews BEGIN SELECT RAISE(FAIL, 'private SQL'); END"
        : 'DROP TRIGGER fail_write',
  );
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    await drafts.close();
    await db.close();
    await dir.delete(recursive: true);
  }
}

void main() {
  late ReviewHarness h;
  setUp(() async {
    h = ReviewHarness();
    await h.open();
  });
  tearDown(() => h.close());

  test('success normalizes optional text, preserves paragraphs, rereads actual changed date, clears only original entry key, schema has no derived columns', () async {
    await DriftGoalRepository(h.db).create(id: goalId, name: '活跃目标', now: 1);
    final changed = CivilDate(year: 2024, month: 2, day: 29);
    final other = ReviewDraftContext.newEntry(date: changed);
    await h.drafts.save(input(context: other, step: '另一草稿'));
    final raw = input(
      date: changed,
      summary: ' \n ',
      reflection: '  思考\n\n  段落 😀  ',
      goal: goalId,
    );
    await h.drafts.save(raw);
    final result = await h.saver.submit(raw) as ReviewSubmitCommitted;
    expect(result.complete, true);
    expect(result.review.date, changed);
    expect(
      result.review.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2024, month: 3, day: 1),
    );
    expect(result.review.summary, isNull);
    expect(result.review.reflection, '思考\n\n  段落 😀');
    expect(result.review.tomorrowFirstStep.text, '打开\n\n  设计图😀');
    expect(result.review.createdAt, h.clock);
    expect(result.review.updatedAt, h.clock);
    expect(result.refreshed!.review!.id, result.review.id);
    expect(result.refreshed!.firstStepGoal!.id, goalId);
    expect(
      result.refreshed!.ledger.unresolvedDuration.milliseconds,
      greaterThan(0),
    );
    expect(await h.drafts.read(draftContext), isNull);
    expect((await h.drafts.read(other))!.tomorrowFirstStepText, '另一草稿');
    expect(await h.reviews.findByDate(reviewDate), isNull);
    final columns = await h.db
        .customSelect('PRAGMA table_info(daily_reviews)')
        .get();
    expect(columns.map((c) => c.data['name']), [
      'id',
      'review_date',
      'summary',
      'reflection',
      'tomorrow_first_step_text',
      'tomorrow_first_step_goal_id',
      'created_at',
      'updated_at',
    ]);
    expect(h.reviews.creates, 1);
  });

  test('failed final draft save blocks create, preserves current input and disk snapshot, then retry writes latest content', () async {
    final model = ReviewFormController(
      context: draftContext,
      store: h.drafts,
      entrySaver: h.saver,
    );
    await model.initialize();
    model.setFirstStep('正式下一步');
    await model.flush();
    await mutate(
      h.draftFile,
      (db) => db.customStatement(
        "CREATE TRIGGER fail_save AFTER UPDATE ON review_drafts BEGIN SELECT RAISE(FAIL, 'fault'); END",
      ),
    );
    model.setReflection('  新的\n\n  反思😀  ');
    expect(await model.submit(), isNull);
    expect(model.submitError, contains('本次填写尚未保留成功'));
    expect(model.reflection, '  新的\n\n  反思😀  ');
    expect(h.reviews.creates, 0);
    expect((await h.drafts.read(draftContext))!.reflection, '');
    await mutate(
      h.draftFile,
      (db) => db.customStatement('DROP TRIGGER fail_save'),
    );
    expect(await model.retrySave(), true);
    expect(await model.submit(), isNotNull);
    expect(
      (await h.reviews.findByDate(reviewDate))!.reflection,
      '新的\n\n  反思😀',
    );
    expect(h.reviews.creates, 1);
    model.dispose();
  });

  test('two real concurrent creates compete by current date without overwriting or clearing loser draft', () async {
    final other = ReviewDraftContext.newEntry(
      date: CivilDate(year: 2026, month: 1, day: 2),
    );
    final a = input(step: '竞争 A');
    final b = input(context: other, step: '竞争 B');
    await h.drafts.save(a);
    await h.drafts.save(b);
    final results = await Future.wait([h.saver.submit(a), h.saver.submit(b)]);
    final winner = results.whereType<ReviewSubmitCommitted>().single;
    expect(
      results.whereType<ReviewSubmitFailed>().single.reason,
      ReviewSubmitFailure.dateOccupied,
    );
    expect(
      (await h.db.customSelect('SELECT * FROM daily_reviews').get()).length,
      1,
    );
    expect((await h.reviews.findByDate(reviewDate))!.id, winner.review.id);
    final loser = winner.review.tomorrowFirstStep.text == '竞争 A'
        ? other
        : draftContext;
    expect(await h.drafts.read(loser), isNotNull);
    expect(h.reviews.creates, 2);
  });

  test('current Goal archive/delete after selection rejects formal create and preserves raw draft', () async {
    final goals = DriftGoalRepository(h.db);
    await goals.create(id: goalId, name: '选后归档', now: 1);
    final raw = input(goal: goalId);
    await h.drafts.save(raw);
    await goals.archive(id: goalId, now: 2);
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.invalidGoal,
    );
    await goals.delete(id: goalId, now: 3); // Unreferenced: physical deletion.
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.invalidGoal,
    );
    expect(await h.reviews.findByDate(reviewDate), isNull);
    expect(
      (await h.drafts.read(draftContext))!.tomorrowFirstStepGoalId,
      goalId,
    );
  });

  test('blank and 2001-rune text rejected by real repository; 2000-rune Unicode input allowed', () async {
    for (final raw in [
      input(step: ' \n '),
      input(step: '😀' * 2001),
      input(summary: '😀' * 2001),
      input(reflection: '😀' * 2001),
    ]) {
      await h.drafts.save(raw);
      expect(
        (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
        ReviewSubmitFailure.invalidInput,
      );
      expect(await h.reviews.findByDate(reviewDate), isNull);
      expect(
        (await h.drafts.read(draftContext))!.tomorrowFirstStepText,
        raw.tomorrowFirstStepText,
      );
    }
    final valid = input(
      step: ' ${'😀' * 2000} ',
      summary: ' ',
      reflection: null,
    );
    await h.drafts.save(valid);
    final result = await h.saver.submit(valid) as ReviewSubmitCommitted;
    expect(result.complete, true);
    expect(result.review.tomorrowFirstStep.text.runes.length, 2000);
    expect(result.review.reflection, isNull);
  });

  test('real SQL insert fault rolls back formal row and retains draft; retry creates once successfully', () async {
    final raw = input();
    await h.drafts.save(raw);
    await h.failWrite(true);
    expect(
      (await h.saver.submit(raw) as ReviewSubmitFailed).reason,
      ReviewSubmitFailure.storage,
    );
    expect(await h.reviews.findByDate(reviewDate), isNull);
    expect(await h.drafts.read(draftContext), isNotNull);
    await h.failWrite(false);
    expect((await h.saver.submit(raw) as ReviewSubmitCommitted).complete, true);
    expect(
      (await h.db.customSelect('SELECT * FROM daily_reviews').get()).length,
      1,
    );
  });

  test('commit with real cleanup and refresh failures retries only finalization, retaining ID/timestamps and one create', () async {
    final raw = input();
    await h.drafts.save(raw);
    await h.failClear(true);
    h.failRefresh = true;
    final saved = await h.saver.submit(raw) as ReviewSubmitCommitted;
    expect(saved.complete, false);
    expect(saved.draftCleared, false);
    expect(saved.refreshed, isNull);
    expect((await h.reviews.findByDate(reviewDate))!.id, saved.review.id);
    expect(await h.drafts.read(draftContext), isNotNull);
    h.clock++;
    await h.failClear(false);
    final readFailed = await h.saver.finishCommitted(
      context: draftContext,
      review: saved.review,
      draftCleared: saved.draftCleared,
    );
    expect(readFailed.draftCleared, true);
    expect(readFailed.refreshed, isNull);
    h.failRefresh = false;
    final complete = await h.saver.finishCommitted(
      context: draftContext,
      review: saved.review,
      draftCleared: readFailed.draftCleared,
    );
    expect(complete.complete, true);
    expect(complete.refreshed!.review!.createdAt, saved.review.createdAt);
    expect(complete.refreshed!.review!.updatedAt, saved.review.updatedAt);
    expect(h.reviews.creates, 1);
  });

  test('reopened residual draft matches every normalized field before finalization; mismatch retains it without create', () async {
    final raw = input(summary: '  概述  ', reflection: ' \n ');
    await h.drafts.save(raw);
    await h.failClear(true);
    final saved = await h.saver.submit(raw) as ReviewSubmitCommitted;
    await h.drafts.close();
    h.drafts = await DriftReviewDraftStore.open(NativeDatabase(h.draftFile));
    final reopenedSaver = ReviewEntrySaver(
      repository: h.reviews,
      drafts: h.drafts,
      refresh: h.refresh,
      newId: () => throw StateError('must not create'),
      now: () => h.clock,
    );
    for (final mismatched in [
      input(summary: '不同', reflection: ' '),
      input(summary: '概述', reflection: '不同'),
      input(summary: '概述', step: '不同'),
      input(summary: '概述', goal: goalId),
      input(summary: '概述', step: '😀' * 2001),
    ]) {
      expect(await reopenedSaver.recoverCommittedDraft(mismatched), isNull);
    }
    expect(await h.drafts.read(draftContext), isNotNull);
    await h.failClear(false);
    final recovered = await reopenedSaver.recoverCommittedDraft(
      (await h.drafts.read(draftContext))!,
    );
    expect(recovered!.complete, true);
    expect(recovered.review.id, saved.review.id);
    expect(h.reviews.creates, 1);
  });

  test('controller locks repeat clicks/input/discard while create waits; post-commit retry cannot call create', () async {
    final model = ReviewFormController(
      context: draftContext,
      store: h.drafts,
      entrySaver: h.saver,
    );
    await model.initialize();
    model.setFirstStep('用户下一步');
    await model.flush();
    h.reviews.gate = Completer<void>();
    await h.failClear(true);
    final first = model.submit();
    while (h.reviews.creates == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(model.editable, false);
    expect(await model.submit(), isNull);
    expect(await model.discard(), false);
    expect(await model.leave(), false);
    model.setFirstStep('不能改');
    h.reviews.gate!.complete();
    expect(await first, isNull);
    expect(model.committed, isNotNull);
    expect(model.firstStep, '用户下一步');
    expect(await model.submit(), isNull);
    expect(await model.discard(), false);
    expect(model.committedMessage, contains('本地收尾失败'));
    await h.failClear(false);
    expect(await model.retryFinish(), isNotNull);
    expect(h.reviews.creates, 1);
    model.dispose();
  });

  test('null readback never claims completion or offers create again; only later identity-matched read finishes', () async {
    final raw = input();
    await h.drafts.save(raw);
    final loader = createReviewContextLoader(h.db);
    final saver = ReviewEntrySaver(
      repository: h.reviews,
      drafts: h.drafts,
      refresh: ({required date, required now}) =>
          loader.load(date: CivilDate(year: 2026, month: 1, day: 1), now: now),
      newId: () => '00000000-0000-4000-8000-000000000077',
      now: () => h.clock,
    );
    final result = await saver.submit(raw) as ReviewSubmitCommitted;
    expect(result.draftCleared, true);
    expect(result.refreshed, isNull);
    final finished = await h.saver.finishCommitted(
      context: draftContext,
      review: result.review,
      draftCleared: true,
    );
    expect(finished.complete, true);
    expect(h.reviews.creates, 1);
  });
}
