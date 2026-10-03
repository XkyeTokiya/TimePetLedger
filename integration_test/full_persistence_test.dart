import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';

import 'support/full_persistence_contract.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'five domain types survive two durable platform storage reopenings',
    (tester) async {
      final name =
          'time_pet_ledger_full_test_${DateTime.now().microsecondsSinceEpoch}';
      var opens = 0;
      await verifyFullPersistence(() async {
        final db = await AppDatabase.open(await connectDatabase(name));
        opens++;
        final files = await db.customSelect('PRAGMA database_list').get();
        debugPrint(
          'E2-T08 open=$opens platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} store=$name databases=${files.map((row) => row.data).toList()}',
        );
        if (!kIsWeb) {
          expect(
            files.singleWhere((row) => row.data['name'] == 'main').data['file'],
            isNot(isEmpty),
          );
        }
        return db;
      });
      expect(opens, 3);
    },
  );
}
