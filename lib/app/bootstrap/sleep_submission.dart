import '../../core/persistence/app_database.dart';
import '../../features/ledger/application/sleep_entry_saver.dart';
import '../../features/ledger/application/sleep_entry_editor.dart';
import '../time/device_recording_date.dart';
import '../../features/ledger/application/sleep_ledger_loader.dart';
import '../../features/ledger/data/drift_ledger_repository.dart';
import '../../features/ledger/domain/sleep_draft_store.dart';
import 'recording_submission.dart' show newLocalTimeBlockId;

SleepEntrySaver createSleepEntrySaver({
  required AppDatabase database,
  required SleepDraftStore drafts,
  required SleepLedgerLoader ledger,
  required DateTime Function() clock,
}) => SleepEntrySaver(
  repository: DriftLedgerRepository(database),
  drafts: drafts,
  refresh: ledger.load,
  // Reuse the existing app-local UUID v4 generator for this independent fact.
  newId: newLocalTimeBlockId,
  now: () => clock().millisecondsSinceEpoch,
);

SleepEntryEditor createSleepEntryEditor(SleepEntrySaver saver) =>
    SleepEntryEditor(
      repository: saver.repository,
      drafts: saver.drafts,
      saver: saver,
      dateOfInstant: deviceDateOfInstant,
    );
