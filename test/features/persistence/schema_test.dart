import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

import '../../../integration_test/support/schema_contract.dart';

void main() {
  for (final check in schemaChecks.entries) {
    test(check.key, () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await check.value(db);
    });
  }

  test(
    'version 1 empty file upgrades to five tables and reopens intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ledger_schema_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/v1.sqlite');
      final upgraded = await AppDatabase.open(
        NativeDatabase(
          file,
          setup: (db) {
            db.execute('PRAGMA user_version = 1');
          },
        ),
      );
      try {
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        for (final check in schemaChecks.values) {
          await check(upgraded);
          await clearSchemaRows(upgraded);
        }
        await upgraded.customStatement(
          "INSERT INTO goals (id, name, status, created_at, updated_at) "
          "VALUES ('00000000-0000-4000-8000-000000000001', '保留', 'active', 123, 123)",
        );
      } finally {
        await upgraded.close();
      }
      final reopened = await AppDatabase.open(NativeDatabase(file));
      addTearDown(reopened.close);
      expect((await reopened.select(reopened.goals).getSingle()).name, '保留');
      expect(
        (await reopened.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
    },
  );

  test('failed schema upgrade rolls back DDL and can retry cleanly', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger_schema_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/failed_upgrade.sqlite');
    await expectLater(
      AppDatabase.open(
        NativeDatabase(
          file,
          setup: (db) {
            db.execute('PRAGMA user_version = 1');
            // Collide with the final index to fail after table creation starts.
            db.execute(
              'CREATE TABLE idx_daily_reviews_first_step_goal (value TEXT)',
            );
          },
        ),
      ),
      throwsA(isA<DatabaseOpenException>()),
    );
    final retried = await AppDatabase.open(
      NativeDatabase(
        file,
        setup: (db) {
          expect(db.select('PRAGMA user_version').single['user_version'], 1);
          expect(
            db
                .select("SELECT name FROM sqlite_master WHERE type = 'table'")
                .map((row) => row['name']),
            ['idx_daily_reviews_first_step_goal'],
          );
          db.execute('DROP TABLE idx_daily_reviews_first_step_goal');
        },
      ),
    );
    addTearDown(retried.close);
    await schemaChecks.values.first(retried);
  });

  test(
    'unsupported newer version fails without silently downgrading',
    () async {
      await expectLater(
        AppDatabase.open(
          NativeDatabase.memory(
            setup: (db) {
              db.execute('PRAGMA user_version = 3');
            },
          ),
        ),
        throwsA(
          isA<DatabaseOpenException>().having(
            (error) => error.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
    },
  );
}
