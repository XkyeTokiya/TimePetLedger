import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import 'sleep_ledger_loader.dart';

final class SleepFirstOpenResult {
  const SleepFirstOpenResult({
    required this.ledger,
    required this.shouldConfirm,
  });
  final SleepLedger ledger;
  final bool shouldConfirm;
}

/// Reads current facts before claiming a local opening. A marker suppresses
/// repeated prompting, but never substitutes for the E3 recorded-sleep result.
final class SleepFirstOpenCoordinator {
  const SleepFirstOpenCoordinator({
    required this.ledger,
    required this.claimOpening,
  });
  final SleepLedgerLoader ledger;
  final Future<bool> Function(CivilDate date) claimOpening;

  Future<SleepFirstOpenResult> check({
    required CivilDate date,
    required InstantMilliseconds now,
  }) async {
    final loaded = await ledger.load(date: date, now: now);
    final recorded = loaded.recordedMainSleepToday;
    if (recorded == null) {
      throw ArgumentError('First opening requires the current device date.');
    }
    final first = await claimOpening(date);
    return SleepFirstOpenResult(
      ledger: loaded,
      shouldConfirm: first && !recorded,
    );
  }
}
