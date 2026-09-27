import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

import '../../../integration_test/support/persistence_fixture.dart';

void main() {
  test('connection enables foreign keys and rejects use after close', () async {
    final database = await AppDatabase.open(NativeDatabase.memory());
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(
      tables.map((row) => row.read<String>('name')),
      unorderedEquals([
        'goals',
        'time_blocks',
        'rhythm_annotations',
        'sleep_sessions',
        'daily_reviews',
      ]),
    );
    await createPersistenceFixture(database);
    await verifyForeignKeysAndRollback(database);
    await database.close();
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsStateError,
    );
  });

  test('each memory fixture is independent and enables foreign keys', () async {
    final first = await AppDatabase.open(NativeDatabase.memory());
    final second = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(first.close);
    addTearDown(second.close);
    await createPersistenceFixture(first);
    await createPersistenceFixture(second);
    await first.customStatement('INSERT INTO fixture_parent VALUES (7)');
    expect(
      await second.customSelect('SELECT * FROM fixture_parent').get(),
      isEmpty,
    );
    await verifyForeignKeysAndRollback(second);
  });

  test(
    'isolated file can be closed and reopened with enforcement intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'time_pet_ledger_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/fixture.sqlite');
      final first = await AppDatabase.open(NativeDatabase(file));
      await createPersistenceFixture(first);
      await first.customStatement('INSERT INTO fixture_parent VALUES (7)');
      await first.close();

      final reopened = await AppDatabase.open(NativeDatabase(file));
      try {
        final row = await reopened
            .customSelect('SELECT id FROM fixture_parent')
            .getSingle();
        expect(row.read<int>('id'), 7);
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
        await reopened.close();
      }
    },
  );

  test(
    'real opening failure is surfaced instead of returning a usable database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'time_pet_ledger_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      await expectLater(
        AppDatabase.open(NativeDatabase(File(directory.path))),
        throwsA(isA<DatabaseOpenException>()),
      );
    },
  );

  test('opening fails if SQLite cannot actually enable foreign keys', () async {
    final directory = await Directory.systemTemp.createTemp(
      'time_pet_ledger_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/foreign_keys.sqlite');
    final initialized = await AppDatabase.open(NativeDatabase(file));
    await initialized.close();
    // SQLite ignores foreign_keys changes inside an existing transaction.
    // Existing schema targets beforeOpen, not schema creation.
    final executor = NativeDatabase(
      file,
      setup: (database) {
        database.execute('PRAGMA foreign_keys = OFF');
        database.execute('BEGIN');
      },
    );
    await expectLater(
      AppDatabase.open(executor),
      throwsA(
        isA<DatabaseOpenException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
    await expectLater(
      AppDatabase.open(executor),
      throwsA(isA<DatabaseOpenException>()),
    );
  });
}
