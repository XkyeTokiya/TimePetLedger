import '../../core/persistence/app_database.dart';
import '../../features/goals/data/drift_goal_repository.dart';
import '../../features/goals/domain/goal.dart';
import '../../features/ledger/application/day_ledger_loader.dart';
import '../../features/ledger/data/drift_ledger_repository.dart';
import '../time/device_recording_date.dart';

DayLedgerLoader createDayLedgerLoader(AppDatabase database) {
  final ledger = DriftLedgerRepository(database);
  final goals = DriftGoalRepository(database);
  return DayLedgerLoader(
    resolveDate: resolveDeviceRecordingDate,
    readFacts: (context) => database.transaction(() async {
      final facts = await ledger.readSleepContext(
        startedAt: context.window.startedAt,
        endedAt: context.window.endedAt,
        dayStartedAt: context.dayStartedAt,
        nextDayStartedAt: context.nextDayStartedAt,
      );
      final referenced = <Goal>[];
      final ids = facts.windowFacts.timeBlocks
          .map((block) => block.goalId)
          .whereType<String>()
          .toSet();
      for (final id in ids) {
        final goal = await goals.findById(id);
        if (goal == null) throw StateError('Missing referenced Goal.');
        referenced.add(goal);
      }
      return DayLedgerFacts(ledger: facts, goals: referenced);
    }),
  );
}
