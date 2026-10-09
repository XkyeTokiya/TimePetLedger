import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';

import '../support/home_feed.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final oct1 = CivilDate(year: 2026, month: 10, day: 1);
final oct2 = CivilDate(year: 2026, month: 10, day: 2);

int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

Future<AppDatabase> openLedger(WidgetTester tester) async {
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(db.close);
  });
  final repo = DriftLedgerRepository(db);
  await tester.runAsync(() async {
    // 跨日睡眠：9 月 30 日 23:40 → 10 月 1 日 07:20，只保留一条事实。
    await repo.createSleepSession(
      id: id(1),
      startedAt: DateTime(2026, 9, 30, 23, 40).millisecondsSinceEpoch,
      endedAt: at(1, 7, 20),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 1,
    );
    await repo.createTimeBlock(
      id: id(2),
      startedAt: at(1, 9),
      endedAt: at(1, 10),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月一日活动',
      now: 1,
    );
    await repo.createTimeBlock(
      id: id(3),
      startedAt: at(2, 8),
      endedAt: at(2, 9),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月二日活动',
      now: 1,
    );
  });
  return db;
}

Future<HomeShellState> mountHome(
  WidgetTester tester,
  AppDatabase db, {
  required CivilDate initialDate,
  required int now,
  DayLedgerLoader? loader,
  int Function()? changingClock,
  bool disableAnimations = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: homeTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: HomeShell(
        ledgerLoader: loader ?? createDayLedgerLoader(db),
        now: changingClock ?? () => now,
        dateOfInstant: deviceDateOfInstant,
        initialDate: initialDate,
        busy: false,
        onOpenSummary: () {},
        onOpenReview: () {},
        onRecordActivity: () {},
        onRecordSleep: () {},
      ),
    ),
  );
  await settleNative(tester);
  return tester.state<HomeShellState>(find.byType(HomeShell));
}

void main() {
  testWidgets(
    'continuous feed keeps one projection per day and moves the top date while reading',
    (tester) async {
      final db = await openLedger(tester);
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: at(3, 9),
      );
      expect(homeDateTitle(tester), '10月2日');
      expect(find.text('十月二日活动'), findsOneWidget);
      expect(find.text('十月一日活动'), findsOneWidget);
      // 顶部统计只属于当前浏览日：10 月 2 日 1 小时已交代。
      expect(coverageText(tester, '已交代'), '1 小时');
      expect(coverageText(tester, '尚未记录'), '23 小时');

      // 跳到 10 月 1 日：日期提示与统计一起切换，窗口以该日为最新一天。
      await shell.openDate(oct1);
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月1日');
      expect(coverageText(tester, '已交代'), '8 小时 20 分钟');
      expect(coverageText(tester, '尚未记录'), '15 小时 40 分钟');
      expect(find.text('主睡眠'), findsWidgets);
      expect(find.text('十月一日活动'), findsOneWidget);
      expect(dayDivider(oct2), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('scrolling across the day boundary updates the pinned date', (
    tester,
  ) async {
    final db = await openLedger(tester);
    await mountHome(tester, db, initialDate: oct2, now: at(3, 9));
    expect(homeDateTitle(tester), '10月2日');

    // 主体向下拖动 = 读更早的时间；跨过日期分隔后顶部日期随之变化。
    await tester.drag(find.byType(HomeTimelineTab), const Offset(0, 700));
    await settleNative(tester);
    expect(homeDateTitle(tester), isNot('10月2日'));
    expect(find.byKey(const ValueKey('home-header-collapsed')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-sticky-day')), findsNothing);
    expect(find.text('10月1日'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'horizontal swipe moves exactly one day and keeps edge gestures',
    (tester) async {
      final db = await openLedger(tester);
      await mountHome(tester, db, initialDate: oct2, now: at(3, 9));

      await swipeFeed(tester, -120);
      expect(homeDateTitle(tester), '10月3日');
      expect(find.byKey(const ValueKey('home-back-to-today')), findsNothing);

      await swipeFeed(tester, 120);
      expect(homeDateTitle(tester), '10月2日');
      await swipeFeed(tester, 120);
      expect(homeDateTitle(tester), '10月1日');
      expect(find.byKey(const ValueKey('home-back-to-today')), findsOneWidget);

      // 左边缘属于侧边栏手势保留区：不切日。
      await swipeFeed(tester, 120, startX: 8);
      expect(homeDateTitle(tester), '10月1日');
      if (find.byType(NavigationDrawer).evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(380, 400));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar jump and back-to-today use the same date rules', (
    tester,
  ) async {
    final db = await openLedger(tester);
    await mountHome(tester, db, initialDate: oct2, now: at(3, 9));

    // 点击顶部日期打开日历，并手动跳到 10 月 1 日。
    await tester.tap(find.byKey(const ValueKey('ledger-date-picker')));
    await tester.pumpAndSettle();
    expect(find.text('选择账本日期'), findsOneWidget);
    await tester.tap(find.text('手动输入日期'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '账本日期'),
      '2026-10-01',
    );
    await tester.tap(find.text('确认日期'));
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月1日');
    expect(coverageText(tester, '已交代'), '8 小时 20 分钟');

    // 日期分隔同样打开该日日历；取消不改变浏览日期。
    await tester.ensureVisible(dayDivider(oct1));
    await tester.pumpAndSettle();
    await tester.tap(dayDivider(oct1));
    await tester.pumpAndSettle();
    expect(find.text('选择账本日期'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(homeDateTitle(tester), '10月1日');

    await tester.tap(find.byKey(const ValueKey('home-back-to-today')));
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月3日');
    expect(coverageText(tester, '已交代'), '0 分钟');
    expect(coverageText(tester, '尚未记录'), '9 小时');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cross-day sleep keeps identity and full interval on both days', (
    tester,
  ) async {
    final db = await openLedger(tester);
    final shell = await mountHome(tester, db, initialDate: oct1, now: at(2, 9));
    expect(homeDateTitle(tester), '10月1日');
    // 醒来日窗口内 00:00–07:20 的切片 + 1 小时活动。
    expect(coverageText(tester, '已交代'), '8 小时 20 分钟');
    expect(find.textContaining('跨日切片'), findsWidgets);

    // 10 月 1 日的睡眠行是窗内切片，完整区间只在详情里展开。
    await tester.tap(
      find
          .ancestor(of: find.text('主睡眠').last, matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    // 只读详情仍展示同一完整事实的原始区间与整段时长。
    expect(find.text('记录详情'), findsOneWidget);
    expect(find.text('完整睡眠区间'), findsOneWidget);
    expect(find.text('9月30日 23:40'), findsWidgets);
    expect(find.text('10月1日 07:20'), findsWidgets);
    expect(find.text('10月1日时间线计入 7 小时 20 分钟'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 同一条事实在 10 月 2 日只贡献自己的窗口切片，不重复整段时长。
    await shell.openDate(oct2);
    await settleNative(tester);
    expect(coverageText(tester, '已交代'), '1 小时');
    // 设备当天窗口只到 09:00，未来部分不计 Gap。
    expect(coverageText(tester, '尚未记录'), '8 小时');
    expect(find.text('十月二日活动'), findsOneWidget);
    expect(dayDivider(oct2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("today's future window is not counted as a gap", (tester) async {
    final db = await openLedger(tester);
    await mountHome(tester, db, initialDate: oct2, now: at(2, 12));
    expect(homeDateTitle(tester), '10月2日');
    // 窗口 00:00–12:00：已交代 1 小时，未记录 00:00–08:00 + 09:00–12:00。
    expect(coverageText(tester, '已交代'), '1 小时');
    expect(coverageText(tester, '尚未记录'), '11 小时');
    expect(find.byKey(const ValueKey('home-sticky-day')), findsNothing);
  });

  testWidgets('reading to the oldest loaded day extends the window earlier', (
    tester,
  ) async {
    final db = await openLedger(tester);
    await mountHome(tester, db, initialDate: oct2, now: at(3, 9));
    // 初始窗口为 9 月 19 日–10 月 2 日；读到最早一天后继续向前装载。
    expect(find.byKey(const ValueKey('day-divider-2026-9-19')), findsOneWidget);
    final scroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(HomeTimelineTab),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    scroll.jumpTo(0);
    await settleNative(tester);
    expect(find.byKey(const ValueKey('day-divider-2026-9-12')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagonal and short drags keep the day, clear swipes change it', (
    tester,
  ) async {
    final db = await openLedger(tester);
    await mountHome(tester, db, initialDate: oct2, now: at(3, 9));
    // 水平手势先赢得识别后再斜向移动，累计为 120 × 100。
    // DragUpdateDetails.delta.dy 为 0，不能用于这个方向判断。
    final diagonal = await tester.startGesture(const Offset(195, 350));
    await diagonal.moveBy(const Offset(80, 0));
    await diagonal.moveBy(const Offset(40, 100));
    await diagonal.up();
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月2日');

    await swipeFeed(tester, -60);
    expect(homeDateTitle(tester), '10月2日');
    final horizontal = await tester.startGesture(const Offset(195, 350));
    await horizontal.moveBy(const Offset(-80, 10));
    await horizontal.moveBy(const Offset(-40, 10));
    await horizontal.up();
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月3日');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed date jump preserves records and position, retry opens target',
    (tester) async {
      final db = await openLedger(tester);
      final base = createDayLedgerLoader(db);
      var fail = false;
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: at(3, 9),
        loader: DayLedgerLoader(
          resolveDate: base.resolveDate,
          readFacts: (context) {
            if (fail) throw StateError('injected read error');
            return base.readFacts(context);
          },
        ),
      );
      final position = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(HomeTimelineTab),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      final offset = position.pixels;
      final dates = shell.feed.loadedDates;
      final context = shell.feed.focusContext;
      fail = true;
      final target = CivilDate(year: 2026, month: 8, day: 1);
      await shell.openDate(target);
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月2日');
      expect(coverageText(tester, '已交代'), '1 小时');
      expect(find.text('十月二日活动'), findsOneWidget);
      expect(shell.feed.loadedDates, dates);
      expect(shell.feed.focusContext, same(context));
      expect(position.pixels, closeTo(offset, 1));
      expect(find.text('账本刷新失败，当前仍显示上一次读取结果。'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('重试读取'));
      await settleNative(tester);
      expect(homeDateTitle(tester), '8月1日');
      expect(dayDivider(target), findsOneWidget);
      expect(shell.feed.refreshFailed, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'midnight rebuild and failed refresh still follow today on retry',
    (tester) async {
      final db = await openLedger(tester);
      final base = createDayLedgerLoader(db);
      var clock = at(2, 23, 59);
      var fail = false;
      final shell = await mountHome(
        tester,
        db,
        initialDate: oct2,
        now: clock,
        changingClock: () => clock,
        loader: DayLedgerLoader(
          resolveDate: base.resolveDate,
          readFacts: (context) {
            if (fail) throw StateError('injected read error');
            return base.readFacts(context);
          },
        ),
      );
      clock = at(3, 0, 1);
      tester.element(find.byType(HomeShell)).markNeedsBuild();
      await tester.pump();
      fail = true;
      await shell.refresh();
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月2日');
      expect(find.text('十月二日活动'), findsOneWidget);
      fail = false;
      await shell.refresh();
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月3日');
      expect(coverageText(tester, '尚未记录'), '1 分钟');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('historical reading stays on its day after midnight refresh', (
    tester,
  ) async {
    final db = await openLedger(tester);
    var clock = at(2, 23, 59);
    final shell = await mountHome(
      tester,
      db,
      initialDate: oct1,
      now: clock,
      changingClock: () => clock,
    );
    clock = at(3, 0, 1);
    await shell.refresh();
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月1日');
    expect(coverageText(tester, '已交代'), '8 小时 20 分钟');
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid buttons and swipes advance from the pending target', (
    tester,
  ) async {
    final db = await openLedger(tester);
    final base = createDayLedgerLoader(db);
    var block = false;
    final gate = Completer<void>();
    final shell = await mountHome(
      tester,
      db,
      initialDate: oct2,
      now: at(5, 12),
      loader: DayLedgerLoader(
        resolveDate: base.resolveDate,
        readFacts: (context) async {
          if (block) await gate.future;
          return base.readFacts(context);
        },
      ),
    );
    block = true;
    await tester.tap(find.byKey(const ValueKey('home-next-day')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-next-day')));
    await tester.pump();
    await swipeFeed(tester, -120);
    final target = CivilDate(year: 2026, month: 10, day: 5);
    expect(shell.feed.navigationDate, target);
    expect(homeDateTitle(tester), '10月2日');
    block = false;
    gate.complete();
    await settleNative(tester);
    expect(homeDateTitle(tester), '10月5日');
    expect(shell.feed.endDate, target);
    expect(tester.takeException(), isNull);
  });
}
