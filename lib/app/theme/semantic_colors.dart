import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 主题语义色：睡眠 / 活动 / Unknown / Gap / 恢复与热力图档位。
///
/// M3 与动态配色从 ColorScheme 角色派生（合同 §2.3 / §2.4）；
/// 暖纸主题使用现行固定值。语义色随主题提供，页面不得复制色值，
/// 也不得用颜色作为唯一状态信号（Gap 虚线、Unknown 形状继续保留）。
@immutable
class TimeLedgerSemanticColors
    extends ThemeExtension<TimeLedgerSemanticColors> {
  const TimeLedgerSemanticColors({
    required this.activity,
    required this.sleep,
    required this.unknown,
    required this.gap,
    required this.recovery,
    required this.heatmapLevels,
    required this.heatmapLabels,
  });

  /// 普通活动 / 事实。
  final Color activity;

  /// 睡眠事实。
  final Color sleep;

  /// 已确认 Unknown。
  final Color unknown;

  /// 派生 Gap；与 Unknown 相近时必须同时用线型或形状区分。
  final Color gap;

  /// 恢复语义、成功反馈。
  final Color recovery;

  /// 热力图 1–4 档底色（<1h、1–2h、2–4h、≥4h）。
  final List<Color> heatmapLevels;

  /// 热力图 1–4 档文字色，与 [heatmapLevels] 一一对应。
  final List<Color> heatmapLabels;

  @override
  TimeLedgerSemanticColors copyWith({
    Color? activity,
    Color? sleep,
    Color? unknown,
    Color? gap,
    Color? recovery,
    List<Color>? heatmapLevels,
    List<Color>? heatmapLabels,
  }) => TimeLedgerSemanticColors(
    activity: activity ?? this.activity,
    sleep: sleep ?? this.sleep,
    unknown: unknown ?? this.unknown,
    gap: gap ?? this.gap,
    recovery: recovery ?? this.recovery,
    heatmapLevels: heatmapLevels ?? this.heatmapLevels,
    heatmapLabels: heatmapLabels ?? this.heatmapLabels,
  );

  @override
  TimeLedgerSemanticColors lerp(
    ThemeExtension<TimeLedgerSemanticColors>? other,
    double t,
  ) {
    if (other is! TimeLedgerSemanticColors) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length && i < b.length; i++)
        Color.lerp(a[i], b[i], t)!,
    ];
    return TimeLedgerSemanticColors(
      activity: Color.lerp(activity, other.activity, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      gap: Color.lerp(gap, other.gap, t)!,
      recovery: Color.lerp(recovery, other.recovery, t)!,
      heatmapLevels: lerpList(heatmapLevels, other.heatmapLevels),
      heatmapLabels: lerpList(heatmapLabels, other.heatmapLabels),
    );
  }
}

/// 读取当前主题语义色。
///
/// 主题显式提供扩展时直接使用（暖纸主题用固定值）；未提供时按合同 §2.3 /
/// §2.4 从当前 [ColorScheme] 派生（M3 / 动态配色的统一规则，也为未挑主题的
/// 局部测试提供确定结果，而不是静默失败或随机兜底）。
extension TimeLedgerSemanticColorsContext on BuildContext {
  TimeLedgerSemanticColors get semanticColors =>
      Theme.of(this).extension<TimeLedgerSemanticColors>() ??
      Theme.of(this).colorScheme.defaultSemanticColors;
}

/// 按合同从配色派生语义色与热力图档位。
extension TimeLedgerSemanticColorsScheme on ColorScheme {
  TimeLedgerSemanticColors get defaultSemanticColors {
    final levels = [
      for (final t in const [0.25, 0.5, 0.75, 1.0])
        Color.lerp(surfaceContainerHighest, primary, t)!,
    ];
    return TimeLedgerSemanticColors(
      activity: primary,
      sleep: tertiary,
      unknown: outline,
      gap: outlineVariant,
      recovery: secondary,
      heatmapLevels: levels,
      heatmapLabels: [
        for (final cell in levels) _bestLabelOn(cell, onSurface, onPrimary),
      ],
    );
  }
}

double _relativeLuminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 档位文字：优先主题色，不足 4.5 时用黑白中对比更高者（合同 §2.4）。
Color _bestLabelOn(Color cell, Color onSurface, Color onPrimary) {
  final themeBest = _contrast(onSurface, cell) >= _contrast(onPrimary, cell)
      ? onSurface
      : onPrimary;
  if (_contrast(themeBest, cell) >= 4.5) return themeBest;
  return _contrast(Colors.white, cell) >= _contrast(Colors.black, cell)
      ? Colors.white
      : Colors.black;
}
