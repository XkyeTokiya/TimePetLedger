import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import '../domain/ledger_repository.dart';
import '../domain/projection/ledger_coverage.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/projection/reconciliation_window.dart';
import 'recording_time_suggestion.dart';

/// 一次加载使用的日期上下文；设备适配在 I/O 前同步解析，不缓存时区。
final class RecordingDateContext {
  RecordingDateContext({
    required CivilDate date,
    required this.relation,
    required this.now,
    required this.dayStartedAt,
    required this.nextDayStartedAt,
  }) : window = ReconciliationWindow.select(
         date: date,
         relation: relation,
         dayStartedAt: dayStartedAt,
         nextDayStartedAt: nextDayStartedAt,
         now: now,
       );

  final InstantMilliseconds dayStartedAt;
  final InstantMilliseconds nextDayStartedAt;
  final LedgerDateRelation relation;
  final InstantMilliseconds now;
  final ReconciliationWindow window;
}

typedef RecordingDateResolver = RecordingDateContext Function({
  required CivilDate date,
  required InstantMilliseconds now,
});

/// 仅供普通记录建议和刷新使用，不声称提供完整 DayLedgerView / 睡眠摘要。
final class RecordingLedger {
  const RecordingLedger._({
    required this.context,
    required this.facts,
    required this.segments,
    required this.coverage,
  });

  final RecordingDateContext context;
  final LedgerSnapshot facts;
  final List<LedgerSegment> segments;
  final LedgerCoverage coverage;
}

final class RecordingLedgerLoader {
  const RecordingLedgerLoader({
    required this.repository,
    required this.resolveDate,
  });

  final LedgerRepository repository;
  final RecordingDateResolver resolveDate;

  Future<RecordingTimeSuggestion> loadTimeSuggestion({
    required CivilDate date,
    required InstantMilliseconds now,
    UnresolvedSpan? explicitGap,
    bool preferClosedGaps = false,
  }) async {
    final context = resolveDate(date: date, now: now);
    final facts = await repository.readRecordingContext(
      startedAt: context.dayStartedAt,
      endedAt: context.nextDayStartedAt,
    );
    return suggestRecordingTimeFromFacts(
      relation: context.relation,
      now: now,
      dayStartedAt: context.dayStartedAt,
      nextDayStartedAt: context.nextDayStartedAt,
      facts: facts,
      explicitGap: explicitGap,
      preferClosedGaps: preferClosedGaps,
    );
  }

  /// 每次重新读取同一事务的完整相交事实，不混入草稿或过滤 Goal / 节奏。
  /// 调用方每次显式提供 now（包括保存后刷新）。失败原样抛出，不返回
  /// 空账本兜底；空窗口沿用 readWindow 的无需查库合同，不代表存储健康。
  /// 完整睡眠摘要还需独立候选查询，留待 Epic 5/8。
  Future<RecordingLedger> load({
    required CivilDate date,
    required InstantMilliseconds now,
  }) async {
    final context = resolveDate(date: date, now: now);
    final window = context.window;
    final facts = await repository.readWindow(
      startedAt: window.startedAt,
      endedAt: window.endedAt,
    );
    final segments = projectLedgerSegments(
      window: window,
      timeBlocks: facts.timeBlocks,
      sleepSessions: facts.sleepSessions,
      annotations: facts.annotations,
    );
    return RecordingLedger._(
      context: context,
      facts: facts,
      segments: segments,
      coverage: projectLedgerCoverage(window: window, segments: segments),
    );
  }
}
