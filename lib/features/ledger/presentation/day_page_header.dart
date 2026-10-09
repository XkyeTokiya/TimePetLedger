import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import 'home/home_timeline_tab.dart' show ledgerWeekdayText;

/// 独立页面（摘要 / 复盘）的日期头：各自管理日期，不与首页共享浏览状态。
class DayPageHeader extends StatelessWidget {
  const DayPageHeader({
    super.key,
    required this.date,
    required this.today,
    required this.busy,
    required this.dateKey,
    required this.onChoose,
    required this.onToday,
  });

  final CivilDate date;
  final CivilDate today;
  final bool busy;

  /// 供既有测试与无障碍入口定位的日期字段 key。
  final Key dateKey;
  final VoidCallback onChoose;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.4,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: InkWell(
              key: dateKey,
              onTap: busy ? null : onChoose,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          date.year == today.year
                              ? '${date.month}月${date.day}日'
                              : '${date.year}年${date.month}月${date.day}日',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        ledgerWeekdayText(date, today),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (date != today)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('page-back-to-today'),
                onPressed: busy ? null : onToday,
                child: const Text('回到今天'),
              ),
            ),
        ],
      ),
    ),
  );
}
