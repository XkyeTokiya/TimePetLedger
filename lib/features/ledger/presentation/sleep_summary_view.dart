import 'package:flutter/material.dart';

import '../domain/projection/derived_duration.dart';
import '../domain/projection/sleep_summary.dart';
import '../domain/time_precision.dart';
import '../domain/sleep_session.dart';
import 'sleep_time_input.dart';
import 'summary_formatting.dart';

/// Complete facts grouped by wake date; never substitute day-slice durations.
class SleepSummaryView extends StatelessWidget {
  const SleepSummaryView({
    super.key,
    required this.summary,
    this.onEdit,
    this.foldRecords = false,
  });
  final SleepSummary summary;
  final ValueChanged<SleepSession>? onEdit;

  /// 首页摘要用：单条记录与更正入口收进 ExpansionTile，合计保持可见。
  final bool foldRecords;

  String _boundary(int time, TimePrecision precision) => formatSleepTime(time);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in [
        (
          label: '主睡眠',
          kind: SummaryDurationKind.mainSleep,
          data: summary.mainSleep,
        ),
        (label: '小睡', kind: SummaryDurationKind.nap, data: summary.nap),
      ]) ...[
        const SizedBox(height: 16),
        if (foldRecords && group.data.records.isNotEmpty)
          ExpansionTile(
            key: ValueKey('sleep-summary-${group.kind.name}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              group.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              formatSummaryDuration(group.data.totalDuration, kind: group.kind),
            ),
            children: [for (final sleep in group.data.records) _record(sleep)],
          )
        else ...[
          Text(group.label, style: Theme.of(context).textTheme.titleMedium),
          Text(
            formatSummaryDuration(group.data.totalDuration, kind: group.kind),
          ),
          for (final sleep in group.data.records) _record(sleep),
        ],
      ],
    ],
  );

  Widget _record(SleepSession sleep) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${_boundary(sleep.startedAt, sleep.startPrecision)} → ${_boundary(sleep.endedAt, sleep.endPrecision)} · 完整时长 ${formatDerivedDuration(DerivedDuration(milliseconds: sleep.endedAt - sleep.startedAt, hasApproximation: sleep.startPrecision == TimePrecision.approximate || sleep.endPrecision == TimePrecision.approximate))}',
      ),
      if (onEdit != null)
        TextButton(
          key: ValueKey('sleep-edit-${sleep.id}'),
          onPressed: () => onEdit!(sleep),
          child: const Text('更正 / 删除'),
        ),
    ],
  );
}
