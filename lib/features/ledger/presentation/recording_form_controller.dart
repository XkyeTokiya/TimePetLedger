import 'package:flutter/foundation.dart';

import '../../../core/identity/entity_id.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_repository.dart';
import '../application/recording_entry_saver.dart';
import '../application/recording_entry_editor.dart';
import '../application/recording_ledger_loader.dart';
import '../application/recording_time_suggestion.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/recording_draft_store.dart';
import '../domain/time_precision.dart';
import '../domain/time_block.dart';
import '../domain/rhythm_annotation.dart';
import '../domain/rhythm_state.dart';
import '../domain/rhythm_details.dart';
import '../domain/ledger_repository.dart';

/// 页面所有的输入状态。所有后台写入串行；离开不清除，放弃等待写入后清除。
class RecordingFormController extends ChangeNotifier {
  RecordingFormController({
    required this.context,
    required this.store,
    required this.loadSuggestion,
    this.entrySaver,
    this.entryEditor,
    this.goals,
  });
  final RecordingDraftContext context;
  final RecordingDraftStore store;
  final Future<RecordingTimeSuggestion> Function() loadSuggestion;
  final RecordingEntrySaver? entrySaver;
  final RecordingEntryEditor? entryEditor;
  final GoalRepository? goals;
  List<Goal> activeGoals = const [];
  Goal? selectedGoal;
  bool goalsLoading = false;
  String? goalsError;
  EntityId? _selectedGoalId;
  bool goalProvided = false;
  EntityId? get goalId => goalProvided ? _selectedGoalId : original?.goalId;
  int _goalRead = 0;
  TimeBlock? original;
  RhythmAnnotation? originalAnnotation;
  RecordingAnnotationIntent annotationIntent = RecordingAnnotationIntent.keep;
  EntityId? annotationId;
  RhythmState? rhythmState;
  String continuationHint = '';
  bool hintProvided = false;
  StuckReasonCode? stuckReasonCode;
  bool stuckReasonCodeProvided = false;
  String stuckReasonText = '';
  bool stuckReasonTextProvided = false;
  RecoveryMethod? recoveryMethod;
  bool recoveryMethodProvided = false;
  RecoveryQuality? recoveryQuality;
  bool recoveryQualityProvided = false;

  bool missingOriginal = false;
  String title = '';
  String note = '';
  BlockKnowledgeState? knowledgeState;
  RecordingTimeInput time = const RecordingTimeInput();
  List<RecordingTimeInput> candidates = const [];
  bool loading = true;
  bool restored = false;
  RecordingDraft? pendingRecovery;
  RecordingDraft? _baseline;
  int presentationStep = 0;
  bool saving = false;
  bool discarding = false;
  bool submitting = false;
  RecordingSubmitCommitted? committed;
  String? submitError;
  List<LedgerFactInterval> conflicts = const [];
  String? loadError;
  String? storageError;
  bool _disposed = false;
  bool _initialized = false;
  bool _initializing = false;
  int _revision = 0;
  Future<void> _writes = Future.value();

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized || _initializing || _disposed) return;
    _initializing = true;
    loading = true;
    loadError = null;
    missingOriginal = false;
    _emit();
    try {
      if (context.entry == RecordingDraftEntry.edit) {
        final source = await entryEditor?.load(context.timeBlockId!);
        if (_disposed) return;
        if (source == null) {
          missingOriginal = true;
          loadError = '记录已不存在，无法更正。';
          await store.clear(context);
          return;
        }
        original = source.timeBlock;
        originalAnnotation = source.annotation;
      }
      final saved = await store.read(context);
      if (_disposed) return;
      if (saved != null) {
        if (context.entry == RecordingDraftEntry.edit && entryEditor != null) {
          committed = await entryEditor!.recoverCommittedEdit(
            draft: saved,
            original: original!,
            annotation: originalAnnotation,
          );
          if (_disposed) return;
        } else if (entrySaver != null) {
          committed = await entrySaver!.recoverCommittedDraft(saved);
          if (_disposed) return;
        }
      }
      if (context.entry == RecordingDraftEntry.edit) {
        goalProvided = false;
        _selectedGoalId = null;
        annotationIntent = RecordingAnnotationIntent.keep;
        rhythmState = originalAnnotation?.state;
        continuationHint = originalAnnotation?.continuationHint ?? '';
        hintProvided = false;
        stuckReasonCode = originalAnnotation?.stuckReasonCode;
        stuckReasonText = originalAnnotation?.stuckReasonText ?? '';
        recoveryMethod = originalAnnotation?.recoveryMethod;
        recoveryQuality = originalAnnotation?.recoveryQuality;

        final block = original!;
        title = block.title ?? '';
        note = block.note ?? '';
        knowledgeState = block.knowledgeState;
        time = RecordingTimeInput(
          startedAt: block.startedAt,
          endedAt: block.endedAt,
          startPrecision: block.startPrecision,
          endPrecision: block.endPrecision,
        );
      } else {
        knowledgeState = BlockKnowledgeState.known;
      }
      // 先识别已经提交的草稿，避免重算时间后重试产生重复正式记录。
      if (context.entry != RecordingDraftEntry.edit && committed == null) {
        final suggestion = await loadSuggestion();
        if (_disposed) return;
        candidates = const [];
        switch (suggestion) {
          case DirectTimeSuggestion(:final input):
            time = input;
          case TimeCandidates(:final candidates):
            this.candidates = candidates;
          case ManualTimeEntry():
            // 新建不恢复旧端点；全开区间由用户在本次编辑中填写。
            time = const RecordingTimeInput();
        }
      }
      if (!_disposed && goals != null) await loadGoals();
      _baseline = _draft;
      if (saved != null && committed == null) pendingRecovery = saved;
      _initialized = true;
    } catch (_) {
      loadError = '无法读取未完成输入、时间建议或账本，请重试。';
    } finally {
      _initializing = false;
      loading = false;
      _emit();
      // 系统生成的时间初值不是用户修改，不创建恢复快照。
    }
  }

  bool get editable =>
      !loading &&
      loadError == null &&
      !discarding &&
      !submitting &&
      !missingOriginal &&
      committed == null;

  bool get hasUserChanges =>
      _baseline != null && !_sameRecordingDraft(_draft, _baseline!);

  Future<void> resumePendingInput() async {
    final saved = pendingRecovery;
    if (saved == null || !editable) return;
    _applySaved(saved, restoreTime: context.entry == RecordingDraftEntry.edit);
    pendingRecovery = null;
    restored = true;
    _emit();
    _persist();
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
    if (baseline != null) _applySaved(baseline, restoreTime: true);
    pendingRecovery = null;
    restored = false;
    storageError = null;
    _emit();
  }

  void setPresentationStep(int value) {
    if (!editable || value == presentationStep) return;
    presentationStep = value.clamp(0, 3);
    _persist();
  }

  void _applySaved(RecordingDraft saved, {required bool restoreTime}) {
    title = saved.title ?? '';
    goalProvided = saved.goalProvided;
    _selectedGoalId = saved.goalId;
    annotationIntent = saved.annotationIntent;
    annotationId = saved.annotationId;
    rhythmState = saved.annotationIntent == RecordingAnnotationIntent.keep
        ? originalAnnotation?.state
        : saved.rhythmState;
    hintProvided = saved.hintProvided;
    stuckReasonCodeProvided = saved.stuckReasonCodeProvided;
    stuckReasonCode = saved.stuckReasonCodeProvided
        ? saved.stuckReasonCode
        : originalAnnotation?.stuckReasonCode;
    stuckReasonTextProvided = saved.stuckReasonTextProvided;
    stuckReasonText = saved.stuckReasonTextProvided
        ? saved.stuckReasonText ?? ''
        : originalAnnotation?.stuckReasonText ?? '';
    recoveryMethodProvided = saved.recoveryMethodProvided;
    recoveryMethod = saved.recoveryMethodProvided
        ? saved.recoveryMethod
        : originalAnnotation?.recoveryMethod;
    recoveryQualityProvided = saved.recoveryQualityProvided;
    recoveryQuality = saved.recoveryQualityProvided
        ? saved.recoveryQuality
        : originalAnnotation?.recoveryQuality;
    continuationHint = saved.hintProvided
        ? saved.continuationHint ?? ''
        : originalAnnotation?.continuationHint ?? '';
    note = saved.noteProvided ? saved.note ?? '' : original?.note ?? '';
    knowledgeState = saved.knowledgeState;
    if (restoreTime) {
      time = RecordingTimeInput(
        startedAt: saved.startedAt,
        endedAt: saved.endedAt,
        startPrecision: saved.startPrecision,
        endPrecision: saved.endPrecision,
      );
    }
    presentationStep = saved.presentationStep.clamp(0, 3);
  }

  /// Metadata reads never replace activity, times or draft association intent.
  /// A failed list is distinct from an empty active list.
  Future<void> loadGoals() async {
    final repository = goals;
    if (repository == null) return;
    final request = ++_goalRead;
    goalsLoading = true;
    goalsError = null;
    _emit();
    try {
      final active = await repository.listActive();
      final id = goalId;
      final selected = id == null ? null : await repository.findById(id);
      if (_disposed || request != _goalRead) return;
      activeGoals = active;
      selectedGoal = selected;
    } catch (_) {
      if (_disposed || request != _goalRead) return;
      goalsError = '目标读取失败，请重试；当前归属和输入已保留。';
    } finally {
      if (!_disposed && request == _goalRead) {
        goalsLoading = false;
        _emit();
      }
    }
  }

  void selectGoal(EntityId id) {
    if (!editable || goalsLoading || goalsError != null) return;
    final selected = activeGoals.where((goal) => goal.id == id).firstOrNull;
    if (selected == null) return;
    _goalRead++;
    _selectedGoalId = id;
    goalProvided = true;
    selectedGoal = selected;
    _persist();
  }

  /// Only used after the goal repository has committed creation.
  Future<void> associateCreatedGoal(EntityId id) async {
    if (_disposed || !editable) return;
    _goalRead++;
    _selectedGoalId = id;
    goalProvided = true;
    selectedGoal = null;
    _persist();
    await loadGoals();
  }

  void clearGoal() {
    if (!editable) return;
    _goalRead++;
    goalsLoading = false;
    _selectedGoalId = null;
    selectedGoal = null;
    goalProvided = true;
    _persist();
  }

  void setTitle(String value) {
    if (!editable) return;
    title = value;
    _persist();
  }

  void setRhythmState(RhythmState? value) {
    if (!editable) return;
    rhythmState = value;
    if (value == null) {
      annotationIntent = context.entry == RecordingDraftEntry.edit
          ? RecordingAnnotationIntent.remove
          : RecordingAnnotationIntent.keep;
    } else {
      annotationIntent = originalAnnotation == null
          ? RecordingAnnotationIntent.add
          : RecordingAnnotationIntent.edit;
      if (annotationIntent == RecordingAnnotationIntent.add) {
        annotationId ??= (entrySaver?.newId ?? entryEditor?.saver.newId)
            ?.call();
      }
    }
    _persist();
  }

  void setContinuationHint(String value) {
    if (!editable || rhythmState == null) return;
    continuationHint = value;
    hintProvided = true;
    if (annotationIntent == RecordingAnnotationIntent.keep) {
      annotationIntent = originalAnnotation == null
          ? RecordingAnnotationIntent.add
          : RecordingAnnotationIntent.edit;
      if (annotationIntent == RecordingAnnotationIntent.add) {
        annotationId ??= (entrySaver?.newId ?? entryEditor?.saver.newId)
            ?.call();
      }
    }
    _persist();
  }

  void setStuckReasonCode(StuckReasonCode? value) {
    if (!editable || rhythmState != RhythmState.stuck) return;
    stuckReasonCode = value;
    stuckReasonCodeProvided = true;
    _markDetailsChanged();
  }

  void setStuckReasonText(String value) {
    if (!editable || rhythmState != RhythmState.stuck) return;
    stuckReasonText = value;
    stuckReasonTextProvided = true;
    _markDetailsChanged();
  }

  void setRecoveryMethod(RecoveryMethod? value) {
    if (!editable || rhythmState != RhythmState.recovery) return;
    recoveryMethod = value;
    recoveryMethodProvided = true;
    _markDetailsChanged();
  }

  void setRecoveryQuality(RecoveryQuality? value) {
    if (!editable || rhythmState != RhythmState.recovery) return;
    recoveryQuality = value;
    recoveryQualityProvided = true;
    _markDetailsChanged();
  }

  void _markDetailsChanged() {
    if (annotationIntent == RecordingAnnotationIntent.keep) {
      annotationIntent = originalAnnotation == null
          ? RecordingAnnotationIntent.add
          : RecordingAnnotationIntent.edit;
      if (annotationIntent == RecordingAnnotationIntent.add) {
        annotationId ??= (entrySaver?.newId ?? entryEditor?.saver.newId)
            ?.call();
      }
    }
    _persist();
  }

  void setNote(String value) {
    if (!editable) return;
    note = value;
    _persist();
  }

  void setKnowledge(BlockKnowledgeState value) {
    if (!editable) return;
    knowledgeState = value;
    _persist();
  }

  void setTime({required int? start, required int? end}) {
    if (!editable) return;
    time = time.withTimes(startedAt: start, endedAt: end);
    candidates = const [];
    _persist();
  }

  void chooseCandidate(RecordingTimeInput input) =>
      setTime(start: input.startedAt, end: input.endedAt);
  void setPrecision({TimePrecision? start, TimePrecision? end}) {
    if (!editable) return;
    time = time.withPrecisions(startPrecision: start, endPrecision: end);
    _persist();
  }

  String? get titleError {
    final normalized = title.trim();
    if (knowledgeState == BlockKnowledgeState.known && normalized.isEmpty) {
      return '请填写活动内容。';
    }
    if (normalized.runes.length > 200) return '活动内容最多 200 个字符。';
    return null;
  }

  String? get timeError {
    if (time.startedAt == null || time.endedAt == null) return '请填写开始与结束时间。';
    if (time.startedAt! >= time.endedAt!) return '结束时间必须晚于开始时间。';
    return null;
  }

  String? get noteError =>
      note.trim().runes.length > 2000 ? '备注最多 2000 个字符。' : null;

  String? get hintError =>
      rhythmState != null && continuationHint.trim().runes.length > 2000
      ? '接续点最多 2000 个字符。'
      : null;

  String? get reasonError {
    if (rhythmState == null) return null;
    // Use the existing domain text validation, including inactive retained text.
    const validationId = '00000000-0000-4000-8000-000000000001';
    try {
      RhythmAnnotation(
        id: validationId,
        timeBlockId: validationId,
        state: rhythmState!,
        stuckReasonText: stuckReasonText,
        createdAt: 0,
        updatedAt: 0,
      );
      return null;
    } on ArgumentError {
      return '原因说明最多 2000 个字符。';
    }
  }

  bool get valid =>
      knowledgeState != null &&
      titleError == null &&
      timeError == null &&
      noteError == null &&
      hintError == null &&
      reasonError == null;

  RecordingDraft get _draft => RecordingDraft(
    context: context,
    title: title,
    note: note,
    noteProvided: true,
    goalId: goalProvided ? _selectedGoalId : null,
    goalProvided: goalProvided,
    annotationIntent: annotationIntent,
    annotationId: annotationId,
    rhythmState: rhythmState,
    continuationHint: continuationHint,
    hintProvided: hintProvided,
    stuckReasonCode: stuckReasonCode,
    stuckReasonCodeProvided: stuckReasonCodeProvided,
    stuckReasonText: stuckReasonText,
    stuckReasonTextProvided: stuckReasonTextProvided,
    recoveryMethod: recoveryMethod,
    recoveryMethodProvided: recoveryMethodProvided,
    recoveryQuality: recoveryQuality,
    recoveryQualityProvided: recoveryQualityProvided,
    startedAt: time.startedAt,
    endedAt: time.endedAt,
    startPrecision: time.startPrecision,
    endPrecision: time.endPrecision,
    knowledgeState: knowledgeState,
    presentationStep: presentationStep,
  );

  void _persist() {
    submitError = null;
    conflicts = const [];
    final draft = _draft;
    final baseline = _baseline;
    final revision = ++_revision;
    saving = true;
    storageError = null;
    _emit();
    _writes = _writes.then((_) async {
      try {
        if (baseline != null && _sameRecordingDraft(draft, baseline)) {
          await store.clear(context);
        } else {
          await store.save(draft);
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

  Future<RecordingLedger?> submit() async {
    if (!editable ||
        (context.entry == RecordingDraftEntry.edit
            ? entryEditor == null
            : entrySaver == null)) {
      return null;
    }
    submitError = null;
    conflicts = const [];
    if (!valid) {
      submitError = '请确认活动和时间后再保存。';
      _emit();
      return null;
    }
    submitting = true;
    _emit();
    try {
      if (!await flush()) {
        submitError = '本次填写尚未保留成功，请重试。';
        return null;
      }
      final result = context.entry == RecordingDraftEntry.edit
          ? await entryEditor!.save(_draft)
          : await entrySaver!.submit(_draft);
      switch (result) {
        case RecordingSubmitFailed(
          :final conflicts,
          :final notFound,
          :final annotationFailure,
        ):
          this.conflicts = conflicts;
          submitError = notFound
              ? '记录已不存在，无法更正；当前输入仍保留。'
              : annotationFailure == AnnotationOperationFailure.alreadyExists
              ? '此记录已有节奏解释，请重新打开后编辑；当前输入仍保留。'
              : annotationFailure == AnnotationOperationFailure.notFound
              ? '节奏解释已不存在，请重新打开后添加；当前输入仍保留。'
              : conflicts.isEmpty
              ? '正式保存失败，当前输入仍保留，请重试。'
              : '时间与已有记录冲突，请手动调整后再保存。';
          return null;
        case RecordingSubmitCommitted():
          committed = result;
          return result.complete ? result.refreshed : null;
      }
    } finally {
      submitting = false;
      _emit();
    }
  }

  Future<RecordingLedger?> retryFinish() async {
    final previous = committed;
    if (submitting ||
        previous == null ||
        previous.complete ||
        (context.entry == RecordingDraftEntry.edit
            ? entryEditor == null
            : entrySaver == null)) {
      return null;
    }
    submitting = true;
    _emit();
    try {
      final result = context.entry == RecordingDraftEntry.edit
          ? await entryEditor!.finishCommitted(
              context: context,
              timeBlock: previous.timeBlock,
              draftCleared: previous.draftCleared,
            )
          : await entrySaver!.finishCommitted(
              draftContext: context,
              timeBlock: previous.timeBlock,
              draftCleared: previous.draftCleared,
            );
      committed = result;
      return result.complete ? result.refreshed : null;
    } finally {
      submitting = false;
      _emit();
    }
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

  Future<bool> discard() async {
    if (!editable && !missingOriginal) return false;
    discarding = true;
    _emit();
    await _writes;
    try {
      await store.clear(context);
      storageError = null;
      return true;
    } catch (_) {
      storageError = '暂时无法清空本次填写，请重试。';
      return false;
    } finally {
      discarding = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _sameRecordingDraft(RecordingDraft a, RecordingDraft b) =>
    a.title == b.title &&
    a.startedAt == b.startedAt &&
    a.endedAt == b.endedAt &&
    a.startPrecision == b.startPrecision &&
    a.endPrecision == b.endPrecision &&
    a.knowledgeState == b.knowledgeState &&
    a.note == b.note &&
    a.noteProvided == b.noteProvided &&
    a.goalId == b.goalId &&
    a.goalProvided == b.goalProvided &&
    a.annotationIntent == b.annotationIntent &&
    a.annotationId == b.annotationId &&
    a.rhythmState == b.rhythmState &&
    a.continuationHint == b.continuationHint &&
    a.hintProvided == b.hintProvided &&
    a.stuckReasonCode == b.stuckReasonCode &&
    a.stuckReasonCodeProvided == b.stuckReasonCodeProvided &&
    a.stuckReasonText == b.stuckReasonText &&
    a.stuckReasonTextProvided == b.stuckReasonTextProvided &&
    a.recoveryMethod == b.recoveryMethod &&
    a.recoveryMethodProvided == b.recoveryMethodProvided &&
    a.recoveryQuality == b.recoveryQuality &&
    a.recoveryQualityProvided == b.recoveryQualityProvided &&
    a.presentationStep == b.presentationStep;
