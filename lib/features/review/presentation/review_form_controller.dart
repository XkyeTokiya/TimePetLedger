import 'package:flutter/foundation.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_repository.dart';
import '../../goals/domain/goal_status.dart';
import '../domain/daily_review.dart';
import '../domain/review_draft_store.dart';
import '../domain/review_text.dart';
import '../domain/tomorrow_first_step.dart';
import '../application/review_entry_saver.dart';
import '../application/review_context_loader.dart';

String formatReviewDate(CivilDate date) =>
    '${date.year < 0 ? '-' : ''}${date.year.abs().toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

CivilDate? parseReviewDate(String value) {
  final match = RegExp(r'^(-?\d{4,})-(\d{2})-(\d{2})$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final year = int.tryParse(match[1]!);
  if (year == null) return null;
  try {
    return CivilDate(
      year: year,
      month: int.parse(match[2]!),
      day: int.parse(match[3]!),
    );
  } on ArgumentError {
    return null;
  }
}

/// Owns raw input only. Reading facts or saving drafts never updates DailyReview.
final class ReviewFormController extends ChangeNotifier {
  ReviewFormController({
    required this.context,
    required this.store,
    this.original,
    this.goals,
    this.entrySaver,
    Goal? originalGoal,
  }) : selectedGoal = originalGoal {
    if (context.isEditing != (original != null) ||
        original != null && original!.id != context.reviewId ||
        originalGoal != null &&
            originalGoal.id != original?.tomorrowFirstStep.goalId) {
      throw ArgumentError('Editing requires the complete original review.');
    }
  }

  final ReviewDraftContext context;
  final ReviewDraftStore store;
  final DailyReview? original;
  final GoalRepository? goals;
  final ReviewEntrySaver? entrySaver;
  bool submitting = false;
  ReviewSubmitCommitted? committed;
  ReviewDeleteCommitted? deleted;
  String? submitError;
  CivilDate? date;
  String dateInput = '';
  String summary = '';
  String reflection = '';
  String firstStep = '';
  EntityId? goalId;
  Goal? selectedGoal;
  List<Goal> activeGoals = const [];
  bool loading = true;
  bool restored = false;
  ReviewDraft? pendingRecovery;
  ReviewDraft? _baseline;
  bool saving = false;
  bool discarding = false;
  bool leaving = false;
  bool goalsLoading = false;
  String? loadError;
  String? storageError;
  String? goalsError;
  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;
  bool _discarded = false;
  int _revision = 0;
  int _goalRead = 0;
  Future<void> _writes = Future.value();

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized || _initializing || _disposed) return;
    _initializing = true;
    loading = true;
    loadError = null;
    _emit();
    try {
      final saved = await store.read(context);
      if (_disposed) return;
      date = original?.date ?? context.entryDate;
      dateInput = date == null ? '' : formatReviewDate(date!);
      summary = original?.summary ?? '';
      reflection = original?.reflection ?? '';
      firstStep = original?.tomorrowFirstStep.text ?? '';
      goalId = original?.tomorrowFirstStep.goalId;
      if (selectedGoal?.id != goalId) selectedGoal = null;
      if (saved != null && !context.isEditing && entrySaver != null) {
        committed = await entrySaver!.recoverCommittedDraft(saved);
        if (_disposed) return;
      }
      _baseline = draft;
      if (saved != null && committed == null) pendingRecovery = saved;
      _initialized = true;
    } catch (_) {
      loadError = '复盘未完成输入或提交状态读取失败，请重试。';
    } finally {
      loading = false;
      _initializing = false;
      _emit();
    }
    if (_initialized && !_disposed) await loadGoals();
  }

  bool get editable =>
      _initialized &&
      !_disposed &&
      !loading &&
      !discarding &&
      !leaving &&
      !submitting &&
      committed == null &&
      deleted == null &&
      !_discarded;

  bool get hasUserChanges =>
      _baseline != null && !_sameReviewDraft(draft, _baseline!);

  Future<void> resumePendingInput() async {
    final saved = pendingRecovery;
    if (saved == null || !editable) return;
    _applyDraft(saved);
    pendingRecovery = null;
    restored = true;
    _emit();
    _persist();
    await loadGoals();
  }

  Future<void> restartInput() async {
    if (pendingRecovery == null && !hasUserChanges) return;
    await _writes;
    try {
      await store.clear(context);
    } catch (_) {
      storageError = '暂时无法清空本次填写，请重试。';
      _emit();
      return;
    }
    final baseline = _baseline;
    if (baseline != null) _applyDraft(baseline);
    pendingRecovery = null;
    restored = false;
    storageError = null;
    _emit();
    await loadGoals();
  }

  void _applyDraft(ReviewDraft value) {
    date = value.date;
    dateInput =
        value.dateInput ?? (date == null ? '' : formatReviewDate(date!));
    summary = value.summary ?? '';
    reflection = value.reflection ?? '';
    firstStep = value.tomorrowFirstStepText ?? '';
    goalId = value.tomorrowFirstStepGoalId;
    if (selectedGoal?.id != goalId) selectedGoal = null;
  }

  CivilDate? get intendedDate =>
      date == null ? null : TomorrowFirstStep.dateAfter(date!);
  String? get dateError => date == null ? '请输入有效日期 YYYY-MM-DD。' : null;

  String? _textError(String value, String field) {
    try {
      normalizeReviewText(value, field);
      return null;
    } on ArgumentError {
      return '最多 2000 个 Unicode 字符（清理首尾空白后）。';
    }
  }

  String? get summaryError => _textError(summary, 'summary');
  String? get reflectionError => _textError(reflection, 'reflection');
  String? get firstStepError => firstStep.trim().isEmpty
      ? '正式保存时需要填写一个非空白的下一步；未完成输入可以留空。'
      : _textError(firstStep, 'text');
  bool get valid =>
      dateError == null &&
      summaryError == null &&
      reflectionError == null &&
      firstStepError == null;

  ReviewDraft get draft => ReviewDraft(
    context: context,
    date: date,
    dateInput: dateInput,
    summary: summary,
    reflection: reflection,
    tomorrowFirstStepText: firstStep,
    tomorrowFirstStepGoalId: goalId,
  );

  void setDateInput(String value) {
    if (!editable) return;
    dateInput = value;
    date = parseReviewDate(value);
    _persist();
  }

  void setSummary(String value) {
    if (!editable) return;
    summary = value;
    _persist();
  }

  void setReflection(String value) {
    if (!editable) return;
    reflection = value;
    _persist();
  }

  void setFirstStep(String value) {
    if (!editable) return;
    firstStep = value;
    _persist();
  }

  void _persist() {
    submitError = null;
    final snapshot = draft;
    final baseline = _baseline;
    final revision = ++_revision;
    saving = true;
    storageError = null;
    _emit();
    _writes = _writes.then((_) async {
      try {
        if (baseline != null && _sameReviewDraft(snapshot, baseline)) {
          await store.clear(context);
        } else {
          await store.save(snapshot);
        }
        if (revision == _revision) storageError = null;
      } catch (_) {
        if (revision == _revision) {
          storageError = '暂时无法保留本次填写，输入仍在此页，请重试。';
        }
      } finally {
        if (revision == _revision) saving = false;
        _emit();
      }
    });
  }

  Future<bool> flush() async {
    await _writes;
    return storageError == null;
  }

  Future<bool> retrySave() async {
    if (!editable) return false;
    _persist();
    return flush();
  }

  /// Freeze input while draining; a failed write keeps this form open/editable.
  Future<bool> leave() async {
    if (_disposed || loading || discarding || leaving || submitting) {
      return false;
    }
    leaving = true;
    _emit();
    final success = await flush();
    if (!success) {
      leaving = false;
      _emit();
    }
    return success;
  }

  Future<bool> discard() async {
    if (!editable) return false;
    discarding = true;
    _emit();
    await _writes;
    try {
      await store.clear(context);
      storageError = null;
      _discarded = true;
      return true;
    } catch (_) {
      storageError = '暂时无法清空本次填写，请重试。';
      return false;
    } finally {
      discarding = false;
      _emit();
    }
  }

  Future<ReviewContext?> submit() async {
    if (!editable || entrySaver == null) return null;
    submitError = null;
    if (!valid) {
      submitError = '请检查复盘日期与文字；正式保存需要一个非空白的下一步。';
      _emit();
      return null;
    }
    submitting = true;
    _emit();
    try {
      // Persist the final complete snapshot before creating or correcting a fact.
      _persist();
      if (!await flush()) {
        submitError = '本次填写尚未保留成功，请重试。';
        return null;
      }
      final result = await entrySaver!.submit(draft);
      switch (result) {
        case ReviewSubmitFailed(:final reason):
          submitError = switch (reason) {
            ReviewSubmitFailure.dateOccupied =>
              '该日期已有复盘，未覆盖；当前输入仍保留，请调整日期或返回读取。',
            ReviewSubmitFailure.invalidGoal => '目标已归档或不存在，未保存；请选择活跃目标或清空关联。',
            ReviewSubmitFailure.invalidInput => '日期或文字不符合保存要求，当前输入仍保留。',
            ReviewSubmitFailure.missingSource =>
              '原复盘已不存在，未保存更正，也未重新创建；当前输入仍保留，请返回读取。',
            ReviewSubmitFailure.storage => '正式保存失败，当前输入仍保留，请重试。',
          };
          return null;
        case ReviewSubmitCommitted():
          committed = result;
          return result.complete ? result.refreshed : null;
      }
    } finally {
      submitting = false;
      _emit();
    }
  }

  Future<ReviewContext?> deleteReview() async {
    if (!editable ||
        !context.isEditing ||
        original == null ||
        entrySaver == null) {
      return null;
    }
    submitting = true;
    submitError = null;
    _emit();
    try {
      // Keep even invalid/incomplete input if the formal delete fails.
      _persist();
      if (!await flush()) {
        submitError = '本次填写尚未保留成功，请重试。';
        return null;
      }
      final result = await entrySaver!.delete(
        context: context,
        original: original!,
      );
      switch (result) {
        case ReviewDeleteFailed():
          submitError = '删除复盘失败，当前输入仍保留，请重试。';
          return null;
        case ReviewDeleteCommitted():
          deleted = result;
          return result.complete ? result.refreshed : null;
      }
    } finally {
      submitting = false;
      _emit();
    }
  }

  Future<ReviewContext?> retryFinish() async {
    final previousDelete = deleted;
    if (previousDelete != null) {
      if (_disposed || submitting || entrySaver == null) return null;
      submitting = true;
      _emit();
      try {
        final result = await entrySaver!.finishDelete(
          context: context,
          original: previousDelete.original,
          draftCleared: previousDelete.draftCleared,
        );
        deleted = result;
        return result.complete ? result.refreshed : null;
      } finally {
        submitting = false;
        _emit();
      }
    }
    final previous = committed;
    if (_disposed || submitting || previous == null || entrySaver == null) {
      return null;
    }
    submitting = true;
    _emit();
    try {
      final result = await entrySaver!.finishCommitted(
        context: context,
        review: previous.review,
        draftCleared: previous.draftCleared,
      );
      committed = result;
      return result.complete ? result.refreshed : null;
    } finally {
      submitting = false;
      _emit();
    }
  }

  String? get committedMessage {
    final result = committed;
    if (result == null) return null;
    if (result.complete) return '复盘已保存。';
    if (!result.draftCleared && result.refreshed == null) {
      return '复盘已保存，但本地收尾和读回失败；请重试收尾，无需再次保存。';
    }
    return result.draftCleared
        ? '复盘已保存，但读回失败；请重试读取，无需再次保存。'
        : '复盘已保存，但本地收尾失败；请重试处理，无需再次保存。';
  }

  String? get deletedMessage {
    final result = deleted;
    if (result == null) return null;
    if (result.complete) return '复盘已删除。';
    if (!result.draftCleared && result.refreshed == null) {
      return '复盘已删除，但本地收尾和读回失败；请重试收尾，无需再次删除。';
    }
    return result.draftCleared
        ? '复盘已删除，但读回失败；请重试读取，无需再次删除。'
        : '复盘已删除，但本地收尾失败；请重试处理，无需再次删除。';
  }

  Future<void> loadGoals() async {
    if (goals == null || !_initialized || _disposed) return;
    final request = ++_goalRead;
    final id = goalId;
    goalsLoading = true;
    goalsError = null;
    _emit();
    try {
      final active = await goals!.listActive();
      final selected = id == null ? null : await goals!.findById(id);
      if (_disposed || request != _goalRead) return;
      activeGoals = active
          .where((goal) => goal.status == GoalStatus.active)
          .toList();
      selectedGoal = selected;
    } catch (_) {
      if (_disposed || request != _goalRead) return;
      goalsError = '目标读取失败，请重试；当前关联与文字已保留。';
    } finally {
      if (!_disposed && request == _goalRead) {
        goalsLoading = false;
        _emit();
      }
    }
  }

  void selectGoal(EntityId id) {
    if (!editable || goalsLoading || goalsError != null) return;
    final goal = activeGoals.where((goal) => goal.id == id).firstOrNull;
    if (goal == null) return;
    ++_goalRead;
    goalId = id;
    selectedGoal = goal;
    _persist();
  }

  void clearGoal() {
    if (!editable) return;
    ++_goalRead;
    goalsLoading = false;
    goalId = null;
    selectedGoal = null;
    _persist();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_goalRead;
    super.dispose();
  }
}

bool _sameReviewDraft(ReviewDraft a, ReviewDraft b) =>
    a.date == b.date &&
    a.dateInput == b.dateInput &&
    a.summary == b.summary &&
    a.reflection == b.reflection &&
    a.tomorrowFirstStepText == b.tomorrowFirstStepText &&
    a.tomorrowFirstStepGoalId == b.tomorrowFirstStepGoalId;
