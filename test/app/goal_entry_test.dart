import '../support/root_navigation.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';

import 'support/checked_sleep_opening.dart';

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
        openSleepOpenings: () => openCheckedSleepOpening(clock),
        now: () => clock,
      ),
    );
    await tester.pumpAndSettle();
    expect(await tester.runAsync(DriftGoalRepository(db).listActive), isEmpty);
    expect(find.text('补一笔'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('root-create')));
    await tester.pumpAndSettle();
    expect(find.text('记录睡眠'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tapRootAction(tester, '打开目标');
    await tester.pumpAndSettle();
    expect(find.text('尚未创建目标。'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('goal-name')), '  本机目标  ');
    await tester.tap(find.text('创建目标'));
    await tester.pumpAndSettle();
    final goals = (await tester.runAsync(DriftGoalRepository(db).listActive))!;
    expect(goals.single.name, '本机目标');
    expect(goals.single.createdAt, clock.millisecondsSinceEpoch);
    expect(find.byKey(ValueKey(goals.single.id)), findsOneWidget);
    await backFromPage(tester);
    await tester.pumpAndSettle();
    await tapRootAction(tester, '打开目标');
    await tester.pumpAndSettle();
    expect(find.text('本机目标'), findsOneWidget);
    expect(find.text('目标已保存。'), findsNothing);
    final actions = find.byKey(ValueKey('goal-actions-${goals.single.id}'));
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('改名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-rename-name')),
      '目标新名',
    );
    await tester.tap(find.text('保存名称'));
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsOneWidget);
    clock = DateTime(2026, 10, 1, 12, 1);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('归档目标'));
    await tester.pumpAndSettle();
    expect(find.text('尚未创建目标。'), findsOneWidget);
    await tester.tap(find.text('查看已归档目标'));
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsOneWidget);
    expect(find.text('已归档'), findsOneWidget);
    clock = DateTime(2026, 10, 1, 12, 2);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复目标'));
    await tester.pumpAndSettle();
    expect(find.text('暂无已归档目标。'), findsOneWidget);
    await backFromPage(tester);
    await tester.pumpAndSettle();
    expect(find.text('目标新名'), findsOneWidget);
    final restored = (await tester.runAsync(
      () => DriftGoalRepository(db).findById(goals.single.id),
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
