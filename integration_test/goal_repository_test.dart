import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';

import 'support/goal_repository_contract.dart';
import 'support/schema_contract.dart' show clearSchemaRows;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final check in goalRepositoryChecks.entries) {
    testWidgets(check.key, (tester) async {
      final name =
          'time_pet_ledger_goal_test_${DateTime.now().microsecondsSinceEpoch}';
      final db = await AppDatabase.open(await connectDatabase(name));
      try {
        await check.value(db);
      } finally {
        try {
          await clearSchemaRows(db);
        } finally {
          await db.close();
        }
      }
    });
  }
}
