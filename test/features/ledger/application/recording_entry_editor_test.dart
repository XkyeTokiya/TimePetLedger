import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

const blockId = '00000000-0000-4000-8000-000000000001';
const goalId = '00000000-0000-4000-8000-000000000002';
const annotationId = '00000000-0000-4000-8000-000000000003';
const otherId = '00000000-0000-4000-8000-000000000004';
const reviewId = '00000000-0000-4000-8000-000000000005';
final date = CivilDate(year: 2026, month: 9, day: 28);
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

class FailingClearStore implements RecordingDraftStore {
  FailingClearStore(this.inner);
  final RecordingDraftStore inner;
  bool failClear = true;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) =>
      inner.read(context);
  @override
  Future<void> save(RecordingDraft draft) => inner.save(draft);
  @override
  Future<void> clear(RecordingDraftContext context) {
    if (failClear) throw StateError('private draft SQL');
    return inner.clear(context);
  }
}

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repository;
  late DriftRecordingDraftStore drafts;
  late RecordingLedgerLoader loader;
  late RecordingEntrySaver saver;
  late RecordingEntryEditor editor;
  var clock = at(29, 12);
  final context = RecordingDraftContext.edit(date: date, timeBlockId: blockId);

  RecordingDraft input({
    required BlockKnowledgeState knowledge,
    required String? title,
    int? start,
    int? end,
    TimePrecision startPrecision = TimePrecision.approximate,
    TimePrecision endPrecision = TimePrecision.exact,
    String? note,
    bool noteProvided = false,
  }) => RecordingDraft(
    context: context,
    title: title,
    startedAt: start ?? at(28, 23, 30),
    endedAt: end ?? at(29, 0, 30),
    startPrecision: startPrecision,
    endPrecision: endPrecision,
    knowledgeState: knowledge,
    note: note,
    noteProvided: noteProvided,
  );

  Future<void> createBlock({
    String id = blockId,
    int? start,
    int? end,
    String? goal,
    String? category,
    String? note,
    AddAnnotation? annotation,
  }) async {
    await repository.createTimeBlock(
      id: id,
      startedAt: start ?? at(28, 23, 30),
      endedAt: end ?? at(29, 0, 30),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '写作',
      goalId: goal,
      categoryId: category,
      note: note,
      annotation: annotation,
      now: 1,
    );
  }

  setUp(() async {
    clock = at(29, 12);
    db = await AppDatabase.open(NativeDatabase.memory());
    repository = DriftLedgerRepository(db);
    drafts = await DriftRecordingDraftStore.open(NativeDatabase.memory());
    loader = RecordingLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
    saver = RecordingEntrySaver(
      repository: repository,
      drafts: drafts,
      refresh: loader.load,
      newId: () => otherId,
      now: () => clock,
    );
    editor = RecordingEntryEditor(
      repository: repository,
      drafts: drafts,
      saver: saver,
    );
  });
  tearDown(() async {
    await drafts.close();
    await db.close();
  });

  test(
    'read by id returns the complete cross-day source and annotation',
    () async {
      await createBlock(
        annotation: const AddAnnotation(
          id: annotationId,
          state: RhythmState.progress,
        ),
      );
      final source = (await editor.load(blockId))!;
      expect(source.timeBlock.startedAt, at(28, 23, 30));
      expect(source.timeBlock.endedAt, at(29, 0, 30));
      expect(source.annotation!.id, annotationId);
      expect(await editor.load(otherId), isNull);
    },
  );

  test('both knowledge corrections preserve hidden archived Goal and annotation; no-op keeps metadata', () async {
    await DriftGoalRepository(db).create(id: goalId, name: '论文', now: 1);
    await createBlock(
      goal: goalId,
      category: 'legacy',
      note: '原备注',
      annotation: const AddAnnotation(
        id: annotationId,
        state: RhythmState.progress,
      ),
    );
    await DriftGoalRepository(db).archive(id: goalId, now: 2);
    final changed = input(knowledge: BlockKnowledgeState.unknown, title: '写作');
    await drafts.save(changed);
    expect(
      (await editor.load(blockId))!.timeBlock.knowledgeState,
      BlockKnowledgeState.known,
    );
    final first = await editor.save(changed) as RecordingSubmitCommitted;
    expect(first.complete, isTrue);
    expect(first.timeBlock.id, blockId);
    expect(first.timeBlock.createdAt, 1);
    expect(first.timeBlock.updatedAt, clock);
    expect(first.timeBlock.goalId, goalId);
    expect(first.timeBlock.categoryId, 'legacy');
    expect(first.timeBlock.note, '原备注');
    expect((await editor.load(blockId))!.annotation!.id, annotationId);
    expect(await drafts.read(context), isNull);
    final firstUpdatedAt = clock;
    clock += 1000;
    final noOp = await editor.save(changed) as RecordingSubmitCommitted;
    expect(noOp.timeBlock.updatedAt, firstUpdatedAt);
    clock += 1000;
    final known = input(knowledge: BlockKnowledgeState.known, title: '修改后的写作');
    final second = await editor.save(known) as RecordingSubmitCommitted;
    expect(second.timeBlock.id, blockId);
    expect(second.timeBlock.createdAt, 1);
    expect(second.timeBlock.updatedAt, clock);
    expect(second.timeBlock.title, '修改后的写作');
    expect(second.timeBlock.goalId, goalId);
    expect((await editor.load(blockId))!.annotation!.id, annotationId);
  });

  test(
    'overlap introduced at save rejects edit and keeps original plus draft',
    () async {
      await createBlock();
      await repository.createSleepSession(
        id: otherId,
        startedAt: at(29, 1),
        endedAt: at(29, 2),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        now: 2,
      );
      final changed = input(
        knowledge: BlockKnowledgeState.known,
        title: '更长写作',
        end: at(29, 1, 30),
      );
      await drafts.save(changed);
      final failed = await editor.save(changed) as RecordingSubmitFailed;
      expect(
        failed.conflicts.single.reference.type,
        LedgerFactType.sleepSession,
      );
      expect((await editor.load(blockId))!.timeBlock.endedAt, at(29, 0, 30));
      expect((await editor.load(blockId))!.timeBlock.updatedAt, 1);
      expect((await drafts.read(context))!.title, '更长写作');
    },
  );

  test(
    'optional note changes and clears on edit; failed edit retains it',
    () async {
      await createBlock(note: '原备注');
      final changed = input(
        knowledge: BlockKnowledgeState.known,
        title: '写作',
        note: '  新备注\n第二行  ',
        noteProvided: true,
      );
      await drafts.save(changed);
      expect((await editor.load(blockId))!.timeBlock.note, '原备注');
      final first = await editor.save(changed) as RecordingSubmitCommitted;
      expect(first.timeBlock.note, '新备注\n第二行');
      expect((await editor.load(blockId))!.timeBlock.note, '新备注\n第二行');

      final cleared = input(
        knowledge: BlockKnowledgeState.known,
        title: '写作',
        note: ' \n ',
        noteProvided: true,
      );
      await drafts.save(cleared);
      final second = await editor.save(cleared) as RecordingSubmitCommitted;
      expect(second.timeBlock.note, isNull);
      expect((await editor.load(blockId))!.timeBlock.note, isNull);
    },
  );

  test(
    'missing edit never creates a fact; duplicate delete is idempotent',
    () async {
      final changed = input(
        knowledge: BlockKnowledgeState.known,
        title: '消失的记录',
      );
      await drafts.save(changed);
      final failed = await editor.save(changed) as RecordingSubmitFailed;
      expect(failed.notFound, isTrue);
      expect((await drafts.read(context))!.title, changed.title);
      final first = await editor.delete(context) as RecordingDeleteCommitted;
      expect(first.complete, isTrue);
      final again = await editor.delete(context) as RecordingDeleteCommitted;
      expect(again.complete, isTrue);
      expect(await drafts.read(context), isNull);
      expect(await editor.load(blockId), isNull);
    },
  );

  test(
    'delete removes annotation, leaves review, and recalculates Gap',
    () async {
      await createBlock(
        annotation: const AddAnnotation(
          id: annotationId,
          state: RhythmState.progress,
        ),
      );
      await DriftReviewRepository(
        db,
      ).create(id: reviewId, date: date, tomorrowFirstStepText: '继续写作', now: 1);
      final before = await loader.load(date: date, now: at(29, 12));
      expect(before.coverage.accountedDuration.roundedMinutes, 30);
      final result = await editor.delete(context) as RecordingDeleteCommitted;
      expect(result.complete, isTrue);
      expect(result.refreshed!.coverage.accountedDuration.roundedMinutes, 0);
      expect(result.refreshed!.coverage.unresolvedSpans, hasLength(1));
      expect(await editor.load(blockId), isNull);
      expect(
        (await db.customSelect('SELECT * FROM rhythm_annotations').get()),
        isEmpty,
      );
      expect(await DriftReviewRepository(db).findByDate(date), isNotNull);
    },
  );

  test('committed delete failures only retry cleanup and refresh', () async {
    await createBlock();
    await drafts.save(
      input(knowledge: BlockKnowledgeState.known, title: '待删编辑'),
    );
    final failing = FailingClearStore(drafts);
    var failRefresh = true;
    final service = RecordingEntrySaver(
      repository: repository,
      drafts: failing,
      refresh: ({required date, required now}) {
        if (failRefresh) throw StateError('private read SQL');
        return loader.load(date: date, now: now);
      },
      newId: () => otherId,
      now: () => clock,
    );
    final deleting = RecordingEntryEditor(
      repository: repository,
      drafts: failing,
      saver: service,
    );
    final first = await deleting.delete(context) as RecordingDeleteCommitted;
    expect(first.complete, isFalse);
    expect(await deleting.load(blockId), isNull);
    expect(await drafts.read(context), isNotNull);
    failing.failClear = false;
    failRefresh = false;
    final finished = await deleting.finishDelete(
      context: context,
      draftCleared: first.draftCleared,
    );
    expect(finished.complete, isTrue);
    expect(await drafts.read(context), isNull);
    expect(finished.refreshed!.coverage.accountedDuration.roundedMinutes, 0);
  });
}
