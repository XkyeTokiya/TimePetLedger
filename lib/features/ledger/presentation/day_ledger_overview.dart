import 'package:flutter/material.dart';

import '../application/recording_ledger_loader.dart';
import '../domain/projection/day_ledger_view.dart';
import '../domain/projection/reconciliation_window.dart';
import 'day_ledger_time_bar.dart';
import 'recording_form.dart';
import 'summary_formatting.dart';

class DayLedgerOverview extends StatelessWidget {
  const DayLedgerOverview({
    super.key,
    required this.view,
    required this.dateContext,
    this.compact = false,
  });
  final DayLedgerView view;
  final RecordingDateContext dateContext;
  final bool compact;

  static Future<void> showExplanation(
    BuildContext context, {
    required DayLedgerView view,
    required RecordingDateContext dateContext,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('时间分布说明'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '设备时区：${DateTime.fromMillisecondsSinceEpoch(dateContext.dayStartedAt).timeZoneName}',
          ),
          DayLedgerOverview(view: view, dateContext: dateContext),
          const Text('想不起来是已交代的事实；尚未记录是派生缺口。时间条按实际时长分布，列表行高不是时间比例。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = switch (dateContext.relation) {
      LedgerDateRelation.today =>
        '截至 ${formatRecordingTime(dateContext.now).split(' ').last}',
      LedgerDateRelation.historical =>
        '${formatRecordingTime(dateContext.dayStartedAt)}'
            ' → ${formatRecordingTime(dateContext.nextDayStartedAt)}',
      LedgerDateRelation.future => '未来日期，暂无对账窗口',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact || dateContext.relation != LedgerDateRelation.historical)
          Text(range, style: theme.textTheme.bodySmall?.copyWith(fontSize: 13)),
        SizedBox(height: compact ? 8 : 16),
        LayoutBuilder(
          builder: (context, constraints) {
            Widget value(String label, String value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: compact ? 13 : 16,
                  ),
                ),
                SizedBox(height: compact ? 0 : 8),
                Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                    children: [
                      for (final part in RegExp(r'\d+|\D+').allMatches(value))
                        TextSpan(
                          text: part.group(0),
                          style: RegExp(r'^\d+$').hasMatch(part.group(0)!)
                              ? theme.textTheme.headlineLarge?.copyWith(
                                  fontSize: compact ? 28 : 32,
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
              ],
            );
            final accounted = value(
              '已交代',
              formatDerivedDuration(view.accountedDuration),
            );
            final unresolved = value(
              '尚未记录',
              formatDerivedDuration(view.unresolvedDuration),
            );
            if (constraints.maxWidth <
                MediaQuery.textScalerOf(context).scale(compact ? 260 : 320)) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [accounted, const SizedBox(height: 16), unresolved],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: accounted),
                const SizedBox(width: 16),
                Expanded(child: unresolved),
              ],
            );
          },
        ),
        if (!compact) const SizedBox(height: 8),
        if (compact && view.unknownDuration.milliseconds > 0)
          InkWell(
            onTap: () =>
                showExplanation(context, view: view, dateContext: dateContext),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '其中想不起来 ${formatDerivedDuration(view.unknownDuration)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ),
                  const SizedBox(
                    width: 48,
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                ],
              ),
            ),
          )
        else if (!compact)
          Text(
            '其中想不起来：${formatDerivedDuration(view.unknownDuration)}（已含在已交代中）',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
          ),
        if (!compact) const SizedBox(height: 24),
        DayLedgerTimeBar(
          view: view,
          dateContext: dateContext,
          showLegend: !compact,
        ),
      ],
    );
  }
}
