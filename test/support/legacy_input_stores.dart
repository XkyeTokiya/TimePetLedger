import 'package:drift/native.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';

/// 新版启动只把旧 SQLite 输入当作一次升级清理；测试用空内存库避免真实连接。
Future<DriftRecordingDraftStore> emptyLegacyRecordingDrafts() =>
    DriftRecordingDraftStore.open(NativeDatabase.memory());

Future<DriftSleepDraftStore> emptyLegacySleepDrafts() =>
    DriftSleepDraftStore.open(NativeDatabase.memory());

Future<DriftReviewDraftStore> emptyLegacyReviewDrafts() =>
    DriftReviewDraftStore.open(NativeDatabase.memory());
