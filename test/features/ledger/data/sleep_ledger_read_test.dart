import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';

import '../../../../integration_test/support/ledger_read_contract.dart';

void main() {
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
      final pending = DriftLedgerRepository(reader).readSleepContext(
        startedAt: dayStart,
        endedAt: dayStart + 24 * hour,
        dayStartedAt: dayStart,
        nextDayStartedAt: dayStart + 24 * hour,
      );
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
      expect(before.windowFacts.timeBlocks.single.title, '写论文');
      expect(before.windowFacts.sleepSessions.single.note, isNull);
      expect(before.sleepSummaryCandidates.single.note, isNull);
      expect(before.windowFacts.annotations.single.state.name, 'progress');
      await changeAll();
      final after = await DriftLedgerRepository(reader).readSleepContext(
        startedAt: dayStart,
        endedAt: dayStart + 24 * hour,
        dayStartedAt: dayStart,
        nextDayStartedAt: dayStart + 24 * hour,
      );
      expect(after.windowFacts.timeBlocks.single.title, 'after');
      expect(after.windowFacts.sleepSessions.single.note, 'after');
      expect(after.sleepSummaryCandidates.single.note, 'after');
      expect(after.windowFacts.annotations.single.state.name, 'stuck');
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
