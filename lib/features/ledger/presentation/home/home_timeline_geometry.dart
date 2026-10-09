import '../../domain/projection/day_ledger_view.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/projection/ledger_coverage.dart';
import '../../domain/projection/ledger_segment.dart';

/// Presentation geometry. Never rounds times or alters the projection window.
final class HomeTimelineGeometry {
  const HomeTimelineGeometry({required this.startedAt, this.a11yFactor = 1})
    : assert(a11yFactor >= 1 && a11yFactor <= 1.25);

  static const baseDpPerHour = 72.0;
  static const shortHeight = 32.0;
  static const textHeight = 12.0;
  final int startedAt;
  final double a11yFactor;
  double get dpPerHour => baseDpPerHour * a11yFactor;
  double y(int instant) => (instant - startedAt) / 3600000 * dpPerHour;
  double height(int start, int end) => (end - start) / 3600000 * dpPerHour;
  int instant(double y) => startedAt + (y / dpPerHour * 3600000).round();

  /// Half-open bounds, including at a shared boundary and excluding W.end.
  TimelineInterval? hit(List<TimelineInterval> intervals, double y) {
    if (y < 0) return null;
    for (final interval in intervals) {
      if (y >= this.y(interval.startedAt) && y < this.y(interval.endedAt)) {
        return interval;
      }
    }
    return null;
  }

  List<List<TimelineInterval>> shortClusters(List<TimelineInterval> intervals) {
    final result = <List<TimelineInterval>>[];
    var cluster = <TimelineInterval>[];
    for (final interval in intervals) {
      if (height(interval.startedAt, interval.endedAt) >= shortHeight) {
        if (cluster.isNotEmpty) result.add(List.unmodifiable(cluster));
        cluster = [];
        continue;
      }
      if (cluster.isNotEmpty && cluster.last.endedAt != interval.startedAt) {
        result.add(List.unmodifiable(cluster));
        cluster = [];
      }
      cluster.add(interval);
    }
    if (cluster.isNotEmpty) result.add(List.unmodifiable(cluster));
    return List.unmodifiable(result);
  }
}

/// One immutable UI candidate; references the original slice or derived Gap.
final class TimelineInterval {
  const TimelineInterval.fact(LedgerSegment value) : fact = value, gap = null;
  const TimelineInterval.gap(UnresolvedSpan value) : gap = value, fact = null;
  final LedgerSegment? fact;
  final UnresolvedSpan? gap;
  int get startedAt => fact?.startedAt ?? gap!.startedAt;
  int get endedAt => fact?.endedAt ?? gap!.endedAt;
  Object get id => fact?.reference ?? (startedAt, endedAt);
  DerivedDuration get duration => fact?.duration ?? gap!.duration;

  static List<TimelineInterval> fromView(DayLedgerView view) => [
    for (final fact in view.segments) TimelineInterval.fact(fact),
    for (final gap in view.unresolvedSpans) TimelineInterval.gap(gap),
  ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}
