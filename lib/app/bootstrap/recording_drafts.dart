import '../../core/persistence/database_connection.dart';
import '../../features/ledger/data/drift_recording_draft_store.dart';
import '../../features/ledger/domain/recording_draft_store.dart';

/// Dedicated persistent name, separate from time_pet_ledger's five fact tables.
/// The caller owns the returned store and must close it with its app lifecycle.
Future<DriftRecordingDraftStore> openRecordingDraftStore() async {
  try {
    return await DriftRecordingDraftStore.open(
      await connectDatabase('time_pet_ledger_recording_drafts'),
    );
  } on RecordingDraftStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(
      RecordingDraftStorageException(RecordingDraftOperation.open, error),
      stack,
    );
  }
}
