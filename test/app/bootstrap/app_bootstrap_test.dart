import '../../support/recording_fields.dart';
import '../../support/ledger_date_selection.dart';
import '../../support/root_navigation.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

Future<void> tapVisible(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) {
    return;
  }
  final target = text == '更正完整记录' || text == '删除完整时间记录'
      ? find.byTooltip(text == '删除完整时间记录' ? '删除记录' : text)
      : find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> enterTime(WidgetTester tester, String label, String value) async {
  await revealRecordingField(tester, label);
  await tapVisible(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tapVisible(tester, '确认');
}

void main() {
  testWidgets('existing record is reachable for edit after opening the app', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await tester.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    await tester.runAsync(
      () => DriftLedgerRepository(db).createTimeBlock(
        id: '00000000-0000-4000-8000-000000000001',
        startedAt: DateTime(2026, 9, 28, 10).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 9, 28, 11).millisecondsSinceEpoch,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
        title: '已有记录',
        now: 1,
      ),
    );
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 9, 29)),
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        now: () => DateTime(2026, 9, 29, 12),
      ),
    );
    await tester.pumpAndSettle();
    await selectLedgerDate(tester, '2026-09-28');
    await tapVisible(tester, '查看记录');
    expect(find.text('已有记录'), findsOneWidget);
    await tapVisible(tester, '更正完整记录');
    expect(find.text('更正记录'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () =>
          DriftLedgerRepository(db)
              .deleteTimeBlock('00000000-0000-4000-8000-000000000001'),
    );
    await tapVisible(tester, '更正完整记录');
    expect(find.text('记录已不存在，无法更正。'), findsOneWidget);
    await tapVisible(tester, '清除编辑草稿并返回');
    expect(
      await tester.runAsync(
        () =>
            DriftLedgerRepository(db)
                .readTimeBlock('00000000-0000-4000-8000-000000000001'),
      ),
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'bootstrapped new Unknown is saved and home shows refreshed coverage',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      await selectLedgerDate(tester, '2026-09-28');
      await tapVisible(tester, '记录活动');
      expect(find.widgetWithText(ListTile, '未填写'), findsNWidgets(2));
      expect(find.text('选择要补记的时间，也可以手动填写：'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始大约'))
            .selected,
        isTrue,
      );
      await tapVisible(tester, '想不起来');
      await enterTime(tester, '开始时间', '2026-09-28 10:00');
      await enterTime(tester, '结束时间', '2026-09-28 11:00');
      await tapVisible(tester, '保存到账本');
      expect(find.text('已保存到账本。'), findsOneWidget);
      expect(ledgerDuration('已交代', '约1 小时'), findsOneWidget);
      expect(find.text('其中想不起来：约1 小时（已含在已交代中）'), findsOneWidget);
      expect(ledgerFactCount(tester, '普通'), 1);
      final rows = await tester.runAsync(
        () => db.customSelect('SELECT * FROM time_blocks').get(),
      );
      expect(rows, hasLength(1));
      expect(rows!.single.data['knowledge_state'], 'unknown');
      expect(rows.single.data['start_precision'], 'approximate');
      expect(rows.single.data['end_precision'], 'approximate');
      await tapVisible(tester, '更正完整记录');
      expect(find.text('更正记录'), findsOneWidget);
      expect(
        recordingTimeSummaryContaining('2026-09-28 10:00'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, '删除完整时间记录');
      expect(find.text('删除完整记录时，依附的节奏解释也会删除。'), findsOneWidget);
      await tapVisible(tester, '取消');
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ),
        hasLength(1),
      );
      await tapVisible(tester, '删除完整时间记录');
      await tapVisible(tester, '删除记录');
      expect(ledgerFactCount(tester, '普通'), 0);
      expect(ledgerDuration('已交代', '0 分钟'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('bootstrap owns one connection across rebuilds and closes it', (
    tester,
  ) async {
    final database = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await tester.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    var opens = 0;
    Future<AppDatabase> open() async {
      opens++;
      return database;
    }

    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime.now()),
        openDatabase: open,
        openDrafts: () async => drafts,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
      same(homeTheme),
    );
    await tester.pumpAndSettle();
    expect(find.text('日账本'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
      same(homeTheme),
    );
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime.now()),
        openDatabase: open,
        openDrafts: () async => drafts,
      ),
    );
    expect(opens, 1);
    expect(find.text('补一笔'), findsOneWidget);
    await tester.runAsync(() async {
      await tapRootAction(tester, '记录活动');
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activity')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsStateError,
      );
      await expectLater(
        drafts.read(
          RecordingDraftContext.newEntry(
            date: CivilDate(year: 2026, month: 9, day: 28),
          ),
        ),
        throwsA(isA<RecordingDraftStorageException>()),
      );
    });
  });

  testWidgets('connection finishing after disposal is still closed', (
    tester,
  ) async {
    final database = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final pending = Completer<AppDatabase>();
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 9, 29)),
        openDatabase: () => pending.future,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(database);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await expectLater(
        database.customSelect('SELECT 1').get(),
        throwsStateError,
      );
    });
  });

  testWidgets('opening failure cannot show a ready app or raw diagnostics', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 9, 29)),
        openDatabase: () async {
          throw const DatabaseOpenException('private SQL path');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('日账本'), findsNothing);
    expect(find.text('无法打开本地存储，请重新启动应用。'), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme,
      same(homeTheme),
    );
    expect(find.textContaining('private SQL path'), findsNothing);
  });
  testWidgets(
    'draft opening failure closes formal connection and shows failure',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => throw StateError('private draft path'),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('无法打开本地存储，请重新启动应用。'), findsOneWidget);
      expect(find.textContaining('private draft path'), findsNothing);
      await tester.runAsync(
        () => expectLater(db.customSelect('SELECT 1').get(), throwsStateError),
      );
    },
  );
  testWidgets('draft connection completing after disposal closes both stores', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final drafts = (await tester.runAsync(
      () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ))!;
    final pending = Completer<DriftRecordingDraftStore>();
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 9, 29)),
        openDatabase: () async => db,
        openDrafts: () => pending.future,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(drafts);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await expectLater(db.customSelect('SELECT 1').get(), throwsStateError);
      await expectLater(
        drafts.read(
          RecordingDraftContext.newEntry(
            date: CivilDate(year: 2026, month: 9, day: 28),
          ),
        ),
        throwsA(isA<RecordingDraftStorageException>()),
      );
    });
  });
}
