import 'package:flutter/foundation.dart';

import '../application/sleep_entry_saver.dart';
import '../application/sleep_entry_editor.dart';
import '../application/sleep_ledger_loader.dart';
import '../application/recording_time_suggestion.dart';
import '../application/sleep_time_prediction_loader.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/sleep_draft_store.dart';
import '../domain/sleep_session.dart';
import '../domain/sleep_type.dart';
import '../domain/sleep_prediction.dart';
import '../domain/time_precision.dart';
import 'sleep_time_input.dart';

/// Owns input and submission feedback; formal writes remain in application/data.
class SleepFormController extends ChangeNotifier {
  SleepFormController({
    required this.context,
    required this.store,
    this.original,
    this.entrySaver,
    this.entryEditor,
    this.loadSuggestion,
    this.loadPredictions,
  }) {
    if (context.isEditing &&
            entryEditor == null &&
            original?.id != context.sleepSessionId ||
        original != null && original!.id != context.sleepSessionId ||
        !context.isEditing && original != null) {
      throw ArgumentError('An edit requires its complete original sleep.');
    }
  }

  final SleepDraftContext context;
  final SleepDraftStore store;
  final Future<RecordingTimeSuggestion> Function()? loadSuggestion;
  final Future<SleepTimePredictions> Function()? loadPredictions;
  SleepTimePredictions? _predictions;
  SleepPredictionOrigin? _predictionOrigin;
  bool _timeManuallyChanged = false;
  SleepSession? original;
  final SleepEntryEditor? entryEditor;
  SleepDeleteCommitted? deleted;
  bool missingOriginal = false;
  final SleepEntrySaver? entrySaver;
  bool submitting = false;
  SleepSubmitCommitted? committed;
  String? submitError;
  List<LedgerFactInterval> conflicts = const [];
  String startedAtInput = '';
  String endedAtInput = '';
  String note = '';
  bool _noteProvided = false;
  int? startedAt;
  int? endedAt;
  TimePrecision? startPrecision;
  TimePrecision? endPrecision;
  SleepType? type;
  bool loading = true;
  bool restored = false;
  SleepDraft? pendingRecovery;
  SleepDraft? _baseline;
  bool saving = false;
  bool discarding = false;
  String? loadError;
  String? storageError;
  bool _disposed = false;
  bool _initializing = false;
  bool _initialized = false;
  bool _discarded = false;
  int _revision = 0;
  Future<void> _writes = Future.value();

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    // A late/repeated restore must never overwrite the user's current input.
    if (_initialized || _initializing || _disposed) return;
    _initializing = true;
    loading = true;
    loadError = null;
    missingOriginal = false;
    _emit();
    try {
      if (context.isEditing && entryEditor != null) {
        original = await entryEditor!.load(context.sleepSessionId!);
        if (_disposed) return;
        if (original == null) {
          missingOriginal = true;
          loadError = '记录已不存在，无法更正；未完成输入将被清除。';
          await store.clear(context);
          return;
        }
      }
      final saved = await store.read(context);
      if (_disposed) return;
      startedAt = original?.startedAt;
      endedAt = original?.endedAt;
      startPrecision = original?.startPrecision;
      endPrecision = original?.endPrecision;
      type = original?.type;
      // 新建睡眠默认主睡眠（2026-10-07 用户决定）。
      if (!context.isEditing && type == null) {
        type = SleepType.mainSleep;
      }
      startedAtInput = formatSleepTime(startedAt);
      endedAtInput = formatSleepTime(endedAt);
      _noteProvided = false;
      note = original?.note ?? '';
      if (saved != null) {
        if (context.isEditing && entryEditor != null) {
          committed = await entryEditor!.recoverCommittedEdit(
            draft: saved,
            original: original!,
          );
        } else if (entrySaver != null && !context.isEditing) {
          committed = await entrySaver!.recoverCommittedDraft(saved);
        }
        if (_disposed) return;
      }
      if (!context.isEditing && committed == null && loadPredictions != null) {
        _predictions = await loadPredictions!();
        if (_disposed) return;
        _applyPrediction(_predictions!.forType(type ?? SleepType.mainSleep));
      } else if (!context.isEditing &&
          committed == null &&
          loadSuggestion != null) {
        final suggestion = await loadSuggestion!();
        if (_disposed) return;
        if (suggestion case DirectTimeSuggestion(:final input)) {
          startedAt = input.startedAt;
          endedAt = input.endedAt;
          startedAtInput = formatSleepTime(startedAt);
          endedAtInput = formatSleepTime(endedAt);
          startPrecision = input.startPrecision;
          endPrecision = input.endPrecision;
        } else if (suggestion is ManualTimeEntry) {
          startedAt = null;
          endedAt = null;
          startedAtInput = '';
          endedAtInput = '';
          startPrecision = TimePrecision.approximate;
          endPrecision = TimePrecision.approximate;
        }
      }
      _baseline = draft;
      if (saved != null && committed == null) pendingRecovery = saved;
      _initialized = true;
    } catch (_) {
      loadError = context.isEditing
          ? '无法读取睡眠记录或未完成输入，请重试。'
          : '无法读取未完成睡眠输入或时间建议，请重试。';
    } finally {
      _initializing = false;
      loading = false;
      _emit();
    }
  }

  bool get editable =>
      !_disposed &&
      _initialized &&
      !loading &&
      !discarding &&
      !_discarded &&
      !submitting &&
      committed == null &&
      deleted == null &&
      !missingOriginal;

  bool get hasUserChanges =>
      _baseline != null && !_sameSleepDraft(draft, _baseline!);

  Future<void> resumePendingInput() async {
    final saved = pendingRecovery;
    if (saved == null || !editable) return;
    _noteProvided = saved.noteProvided;
    note = saved.noteProvided ? saved.note ?? '' : original?.note ?? '';
    type = saved.type ?? type;
    if (context.isEditing) {
      startedAt = saved.startedAt;
      endedAt = saved.endedAt;
      startPrecision = saved.startPrecision;
      endPrecision = saved.endPrecision;
      startedAtInput = saved.startedAtInput ?? formatSleepTime(startedAt);
      endedAtInput = saved.endedAtInput ?? formatSleepTime(endedAt);
      _predictionOrigin = saved.predictionOrigin;
    } else if (_predictions != null) {
      _applyPrediction(_predictions!.forType(type ?? SleepType.mainSleep));
    }
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
    if (baseline != null) _applyDraft(baseline);
    pendingRecovery = null;
    restored = false;
    storageError = null;
    _emit();
  }

  void _applyDraft(SleepDraft value) {
    startedAt = value.startedAt;
    endedAt = value.endedAt;
    startPrecision = value.startPrecision;
    endPrecision = value.endPrecision;
    type = value.type;
    startedAtInput = value.startedAtInput ?? formatSleepTime(startedAt);
    endedAtInput = value.endedAtInput ?? formatSleepTime(endedAt);
    note = value.note ?? '';
    _noteProvided = value.noteProvided;
    _predictionOrigin = value.predictionOrigin;
    _timeManuallyChanged = false;
  }

  void setStartedAtInput(String value) {
    if (!editable) return;
    startedAtInput = value;
    _timeManuallyChanged = true;
    startedAt = parseSleepTime(value);
    _persist();
  }

  void setEndedAtInput(String value) {
    if (!editable) return;
    endedAtInput = value;
    _timeManuallyChanged = true;
    endedAt = parseSleepTime(value);
    _persist();
  }

  /// 组件直接应用绝对时间，显示到分钟不舍入未改动的事实边界。
  void setTime({required int? start, required int? end}) {
    if (!editable) return;
    _timeManuallyChanged = true;
    startedAt = start;
    endedAt = end;
    startedAtInput = formatSleepTime(start);
    endedAtInput = formatSleepTime(end);
    _persist();
  }

  void setType(SleepType value) {
    if (!editable) return;
    type = value;
    if (!_timeManuallyChanged && _predictions != null) {
      _applyPrediction(_predictions!.forType(value));
    }
    _persist();
  }

  void _applyPrediction(SleepPredictionOrigin prediction) {
    _predictionOrigin = prediction;
    startedAt = prediction.startedAt;
    endedAt = prediction.endedAt;
    startedAtInput = formatSleepTime(startedAt);
    endedAtInput = formatSleepTime(endedAt);
    startPrecision = TimePrecision.approximate;
    endPrecision = TimePrecision.approximate;
  }

  void setNote(String value) {
    if (!editable) return;
    note = value;
    _noteProvided = true;
    _persist();
  }

  void setPrecision({TimePrecision? start, TimePrecision? end}) {
    if (!editable) return;
    if (start != null) startPrecision = start;
    if (end != null) endPrecision = end;
    _persist();
  }

  String? get timeError {
    if (startedAt == null || endedAt == null) return '请填写有效的入睡和醒来日期时间。';
    if (startedAt! >= endedAt!) return '醒来时间必须晚于入睡时间。';
    return null;
  }

  String? get noteError =>
      note.trim().runes.length > 2000 ? '备注最多 2000 个字符。' : null;

  bool get valid =>
      type != null &&
      startPrecision != null &&
      endPrecision != null &&
      timeError == null &&
      noteError == null;

  SleepDraft get draft => SleepDraft(
    context: context,
    startedAt: startedAt,
    endedAt: endedAt,
    startPrecision: startPrecision,
    endPrecision: endPrecision,
    type: type,
    startedAtInput: startedAtInput,
    endedAtInput: endedAtInput,
    note: note,
    noteProvided: _noteProvided,
    predictionOrigin: _predictionOrigin,
  );

  void _persist() {
    submitError = null;
    conflicts = const [];
    final input = draft;
    final baseline = _baseline;
    final revision = ++_revision;
    saving = true;
    storageError = null;
    _emit();
    _writes = _writes.then((_) async {
      try {
        if (baseline != null && _sameSleepDraft(input, baseline)) {
          await store.clear(context);
        } else {
          await store.save(input);
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

  Future<SleepLedger?> submit() async {
    if (!editable ||
        (context.isEditing ? entryEditor == null : entrySaver == null)) {
      return null;
    }
    submitError = null;
    conflicts = const [];
    if (!valid) {
      submitError = noteError ?? '请确认睡眠类型、起止时间和精度后再保存。';
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
      final result = context.isEditing
          ? await entryEditor!.save(draft, original: original!)
          : await entrySaver!.submit(draft);
      switch (result) {
        case SleepSubmitFailed(:final conflicts, :final notFound):
          this.conflicts = conflicts;
          missingOriginal = notFound;
          submitError = notFound
              ? '记录已不存在，无法更正；当前输入仍保留。'
              : conflicts.isEmpty
              ? '正式保存失败，当前睡眠输入仍保留，请重试。'
              : '时间与已有记录冲突，请手动调整后再保存。';
          return null;
        case SleepSubmitCommitted():
          committed = result;
          return result.complete ? result.refreshed : null;
      }
    } finally {
      submitting = false;
      _emit();
    }
  }

  Future<SleepLedger?> delete() async {
    if (!editable || entryEditor == null || original == null) return null;
    submitting = true;
    submitError = null;
    conflicts = const [];
    _emit();
    try {
      if (!await flush()) {
        submitError = '本次填写尚未保留成功，请重试。';
        return null;
      }
      final result = await entryEditor!.delete(
        context: context,
        original: original!,
      );
      switch (result) {
        case SleepDeleteFailed():
          submitError = '删除失败，睡眠记录与当前输入仍保留，请重试。';
          return null;
        case SleepDeleteCommitted():
          deleted = result;
          return result.complete ? result.refreshed : null;
      }
    } finally {
      submitting = false;
      _emit();
    }
  }

  Future<SleepLedger?> retryFinish() async {
    if (_disposed || submitting) return null;
    final previousDelete = deleted;
    if (previousDelete != null) {
      if (previousDelete.complete || entryEditor == null) return null;
      submitting = true;
      _emit();
      try {
        deleted = await entryEditor!.finishDelete(
          context: context,
          draftCleared: previousDelete.draftCleared,
          refreshDates: previousDelete.refreshDates,
        );
        return deleted!.complete ? deleted!.refreshed : null;
      } finally {
        submitting = false;
        _emit();
      }
    }
    final previous = committed;
    final saver = context.isEditing ? entryEditor?.saver : entrySaver;
    if (previous == null || previous.complete || saver == null) return null;
    submitting = true;
    _emit();
    try {
      committed = await saver.finishCommitted(
        context: context,
        sleepSession: previous.sleepSession,
        draftCleared: previous.draftCleared,
        refreshDates: previous.refreshDates,
      );
      return committed!.complete ? committed!.refreshed : null;
    } finally {
      submitting = false;
      _emit();
    }
  }

  bool get postCommit => committed != null || deleted != null;
  bool get finishPending =>
      (committed != null && !committed!.complete) ||
      (deleted != null && !deleted!.complete);

  String? get committedMessage {
    if (!postCommit) return null;
    final action = deleted != null ? '删除' : '保存';
    final cleared = deleted?.draftCleared ?? committed!.draftCleared;
    final refreshed = deleted?.refreshComplete ?? committed!.refreshComplete;
    if (cleared && refreshed) return deleted != null ? '睡眠已删除。' : '睡眠已保存到账本。';
    if (!cleared && !refreshed) {
      return '睡眠已$action，但本地收尾和摘要 / 账本刷新失败；请继续处理，无需再次$action。';
    }
    return cleared
        ? '睡眠已$action，但摘要 / 账本刷新失败；请继续刷新，无需再次$action。'
        : '睡眠已$action，但本地收尾失败；请继续处理，无需再次$action。';
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
    if (_disposed ||
        loading ||
        discarding ||
        _discarded ||
        submitting ||
        postCommit) {
      return false;
    }
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _sameSleepDraft(SleepDraft a, SleepDraft b) =>
    a.startedAt == b.startedAt &&
    a.endedAt == b.endedAt &&
    a.startPrecision == b.startPrecision &&
    a.endPrecision == b.endPrecision &&
    a.type == b.type &&
    a.startedAtInput == b.startedAtInput &&
    a.endedAtInput == b.endedAtInput &&
    a.note == b.note &&
    a.noteProvided == b.noteProvided &&
    a.predictionOrigin == b.predictionOrigin;
