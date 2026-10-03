import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import 'sleep_entry_saver_test.dart' show FailingSleepClearStore;

const sleepId = '00000000-0000-4000-8000-000000000001';
const blockId = '00000000-0000-4000-8000-000000000002';
const napId = '00000000-0000-4000-8000-000000000003';
const reviewId = '00000000-0000-4000-8000-000000000004';
CivilDate day(int number) => CivilDate(year: 2026, month: 9, day: number);
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;
final editContext = SleepDraftContext.edit(
  date: day(28),
  sleepSessionId: sleepId,
);
SleepDraft input({
  int? start,
  int? end,
  SleepType type = SleepType.mainSleep,
  TimePrecision startPrecision = TimePrecision.approximate,
  TimePrecision endPrecision = TimePrecision.exact,
}) => SleepDraft(
  context: editContext,
  startedAt: start ?? at(28, 23, 50),
  endedAt: end ?? at(29, 7, 40),
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  type: type,
);

void main() {
  late AppDatabase db;
  late DriftLedgerRepository repo;
  late DriftSleepDraftStore drafts;
  late SleepLedgerLoader loader;
  late SleepEntrySaver saver;
  late SleepEntryEditor editor;
  var clock = at(30, 12);
  Future<SleepSession> create() => repo.createSleepSession(
    id: sleepId,
    startedAt: at(28, 23, 50),
    endedAt: at(29, 7, 40),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: 1,
    note: '原备注\n继续保留',
  );
  SleepEntryEditor service({
    SleepDraftStore? store,
    SleepLedgerRefresh? refresh,
  }) {
    final saver = SleepEntrySaver(
      repository: repo,
      drafts: store ?? drafts,
      refresh: refresh ?? loader.load,
      newId: () => throw StateError('Editing must never create identity'),
      now: () => clock,
    );
    return SleepEntryEditor(
      repository: repo,
      drafts: store ?? drafts,
      saver: saver,
      dateOfInstant: deviceDateOfInstant,
    );
  }

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
    clock = at(30, 12);
    db = await AppDatabase.open(NativeDatabase.memory());
    repo = DriftLedgerRepository(db);
    drafts = await DriftSleepDraftStore.open(NativeDatabase.memory());
    loader = SleepLedgerLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
    );
    saver = SleepEntrySaver(
      repository: repo,
      drafts: drafts,
      refresh: loader.load,
      newId: () => throw StateError('No new identity'),
      now: () => clock,
    );
    editor = SleepEntryEditor(
      repository: repo,
      drafts: drafts,
      saver: saver,
      dateOfInstant: deviceDateOfInstant,
    );
  });
  tearDown(() async {
    await drafts.close();
    await db.close();
  });

  test('read by id returns complete cross-day source and hidden fields; missing/corrupt/storage errors are distinct', () async {
    await create();
    final original = (await editor.load(sleepId))!;
    expect(original.startedAt, at(28, 23, 50));
    expect(original.endedAt, at(29, 7, 40));
    expect(original.note, '原备注\n继续保留');
    expect(original.createdAt, 1);
    expect(await editor.load(napId), isNull);
    await db.customStatement('PRAGMA ignore_check_constraints = ON');
    await db.customStatement(
      "UPDATE sleep_sessions SET sleep_type = 'corrupt' WHERE id = '$sleepId'",
    );
    await expectLater(
      editor.load(sleepId),
      throwsA(isA<LedgerDataException>()),
    );
    final closed = await AppDatabase.open(NativeDatabase.memory());
    final closedRepo = DriftLedgerRepository(closed);
    await closed.close();
    await expectLater(
      closedRepo.readSleepSession(sleepId),
      throwsA(isA<LedgerStorageException>()),
    );
  });

  test('cross-day edits move wake summary, preserve identity/note, switch both types and independently change precision', () async {
    final original = await create();
    await DriftReviewRepository(db).create(
      id: reviewId,
      date: day(29),
      summary: '已有解释',
      reflection: '保留反思',
      tomorrowFirstStepText: '继续',
      now: 1,
    );
    final before = await db.customSelect('SELECT * FROM daily_reviews').get();
    final pending = input(
      start: at(29, 23, 40),
      end: at(30, 7, 40),
      type: SleepType.nap,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
    );
    await drafts.save(pending);
    expect((await editor.load(sleepId))!.startedAt, original.startedAt);
    // Omitted note must retain the latest transaction value, not a stale form copy.
    await repo.updateSleepSession(id: sleepId, now: 2, note: (value: '最新备注'));
    final result =
        await editor.save(pending, original: original) as SleepSubmitCommitted;
    expect(result.complete, isTrue);
    expect(result.sleepSession.id, sleepId);
    expect(result.sleepSession.createdAt, 1);
    expect(result.sleepSession.updatedAt, clock);
    expect(result.sleepSession.note, '最新备注');
    expect(result.sleepSession.startPrecision, TimePrecision.exact);
    expect(result.sleepSession.endPrecision, TimePrecision.approximate);
    expect(result.refreshedDates.keys.toSet(), {day(28), day(29), day(30)});
    expect(
      result.refreshedDates[day(28)]!.coverage.accountedDuration.roundedMinutes,
      0,
    );
    expect(
      result.refreshedDates[day(29)]!.sleepSummary.mainSleep.records,
      isEmpty,
    );
    expect(
      result.refreshedDates[day(29)]!.coverage.accountedDuration.roundedMinutes,
      20,
    );
    expect(
      result
          .refreshedDates[day(30)]!
          .sleepSummary
          .nap
          .totalDuration
          .duration
          .roundedMinutes,
      480,
    );
    expect(
      result.refreshedDates[day(30)]!.coverage.accountedDuration.roundedMinutes,
      460,
    );
    expect(await drafts.read(editContext), isNull);
    clock += 1000;
    final back = input(
      start: pending.startedAt,
      end: pending.endedAt,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
    );
    final reverted = await editor.save(
      back,
      original: result.sleepSession,
    ) as SleepSubmitCommitted;
    expect(reverted.sleepSession.type, SleepType.mainSleep);
    expect(reverted.refreshedDates[day(30)]!.sleepSummary.nap.records, isEmpty);
    expect(
      reverted.refreshedDates[day(30)]!.sleepSummary.mainSleep.records,
      hasLength(1),
    );
    expect(
      (await db.customSelect('SELECT * FROM daily_reviews').get()).map(
        (r) => r.data,
      ),
      before.map((r) => r.data),
    );
    expect(
      await db.customSelect('SELECT * FROM sleep_sessions').get(),
      hasLength(1),
    );
  });

  test('unchanged save performs no UPDATE and preserves millisecond boundaries plus updatedAt', () async {
    final original = await repo.createSleepSession(
      id: sleepId,
      startedAt: at(28, 23, 50) + 123,
      endedAt: at(29, 7, 40) + 456,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 1,
    );
    await db.customStatement(
      "CREATE TRIGGER no_sleep_update BEFORE UPDATE ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'unexpected update'); END",
    );
    final pending = input(start: original.startedAt, end: original.endedAt);
    await drafts.save(pending);
    final result =
        await editor.save(pending, original: original) as SleepSubmitCommitted;
    expect(result.complete, isTrue);
    expect(result.sleepSession.updatedAt, 1);
    expect(result.sleepSession.startedAt, original.startedAt);
    expect(result.sleepSession.endedAt, original.endedAt);
    expect(await drafts.read(editContext), isNull);
  });

  test('current TimeBlock and sleep conflicts reject atomically, preserve draft and all facts', () async {
    final original = await create();
    final pending = input(start: at(29, 10), end: at(29, 12));
    await drafts.save(pending);
    await repo.createTimeBlock(
      id: blockId,
      startedAt: at(29, 10),
      endedAt: at(29, 11),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '日间活动',
      now: 1,
    );
    await repo.createSleepSession(
      id: napId,
      startedAt: at(29, 11),
      endedAt: at(29, 12),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      type: SleepType.nap,
      now: 1,
    );
    final before = await snapshot();
    final result =
        await editor.save(pending, original: original) as SleepSubmitFailed;
    expect(result.conflicts.map((c) => c.reference.type).toSet(), {
      LedgerFactType.timeBlock,
      LedgerFactType.sleepSession,
    });
    expect(await snapshot(), before);
    expect(await drafts.read(editContext), isNotNull);
  });

  for (final operation in ['update', 'delete']) {
    test(
      'SQLite $operation failure rolls back and retains original plus edit draft',
      () async {
        final original = await create();
        final pending = input(end: at(29, 8));
        await drafts.save(pending);
        final before = await snapshot();
        await db.customStatement(
          "CREATE TRIGGER fail_sleep AFTER ${operation.toUpperCase()} ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
        );
        if (operation == 'update') {
          expect(
            await editor.save(pending, original: original),
            isA<SleepSubmitFailed>(),
          );
        } else {
          expect(
            await editor.delete(context: editContext, original: original),
            isA<SleepDeleteFailed>(),
          );
        }
        expect(await snapshot(), before);
        expect((await drafts.read(editContext))!.endedAt, pending.endedAt);
      },
    );
  }

  test('delete recalculates both days and wake summary, leaves review; repeat delete succeeds, missing edit never recreates', () async {
    final original = await create();
    await DriftReviewRepository(db).create(
      id: reviewId,
      date: day(29),
      summary: '原复盘',
      tomorrowFirstStepText: '继续',
      now: 1,
    );
    await drafts.save(input(end: at(29, 8)));
    final result = await editor.delete(
      context: editContext,
      original: original,
    ) as SleepDeleteCommitted;
    expect(result.complete, isTrue);
    expect(await editor.load(sleepId), isNull);
    expect(
      result.refreshedDates[day(28)]!.coverage.accountedDuration.roundedMinutes,
      0,
    );
    expect(
      result.refreshedDates[day(29)]!.sleepSummary.mainSleep.records,
      isEmpty,
    );
    expect(
      result.refreshedDates[day(29)]!.coverage.unresolvedSpans,
      hasLength(1),
    );
    expect(
      (await DriftReviewRepository(db).findByDate(day(29)))!.summary,
      '原复盘',
    );
    expect(
      (await editor.delete(
        context: editContext,
        original: original,
      ) as SleepDeleteCommitted).complete,
      isTrue,
    );
    final pending = input(end: at(29, 8));
    await drafts.save(pending);
    final failed =
        await editor.save(pending, original: original) as SleepSubmitFailed;
    expect(failed.notFound, isTrue);
    expect(await drafts.read(editContext), isNotNull);
    expect(
      await db.customSelect('SELECT * FROM sleep_sessions').get(),
      isEmpty,
    );
  });

  for (final operation in ['update', 'delete']) {
    test(
      '$operation commit survives cleanup and an old/new day refresh failure; retry performs only cleanup/read',
      () async {
        final original = await create();
        final pending = input(start: at(29, 23, 50), end: at(30, 7, 40));
        await drafts.save(pending);
        final store = FailingSleepClearStore(drafts);
        var failRead = true;
        final refreshCalls = <CivilDate>[];
        final failing = service(
          store: store,
          refresh: ({required date, required now}) async {
            refreshCalls.add(date);
            if (failRead && date == day(29)) {
              throw StateError('private read SQL');
            }
            return loader.load(date: date, now: now);
          },
        );
        if (operation == 'update') {
          final first = await failing.save(
            pending,
            original: original,
          ) as SleepSubmitCommitted;
          expect(first.refreshed, isNotNull);
          expect(first.refreshComplete, isFalse);
          expect(first.draftCleared, isFalse);
          expect((await editor.load(sleepId))!.endedAt, pending.endedAt);
          await db.customStatement(
            "CREATE TRIGGER no_repeat BEFORE UPDATE ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'repeat mutation'); END",
          );
          failRead = false;
          store.failClear = false;
          final finished = await failing.saver.finishCommitted(
            context: editContext,
            sleepSession: first.sleepSession,
            draftCleared: first.draftCleared,
            refreshDates: first.refreshDates,
          );
          expect(finished.complete, isTrue);
          expect(
            finished.refreshedDates[day(30)]!.sleepSummary.mainSleep.records,
            hasLength(1),
          );
        } else {
          final first = await failing.delete(
            context: editContext,
            original: original,
          ) as SleepDeleteCommitted;
          expect(first.refreshed, isNotNull);
          expect(first.refreshComplete, isFalse);
          expect(await editor.load(sleepId), isNull);
          await db.customStatement(
            "CREATE TRIGGER no_repeat BEFORE DELETE ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'repeat mutation'); END",
          );
          failRead = false;
          store.failClear = false;
          final finished = await failing.finishDelete(
            context: editContext,
            draftCleared: first.draftCleared,
            refreshDates: first.refreshDates,
          );
          expect(finished.complete, isTrue);
          expect(
            finished.refreshedDates[day(29)]!.sleepSummary.mainSleep.records,
            isEmpty,
          );
        }
        expect(refreshCalls.contains(day(29)), isTrue);
        expect(await drafts.read(editContext), isNull);
      },
    );
  }
}
