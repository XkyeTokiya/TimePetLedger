import '../../../core/identity/entity_id.dart';
import '../domain/ledger_repository.dart';
import '../domain/recording_draft_store.dart';
import '../domain/time_block.dart';
import 'recording_entry_saver.dart';
import 'recording_ledger_loader.dart';
import 'recording_annotation_change.dart';
import '../domain/rhythm_annotation.dart';

sealed class RecordingDeleteResult {
  const RecordingDeleteResult();
}

final class RecordingDeleteFailed extends RecordingDeleteResult {
  const RecordingDeleteFailed();
}

final class RecordingDeleteCommitted extends RecordingDeleteResult {
  const RecordingDeleteCommitted({
    required this.draftCleared,
    required this.refreshed,
  });
  final bool draftCleared;
  final RecordingLedger? refreshed;
  bool get complete => draftCleared && refreshed != null;
}

/// Loads and mutates the complete source fact by id. Omitted hidden fields and
/// annotation are preserved by LedgerRepository.updateTimeBlock.
final class RecordingEntryEditor {
  const RecordingEntryEditor({
    required this.repository,
    required this.drafts,
    required this.saver,
  });
  final LedgerRepository repository;
  final RecordingDraftStore drafts;
  final RecordingEntrySaver saver;

  Future<TimeBlockWriteResult?> load(EntityId id) =>
      repository.readTimeBlock(id);

  Future<RecordingSubmitCommitted?> recoverCommittedEdit({
    required RecordingDraft draft,
    required TimeBlock original,
    RhythmAnnotation? annotation,
  }) {
    if (!_matches(draft, original) ||
        !recordingAnnotationMatches(draft, annotation, isNewFact: false)) {
      return Future.value();
    }
    return saver.finishCommitted(
      draftContext: draft.context,
      timeBlock: original,
      draftCleared: false,
    );
  }

  Future<RecordingSubmitResult> save(RecordingDraft draft) async {
    final id = draft.context.timeBlockId;
    if (draft.context.entry != RecordingDraftEntry.edit || id == null) {
      throw ArgumentError('An edit draft must identify a TimeBlock.');
    }
    late final TimeBlockWriteResult result;
    try {
      result = await repository.updateTimeBlock(
        id: id,
        now: saver.now(),
        startedAt: draft.startedAt!,
        endedAt: draft.endedAt!,
        startPrecision: draft.startPrecision,
        endPrecision: draft.endPrecision,
        knowledgeState: draft.knowledgeState!,
        title: (value: draft.title),
        note: draft.noteProvided ? (value: draft.note) : null,
        goalId: draft.goalProvided ? (value: draft.goalId) : null,
        annotation: recordingAnnotationChange(draft),
      );
    } on LedgerConflictException catch (error) {
      return RecordingSubmitFailed(conflicts: error.conflicts);
    } on LedgerFactNotFoundException {
      return const RecordingSubmitFailed(notFound: true);
    } on LedgerAnnotationOperationException catch (error) {
      return RecordingSubmitFailed(annotationFailure: error.reason);
    } catch (_) {
      return const RecordingSubmitFailed();
    }
    return saver.finishCommitted(
      draftContext: draft.context,
      timeBlock: result.timeBlock,
      draftCleared: false,
    );
  }

  Future<RecordingSubmitCommitted> finishCommitted({
    required RecordingDraftContext context,
    required TimeBlock timeBlock,
    required bool draftCleared,
  }) => saver.finishCommitted(
    draftContext: context,
    timeBlock: timeBlock,
    draftCleared: draftCleared,
  );

  Future<RecordingDeleteResult> delete(RecordingDraftContext context) async {
    final id = context.timeBlockId;
    if (context.entry != RecordingDraftEntry.edit || id == null) {
      throw ArgumentError('Deletion must identify a TimeBlock.');
    }
    try {
      await repository.deleteTimeBlock(id);
    } catch (_) {
      return const RecordingDeleteFailed();
    }
    return finishDelete(context: context, draftCleared: false);
  }

  Future<RecordingDeleteCommitted> finishDelete({
    required RecordingDraftContext context,
    required bool draftCleared,
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(context);
        cleared = true;
      } catch (_) {
        // Deletion already committed; retain this fact in the result.
      }
    }
    RecordingLedger? refreshed;
    try {
      refreshed = await saver.refresh(date: context.date, now: saver.now());
    } catch (_) {
      // A failed refresh cannot reverse a committed deletion.
    }
    return RecordingDeleteCommitted(
      draftCleared: cleared,
      refreshed: refreshed,
    );
  }
}

bool _matches(RecordingDraft draft, TimeBlock original) {
  final title = draft.title?.trim();
  final note = draft.note?.trim();
  return original.startedAt == draft.startedAt &&
      original.endedAt == draft.endedAt &&
      original.startPrecision == draft.startPrecision &&
      original.endPrecision == draft.endPrecision &&
      original.knowledgeState == draft.knowledgeState &&
      (!draft.goalProvided || original.goalId == draft.goalId) &&
      original.title == (title == null || title.isEmpty ? null : title) &&
      (!draft.noteProvided ||
          original.note == (note == null || note.isEmpty ? null : note));
}
