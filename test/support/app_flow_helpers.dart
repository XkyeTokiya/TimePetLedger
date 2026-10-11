import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 从旧流程测试迁出的共享助手（P2）。

// All writes execute on SQLite. Only reads after a committed TimeBlock write
// are intercepted; failed submission is never replaced by a mock result.
class BlockReadFailure extends QueryInterceptor {
  bool arm = false;
  bool failReads = false;
  bool wroteBlock = false;
  int blockInserts = 0;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(sql, args);
    if (sql.contains('time_blocks')) {
      blockInserts++;
      wroteBlock = true;
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (wroteBlock && arm) failReads = true;
    wroteBlock = false;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    wroteBlock = false;
    await inner.rollback();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failReads &&
        sql.contains('time_blocks') &&
        sql.toUpperCase().contains('WHERE')) {
      throw StateError('test committed read failure');
    }
    return executor.runSelect(sql, args);
  }
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
}
