import '../domain/annotation_change.dart';
import '../domain/recording_draft_store.dart';
import '../domain/rhythm_annotation.dart';

/// Translate only the explicit input intent; unchanged details stay omitted.
AnnotationChange recordingAnnotationChange(RecordingDraft draft) =>
    switch (draft.annotationIntent) {
      RecordingAnnotationIntent.keep => const KeepAnnotation(),
      RecordingAnnotationIntent.add => AddAnnotation(
        id: draft.annotationId!,
        state: draft.rhythmState!,
        continuationHint: draft.continuationHint,
        stuckReasonCode: draft.stuckReasonCode,
        stuckReasonText: draft.stuckReasonText,
        recoveryMethod: draft.recoveryMethod,
        recoveryQuality: draft.recoveryQuality,
      ),
      RecordingAnnotationIntent.edit => EditAnnotation(
        state: draft.rhythmState,
        stuckReasonCode: draft.stuckReasonCodeProvided
            ? (value: draft.stuckReasonCode)
            : null,
        stuckReasonText: draft.stuckReasonTextProvided
            ? (value: draft.stuckReasonText)
            : null,
        recoveryMethod: draft.recoveryMethodProvided
            ? (value: draft.recoveryMethod)
            : null,
        recoveryQuality: draft.recoveryQualityProvided
            ? (value: draft.recoveryQuality)
            : null,
        continuationHint: draft.hintProvided
            ? (value: draft.continuationHint)
            : null,
      ),
      RecordingAnnotationIntent.remove => const RemoveAnnotation(),
    };

/// Recovery must include annotation changes before clearing persisted input.
/// An add matches its stable draft id, so a competing add is not a commit.
bool recordingAnnotationMatches(
  RecordingDraft draft,
  RhythmAnnotation? current, {
  required bool isNewFact,
}) {
  final hint = draft.continuationHint?.trim();
  final normalizedHint = hint == null || hint.isEmpty ? null : hint;
  final reason = draft.stuckReasonText?.trim();
  final normalizedReason = reason == null || reason.isEmpty ? null : reason;
  bool detailsMatch({required bool adding}) =>
      (adding || draft.stuckReasonCodeProvided
          ? current!.stuckReasonCode == draft.stuckReasonCode
          : true) &&
      (adding || draft.stuckReasonTextProvided
          ? current!.stuckReasonText == normalizedReason
          : true) &&
      (adding || draft.recoveryMethodProvided
          ? current!.recoveryMethod == draft.recoveryMethod
          : true) &&
      (adding || draft.recoveryQualityProvided
          ? current!.recoveryQuality == draft.recoveryQuality
          : true);
  return switch (draft.annotationIntent) {
    RecordingAnnotationIntent.keep => !isNewFact || current == null,
    RecordingAnnotationIntent.remove => current == null,
    RecordingAnnotationIntent.add =>
      current != null &&
          draft.annotationId != null &&
          current.id == draft.annotationId &&
          current.state == draft.rhythmState &&
          current.continuationHint == normalizedHint &&
          detailsMatch(adding: true),
    RecordingAnnotationIntent.edit =>
      current != null &&
          (draft.rhythmState == null || current.state == draft.rhythmState) &&
          (!draft.hintProvided || current.continuationHint == normalizedHint) &&
          detailsMatch(adding: false),
  };
}
