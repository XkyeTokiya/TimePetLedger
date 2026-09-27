import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const ledgerId = '00000000-0000-4000-8000-000000000001';
const secondLedgerId = '00000000-0000-4000-8000-000000000002';
const thirdLedgerId = '00000000-0000-4000-8000-000000000003';
final dayStart = DateTime.utc(2026, 9, 27).millisecondsSinceEpoch;
const hour = 3600000;

Future<void> insertLedgerRow(
  AppDatabase db,
  String table,
  Map<String, Object?> row,
) => db.customStatement(
  'INSERT INTO $table (${row.keys.join(', ')}) VALUES '
  '(${List.filled(row.length, '?').join(', ')})',
  row.values.toList(),
);

Map<String, Object?> blockRow({String id = ledgerId, int? start, int? end}) => {
  'id': id,
  'started_at': start ?? dayStart + 8 * hour,
  'ended_at': end ?? dayStart + 9 * hour,
  'start_precision': 'approximate',
  'end_precision': 'exact',
  'knowledge_state': 'known',
  'title': '写论文',
  'goal_id': null,
  'category_id': null,
  'note': null,
  'created_at': 123,
  'updated_at': 456,
};
Map<String, Object?> sleepRow({String id = ledgerId, int? start, int? end}) => {
  'id': id,
  'started_at': start ?? dayStart - 600000,
  'ended_at': end ?? dayStart + 7 * hour + 2400000,
  'start_precision': 'exact',
  'end_precision': 'approximate',
  'sleep_type': 'mainSleep',
  'note': null,
  'created_at': 234,
  'updated_at': 567,
};
Map<String, Object?> annotationRow({
  String id = ledgerId,
  String blockId = ledgerId,
}) => {
  'id': id,
  'time_block_id': blockId,
  'state': 'progress',
  'stuck_reason_code': null,
  'stuck_reason_text': null,
  'recovery_method': null,
  'recovery_quality': null,
  'continuation_hint': null,
  'created_at': 345,
  'updated_at': 678,
};

Future<LedgerSnapshot> readDay(AppDatabase db) =>
    DriftLedgerRepository(db)
        .readWindow(startedAt: dayStart, endedAt: dayStart + 24 * hour);

final ledgerReadChecks = <String, Future<void> Function(AppDatabase)>{
  'cross-midnight complete facts, precision and every optional field survive':
      (db) async {
        await insertLedgerRow(db, 'goals', {
          'id': ledgerId,
          'name': '论文',
          'status': 'active',
          'created_at': 1,
          'updated_at': 1,
        });
        await insertLedgerRow(db, 'time_blocks', {
          ...blockRow(),
          'goal_id': ledgerId,
          'category_id': '  extension  ',
          'note': '内部  空格\n下一段',
        });
        await insertLedgerRow(db, 'time_blocks', {
          ...blockRow(
            id: secondLedgerId,
            start: dayStart + 23 * hour,
            end: dayStart + 25 * hour,
          ),
          'knowledge_state': 'unknown',
          'title': null,
        });
        await insertLedgerRow(db, 'sleep_sessions', {
          ...sleepRow(),
          'note': '跨日睡眠',
        });
        await insertLedgerRow(db, 'sleep_sessions', {
          ...sleepRow(
            id: secondLedgerId,
            start: dayStart + 12 * hour,
            end: dayStart + 13 * hour,
          ),
          'sleep_type': 'nap',
        });
        await insertLedgerRow(db, 'rhythm_annotations', {
          ...annotationRow(),
          'stuck_reason_code': 'brainFog',
          'stuck_reason_text': '保留  原因\n文字',
          'recovery_method': 'walk',
          'recovery_quality': 'partlyRecovered',
          'continuation_hint': '打开设计图\n补充字段',
        });
        await db.customStatement(
          "UPDATE goals SET status = 'archived', archived_at = 2",
        );
        final before = await db
            .customSelect('SELECT * FROM time_blocks ORDER BY id')
            .get();
        final result = await readDay(db);
        expect(result.timeBlocks, hasLength(2));
        expect(result.sleepSessions, hasLength(2));
        expect(result.annotations, hasLength(1));
        final block = result.timeBlocks.first;
        expect(block.id, ledgerId);
        expect(block.startedAt, dayStart + 8 * hour);
        expect(block.endedAt, dayStart + 9 * hour);
        expect(block.startPrecision, TimePrecision.approximate);
        expect(block.endPrecision, TimePrecision.exact);
        expect(block.title, '写论文');
        expect(block.goalId, ledgerId);
        expect(block.categoryId, '  extension  ');
        expect(block.note, '内部  空格\n下一段');
        expect(block.createdAt, 123);
        expect(block.updatedAt, 456);
        expect(result.timeBlocks.last.endedAt, dayStart + 25 * hour);
        expect(result.timeBlocks.last.knowledgeState.name, 'unknown');
        expect(result.timeBlocks.last.title, isNull);
        expect(result.timeBlocks.last.goalId, isNull);
        expect(result.timeBlocks.last.categoryId, isNull);
        expect(result.timeBlocks.last.note, isNull);
        final sleep = result.sleepSessions.first;
        expect(
          sleep.id,
          ledgerId,
        ); // Same id across different fact types is legal.
        expect(sleep.startedAt, dayStart - 600000);
        expect(sleep.endedAt, dayStart + 7 * hour + 2400000);
        expect(sleep.startPrecision, TimePrecision.exact);
        expect(sleep.endPrecision, TimePrecision.approximate);
        expect(sleep.type, SleepType.mainSleep);
        expect(sleep.note, '跨日睡眠');
        expect(sleep.createdAt, 234);
        expect(sleep.updatedAt, 567);
        expect(result.sleepSessions.last.type, SleepType.nap);
        expect(result.sleepSessions.last.note, isNull);
        final a = result.annotations.single;
        expect(a.id, ledgerId);
        expect(a.timeBlockId, ledgerId);
        expect(a.state, RhythmState.progress);
        expect(a.stuckReasonCode, StuckReasonCode.brainFog);
        expect(a.stuckReasonText, '保留  原因\n文字');
        expect(a.recoveryMethod, RecoveryMethod.walk);
        expect(a.recoveryQuality, RecoveryQuality.partlyRecovered);
        expect(a.continuationHint, '打开设计图\n补充字段');
        expect(a.createdAt, 345);
        expect(a.updatedAt, 678);
        expect(
          a.applicableStuckReasonCode,
          isNull,
        ); // Stored details are not erased.
        expect(
          (await db.customSelect('SELECT * FROM time_blocks ORDER BY id').get())
              .map((row) => row.data),
          before.map((row) => row.data),
        );
        expect(() => result.timeBlocks.clear(), throwsUnsupportedError);
        expect(() => result.sleepSessions.clear(), throwsUnsupportedError);
        expect(() => result.annotations.clear(), throwsUnsupportedError);
      },
  'half-open intersection includes containing and contained facts, not touching':
      (db) async {
        final repo = DriftLedgerRepository(db);
        for (final table in ['time_blocks', 'sleep_sessions']) {
          for (final range in [
            (0, 100),
            (20, 30),
            (10, 25),
            (25, 40),
            (0, 20),
            (30, 40),
          ]) {
            final row = table == 'time_blocks'
                ? blockRow(start: range.$1, end: range.$2)
                : sleepRow(start: range.$1, end: range.$2);
            await insertLedgerRow(db, table, row);
            if (table == 'time_blocks') {
              await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
            }
            final result = await repo.readWindow(startedAt: 20, endedAt: 30);
            final intersects = range.$1 < 30 && range.$2 > 20;
            if (table == 'time_blocks') {
              expect(result.timeBlocks, hasLength(intersects ? 1 : 0));
              expect(result.annotations, hasLength(intersects ? 1 : 0));
              if (intersects) {
                expect(result.timeBlocks.single.startedAt, range.$1);
                expect(result.timeBlocks.single.endedAt, range.$2);
              }
            } else {
              expect(result.sleepSessions, hasLength(intersects ? 1 : 0));
              if (intersects) {
                expect(result.sleepSessions.single.startedAt, range.$1);
                expect(result.sleepSessions.single.endedAt, range.$2);
              }
            }
            await db.customStatement('DELETE FROM $table');
          }
        }
      },
  'empty/no-match windows stay empty; unrelated annotations are excluded':
      (db) async {
        final repo = DriftLedgerRepository(db);
        expect((await readDay(db)).timeBlocks, isEmpty);
        await insertLedgerRow(db, 'time_blocks', blockRow());
        await insertLedgerRow(
          db,
          'time_blocks',
          blockRow(
            id: secondLedgerId,
            start: dayStart + 25 * hour,
            end: dayStart + 26 * hour,
          ),
        );
        await insertLedgerRow(
          db,
          'rhythm_annotations',
          annotationRow(id: secondLedgerId, blockId: secondLedgerId),
        );
        final result = await readDay(db);
        expect(result.timeBlocks.single.id, ledgerId);
        expect(result.sleepSessions, isEmpty);
        expect(result.annotations, isEmpty);
        final empty = await repo.readWindow(
          startedAt: dayStart + 8 * hour + 1,
          endedAt: dayStart + 8 * hour + 1,
        );
        expect(empty.timeBlocks, isEmpty);
        expect(empty.sleepSessions, isEmpty);
        expect(empty.annotations, isEmpty);
        final noMatch = await repo.readWindow(startedAt: 0, endedAt: 1);
        expect(noMatch.timeBlocks, isEmpty);
        expect(noMatch.sleepSessions, isEmpty);
        expect(noMatch.annotations, isEmpty);
        await expectLater(
          repo.readWindow(startedAt: 2, endedAt: 1),
          throwsArgumentError,
        );
      },
  'every stored code decodes, nullable details remain nullable': (db) async {
    await insertLedgerRow(db, 'time_blocks', blockRow());
    await insertLedgerRow(db, 'sleep_sessions', sleepRow());
    await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
    final minimal = (await readDay(db)).annotations.single;
    expect(minimal.stuckReasonCode, isNull);
    expect(minimal.stuckReasonText, isNull);
    expect(minimal.recoveryMethod, isNull);
    expect(minimal.recoveryQuality, isNull);
    expect(minimal.continuationHint, isNull);
    for (final state in RhythmState.values) {
      await db.customStatement('UPDATE rhythm_annotations SET state = ?', [
        state.name,
      ]);
      expect((await readDay(db)).annotations.single.state, state);
    }
    for (final code in StuckReasonCode.values) {
      await db.customStatement(
        'UPDATE rhythm_annotations SET stuck_reason_code = ?',
        [code.name],
      );
      expect((await readDay(db)).annotations.single.stuckReasonCode, code);
    }
    for (final code in RecoveryMethod.values) {
      await db.customStatement(
        'UPDATE rhythm_annotations SET recovery_method = ?',
        [code.name],
      );
      expect((await readDay(db)).annotations.single.recoveryMethod, code);
    }
    for (final code in RecoveryQuality.values) {
      await db.customStatement(
        'UPDATE rhythm_annotations SET recovery_quality = ?',
        [code.name],
      );
      expect((await readDay(db)).annotations.single.recoveryQuality, code);
    }
    await db.customStatement(
      "UPDATE time_blocks SET knowledge_state = 'unknown'",
    );
    expect((await readDay(db)).timeBlocks.single.title, '写论文');
  },
  'corrupt persisted codes fail the whole read instead of silently degrading':
      (db) async {
        await insertLedgerRow(db, 'time_blocks', blockRow());
        await insertLedgerRow(db, 'sleep_sessions', sleepRow());
        await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
        final cases = {
          'time_blocks': {
            'knowledge_state': 'known',
            'start_precision': 'approximate',
            'end_precision': 'exact',
          },
          'sleep_sessions': {
            'sleep_type': 'mainSleep',
            'start_precision': 'exact',
            'end_precision': 'approximate',
          },
          'rhythm_annotations': {
            'state': 'progress',
            'stuck_reason_code': null,
            'recovery_method': null,
            'recovery_quality': null,
          },
        };
        for (final table in cases.entries) {
          for (final field in table.value.entries) {
            // Deliberate corruption fixture only: normal rows above passed schema.
            // Restore CHECK enforcement before exercising the production reader.
            await db.customStatement('PRAGMA ignore_check_constraints = ON');
            try {
              await db.customStatement(
                'UPDATE ${table.key} SET ${field.key} = ?',
                ['INVALID'],
              );
            } finally {
              await db.customStatement('PRAGMA ignore_check_constraints = OFF');
            }
            await expectLater(
              readDay(db),
              throwsA(
                isA<LedgerDataException>()
                    .having((e) => e.table, 'table', table.key)
                    .having((e) => e.field, 'field', field.key),
              ),
            );
            await db.customStatement(
              'UPDATE ${table.key} SET ${field.key} = ?',
              [field.value],
            );
          }
        }
        expect((await readDay(db)).timeBlocks, hasLength(1));
        expect(
          (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
            'foreign_keys',
          ),
          1,
        );
      },
  'invalid stored value types and unnormalized text are not rewritten':
      (db) async {
        await insertLedgerRow(db, 'time_blocks', blockRow());
        for (final entry in {
          'created_at': 1.5,
          'updated_at': 'bad',
          'title': '  bad  ',
        }.entries) {
          final before = blockRow()[entry.key];
          await db.customStatement('UPDATE time_blocks SET ${entry.key} = ?', [
            entry.value,
          ]);
          await expectLater(readDay(db), throwsA(isA<LedgerDataException>()));
          expect(
            (await db
                    .customSelect('SELECT ${entry.key} FROM time_blocks')
                    .getSingle())
                .data[entry.key],
            entry.value,
          );
          await db.customStatement('UPDATE time_blocks SET ${entry.key} = ?', [
            before,
          ]);
        }
      },
};

/// Observes real executor calls; it does not supply rows or replace SQLite.
class LedgerReadTrace extends QueryInterceptor {
  bool enabled = false;
  final List<QueryExecutor> readers = [];
  int commits = 0;
  int rollbacks = 0;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (enabled) readers.add(executor);
    return executor.runSelect(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    if (enabled) commits++;
    return inner.send();
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) {
    if (enabled) rollbacks++;
    return inner.rollback();
  }
}

Future<void> verifyReadTransaction(
  AppDatabase db,
  LedgerReadTrace trace,
) async {
  await insertLedgerRow(db, 'time_blocks', blockRow());
  await insertLedgerRow(db, 'sleep_sessions', sleepRow());
  await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
  trace.enabled = true;
  final snapshot = await readDay(db);
  trace.enabled = false;
  expect(snapshot.timeBlocks, hasLength(1));
  expect(snapshot.sleepSessions, hasLength(1));
  expect(snapshot.annotations, hasLength(1));
  expect(trace.readers, hasLength(3));
  expect(trace.readers.first, isA<TransactionExecutor>());
  expect(
    trace.readers.every((executor) => identical(executor, trace.readers.first)),
    isTrue,
  );
  expect(trace.commits, 1);
  expect(trace.rollbacks, 0);
  await db.customStatement("UPDATE time_blocks SET title = '  invalid  '");
  trace.enabled = true;
  try {
    await expectLater(readDay(db), throwsA(isA<LedgerDataException>()));
  } finally {
    trace.enabled = false;
  }
  expect(trace.commits, 1);
  expect(trace.rollbacks, 1);
}
