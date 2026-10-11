import '../../support/ledger_date_selection.dart';
import '../../support/root_navigation.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/legacy_input_stores.dart';

import '../support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/theme/app_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_quick_sheet.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

Future<void> tapVisible(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) {
    return;
  }
  final target = find.text(text);
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
        openSleepDrafts: emptyLegacySleepDrafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
        now: () => DateTime(2026, 9, 29, 12),
      ),
    );
    await tester.pumpAndSettle();
    await selectLedgerDate(tester, '2026-09-28');
    await tapVisible(tester, '查看记录');
    expect(find.text('已有记录'), findsWidgets);
    await tester.ensureVisible(
      recordingFact('00000000-0000-4000-8000-000000000001').first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      recordingFact('00000000-0000-4000-8000-000000000001').first,
    );
    await tester.pumpAndSettle();
    expect(find.text('记录详情'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fact-detail-edit')));
    await tester.pumpAndSettle();
    expect(find.text('更正记录'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () =>
          DriftLedgerRepository(db)
              .deleteTimeBlock('00000000-0000-4000-8000-000000000001'),
    );
    await tester.tap(find.byKey(const ValueKey('fact-detail-edit')));
    await tester.pumpAndSettle();
    expect(find.text('记录已不存在，无法更正。'), findsOneWidget);
    await tester.tap(find.text('清除未完成输入'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
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
          openSleepDrafts: emptyLegacySleepDrafts,
          openReviewDrafts: emptyLegacyReviewDrafts,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      // 今天先放一条记录，让新记录面板预填尾部区间（08:00–09:00 之后到当前时刻）。
      await tester.runAsync(
        () => DriftLedgerRepository(db).createTimeBlock(
          id: '00000000-0000-4000-8000-000000000009',
          startedAt: DateTime(2026, 9, 29, 8).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 29, 9).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '上午的事',
          now: 1,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, '记录活动');
      expect(
        find.descendant(
          of: find.byType(ActivityQuickSheet),
          matching: find.text('09:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ActivityQuickSheet),
          matching: find.text('12:00'),
        ),
        findsOneWidget,
      );
      await tapVisible(tester, '想不起来');
      await tapVisible(tester, '保存记录');
      expect(find.text('已保存到账本。'), findsOneWidget);
      expect(ledgerDuration('已交代', '4 小时'), findsOneWidget);
      expect(ledgerFactCount(tester, '普通'), 2);
      final rows = await tester.runAsync(
        () => db.customSelect('SELECT * FROM time_blocks ORDER BY id').get(),
      );
      expect(rows, hasLength(2));
      final unknownRow = rows!.firstWhere(
        (row) => row.data['knowledge_state'] == 'unknown',
      );
      expect(
        unknownRow.data['started_at'],
        DateTime(2026, 9, 29, 9).millisecondsSinceEpoch,
      );
      expect(
        unknownRow.data['ended_at'],
        DateTime(2026, 9, 29, 12).millisecondsSinceEpoch,
      );

      // 新记录的详情与更正入口可达；来源删除后报缺失而不重建。
      final unknownId = unknownRow.data['id'] as String;
      await tester.ensureVisible(recordingFact(unknownId).first);
      await tester.pumpAndSettle();
      await tester.tap(recordingFact(unknownId).first);
      await tester.pumpAndSettle();
      expect(find.text('记录详情'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('fact-detail-edit')));
      await tester.pumpAndSettle();
      expect(find.text('更正记录'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => DriftLedgerRepository(db).deleteTimeBlock(unknownId),
      );
      await tester.tap(find.byKey(const ValueKey('fact-detail-edit')));
      await tester.pumpAndSettle();
      expect(find.text('记录已不存在，无法更正。'), findsOneWidget);
      await tester.tap(find.text('清除未完成输入'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => DriftLedgerRepository(db).readTimeBlock(unknownId),
        ),
        isNull,
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
        openSleepDrafts: emptyLegacySleepDrafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme?.colorScheme,
      defaultM3ColorScheme(Brightness.light),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-date-title')), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme?.colorScheme,
      defaultM3ColorScheme(Brightness.light),
    );
    await tester.pumpWidget(
      AppBootstrap(
        openSleepOpenings: () => openCheckedSleepOpening(DateTime.now()),
        openDatabase: open,
        openDrafts: () async => drafts,
        openSleepDrafts: emptyLegacySleepDrafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
      ),
    );
    expect(opens, 1);
    expect(find.text('记录一笔'), findsOneWidget);
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
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme?.colorScheme,
      defaultM3ColorScheme(Brightness.light),
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
          openSleepDrafts: emptyLegacySleepDrafts,
          openReviewDrafts: emptyLegacyReviewDrafts,
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
        openSleepDrafts: emptyLegacySleepDrafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
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
