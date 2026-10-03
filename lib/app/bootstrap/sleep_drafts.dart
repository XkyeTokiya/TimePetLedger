import '../../core/persistence/database_connection.dart';
import '../../features/ledger/data/drift_sleep_draft_store.dart';
import '../../features/ledger/domain/sleep_draft_store.dart';

/// Caller owns this separately named persistent connection and must close it.
Future<DriftSleepDraftStore> openSleepDraftStore() async {
  try {
    return await DriftSleepDraftStore.open(
      await connectDatabase('time_pet_ledger_sleep_drafts'),
    );
  } on SleepDraftStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(
      SleepDraftStorageException(SleepDraftOperation.open, error),
      stack,
    );
  }
}
