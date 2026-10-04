import 'package:drift/native.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/app/bootstrap/sleep_submission.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/application/review_entry_saver.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

/// Isolated, real SQLite connections. Never opens the application's data path.
class PageT01Fixture {
  PageT01Fixture(
    this.db,
    this.recordingDrafts,
    this.sleepDrafts,
    this.reviewDrafts,
  );

  static final day = CivilDate(year: 2026, month: 10, day: 2);
  static int instant(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
  static final now = instant(2, 12);
  static const sleepId = '00000000-0000-4000-8000-000000000001';
  static const walkId = '00000000-0000-4000-8000-000000000002';
  static final gap = RecordingDraftContext.gap(
    date: day,
    startedAt: instant(2, 10, 30),
    endedAt: instant(2, 11),
  );

  final AppDatabase db;
  final DriftRecordingDraftStore recordingDrafts;
  final DriftSleepDraftStore sleepDrafts;
  final DriftReviewDraftStore reviewDrafts;
  late final ledger = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  late final reviews = DriftReviewRepository(db);
  late final reviewLoader = createReviewContextLoader(db);
  int _nextId = 100;
  String newId() =>
      '00000000-0000-4000-8000-${(_nextId++).toString().padLeft(12, '0')}';
  late final recordingSaver = RecordingEntrySaver(
    repository: ledger,
    drafts: recordingDrafts,
    refresh: RecordingLedgerLoader(
      repository: ledger,
      resolveDate: resolveDeviceRecordingDate,
    ).load,
    newId: newId,
    now: () => now,
  );
  late final sleepSaver = SleepEntrySaver(
    repository: ledger,
    drafts: sleepDrafts,
    refresh: SleepLedgerLoader(
      repository: ledger,
      resolveDate: resolveDeviceRecordingDate,
    ).load,
    newId: newId,
    now: () => now,
  );
  late final sleepEditor = createSleepEntryEditor(sleepSaver);
  late final reviewSaver = ReviewEntrySaver(
    repository: reviews,
    drafts: reviewDrafts,
    refresh: reviewLoader.load,
    newId: newId,
    now: () => now,
  );

  static Future<PageT01Fixture> open() async => PageT01Fixture(
    await AppDatabase.open(NativeDatabase.memory()),
    await DriftRecordingDraftStore.open(NativeDatabase.memory()),
    await DriftSleepDraftStore.open(NativeDatabase.memory()),
    await DriftReviewDraftStore.open(NativeDatabase.memory()),
  );

  Future<void> seedSleep() => ledger.createSleepSession(
    id: sleepId,
    startedAt: instant(1, 23, 40),
    endedAt: instant(2, 7, 20),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: instant(2, 8),
  );

  Future<void> seedWalk() => ledger.createTimeBlock(
    id: walkId,
    startedAt: instant(2, 11),
    endedAt: instant(2, 11, 30),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '散步',
    now: now,
  );

  Future<void> close() async {
    await recordingDrafts.close();
    await sleepDrafts.close();
    await reviewDrafts.close();
    await db.close();
  }
}
