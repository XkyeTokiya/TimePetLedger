import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart' show homeTapTarget;
import '../../../../app/theme/theme_text.dart';
import '../../../../core/time/civil_date.dart';
import '../../../settings/domain/app_preferences.dart';
import 'home_ledger_style.dart';
import 'home_timeline_tab.dart' show ledgerWeekdayText;
import 'home_value_transition.dart';

/// Compact layout keeps all date controls, even when text requires two lines.
class HomeDateTitle extends StatefulWidget {
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
    this.showMenuButton = true,
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

  /// 日期行是否显示菜单按钮（默认显示，可在界面设置隐藏；隐藏后仍可
  /// 从屏幕边缘滑出快捷区）。
  final bool showMenuButton;

  @override
  State<HomeDateTitle> createState() => _HomeDateTitleState();
}

class _HomeDateTitleState extends State<HomeDateTitle> {
  _DateTitleMetrics? _metrics;

  @override
  void didUpdateWidget(HomeDateTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date || widget.today != oldWidget.today) {
      _metrics = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _metrics = null;
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final today = widget.today;
    final busy = widget.busy;
    final onChooseDate = widget.onChooseDate;
    final onShiftDay = widget.onShiftDay;
    final onToday = widget.onToday;
    final onMenu = widget.onMenu;
    final side = widget.side;
    final menuFocusNode = widget.menuFocusNode;
    final canShiftNext = widget.canShiftNext;
    final progress = widget.progress;
    final showMenuButton = widget.showMenuButton;
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
    final weekdayName = weekdayText.split(' · ').first;
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
        lerpDouble(8, 4, progress)!,
        lerpDouble(0, 4, progress)!,
        lerpDouble(8, 4, progress)!,
        12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = _metrics ??= _measure(
            context,
            dateText: dateText,
            weekdayText: weekdayText,
            weekdayName: weekdayName,
            weekdayStyle: weekdayStyle,
            dateStyle: dateStyle,
            base: base,
          );
          final weekdayWidths = [
            metrics.weekdayFullWidth,
            metrics.weekdayShortWidth,
            0.0,
          ];
          // 菜单（可选）+ 前后箭头始终占位；返回今天固定图标形式。
          final fixedWidths =
              (showMenuButton ? homeTapTarget : 0.0) + 2 * homeTapTarget;
          final buttonWidths = [homeTapTarget, homeTapTarget, 0.0];
          // 页头只有日期行：星期与返回今天都在同一行内取舍。两端点的行宽
          // 与字号不同，用屏幕宽推算两个稳定态的可用宽度；星期取能在展开
          // 态站住的最长形态，收放期间不变形。返回今天优先常显；只能站住
          // 紧凑态时随收放渐显；两端都放不下时先缩短星期再试（按钮优先于
          // 星期长度），最后才省略按钮（快捷区保留入口）。任何情况都不再
          // 出现第二行。
          final pad = lerpDouble(8, 4, progress)!;
          final screenWidth = constraints.maxWidth + 2 * pad;
          final expandedWidth = screenWidth - 16;
          final collapsedWidth = screenWidth - 8;
          bool fits({
            required bool expanded,
            required int weekday,
            required int button,
          }) {
            if (date == today && button != 2) return false;
            final available =
                (expanded ? expandedWidth : collapsedWidth) -
                fixedWidths -
                buttonWidths[button];
            final dateWidth = expanded
                ? metrics.expandedDateWidth
                : metrics.compactDateWidth;
            final weekdayWidth = weekdayWidths[weekday];
            final group = weekdayWidth > 0 ? 8 + weekdayWidth : 0.0;
            return available >= dateWidth + group;
          }

          final baseWeekday = [0, 1, 2].firstWhere(
            (weekday) => fits(expanded: true, weekday: weekday, button: 2),
            orElse: () => 2,
          );
          var weekdayForm = baseWeekday;
          var buttonAlways = false;
          var buttonCompactOnly = false;
          // 返回今天优先常显：从最长的星期形态开始，必要时缩短 / 隐藏
          // 星期以保住按钮（读屏仍播报完整星期）。
          for (final weekday in [0, 1, 2]) {
            if (weekday < baseWeekday) continue;
            if (fits(expanded: true, weekday: weekday, button: 0)) {
              weekdayForm = weekday;
              buttonAlways = true;
              break;
            }
          }
          if (!buttonAlways) {
            // 展开态实在放不下时退到紧凑态渐显，仍尽量保留较长的星期。
            for (final weekday in [0, 1, 2]) {
              if (weekday < baseWeekday) continue;
              if (fits(expanded: false, weekday: weekday, button: 0)) {
                weekdayForm = weekday;
                buttonCompactOnly = true;
                break;
              }
            }
          }
          final weekdayMessage = switch (weekdayForm) {
            0 => weekdayText,
            1 => weekdayName,
            _ => null,
          };
          final menu = showMenuButton
              ? IconButton(
                  key: const ValueKey('home-menu'),
                  focusNode: menuFocusNode,
                  tooltip: '菜单',
                  onPressed: busy ? null : onMenu,
                  icon: const Icon(Icons.menu, size: 24),
                )
              : null;
          final todayWidget = _TodayButton(busy: busy, onToday: onToday);
          final todayButton = buttonAlways
              ? todayWidget
              : buttonCompactOnly
              ? _CompactSlot(progress: progress, child: todayWidget)
              : null;
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
                  if (side == HomeQuickPanelSide.left && menu != null) menu,
                  if (side == HomeQuickPanelSide.right && todayButton != null)
                    todayButton,
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
                              child: weekdayMessage == null
                                  ? Semantics(
                                      label: weekdayText,
                                      child: _dateGroup(
                                        dateText: dateText,
                                        dateStyle: dateStyle,
                                        weekdayStyle: weekdayStyle,
                                      ),
                                    )
                                  : _dateGroup(
                                      dateText: dateText,
                                      dateStyle: dateStyle,
                                      weekdayStyle: weekdayStyle,
                                      weekdayMessage: weekdayMessage,
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
                  if (side == HomeQuickPanelSide.left && todayButton != null)
                    todayButton,
                  if (side == HomeQuickPanelSide.right && menu != null) menu,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  _DateTitleMetrics _measure(
    BuildContext context, {
    required String dateText,
    required String weekdayText,
    required String weekdayName,
    required TextStyle weekdayStyle,
    required TextStyle dateStyle,
    required double base,
  }) {
    final scale = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scale,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return _DateTitleMetrics(
      weekdayFullWidth: widthOf(weekdayText, weekdayStyle),
      weekdayShortWidth: widthOf(weekdayName, weekdayStyle),
      expandedDateWidth: widthOf(dateText, dateStyle.copyWith(fontSize: base)),
      compactDateWidth: widthOf(
        dateText,
        dateStyle.copyWith(fontSize: HomeLedgerStyle.compactDateSize),
      ),
    );
  }

  Widget _dateGroup({
    required String dateText,
    required TextStyle dateStyle,
    required TextStyle weekdayStyle,
    String? weekdayMessage,
  }) => Wrap(
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
      if (weekdayMessage != null) Text(weekdayMessage, style: weekdayStyle),
    ],
  );
}

class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.busy, required this.onToday});
  final bool busy;
  final VoidCallback onToday;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: homeTapTarget,
      height: homeTapTarget,
      child: IconButton(
        key: const ValueKey('home-back-to-today'),
        tooltip: '返回今天',
        onPressed: busy ? null : onToday,
        padding: EdgeInsets.zero,
        icon: Icon(Icons.today_outlined, color: colors.primary),
      ),
    );
  }
}

/// 过渡中先用同一最终控件占据逐步增长的宽度；只有稳定紧凑态才允许
/// 它接收焦点、语义和点击，避免返回今天在端点突然挤动日期。
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

/// 日期行的静态测量（与收放进度无关），按日期/主题/字号失效。
class _DateTitleMetrics {
  const _DateTitleMetrics({
    required this.weekdayFullWidth,
    required this.weekdayShortWidth,
    required this.expandedDateWidth,
    required this.compactDateWidth,
  });

  final double weekdayFullWidth;
  final double weekdayShortWidth;
  final double expandedDateWidth;
  final double compactDateWidth;
}
