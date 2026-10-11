import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

/// 从旧录制表单测试迁出的数据 / 控制器夹具（P2）：不依赖已删除的旧控件。
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 1);
final start = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 1, 11).millisecondsSinceEpoch;
final editContext = RecordingDraftContext.edit(date: date, timeBlockId: id(8));
final newContext = RecordingDraftContext.newEntry(date: date);

class Queries extends QueryInterceptor {
  bool failClear = false;
  bool failSave = false;
  int writes = 0;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failSave && sql.contains('INSERT INTO recording_drafts')) {
      throw StateError('draft save');
    }
    if (failClear && sql.startsWith('DELETE FROM recording_drafts')) {
      throw StateError('cleanup');
    }
    return executor.runCustom(sql, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runInsert(sql, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runUpdate(sql, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runDelete(sql, args);
  }
}

class Fixture {
  Fixture(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  late final repo = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  late final loader = RecordingLedgerLoader(
    repository: repo,
    resolveDate: resolveDeviceRecordingDate,
  );
  int ids = 100;
  bool failRefresh = false;
  late final saver = RecordingEntrySaver(
    repository: repo,
    drafts: drafts,
    refresh: ({required date, required now}) {
      if (failRefresh) throw StateError('refresh');
      return loader.load(date: date, now: now);
    },
    newId: () => id(ids++),
    now: () => end + 1,
  );
  late final editor = RecordingEntryEditor(
    repository: repo,
    drafts: drafts,
    saver: saver,
  );
  static Future<Fixture> open({Queries? formal, Queries? draft}) async =>
      Fixture(
        await AppDatabase.open(
          formal == null
              ? NativeDatabase.memory()
              : NativeDatabase.memory().interceptWith(formal),
        ),
        await DriftRecordingDraftStore.open(
          draft == null
              ? NativeDatabase.memory()
              : NativeDatabase.memory().interceptWith(draft),
        ),
      );
  Future<void> close() async {
    await drafts.close();
    await db.close();
  }

  Future<void> ensureTestGoal() async {
    if (await goals.findById(id(1)) == null) {
      await goals.create(id: id(1), name: '目标', now: 1);
    }
  }

  Future<void> source({
    RhythmState? state,
    bool details = true,
    bool withGoal = false,
  }) async {
    if (withGoal) await ensureTestGoal();
    await repo.createTimeBlock(
      id: id(8),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '原活动',
      note: '原备注',
      categoryId: '原分类',
      goalId: withGoal ? id(1) : null,
      now: 1,
      annotation: state == null
          ? null
          : AddAnnotation(
              id: id(7),
              state: state,
              continuationHint: '原接续点',
              stuckReasonCode: details ? StuckReasonCode.unclearNextStep : null,
              stuckReasonText: details ? '原原因' : null,
              recoveryMethod: details ? RecoveryMethod.walk : null,
              recoveryQuality: details ? RecoveryQuality.partlyRecovered : null,
            ),
    );
  }

  RecordingFormController controller(RecordingDraftContext context) =>
      RecordingFormController(
        context: context,
        store: drafts,
        entrySaver: saver,
        entryEditor: editor,
        goals: goals,
        loadSuggestion: () async => DirectTimeSuggestion(
          RecordingTimeInput(startedAt: start, endedAt: end),
        ),
      );

  Future<List<Object?>> snapshot() async => [
    for (final table in [
      'time_blocks',
      'rhythm_annotations',
      'goals',
      'sleep_sessions',
      'daily_reviews',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  ];
}
