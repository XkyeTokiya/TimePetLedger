import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:dynamic_color_testing/dynamic_color_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/theme/semantic_colors.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('preset schemes resolve to contractual key colors', () {
    expect(
      schemeForTheme(
        scheme: ThemeScheme.defaultM3,
        brightness: Brightness.light,
      ).primary,
      const Color(0xFF6750A4),
    );
    expect(
      schemeForTheme(
        scheme: ThemeScheme.defaultM3,
        brightness: Brightness.dark,
      ).primary,
      const Color(0xFFD0BCFF),
    );
    expect(
      schemeForTheme(scheme: ThemeScheme.blue, brightness: Brightness.light),
      ColorScheme.fromSeed(seedColor: const Color(0xFF0B57D0)),
    );
    expect(
      schemeForTheme(scheme: ThemeScheme.teal, brightness: Brightness.dark),
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF006A6A),
        brightness: Brightness.dark,
      ),
    );
    expect(
      () => schemeForTheme(
        scheme: ThemeScheme.warmPaper,
        brightness: Brightness.light,
      ),
      throwsArgumentError,
    );
  });

  test('buildAppTheme carries semantics, font choice and warm pair', () {
    final m3 = buildAppTheme(
      scheme: ThemeScheme.green,
      brightness: Brightness.light,
    );
    expect(m3.useMaterial3, isTrue);
    expect(m3.extension<TimeLedgerSemanticColors>(), isNotNull);
    expect(m3.textTheme.bodyMedium?.fontFamily, isNot(homeSerifFamily));

    final serif = buildAppTheme(
      scheme: ThemeScheme.green,
      brightness: Brightness.light,
      fontChoice: AppFontChoice.serif,
    );
    expect(serif.textTheme.bodyMedium?.fontFamily, homeSerifFamily);

    final warm = buildAppTheme(
      scheme: ThemeScheme.warmPaper,
      brightness: Brightness.light,
      fontChoice: AppFontChoice.serif,
    );
    expect(warm.colorScheme.surface, HomePalette.paper);
    expect(warm.colorScheme.primary, HomePalette.accentDeep);
    expect(warm.scaffoldBackgroundColor, HomePalette.paper);
    expect(
      warm.extension<TimeLedgerSemanticColors>()?.activity,
      HomePalette.activity,
    );

    final warmDark = buildAppTheme(
      scheme: ThemeScheme.warmPaper,
      brightness: Brightness.dark,
    );
    expect(warmDark.colorScheme.brightness, Brightness.dark);
    expect(
      warmDark.extension<TimeLedgerSemanticColors>()?.activity,
      const Color(0xFFD9AE86),
    );
  });

  test('every theme family uses the unified outlined input style', () {
    // 2026-10-11 用户要求：输入框统一为描边 + 浮动标签（参考其他应用）。
    for (final scheme in const [
      ThemeScheme.defaultM3,
      ThemeScheme.blue,
      ThemeScheme.warmPaper,
    ]) {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(scheme: scheme, brightness: brightness);
        final input = theme.inputDecorationTheme;
        final colors = theme.colorScheme;
        expect(input.filled, isFalse, reason: '$scheme/$brightness');
        final enabled = input.enabledBorder! as OutlineInputBorder;
        expect(enabled.borderSide.color, colors.outlineVariant);
        final focused = input.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, colors.primary);
        expect(focused.borderSide.width, 2);
        final error = input.errorBorder! as OutlineInputBorder;
        expect(error.borderSide.color, colors.error);
        expect(input.floatingLabelStyle, isNotNull);
        expect(input.errorMaxLines, 8);
      }
    }
  });

  test('derived semantics keep heatmap labels readable for every scheme', () {
    for (final seed in const [
      0xFF6750A4,
      0xFF0B57D0,
      0xFF146C2E,
      0xFFE8710A,
      0xFF006A6A,
      0xFFB65F48,
    ]) {
      for (final brightness in const [Brightness.light, Brightness.dark]) {
        final scheme = ColorScheme.fromSeed(
          seedColor: Color(seed),
          brightness: brightness,
        );
        final semantics = scheme.defaultSemanticColors;
        expect(semantics.heatmapLevels.length, 4);
        expect(semantics.heatmapLabels.length, 4);
        for (var i = 0; i < 4; i++) {
          expect(
            _contrast(semantics.heatmapLabels[i], semantics.heatmapLevels[i]),
            greaterThanOrEqualTo(4.5),
            reason: 'seed=$seed brightness=$brightness level=$i',
          );
        }
      }
    }
  });

  testWidgets(
    'dynamic scheme selected without support falls back to default M3',
    (tester) async {
      final fallback = buildAppTheme(
        scheme: ThemeScheme.dynamic,
        brightness: Brightness.light,
      );
      expect(fallback.colorScheme, defaultM3ColorScheme(Brightness.light));

      DynamicColorTestingUtils.setMockDynamicColors(
        corePalette: SampleCorePalettes.green,
      );
      ColorScheme? dynamicLight;
      await tester.pumpWidget(
        DynamicColorBuilder(
          builder: (light, dark) {
            dynamicLight = light;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(dynamicLight, isNotNull);
      final themed = buildAppTheme(
        scheme: ThemeScheme.dynamic,
        brightness: Brightness.light,
        dynamicScheme: dynamicLight,
      );
      expect(themed.colorScheme, dynamicLight);
    },
  );
}
