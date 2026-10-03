import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../../goals/domain/goal.dart';
import '../domain/ledger_repository.dart';
import '../domain/projection/day_ledger_view.dart';
import 'recording_ledger_loader.dart';

/// 正式事实和被引用目标须由组装层在同一读取事务中取得。
final class DayLedgerFacts {
  DayLedgerFacts({required this.ledger, required Iterable<Goal> goals})
    : goals = List.unmodifiable(goals);
  final SleepLedgerSnapshot ledger;
  final List<Goal> goals;
}

final class DayLedgerLoader {
  const DayLedgerLoader({required this.resolveDate, required this.readFacts});
  final RecordingDateResolver resolveDate;
  final Future<DayLedgerFacts> Function(RecordingDateContext) readFacts;

  Future<DayLedgerView> load({
    required CivilDate date,
    required InstantMilliseconds now,
  }) async {
    final context = resolveDate(date: date, now: now);
    final facts = await readFacts(context);
    final windowFacts = facts.ledger.windowFacts;
    return projectDayLedgerView(
      date: date,
      relation: context.relation,
      dayStartedAt: context.dayStartedAt,
      nextDayStartedAt: context.nextDayStartedAt,
      now: context.now,
      timeBlocks: windowFacts.timeBlocks,
      windowSleepSessions: windowFacts.sleepSessions,
      annotations: windowFacts.annotations,
      sleepSummaryCandidates: facts.ledger.sleepSummaryCandidates,
      goals: facts.goals,
    );
  }
}
