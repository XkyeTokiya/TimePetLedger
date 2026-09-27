import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';

import 'support/persistence_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real platform storage opens, enforces constraints, isolates and reopens',
    (tester) async {
      // The production name is never passed to the connection factory in tests.
      final run = DateTime.now().microsecondsSinceEpoch;
      final firstName = 'time_pet_ledger_test_${run}_a';
      final secondName = 'time_pet_ledger_test_${run}_b';
      AppDatabase? first;
      AppDatabase? second;
      AppDatabase? reopened;
      try {
        first = await AppDatabase.open(await connectDatabase(firstName));
        second = await AppDatabase.open(await connectDatabase(secondName));
        await createPersistenceFixture(first);
        await createPersistenceFixture(second);
        await verifyForeignKeysAndRollback(first);
        await verifyForeignKeysAndRollback(second);
        await first.customStatement('INSERT INTO fixture_parent VALUES (7)');
        expect(
          await second.customSelect('SELECT * FROM fixture_parent').get(),
          isEmpty,
        );
        await first.close();
        final closed = first;
        first = null;
        await expectLater(
          closed.customSelect('SELECT 1').get(),
          throwsStateError,
        );

        reopened = await AppDatabase.open(await connectDatabase(firstName));
        expect(
          (await reopened
                  .customSelect('SELECT id FROM fixture_parent')
                  .getSingle())
              .read<int>('id'),
          7,
        );
        expect(
          (await reopened.customSelect('PRAGMA foreign_keys').getSingle())
              .read<int>('foreign_keys'),
          1,
        );
        await expectLater(
          reopened.customStatement('INSERT INTO fixture_child VALUES (1, 999)'),
          throwsA(isA<Exception>()),
        );
      } finally {
        // Only remove our artificial tables from our uniquely named test stores.
        for (final database in [first, second, reopened]) {
          if (database != null) {
            try {
              await database.customStatement(
                'DROP TABLE IF EXISTS fixture_child',
              );
              await database.customStatement(
                'DROP TABLE IF EXISTS fixture_parent',
              );
            } finally {
              await database.close();
            }
          }
        }
      }
    },
  );
}
