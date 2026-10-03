import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/review/application/review_entry_saver.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

import '../data/review_draft_store_test.dart' show mutate;
import 'review_correction_saver_test.dart';
import 'review_entry_saver_test.dart'
    show reviewDate, goalId, draftContext, input;

final otherDate = CivilDate(year: 2026, month: 1, day: 1);
final otherEdit = ReviewDraftContext.edit(reviewId: replacementId);
final otherEntry = ReviewDraftContext.newEntry(date: otherDate);

class DeletionReviews extends CorrectionReviews {
  DeletionReviews(super.inner);
  int deletes = 0;
  Completer<void>? deleteGate;
  @override
  Future<void> delete(String id) async {
    deletes++;
    await deleteGate?.future;
    await inner.delete(id);
  }
}

class DeletionHarness extends CorrectionHarness {
  late DeletionReviews deletion;
  @override
  Future<void> open() async {
    await super.open();
    reviews = traced = deletion = DeletionReviews(reviews.inner);
  }

  @override
  Future<void> reopen() async {
    await super.reopen();
    reviews = traced = deletion = DeletionReviews(reviews.inner);
  }
}

ReviewEntrySaver deletionSaver(
  DeletionHarness h, {
  ReviewContextRefresh? refresh,
}) => ReviewEntrySaver(
  repository: h.reviews,
  drafts: h.drafts,
  refresh: refresh ?? h.refresh,
  newId: () => throw StateError('Deletion must not create'),
  now: () => h.clock,
);

Future<Map<String, Object?>> formalFacts(DeletionHarness h) async => {
  for (final table in [
    'goals',
    'time_blocks',
    'sleep_sessions',
    'rhythm_annotations',
    'daily_reviews',
  ])
    table: (await h.db.customSelect('SELECT * FROM $table ORDER BY id').get())
        .map((row) => row.data)
        .toList(),
};

Future<DailyReview> deletionScene(DeletionHarness h) async {
  await DriftGoalRepository(h.db).create(id: goalId, name: '保留目标', now: 1);
  final original = await seedReview(h, goal: goalId);
  await h.traced.inner.create(
    id: replacementId,
    date: otherDate,
    tomorrowFirstStepText: '其他复盘第一步',
    now: 20,
  );
  final start = DateTime(2025, 12, 31, 8).millisecondsSinceEpoch;
  final end = DateTime(2025, 12, 31, 9).millisecondsSinceEpoch;
  await h.db.customStatement(
    "INSERT INTO time_blocks (id,started_at,ended_at,start_precision,end_precision,knowledge_state,title,goal_id,note,created_at,updated_at) VALUES (?, ?, ?, 'exact','exact','known','保留活动',?,'保留备注',1,1)",
    [sourceId, start, end, goalId],
  );
  await h.db.customStatement(
    "INSERT INTO rhythm_annotations (id,time_block_id,state,continuation_hint,created_at,updated_at) VALUES (?,?,'progress','活动接续点保留',1,1)",
    [sourceId, sourceId],
  );
  await h.db.customStatement(
    "INSERT INTO sleep_sessions (id,started_at,ended_at,start_precision,end_precision,sleep_type,note,created_at,updated_at) VALUES (?, ?, ?, 'exact','exact','mainSleep','保留睡眠',1,1)",
    [
      sourceId,
      DateTime(2025, 12, 30, 23).millisecondsSinceEpoch,
      DateTime(2025, 12, 31, 7).millisecondsSinceEpoch,
    ],
  );
  await h.drafts.save(correction(reflection: '  未提交编辑\n\n😀  '));
  await h.drafts.save(input(step: '同日独立新建草稿'));
  await h.drafts.save(
    input(context: otherEntry, date: otherDate, step: '其他日期新建草稿'),
  );
  await h.drafts.save(
    input(context: otherEdit, date: otherDate, step: '其他身份编辑草稿'),
  );
  return original;
}

Future<void> expectOtherDrafts(DeletionHarness h) async {
  expect(
    (await h.drafts.read(draftContext))!.tomorrowFirstStepText,
    '同日独立新建草稿',
  );
  expect((await h.drafts.read(otherEntry))!.tomorrowFirstStepText, '其他日期新建草稿');
  expect((await h.drafts.read(otherEdit))!.tomorrowFirstStepText, '其他身份编辑草稿');
}

Future<void> deleteFault(DeletionHarness h, bool fail) => h.db.customStatement(
  fail
      ? "CREATE TRIGGER fail_delete AFTER DELETE ON daily_reviews BEGIN SELECT RAISE(FAIL, 'private SQL'); END"
      : 'DROP TRIGGER fail_delete',
);

void main() {
  late DeletionHarness h;
  setUp(() async {
    h = DeletionHarness();
    await h.open();
  });
  tearDown(() => h.close());

  test('delete stored source despite invalid edited date/step; only source review/edit key removed, ledger and all other facts unchanged', () async {
    final original = await deletionScene(h);
    final before = await formalFacts(h);
    final ledgerBefore = await h.refresh(date: reviewDate, now: h.clock);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: deletionSaver(h),
    );
    await model.initialize();
    model.setDateInput('未完成日期');
    model.setFirstStep('  ');
    final result = (await model.deleteReview())!;
    expect(model.valid, false);
    expect(result.ledger.date, original.date);
    expect(result.review, isNull);
    final after = await formalFacts(h);
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
    ]) {
      expect(after[table], before[table]);
    }
    expect(
      after['daily_reviews'],
      (before['daily_reviews'] as List<Map<String, dynamic>>)
          .where((row) => row['id'] != sourceId)
          .toList(),
    );
    expect(
      result.ledger.accountedDuration.milliseconds,
      ledgerBefore.ledger.accountedDuration.milliseconds,
    );
    expect(
      result.ledger.unresolvedDuration.milliseconds,
      ledgerBefore.ledger.unresolvedDuration.milliseconds,
    );
    expect(await h.drafts.read(editContext), isNull);
    await expectOtherDrafts(h);
    expect(h.deletion.deletes, 1);
    expect(h.deletion.creates, 0);
    expect(h.deletion.updates, 0);
    expect(await model.submit(), isNull);
    expect(await model.deleteReview(), isNull);
    model.dispose();
  });

  test('repeat deletion is idempotent and same-date replacement survives; readback shows current identity', () async {
    final original = await seedReview(h);
    final saver = deletionSaver(h);
    expect(
      (await saver.delete(
        context: editContext,
        original: original,
      ) as ReviewDeleteCommitted).complete,
      true,
    );
    await h.traced.inner.create(
      id: replacementId,
      date: original.date,
      tomorrowFirstStepText: '新身份不删除',
      now: 20,
    );
    final second = await saver.delete(
      context: editContext,
      original: original,
    ) as ReviewDeleteCommitted;
    expect(second.complete, true);
    expect(second.refreshed!.review!.id, replacementId);
    expect(
      (await h.reviews.findByDate(original.date))!.tomorrowFirstStep.text,
      '新身份不删除',
    );
    expect(h.deletion.deletes, 2);
    expect(h.deletion.creates, 0);
  });

  test('real delete storage fault rolls back all formal tables, preserves latest raw input, retry succeeds', () async {
    final original = await deletionScene(h);
    final before = await formalFacts(h);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: deletionSaver(h),
    );
    await model.initialize();
    model.setReflection('  原始输入仍保留\n\n😀  ');
    await deleteFault(h, true);
    expect(await model.deleteReview(), isNull);
    expect(model.deleted, isNull);
    expect(model.submitError, contains('删除复盘失败'));
    expect(model.editable, true);
    expect(await formalFacts(h), before);
    expect((await h.drafts.read(editContext))!.reflection, model.reflection);
    await deleteFault(h, false);
    expect(await model.deleteReview(), isNotNull);
    expect(h.deletion.deletes, 2);
    await expectOtherDrafts(h);
    model.dispose();
  });

  test('delete locks repeat operations; committed clear/read failures retry only finalization and cannot resurrect draft', () async {
    final original = await deletionScene(h);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: deletionSaver(h),
    );
    await model.initialize();
    await h.failClear(true);
    h.failRefresh = true;
    h.deletion.deleteGate = Completer<void>();
    final first = model.deleteReview();
    expect(await model.deleteReview(), isNull);
    expect(await model.submit(), isNull);
    expect(await model.leave(), false);
    expect(await model.discard(), false);
    model.setReflection('不能修改');
    await Future<void>.delayed(Duration.zero);
    h.deletion.deleteGate!.complete();
    expect(await first, isNull);
    expect(model.deletedMessage, contains('草稿清理和读回失败'));
    expect(await h.reviews.findByDate(original.date), isNull);
    expect(model.editable, false);
    expect(await model.submit(), isNull);
    model.setFirstStep('不得重新提交');
    expect(model.firstStep, '原下一步');
    await h.failClear(false);
    expect(await model.retryFinish(), isNull);
    expect(model.deleted!.draftCleared, true);
    expect(model.deletedMessage, contains('但读回失败'));
    h.failRefresh = false;
    expect(await model.retryFinish(), isNotNull);
    expect(await h.drafts.read(editContext), isNull);
    await expectOtherDrafts(h);
    expect(h.deletion.deletes, 1);
    expect(h.deletion.updates, 0);
    expect(h.deletion.creates, 0);
    model.dispose();
  });

  test('stale source or wrong-date readback never counts as complete; later read only retries cleanup/read', () async {
    final original = await seedReview(h);
    var loaded = await h.refresh(date: reviewDate, now: h.clock);
    final saver = deletionSaver(
      h,
      refresh: ({required date, required now}) async => loaded,
    );
    final first = await saver.delete(
      context: editContext,
      original: original,
    ) as ReviewDeleteCommitted;
    expect(first.draftCleared, true);
    expect(first.refreshed, isNull);
    loaded = await h.refresh(date: otherDate, now: h.clock);
    expect(
      (await saver.finishDelete(
        context: editContext,
        original: original,
        draftCleared: true,
      )).complete,
      false,
    );
    loaded = await h.refresh(date: reviewDate, now: h.clock);
    expect(
      (await saver.finishDelete(
        context: editContext,
        original: original,
        draftCleared: true,
      )).complete,
      true,
    );
    expect(h.deletion.deletes, 1);
  });

  test('file reopen retains residual edit only by old ID; old restored edit cannot recreate deleted source', () async {
    final original = await deletionScene(h);
    await h.failClear(true);
    final removed = await deletionSaver(
      h,
    ).delete(context: editContext, original: original) as ReviewDeleteCommitted;
    expect(removed.draftCleared, false);
    await h.reopen();
    expect(await h.reviews.findByDate(original.date), isNull);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: deletionSaver(h),
    );
    await model.initialize();
    expect(model.restored, true);
    expect(model.reflection, '  未提交编辑\n\n😀  ');
    expect(await model.submit(), isNull);
    expect(model.submitError, contains('原复盘已不存在'));
    expect(await h.reviews.findByDate(original.date), isNull);
    expect(h.deletion.creates, 0);
    await h.failClear(false);
    expect(
      (await deletionSaver(h).finishDelete(
        context: editContext,
        original: original,
        draftCleared: false,
      )).complete,
      true,
    );
    await expectOtherDrafts(h);
    model.dispose();
  });

  test('failed queued draft write blocks delete and keeps raw input; retry can delete without valid form text', () async {
    final original = await seedReview(h);
    final model = ReviewFormController(
      context: editContext,
      store: h.drafts,
      original: original,
      entrySaver: deletionSaver(h),
    );
    await model.initialize();
    model.setReflection('磁盘旧输入');
    await model.flush();
    await mutate(
      h.draftFile,
      (db) => db.customStatement(
        "CREATE TRIGGER fail_save AFTER UPDATE ON review_drafts BEGIN SELECT RAISE(FAIL, 'fault'); END",
      ),
    );
    model.setReflection('  内存新输入  ');
    expect(await model.deleteReview(), isNull);
    expect(model.submitError, contains('草稿尚未保留成功'));
    expect(h.deletion.deletes, 0);
    expect((await h.drafts.read(editContext))!.reflection, '磁盘旧输入');
    expect((await h.reviews.findByDate(original.date))!.id, sourceId);
    await mutate(
      h.draftFile,
      (db) => db.customStatement('DROP TRIGGER fail_save'),
    );
    model.setFirstStep('');
    expect(await model.deleteReview(), isNotNull);
    expect(h.deletion.deletes, 1);
    model.dispose();
  });
}
