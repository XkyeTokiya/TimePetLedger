import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/persistence/app_database.dart';
import '../../core/persistence/database_connection.dart';
import '../main_app.dart';
import '../app_version.dart';
import '../theme/app_theme.dart';
import '../../features/goals/data/drift_goal_repository.dart';
import '../../features/goals/data/drift_goal_history_reader.dart';
import '../../features/goals/presentation/goal_management_page.dart';
import '../../features/settings/data/drift_app_preferences_store.dart';
import '../../features/settings/data/drift_data_maintenance.dart';
import '../../features/settings/domain/app_preferences.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/ledger/data/drift_recording_draft_store.dart';
import '../../features/ledger/data/session_recording_draft_store.dart';
import '../../features/ledger/data/session_sleep_draft_store.dart';
import '../../features/ledger/application/recording_entry_editor.dart';
import 'recording_drafts.dart';
import 'app_preferences.dart';
import 'sleep_drafts.dart';
import '../time/device_sleep_prediction_calendar.dart';
import '../../features/ledger/application/sleep_time_prediction_loader.dart';
import 'sleep_entry.dart';
import 'sleep_ledger.dart';
import 'day_ledger.dart';
import 'review_context.dart';
import 'review_submission.dart';
import 'review_drafts.dart';
import '../../features/review/data/drift_review_draft_store.dart';
import '../../features/review/data/session_review_draft_store.dart';
import 'sleep_submission.dart';
import 'sleep_openings.dart';
import '../../core/time/civil_date.dart';
import '../../features/ledger/application/sleep_first_open.dart';
import '../../features/ledger/data/drift_sleep_opening_store.dart';
import '../../features/ledger/data/drift_sleep_draft_store.dart';
import 'recording_ledger.dart';
import 'recording_submission.dart';

Future<AppDatabase> openAppDatabase() async {
  return AppDatabase.open(await connectDatabase('time_pet_ledger'));
}

/// Owns formal storage, persistent sleep learning, and session-only input recovery.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    this.openDatabase = openAppDatabase,
    this.openDrafts = openRecordingDraftStore,
    this.openSleepDrafts = openSleepDraftStore,
    this.openSleepOpenings = openSleepOpeningStore,
    this.openReviewDrafts = openReviewDraftStore,
    this.openPreferences = openAppPreferencesStore,
    this.now = DateTime.now,
    this.seed,
  });

  /// 仅开发用：数据库首次打开后写入演示数据（幂等，由实现自行保证）。
  final Future<void> Function(AppDatabase database)? seed;

  final Future<AppDatabase> Function() openDatabase;
  final Future<DriftRecordingDraftStore> Function() openDrafts;
  final Future<DriftSleepDraftStore> Function() openSleepDrafts;
  final Future<DriftSleepOpeningStore> Function() openSleepOpenings;
  final Future<DriftReviewDraftStore> Function() openReviewDrafts;
  final Future<DriftAppPreferencesStore> Function() openPreferences;
  final DateTime Function() now;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _ready;
  AppDatabase? _database;
  final _drafts = SessionRecordingDraftStore();
  final _sleepDrafts = SessionSleepDraftStore();
  final _reviewDrafts = SessionReviewDraftStore();
  DriftSleepDraftStore? _sleepLearning;
  Future<DriftSleepOpeningStore>? _openingSleepState;
  DriftSleepOpeningStore? _sleepState;
  late final _preferences = AppPreferencesSession(
    openStore: widget.openPreferences,
  );

  /// 主题偏好：在首帧前预读（Q-041 合同 §2.7），设置保存成功后即时更新。
  final _themePreferences = ValueNotifier<AppPreferences?>(null);

  /// 数据概况内部仍计入未完成输入，但设置页不单列其数量。
  Future<int> _openDrafts() async {
    return _drafts.count + _sleepDrafts.count + _reviewDrafts.count;
  }

  /// 高级清空同时清除当前会话输入与睡眠学习辅助数据。
  Future<void> _clearDrafts() async {
    _drafts.clearAll();
    _sleepDrafts.clearAll();
    _reviewDrafts.clearAll();
    await _sleepLearning?.clearAll();
  }

  Future<bool> _claimSleepOpening(CivilDate date) async {
    if (!mounted) throw StateError('App has closed.');
    final pending = _openingSleepState ??= widget.openSleepOpenings();
    late final DriftSleepOpeningStore store;
    try {
      store = await pending;
    } catch (_) {
      if (identical(_openingSleepState, pending)) _openingSleepState = null;
      rethrow;
    }
    if (!mounted) {
      await store.close();
      throw StateError('App has closed.');
    }
    _sleepState = store;
    return store.claim(date);
  }

  @override
  void initState() {
    super.initState();
    _ready = _open();
    // 主题偏好预读与数据库打开并行（Q-041 合同 §2.7）：先于就绪完成时
    // 首帧即用所选主题，避免冷启动闪变；读取失败保持默认主题、不阻塞启动。
    runZonedGuarded(() {
      _preferences.read().then((preferences) {
        if (mounted) _themePreferences.value = preferences;
      }, onError: (Object _) {});
    }, (Object _, StackTrace _) {});
  }

  Future<void> _open() async {
    final database = await widget.openDatabase();
    DriftRecordingDraftStore? legacyRecording;
    DriftReviewDraftStore? legacyReview;
    DriftSleepDraftStore? sleepLearning;
    try {
      if (!mounted) {
        await database.close();
        return;
      }
      // 旧版本曾把未完成输入写入独立 SQLite。升级启动时清除它们；
      // 睡眠学习证据继续留在原辅助库并由 app 生命周期持有。
      legacyRecording = await widget.openDrafts();
      legacyReview = await widget.openReviewDrafts();
      sleepLearning = await widget.openSleepDrafts();
      await legacyRecording.clearAll();
      await legacyReview.clearAll();
      await sleepLearning.clearDraftsOnly();
      await legacyRecording.close();
      legacyRecording = null;
      await legacyReview.close();
      legacyReview = null;
      if (!mounted) {
        await sleepLearning.close();
        await database.close();
      } else {
        final seed = widget.seed;
        if (seed != null) await seed(database);
        if (!mounted) {
          await sleepLearning.close();
          await database.close();
          return;
        }
        _database = database;
        _sleepLearning = sleepLearning;
      }
    } catch (_) {
      await legacyRecording?.close();
      await legacyReview?.close();
      await sleepLearning?.close();
      await database.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    _themePreferences.dispose();
    unawaited(
      _preferences.close().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'app bootstrap',
            context: ErrorDescription('while closing preferences'),
          ),
        );
      }),
    );
    final sleepState = _sleepState;
    if (sleepState != null) {
      unawaited(
        sleepState.close().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'app bootstrap',
              context: ErrorDescription('while closing sleep opening state'),
            ),
          );
        }),
      );
    }
    final database = _database;
    if (database != null) {
      unawaited(
        database.close().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'app bootstrap',
              context: ErrorDescription('while closing local storage'),
            ),
          );
        }),
      );
    }
    final sleepLearning = _sleepLearning;
    if (sleepLearning != null) {
      unawaited(
        sleepLearning.close().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'app bootstrap',
              context: ErrorDescription('while closing sleep learning'),
            ),
          );
        }),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            theme: buildAppTheme(
              scheme: ThemeScheme.defaultM3,
              brightness: Brightness.light,
            ),
            home: const Scaffold(
              body: Center(child: Text('无法打开本地存储，请重新启动应用。')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: buildAppTheme(
              scheme: ThemeScheme.defaultM3,
              brightness: Brightness.light,
            ),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final ledger = createRecordingLedgerLoader(_database!);
        final saver = createRecordingEntrySaver(
          database: _database!,
          drafts: _drafts,
          ledger: ledger,
          clock: widget.now,
        );
        final sleepLedger = createSleepLedgerLoader(_database!);
        final reviewLoader = createReviewContextLoader(_database!);
        return MainApp(
          goals: DriftGoalRepository(_database!),
          goalEntry: () => GoalManagementPage(
            repository: DriftGoalRepository(_database!),
            history: DriftGoalHistoryReader(_database!),
            newId: newLocalTimeBlockId,
            now: () => widget.now().millisecondsSinceEpoch,
            preferences: _preferences,
          ),
          settingsEntry: () => SettingsPage(
            preferences: _preferences,
            onSaved: (preferences) => _themePreferences.value = preferences,
            maintenance: DriftDataMaintenance(
              _database!,
              draftCount: _openDrafts,
              clearDrafts: _clearDrafts,
            ),
            newGoalId: newLocalTimeBlockId,
            newFactId: newLocalTimeBlockId,
            now: () => widget.now().millisecondsSinceEpoch,
            versionLabel: kAppVersionLabel,
          ),
          dayLedger: createDayLedgerLoader(_database!),
          reviewContext: reviewLoader,
          reviewSaver: createReviewEntrySaver(
            database: _database!,
            drafts: _reviewDrafts,
            loader: reviewLoader,
            clock: widget.now,
          ),
          reviewDrafts: _reviewDrafts,
          preferences: _preferences,
          themePreferences: _themePreferences,
          firstSleepOpen: SleepFirstOpenCoordinator(
            ledger: sleepLedger,
            claimOpening: _claimSleepOpening,
          ),
          sleepLedger: sleepLedger,
          sleepEntry: (context) {
            final openedAt = widget.now().millisecondsSinceEpoch;
            return SleepEntry(
              context: context,
              loadPredictions: () =>
                  SleepTimePredictionLoader(
                    repository: ledger.repository,
                    resolveDate: ledger.resolveDate,
                    calendar: const DeviceSleepPredictionCalendar(),
                  ).load(
                    date: context.date,
                    now: openedAt,
                    learning: _sleepLearning,
                  ),
              store: _sleepDrafts,
              createEditor: createSleepEntryEditor,
              createSaver: (drafts) => createSleepEntrySaver(
                database: _database!,
                drafts: drafts,
                ledger: sleepLedger,
                clock: widget.now,
                learning: _sleepLearning,
              ),
            );
          },
          ledger: ledger,
          drafts: _drafts,
          now: widget.now,
          entrySaver: saver,
          entryEditor: RecordingEntryEditor(
            repository: saver.repository,
            drafts: _drafts,
            saver: saver,
          ),
        );
      },
    );
  }
}
