import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import '../features/ledger/presentation/sleep_form_test.dart'
    as sleep_test
    show tapText;
import '../support/root_navigation.dart';

Future<void> tapText(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) return;
  await sleep_test.tapText(tester, text);
}

/// Advances the stepped activity recorder (节奏 → 事项 → 时间).
Future<void> advanceRecorder(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('activity-primary')));
  await tester.pumpAndSettle();
}

final day = CivilDate(year: 2026, month: 9, day: 30);
const id = '00000000-0000-4000-8000-000000000001';

class LocalApp {
  LocalApp(this.dir);
  final Directory dir;
  DateTime now = DateTime(2026, 9, 30, 12);
  final databases = <AppDatabase>[];
  final markers = <DriftSleepOpeningStore>[];
  var markerOpens = 0;
  var failMarker = false;
  Completer<DriftSleepOpeningStore>? pendingMarker;

  File file(String name) => File('${dir.path}/$name.sqlite');
  AppBootstrap build() => AppBootstrap(
    openDatabase: () async {
      final db = await AppDatabase.open(NativeDatabase(file('formal')));
      databases.add(db);
      return db;
    },
    openDrafts: () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
    openSleepDrafts: () =>
        DriftSleepDraftStore.open(NativeDatabase(file('drafts'))),
    openSleepOpenings: () async {
      markerOpens++;
      if (failMarker) throw StateError('private marker diagnostics');
      final pending = pendingMarker;
      final store = pending == null
          ? await DriftSleepOpeningStore.open(NativeDatabase(file('markers')))
          : await pending.future;
      markers.add(store);
      return store;
    },
    now: () => now,
  );
}

Future<LocalApp> setup(WidgetTester tester) async {
  final dir = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('first_sleep_app_'),
  ))!;
  addTearDown(() => dir.delete(recursive: true));
  return LocalApp(dir);
}

Future<void> stop(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
}

Future<void> resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'first confirmation can continue ledger; reopening same file/date suppresses; next day resumes once',
    (tester) async {
      final app = await setup(tester);
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text('确认主睡眠'), findsOneWidget);
      await tapText(tester, '继续账本');
      await tester.ensureVisible(find.text('完整睡眠 · 按醒来日期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整睡眠 · 按醒来日期'));
      await tester.pumpAndSettle();
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      await tapText(tester, '记录活动');
      await advanceRecorder(tester);
      expect(find.byKey(const ValueKey('activity')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await resume(tester);
      expect(find.text('确认主睡眠'), findsNothing);
      expect(app.markerOpens, 1);
      await stop(tester);
      await tester.runAsync(
        () => expectLater(app.markers.single.claim(day), throwsA(anything)),
      );
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text('确认主睡眠'), findsNothing);
      app.now = DateTime(2026, 10, 1, 0, 1);
      await resume(tester);
      expect(find.text('确认主睡眠'), findsOneWidget);
      await tapText(tester, '继续账本');
      await resume(tester);
      expect(find.text('确认主睡眠'), findsNothing);
      for (final table in [
        'goals',
        'time_blocks',
        'sleep_sessions',
        'rhythm_annotations',
        'daily_reviews',
      ]) {
        expect(
          await tester.runAsync(
            () => app.databases.last.customSelect('SELECT * FROM $table').get(),
          ),
          isEmpty,
        );
      }
      await stop(tester);
    },
  );

  testWidgets(
    'confirmation restores incomplete nap draft unchanged; leaving and manual reentry do not prompt again',
    (tester) async {
      final app = await setup(tester);
      await tester.runAsync(() async {
        final drafts = await DriftSleepDraftStore.open(
          NativeDatabase(app.file('drafts')),
        );
        await drafts.save(
          SleepDraft(
            context: SleepDraftContext.newEntry(date: day),
            startedAt: DateTime(2026, 9, 30, 10).millisecondsSinceEpoch,
            endedAt: null,
            startPrecision: TimePrecision.approximate,
            endPrecision: TimePrecision.exact,
            type: SleepType.nap,
            startedAtInput: '2026-09-30 10:00',
            endedAtInput: '2026-09-',
          ),
        );
        await drafts.close();
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tapText(tester, '确认睡眠起止');
      expect(find.text('已恢复上次睡眠输入'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('sleep-end')))
            .controller!
            .text,
        '2026-09-',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '小睡'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '入睡大约'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '醒来准确'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await resume(tester);
      expect(find.text('确认主睡眠'), findsNothing);
      await tapText(tester, '记录睡眠');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('sleep-end')))
            .controller!
            .text,
        '2026-09-',
      );
      expect(
        await tester.runAsync(
          () => app.databases.last
              .customSelect('SELECT * FROM sleep_sessions')
              .get(),
        ),
        isEmpty,
      );
      await stop(tester);
    },
  );

  testWidgets(
    'recorded main sleep skips; deletion then resume uses current absence without prompting',
    (tester) async {
      final app = await setup(tester);
      await tester.runAsync(() async {
        final db = await AppDatabase.open(NativeDatabase(app.file('formal')));
        await DriftLedgerRepository(db).createSleepSession(
          id: id,
          startedAt: DateTime(2026, 9, 29, 23).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 9, 30, 7).millisecondsSinceEpoch,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          type: SleepType.mainSleep,
          now: 1,
        );
        await db.close();
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text('确认主睡眠'), findsNothing);
      expect(find.text('尚未记录主睡眠'), findsNothing);
      await tester.runAsync(
        () => DriftLedgerRepository(app.databases.last).deleteSleepSession(id),
      );
      await resume(tester);
      await tester.ensureVisible(find.text('完整睡眠 · 按醒来日期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('完整睡眠 · 按醒来日期'));
      await tester.pumpAndSettle();
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      expect(find.text('确认主睡眠'), findsNothing);
      await stop(tester);
    },
  );

  testWidgets(
    'failed fact read is visible and retryable without consuming first opening',
    (tester) async {
      final app = await setup(tester);
      await tester.runAsync(() async {
        final db = await AppDatabase.open(NativeDatabase(app.file('formal')));
        await db.customStatement('PRAGMA ignore_check_constraints = ON');
        await db.customStatement(
          "INSERT INTO sleep_sessions (id, started_at, ended_at, start_precision, end_precision, sleep_type, created_at, updated_at) VALUES (?, ?, ?, 'exact', 'exact', 'invalid', 1, 1)",
          [
            id,
            DateTime(2026, 9, 30, 1).millisecondsSinceEpoch,
            DateTime(2026, 9, 30, 2).millisecondsSinceEpoch,
          ],
        );
        await db.close();
      });
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text('主睡眠确认检查失败；可继续记账，或重试检查。'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsNothing);
      expect(find.text('确认主睡眠'), findsNothing);
      expect(app.markerOpens, 0);
      await tester.runAsync(
        () => app.databases.last.customStatement('DELETE FROM sleep_sessions'),
      );
      await tapText(tester, '重试主睡眠检查');
      expect(find.text('确认主睡眠'), findsOneWidget);
      await tapText(tester, '继续账本');
      await stop(tester);
    },
  );

  testWidgets(
    'marker opening failure leaves ledger usable; retry opens once and claims first date',
    (tester) async {
      final app = await setup(tester)
        ..failMarker = true;
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(find.text('主睡眠确认检查失败；可继续记账，或重试检查。'), findsOneWidget);
      expect(find.textContaining('private marker'), findsNothing);
      await tapText(tester, '记录活动');
      await advanceRecorder(tester);
      expect(find.byKey(const ValueKey('activity')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      app.failMarker = false;
      await tapText(tester, '重试主睡眠检查');
      expect(find.text('确认主睡眠'), findsOneWidget);
      await tapText(tester, '继续账本');
      await resume(tester);
      expect(app.markerOpens, 2);
      await stop(tester);
    },
  );

  testWidgets(
    'returning from an open form on the next device date checks the new day',
    (tester) async {
      final app = await setup(tester);
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      await tapText(tester, '继续账本');
      await tapText(tester, '记录活动');
      app.now = DateTime(2026, 10, 1, 0, 1);
      await resume(tester);
      expect(find.text('确认主睡眠'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('确认主睡眠'), findsOneWidget);
      await tapText(tester, '确认睡眠起止');
      expect(find.byKey(const ValueKey('sleep-start')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('10月1日 今天'), findsOneWidget);
      await resume(tester);
      expect(find.text('确认主睡眠'), findsNothing);
      await stop(tester);
    },
  );

  testWidgets(
    'late first check across midnight does not present a stale-date confirmation',
    (tester) async {
      final app = await setup(tester);
      app.pendingMarker = Completer<DriftSleepOpeningStore>();
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(app.markerOpens, 1);
      app.now = DateTime(2026, 10, 1, 0, 1);
      final store = (await tester.runAsync(
        () => DriftSleepOpeningStore.open(NativeDatabase(app.file('markers'))),
      ))!;
      app.pendingMarker!.complete(store);
      await tester.pumpAndSettle();
      expect(find.text('确认主睡眠'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => store.claim(CivilDate(year: 2026, month: 10, day: 1)),
        ),
        isFalse,
      );
      expect(app.markerOpens, 1);
      await tapText(tester, '继续账本');
      await stop(tester);
    },
  );

  testWidgets(
    'opening state completing after app disposal closes without claiming',
    (tester) async {
      final app = await setup(tester);
      app.pendingMarker = Completer<DriftSleepOpeningStore>();
      await tester.pumpWidget(app.build());
      await tester.pumpAndSettle();
      expect(app.markerOpens, 1);
      await stop(tester);
      final store = (await tester.runAsync(
        () => DriftSleepOpeningStore.open(NativeDatabase(app.file('markers'))),
      ))!;
      app.pendingMarker!.complete(store);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await expectLater(store.claim(day), throwsA(anything));
        final reopened = await DriftSleepOpeningStore.open(
          NativeDatabase(app.file('markers')),
        );
        expect(await reopened.claim(day), isTrue);
        await reopened.close();
      });
    },
  );
}
