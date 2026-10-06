import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/persistence/app_database.dart';
import '../../core/persistence/database_connection.dart';
import '../main_app.dart';
import '../theme/home_theme.dart';
import '../../features/goals/data/drift_goal_repository.dart';
import '../../features/goals/data/drift_goal_history_reader.dart';
import '../../features/goals/presentation/goal_management_page.dart';
import '../../features/settings/data/drift_app_preferences_store.dart';
import '../../features/settings/data/drift_data_maintenance.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/ledger/data/drift_recording_draft_store.dart';
import '../../features/ledger/application/recording_entry_editor.dart';
import 'recording_drafts.dart';
import 'app_preferences.dart';
import 'sleep_drafts.dart';
import 'sleep_entry.dart';
import 'sleep_ledger.dart';
import 'day_ledger.dart';
import 'review_context.dart';
import 'review_submission.dart';
import 'review_drafts.dart';
import '../../features/review/data/drift_review_draft_store.dart';
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

/// Owns formal and independent draft connections; presentation receives interfaces.
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
  DriftRecordingDraftStore? _drafts;
  Future<DriftSleepOpeningStore>? _openingSleepState;
  DriftSleepOpeningStore? _sleepState;
  late final _preferences = AppPreferencesSession(
    openStore: widget.openPreferences,
  );
  late final _reviewDrafts = ReviewDraftSession(
    openStore: widget.openReviewDrafts,
  );

  /// 数据概况用：三类草稿的现存数量之和。
  Future<int> _openDrafts() async {
    final drafts = _drafts;
    if (drafts == null) return 0;
    final sleep = await widget.openSleepDrafts();
    final review = await widget.openReviewDrafts();
    try {
      return await drafts.countAll() +
          await sleep.countAll() +
          await review.countAll();
    } finally {
      await sleep.close();
      await review.close();
    }
  }

  /// 数据清空用：清除三类草稿；草稿连接用完即关。
  Future<void> _clearDrafts() async {
    final drafts = _drafts;
    final sleep = await widget.openSleepDrafts();
    final review = await widget.openReviewDrafts();
    try {
      await drafts?.clearAll();
      await sleep.clearAll();
      await review.clearAll();
    } finally {
      await sleep.close();
      await review.close();
    }
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
  }

  Future<void> _open() async {
    final database = await widget.openDatabase();
    DriftRecordingDraftStore? drafts;
    try {
      if (!mounted) {
        await database.close();
        return;
      }
      drafts = await widget.openDrafts();
      if (!mounted) {
        await drafts.close();
        await database.close();
      } else {
        final seed = widget.seed;
        if (seed != null) await seed(database);
        if (!mounted) {
          await drafts.close();
          await database.close();
          return;
        }
        _database = database;
        _drafts = drafts;
      }
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    unawaited(
      _reviewDrafts.close().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'app bootstrap',
            context: ErrorDescription('while closing review drafts'),
          ),
        );
      }),
    );
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
    final drafts = _drafts;
    if (drafts != null) {
      unawaited(
        drafts.close().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'app bootstrap',
              context: ErrorDescription('while closing recording drafts'),
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
            theme: homeTheme,
            home: const Scaffold(
              body: Center(child: Text('无法打开本地存储，请重新启动应用。')),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: homeTheme,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final ledger = createRecordingLedgerLoader(_database!);
        final saver = createRecordingEntrySaver(
          database: _database!,
          drafts: _drafts!,
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
            maintenance: DriftDataMaintenance(
              _database!,
              draftCount: _openDrafts,
              clearDrafts: _clearDrafts,
            ),
            newGoalId: newLocalTimeBlockId,
            newFactId: newLocalTimeBlockId,
            now: () => widget.now().millisecondsSinceEpoch,
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
          firstSleepOpen: SleepFirstOpenCoordinator(
            ledger: sleepLedger,
            claimOpening: _claimSleepOpening,
          ),
          sleepLedger: sleepLedger,
          sleepEntry: (context) => SleepEntry(
            context: context,
            openStore: widget.openSleepDrafts,
            createEditor: createSleepEntryEditor,
            createSaver: (drafts) => createSleepEntrySaver(
              database: _database!,
              drafts: drafts,
              ledger: sleepLedger,
              clock: widget.now,
            ),
          ),
          ledger: ledger,
          drafts: _drafts!,
          now: widget.now,
          entrySaver: saver,
          entryEditor: RecordingEntryEditor(
            repository: saver.repository,
            drafts: _drafts!,
            saver: saver,
          ),
        );
      },
    );
  }
}
