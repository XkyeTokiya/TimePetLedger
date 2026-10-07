import '../support/root_navigation.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import 'support/checked_sleep_opening.dart';
import '../support/legacy_input_stores.dart';

void main() {
  testWidgets('bootstrap creates and manages goals on its existing database', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await tester.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    var clock = DateTime(2026, 10, 1, 12);
    await tester.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openSleepDrafts: emptyLegacySleepDrafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
        openSleepOpenings: () => openCheckedSleepOpening(clock),
        openPreferences: () =>
            DriftAppPreferencesStore.open(NativeDatabase.memory()),
        now: () => clock,
      ),
    );
    await tester.pumpAndSettle();
    expect(await tester.runAsync(DriftGoalRepository(db).listActive), isEmpty);
    expect(find.byKey(const ValueKey('home-record-activity')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-record-sleep')), findsOneWidget);

    await tapRootAction(tester, '打开目标');
    await tester.pumpAndSettle();
    expect(find.text('还没有目标。'), findsOneWidget);

    // Create from the list footer; the new goal opens its detail.
    await tester.tap(find.byKey(const ValueKey('goal-new')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-name-input')),
      '  本机目标  ',
    );
    await tester.tap(find.byKey(const ValueKey('goal-save-name')));
    await tester.pumpAndSettle();
    final goals = (await tester.runAsync(DriftGoalRepository(db).listActive))!;
    expect(goals.single.name, '本机目标');
    expect(goals.single.createdAt, clock.millisecondsSinceEpoch);
    final id = goals.single.id;

    // Rename from the detail name field.
    await tester.tap(find.byKey(const ValueKey('goal-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-name-input')),
      '目标新名',
    );
    await tester.tap(find.byKey(const ValueKey('goal-save-name')));
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsWidgets);

    // Archive: confirm, then the active list is empty and the archived tab
    // holds the goal.
    clock = DateTime(2026, 10, 1, 12, 1);
    await tester.tap(find.byKey(const ValueKey('goal-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-confirm-action')));
    await tester.pumpAndSettle();
    expect(find.text('还没有目标。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-tab-archived')));
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsOneWidget);

    // Restore from the archived detail.
    clock = DateTime(2026, 10, 1, 12, 2);
    await tester.tap(find.byKey(ValueKey('goal-open-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-restore')));
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsWidgets);

    final restored = (await tester.runAsync(
      () => DriftGoalRepository(db).findById(id),
    ))!;
    expect(restored.createdAt, goals.single.createdAt);
    expect(restored.updatedAt, clock.millisecondsSinceEpoch);
    expect(restored.archivedAt, isNull);
    for (final table in [
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ]) {
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM $table').get(),
        ),
        isEmpty,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
  });
}
