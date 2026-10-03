import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_conflicts.dart';
import '../domain/ledger_repository.dart';
import '../domain/recording_draft_store.dart';
import '../domain/time_block.dart';
import 'recording_ledger_loader.dart';
import 'recording_annotation_change.dart';
import '../domain/annotation_change.dart';

typedef RecordingLedgerRefresh = Future<RecordingLedger> Function({
  required CivilDate date,
  required InstantMilliseconds now,
});

sealed class RecordingSubmitResult {
  const RecordingSubmitResult();
}

/// The formal transaction did not commit. The draft remains available.
final class RecordingSubmitFailed extends RecordingSubmitResult {
  const RecordingSubmitFailed({
    this.conflicts = const [],
    this.notFound = false,
    this.annotationFailure,
  });
  final List<LedgerFactInterval> conflicts;
  final bool notFound;
  final AnnotationOperationFailure? annotationFailure;
}

/// The formal fact committed. Cleanup and refresh can be retried without
/// issuing another createTimeBlock call.
final class RecordingSubmitCommitted extends RecordingSubmitResult {
  const RecordingSubmitCommitted({
    required this.timeBlock,
    required this.draftCleared,
    required this.refreshed,
  });
  final TimeBlock timeBlock;
  final bool draftCleared;
  final RecordingLedger? refreshed;
  bool get complete => draftCleared && refreshed != null;
}

/// Coordinates only a new ordinary TimeBlock. The repository retains the
/// atomic conflict check; draft cleanup occurs only after its commit result.
final class RecordingEntrySaver {
  const RecordingEntrySaver({
    required this.repository,
    required this.drafts,
    required this.refresh,
    required this.newId,
    required this.now,
  });

  final LedgerRepository repository;
  final RecordingDraftStore drafts;
  final RecordingLedgerRefresh refresh;
  final EntityId Function() newId;
  final InstantMilliseconds Function() now;

  /// A crash or draft-clear failure can leave the submitted input on disk.
  /// Recognize the same formal fact before offering another create action.
  /// This read is only recovery detection; the repository's transaction still
  /// performs the authoritative conflict check on every new submission.
  Future<RecordingSubmitCommitted?> recoverCommittedDraft(
    RecordingDraft draft,
  ) async {
    final start = draft.startedAt;
    final end = draft.endedAt;
    final knowledge = draft.knowledgeState;
    if (draft.context.entry == RecordingDraftEntry.edit ||
        start == null ||
        end == null ||
        start >= end ||
        knowledge == null) {
      return null;
    }
    final facts = await repository.readWindow(startedAt: start, endedAt: end);
    final normalizedTitle = draft.title?.trim();
    final normalizedNote = draft.note?.trim();
    for (final block in facts.timeBlocks) {
      if (block.startedAt == start &&
          block.endedAt == end &&
          block.startPrecision == draft.startPrecision &&
          block.endPrecision == draft.endPrecision &&
          block.knowledgeState == knowledge &&
          block.goalId == draft.goalId &&
          recordingAnnotationMatches(
            draft,
            facts.annotations
                .where((a) => a.timeBlockId == block.id)
                .firstOrNull,
            isNewFact: true,
          ) &&
          block.title ==
              (normalizedTitle == null || normalizedTitle.isEmpty
                  ? null
                  : normalizedTitle) &&
          block.note ==
              (normalizedNote == null || normalizedNote.isEmpty
                  ? null
                  : normalizedNote)) {
        return finishCommitted(
          draftContext: draft.context,
          timeBlock: block,
          draftCleared: false,
        );
      }
    }
    return null;
  }

  Future<RecordingSubmitResult> submit(RecordingDraft draft) async {
    if (draft.context.entry == RecordingDraftEntry.edit) {
      throw ArgumentError('Only new recording drafts can be submitted here.');
    }
    late final TimeBlockWriteResult committed;
    try {
      final change = recordingAnnotationChange(draft);
      if (change is EditAnnotation) {
        return const RecordingSubmitFailed(
          annotationFailure: AnnotationOperationFailure.notFound,
        );
      }
      committed = await repository.createTimeBlock(
        id: newId(),
        startedAt: draft.startedAt!,
        endedAt: draft.endedAt!,
        startPrecision: draft.startPrecision,
        endPrecision: draft.endPrecision,
        knowledgeState: draft.knowledgeState!,
        title: draft.title,
        note: draft.note,
        goalId: draft.goalId,
        annotation: change is AddAnnotation ? change : null,
        now: now(),
      );
    } on LedgerConflictException catch (error) {
      return RecordingSubmitFailed(conflicts: error.conflicts);
    } on LedgerAnnotationOperationException catch (error) {
      return RecordingSubmitFailed(annotationFailure: error.reason);
    } catch (_) {
      return const RecordingSubmitFailed();
    }
    return finishCommitted(
      draftContext: draft.context,
      timeBlock: committed.timeBlock,
      draftCleared: false,
    );
  }

  Future<RecordingSubmitCommitted> finishCommitted({
    required RecordingDraftContext draftContext,
    required TimeBlock timeBlock,
    required bool draftCleared,
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(draftContext);
        cleared = true;
      } catch (_) {
        // The formal commit cannot be undone by an independent draft store.
      }
    }
    RecordingLedger? refreshed;
    try {
      refreshed = await refresh(date: draftContext.date, now: now());
    } catch (_) {
      // A failed read does not make the already committed fact uncommitted.
    }
    return RecordingSubmitCommitted(
      timeBlock: timeBlock,
      draftCleared: cleared,
      refreshed: refreshed,
    );
  }
}
