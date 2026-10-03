import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';

import '../../../../integration_test/support/ledger_write_contract.dart';

void main() {
  for (final check in ledgerWriteChecks.entries) {
    test(check.key, () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await check.value(db);
    });
  }
  test('conflict reads and combined insert use the same transaction', () async {
    final trace = LedgerWriteTrace();
    final db = await AppDatabase.open(
      NativeDatabase.memory().interceptWith(trace),
    );
    addTearDown(db.close);
    await verifyWriteTransaction(db, trace);
  });
  test('independent connections serialize conflict check and commit; retry rechecks', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger_write_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/race.sqlite');
    final gate = _ConflictReadGate();
    final first = await AppDatabase.open(
      NativeDatabase(file).interceptWith(gate),
    );
    final second = await AppDatabase.open(NativeDatabase(file));
    addTearDown(first.close);
    addTearDown(second.close);
    await second.customStatement('PRAGMA busy_timeout = 0');
    final a = DriftLedgerRepository(first);
    final b = DriftLedgerRepository(second);
    gate.enabled = true;
    final pending = writeBlock(a, annotation: explanation);
    try {
      await gate.reached.future.timeout(const Duration(seconds: 5));
      await expectLater(
        writeSleep(b, id: writeId2, start: 150, end: 250),
        throwsA(
          isA<LedgerStorageException>().having(
            (e) => e.cause.toString(),
            'cause',
            contains('database is locked'),
          ),
        ),
      );
    } finally {
      gate.release.complete();
    }
    await pending;
    await expectLater(
      writeSleep(b, id: writeId2, start: 150, end: 250),
      throwsA(isA<LedgerConflictException>()),
    );
    final read = await allLedger(b);
    expect(read.timeBlocks, hasLength(1));
    expect(read.annotations, hasLength(1));
    expect(read.sleepSessions, isEmpty);
  });
}

class _ConflictReadGate extends QueryInterceptor {
  bool enabled = false;
  final reached = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    if (enabled &&
        !reached.isCompleted &&
        statement.contains('FROM sleep_sessions WHERE started_at')) {
      reached.complete();
      await release.future;
    }
    return result;
  }
}
