import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

void main() {
  for (final check in ledgerReadChecks.entries) {
    test(check.key, () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await check.value(db);
    });
  }
  test('all queries and mapping share one real transaction', () async {
    final trace = LedgerReadTrace();
    final db = await AppDatabase.open(
      NativeDatabase.memory().interceptWith(trace),
    );
    addTearDown(db.close);
    await verifyReadTransaction(db, trace);
  });
  test(
    'another connection cannot commit a mixed snapshot between table reads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger_snapshot_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/snapshot.sqlite');
      final gate = _FirstReadGate();
      final reader = await AppDatabase.open(
        NativeDatabase(file).interceptWith(gate),
      );
      final writer = await AppDatabase.open(NativeDatabase(file));
      addTearDown(reader.close);
      addTearDown(writer.close);
      await insertLedgerRow(writer, 'time_blocks', blockRow());
      await insertLedgerRow(writer, 'sleep_sessions', sleepRow());
      await insertLedgerRow(writer, 'rhythm_annotations', annotationRow());
      // Make contention fail immediately; no timing-based sleep or hung writer.
      await writer.customStatement('PRAGMA busy_timeout = 0');
      Future<void> changeAll() => writer.transaction(() async {
        await writer.customStatement("UPDATE time_blocks SET title = 'after'");
        await writer.customStatement(
          "UPDATE sleep_sessions SET note = 'after'",
        );
        await writer.customStatement(
          "UPDATE rhythm_annotations SET state = 'stuck'",
        );
      });
      gate.enabled = true;
      final pending = readDay(reader);
      try {
        await gate.firstRead.future.timeout(const Duration(seconds: 5));
        await expectLater(
          changeAll(),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains('database is locked'),
              'SQLite busy',
            ),
          ),
        );
      } finally {
        gate.release.complete();
      }
      final before = await pending;
      expect(before.timeBlocks.single.title, '写论文');
      expect(before.sleepSessions.single.note, isNull);
      expect(before.annotations.single.state.name, 'progress');
      await changeAll();
      final after = await readDay(reader);
      expect(after.timeBlocks.single.title, 'after');
      expect(after.sleepSessions.single.note, 'after');
      expect(after.annotations.single.state.name, 'stuck');
    },
  );
  test(
    'closed connection fails explicitly instead of returning an empty ledger',
    () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      await db.close();
      await expectLater(readDay(db), throwsA(isA<LedgerStorageException>()));
    },
  );
}

class _FirstReadGate extends QueryInterceptor {
  bool enabled = false;
  final firstRead = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (enabled &&
        !firstRead.isCompleted &&
        statement.contains('FROM time_blocks')) {
      firstRead.complete();
      await release.future;
    }
    return rows;
  }
}
