import 'package:drift/drift.dart';

import '../domain/app_preferences.dart';

/// 独立命名的偏好连接，不进入正式账本或草稿表（Q-034 保留设置）。
final class DriftAppPreferencesStore implements AppPreferencesStore {
  DriftAppPreferencesStore._(this._database);
  final _PreferencesDatabase _database;

  static Future<DriftAppPreferencesStore> open(QueryExecutor executor) async {
    final database = _PreferencesDatabase(executor);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftAppPreferencesStore._(database);
    } catch (error, stack) {
      try {
        await database.close();
      } catch (_) {
        // Preserve the opening failure.
      }
      Error.throwWithStackTrace(AppPreferencesStorageException(error), stack);
    }
  }

  @override
  Future<AppPreferences> read() async {
    try {
      final rows = await _database
          .customSelect('SELECT key, value FROM app_preferences')
          .get();
      final values = {
        for (final row in rows)
          row.read<String>('key'): row.read<String>('value'),
      };
      return AppPreferences(
        commonGoalId: values['common_goal_id'],
        heatRange: _heatRange(values['heat_range']),
        recordingMode: _recordingMode(values['recording_mode']),
        reminders: _bool(values['reminders']),
        sleepReminderMinutes: _int(values['sleep_reminder_minutes']),
        reviewReminderMinutes: _int(values['review_reminder_minutes']),
        themeScheme: _themeScheme(values['theme_scheme']),
        themeMode: _appThemeMode(values['theme_mode']),
        fontChoice: _fontChoice(values['font_choice']),
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(AppPreferencesStorageException(error), stack);
    }
  }

  @override
  Future<void> write(AppPreferences preferences) async {
    try {
      await _database.transaction(() async {
        for (final entry in {
          'common_goal_id': preferences.commonGoalId,
          'heat_range': preferences.heatRange?.name,
          'recording_mode': preferences.recordingMode?.name,
          'reminders': preferences.reminders?.toString(),
          'sleep_reminder_minutes': preferences.sleepReminderMinutes
              ?.toString(),
          'review_reminder_minutes': preferences.reviewReminderMinutes
              ?.toString(),
          'theme_scheme': preferences.themeScheme?.name,
          'theme_mode': preferences.themeMode?.name,
          'font_choice': preferences.fontChoice?.name,
        }.entries) {
          final value = entry.value;
          if (value == null) {
            await _database.customUpdate(
              'DELETE FROM app_preferences WHERE key = ?',
              variables: [Variable(entry.key)],
            );
          } else {
            await _database.customUpdate(
              'INSERT INTO app_preferences (key, value) VALUES (?, ?) '
              'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
              variables: [Variable(entry.key), Variable(value)],
            );
          }
        }
      });
    } catch (error, stack) {
      Error.throwWithStackTrace(AppPreferencesStorageException(error), stack);
    }
  }

  Future<void> close() => _database.close();

  static HeatRange? _heatRange(String? value) => HeatRange.values
      .where((candidate) => candidate.name == value)
      .firstOrNull;

  static RecordingMode? _recordingMode(String? value) => RecordingMode.values
      .where((candidate) => candidate.name == value)
      .firstOrNull;

  static ThemeScheme? _themeScheme(String? value) => ThemeScheme.values
      .where((candidate) => candidate.name == value)
      .firstOrNull;

  static AppThemeMode? _appThemeMode(String? value) => AppThemeMode.values
      .where((candidate) => candidate.name == value)
      .firstOrNull;

  static AppFontChoice? _fontChoice(String? value) => AppFontChoice.values
      .where((candidate) => candidate.name == value)
      .firstOrNull;

  static bool? _bool(String? value) => switch (value) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  static int? _int(String? value) => value == null ? null : int.tryParse(value);
}

class _PreferencesDatabase extends GeneratedDatabase {
  _PreferencesDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''
CREATE TABLE app_preferences (
 key TEXT NOT NULL PRIMARY KEY,
 value TEXT NOT NULL
)
'''),
    onUpgrade: (_, from, to) =>
        throw StateError('Unsupported preferences schema: $from -> $to'),
  );
}
