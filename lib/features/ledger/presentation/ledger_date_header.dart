import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import 'day_ledger_date_dialog.dart';

class LedgerDateHeader extends StatelessWidget {
  const LedgerDateHeader({
    super.key,
    required this.date,
    required this.today,
    required this.followToday,
    required this.busy,
    required this.onChoose,
    required this.onSelect,
    this.compact = false,
  });
  final CivilDate date;
  final CivilDate today;
  final bool followToday;
  final bool busy;
  final VoidCallback onChoose;
  final ValueChanged<CivilDate> onSelect;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String relative;
    if (date == today) {
      relative = '今天';
    } else if (date == adjacentLedgerDate(today, -1)) {
      relative = '昨天';
    } else {
      try {
        relative = [
          '星期一',
          '星期二',
          '星期三',
          '星期四',
          '星期五',
          '星期六',
          '星期日',
        ][DateTime.utc(date.year, date.month, date.day).weekday - 1];
      } on ArgumentError {
        relative = '所选日期';
      }
    }
    final dateButton = TextButton(
      key: const ValueKey('ledger-date-picker'),
      style: compact
          ? TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              padding: EdgeInsets.zero,
            )
          : null,
      onPressed: busy ? null : onChoose,
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.month}月${date.day}日 ${relative.replaceFirst('星期', '周')}',
                  style: const TextStyle(fontSize: 19),
                ),
                Text(
                  '${date.year}年',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            )
          : Text(
              '日期：${ledgerDateText(date)}',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
    );
    final previous = IconButton(
      tooltip: '前一天',
      onPressed: busy ? null : () => onSelect(adjacentLedgerDate(date, -1)),
      icon: const Icon(Icons.chevron_left),
    );
    final next = IconButton(
      tooltip: '后一天',
      onPressed: busy ? null : () => onSelect(adjacentLedgerDate(date, 1)),
      icon: const Icon(Icons.chevron_right),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final measure = TextPainter(
              text: TextSpan(
                text: compact
                    ? '${date.month}月${date.day}日 ${relative.replaceFirst('星期', '周')}'
                    : '日期：${ledgerDateText(date)}',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final neededWidth = measure.width + 24 + 2 * 48;
            measure.dispose();
            if (constraints.maxWidth < neededWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dateButton,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [previous, next],
                  ),
                ],
              );
            }
            return Row(
              children: [
                previous,
                Expanded(child: dateButton),
                next,
              ],
            );
          },
        ),
        if (!compact)
          Text(
            '$relative · ${followToday ? '跟随今天' : '固定日期'}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
          ),
      ],
    );
  }
}
