import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

/// Artificial test tables only; never used on the production database.
Future<void> createPersistenceFixture(AppDatabase database) async {
  await database.customStatement(
    'CREATE TABLE fixture_parent (id INTEGER PRIMARY KEY)',
  );
  await database.customStatement(
    'CREATE TABLE fixture_child ('
    'id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL '
    'REFERENCES fixture_parent(id))',
  );
}

Future<void> verifyForeignKeysAndRollback(AppDatabase database) async {
  final pragma = await database.customSelect('PRAGMA foreign_keys').getSingle();
  expect(pragma.read<int>('foreign_keys'), 1);

  await expectLater(
    database.customStatement('INSERT INTO fixture_child VALUES (1, 999)'),
    throwsA(isA<Exception>()),
  );
  await expectLater(
    database.transaction(() async {
      await database.customStatement('INSERT INTO fixture_parent VALUES (1)');
      await database.customStatement('INSERT INTO fixture_child VALUES (1, 1)');
      await database.customStatement(
        'INSERT INTO fixture_child VALUES (2, 999)',
      );
    }),
    throwsA(isA<Exception>()),
  );
  for (final table in ['fixture_parent', 'fixture_child']) {
    final count = await database
        .customSelect('SELECT COUNT(*) AS count FROM $table')
        .getSingle();
    expect(count.read<int>('count'), 0, reason: 'Rollback must include $table');
  }
}
