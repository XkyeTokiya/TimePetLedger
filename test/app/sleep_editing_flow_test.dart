import '../support/root_navigation.dart';
import '../support/ledger_date_selection.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';

import '../features/ledger/application/sleep_entry_editor_test.dart'
    show sleepId, day, at;
import '../support/app_sleep_navigation.dart' show tapText, enter;

Future<void> selectDate(WidgetTester tester, String date) async {
  await selectLedgerDate(tester, date);
  await tapText(tester, '查看记录');
}

Future<void> edit(WidgetTester tester) async {
  // 连续时间轴同屏展示跨日事实的每个日切片，同一 key 会出现多次。
  final target = sleepFact(sleepId).first;
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  if (find.text('编辑完整记录').evaluate().isNotEmpty) {
    await tester.tap(find.text('编辑完整记录'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'app edits complete fact from either day, reopens file draft, migrates wake summary, preserves note and deletes with refreshed Gap',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('sleep_edit_'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/drafts.sqlite');
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final ordinary = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      var nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      final repo = DriftLedgerRepository(db);
      final original = (await tester.runAsync(
        () => repo.createSleepSession(
          id: sleepId,
          startedAt: at(28, 23, 50),
          endedAt: at(29, 7, 40),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          now: 1,
          note: '隐藏备注\n仍然保留',
        ),
      ))!;
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 30)),
          openDatabase: () async => db,
          openDrafts: () async => ordinary,
          openReviewDrafts: emptyLegacyReviewDrafts,
          openSleepDrafts: () async => nextStore,
          now: () => DateTime(2026, 9, 30, 12),
        ),
      );
      await tester.pumpAndSettle();
      await selectDate(tester, '2026-09-28');
      expect(ledgerDuration('已交代', '约10 分钟'), findsOneWidget);
      expect(sleepFact(sleepId), findsOneWidget);
      await edit(tester);
      final c = tester.widget<SleepForm>(find.byType(SleepForm)).controller;
      expect(c.original!.id, sleepId);
      expect(c.endedAt, original.endedAt);
      expect(c.startedAt, original.startedAt);
      expect(c.note, '隐藏备注\n仍然保留');
      expect(c.draft.noteProvided, isFalse);
      await tapText(tester, '小睡');
      await enter(tester, 'sleep-start', '2026-09-29 23:50');
      await enter(tester, 'sleep-end', '2026-09-30 07:40');
      await tapText(tester, '入睡准确');
      await tapText(tester, '醒来大约');
      expect(
        (await tester.runAsync(() => repo.readSleepSession(sleepId)))!.endedAt,
        original.endedAt,
      );
      await tapText(tester, '返回');
      nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      final context28 = SleepDraftContext.edit(
        date: day(28),
        sleepSessionId: sleepId,
      );
      final saved = (await tester.runAsync(() => nextStore.read(context28)))!;
      expect(saved.type, SleepType.nap);
      expect(saved.startedAt, at(29, 23, 50));
      expect(saved.endPrecision, TimePrecision.approximate);
      await edit(tester);
      expect(
        tester.widget<SleepForm>(find.byType(SleepForm)).controller.restored,
        isTrue,
      );
      expect(
        tester
            .widget<SleepForm>(find.byType(SleepForm))
            .controller
            .endedAtInput,
        '2026-09-30 07:40',
      );
      await tapText(tester, '保存更正');
      expect(ledgerDuration('已交代', '0 分钟'), findsOneWidget);
      expect(sleepFact(sleepId), findsNothing);
      final updated = (await tester.runAsync(
        () => repo.readSleepSession(sleepId),
      ))!;
      expect(updated.id, original.id);
      expect(updated.createdAt, 1);
      expect(updated.updatedAt, at(30, 12));
      expect(updated.note, original.note);
      expect(updated.type, SleepType.nap);
      expect(updated.startPrecision, TimePrecision.exact);
      expect(updated.endPrecision, TimePrecision.approximate);
      nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      expect(await tester.runAsync(() => nextStore.read(context28)), isNull);
      await selectDate(tester, '2026-09-29');
      expect(ledgerDuration('已交代', '10 分钟'), findsOneWidget);
      await tester.ensureVisible(find.text('完整睡眠 · 按醒来日期'));
      await tester.tap(find.text('完整睡眠 · 按醒来日期'));
      await tester.pumpAndSettle();
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      await selectDate(tester, '2026-09-30');
      expect(ledgerDuration('已交代', '约7 小时 40 分钟'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('约7 小时 50 分钟'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('约7 小时 50 分钟'), findsOneWidget);
      expect(sleepFact(sleepId), findsOneWidget);
      await edit(
        tester,
      ); // Awake-day summary leads to the same complete source.
      final awake = tester.widget<SleepForm>(find.byType(SleepForm)).controller;
      expect(awake.startedAt, updated.startedAt);
      expect(awake.endedAt, updated.endedAt);
      await tapText(tester, '主睡眠');
      await tapText(tester, '保存更正');
      expect(
        (await tester.runAsync(() => repo.readSleepSession(sleepId)))!.type,
        SleepType.mainSleep,
      );
      await tester.scrollUntilVisible(
        find.text('约7 小时 50 分钟'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('尚未记录小睡'), findsOneWidget);
      nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      await edit(tester);
      await tapText(tester, '删除睡眠');
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(ledgerDuration('已交代', '0 分钟'), findsOneWidget);
      expect(ledgerDuration('尚未记录', '12 小时'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      expect(
        await tester.runAsync(() => repo.readSleepSession(sleepId)),
        isNull,
      );
      final verify = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      expect(
        await tester.runAsync(
          () => verify.read(
            SleepDraftContext.edit(date: day(30), sleepSessionId: sleepId),
          ),
        ),
        isNull,
      );
      await tester.runAsync(verify.close);
      await selectDate(tester, '2026-09-29');
      expect(ledgerDuration('已交代', '0 分钟'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM sleep_sessions').get(),
        ),
        isEmpty,
      );
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ),
        isEmpty,
      );
      expect(
        await tester.runAsync(
          () => db.customSelect('SELECT * FROM rhythm_annotations').get(),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'app rejects a stale summary edit when source was removed, preserving the real edit draft',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final ordinary = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final store = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase.memory()),
      ))!;
      final repo = DriftLedgerRepository(db);
      await tester.runAsync(
        () => repo.createSleepSession(
          id: sleepId,
          startedAt: at(28, 23, 50),
          endedAt: at(29, 7, 40),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          now: 1,
        ),
      );
      final context = SleepDraftContext.edit(
        date: day(29),
        sleepSessionId: sleepId,
      );
      await tester.runAsync(
        () => store.save(
          SleepDraft(
            context: context,
            startedAt: at(28, 23, 40),
            endedAt: at(29, 8),
            startPrecision: TimePrecision.approximate,
            endPrecision: TimePrecision.exact,
            type: SleepType.nap,
          ),
        ),
      );
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => ordinary,
          openReviewDrafts: emptyLegacyReviewDrafts,
          openSleepDrafts: () async => store,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '查看记录');
      await tester.runAsync(() => repo.deleteSleepSession(sleepId));
      await edit(tester);
      expect(find.textContaining('记录已不存在'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      expect(
        (await tester.runAsync(() => store.read(context)))!.type,
        SleepType.nap,
      );
      expect(
        await tester.runAsync(() => repo.readSleepSession(sleepId)),
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      // UI-04：编辑返回先回到来源详情，再返回账本。
      if (find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(ledgerDuration('已交代', '0 分钟'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
