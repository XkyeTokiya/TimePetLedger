import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_repository.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

final entryDate = CivilDate(year: 2025, month: 12, day: 31);
const reviewId = '00000000-0000-4000-8000-000000000099';
const goalId = '00000000-0000-4000-8000-000000000001';
const activeId = '00000000-0000-4000-8000-000000000002';
final entry = ReviewDraftContext.newEntry(date: entryDate);

String draftKey(ReviewDraftContext context) => context.isEditing
    ? 'edit:${context.reviewId}'
    : formatReviewDate(context.entryDate!);

class MemoryDrafts implements ReviewDraftStore {
  final values = <String, ReviewDraft>{};
  final snapshots = <ReviewDraft>[];
  final operations = <String>[];
  bool failRead = false;
  bool failSave = false;
  bool failClear = false;
  Completer<void>? saveGate;
  @override
  Future<ReviewDraft?> read(ReviewDraftContext context) async {
    if (failRead) throw StateError('read');
    return values[draftKey(context)];
  }

  @override
  Future<void> save(ReviewDraft draft) async {
    operations.add('save:${draft.summary}');
    await saveGate?.future;
    if (failSave) throw StateError('save');
    snapshots.add(draft);
    values[draftKey(draft.context)] = draft;
  }

  @override
  Future<void> clear(ReviewDraftContext context) async {
    operations.add('clear:${draftKey(context)}');
    if (failClear) throw StateError('clear');
    values.remove(draftKey(context));
  }
}

class ReadGoals implements GoalRepository {
  final old = Goal.create(id: goalId, name: '同名', now: 1).archive(now: 2);
  final active = Goal.create(id: activeId, name: '同名', now: 1);
  bool fail = false;
  Completer<List<Goal>>? gate;
  @override
  Future<List<Goal>> listActive() async {
    if (fail) throw StateError('goals');
    return gate?.future ?? [active];
  }

  @override
  Future<Goal?> findById(String id) async => id == goalId ? old : active;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DailyReview originalReview({String? goal = goalId}) => DailyReview(
  id: reviewId,
  date: entryDate,
  summary: '原概述',
  reflection: '原反思',
  tomorrowFirstStep: TomorrowFirstStep(
    reviewDate: entryDate,
    text: '原下一步',
    goalId: goal,
  ),
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  test(
    'untouched review creates no snapshot and restart restores baseline',
    () async {
      final store = MemoryDrafts();
      final model = ReviewFormController(context: entry, store: store);
      await model.initialize();
      expect(model.hasUserChanges, isFalse);
      expect(await model.flush(), isTrue);
      expect(store.snapshots, isEmpty);
      model.setSummary('临时');
      await model.flush();
      expect(store.values[draftKey(entry)], isNotNull);
      await model.restartInput();
      expect(model.summary, isEmpty);
      expect(store.values[draftKey(entry)], isNull);
      model.dispose();
    },
  );

  test('restore full cleared snapshot by original identity, mutable date and incomplete input never fall back', () async {
    final store = MemoryDrafts();
    final original = originalReview();
    final edit = ReviewDraftContext.edit(reviewId: reviewId);
    await store.save(
      ReviewDraft(
        context: edit,
        date: null,
        dateInput: '2026-',
        summary: '',
        reflection: null,
        tomorrowFirstStepText: '  \n ',
        tomorrowFirstStepGoalId: null,
      ),
    );
    final model = ReviewFormController(
      context: edit,
      store: store,
      original: original,
    );
    await model.initialize();
    expect(model.pendingRecovery, isNotNull);
    await model.resumePendingInput();
    expect(model.restored, true);
    expect(model.date, isNull);
    expect(model.dateInput, '2026-');
    expect(model.summary, '');
    expect(model.reflection, '');
    expect(model.goalId, isNull);
    expect(model.firstStep, '  \n ');
    expect(model.firstStepError, isNotNull);
    model.setDateInput('2024-02-29');
    expect(model.intendedDate, CivilDate(year: 2024, month: 3, day: 1));
    model.setReflection('新的\n反思');
    await model.initialize();
    await model.flush();
    expect(model.reflection, '新的\n反思');
    expect(store.values.keys, [draftKey(edit)]);
    expect(original.date, entryDate);
    expect(original.reflection, '原反思');
    expect(original.tomorrowFirstStep.goalId, goalId);
    model.dispose();
  });

  test('new-entry defaults only after successful read; retry does not overwrite a draft', () async {
    final store = MemoryDrafts()..failRead = true;
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    expect(model.loadError, isNotNull);
    expect(model.editable, false);
    model.setSummary('blocked');
    expect(store.snapshots, isEmpty);
    store.failRead = false;
    await model.initialize();
    expect(model.date, entryDate);
    expect(model.firstStep, '');
    expect(model.valid, false);
    model.setFirstStep('');
    await model.flush();
    expect(store.values[draftKey(entry)], isNull);
    model.dispose();
  });

  test('optional long text, single step, trim Unicode boundaries preserve raw multiline snapshots', () async {
    final store = MemoryDrafts();
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    model.setSummary(' \n\t ');
    model.setReflection('');
    model.setFirstStep('  先做\n\n  一件事 😀  ');
    expect(model.valid, true);
    final within =
        '  ${'😀' * 1997}\na\u0301  '; // 2000 runes, >2000 UTF-16 units.
    final over = ' ${within.trim()}界 ';
    for (final set in [
      model.setSummary,
      model.setReflection,
      model.setFirstStep,
    ]) {
      set(within);
      expect([
        model.summaryError,
        model.reflectionError,
        model.firstStepError,
      ], everyElement(isNull));
      set(over);
      expect(model.valid, false);
      await model.flush();
      expect(
        store.snapshots.last.summary == over ||
            store.snapshots.last.reflection == over ||
            store.snapshots.last.tomorrowFirstStepText == over,
        true,
      );
      set(within);
    }
    model.setFirstStep(' \n ');
    await model.flush();
    expect(store.snapshots.last.tomorrowFirstStepText, ' \n ');
    expect(model.firstStepError, isNotNull);
    model.dispose();
  });

  test('calendar boundaries synchronously derive the next civil day; invalid date persists without stale next day', () async {
    final store = MemoryDrafts();
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    for (final pair in {
      '2025-12-31': '2026-01-01',
      '2024-02-28': '2024-02-29',
      '2024-02-29': '2024-03-01',
      '1900-02-28': '1900-03-01',
      '2000-02-28': '2000-02-29',
      '2026-04-30': '2026-05-01',
      '-0001-12-31': '0000-01-01',
    }.entries) {
      model.setDateInput(pair.key);
      expect(formatReviewDate(model.intendedDate!), pair.value);
    }
    model.setDateInput('2025-02-29');
    expect(model.intendedDate, isNull);
    await model.flush();
    model.dispose();
    final restored = ReviewFormController(context: entry, store: store);
    await restored.initialize();
    expect(restored.pendingRecovery, isNotNull);
    await restored.resumePendingInput();
    expect(restored.dateInput, '2025-02-29');
    expect(restored.date, isNull);
    restored.dispose();
  });

  test('rapid input drains in order on leave and locks new input; date keys remain separate', () async {
    final store = MemoryDrafts()..saveGate = Completer<void>();
    final other = ReviewDraftContext.newEntry(
      date: CivilDate(year: 2026, month: 1, day: 1),
    );
    store.values[draftKey(other)] = ReviewDraft(
      context: other,
      date: other.entryDate,
      summary: '另一日',
    );
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    model.setSummary('a');
    model.setSummary('ab');
    model.setDateInput('2026-01-01');
    model.setSummary('abc');
    var left = false;
    final leave = model.leave().then((value) => left = value);
    await Future<void>.delayed(Duration.zero);
    expect(left, false);
    expect(model.editable, false);
    model.setSummary('too late');
    store.saveGate!.complete();
    await leave;
    expect(left, true);
    expect(store.snapshots.map((d) => d.summary), ['a', 'ab', 'ab', 'abc']);
    expect(store.values[draftKey(entry)]!.date, other.entryDate);
    expect(store.values[draftKey(other)]!.summary, '另一日');
    model.dispose();
  });

  test('save failure blocks leaving, retains input, then retry succeeds without clear', () async {
    final store = MemoryDrafts();
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    model.setSummary('已保留');
    await model.flush();
    store.failSave = true;
    model.setSummary('新输入');
    expect(await model.leave(), false);
    expect(model.editable, true);
    expect(model.summary, '新输入');
    expect(store.values[draftKey(entry)]!.summary, '已保留');
    expect(model.storageError, isNotNull);
    store.failSave = false;
    expect(await model.retrySave(), true);
    expect(await model.leave(), true);
    expect(store.values[draftKey(entry)]!.summary, '新输入');
    expect(store.operations.where((v) => v.startsWith('clear')), isEmpty);
    model.dispose();
  });

  test('discard waits accepted saves, clears only this key; failure preserves input and can retry', () async {
    final store = MemoryDrafts()..saveGate = Completer<void>();
    final edit = ReviewDraftContext.edit(reviewId: reviewId);
    store.values[draftKey(edit)] = ReviewDraft(
      context: edit,
      date: entryDate,
      summary: '编辑草稿',
    );
    final model = ReviewFormController(context: entry, store: store);
    await model.initialize();
    model.setSummary('待保存');
    store.failClear = true;
    final discard = model.discard();
    await Future<void>.delayed(Duration.zero);
    expect(store.operations, ['save:待保存']);
    model.setSummary('不能改');
    store.saveGate!.complete();
    expect(await discard, false);
    expect(model.summary, '待保存');
    expect(model.storageError, isNotNull);
    expect(store.values[draftKey(entry)]!.summary, '待保存');
    store.failClear = false;
    expect(await model.discard(), true);
    expect(store.values.keys, [draftKey(edit)]);
    model.dispose();
  });

  test('original archived Goal remains visible, selection only active, clear survives restore; failures preserve association', () async {
    final store = MemoryDrafts();
    final goals = ReadGoals();
    final edit = ReviewDraftContext.edit(reviewId: reviewId);
    final model = ReviewFormController(
      context: edit,
      store: store,
      original: originalReview(),
      originalGoal: goals.old,
      goals: goals,
    );
    await model.initialize();
    expect(model.selectedGoal, goals.old);
    expect(model.activeGoals, [goals.active]);
    model.selectGoal(goalId);
    expect(store.snapshots, isEmpty);
    goals.fail = true;
    await model.loadGoals();
    expect(model.goalsError, isNotNull);
    expect(model.goalId, goalId);
    model.selectGoal(activeId);
    expect(model.goalId, goalId);
    goals.fail = false;
    await model.loadGoals();
    model.selectGoal(activeId);
    expect(model.goalId, activeId);
    model.clearGoal();
    await model.flush();
    model.dispose();
    final restored = ReviewFormController(
      context: edit,
      store: store,
      original: originalReview(),
      goals: goals,
    );
    await restored.initialize();
    expect(restored.pendingRecovery, isNotNull);
    await restored.resumePendingInput();
    expect(restored.goalId, isNull);
    expect(restored.selectedGoal, isNull);
    expect(restored.firstStep, '原下一步');
    restored.dispose();
  });

  test(
    'late Goal response cannot resurrect explicitly cleared association',
    () async {
      final goals = ReadGoals();
      final model = ReviewFormController(
        context: ReviewDraftContext.edit(reviewId: reviewId),
        store: MemoryDrafts(),
        original: originalReview(),
        goals: goals,
      );
      await model.initialize();
      goals.gate = Completer<List<Goal>>();
      final loading = model.loadGoals();
      model.clearGoal();
      goals.gate!.complete([goals.active]);
      await loading;
      expect(model.goalId, isNull);
      expect(model.selectedGoal, isNull);
      expect(model.goalsLoading, false);
      await model.flush();
      model.dispose();
    },
  );

  test(
    'queued saves continue after disposal, without late notifications',
    () async {
      final store = MemoryDrafts()..saveGate = Completer<void>();
      final model = ReviewFormController(context: entry, store: store);
      await model.initialize();
      model.setSummary('离开时输入');
      model.dispose();
      store.saveGate!.complete();
      expect(await model.flush(), true);
      expect(store.values[draftKey(entry)]!.summary, '离开时输入');
    },
  );
}
