import 'package:flutter/material.dart';

/// Visual tokens taken from the confirmed home reference
/// (docs/planning/assets/home-summary-round-one/home-reference.png).
///
/// Scoped to the rebuilt home for now; the previous [timeLedgerTheme] still
/// serves the pages that have not been rebuilt yet.
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

/// Bundled Simplified-Chinese serif declared in pubspec (`NotoSerifSC`).
const String homeSerifFamily = 'NotoSerifSC';

/// Minimum touch target used across the rebuilt home. The reference's 44px
/// visual minimum is raised to 48 so it also satisfies the Android
/// accessibility tap-target guideline the app is verified against.
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
