import 'package:flutter/material.dart';

import '../../features/settings/domain/app_preferences.dart';
import 'semantic_colors.dart';

/// App-wide visual tokens taken from the confirmed home reference
/// (docs/planning/assets/home-summary-round-one/home-reference.png).
///
/// The historical `Home` name is retained to avoid a repository-wide rename.
/// [homeTheme] is the warm-paper default; [buildWarmPaperTheme] renders the
/// optional warm-paper light / dark pair. See `design.md` for the contract.
class HomePalette {
  const HomePalette._();

  static const paper = Color(0xFFFCF9F4);
  static const ink = Color(0xFF241F1A);
  static const muted = Color(0xFF6C625A);
  static const faint = Color(0xFF9A9088);
  static const hairline = Color(0xFFE1D3C4);
  static const accent = Color(0xFFB65F48);
  static const accentDeep = Color(0xFF9C4A35);
  static const tint = Color(0xFFF4E8DC);
  static const sleep = Color(0xFF7E8FA0);
  static const activity = Color(0xFFB08968);
  static const unknown = Color(0xFF8A8177);
  static const gap = Color(0xFF9A9088);
  static const recovery = Color(0xFF6D7E64);
  static const error = Color(0xFF9C3325);
  static const errorSurface = Color(0xFFF9E9E1);
}

/// The shared spacing scale. Components may combine adjacent steps, but should
/// not introduce one-off values without a layout-specific reason.
class TimeLedgerSpacing {
  const TimeLedgerSpacing._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = lg;
}

class TimeLedgerRadius {
  const TimeLedgerRadius._();

  static const compact = 8.0;
  static const panel = 10.0;
}

/// Bundled Simplified-Chinese serif declared in pubspec (`NotoSerifSC`).
const String homeSerifFamily = 'NotoSerifSC';

/// Standard home controls retain a 48dp target. Proportional timeline data
/// rectangles use the explicit Q-039 small-target exception, with independent
/// semantics, keyboard focus and a 48dp-row disambiguation panel.
const double homeTapTarget = 48;

/// 暖纸浅色语义色：沿用 design.md §3 / 实施前合同 §2.3 的固定值。
const warmPaperSemanticColors = TimeLedgerSemanticColors(
  activity: HomePalette.activity,
  sleep: HomePalette.sleep,
  unknown: HomePalette.unknown,
  gap: HomePalette.gap,
  recovery: HomePalette.recovery,
  heatmapLevels: [
    Color(0xFFEEE0D8),
    Color(0xFFDFB6A5),
    Color(0xFFBF765E),
    Color(0xFF914C3A),
  ],
  heatmapLabels: [
    HomePalette.ink,
    HomePalette.ink,
    Color(0xFFFFF8F0),
    Color(0xFFFFF8F0),
  ],
);

/// 暖纸浅色配色方案；暖纸主题的唯一来源（Q-041 保留主题）。
const _warmLightScheme = ColorScheme.light(
  primary: HomePalette.accentDeep,
  onPrimary: Color(0xFFFFF8F4),
  primaryContainer: HomePalette.tint,
  onPrimaryContainer: HomePalette.ink,
  secondary: HomePalette.sleep,
  onSecondary: Color(0xFFFFF8F4),
  secondaryContainer: HomePalette.tint,
  onSecondaryContainer: HomePalette.ink,
  tertiary: HomePalette.unknown,
  onTertiary: Color(0xFFFFF8F4),
  surface: HomePalette.paper,
  onSurface: HomePalette.ink,
  onSurfaceVariant: HomePalette.muted,
  surfaceDim: HomePalette.paper,
  surfaceBright: HomePalette.paper,
  surfaceContainerLowest: HomePalette.paper,
  surfaceContainerLow: HomePalette.paper,
  surfaceContainer: HomePalette.tint,
  surfaceContainerHigh: HomePalette.tint,
  surfaceContainerHighest: HomePalette.tint,
  outline: HomePalette.faint,
  outlineVariant: HomePalette.hairline,
  error: HomePalette.error,
  onError: Color(0xFFFFF8F4),
  errorContainer: HomePalette.errorSurface,
  onErrorContainer: HomePalette.error,
  inverseSurface: HomePalette.ink,
  onInverseSurface: HomePalette.paper,
  inversePrimary: HomePalette.tint,
  surfaceTint: Colors.transparent,
);

/// 暖纸深色语义色（合同 §2.3 候选）：固定主题色 + 派生热力图档位。
TimeLedgerSemanticColors _warmDarkSemantics(ColorScheme colors) {
  final derived = colors.defaultSemanticColors;
  return TimeLedgerSemanticColors(
    activity: const Color(0xFFD9AE86),
    sleep: const Color(0xFFA9B9CA),
    unknown: const Color(0xFFB3A79C),
    gap: const Color(0xFF94897E),
    recovery: const Color(0xFF9FB891),
    heatmapLevels: derived.heatmapLevels,
    heatmapLabels: derived.heatmapLabels,
  );
}

/// 默认应用主题：暖纸浅色 + 衬线（历史名称保留，现有测试与页面继续使用）。
final ThemeData homeTheme = buildWarmPaperTheme(
  brightness: Brightness.light,
  fontChoice: AppFontChoice.serif,
);

/// 构建暖纸主题（浅 / 深），字体随 [fontChoice] 切换（Q-041）。
ThemeData buildWarmPaperTheme({
  required Brightness brightness,
  required AppFontChoice fontChoice,
}) {
  final light = brightness == Brightness.light;
  final colors = light
      ? _warmLightScheme
      : ColorScheme.fromSeed(
          seedColor: const Color(0xFFB65F48),
          brightness: Brightness.dark,
        );
  final semantics = light
      ? warmPaperSemanticColors
      : _warmDarkSemantics(colors);
  final family = fontChoice == AppFontChoice.serif ? homeSerifFamily : null;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    fontFamily: family,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: [semantics],
  );
  final text = base.textTheme
      .apply(
        fontFamily: family,
        bodyColor: colors.onSurface,
        displayColor: colors.onSurface,
      )
      .copyWith(
        displayLarge: TextStyle(
          fontFamily: family,
          fontSize: 48,
          height: 1.16,
          color: colors.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: family,
          fontSize: 32,
          height: 1.25,
          color: colors.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: family,
          fontSize: 28,
          height: 1.3,
          color: colors.onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: family,
          fontSize: 24,
          height: 1.35,
          color: colors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: family,
          fontSize: 17,
          height: 1.5,
          color: colors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: family,
          fontSize: 15,
          height: 1.5,
          color: colors.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: family,
          fontSize: 13,
          height: 1.5,
          color: colors.onSurfaceVariant,
        ),
        titleMedium: TextStyle(
          fontFamily: family,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: family,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleSmall: TextStyle(
          fontFamily: family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        labelLarge: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        labelMedium: TextStyle(
          fontFamily: family,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        labelSmall: TextStyle(
          fontFamily: family,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      );
  const pill = StadiumBorder();
  final minimumTarget = const WidgetStatePropertyAll(
    Size(homeTapTarget, homeTapTarget),
  );
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
    iconTheme: IconThemeData(color: colors.onSurfaceVariant, size: 26),
    dividerColor: colors.outlineVariant,
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: family,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: colors.outlineVariant,
      labelStyle: TextStyle(
        fontFamily: family,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: family, fontSize: 16),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: family,
        color: colors.onInverseSurface,
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: colors.onSurface,
      iconColor: colors.onSurfaceVariant,
      subtitleTextStyle: text.bodySmall,
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onPrimary
            : colors.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.primary
            : colors.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.outline,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintStyle: TextStyle(color: colors.onSurfaceVariant),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      errorStyle: TextStyle(color: colors.error),
      errorMaxLines: 8,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.primary,
      selectionColor: colors.surfaceContainerHighest,
      selectionHandleColor: colors.primary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        shape: const WidgetStatePropertyAll(pill),
        backgroundColor: WidgetStatePropertyAll(colors.primary),
        foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        shape: const WidgetStatePropertyAll(pill),
        foregroundColor: WidgetStatePropertyAll(colors.onSurface),
        side: WidgetStatePropertyAll(BorderSide(color: colors.outline)),
        textStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: WidgetStatePropertyAll(colors.primary),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: family, fontSize: 15),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: WidgetStatePropertyAll(colors.onSurface),
      ),
    ),
  );
}
