import '../../core/persistence/app_database.dart';
import '../../features/review/application/review_context_loader.dart';
import '../../features/review/application/review_entry_saver.dart';
import '../../features/review/data/drift_review_repository.dart';
import '../../features/review/domain/review_draft_store.dart';
import 'recording_submission.dart' show newLocalTimeBlockId;

ReviewEntrySaver createReviewEntrySaver({
  required AppDatabase database,
  required ReviewDraftStore drafts,
  required ReviewContextLoader loader,
  required DateTime Function() clock,
}) => ReviewEntrySaver(
  repository: DriftReviewRepository(database),
  drafts: drafts,
  refresh: loader.load,
  newId: newLocalTimeBlockId,
  now: () => clock().millisecondsSinceEpoch,
);
