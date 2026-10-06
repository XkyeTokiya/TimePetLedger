import '../block_knowledge_state.dart';
import 'derived_duration.dart';
import 'ledger_coverage.dart';
import 'ledger_segment.dart';

/// 一天时间构成的互斥部分，直接取自同一窗口的既有投影。
///
/// Persistence: NO。不新增事实源，不改变切片或覆盖算法；unknown 与 gap
/// 复用覆盖结果，不在此重算。各部分合计等于对账窗口 μ(W)：
/// sleep + knownActivity + unknown + gap。accountedDuration 等于前三项之和
/// （DERIVED_MODELS「同一窗口中的关系」）。
final class DayComposition {
  const DayComposition._({
    required this.sleep,
    required this.knownActivity,
    required this.unknown,
    required this.gap,
  });

  /// 当日窗口内的睡眠切片，不是完整睡眠摘要（Q-010）。
  final DerivedDuration sleep;

  /// 当日窗口内已知内容的 TimeBlock 切片。
  final DerivedDuration knownActivity;

  /// 已交代中内容未知的切片；已含在 accountedDuration，不重复相加。
  final DerivedDuration unknown;

  /// 派生缺口 G(W)；不参与已交代。
  final DerivedDuration gap;
}

/// 输入为同一窗口的切片与覆盖结果；不修改输入，不做 I/O。
DayComposition projectDayComposition({
  required LedgerCoverage coverage,
  required Iterable<LedgerSegment> segments,
}) {
  final parts = segments.toList();
  return DayComposition._(
    sleep: DerivedDuration.sum(
      parts.whereType<SleepSessionSegment>().map((part) => part.duration),
    ),
    knownActivity: DerivedDuration.sum(
      parts
          .whereType<TimeBlockSegment>()
          .where(
            (part) => part.source.knowledgeState == BlockKnowledgeState.known,
          )
          .map((part) => part.duration),
    ),
    unknown: coverage.unknownDuration,
    gap: coverage.unresolvedDuration,
  );
}
