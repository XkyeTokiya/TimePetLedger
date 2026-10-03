import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

final date = CivilDate(year: 2026, month: 9, day: 28);
final context = RecordingDraftContext.newEntry(date: date);
int at(int hour, [int minute = 0]) =>
    DateTime(2026, 9, 28, hour, minute).millisecondsSinceEpoch;
final current = DateTime(2026, 9, 29, 12).millisecondsSinceEpoch;

RecordingDraft draft({
  required int start,
  required int end,
  BlockKnowledgeState knowledge = BlockKnowledgeState.known,
  String? title = '  写作  ',
  String? note,
}) => RecordingDraft(
  context: context,
  title: title,
  note: note,
  noteProvided: true,
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  knowledgeState: knowledge,
);

class FailingClearStore implements RecordingDraftStore {
  FailingClearStore(this.inner);
  final RecordingDraftStore inner;
  bool failClear = true;
  int clearCalls = 0;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) =>
      inner.read(context);
  @override
  Future<void> save(RecordingDraft value) => inner.save(value);
  @override
  Future<void> clear(RecordingDraftContext context) {
    clearCalls++;
    if (failClear) throw StateError('private draft SQL');
    return inner.clear(context);
  }
}

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repository;
  late DriftRecordingDraftStore drafts;
  late RecordingLedgerLoader loader;
  var idNumber = 1;
  String newId() =>
      '00000000-0000-4000-8000-${(idNumber++).toRadixString(16).padLeft(12, '0')}';
  RecordingEntrySaver saver({
    RecordingDraftStore? store,
    RecordingLedgerRefresh? refresh,
  }) => RecordingEntrySaver(
    repository: repository,
    drafts: store ?? drafts,
    refresh: refresh ?? loader.load,
    newId: newId,
    now: () => current,
  );

  setUp(() async {
    idNumber = 1;
    db = await AppDatabase.open(NativeDatabase.memory());
    repository = DriftLedgerRepository(db);
    drafts = await DriftRecordingDraftStore.open(NativeDatabase.memory());
    loader = RecordingLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
  });
  tearDown(() async {
    await drafts.close();
    await db.close();
  });

  test(
    'known and Unknown commit, clear real drafts, read back and reproject',
    () async {
      final known = draft(start: at(10), end: at(11), note: '  边听歌\n继续写  ');
      await drafts.save(known);
      final first = await saver().submit(known) as RecordingSubmitCommitted;
      expect(first.complete, isTrue);
      expect(first.timeBlock.title, '写作');
      expect(first.timeBlock.note, '边听歌\n继续写');
      expect(
        (await repository.readTimeBlock(first.timeBlock.id))!.timeBlock.note,
        '边听歌\n继续写',
      );
      expect(first.timeBlock.createdAt, current);
      expect(first.timeBlock.startPrecision, TimePrecision.approximate);
      expect(first.timeBlock.endPrecision, TimePrecision.exact);
      expect(await drafts.read(context), isNull);
      expect(first.refreshed!.coverage.accountedDuration.roundedMinutes, 60);

      final unknown = draft(
        start: at(11),
        end: at(11, 30),
        knowledge: BlockKnowledgeState.unknown,
        title: null,
        note: ' \n ',
      );
      await drafts.save(unknown);
      final second = await saver().submit(unknown) as RecordingSubmitCommitted;
      expect(second.complete, isTrue);
      expect(second.timeBlock.title, isNull);
      expect(second.timeBlock.note, isNull);
      expect(second.refreshed!.facts.timeBlocks, hasLength(2));
      expect(second.refreshed!.coverage.accountedDuration.roundedMinutes, 90);
      expect(second.refreshed!.coverage.unknownDuration.roundedMinutes, 30);
      expect(await drafts.read(context), isNull);
    },
  );

  test(
    'facts inserted after drafting cause TimeBlock and Sleep conflicts',
    () async {
      final pending = draft(start: at(10), end: at(11), note: '失败保留');
      await drafts.save(pending);
      await repository.createTimeBlock(
        id: newId(),
        startedAt: at(10, 30),
        endedAt: at(11, 30),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '已有活动',
        now: current,
      );
      final blockConflict =
          await saver().submit(pending) as RecordingSubmitFailed;
      expect(
        blockConflict.conflicts.single.reference.type,
        LedgerFactType.timeBlock,
      );
      expect((await drafts.read(context))!.title, pending.title);
      expect((await drafts.read(context))!.note, '失败保留');
      expect(
        (await repository.readWindow(
          startedAt: at(9),
          endedAt: at(14),
        )).timeBlocks,
        hasLength(1),
      );

      await repository.createSleepSession(
        id: newId(),
        startedAt: at(12),
        endedAt: at(13),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        now: current,
      );
      final sleeping = draft(start: at(12, 30), end: at(13, 30));
      await drafts.save(sleeping);
      final sleepConflict =
          await saver().submit(sleeping) as RecordingSubmitFailed;
      expect(
        sleepConflict.conflicts.single.reference.type,
        LedgerFactType.sleepSession,
      );
      expect((await drafts.read(context))!.startedAt, sleeping.startedAt);
      expect(
        (await repository.readWindow(
          startedAt: at(9),
          endedAt: at(14),
        )).timeBlocks,
        hasLength(1),
      );
    },
  );

  test('after commit, cleanup and refresh failures are retryable without another fact', () async {
    final input = draft(start: at(10), end: at(11));
    await drafts.save(input);
    final failing = FailingClearStore(drafts);
    var reads = 0;
    final service = saver(
      store: failing,
      refresh: ({required date, required now}) {
        reads++;
        if (reads == 1) throw StateError('private read SQL');
        return loader.load(date: date, now: now);
      },
    );
    final first = await service.submit(input) as RecordingSubmitCommitted;
    expect(first.complete, isFalse);
    expect(first.draftCleared, isFalse);
    expect(first.refreshed, isNull);
    expect(await drafts.read(context), isNotNull);
    failing.failClear = false;
    final finished = await service.finishCommitted(
      draftContext: context,
      timeBlock: first.timeBlock,
      draftCleared: first.draftCleared,
    );
    expect(finished.complete, isTrue);
    expect(finished.refreshed!.coverage.accountedDuration.roundedMinutes, 60);
    expect(await drafts.read(context), isNull);
    expect(
      (await repository.readWindow(
        startedAt: at(9),
        endedAt: at(12),
      )).timeBlocks,
      hasLength(1),
    );
  });

  test(
    'reopened stale draft recognizes committed fact and only finishes cleanup',
    () async {
      final input = draft(start: at(10), end: at(11), note: '已提交备注');
      await drafts.save(input);
      final failing = FailingClearStore(drafts);
      final first =
          await saver(store: failing).submit(input) as RecordingSubmitCommitted;
      expect(first.draftCleared, isFalse);
      final reopened = (await drafts.read(context))!;
      failing.failClear = false;
      final recovered = await saver(store: failing)
          .recoverCommittedDraft(reopened);
      expect(recovered!.complete, isTrue);
      expect(recovered.timeBlock.id, first.timeBlock.id);
      expect(await drafts.read(context), isNull);
      expect(
        (await repository.readWindow(
          startedAt: at(9),
          endedAt: at(12),
        )).timeBlocks,
        hasLength(1),
      );
    },
  );

  test(
    'recovery does not confuse matching times and title with a different note',
    () async {
      await repository.createTimeBlock(
        id: newId(),
        startedAt: at(10),
        endedAt: at(11),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '写作',
        note: '另一条备注',
        now: current,
      );
      final pending = draft(start: at(10), end: at(11), note: '待提交备注');
      expect(await saver().recoverCommittedDraft(pending), isNull);
    },
  );
}
