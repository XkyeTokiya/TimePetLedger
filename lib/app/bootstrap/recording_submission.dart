import 'dart:math';

import '../../core/identity/entity_id.dart';
import '../../core/persistence/app_database.dart';
import '../../features/ledger/application/recording_entry_saver.dart';
import '../../features/ledger/application/recording_ledger_loader.dart';
import '../../features/ledger/data/drift_ledger_repository.dart';
import '../../features/ledger/domain/recording_draft_store.dart';

EntityId newLocalTimeBlockId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return hex
      .replaceRange(8, 8, '-')
      .replaceRange(13, 13, '-')
      .replaceRange(18, 18, '-')
      .replaceRange(23, 23, '-');
}

RecordingEntrySaver createRecordingEntrySaver({
  required AppDatabase database,
  required RecordingDraftStore drafts,
  required RecordingLedgerLoader ledger,
  required DateTime Function() clock,
}) => RecordingEntrySaver(
  repository: DriftLedgerRepository(database),
  drafts: drafts,
  refresh: ledger.load,
  newId: newLocalTimeBlockId,
  now: () => clock().millisecondsSinceEpoch,
);
