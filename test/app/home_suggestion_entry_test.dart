import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';

import '../support/ledger_date_selection.dart' show selectLedgerDate;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

/// 真实 bootstrap 打开首页建议区域：读偏好、查账本、按 Q-028 / Q-029 解析。
Future<void> open(
  WidgetTester tester,
  int now, {
  Future<void> Function(DriftLedgerRepository repo)? seed,
  AppPreferences? preferences,
}) async {
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  final drafts = (await tester.runAsync(
    () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
  ))!;
  final sleepDrafts = (await tester.runAsync(
    () => DriftSleepDraftStore.open(NativeDatabase.memory()),
  ))!;
  final openings = (await tester.runAsync(
    () => DriftSleepOpeningStore.open(NativeDatabase.memory()),
  ))!;
  final prefStore = (await tester.runAsync(
    () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
    await tester.runAsync(drafts.close);
    await tester.runAsync(sleepDrafts.close);
    await tester.runAsync(openings.close);
    await tester.runAsync(prefStore.close);
  });
  if (seed != null) {
    await tester.runAsync(() => seed(DriftLedgerRepository(db)));
  }
  if (preferences != null) {
    await tester.runAsync(() => prefStore.write(preferences));
  }
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async => db,
      openDrafts: () async => drafts,
      openReviewDrafts: emptyLegacyReviewDrafts,
      openSleepDrafts: () async => sleepDrafts,
      openSleepOpenings: () async => openings,
      openPreferences: () async => prefStore,
      now: () => DateTime.fromMillisecondsSinceEpoch(now),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> mainSleep(DriftLedgerRepository repo) async {
  await repo.createSleepSession(
    id: id(1),
    startedAt: at(28, 23, 40),
    endedAt: at(29, 7, 20),
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    type: SleepType.mainSleep,
    now: 1,
  );
}

void main() {
  testWidgets('sleep suggestion greets records when no main sleep exists', (
    tester,
  ) async {
    // 09:00 处于 08:00–12:00 窗口内且尚未记录主睡眠。
    await open(tester, at(29, 9));
    expect(find.byKey(const ValueKey('home-suggestion')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-suggestion-sleep')), findsOneWidget);
    expect(find.text('昨晚睡得怎么样？'), findsOneWidget);
    expect(find.text('记录睡眠'), findsWidgets);
    // 首次打开不再弹模态确认框。
    expect(find.text('确认主睡眠'), findsNothing);
  });

  testWidgets('recorded main sleep falls back to greeting inside the window', (
    tester,
  ) async {
    await open(tester, at(29, 9), seed: mainSleep);
    expect(find.byKey(const ValueKey('home-suggestion')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-suggestion-greeting')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-suggestion-sleep')), findsNothing);
  });

  testWidgets('after noon a long trailing gap suggests recording', (
    tester,
  ) async {
    // 13:00 已有事实仅到 10:00，尾部 Gap 达 3 小时。
    await open(
      tester,
      at(29, 13),
      seed: (repo) async {
        await repo.createTimeBlock(
          id: id(2),
          startedAt: at(29, 9),
          endedAt: at(29, 10),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '早餐',
          now: 1,
        );
      },
    );
    expect(
      find.byKey(const ValueKey('home-suggestion-record')),
      findsOneWidget,
    );
    expect(find.text('刚才在做什么？'), findsOneWidget);
    expect(find.text('补记一笔'), findsOneWidget);
  });

  testWidgets('review suggestion appears at the review time', (tester) async {
    // 22:00；用一条覆盖到窗口末端的事实消除长尾 Gap，且无睡眠待补。
    await open(
      tester,
      at(29, 22),
      seed: (repo) async {
        await repo.createTimeBlock(
          id: id(3),
          startedAt: at(29, 21),
          endedAt: at(29, 22),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '晚间',
          now: 1,
        );
      },
    );
    expect(
      find.byKey(const ValueKey('home-suggestion-review')),
      findsOneWidget,
    );
    expect(find.text('开始复盘'), findsOneWidget);
  });

  testWidgets('a disabled total switch hides the whole region', (tester) async {
    await open(
      tester,
      at(29, 9),
      preferences: const AppPreferences(reminders: false),
    );
    expect(find.byKey(const ValueKey('home-suggestion')), findsNothing);
    expect(find.text('早上好。'), findsNothing);
  });

  testWidgets('historical dates do not show the bottom reminder region', (
    tester,
  ) async {
    // 底部提醒只属于今天；历史日连普通问候也不显示。
    await open(
      tester,
      at(29, 13),
      seed: (repo) async {
        await repo.createTimeBlock(
          id: id(2),
          startedAt: at(29, 9),
          endedAt: at(29, 10),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '早餐',
          now: 1,
        );
      },
    );
    await selectLedgerDate(tester, '2026-09-28');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-suggestion')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-suggestion-greeting')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home-suggestion-record')), findsNothing);
  });

  testWidgets('editable reminder times move the sleep window', (tester) async {
    // 睡眠时点改为 06:00 后，06:30 仍应提示记录睡眠。
    await open(
      tester,
      at(29, 6, 30),
      preferences: const AppPreferences(sleepReminderMinutes: 6 * 60),
    );
    expect(find.byKey(const ValueKey('home-suggestion-sleep')), findsOneWidget);
  });
}
