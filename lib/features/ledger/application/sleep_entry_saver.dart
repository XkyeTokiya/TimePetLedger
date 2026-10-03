import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/ledger_repository.dart';
import '../domain/sleep_draft_store.dart';
import '../domain/sleep_session.dart';
import 'sleep_ledger_loader.dart';

typedef SleepLedgerRefresh = Future<SleepLedger> Function({
  required CivilDate date,
  required InstantMilliseconds now,
});

sealed class SleepSubmitResult {
  const SleepSubmitResult();
}

/// No formal fact committed; retain the draft for manual correction or retry.
final class SleepSubmitFailed extends SleepSubmitResult {
  const SleepSubmitFailed({this.conflicts = const [], this.notFound = false});
  final List<LedgerFactInterval> conflicts;
  final bool notFound;
}

/// Cleanup/read failures cannot undo the successful formal transaction.
final class SleepSubmitCommitted extends SleepSubmitResult {
  const SleepSubmitCommitted({
    required this.sleepSession,
    required this.draftCleared,
    required this.refreshed,
    this.refreshDates = const [],
    this.refreshedDates = const {},
  });
  final SleepSession sleepSession;
  final bool draftCleared;
  final SleepLedger? refreshed;
  final List<CivilDate> refreshDates;
  final Map<CivilDate, SleepLedger> refreshedDates;
  bool get refreshComplete =>
      refreshed != null && refreshDates.every(refreshedDates.containsKey);
  bool get complete => draftCleared && refreshComplete;
}

final class SleepEntrySaver {
  const SleepEntrySaver({
    required this.repository,
    required this.drafts,
    required this.refresh,
    required this.newId,
    required this.now,
  });
  final LedgerRepository repository;
  final SleepDraftStore drafts;
  final SleepLedgerRefresh refresh;
  final EntityId Function() newId;
  final InstantMilliseconds Function() now;

  /// Detect a residual draft already represented by the same complete fact.
  /// This recovery read never replaces the create transaction's conflict check.
  Future<SleepSubmitCommitted?> recoverCommittedDraft(SleepDraft draft) async {
    if (draft.context.isEditing || !_complete(draft)) return null;
    final facts = await repository.readWindow(
      startedAt: draft.startedAt!,
      endedAt: draft.endedAt!,
    );
    final note = draft.noteProvided ? draft.note?.trim() : null;
    for (final sleep in facts.sleepSessions) {
      if (sleep.startedAt == draft.startedAt &&
          sleep.endedAt == draft.endedAt &&
          sleep.startPrecision == draft.startPrecision &&
          sleep.endPrecision == draft.endPrecision &&
          sleep.type == draft.type &&
          sleep.note == (note == null || note.isEmpty ? null : note)) {
        return finishCommitted(
          context: draft.context,
          sleepSession: sleep,
          draftCleared: false,
        );
      }
    }
    return null;
  }

  bool _complete(SleepDraft draft) =>
      draft.startedAt != null &&
      draft.endedAt != null &&
      draft.startedAt! < draft.endedAt! &&
      draft.startPrecision != null &&
      draft.endPrecision != null &&
      draft.type != null;

  Future<SleepSubmitResult> submit(SleepDraft draft) async {
    if (draft.context.isEditing) {
      throw ArgumentError('Only new sleep drafts can be submitted here.');
    }
    if (!_complete(draft)) return const SleepSubmitFailed();
    late final SleepSession committed;
    try {
      committed = await repository.createSleepSession(
        id: newId(),
        startedAt: draft.startedAt!,
        endedAt: draft.endedAt!,
        startPrecision: draft.startPrecision!,
        endPrecision: draft.endPrecision!,
        type: draft.type!,
        note: draft.noteProvided ? draft.note : null,
        now: now(),
      );
    } on LedgerConflictException catch (error) {
      return SleepSubmitFailed(conflicts: error.conflicts);
    } catch (_) {
      return const SleepSubmitFailed();
    }
    return finishCommitted(
      context: draft.context,
      sleepSession: committed,
      draftCleared: false,
    );
  }

  Future<SleepSubmitCommitted> finishCommitted({
    required SleepDraftContext context,
    required SleepSession sleepSession,
    required bool draftCleared,
    List<CivilDate> refreshDates = const [],
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(context);
        cleared = true;
      } catch (_) {
        // The draft store is independent of the committed formal transaction.
      }
    }
    final views = await refreshContexts(context: context, dates: refreshDates);
    return SleepSubmitCommitted(
      sleepSession: sleepSession,
      draftCleared: cleared,
      refreshed: views[context.date],
      refreshDates: List.unmodifiable(refreshDates),
      refreshedDates: Map.unmodifiable(views),
    );
  }

  /// Every requested day is re-read; partial failure remains an explicit
  /// post-commit failure. Each day's facts/summary still use one read snapshot.
  Future<Map<CivilDate, SleepLedger>> refreshContexts({
    required SleepDraftContext context,
    required Iterable<CivilDate> dates,
  }) async {
    final views = <CivilDate, SleepLedger>{};
    final currentTime = now();
    for (final date in {context.date, ...dates}) {
      try {
        views[date] = await refresh(date: date, now: currentTime);
      } catch (_) {
        // An already committed mutation must never be offered again.
      }
    }
    return views;
  }
}
