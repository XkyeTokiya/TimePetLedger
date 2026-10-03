import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

import '../../../integration_test/support/full_persistence_contract.dart';

void main() {
  test('five domain types survive closing and reopening an actual SQLite file twice', () async {
    final directory = await Directory.systemTemp.createTemp(
      'ledger_full_persistence_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/ledger.sqlite');
    var opens = 0;
    await verifyFullPersistence(() async {
      if (opens > 0) expect(await file.length(), greaterThan(0));
      opens++;
      return AppDatabase.open(NativeDatabase(file));
    });
    expect(opens, 3);
    expect(await file.exists(), isTrue);
  });
}
