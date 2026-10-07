import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';

void main() {
  test('warm ledger palette and typography remain the app-wide baseline', () {
    expect(homeTheme.scaffoldBackgroundColor, HomePalette.paper);
    expect(homeTheme.colorScheme.primary, HomePalette.accentDeep);
    expect(homeTheme.colorScheme.surface, HomePalette.paper);
    expect(homeTheme.colorScheme.onSurface, HomePalette.ink);
    expect(homeTheme.dividerColor, HomePalette.hairline);
    final text = homeTheme.textTheme;
    expect(text.bodyMedium?.fontFamily, homeSerifFamily);
    expect(text.displayLarge?.fontSize, 48);
    expect(text.headlineLarge?.fontSize, 32);
    expect(text.titleLarge?.fontSize, 20);
    expect(text.titleMedium?.fontSize, 16);
    expect(text.titleMedium?.fontWeight, FontWeight.w600);
    expect(text.bodyLarge?.fontSize, 17);
    expect(text.bodyMedium?.fontSize, 15);
    expect(text.bodySmall?.fontSize, 13);
    expect(text.labelMedium?.fontSize, 13);
  });

  test('layout tokens use the documented scale and accessible target', () {
    expect(
      const [
        TimeLedgerSpacing.xxs,
        TimeLedgerSpacing.xs,
        TimeLedgerSpacing.sm,
        TimeLedgerSpacing.md,
        TimeLedgerSpacing.lg,
        TimeLedgerSpacing.xl,
        TimeLedgerSpacing.xxl,
      ],
      const [4, 8, 12, 16, 20, 24, 32],
    );
    expect(TimeLedgerSpacing.page, 20);
    expect(TimeLedgerRadius.compact, 8);
    expect(TimeLedgerRadius.panel, 10);
    expect(homeTapTarget, 48);
    expect(homeTheme.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}
