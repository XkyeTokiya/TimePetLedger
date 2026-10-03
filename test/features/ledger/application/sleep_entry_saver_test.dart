import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

final date = CivilDate(year: 2026, month: 9, day: 29);
final context = SleepDraftContext.newEntry(date: date);
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;
final current = at(29, 15);
SleepDraft draft({
  int? start,
  int? end,
  SleepType type = SleepType.mainSleep,
  String? note,
  bool noteProvided = false,
}) => SleepDraft(
  context: context,
  startedAt: start ?? at(28, 23, 50),
  endedAt: end ?? at(29, 7, 40),
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  type: type,
  note: note,
  noteProvided: noteProvided,
);

class FailingSleepClearStore implements SleepDraftStore {
  FailingSleepClearStore(this.inner);
  final SleepDraftStore inner;
  bool failClear = true;
  int clears = 0;
  @override
  Future<SleepDraft?> read(SleepDraftContext context) => inner.read(context);
  @override
  Future<void> save(SleepDraft draft) => inner.save(draft);
  @override
  Future<void> clear(SleepDraftContext context) async {
    clears++;
    if (failClear) throw StateError('private SQL');
    await inner.clear(context);
  }
}

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repository;
  late DriftSleepDraftStore drafts;
  late SleepLedgerLoader loader;
  var ids = 0;
  String newId() =>
      '00000000-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}';
  SleepEntrySaver saver({
    SleepDraftStore? store,
    SleepLedgerRefresh? refresh,
  }) => SleepEntrySaver(
    repository: repository,
    drafts: store ?? drafts,
    refresh: refresh ?? loader.load,
    newId: newId,
    now: () => current,
  );
  Future<List<List<Map<String, Object?>>>> snapshot() async => [
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  ];
  setUp(() async {
    ids = 0;
    db = await AppDatabase.open(NativeDatabase.memory());
    repository = DriftLedgerRepository(db);
    drafts = await DriftSleepDraftStore.open(NativeDatabase.memory());
    loader = SleepLedgerLoader(
      repository: repository,
      resolveDate: resolveDeviceRecordingDate,
    );
  });
  tearDown(() async {
    await drafts.close();
    await db.close();
  });

  test(
    'overlong note is rejected by formal write and retains the raw draft',
    () async {
      final input = draft(note: '😀' * 2001, noteProvided: true);
      await drafts.save(input);
      final before = await snapshot();
      expect(await saver().submit(input), isA<SleepSubmitFailed>());
      expect(await snapshot(), before);
      expect((await drafts.read(context))!.note, input.note);
    },
  );

  test('committed recovery matches normalized note before clearing a residual draft', () async {
    final input = draft(note: '  第一行\n  第二行😀  ', noteProvided: true);
    await drafts.save(input);
    final store = FailingSleepClearStore(drafts);
    final service = saver(store: store);
    final committed = await service.submit(input) as SleepSubmitCommitted;
    expect(committed.sleepSession.note, '第一行\n  第二行😀');
    expect(committed.draftCleared, isFalse);
    expect(
      await service.recoverCommittedDraft(
        draft(note: '不同备注', noteProvided: true),
      ),
      isNull,
    );
    expect((await drafts.read(context))!.note, input.note);
    store.failClear = false;
    final recovered = (await service.recoverCommittedDraft(input))!;
    expect(recovered.complete, isTrue);
    expect(recovered.sleepSession.id, committed.sleepSession.id);
    expect(ids, 1);
    expect(await drafts.read(context), isNull);
    expect(
      await db.customSelect('SELECT * FROM sleep_sessions').get(),
      hasLength(1),
    );
  });

  test('cross-day mainSleep and adjacent nap keep complete facts, clear drafts and refresh both projections', () async {
    final main = draft();
    await drafts.save(main);
    final first = await saver().submit(main) as SleepSubmitCommitted;
    expect(first.complete, isTrue);
    expect(first.sleepSession.startedAt, at(28, 23, 50));
    expect(first.sleepSession.endedAt, at(29, 7, 40));
    expect(first.sleepSession.createdAt, current);
    expect(first.sleepSession.updatedAt, current);
    expect(first.sleepSession.startPrecision, TimePrecision.approximate);
    expect(first.sleepSession.endPrecision, TimePrecision.exact);
    expect(
      first
          .refreshed!
          .sleepSummary
          .mainSleep
          .totalDuration
          .duration
          .roundedMinutes,
      470,
    );
    expect(
      first
          .refreshed!
          .sleepSummary
          .mainSleep
          .totalDuration
          .duration
          .hasApproximation,
      isTrue,
    );
    expect(first.refreshed!.coverage.accountedDuration.roundedMinutes, 460);
    expect(
      first.refreshed!.coverage.accountedDuration.hasApproximation,
      isFalse,
    );
    expect(await drafts.read(context), isNull);
    final nap = draft(
      start: at(29, 7, 40),
      end: at(29, 8),
      type: SleepType.nap,
    );
    await drafts.save(nap);
    final second = await saver().submit(nap) as SleepSubmitCommitted;
    expect(second.complete, isTrue);
    expect(second.refreshed!.sleepSummary.mainSleep.records, hasLength(1));
    expect(
      second.refreshed!.sleepSummary.nap.totalDuration.duration.roundedMinutes,
      20,
    );
    expect(second.refreshed!.coverage.accountedDuration.roundedMinutes, 480);
    expect(second.refreshed!.coverage.unresolvedDuration.roundedMinutes, 420);
    expect(await drafts.read(context), isNull);
    final rows = await db.customSelect('SELECT * FROM sleep_sessions').get();
    expect(rows, hasLength(2));
    expect(await db.customSelect('SELECT * FROM time_blocks').get(), isEmpty);
    expect(
      await db.customSelect('SELECT * FROM rhythm_annotations').get(),
      isEmpty,
    );
    final previousDay = await loader.load(
      date: CivilDate(year: 2026, month: 9, day: 28),
      now: current,
    );
    expect(previousDay.coverage.accountedDuration.roundedMinutes, 10);
    expect(previousDay.sleepSummary.mainSleep.records, isEmpty);
  });

  test('facts arriving after drafting reject both conflict types atomically and preserve all original rows', () async {
    final input = draft(start: at(29, 10), end: at(29, 12));
    await drafts.save(input);
    expect(
      (await loader.load(
        date: date,
        now: current,
      )).facts.windowFacts.timeBlocks,
      isEmpty,
    );
    await repository.createTimeBlock(
      id: newId(),
      startedAt: at(29, 10),
      endedAt: at(29, 11),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.unknown,
      now: current,
    );
    await repository.createSleepSession(
      id: newId(),
      startedAt: at(29, 11),
      endedAt: at(29, 12),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.nap,
      now: current,
    );
    final before = await snapshot();
    final result = await saver().submit(input) as SleepSubmitFailed;
    expect(result.conflicts.map((c) => c.reference.type).toSet(), {
      LedgerFactType.timeBlock,
      LedgerFactType.sleepSession,
    });
    expect(result.conflicts.map((c) => (c.startedAt, c.endedAt)), [
      (at(29, 10), at(29, 11)),
      (at(29, 11), at(29, 12)),
    ]);
    expect(await snapshot(), before);
    expect((await drafts.read(context))!.endedAt, input.endedAt);
    // A manual correction may meet either fact type's boundary without overlap.
    final beforeBlock = draft(start: at(29, 9), end: at(29, 10));
    await drafts.save(beforeBlock);
    expect(
      (await saver().submit(beforeBlock) as SleepSubmitCommitted).complete,
      isTrue,
    );
    final corrected = draft(start: at(29, 12), end: at(29, 13));
    await drafts.save(corrected);
    expect(await saver().submit(corrected), isA<SleepSubmitCommitted>());
  });

  test('failure after SQLite INSERT rolls back the attempted row and preserves draft and other facts', () async {
    await repository.createSleepSession(
      id: newId(),
      startedAt: at(29, 13),
      endedAt: at(29, 14),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.nap,
      now: current,
    );
    final input = draft();
    await drafts.save(input);
    final before = await snapshot();
    await db.customStatement(
      "CREATE TRIGGER fail_sleep AFTER INSERT ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
    expect(await saver().submit(input), isA<SleepSubmitFailed>());
    expect(await snapshot(), before);
    expect((await drafts.read(context))!.startedAt, input.startedAt);
    await db.customStatement('DROP TRIGGER fail_sleep');
    expect(
      (await saver().submit(input) as SleepSubmitCommitted).complete,
      isTrue,
    );
  });

  for (final failClear in [false, true]) {
    for (final failRefresh in [false, true]) {
      if (!failClear && !failRefresh) continue;
      test(
        'committed clear=$failClear refresh=$failRefresh failures retry without another create',
        () async {
          final input = draft();
          await drafts.save(input);
          final store = FailingSleepClearStore(drafts)..failClear = failClear;
          var failingRead = failRefresh;
          final service = saver(
            store: store,
            refresh: ({required date, required now}) async {
              if (failingRead) throw StateError('private read');
              return loader.load(date: date, now: now);
            },
          );
          final first = await service.submit(input) as SleepSubmitCommitted;
          expect(first.draftCleared, !failClear);
          expect(first.refreshed == null, failRefresh);
          expect(first.complete, isFalse);
          expect(
            await db.customSelect('SELECT * FROM sleep_sessions').get(),
            hasLength(1),
          );
          store.failClear = false;
          failingRead = false;
          final second = await service.finishCommitted(
            context: context,
            sleepSession: first.sleepSession,
            draftCleared: first.draftCleared,
          );
          expect(second.complete, isTrue);
          expect(ids, 1);
          expect(store.clears, failClear ? 2 : 1);
          expect(await drafts.read(context), isNull);
          expect(
            second.refreshed!.coverage.accountedDuration.roundedMinutes,
            460,
          );
        },
      );
    }
  }

  test('residual draft recovery checks full input and cannot mistake nap or a note for a submitted main sleep', () async {
    final input = draft();
    await drafts.save(input);
    final store = FailingSleepClearStore(drafts);
    final service = saver(store: store);
    final first = await service.submit(input) as SleepSubmitCommitted;
    expect(first.draftCleared, isFalse);
    expect(
      await service.recoverCommittedDraft(draft(type: SleepType.nap)),
      isNull,
    );
    store.failClear = false;
    final recovered = await service.recoverCommittedDraft(
      (await drafts.read(context))!,
    );
    expect(recovered!.complete, isTrue);
    expect(recovered.sleepSession.id, first.sleepSession.id);
    expect(ids, 1);
    await repository.updateSleepSession(
      id: first.sleepSession.id,
      now: current,
      note: (value: '另一个内容'),
    );
    expect(await service.recoverCommittedDraft(input), isNull);
  });
}
