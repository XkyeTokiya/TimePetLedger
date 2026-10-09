import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import 'home_ledger_style.dart';
import 'home_timeline_tab.dart' show ledgerWeekdayText;
import 'home_value_transition.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.busy,
    required this.onMenu,
    this.onToday,
  });
  final bool busy;
  final VoidCallback onMenu;
  final VoidCallback? onToday;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('home-menu'),
          tooltip: '菜单',
          onPressed: busy ? null : onMenu,
          icon: const Icon(Icons.menu, size: 24),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text('日账本', style: Theme.of(context).textTheme.titleMedium),
        ),
        if (onToday != null) ...[
          const SizedBox(width: 8),
          _TodayButton(busy: busy, onToday: onToday!),
        ],
      ],
    ),
  );
}

/// Compact layout keeps all date controls, even when text requires two lines.
class HomeDateTitle extends StatelessWidget {
  const HomeDateTitle({
    super.key,
    required this.date,
    required this.today,
    required this.busy,
    required this.onChooseDate,
    required this.onShiftDay,
    required this.onToday,
    required this.onMenu,
    this.progress = 0,
  });
  final CivilDate date;
  final CivilDate today;
  final bool busy;
  final VoidCallback onChooseDate;
  final ValueChanged<int> onShiftDay;
  final VoidCallback onToday;
  final VoidCallback onMenu;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final compact = progress == 1;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final base = largeText ? 24.0 : HomeLedgerStyle.dateSize;
    final fontSize = lerpDouble(
      base,
      HomeLedgerStyle.compactDateSize,
      progress,
    )!;
    final dateText = date.year == today.year
        ? '${date.month}月${date.day}日'
        : '${date.year}年${date.month}月${date.day}日';
    final dateStyle = TextStyle(
      fontFamily: homeSerifFamily,
      fontSize: fontSize,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: compact ? HomePalette.ink : HomePalette.accentDeep,
    );
    return Padding(
      key: ValueKey(compact ? 'home-header-collapsed' : 'home-header-expanded'),
      padding: EdgeInsets.fromLTRB(compact ? 4 : 16, compact ? 4 : 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Put today's shortcut in the navigation row when the actual text
          // fits. Large text / cross-year dates keep a second accessible row.
          final dateMeasure = TextPainter(
            text: TextSpan(text: dateText, style: dateStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final todayMeasure = TextPainter(
            text: const TextSpan(text: '回到今天', style: HomeLedgerStyle.button),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final inlineToday =
              compact &&
              date != today &&
              constraints.maxWidth >=
                  3 * homeTapTarget +
                      dateMeasure.width +
                      todayMeasure.width +
                      32;
          dateMeasure.dispose();
          todayMeasure.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (compact)
                    IconButton(
                      key: const ValueKey('home-menu'),
                      tooltip: '菜单',
                      onPressed: busy ? null : onMenu,
                      icon: const Icon(Icons.menu, size: 24),
                    ),
                  IconButton(
                    key: const ValueKey('home-previous-day'),
                    tooltip: '前一天',
                    onPressed: busy ? null : () => onShiftDay(-1),
                    icon: const Icon(Icons.chevron_left, size: 24),
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: InkWell(
                        key: const ValueKey('ledger-date-picker'),
                        onTap: busy ? null : onChooseDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: HomeValueTransition(
                            value: date,
                            child: Center(
                              child: Text(
                                dateText,
                                key: const ValueKey('home-date-title'),
                                textAlign: TextAlign.center,
                                style: dateStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home-next-day'),
                    tooltip: '后一天',
                    onPressed: busy ? null : () => onShiftDay(1),
                    icon: const Icon(Icons.chevron_right, size: 24),
                  ),
                  if (inlineToday) _TodayButton(busy: busy, onToday: onToday),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ledgerWeekdayText(date, today),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: HomePalette.muted,
                      ),
                    ),
                  ),
                  if (compact && date != today && !inlineToday)
                    _TodayButton(busy: busy, onToday: onToday),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.busy, required this.onToday});
  final bool busy;
  final VoidCallback onToday;
  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('home-back-to-today'),
    onPressed: busy ? null : onToday,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: HomeLedgerStyle.button,
      backgroundColor: HomePalette.tint,
      foregroundColor: HomePalette.accentDeep,
    ),
    child: const Text('回到今天'),
  );
}
