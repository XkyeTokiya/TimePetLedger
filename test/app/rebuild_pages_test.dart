import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_history_reader.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/presentation/goal_management_page.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/fact_detail_page.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';
import 'package:time_pet_ledger/features/settings/data/drift_data_maintenance.dart';
import 'package:time_pet_ledger/features/settings/domain/app_preferences.dart';
import 'package:time_pet_ledger/features/settings/presentation/settings_page.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final now = DateTime(2026, 10, 6, 15);
final day5 = CivilDate(year: 2026, month: 10, day: 5);

ReconciliationWindow window5() => ReconciliationWindow.select(
  date: day5,
  relation: LedgerDateRelation.historical,
  dayStartedAt: at(5, 0),
  nextDayStartedAt: at(6, 0),
  now: now.millisecondsSinceEpoch,
);

Widget host(Widget child) => MaterialApp(theme: homeTheme, home: child);

void main() {
  testWidgets('fact detail reads a TimeBlock and confirms deletion', (t) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => t.runAsync(db.close));
    final repo = DriftLedgerRepository(db);
    await t.runAsync(
      () => repo.createTimeBlock(
        id: id(1),
        startedAt: at(5, 8),
        endedAt: at(5, 10),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '设计首页',
        note: '先画补记弹层',
        now: 1,
      ),
    );
    final facts = (await t.runAsync(
      () => repo.readWindow(startedAt: at(5, 0), endedAt: at(6, 0)),
    ))!;
    final segment = projectLedgerSegments(
      window: window5(),
      timeBlocks: facts.timeBlocks,
      sleepSessions: facts.sleepSessions,
      annotations: facts.annotations,
    ).single;

    LedgerDetailAction? action;
    await t.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () async {
                action = await showFactDetail(
                  context,
                  segment: segment,
                  canEdit: true,
                  canDelete: true,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pumpAndSettle();

    expect(find.text('记录详情'), findsOneWidget);
    expect(find.text('设计首页'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('先画补记弹层'), findsOneWidget);
    expect(find.text('2 小时'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('fact-detail-delete')));
    await t.pumpAndSettle();
    expect(find.text('删除这条记录？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('fact-detail-confirm-delete')));
    await t.pumpAndSettle();
    expect(action, LedgerDetailAction.delete);
  });

  testWidgets('fact detail shows the full cross-day sleep interval', (t) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => t.runAsync(db.close));
    final repo = DriftLedgerRepository(db);
    await t.runAsync(
      () => repo.createSleepSession(
        id: id(2),
        startedAt: at(4, 23),
        endedAt: at(5, 7),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        note: '夜里醒了一次',
        now: 1,
      ),
    );
    final sleep = (await t.runAsync(() => repo.readSleepSession(id(2))))!;
    final segment = projectLedgerSegments(
      window: window5(),
      timeBlocks: const [],
      sleepSessions: [sleep],
      annotations: const [],
    ).single;

    LedgerDetailAction? action;
    await t.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () async {
                action = await showFactDetail(
                  context,
                  segment: segment,
                  canEdit: true,
                  canDelete: false,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pumpAndSettle();

    expect(find.text('主睡眠'), findsOneWidget);
    expect(find.text('完整睡眠区间'), findsOneWidget);
    expect(find.text('入睡'), findsOneWidget);
    expect(find.text('醒来'), findsOneWidget);
    expect(find.text('8 小时'), findsOneWidget);
    expect(find.byKey(const ValueKey('fact-detail-delete')), findsNothing);
    await t.tap(find.byKey(const ValueKey('fact-detail-edit')));
    await t.pumpAndSettle();
    expect(action, LedgerDetailAction.edit);
  });

  testWidgets('goal management lists, opens details and archives', (t) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final prefsStore = (await t.runAsync(
      () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => t.runAsync(db.close));
    addTearDown(() => t.runAsync(prefsStore.close));
    final goals = DriftGoalRepository(db);
    final ledger = DriftLedgerRepository(db);
    await t.runAsync(() async {
      await goals.create(id: id(1), name: '毕业设计', now: 1);
      await ledger.createTimeBlock(
        id: id(2),
        startedAt: at(5, 9),
        endedAt: at(5, 11),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '查阅资料',
        goalId: id(1),
        now: 2,
      );
    });
    await t.pumpWidget(
      host(
        GoalManagementPage(
          repository: goals,
          history: DriftGoalHistoryReader(db),
          preferences: prefsStore,
          newId: () => id(9),
          now: () => now.millisecondsSinceEpoch,
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('我的目标'), findsOneWidget);
    expect(find.text('毕业设计'), findsOneWidget);
    await t.tap(find.byKey(ValueKey('goal-open-${id(1)}')));
    await t.pumpAndSettle();
    expect(find.text('时间投入'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('查阅资料'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('此前记录'), findsOneWidget);
    expect(find.text('查阅资料'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('goal-archive')));
    await t.pumpAndSettle();
    expect(find.text('归档这个目标？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('goal-confirm-action')));
    await t.pumpAndSettle();
    expect(find.text('还没有目标。'), findsOneWidget);
    expect((await t.runAsync(goals.listArchived))!.single.name, '毕业设计');
  });

  testWidgets('goal management toggles the common goal preference', (t) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final prefsStore = (await t.runAsync(
      () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => t.runAsync(db.close));
    addTearDown(() => t.runAsync(prefsStore.close));
    final goals = DriftGoalRepository(db);
    await t.runAsync(() => goals.create(id: id(1), name: '英语学习', now: 1));
    await t.pumpWidget(
      host(
        GoalManagementPage(
          repository: goals,
          history: DriftGoalHistoryReader(db),
          preferences: prefsStore,
          newId: () => id(9),
          now: () => now.millisecondsSinceEpoch,
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(ValueKey('goal-common-${id(1)}')));
    await t.pumpAndSettle();
    expect(find.text('常用'), findsOneWidget);
    expect((await t.runAsync(prefsStore.read))!.commonGoalId, id(1));

    await t.tap(find.byKey(ValueKey('goal-common-${id(1)}')));
    await t.pumpAndSettle();
    expect((await t.runAsync(prefsStore.read))!.commonGoalId, isNull);
  });

  testWidgets('settings saves a preference and seeds only when empty', (
    t,
  ) async {
    final db = (await t.runAsync(
      () => AppDatabase.open(NativeDatabase.memory()),
    ))!;
    final prefsStore = (await t.runAsync(
      () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
    ))!;
    addTearDown(() => t.runAsync(db.close));
    addTearDown(() => t.runAsync(prefsStore.close));
    final maintenance = DriftDataMaintenance(db);
    var nextFactId = 2;
    await t.pumpWidget(
      host(
        SettingsPage(
          preferences: prefsStore,
          maintenance: maintenance,
          newGoalId: () => id(1),
          newFactId: () => id(nextFactId++),
          now: () => now.millisecondsSinceEpoch,
          versionLabel: '0.1.0 · 构建 1',
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('settings-open-display')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('settings-heat-month')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const ValueKey('settings-heat-month')));
    await t.pumpAndSettle();
    expect((await t.runAsync(prefsStore.read))!.heatRange, HeatRange.month);

    await t.tap(find.byKey(const ValueKey('settings-back')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings-open-recording')));
    await t.pumpAndSettle();
    for (final entry in ['sleep', 'review']) {
      final field = find.byKey(ValueKey('settings-$entry-reminder'));
      await t.ensureVisible(field);
      await t.tap(field);
      await t.pumpAndSettle();
      final original = (await t.runAsync(prefsStore.read))!;
      final wheels = t
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      expect(
        (wheels[0].controller! as FixedExtentScrollController).selectedItem,
        entry == 'sleep' ? 8 : 22,
      );
      expect(
        (wheels[1].controller! as FixedExtentScrollController).selectedItem,
        0,
      );
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      final cancelled = (await t.runAsync(prefsStore.read))!;
      expect(
        (cancelled.sleepReminderMinutes, cancelled.reviewReminderMinutes),
        (original.sleepReminderMinutes, original.reviewReminderMinutes),
      );
      await t.tap(field);
      await t.pumpAndSettle();
      final changed = t
          .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
          .toList();
      (changed[0].controller! as FixedExtentScrollController).jumpToItem(9);
      (changed[1].controller! as FixedExtentScrollController).jumpToItem(17);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('time-picker-confirm')));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final saved = (await t.runAsync(prefsStore.read))!;
      expect(
        entry == 'sleep'
            ? saved.sleepReminderMinutes
            : saved.reviewReminderMinutes,
        9 * 60 + 17,
      );
    }
    await t.tap(find.byKey(const ValueKey('settings-back')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings-open-advanced')));
    await t.pumpAndSettle();
    expect(find.textContaining('目前还没有数据'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('settings-seed')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings-confirm-seed')));
    await t.pumpAndSettle();
    expect(find.text('测试数据已添加。'), findsOneWidget);
    final counts = (await t.runAsync(maintenance.counts))!;
    expect(counts.goals, 1);
    expect(counts.activities, greaterThan(0));
    expect(counts.sleep, greaterThan(0));
    expect(counts.reviews, greaterThan(0));
    expect(
      t.widget<InkWell>(find.byKey(const ValueKey('settings-seed'))).onTap,
      isNull,
    );
  });
}
