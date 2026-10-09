import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart' show homeTapTarget;
import '../../../../app/theme/theme_text.dart';
import '../../../../core/time/civil_date.dart';
import '../../../settings/domain/app_preferences.dart';
import 'home_ledger_style.dart';
import 'home_timeline_tab.dart' show ledgerWeekdayText;
import 'home_value_transition.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.busy,
    required this.onMenu,
    this.side = HomeQuickPanelSide.left,
    this.menuFocusNode,
    this.onToday,
  });
  final bool busy;
  final VoidCallback onMenu;
  final HomeQuickPanelSide side;
  final FocusNode? menuFocusNode;
  final VoidCallback? onToday;
  @override
  Widget build(BuildContext context) {
    final menu = IconButton(
      key: const ValueKey('home-menu'),
      focusNode: menuFocusNode,
      tooltip: '菜单',
      onPressed: busy ? null : onMenu,
      icon: const Icon(Icons.menu, size: 24),
    );
    final today = onToday == null
        ? null
        : _TodayButton(busy: busy, onToday: onToday!);
    return Padding(
      padding: side == HomeQuickPanelSide.left
          ? const EdgeInsets.fromLTRB(4, 4, 16, 4)
          : const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          if (side == HomeQuickPanelSide.left) ...[
            menu,
            const SizedBox(width: 4),
          ] else if (today != null) ...[
            today,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              '日账本',
              textAlign: side == HomeQuickPanelSide.left
                  ? TextAlign.start
                  : TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (side == HomeQuickPanelSide.right) ...[
            const SizedBox(width: 4),
            menu,
          ] else if (today != null) ...[
            const SizedBox(width: 8),
            today,
          ],
        ],
      ),
    );
  }
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
    this.side = HomeQuickPanelSide.left,
    this.menuFocusNode,
    this.canShiftNext = true,
    this.progress = 0,
  });
  final CivilDate date;
  final CivilDate today;
  final bool busy;
  final VoidCallback onChooseDate;
  final ValueChanged<int> onShiftDay;
  final VoidCallback onToday;
  final VoidCallback onMenu;
  final HomeQuickPanelSide side;
  final FocusNode? menuFocusNode;
  final bool canShiftNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
    final weekdayText = ledgerWeekdayText(date, today);
    final weekdayStyle = TextStyle(
      fontSize: 12,
      height: 1.2,
      color: colors.onSurfaceVariant,
    );
    final dateStyle = withThemeFont(
      context,
      TextStyle(
        fontSize: fontSize,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: Color.lerp(colors.primary, colors.onSurface, progress),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        lerpDouble(16, 4, progress)!,
        lerpDouble(0, 4, progress)!,
        16,
        12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dateMeasure = TextPainter(
            text: TextSpan(text: dateText, style: dateStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final todayMeasure = TextPainter(
            text: TextSpan(
              text: '返回今天',
              style: withThemeFont(context, HomeLedgerStyle.button),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final weekdayMeasure = TextPainter(
            text: TextSpan(text: weekdayText, style: weekdayStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final expandedDateMeasure = TextPainter(
            text: TextSpan(
              text: dateText,
              style: dateStyle.copyWith(fontSize: base),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final compactDateMeasure = TextPainter(
            text: TextSpan(
              text: dateText,
              style: dateStyle.copyWith(
                fontSize: HomeLedgerStyle.compactDateSize,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final inlineToday =
              date != today &&
              constraints.maxWidth >=
                  3 * homeTapTarget +
                      dateMeasure.width +
                      todayMeasure.width +
                      32;
          // 星期默认并入日期行；展开与紧凑两个稳定头部状态都放得下才并入，
          // 避免收放动画中途在日期行和独立行之间来回切换。
          final widthExpanded = constraints.maxWidth - 12 * progress;
          final widthCollapsed = constraints.maxWidth + 12 * (1 - progress);
          final buttonWidth = date != today ? todayMeasure.width + 24 : 0.0;
          final inlineWeekday =
              widthExpanded - 2 * homeTapTarget >=
                  expandedDateMeasure.width +
                      8 +
                      weekdayMeasure.width +
                      buttonWidth &&
              widthCollapsed - 3 * homeTapTarget >=
                  compactDateMeasure.width +
                      8 +
                      weekdayMeasure.width +
                      buttonWidth;
          dateMeasure.dispose();
          todayMeasure.dispose();
          weekdayMeasure.dispose();
          expandedDateMeasure.dispose();
          compactDateMeasure.dispose();
          final menu = IconButton(
            key: compact ? const ValueKey('home-menu') : null,
            focusNode: compact ? menuFocusNode : null,
            tooltip: '菜单',
            onPressed: busy ? null : onMenu,
            icon: const Icon(Icons.menu, size: 24),
          );
          final todayButton = _TodayButton(
            busy: busy,
            onToday: onToday,
            buttonKey: compact ? const ValueKey('home-back-to-today') : null,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox.shrink(
                key: ValueKey(
                  compact ? 'home-header-collapsed' : 'home-header-expanded',
                ),
              ),
              Row(
                children: [
                  if (side == HomeQuickPanelSide.left)
                    _CompactSlot(progress: progress, child: menu),
                  if (inlineToday && side == HomeQuickPanelSide.right)
                    _CompactSlot(progress: progress, child: todayButton),
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
                              // Wrap keeps transient wider content (date
                              // switch, retained outgoing child) from
                              // overflowing: it wraps instead of erroring.
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    dateText,
                                    key: const ValueKey('home-date-title'),
                                    textAlign: TextAlign.center,
                                    style: dateStyle,
                                  ),
                                  if (inlineWeekday)
                                    Text(weekdayText, style: weekdayStyle),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home-next-day'),
                    tooltip: canShiftNext ? '后一天' : '已到浏览上限',
                    onPressed: busy || !canShiftNext
                        ? null
                        : () => onShiftDay(1),
                    icon: const Icon(Icons.chevron_right, size: 24),
                  ),
                  if (inlineToday && side == HomeQuickPanelSide.left)
                    _CompactSlot(progress: progress, child: todayButton),
                  if (side == HomeQuickPanelSide.right)
                    _CompactSlot(progress: progress, child: menu),
                ],
              ),
              // 星期并入日期行后，第二行只在仍需独立容纳“返回今天”时保留。
              if (!inlineWeekday || (date != today && !inlineToday)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (date != today &&
                        !inlineToday &&
                        side == HomeQuickPanelSide.right)
                      _CompactSlot(progress: progress, child: todayButton),
                    if (inlineWeekday)
                      const Spacer()
                    else
                      Expanded(
                        child: Text(
                          weekdayText,
                          textAlign: TextAlign.center,
                          style: weekdayStyle,
                        ),
                      ),
                    if (date != today &&
                        !inlineToday &&
                        side == HomeQuickPanelSide.left)
                      _CompactSlot(progress: progress, child: todayButton),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({
    required this.busy,
    required this.onToday,
    this.buttonKey = const ValueKey('home-back-to-today'),
  });
  final bool busy;
  final VoidCallback onToday;
  final Key? buttonKey;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      key: buttonKey,
      onPressed: busy ? null : onToday,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: withThemeFont(context, HomeLedgerStyle.button),
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.primary,
      ),
      child: const Text('返回今天'),
    );
  }
}

/// 过渡中先用同一最终控件占据逐步增长的宽度；只有稳定紧凑态才允许
/// 它接收焦点、语义和点击，避免菜单 / 返回今天在端点突然挤动日期。
class _CompactSlot extends StatelessWidget {
  const _CompactSlot({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Align(
      widthFactor: progress,
      child: Opacity(
        opacity: progress,
        child: IgnorePointer(
          ignoring: progress < 1,
          child: ExcludeSemantics(excluding: progress < 1, child: child),
        ),
      ),
    ),
  );
}
