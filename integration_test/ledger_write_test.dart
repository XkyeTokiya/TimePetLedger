import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';

import 'support/ledger_write_contract.dart';
import 'support/schema_contract.dart' show clearSchemaRows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final checks = <String, Future<void> Function(AppDatabase, LedgerWriteTrace)>{
    for (final entry in ledgerWriteChecks.entries)
      entry.key: (db, trace) => entry.value(db),
    'conflict reads and insert share one transaction': verifyWriteTransaction,
  };
  for (final check in checks.entries) {
    testWidgets(check.key, (tester) async {
      final name =
          'time_pet_ledger_write_test_${DateTime.now().microsecondsSinceEpoch}';
      final trace = LedgerWriteTrace();
      final db = await AppDatabase.open(
        (await connectDatabase(name)).interceptWith(trace),
      );
      try {
        await check.value(db, trace);
      } finally {
        trace.enabled = false;
        try {
          await clearSchemaRows(db);
        } finally {
          await db.close();
        }
      }
    });
  }
}
