import '../support/root_navigation.dart';

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/sleep_entry.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import '../support/app_sleep_navigation.dart' show tapText, enter;

final context = SleepDraftContext.newEntry(
  date: CivilDate(year: 2026, month: 9, day: 29),
);

void main() {
  testWidgets(
    'app entry needs no Goal, closes/reopens real draft storage and leaves formal data unchanged',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('sleep_entry_'),
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
      final opened = <DriftSleepDraftStore>[];
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => ordinary,
          openSleepDrafts: () async {
            opened.add(nextStore);
            return nextStore;
          },
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        opened,
        isEmpty,
      ); // lazy app-owned connection, ordinary entry unchanged
      await tapRootAction(tester, '记录睡眠');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sleep-start-time')), findsOneWidget);
      final first = tester
          .widget<SleepRecordingPage>(find.byType(SleepRecordingPage))
          .controller;
      expect(
        (first.startedAt, first.endedAt),
        (
          DateTime(2026, 9, 28, 23).millisecondsSinceEpoch,
          DateTime(2026, 9, 29, 7).millisecondsSinceEpoch,
        ),
      );
      first.setTime(
        start: DateTime(2026, 9, 28, 23, 50).millisecondsSinceEpoch,
        end: DateTime(2026, 9, 29, 7, 40).millisecondsSinceEpoch,
      );
      first.setType(SleepType.mainSleep);
      first.setNote('保留备注');
      await tester.runAsync(first.flush);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(find.byType(SleepRecordingPage), findsNothing);
      await tester.runAsync(
        () => expectLater(
          opened.single.read(context),
          throwsA(isA<SleepDraftStorageException>()),
        ),
      );
      nextStore = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      await tapRootAction(tester, '记录睡眠');
      await tester.pumpAndSettle();
      expect(opened, hasLength(2));
      final second = tester
          .widget<SleepRecordingPage>(find.byType(SleepRecordingPage))
          .controller;
      expect(second.restored, isTrue);
      expect(second.note, '保留备注');
      expect(second.type, SleepType.mainSleep);
      expect(
        (second.startedAt, second.endedAt),
        (
          DateTime(2026, 9, 28, 23).millisecondsSinceEpoch,
          DateTime(2026, 9, 29, 7).millisecondsSinceEpoch,
        ),
      );
      for (final table in [
        'goals',
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
      await tester.runAsync(second.flush);
      await tapText(tester, '放弃草稿');
      await tester.pumpAndSettle();
      expect(find.text('放弃这次睡眠？'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '放弃草稿').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      final verification = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase(file)),
      ))!;
      expect(await tester.runAsync(() => verification.read(context)), isNull);
      await tester.runAsync(verification.close);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('edit draft typing with a real original never writes that fact', (
    tester,
  ) async {
    final db = (await tester.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final store = (await tester.runAsync(
      () => DriftSleepDraftStore.open(NativeDatabase.memory()),
    ))!;
    final repo = DriftLedgerRepository(db);
    final original = (await tester.runAsync(
      () => repo.createSleepSession(
        id: '00000000-0000-4000-8000-000000000001',
        startedAt: 1,
        endedAt: 60001,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        now: 1,
      ),
    ))!;
    final before = await tester.runAsync(
      () => db.customSelect('SELECT * FROM sleep_sessions').get(),
    );
    final c = SleepFormController(
      context: SleepDraftContext.edit(
        date: context.date,
        sleepSessionId: original.id,
      ),
      store: store,
      original: original,
    );
    await tester.pumpWidget(MaterialApp(home: SleepForm(controller: c)));
    await tester.pumpAndSettle();
    await enter(tester, 'sleep-start', '2026-09-29 01:00');
    await tapText(tester, '小睡');
    await tester.runAsync(c.flush);
    final after = await tester.runAsync(
      () => db.customSelect('SELECT * FROM sleep_sessions').get(),
    );
    expect(after!.map((r) => r.data), before!.map((r) => r.data));
    expect(
      (await tester.runAsync(() => store.read(c.context)))!.type,
      SleepType.nap,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.runAsync(store.close);
    await tester.runAsync(db.close);
  });

  testWidgets(
    'opening failure is retryable and late connection closes after disposal',
    (tester) async {
      final store = (await tester.runAsync(
        () => DriftSleepDraftStore.open(NativeDatabase.memory()),
      ))!;
      final pending = Completer<DriftSleepDraftStore>();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SleepEntry(
            context: context,
            openStore: () async {
              attempts++;
              if (attempts == 1) throw StateError('private path');
              return pending.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('无法打开睡眠草稿，请重试。'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      await tester.tap(find.text('重试打开'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(store);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => expectLater(
          store.read(context),
          throwsA(isA<SleepDraftStorageException>()),
        ),
      );
    },
  );
}
