import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';
import 'package:time_pet_ledger/features/settings/domain/data_overview.dart';
import 'package:time_pet_ledger/features/settings/presentation/settings_page.dart';

const _captureKey = ValueKey('settings-visual-capture');

final class _PreferencesStore implements AppPreferencesStore {
  AppPreferences value = const AppPreferences(
    heatRange: HeatRange.week,
    recordingMode: RecordingMode.guided,
    reminders: true,
  );

  @override
  Future<AppPreferences> read() async => value;

  @override
  Future<void> write(AppPreferences preferences) async => value = preferences;
}

final class _Maintenance implements DataMaintenance {
  @override
  Future<DataCounts> counts() async => const DataCounts(
    activities: 0,
    sleep: 0,
    goals: 0,
    reviews: 0,
    drafts: 0,
  );

  @override
  Future<void> clear() async {}

  @override
  Future<void> seed({
    required EntityId Function() newGoalId,
    required EntityId Function() newFactId,
    required int now,
  }) async {}
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('NotoSerifSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Regular.otf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.otf')))
        .load();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['SETTINGS_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await Directory(directory).create(recursive: true);
      await File('$directory/$name.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    double textScale = 1,
    _PreferencesStore? preferences,
    ThemeData? theme,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? homeTheme,
        builder: (context, child) =>
            RepaintBoundary(key: _captureKey, child: child!),
        home: SettingsPage(
          preferences: preferences ?? _PreferencesStore(),
          maintenance: _Maintenance(),
          newGoalId: () => '00000000-0000-4000-8000-000000000001',
          newFactId: () => '00000000-0000-4000-8000-000000000002',
          now: () => DateTime(2026, 10, 8, 15).millisecondsSinceEpoch,
          versionLabel: '0.1.0 · 构建 1',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('display settings persist the quick-panel side', (tester) async {
    final preferences = _PreferencesStore();
    await mount(tester, preferences: preferences);
    await tester.tap(find.byKey(const ValueKey('settings-open-display')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-quick-panel-current')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('settings-quick-panel-right')));
    await tester.pumpAndSettle();
    expect(preferences.value.homeQuickPanelSide, HomeQuickPanelSide.right);
    expect(find.text('设置已保存。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings visual states fit the 360 by 800 baseline', (
    tester,
  ) async {
    await mount(tester);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await capture(tester, '01-settings-home');

    await tester.tap(find.byKey(const ValueKey('settings-open-display')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '02-settings-display');

    await tester.tap(find.byKey(const ValueKey('settings-theme-picker')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '02b-theme-scheme-sheet');
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-theme-mode')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '02c-theme-mode-sheet');
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-recording')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await capture(tester, '03-settings-recording');

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-advanced')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '04-settings-advanced');

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-about')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '05-settings-about');
  });

  testWidgets('settings render under the default M3 theme', (tester) async {
    await mount(tester, theme: ThemeData(useMaterial3: true));
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-01-settings-home');

    await tester.tap(find.byKey(const ValueKey('settings-open-display')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-02-settings-display');

    await tester.tap(find.byKey(const ValueKey('settings-theme-picker')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-02b-theme-scheme-sheet');
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-recording')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-03-settings-recording');

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-advanced')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-04-settings-advanced');

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-about')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, 'm3-05-settings-about');
  });

  testWidgets('settings remain scrollable without overflow across text sizes', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 412.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        await mount(tester, size: Size(width, 800), textScale: scale);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('settings-open-recording')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
