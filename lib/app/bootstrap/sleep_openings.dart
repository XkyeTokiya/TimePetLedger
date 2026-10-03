import '../../core/persistence/database_connection.dart';
import '../../features/ledger/data/drift_sleep_opening_store.dart';
import '../../features/ledger/domain/sleep_opening_store.dart';

/// App owns the connection; interaction state stays outside formal/draft tables.
Future<DriftSleepOpeningStore> openSleepOpeningStore() async {
  try {
    return await DriftSleepOpeningStore.open(
      await connectDatabase('time_pet_ledger_sleep_openings'),
    );
  } on SleepOpeningStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(SleepOpeningStorageException(error), stack);
  }
}
