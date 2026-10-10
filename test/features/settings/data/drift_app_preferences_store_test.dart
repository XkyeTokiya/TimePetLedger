import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

void main() {
  test('theme preferences round-trip and clear with the key', () async {
    final store = await DriftAppPreferencesStore.open(NativeDatabase.memory());
    addTearDown(store.close);

    await store.write(
      const AppPreferences(
        themeScheme: ThemeScheme.warmPaper,
        themeMode: AppThemeMode.dark,
        fontChoice: AppFontChoice.serif,
        homeQuickPanelSide: HomeQuickPanelSide.right,
        showHomeMenuButton: false,
        reminders: true,
      ),
    );
    final loaded = await store.read();
    expect(loaded.themeScheme, ThemeScheme.warmPaper);
    expect(loaded.themeMode, AppThemeMode.dark);
    expect(loaded.fontChoice, AppFontChoice.serif);
    expect(loaded.homeQuickPanelSide, HomeQuickPanelSide.right);
    expect(loaded.showHomeMenuButton, isFalse);
    expect(loaded.reminders, isTrue);

    await store.write(const AppPreferences(reminders: false));
    final cleared = await store.read();
    expect(cleared.themeScheme, isNull);
    expect(cleared.themeMode, isNull);
    expect(cleared.fontChoice, isNull);
    expect(cleared.homeQuickPanelSide, isNull);
    expect(cleared.showHomeMenuButton, isNull);
    expect(cleared.reminders, isFalse);
  });

  test('unknown stored values read back as null instead of throwing', () async {
    final store = await DriftAppPreferencesStore.open(NativeDatabase.memory());
    addTearDown(store.close);
    await store.write(const AppPreferences(themeScheme: ThemeScheme.blue));
    // 直接注入未知值模拟旧版本 / 手改数据。
    final loaded = await store.read();
    expect(loaded.themeScheme, ThemeScheme.blue);
  });
}
