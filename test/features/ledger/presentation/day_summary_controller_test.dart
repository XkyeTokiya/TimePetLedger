import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';

void main() {
  test('shared summary controller keeps full sleep separate from window contribution', () async {
    final start = DateTime(2026, 10, 1).millisecondsSinceEpoch;
    final sleep = SleepSession(
      id: '00000000-0000-4000-8000-000000000001',
      startedAt: start - 3600000,
      endedAt: start + 7 * 3600000,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      createdAt: 1,
      updatedAt: 1,
    );
    var instant = start + 8 * 3600000;
    final controller = DayLedgerController(
      loader: DayLedgerLoader(
        resolveDate: resolveDeviceRecordingDate,
        readFacts: (_) async => DayLedgerFacts(
          ledger: SleepLedgerSnapshot(
            windowFacts: LedgerSnapshot(
              timeBlocks: [],
              sleepSessions: [sleep],
              annotations: [],
            ),
            sleepSummaryCandidates: [sleep],
          ),
          goals: [],
        ),
      ),
      now: () => instant,
      dateOfInstant: deviceDateOfInstant,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final old = controller.view!;
    expect(controller.status, DayLedgerStatus.ready);
    expect(old.sleepSummary.mainSleep.totalDuration.milliseconds, 8 * 3600000);
    expect(old.accountedDuration.milliseconds, 7 * 3600000);
    expect(old.sleepSummary.mainSleep.totalDuration.hasApproximation, isTrue);
    expect(old.accountedDuration.hasApproximation, isFalse);
    instant = start + 3600000;
    await controller.refresh();
    expect(controller.view!.accountedDuration.milliseconds, 3600000);
    expect(
      controller.view!.sleepSummary.mainSleep.totalDuration.milliseconds,
      8 * 3600000,
    );
    expect(old.accountedDuration.milliseconds, 7 * 3600000);
  });
}
