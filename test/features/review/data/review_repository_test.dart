import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_repository.dart';

import '../../../../integration_test/support/review_repository_contract.dart';

void main() {
  for (final check in reviewRepositoryChecks.entries) {
    test(check.key, () async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      addTearDown(db.close);
      await check.value(db);
    });
  }
  test('closed storage never reports read or write success', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    final repo = DriftReviewRepository(db);
    await db.close();
    await expectLater(
      repo.findByDate(historical),
      throwsA(isA<ReviewStorageException>()),
    );
    await expectLater(
      repo.create(
        id: reviewId,
        date: historical,
        tomorrowFirstStepText: '一步',
        now: 1,
      ),
      throwsA(isA<ReviewStorageException>()),
    );
  });
}
