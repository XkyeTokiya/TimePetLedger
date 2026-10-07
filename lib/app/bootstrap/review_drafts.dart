import '../../core/persistence/database_connection.dart';
import '../../features/review/data/drift_review_draft_store.dart';
import '../../features/review/domain/review_draft_store.dart';

Future<DriftReviewDraftStore> openReviewDraftStore() async {
  try {
    return await DriftReviewDraftStore.open(
      await connectDatabase('time_pet_ledger_review_drafts'),
    );
  } on ReviewDraftStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(
      ReviewDraftStorageException(ReviewDraftOperation.open, error),
      stack,
    );
  }
}
