import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import 'support/checked_sleep_opening.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
Future<void> tap(WidgetTester tester, Finder target) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> textTap(WidgetTester tester, String text) =>
    tap(tester, find.text(text));
Future<void> choose(WidgetTester tester, int n) async {
  await textTap(tester, '选择目标');
  await tap(tester, find.byKey(ValueKey('goal-option-${id(n)}')));
}

Future<void> time(WidgetTester tester, String label, String value) async {
  await textTap(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await textTap(tester, '确认');
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
}

void main() {
  testWidgets(
    'real bootstrap ordinary selection reopens both files, saves by id, legacy home edit clears',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('app_goal_'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final factsFile = File('${dir.path}/facts.sqlite');
      final draftFile = File('${dir.path}/drafts.sqlite');
      var db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase(factsFile)),
      ))!;
      var drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase(draftFile)),
      ))!;
      Future<void> mount() async {
        await tester.pumpWidget(
          AppBootstrap(
            openDatabase: () async => db,
            openDrafts: () async => drafts,
            openSleepOpenings: () =>
                openCheckedSleepOpening(DateTime(2026, 10, 1)),
            now: () => DateTime(2026, 10, 1, 12),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tester.runAsync(() async {
        await DriftGoalRepository(db).create(id: id(1), name: '文件重开目标', now: 1);
        await DriftGoalRepository(db).create(id: id(2), name: '文件重开目标', now: 1);
      });
      await mount();
      await textTap(tester, '补一笔');
      await tester.enterText(
        find.byKey(const ValueKey('activity')),
        '  原始输入 🐾  ',
      );
      await textTap(tester, '记得做了什么');
      await time(tester, '开始时间', '2026-10-01 10:00');
      await time(tester, '结束时间', '2026-10-01 11:00');
      await choose(tester, 2);
      final context = tester
          .widget<RecordingForm>(find.byType(RecordingForm))
          .context;
      await textTap(tester, '保留草稿并返回');
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ))!,
        isEmpty,
      );
      await disposeApp(tester);
      db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase(factsFile)),
      ))!;
      drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase(draftFile)),
      ))!;
      expect(
        (await tester.runAsync(() => drafts.read(context)))!.goalId,
        id(2),
      );
      await mount();
      await textTap(tester, '补一笔');
      expect(find.text('已恢复上次输入'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '  原始输入 🐾  ',
      );
      await textTap(tester, '确认并保存到账本');
      final block = (await tester.runAsync(
        () => DriftLedgerRepository(db).readWindow(
          startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
        ),
      ))!.timeBlocks.single;
      expect(block.goalId, id(2));
      await tap(tester, find.byKey(ValueKey('edit-${block.id}')));
      await textTap(tester, '移除目标归属');
      await textTap(tester, '保留草稿并返回');
      expect(
        (await tester.runAsync(
          () => DriftLedgerRepository(db).readTimeBlock(block.id),
        ))!.timeBlock.goalId,
        id(2),
      );
      await disposeApp(tester);
      db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase(factsFile)),
      ))!;
      drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase(draftFile)),
      ))!;
      await mount();
      await tap(tester, find.byKey(ValueKey('edit-${block.id}')));
      expect(find.text('未关联目标'), findsOneWidget);
      await textTap(tester, '保存更正');
      expect(
        (await tester.runAsync(
          () => DriftLedgerRepository(db).readTimeBlock(block.id),
        ))!.timeBlock.goalId,
        isNull,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'bootstrap Gap prefills unchanged approximate times, timeline source edit retains archived Goal and clears',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await tester.runAsync(
        () => DriftGoalRepository(db).create(id: id(1), name: 'Gap目标', now: 1),
      );
      await tester.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 10, 1)),
          now: () => DateTime(2026, 10, 1, 12),
        ),
      );
      await tester.pumpAndSettle();
      await textTap(tester, '打开日账本');
      await textTap(tester, '补一笔');
      final form = tester.widget<RecordingForm>(find.byType(RecordingForm));
      expect(form.context.entry, RecordingDraftEntry.gap);
      expect(find.text('2026-10-01 00:00'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('activity')), 'Gap活动');
      await textTap(tester, '记得做了什么');
      await choose(tester, 1);
      await textTap(tester, '确认并保存到账本');
      final block = (await tester.runAsync(
        () => DriftLedgerRepository(db).readWindow(
          startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 1, 12).millisecondsSinceEpoch,
        ),
      ))!.timeBlocks.single;
      expect(block.goalId, id(1));
      expect(block.startedAt, form.context.gapStartedAt);
      expect(block.endedAt, form.context.gapEndedAt);
      await tester.runAsync(
        () => DriftGoalRepository(db).archive(id: id(1), now: 2),
      );
      await tap(
        tester,
        find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: block.id))),
      );
      expect(find.text('Gap目标（已归档）'), findsOneWidget);
      await textTap(tester, '想不起来');
      await textTap(tester, '保存更正');
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      final retained = (await tester.runAsync(
        () => DriftLedgerRepository(db).readTimeBlock(block.id),
      ))!.timeBlock;
      expect(retained.goalId, id(1));
      expect(retained.startPrecision, block.startPrecision);
      await tap(
        tester,
        find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: block.id))),
      );
      await textTap(tester, '移除目标归属');
      await textTap(tester, '保存更正');
      expect(
        (await tester.runAsync(
          () => DriftLedgerRepository(db).readTimeBlock(block.id),
        ))!.timeBlock.goalId,
        isNull,
      );
      await disposeApp(tester);
    },
  );
}
