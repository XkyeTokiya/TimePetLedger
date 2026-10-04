import 'package:flutter/material.dart';

/// The single app palette, adopted in UI-N's visual portion for UI-T02.
/// Feature widgets consume ThemeData rather than depending on app assembly.
final ThemeData timeLedgerTheme = _buildTheme();

ThemeData _buildTheme() {
  const background = Color(0xff0e1c27);
  const surface = Color(0xff172a3a);
  const foreground = Color(0xfff3f6fa);
  const secondaryText = Color(0xffb5c6d9);
  const cyan = Color(0xff42e4dc);
  const divider = Color(0xff2a3c4c);
  const outline = Color(0xff7890a8);
  const disabledSurface = Color(0xff263a4a);
  const disabledText = Color(0xff9baab8);
  const error = Color(0xffffb4ab);
  const colors = ColorScheme.dark(
    primary: cyan,
    onPrimary: Color(0xff073036),
    primaryContainer: Color(0xff194c50),
    onPrimaryContainer: foreground,
    secondary: Color(0xff83a7ff),
    onSecondary: background,
    secondaryContainer: Color(0xff293d62),
    onSecondaryContainer: foreground,
    tertiary: Color(0xffb1bfd1),
    onTertiary: background,
    tertiaryContainer: Color(0xff314153),
    onTertiaryContainer: foreground,
    surface: surface,
    onSurface: foreground,
    onSurfaceVariant: secondaryText,
    surfaceDim: background,
    surfaceBright: surface,
    surfaceContainerLowest: background,
    surfaceContainerLow: background,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: surface,
    outline: outline,
    outlineVariant: divider,
    error: error,
    onError: Color(0xff3b1110),
    errorContainer: Color(0xff573330),
    onErrorContainer: error,
    inverseSurface: foreground,
    onInverseSurface: background,
    inversePrimary: Color(0xff006a66),
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final actionText = WidgetStateProperty.resolveWith<Color>(
    (states) => states.contains(WidgetState.disabled) ? disabledText : cyan,
  );
  const minimumTarget = WidgetStatePropertyAll(Size(48, 48));
  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ),
    iconTheme: const IconThemeData(color: secondaryText),
    disabledColor: disabledText,
    dividerColor: divider,
    focusColor: cyan.withValues(alpha: .18),
    appBarTheme: const AppBarThemeData(
      backgroundColor: background,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(color: surface),
    dialogTheme: const DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      textColor: foreground,
      subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: secondaryText,
      ),
      iconColor: secondaryText,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      labelStyle: const TextStyle(color: secondaryText),
      hintStyle: const TextStyle(color: secondaryText),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.error)
              ? error
              : states.contains(WidgetState.focused)
              ? cyan
              : secondaryText,
        ),
      ),
      errorStyle: const TextStyle(color: error),
      errorMaxLines: 8,
      border: inputBorder(outline),
      enabledBorder: inputBorder(outline),
      disabledBorder: inputBorder(divider),
      focusedBorder: inputBorder(cyan, 2),
      errorBorder: inputBorder(error),
      focusedErrorBorder: inputBorder(error, 2),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cyan,
      selectionColor: cyan.withValues(alpha: .3),
      selectionHandleColor: cyan,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? disabledSurface : cyan,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledText
              : colors.onPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const BorderSide(color: foreground, width: 2)
              : BorderSide.none,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: actionText,
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? divider
                : states.contains(WidgetState.focused)
                ? cyan
                : outline,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: actionText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: minimumTarget,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? disabledText
              : secondaryText,
        ),
      ),
    ),
  );
}
