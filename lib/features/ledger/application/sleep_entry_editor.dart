import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_repository.dart';
import '../domain/sleep_draft_store.dart';
import '../domain/sleep_session.dart';
import 'sleep_entry_saver.dart';
import 'sleep_ledger_loader.dart';

sealed class SleepDeleteResult {
  const SleepDeleteResult();
}

final class SleepDeleteFailed extends SleepDeleteResult {
  const SleepDeleteFailed();
}

final class SleepDeleteCommitted extends SleepDeleteResult {
  const SleepDeleteCommitted({
    required this.draftCleared,
    required this.refreshed,
    required this.refreshDates,
    required this.refreshedDates,
  });
  final bool draftCleared;
  final SleepLedger? refreshed;
  final List<CivilDate> refreshDates;
  final Map<CivilDate, SleepLedger> refreshedDates;
  bool get refreshComplete =>
      refreshed != null && refreshDates.every(refreshedDates.containsKey);
  bool get complete => draftCleared && refreshComplete;
}

/// Edits the complete source fact, preserving omitted note inside the write
/// transaction. The app supplies the current device's instant-to-date mapping.
final class SleepEntryEditor {
  const SleepEntryEditor({
    required this.repository,
    required this.drafts,
    required this.saver,
    required this.dateOfInstant,
  });
  final LedgerRepository repository;
  final SleepDraftStore drafts;
  final SleepEntrySaver saver;
  final CivilDate Function(InstantMilliseconds) dateOfInstant;

  Future<SleepSession?> load(EntityId id) => repository.readSleepSession(id);

  // The app holds one viewed day. Refresh it and both source/target boundary
  // and wake dates; other affected days have no cache and are read on access.
  List<CivilDate> _dates(
    SleepDraftContext context,
    SleepSession original, [
    SleepSession? updated,
  ]) => List.unmodifiable({
    context.date,
    dateOfInstant(original.startedAt),
    dateOfInstant(original.endedAt),
    if (updated != null) ...[
      dateOfInstant(updated.startedAt),
      dateOfInstant(updated.endedAt),
    ],
  });

  Future<SleepSubmitCommitted?> recoverCommittedEdit({
    required SleepDraft draft,
    required SleepSession original,
  }) async {
    final note = draft.note?.trim();
    if (draft.context.sleepSessionId != original.id ||
        draft.startedAt != original.startedAt ||
        draft.endedAt != original.endedAt ||
        draft.startPrecision != original.startPrecision ||
        draft.endPrecision != original.endPrecision ||
        draft.type != original.type ||
        (draft.noteProvided &&
            original.note != (note == null || note.isEmpty ? null : note))) {
      return null;
    }
    return saver.finishCommitted(
      context: draft.context,
      sleepSession: original,
      draftCleared: false,
      refreshDates: _dates(draft.context, original),
    );
  }

  Future<SleepSubmitResult> save(
    SleepDraft draft, {
    required SleepSession original,
  }) async {
    final id = draft.context.sleepSessionId;
    if (!draft.context.isEditing || id != original.id) {
      throw ArgumentError('Edit must identify its complete sleep source.');
    }
    if (draft.startedAt == null ||
        draft.endedAt == null ||
        draft.type == null ||
        draft.startPrecision == null ||
        draft.endPrecision == null) {
      return const SleepSubmitFailed();
    }
    late final SleepSession updated;
    try {
      updated = await repository.updateSleepSession(
        id: id!,
        now: saver.now(),
        startedAt: draft.startedAt!,
        endedAt: draft.endedAt!,
        startPrecision: draft.startPrecision!,
        endPrecision: draft.endPrecision!,
        type: draft.type!,
        note: draft.noteProvided ? (value: draft.note) : null,
      );
    } on LedgerConflictException catch (error) {
      return SleepSubmitFailed(conflicts: error.conflicts);
    } on LedgerFactNotFoundException {
      return const SleepSubmitFailed(notFound: true);
    } catch (_) {
      return const SleepSubmitFailed();
    }
    return saver.finishCommitted(
      context: draft.context,
      sleepSession: updated,
      draftCleared: false,
      refreshDates: _dates(draft.context, original, updated),
    );
  }

  Future<SleepDeleteResult> delete({
    required SleepDraftContext context,
    required SleepSession original,
  }) async {
    if (!context.isEditing || context.sleepSessionId != original.id) {
      throw ArgumentError('Deletion must identify its complete sleep source.');
    }
    try {
      await repository.deleteSleepSession(original.id);
    } catch (_) {
      return const SleepDeleteFailed();
    }
    return finishDelete(
      context: context,
      draftCleared: false,
      refreshDates: _dates(context, original),
    );
  }

  Future<SleepDeleteCommitted> finishDelete({
    required SleepDraftContext context,
    required bool draftCleared,
    required List<CivilDate> refreshDates,
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(context);
        cleared = true;
      } catch (_) {
        // Formal deletion already committed; independent cleanup can be retried.
      }
    }
    final views = await saver.refreshContexts(
      context: context,
      dates: refreshDates,
    );
    return SleepDeleteCommitted(
      draftCleared: cleared,
      refreshed: views[context.date],
      refreshDates: List.unmodifiable(refreshDates),
      refreshedDates: Map.unmodifiable(views),
    );
  }
}
