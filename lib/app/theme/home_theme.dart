import 'package:flutter/material.dart';

/// App-wide visual tokens taken from the confirmed home reference
/// (docs/planning/assets/home-summary-round-one/home-reference.png).
///
/// The historical `Home` name is retained to avoid a repository-wide rename.
/// New production UI should treat these values and [homeTheme] as the shared
/// app theme; see `design.md` for the usage contract.
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

final ThemeData homeTheme = _buildHomeTheme();

ThemeData _buildHomeTheme() {
  const colors = ColorScheme.light(
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
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: HomePalette.paper,
    fontFamily: homeSerifFamily,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final text = base.textTheme
      .apply(
        fontFamily: homeSerifFamily,
        bodyColor: HomePalette.ink,
        displayColor: HomePalette.ink,
      )
      .copyWith(
        displayLarge: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 48,
          height: 1.16,
          color: HomePalette.ink,
        ),
        headlineLarge: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 32,
          height: 1.25,
          color: HomePalette.ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 28,
          height: 1.3,
          color: HomePalette.ink,
        ),
        headlineSmall: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 24,
          height: 1.35,
          color: HomePalette.ink,
        ),
        bodyLarge: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 17,
          height: 1.5,
          color: HomePalette.ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 15,
          height: 1.5,
          color: HomePalette.ink,
        ),
        bodySmall: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 13,
          height: 1.5,
          color: HomePalette.muted,
        ),
        titleMedium: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: HomePalette.ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HomePalette.ink,
        ),
        titleSmall: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: HomePalette.ink,
        ),
        labelLarge: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: HomePalette.ink,
        ),
        labelMedium: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: HomePalette.ink,
        ),
        labelSmall: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: HomePalette.muted,
        ),
      );
  const pill = StadiumBorder();
  final minimumTarget = const WidgetStatePropertyAll(
    Size(homeTapTarget, homeTapTarget),
  );
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: homeSerifFamily),
    iconTheme: const IconThemeData(color: HomePalette.muted, size: 26),
    dividerColor: HomePalette.hairline,
    dividerTheme: const DividerThemeData(
      color: HomePalette.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: HomePalette.paper,
      foregroundColor: HomePalette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: HomePalette.ink,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: HomePalette.accentDeep,
      unselectedLabelColor: HomePalette.muted,
      indicatorColor: HomePalette.accentDeep,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: HomePalette.hairline,
      labelStyle: TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 16,
      ),
    ),
    cardTheme: const CardThemeData(
      color: HomePalette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: HomePalette.paper,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: HomePalette.paper,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: HomePalette.ink,
      contentTextStyle: TextStyle(
        fontFamily: homeSerifFamily,
        color: HomePalette.paper,
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: HomePalette.ink,
      iconColor: HomePalette.muted,
      subtitleTextStyle: text.bodySmall,
    ),
    switchTheme: SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? HomePalette.paper
            : HomePalette.faint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? HomePalette.accentDeep
            : HomePalette.tint,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : HomePalette.faint,
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: HomePalette.tint,
      labelStyle: TextStyle(color: HomePalette.muted),
      hintStyle: TextStyle(color: HomePalette.muted),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: HomePalette.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HomePalette.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HomePalette.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HomePalette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: HomePalette.error, width: 2),
      ),
      errorStyle: TextStyle(color: HomePalette.error),
      errorMaxLines: 8,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: HomePalette.accentDeep,
      selectionColor: HomePalette.tint,
      selectionHandleColor: HomePalette.accentDeep,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        shape: const WidgetStatePropertyAll(pill),
        backgroundColor: const WidgetStatePropertyAll(HomePalette.accentDeep),
        foregroundColor: const WidgetStatePropertyAll(Color(0xFFFFF8F4)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: homeSerifFamily,
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
        foregroundColor: const WidgetStatePropertyAll(HomePalette.ink),
        side: const WidgetStatePropertyAll(
          BorderSide(color: HomePalette.faint),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: homeSerifFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: const WidgetStatePropertyAll(HomePalette.accentDeep),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: homeSerifFamily, fontSize: 15),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: const WidgetStatePropertyAll(HomePalette.ink),
      ),
    ),
  );
}
