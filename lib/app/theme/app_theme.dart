import 'package:flutter/material.dart';

import '../../features/settings/domain/app_preferences.dart';
import 'home_theme.dart';
import 'semantic_colors.dart';

/// 预设配色种子（实施前合同 §2.1）。
const Map<ThemeScheme, int> themeSchemeSeeds = {
  ThemeScheme.blue: 0xFF0B57D0,
  ThemeScheme.green: 0xFF146C2E,
  ThemeScheme.orange: 0xFFE8710A,
  ThemeScheme.teal: 0xFF006A6A,
};

/// 默认 M3 基准配色（framework 默认 scheme，浅 primary #6750A4）。
ColorScheme defaultM3ColorScheme(Brightness brightness) =>
    brightness == Brightness.light
    ? ThemeData(useMaterial3: true).colorScheme
    : ThemeData(useMaterial3: true, brightness: Brightness.dark).colorScheme;

/// 解析配色方案 → ColorScheme；暖纸由 [buildWarmPaperTheme] 构建。
ColorScheme schemeForTheme({
  required ThemeScheme scheme,
  required Brightness brightness,
  ColorScheme? dynamicScheme,
}) {
  switch (scheme) {
    case ThemeScheme.defaultM3:
      return defaultM3ColorScheme(brightness);
    case ThemeScheme.dynamic:
      return dynamicScheme ?? defaultM3ColorScheme(brightness);
    case ThemeScheme.warmPaper:
      throw ArgumentError('warmPaper 通过 buildWarmPaperTheme 构建');
    case ThemeScheme.blue:
    case ThemeScheme.green:
    case ThemeScheme.orange:
    case ThemeScheme.teal:
      return ColorScheme.fromSeed(
        seedColor: Color(themeSchemeSeeds[scheme]!),
        brightness: brightness,
      );
  }
}

/// 预览用的浅色方案（含暖纸；动态返回默认 M3 基线）。
ColorScheme previewLightScheme(ThemeScheme scheme) {
  if (scheme == ThemeScheme.warmPaper) {
    return buildWarmPaperTheme(
      brightness: Brightness.light,
      fontChoice: AppFontChoice.system,
    ).colorScheme;
  }
  if (scheme == ThemeScheme.dynamic) {
    return defaultM3ColorScheme(Brightness.light);
  }
  return schemeForTheme(scheme: scheme, brightness: Brightness.light);
}

/// 构建应用主题：配色 + 明暗 + 字体（Q-041 合同 §2）。
///
/// M3 预设使用默认组件样式并附派生语义色；暖纸复用固定主题规格。
ThemeData buildAppTheme({
  required ThemeScheme scheme,
  required Brightness brightness,
  AppFontChoice fontChoice = AppFontChoice.system,
  ColorScheme? dynamicScheme,
}) {
  if (scheme == ThemeScheme.warmPaper) {
    return buildWarmPaperTheme(brightness: brightness, fontChoice: fontChoice);
  }
  final colors = schemeForTheme(
    scheme: scheme,
    brightness: brightness,
    dynamicScheme: dynamicScheme,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    fontFamily: fontChoice == AppFontChoice.serif ? homeSerifFamily : null,
    extensions: [colors.defaultSemanticColors],
  );
}
