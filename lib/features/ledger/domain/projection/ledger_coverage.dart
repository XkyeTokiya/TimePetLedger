import '../../../../core/time/time_contract.dart';
import '../block_knowledge_state.dart';
import '../time_precision.dart';
import 'derived_duration.dart';
import 'ledger_segment.dart';
import 'reconciliation_window.dart';

/// 窗口中尚未处理的正时长空隙；无持久化身份，不是 Unknown 事实。
final class UnresolvedSpan {
  const UnresolvedSpan._({
    required this.startedAt,
    required this.endedAt,
    required this.startPrecision,
    required this.endPrecision,
  });

  final InstantMilliseconds startedAt;
  final InstantMilliseconds endedAt;
  final TimePrecision startPrecision;
  final TimePrecision endPrecision;

  DerivedDuration get duration => DerivedDuration(
    milliseconds: intervalMilliseconds(startedAt: startedAt, endedAt: endedAt),
    hasApproximation:
        startPrecision == TimePrecision.approximate ||
        endPrecision == TimePrecision.approximate,
  );
}

/// 同一对账窗口的覆盖与补集，不持久化、不表达完成率（LEDGER-001–005）。
final class LedgerCoverage {
  const LedgerCoverage._({
    required this.window,
    required this.unresolvedSpans,
    required this.accountedDuration,
    required this.unknownDuration,
    required this.unresolvedDuration,
  });

  final ReconciliationWindow window;
  final List<UnresolvedSpan> unresolvedSpans;
  final DerivedDuration accountedDuration;

  /// 已交代时长的子集，不能再次加到 accountedDuration 上。
  final DerivedDuration unknownDuration;
  final DerivedDuration unresolvedDuration;
}

/// 从同一 window 的全部主要事实切片计算覆盖与 Gap。
///
/// 调用方传入 projectLedgerSegments 的完整输出，不按 Goal 或节奏筛选。
/// 输入沿用合法、不重叠的事实前提，且所有切片属于该窗口；本函数不
/// 定义非法重叠的容错、合并或修复行为。复制后排序，不修改输入集合。
/// annotation 不另占时长；Unknown 与睡眠均属于已覆盖区域。
LedgerCoverage projectLedgerCoverage({
  required ReconciliationWindow window,
  required Iterable<LedgerSegment> segments,
}) {
  final ordered = segments.toList()
    ..sort((left, right) => left.startedAt.compareTo(right.startedAt));
  final gaps = <UnresolvedSpan>[];
  var cursor = window.startedAt;
  var cursorPrecision = TimePrecision.exact;

  for (final segment in ordered) {
    if (cursor < segment.startedAt) {
      gaps.add(
        UnresolvedSpan._(
          startedAt: cursor,
          endedAt: segment.startedAt,
          startPrecision: cursorPrecision,
          endPrecision: segment.startPrecision,
        ),
      );
    }
    cursor = segment.endedAt;
    cursorPrecision = segment.endPrecision;
  }
  if (cursor < window.endedAt) {
    gaps.add(
      UnresolvedSpan._(
        startedAt: cursor,
        endedAt: window.endedAt,
        startPrecision: cursorPrecision,
        endPrecision: TimePrecision.exact,
      ),
    );
  }

  return LedgerCoverage._(
    window: window,
    unresolvedSpans: List.unmodifiable(gaps),
    accountedDuration: DerivedDuration.sum(
      ordered.map((part) => part.duration),
    ),
    unknownDuration: DerivedDuration.sum(
      ordered
          .whereType<TimeBlockSegment>()
          .where(
            (part) => part.source.knowledgeState == BlockKnowledgeState.unknown,
          )
          .map((part) => part.duration),
    ),
    // 即使数值等于窗口减覆盖，近似也必须从实际 Gap 独立求得（Q-014）。
    unresolvedDuration: DerivedDuration.sum(gaps.map((gap) => gap.duration)),
  );
}
