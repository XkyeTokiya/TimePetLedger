import 'package:flutter/material.dart';

import '../domain/projection/derived_duration.dart';
import '../domain/projection/sleep_summary.dart';
import '../domain/time_precision.dart';
import '../domain/sleep_session.dart';
import 'sleep_time_input.dart';
import 'summary_formatting.dart';

/// Complete facts grouped by wake date; never substitute day-slice durations.
class SleepSummaryView extends StatelessWidget {
  const SleepSummaryView({super.key, required this.summary, this.onEdit});
  final SleepSummary summary;
  final ValueChanged<SleepSession>? onEdit;

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
        Text(group.label, style: Theme.of(context).textTheme.titleMedium),
        Text(formatSummaryDuration(group.data.totalDuration, kind: group.kind)),
        for (final sleep in group.data.records) ...[
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
      ],
    ],
  );
}
