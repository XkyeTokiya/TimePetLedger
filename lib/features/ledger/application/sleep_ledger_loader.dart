import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_repository.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/projection/reconciliation_window.dart';
import '../domain/projection/sleep_summary.dart';
import 'recording_ledger_loader.dart';

/// 睡眠入口的读取结果；不持久化，不负责首次打开标记或提醒调度。
final class SleepLedger {
  const SleepLedger._({
    required this.context,
    required this.facts,
    required this.segments,
    required this.coverage,
    required this.sleepSummary,
    required this.recordedMainSleepToday,
  });

  final RecordingDateContext context;
  final SleepLedgerSnapshot facts;
  final List<LedgerSegment> segments;
  final LedgerCoverage coverage;
  final SleepSummary sleepSummary;

  /// 仅今天有判定结果；历史 / 未来日为 null，不能据此安排提醒。
  final bool? recordedMainSleepToday;
}

final class SleepLedgerLoader {
  const SleepLedgerLoader({
    required this.repository,
    required this.resolveDate,
  });

  final LedgerRepository repository;
  // 复用设备日期合同，不依赖普通编辑器、表单或草稿。
  final RecordingDateResolver resolveDate;

  /// now 显式提供，设备时区适配在 I/O 前完成；失败原样抛出，不以空集兜底。
  Future<SleepLedger> load({
    required CivilDate date,
    required InstantMilliseconds now,
  }) async {
    final context = resolveDate(date: date, now: now);
    final window = context.window;
    final facts = await repository.readSleepContext(
      startedAt: window.startedAt,
      endedAt: window.endedAt,
      dayStartedAt: context.dayStartedAt,
      nextDayStartedAt: context.nextDayStartedAt,
    );
    final segments = projectLedgerSegments(
      window: window,
      timeBlocks: facts.windowFacts.timeBlocks,
      sleepSessions: facts.windowFacts.sleepSessions,
      annotations: facts.windowFacts.annotations,
    );
    return SleepLedger._(
      context: context,
      facts: facts,
      segments: segments,
      coverage: projectLedgerCoverage(window: window, segments: segments),
      sleepSummary: projectSleepSummary(
        sleepSessions: facts.sleepSummaryCandidates,
        dayStartedAt: context.dayStartedAt,
        nextDayStartedAt: context.nextDayStartedAt,
      ),
      recordedMainSleepToday: context.relation == LedgerDateRelation.today
          ? hasRecordedMainSleepToday(
              sleepSessions: facts.sleepSummaryCandidates,
              dayStartedAt: context.dayStartedAt,
              nextDayStartedAt: context.nextDayStartedAt,
              now: context.now,
            )
          : null,
    );
  }
}
