import 'package:flutter/material.dart';

import '../../domain/time_block.dart';

/// 理解层顶部的事实摘要：刚保存（或正在补充）的这笔记录本身。
///
/// 时间范围 + 标题；标题为空时只显示时间，提醒用户正在解释哪一笔事实。
class UnderstandingFactSummary extends StatelessWidget {
  const UnderstandingFactSummary({super.key, required this.fact});

  final TimeBlock fact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = fact.title?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${_clock(fact.startedAt)} → ${_clock(fact.endedAt)}',
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text('·', style: TextStyle(fontSize: 13, color: colors.outline)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _clock(int value) {
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)}';
  }
}

/// 理解层的三步进度：目标 → 状态 → 补充。
///
/// 走过的步骤显示对勾，当前步骤高亮；系统返回可回到上一步。
class UnderstandingStepBar extends StatelessWidget {
  const UnderstandingStepBar({super.key, required this.stage});

  /// 'goal' / 'status' / 'details'。
  final String stage;

  static const _labels = ['目标', '状态', '补充'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = switch (stage) {
      'status' => 1,
      'details' => 2,
      _ => 0,
    };
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: i <= current ? colors.primary : colors.outlineVariant,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(colors, done: i < current, active: i == current),
              const SizedBox(width: 6),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == current ? FontWeight.w600 : FontWeight.w400,
                  color: i <= current
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dot(ColorScheme colors, {required bool done, required bool active}) {
    final base = done || active ? colors.primary : colors.outlineVariant;
    if (done) {
      return Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(color: base, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 10, color: colors.onPrimary),
      );
    }
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : Colors.transparent,
        border: Border.all(color: base, width: 2),
      ),
    );
  }
}

/// 理解层的统一选项卡：目标、状态、跳过与“暂时说不清”共用。
///
/// [selected] 为选择型卡片的选中态；[action] 为动作型卡片（较弱底色、
/// 行尾箭头），例如“不关联目标”“暂时说不清”。
class UnderstandingOptionTile extends StatelessWidget {
  const UnderstandingOptionTile({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    this.selected = false,
    this.action = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final bool action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = selected
        ? colors.secondaryContainer
        : action
        ? colors.surfaceContainer
        : colors.surfaceContainerHigh;
    final iconBackground = selected
        ? colors.primary
        : colors.surfaceContainerHighest;
    final iconColor = selected ? colors.onPrimary : colors.onSurfaceVariant;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle
                    : (action ? Icons.chevron_right : Icons.radio_button_off),
                size: selected ? 22 : 20,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 紧凑选项（两列网格用）：小图标 + 标签 + 选中对勾。
class UnderstandingCompactOption extends StatelessWidget {
  const UnderstandingCompactOption({
    super.key,
    this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 15, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 两列选项网格：同一行两块，行距与列距一致。
class UnderstandingOptionGrid extends StatelessWidget {
  const UnderstandingOptionGrid({
    super.key,
    required this.children,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// 可展开的补充卡：图标圆底 + 标题 +（折叠时的已填摘要）+ 展开箭头；
/// 展开后在卡片内显示输入框。
class UnderstandingNoteCard extends StatelessWidget {
  const UnderstandingNoteCard({
    super.key,
    required this.icon,
    required this.label,
    required this.open,
    required this.onTap,
    this.value,
    this.child,
  });

  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback? onTap;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = value?.trim();
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 19, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        if (!open && preview != null && preview.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (open && child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: child,
            ),
        ],
      ),
    );
  }
}
