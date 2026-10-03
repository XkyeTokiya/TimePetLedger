import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../domain/daily_review.dart';
import '../domain/daily_review_correction.dart';
import '../domain/review_draft_store.dart';
import '../domain/review_repository.dart';
import '../domain/review_text.dart';
import 'review_context_loader.dart';

typedef ReviewContextRefresh = Future<ReviewContext> Function({
  required CivilDate date,
  required int now,
});

enum ReviewSubmitFailure {
  invalidInput,
  dateOccupied,
  invalidGoal,
  missingSource,
  storage,
}

sealed class ReviewSubmitResult {
  const ReviewSubmitResult();
}

/// No formal write committed; retain all input and its draft.
final class ReviewSubmitFailed extends ReviewSubmitResult {
  const ReviewSubmitFailed(this.reason);
  final ReviewSubmitFailure reason;
}

/// Cleanup and read failures cannot undo a committed DailyReview.
final class ReviewSubmitCommitted extends ReviewSubmitResult {
  const ReviewSubmitCommitted({
    required this.review,
    required this.draftCleared,
    required this.refreshed,
  });
  final DailyReview review;
  final bool draftCleared;
  final ReviewContext? refreshed;
  bool get complete => draftCleared && refreshed != null;
}

sealed class ReviewDeleteResult {
  const ReviewDeleteResult();
}

final class ReviewDeleteFailed extends ReviewDeleteResult {
  const ReviewDeleteFailed();
}

/// The source identity is gone; only independent cleanup/read may be retried.
final class ReviewDeleteCommitted extends ReviewDeleteResult {
  const ReviewDeleteCommitted({
    required this.original,
    required this.draftCleared,
    required this.refreshed,
  });
  final DailyReview original;
  final bool draftCleared;
  final ReviewContext? refreshed;
  bool get complete => draftCleared && refreshed != null;
}

final class ReviewEntrySaver {
  const ReviewEntrySaver({
    required this.repository,
    required this.drafts,
    required this.refresh,
    required this.newId,
    required this.now,
  });
  final ReviewRepository repository;
  final ReviewDraftStore drafts;
  final ReviewContextRefresh refresh;
  final EntityId Function() newId;
  final int Function() now;

  Future<ReviewDeleteResult> delete({
    required ReviewDraftContext context,
    required DailyReview original,
  }) async {
    if (!context.isEditing || context.reviewId != original.id) {
      throw ArgumentError('Deletion must identify the original review.');
    }
    try {
      await repository.delete(original.id);
    } catch (_) {
      return const ReviewDeleteFailed();
    }
    return finishDelete(
      context: context,
      original: original,
      draftCleared: false,
    );
  }

  /// No formal write, including when the source date now has another review.
  Future<ReviewDeleteCommitted> finishDelete({
    required ReviewDraftContext context,
    required DailyReview original,
    required bool draftCleared,
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(context);
        cleared = true;
      } catch (_) {
        // Independent cleanup cannot reverse the committed deletion.
      }
    }
    ReviewContext? refreshed;
    try {
      // Return to the stored source date, not a date changed in unsaved input.
      final loaded = await refresh(date: original.date, now: now());
      if (loaded.ledger.date == original.date &&
          loaded.review?.id != original.id) {
        refreshed = loaded;
      }
    } catch (_) {
      // Keep the known deletion and frozen source identity for a read retry.
    }
    return ReviewDeleteCommitted(
      original: original,
      draftCleared: cleared,
      refreshed: refreshed,
    );
  }

  Future<ReviewSubmitResult> submit(ReviewDraft draft) async {
    if (draft.date == null) {
      return const ReviewSubmitFailed(ReviewSubmitFailure.invalidInput);
    }
    late final DailyReview review;
    try {
      // Both operations recheck current date/Goal constraints in one transaction.
      // An edit is a complete snapshot: null optional values explicitly clear.
      review = draft.context.isEditing
          ? await repository.update(
              id: draft.context.reviewId!,
              date: draft.date!,
              now: now(),
              summary: (value: draft.summary),
              reflection: (value: draft.reflection),
              tomorrowFirstStepText: draft.tomorrowFirstStepText ?? '',
              tomorrowFirstStepGoalId: (value: draft.tomorrowFirstStepGoalId),
            )
          : await repository.create(
              id: newId(),
              date: draft.date!,
              now: now(),
              summary: draft.summary,
              reflection: draft.reflection,
              tomorrowFirstStepText: draft.tomorrowFirstStepText ?? '',
              tomorrowFirstStepGoalId: draft.tomorrowFirstStepGoalId,
            );
    } on DailyReviewDateConflict {
      return const ReviewSubmitFailed(ReviewSubmitFailure.dateOccupied);
    } on ReviewNotFoundException {
      return const ReviewSubmitFailed(ReviewSubmitFailure.missingSource);
    } on ArgumentError catch (error) {
      return ReviewSubmitFailed(
        error.name == 'goal'
            ? ReviewSubmitFailure.invalidGoal
            : ReviewSubmitFailure.invalidInput,
      );
    } catch (_) {
      return const ReviewSubmitFailed(ReviewSubmitFailure.storage);
    }
    return finishCommitted(
      context: draft.context,
      review: review,
      draftCleared: false,
    );
  }

  /// Match every normalized field before treating a residual new-entry draft as
  /// already represented. Different existing content remains a date conflict.
  Future<ReviewSubmitCommitted?> recoverCommittedDraft(
    ReviewDraft draft,
  ) async {
    if (draft.context.isEditing || draft.date == null) return null;
    String? summary, reflection, step;
    try {
      summary = normalizeReviewText(draft.summary, 'summary');
      reflection = normalizeReviewText(draft.reflection, 'reflection');
      step = normalizeReviewText(draft.tomorrowFirstStepText, 'text');
    } on ArgumentError {
      return null;
    }
    if (step == null) return null;
    final existing = await repository.findByDate(draft.date!);
    if (existing == null ||
        existing.summary != summary ||
        existing.reflection != reflection ||
        existing.tomorrowFirstStep.text != step ||
        existing.tomorrowFirstStep.goalId != draft.tomorrowFirstStepGoalId) {
      return null;
    }
    return finishCommitted(
      context: draft.context,
      review: existing,
      draftCleared: false,
    );
  }

  /// This path has no create call, including when cleanup or refresh fails again.
  Future<ReviewSubmitCommitted> finishCommitted({
    required ReviewDraftContext context,
    required DailyReview review,
    required bool draftCleared,
  }) async {
    var cleared = draftCleared;
    if (!cleared) {
      try {
        await drafts.clear(context);
        cleared = true;
      } catch (_) {
        // Independent draft storage cannot roll back the formal transaction.
      }
    }
    ReviewContext? refreshed;
    try {
      final loaded = await refresh(date: review.date, now: now());
      // Missing or replaced facts must not be presented as a successful readback.
      if (loaded.review?.id == review.id && loaded.ledger.date == review.date) {
        refreshed = loaded;
      }
    } catch (_) {
      // Preserve the committed identity; a retry only reads/cleans up.
    }
    return ReviewSubmitCommitted(
      review: review,
      draftCleared: cleared,
      refreshed: refreshed,
    );
  }
}
