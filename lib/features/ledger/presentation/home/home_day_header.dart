import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../day_ledger_date_dialog.dart';
import 'home_value_transition.dart';

/// Top row: menu entry and product name.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.busy, required this.onMenu});

  final bool busy;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('home-menu'),
          tooltip: '菜单',
          onPressed: busy ? null : onMenu,
          icon: const Icon(Icons.menu),
        ),
        const SizedBox(width: 4),
        Text('日账本', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
      ],
    ),
  );
}

/// 顶部日期：当前浏览日期 + 前后一天 + 日历入口；历史日期提供回到今天。
class HomeDateTitle extends StatelessWidget {
  const HomeDateTitle({
    super.key,
    required this.date,
    required this.today,
    required this.busy,
    required this.onChooseDate,
    required this.onShiftDay,
    required this.onToday,
    this.compact = false,
  });

  final CivilDate date;
  final CivilDate today;
  final bool busy;
  final VoidCallback onChooseDate;
  final ValueChanged<int> onShiftDay;
  final VoidCallback onToday;

  /// Short viewports (e.g. landscape phones) shrink the otherwise oversized date.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 370;
    final fontSize = compact ? 28.0 : (narrow ? 34.0 : 42.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 2 : 6, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // 日期随宽度缩小字体时仍保持 48 高的可点区域。
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: InkWell(
                    key: const ValueKey('ledger-date-picker'),
                    onTap: busy ? null : onChooseDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Flexible(
                            child: HomeValueTransition(
                              value: date,
                              height:
                                  MediaQuery.textScalerOf(context)
                                      .scale(fontSize) *
                                  1.15,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  date.year == today.year
                                      ? '${date.month}月${date.day}日'
                                      : '${date.year}年${date.month}月${date.day}日',
                                  key: const ValueKey('home-date-title'),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontFamily: homeSerifFamily,
                                    fontSize: fontSize,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                    color: HomePalette.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.expand_more,
                            size: 18,
                            color: HomePalette.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('home-previous-day'),
                tooltip: '前一天',
                onPressed: busy ? null : () => onShiftDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: const ValueKey('home-next-day'),
                tooltip: '后一天',
                onPressed: busy ? null : () => onShiftDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            // 固定行高：日期是否提供“回到今天”不再改变头部高度，避免
            // 视图高度与时间轴留白互相反馈。
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  HomeValueTransition(
                    value: _relativeLabel(date, today),
                    child: Text(
                      _relativeLabel(date, today),
                      style: const TextStyle(
                        fontFamily: homeSerifFamily,
                        fontSize: 13,
                        color: HomePalette.muted,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (date != today)
                    TextButton(
                      key: const ValueKey('home-back-to-today'),
                      onPressed: busy ? null : onToday,
                      child: const Text('回到今天'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeLabel(CivilDate date, CivilDate today) {
  const names = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final index = DateTime.utc(date.year, date.month, date.day).weekday - 1;
  final weekday = index >= 0 && index < names.length ? names[index] : '所选日期';
  if (date == today) return '$weekday · 今天';
  if (date == adjacentLedgerDate(today, -1)) return '$weekday · 昨天';
  return weekday;
}
