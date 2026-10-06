import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../day_ledger_date_dialog.dart';

/// Top row: menu entry, product name, calendar entry (date picker).
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.busy,
    required this.onMenu,
    required this.onChooseDate,
  });

  final bool busy;
  final VoidCallback onMenu;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('home-menu'),
          tooltip: '更多',
          onPressed: busy ? null : onMenu,
          icon: const Icon(Icons.menu),
        ),
        const SizedBox(width: 4),
        Text('日账本', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        IconButton(
          key: const ValueKey('home-date'),
          tooltip: '选择日期',
          onPressed: busy ? null : onChooseDate,
          icon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    ),
  );
}

/// Oversized serif date with a relative label; year appears only across years.
class HomeDateTitle extends StatelessWidget {
  const HomeDateTitle({
    super.key,
    required this.date,
    required this.today,
    required this.busy,
    required this.onChooseDate,
    this.compact = false,
  });

  final CivilDate date;
  final CivilDate today;
  final bool busy;
  final VoidCallback onChooseDate;

  /// Short viewports (e.g. landscape phones) shrink the otherwise oversized date.
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, compact ? 2 : 8, 20, 0),
    child: GestureDetector(
      key: const ValueKey('ledger-date-picker'),
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onChooseDate,
      child: Container(
        alignment: Alignment.centerLeft,
        constraints: const BoxConstraints(minHeight: homeTapTarget),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(
              date.year == today.year
                  ? '${date.month}月${date.day}日'
                  : '${date.year}年${date.month}月${date.day}日',
              key: const ValueKey('home-date-title'),
              style: TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: compact ? 28 : 42,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: HomePalette.ink,
              ),
            ),
            Text(
              _relativeLabel(date, today),
              style: const TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 17,
                color: HomePalette.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _relativeLabel(CivilDate date, CivilDate today) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final index = DateTime.utc(date.year, date.month, date.day).weekday - 1;
  final weekday = index >= 0 && index < names.length ? names[index] : '所选日期';
  if (date == today) return '$weekday · 今天';
  if (date == adjacentLedgerDate(today, -1)) return '$weekday · 昨天';
  return weekday;
}
