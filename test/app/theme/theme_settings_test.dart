import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';
import 'package:time_pet_ledger/features/settings/domain/data_overview.dart';
import 'package:time_pet_ledger/features/settings/presentation/settings_page.dart';

final class _RecordingStore implements AppPreferencesStore {
  AppPreferences value = const AppPreferences();
  int writes = 0;

  @override
  Future<AppPreferences> read() async => value;

  @override
  Future<void> write(AppPreferences preferences) async {
    value = preferences;
    writes++;
  }
}

final class _Maintenance implements DataMaintenance {
  @override
  Future<DataCounts> counts() async => const DataCounts(
    activities: 1,
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
  Future<void> mount(WidgetTester tester, _RecordingStore store) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: SettingsPage(
          preferences: store,
          maintenance: _Maintenance(),
          newGoalId: () => 'goal-1',
          newFactId: () => 'fact-1',
          now: () => 0,
          onSaved: (_) => saved++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-display')));
    await tester.pumpAndSettle();
    expect(saved, 0);
  }

  testWidgets('display section exposes rows and hides unsupported dynamic', (
    tester,
  ) async {
    final store = _RecordingStore();
    await mount(tester, store);

    expect(find.text('主题'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-theme-mode-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-theme-current')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-font-current')), findsOneWidget);
    // 测试环境没有动态取色插件：开关隐藏（合同 §2.5）。
    expect(find.byKey(const ValueKey('settings-theme-dynamic')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-theme-picker')));
    await tester.pumpAndSettle();
    expect(find.text('自选主题色'), findsWidgets);
    expect(
      find.byKey(const ValueKey('settings-theme-defaultM3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-theme-warmPaper')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-theme-dynamic')), findsNothing);
  });

  testWidgets('theme, mode and font selections each write once', (
    tester,
  ) async {
    final store = _RecordingStore();
    await mount(tester, store);

    await tester.tap(find.byKey(const ValueKey('settings-theme-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-theme-warmPaper')));
    await tester.pumpAndSettle();
    expect(store.value.themeScheme, ThemeScheme.warmPaper);
    expect(store.writes, 1);

    await tester.tap(find.byKey(const ValueKey('settings-theme-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-theme-mode-dark')));
    await tester.pumpAndSettle();
    expect(store.value.themeMode, AppThemeMode.dark);
    expect(store.writes, 2);

    await tester.tap(find.byKey(const ValueKey('settings-font')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-font-serif')));
    await tester.pumpAndSettle();
    expect(store.value.fontChoice, AppFontChoice.serif);
    expect(store.writes, 3);
    expect(
      find.byKey(const ValueKey('settings-theme-current')),
      findsOneWidget,
    );
  });

  testWidgets('recording mode sheet writes the guided/form preference', (
    tester,
  ) async {
    final store = _RecordingStore();
    await mount(tester, store);
    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-open-recording')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-mode-guided')));
    await tester.pumpAndSettle();
    expect(store.value.recordingMode, RecordingMode.guided);
    expect(store.writes, 1);
  });
}
