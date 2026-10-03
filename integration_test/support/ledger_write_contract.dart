import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const writeId = '00000000-0000-4000-8000-000000000001';
const writeId2 = '00000000-0000-4000-8000-000000000002';
const writeId3 = '00000000-0000-4000-8000-000000000003';
const explanation = AddAnnotation(
  id: writeId,
  state: RhythmState.stuck,
  stuckReasonCode: StuckReasonCode.brainFog,
  stuckReasonText: ' 原因\n详情 ',
  recoveryMethod: RecoveryMethod.walk,
  recoveryQuality: RecoveryQuality.partlyRecovered,
  continuationHint: ' 下次接着做 ',
);

Future<TimeBlockWriteResult> writeBlock(
  LedgerRepository repo, {
  String id = writeId,
  int start = 100,
  int end = 200,
  String? goalId,
  AddAnnotation? annotation,
}) => repo.createTimeBlock(
  id: id,
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  knowledgeState: BlockKnowledgeState.known,
  title: ' 活动 ',
  goalId: goalId,
  now: 1001,
  annotation: annotation,
);
Future<SleepSession> writeSleep(
  LedgerRepository repo, {
  String id = writeId,
  int start = 100,
  int end = 200,
}) => repo.createSleepSession(
  id: id,
  startedAt: start,
  endedAt: end,
  startPrecision: TimePrecision.exact,
  endPrecision: TimePrecision.approximate,
  type: SleepType.mainSleep,
  now: 1001,
);
Future<LedgerSnapshot> allLedger(LedgerRepository repo) =>
    repo.readWindow(startedAt: -1000000000000, endedAt: 2000000000000);

Future<List<Map<String, Object?>>> databaseFacts(AppDatabase db) async => [
  for (final table in [
    'goals',
    'time_blocks',
    'sleep_sessions',
    'rhythm_annotations',
    'daily_reviews',
  ])
    for (final row
        in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
      {'table': table, ...row.data},
];

final ledgerWriteChecks = <String, Future<void> Function(AppDatabase)>{
  'creation encodes all fields and commits facts and explanation together':
      (db) async {
        final LedgerRepository repo = DriftLedgerRepository(db);
        await DriftGoalRepository(db).create(id: writeId, name: '论文', now: 1);
        final saved = await repo.createTimeBlock(
          id: writeId,
          startedAt: -100,
          endedAt: 100,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.unknown,
          title: ' 保留描述 ',
          goalId: writeId,
          categoryId: ' extension ',
          note: '  原文\n下一段  ',
          now: 1234,
          annotation: explanation,
        );
        final sleep = await repo.createSleepSession(
          id: writeId,
          startedAt: 100,
          endedAt: 500,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          note: '  跨日原文  ',
          now: 2345,
        );
        final read = await allLedger(repo);
        final block = read.timeBlocks.single;
        expect(block.id, saved.timeBlock.id);
        expect(block.startedAt, -100);
        expect(block.endedAt, 100);
        expect(block.knowledgeState, BlockKnowledgeState.unknown);
        expect(block.startPrecision, TimePrecision.exact);
        expect(block.endPrecision, TimePrecision.approximate);
        expect(block.title, '保留描述');
        expect(block.goalId, writeId);
        expect(block.categoryId, ' extension ');
        expect(block.note, '原文\n下一段');
        expect(block.createdAt, 1234);
        expect(block.updatedAt, 1234);
        final a = read.annotations.single;
        expect(a.timeBlockId, writeId);
        expect(a.id, writeId);
        expect(a.state, RhythmState.stuck);
        expect(a.stuckReasonCode, StuckReasonCode.brainFog);
        expect(a.stuckReasonText, '原因\n详情');
        expect(a.recoveryMethod, RecoveryMethod.walk);
        expect(a.recoveryQuality, RecoveryQuality.partlyRecovered);
        expect(a.continuationHint, '下次接着做');
        expect(a.createdAt, 1234);
        expect(a.updatedAt, 1234);
        expect(read.sleepSessions.single.id, sleep.id);
        expect(read.sleepSessions.single.type, SleepType.nap);
        expect(read.sleepSessions.single.note, '跨日原文');
        expect(read.sleepSessions.single.createdAt, 2345);
        expect(
          read.sleepSessions.single.startPrecision,
          TimePrecision.approximate,
        );
        expect(read.sleepSessions.single.endPrecision, TimePrecision.exact);
      },
  'all four fact pairings reject positive overlaps and allow adjacent endpoints':
      (db) async {
        final repo = DriftLedgerRepository(db);
        for (final existingSleep in [false, true]) {
          for (final candidateSleep in [false, true]) {
            if (existingSleep) {
              await writeSleep(repo);
            } else {
              await writeBlock(repo);
            }
            final before = await databaseFacts(db);
            final attempt = candidateSleep
                ? writeSleep(repo, id: writeId2, start: 150, end: 250)
                : writeBlock(repo, id: writeId2, start: 150, end: 250);
            await expectLater(
              attempt,
              throwsA(
                isA<LedgerConflictException>().having(
                  (e) => e.conflicts.single.reference,
                  'conflict identity',
                  (
                    type: existingSleep
                        ? LedgerFactType.sleepSession
                        : LedgerFactType.timeBlock,
                    id: writeId,
                  ),
                ),
              ),
            );
            expect(await databaseFacts(db), before);
            if (candidateSleep) {
              await writeSleep(repo, id: writeId2, start: 200, end: 250);
            } else {
              await writeBlock(repo, id: writeId2, start: 200, end: 250);
            }
            for (final id in [writeId, writeId2]) {
              await repo.deleteTimeBlock(id);
              await repo.deleteSleepSession(id);
            }
          }
        }
      },
  'correction excludes only its own type and id, including same-id other facts':
      (db) async {
        final repo = DriftLedgerRepository(db);
        await writeBlock(repo, start: 10, end: 20, annotation: explanation);
        await writeSleep(repo, start: 30, end: 40);
        await repo.updateTimeBlock(
          id: writeId,
          now: 2,
          startedAt: 11,
          endedAt: 19,
        );
        await repo.updateSleepSession(
          id: writeId,
          now: 3,
          startedAt: 29,
          endedAt: 41,
        );
        final before = await databaseFacts(db);
        await expectLater(
          repo.updateTimeBlock(id: writeId, now: 4, startedAt: 35, endedAt: 36),
          throwsA(
            isA<LedgerConflictException>().having(
              (e) => e.conflicts.single.reference.type,
              'type',
              LedgerFactType.sleepSession,
            ),
          ),
        );
        await expectLater(
          repo.updateSleepSession(
            id: writeId,
            now: 4,
            startedAt: 12,
            endedAt: 18,
          ),
          throwsA(
            isA<LedgerConflictException>().having(
              (e) => e.conflicts.single.reference.type,
              'type',
              LedgerFactType.timeBlock,
            ),
          ),
        );
        expect(await databaseFacts(db), before);
        expect((await allLedger(repo)).annotations.single.updatedAt, 1001);
      },
  'explicit keep/add/edit/remove and metadata no-ops preserve intent':
      (db) async {
        final repo = DriftLedgerRepository(db);
        await writeBlock(repo);
        await repo.updateTimeBlock(
          id: writeId,
          now: 2,
          annotation: explanation,
        );
        final edited = await repo.updateTimeBlock(
          id: writeId,
          now: 3,
          knowledgeState: BlockKnowledgeState.unknown,
          note: (value: '备注'),
          annotation: const EditAnnotation(state: RhythmState.recovery),
        );
        expect(edited.timeBlock.createdAt, 1001);
        expect(edited.timeBlock.updatedAt, 3);
        expect(edited.timeBlock.title, '活动');
        expect(edited.annotation!.createdAt, 2);
        expect(edited.annotation!.stuckReasonCode, StuckReasonCode.brainFog);
        expect(edited.annotation!.continuationHint, '下次接着做');
        final kept = await repo.updateTimeBlock(
          id: writeId,
          now: 4,
          title: (value: '新名称'),
        );
        expect(kept.annotation!.updatedAt, 3);
        final cleared = await repo.updateTimeBlock(
          id: writeId,
          now: 5,
          annotation: const EditAnnotation(
            stuckReasonCode: (value: null),
            continuationHint: (value: null),
          ),
        );
        expect(cleared.timeBlock.updatedAt, 4);
        expect(cleared.annotation!.updatedAt, 5);
        expect(cleared.annotation!.stuckReasonCode, isNull);
        expect(cleared.annotation!.continuationHint, isNull);
        var before = await databaseFacts(db);
        await expectLater(
          repo.updateTimeBlock(
            id: writeId,
            now: 6,
            title: (value: '不能提交'),
            annotation: explanation,
          ),
          throwsA(isA<LedgerAnnotationOperationException>()),
        );
        expect(await databaseFacts(db), before);
        await db.customStatement(
          "CREATE TEMP TRIGGER no_block_update BEFORE UPDATE ON time_blocks BEGIN SELECT RAISE(FAIL, 'unexpected'); END",
        );
        await db.customStatement(
          "CREATE TEMP TRIGGER no_annotation_update BEFORE UPDATE ON rhythm_annotations BEGIN SELECT RAISE(FAIL, 'unexpected'); END",
        );
        await repo.updateTimeBlock(
          id: writeId,
          now: 999,
          title: (value: ' 新名称 '),
          annotation: const EditAnnotation(),
        );
        expect(await databaseFacts(db), before);
        await db.customStatement('DROP TRIGGER no_block_update');
        await db.customStatement('DROP TRIGGER no_annotation_update');
        await repo.updateTimeBlock(
          id: writeId,
          now: 7,
          annotation: const RemoveAnnotation(),
        );
        before = await databaseFacts(db);
        await repo.updateTimeBlock(
          id: writeId,
          now: 8,
          annotation: const RemoveAnnotation(),
        );
        expect(await databaseFacts(db), before);
        await expectLater(
          repo.updateTimeBlock(
            id: writeId,
            now: 9,
            note: (value: null),
            annotation: const EditAnnotation(),
          ),
          throwsA(isA<LedgerAnnotationOperationException>()),
        );
        expect(await databaseFacts(db), before);
        await writeSleep(repo, id: writeId2, start: 300, end: 400);
        await db.customStatement(
          "CREATE TEMP TRIGGER no_sleep_update BEFORE UPDATE ON sleep_sessions BEGIN SELECT RAISE(FAIL, 'unexpected'); END",
        );
        final same = await repo.updateSleepSession(id: writeId2, now: 999);
        expect(same.updatedAt, 1001);
        await db.customStatement('DROP TRIGGER no_sleep_update');
        final changed = await repo.updateSleepSession(
          id: writeId2,
          now: -1,
          type: SleepType.nap,
          note: (value: '  note  '),
          startPrecision: TimePrecision.approximate,
        );
        expect(changed.note, 'note');
        expect(changed.updatedAt, -1);
        expect(changed.createdAt, 1001);
      },
  'Goal is rechecked inside saves; archive preserves only existing associations':
      (db) async {
        final repo = DriftLedgerRepository(db);
        final goals = DriftGoalRepository(db);
        await goals.create(id: writeId, name: '目标', now: 1);
        await goals.create(id: writeId2, name: '另一个', now: 1);
        await goals.archive(id: writeId2, now: 2);
        for (final goal in [writeId2, writeId3]) {
          await expectLater(
            writeBlock(repo, goalId: goal),
            throwsArgumentError,
          );
          await expectLater(
            writeBlock(repo, goalId: goal, annotation: explanation),
            throwsArgumentError,
          );
        }
        await writeBlock(repo, goalId: writeId);
        await goals.archive(id: writeId, now: 3);
        await repo.updateTimeBlock(
          id: writeId,
          now: 4,
          note: (value: '历史关联'),
          annotation: explanation,
        );
        expect((await allLedger(repo)).timeBlocks.single.goalId, writeId);
        final before = await databaseFacts(db);
        await expectLater(
          repo.updateTimeBlock(id: writeId, now: 5, goalId: (value: writeId2)),
          throwsArgumentError,
        );
        expect(await databaseFacts(db), before);
        await repo.updateTimeBlock(id: writeId, now: 6, goalId: (value: null));
        await expectLater(
          repo.updateTimeBlock(id: writeId, now: 7, goalId: (value: writeId)),
          throwsArgumentError,
        );
        await goals.restore(id: writeId, now: 8);
        await repo.updateTimeBlock(
          id: writeId,
          now: 9,
          goalId: (value: writeId),
        );
      },
  'duplicate and missing operations never upsert or overwrite': (db) async {
    final repo = DriftLedgerRepository(db);
    await writeBlock(repo, annotation: explanation);
    await writeSleep(repo, start: 300, end: 400);
    final before = await databaseFacts(db);
    await expectLater(
      writeBlock(repo, start: 500, end: 600),
      throwsA(isA<LedgerFactAlreadyExistsException>()),
    );
    await expectLater(
      writeSleep(repo, start: 500, end: 600),
      throwsA(isA<LedgerFactAlreadyExistsException>()),
    );
    await expectLater(
      repo.updateTimeBlock(id: writeId2, now: 2),
      throwsA(isA<LedgerFactNotFoundException>()),
    );
    await expectLater(
      repo.updateSleepSession(id: writeId2, now: 2),
      throwsA(isA<LedgerFactNotFoundException>()),
    );
    await expectLater(
      writeBlock(repo, id: writeId2, start: 500, end: 500),
      throwsArgumentError,
    );
    await expectLater(
      writeSleep(repo, id: writeId2, start: 600, end: 500),
      throwsArgumentError,
    );
    await expectLater(
      repo.updateTimeBlock(id: writeId, now: 2, title: (value: null)),
      throwsArgumentError,
    );
    expect(await databaseFacts(db), before);
  },
  'approved deletes cascade only the explanation and remain idempotent':
      (db) async {
        final repo = DriftLedgerRepository(db);
        await writeBlock(repo, annotation: explanation);
        await writeSleep(repo, start: 300, end: 400);
        await db.customStatement(
          "INSERT INTO daily_reviews (id,review_date,tomorrow_first_step_text,created_at,updated_at) VALUES (?, '2026-09-27', '不改复盘', 1, 1)",
          [writeId],
        );
        await repo.deleteTimeBlock(writeId);
        await repo.deleteTimeBlock(writeId);
        var read = await allLedger(repo);
        expect(read.timeBlocks, isEmpty);
        expect(read.annotations, isEmpty);
        expect(read.sleepSessions, hasLength(1));
        await repo.deleteSleepSession(writeId);
        await repo.deleteSleepSession(writeId);
        read = await allLedger(repo);
        expect(read.sleepSessions, isEmpty);
        expect(
          (await db.select(db.dailyReviews).getSingle()).tomorrowFirstStepText,
          '不改复盘',
        );
      },
  'constraint failure after inserting a block rolls the whole combination back':
      (db) async {
        final repo = DriftLedgerRepository(db);
        await writeBlock(repo, annotation: explanation);
        final before = await databaseFacts(db);
        await expectLater(
          writeBlock(
            repo,
            id: writeId2,
            start: 300,
            end: 400,
            annotation: explanation,
          ),
          throwsA(isA<LedgerStorageException>()),
        ); // Existing annotation PK, not upsert.
        expect(await databaseFacts(db), before);
      },
  'failures mid-create/update/remove/delete leave all original rows intact':
      (db) async {
        final repo = DriftLedgerRepository(db);
        await db.customStatement(
          "CREATE TEMP TRIGGER fail_add AFTER INSERT ON rhythm_annotations BEGIN SELECT RAISE(FAIL, 'injected'); END",
        );
        await expectLater(
          writeBlock(repo, annotation: explanation),
          throwsA(isA<LedgerStorageException>()),
        );
        expect(await databaseFacts(db), isEmpty);
        await db.customStatement('DROP TRIGGER fail_add');
        await writeBlock(repo, annotation: explanation);
        await writeSleep(repo, start: 300, end: 400);
        final before = await databaseFacts(db);
        await db.customStatement(
          "CREATE TEMP TRIGGER fail_edit AFTER UPDATE ON rhythm_annotations BEGIN SELECT RAISE(FAIL, 'injected'); END",
        );
        await expectLater(
          repo.updateTimeBlock(
            id: writeId,
            now: 2,
            title: (value: '不能提交'),
            annotation: const EditAnnotation(state: RhythmState.progress),
          ),
          throwsA(isA<LedgerStorageException>()),
        );
        expect(await databaseFacts(db), before);
        await db.customStatement('DROP TRIGGER fail_edit');
        await db.customStatement(
          "CREATE TEMP TRIGGER fail_remove AFTER DELETE ON rhythm_annotations BEGIN SELECT RAISE(FAIL, 'injected'); END",
        );
        await expectLater(
          repo.updateTimeBlock(
            id: writeId,
            now: 3,
            note: (value: '不能提交'),
            annotation: const RemoveAnnotation(),
          ),
          throwsA(isA<LedgerStorageException>()),
        );
        expect(await databaseFacts(db), before);
        await expectLater(
          repo.deleteTimeBlock(writeId),
          throwsA(isA<LedgerStorageException>()),
        );
        expect(await databaseFacts(db), before);
        await db.customStatement('DROP TRIGGER fail_remove');
        await db.customStatement(
          "CREATE TEMP TRIGGER fail_sleep AFTER UPDATE ON sleep_sessions BEGIN SELECT RAISE(FAIL, 'injected'); END",
        );
        await expectLater(
          repo.updateSleepSession(id: writeId, now: 3, note: (value: '不能提交')),
          throwsA(isA<LedgerStorageException>()),
        );
        expect(await databaseFacts(db), before);
        await db.customStatement('DROP TRIGGER fail_sleep');
        await repo.updateTimeBlock(
          id: writeId,
          now: 4,
          title: (value: '重试成功'),
          annotation: const EditAnnotation(state: RhythmState.progress),
        );
        expect((await allLedger(repo)).timeBlocks.single.title, '重试成功');
      },
  'concurrent overlapping requests admit one fact, never both': (db) async {
    final repo = DriftLedgerRepository(db);
    Future<Object> outcome(Future<Object> operation) async {
      try {
        return await operation;
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      outcome(writeBlock(repo, annotation: explanation)),
      outcome(writeSleep(repo, id: writeId2, start: 150, end: 250)),
    ]);
    expect(results.whereType<LedgerConflictException>(), hasLength(1));
    final saved = await allLedger(repo);
    expect(saved.timeBlocks.length + saved.sleepSessions.length, 1);
    expect(saved.annotations.length, saved.timeBlocks.length);
  },
};

/// Records real executor usage, without fabricating rows or replacing SQLite.
class LedgerWriteTrace extends QueryInterceptor {
  bool enabled = false;
  final List<QueryExecutor> calls = [];
  final List<String> sql = [];
  int commits = 0;
  void record(QueryExecutor executor, String statement) {
    if (enabled) {
      calls.add(executor);
      sql.add(statement);
    }
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    record(executor, statement);
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    record(executor, statement);
    return executor.runInsert(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    if (enabled) commits++;
    return inner.send();
  }
}

Future<void> verifyWriteTransaction(
  AppDatabase db,
  LedgerWriteTrace trace,
) async {
  trace.enabled = true;
  try {
    await writeBlock(DriftLedgerRepository(db), annotation: explanation);
  } finally {
    trace.enabled = false;
  }
  expect(trace.calls.first, isA<TransactionExecutor>());
  expect(
    trace.calls.every((call) => identical(call, trace.calls.first)),
    isTrue,
  );
  expect(trace.commits, 1);
  final firstInsert = trace.sql.indexWhere((sql) => sql.startsWith('INSERT'));
  expect(firstInsert, greaterThan(0));
  expect(
    trace.sql
        .take(firstInsert)
        .any((sql) => sql.contains('FROM time_blocks WHERE started_at')),
    isTrue,
  );
  expect(
    trace.sql
        .take(firstInsert)
        .any((sql) => sql.contains('FROM sleep_sessions WHERE started_at')),
    isTrue,
  );
}
