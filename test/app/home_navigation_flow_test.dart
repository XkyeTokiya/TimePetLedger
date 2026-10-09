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
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_summary_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/settings/data/drift_app_preferences_store.dart';

import '../support/home_feed.dart';
import '../support/ledger_date_selection.dart';
import 'review_form_entry_test.dart' show tapText;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final day1 = CivilDate(year: 2026, month: 10, day: 1);
final day2 = CivilDate(year: 2026, month: 10, day: 2);

int at(int day, int hour) =>
    DateTime(2026, 10, day, hour).millisecondsSinceEpoch;

Future<({AppDatabase db, ReviewDraftStore drafts})> openApp(
  WidgetTester tester, {
  required DateTime clock,
  DateTime Function()? changingClock,
}) async {
  final db = (await tester.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  final recording = (await tester.runAsync(
    () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
  ))!;
  final sleepDrafts = (await tester.runAsync(
    () => DriftSleepDraftStore.open(NativeDatabase.memory()),
  ))!;
  final openings = (await tester.runAsync(
    () => DriftSleepOpeningStore.open(NativeDatabase.memory()),
  ))!;
  final drafts = (await tester.runAsync(
    () => DriftReviewDraftStore.open(NativeDatabase.memory()),
  ))!;
  final preferences = (await tester.runAsync(
    () => DriftAppPreferencesStore.open(NativeDatabase.memory()),
  ))!;
  // 内存库在测试进程结束时回收；这里只拆掉 widget 树，避免关闭未使用的
  // 草稿连接在 fake-async 收尾阶段等待永不发生的续体。
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.runAsync(() async {
    final repo = DriftLedgerRepository(db);
    await repo.createTimeBlock(
      id: id(1),
      startedAt: at(1, 9),
      endedAt: at(1, 10),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月一日的活动',
      now: 1,
    );
    await repo.createTimeBlock(
      id: id(2),
      startedAt: at(2, 8),
      endedAt: at(2, 9),
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '十月二日的活动',
      now: 1,
    );
    await DriftReviewRepository(db).create(
      id: id(9),
      date: day1,
      summary: '十月的概述',
      reflection: '十月的反思',
      tomorrowFirstStepText: '十月的第一步',
      now: 2,
    );
  });
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async => db,
      openDrafts: () async => recording,
      openSleepDrafts: () async => sleepDrafts,
      openSleepOpenings: () async => openings,
      openReviewDrafts: () async => drafts,
      openPreferences: () async => preferences,
      now: () => changingClock?.call() ?? clock,
    ),
  );
  await settleNative(tester);
  return (db: db, drafts: drafts);
}

double feedOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(HomeTimelineTab),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .pixels;

void resumeAfterPause(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets(
    'summary and review inherit the home date, manage their own, and the home keeps its reading place',
    (tester) async {
      await openApp(tester, clock: DateTime(2026, 10, 2, 12));

      // 首页当前浏览 10 月 2 日；后退一天到 10 月 1 日并建立阅读位置。
      expect(homeDateTitle(tester), '10月2日');
      await tester.tap(find.byKey(const ValueKey('home-previous-day')));
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月1日');
      // 向下滚动 10 月 1 日自己的记录：阅读位置变化但浏览日期仍是 10 月 1 日。
      await tester.drag(find.byType(HomeTimelineTab), const Offset(0, -60));
      await settleNative(tester);
      final offsetBefore = feedOffset(tester);

      // 摘要继承 10 月 1 日；进入后独立改到 10 月 2 日。
      await tapText(tester, '打开基础摘要');
      expect(find.byType(DaySummaryPage), findsOneWidget);
      expect(find.text('10月1日'), findsWidgets);
      await selectLedgerDate(tester, '2026-10-02');
      await settleNative(tester);
      expect(find.text('10月2日'), findsWidgets);
      // 摘要展示的是当天真实投影：已交代 1 小时、尚未记录 11 小时。
      expect(find.textContaining('已交代 1 小时'), findsOneWidget);
      expect(find.byKey(const ValueKey('summary-day-chart')), findsOneWidget);

      // 返回首页：浏览日期与阅读位置都不被摘要页改变。
      await tester.pageBack();
      await settleNative(tester);
      expect(find.byType(DaySummaryPage), findsNothing);
      expect(homeDateTitle(tester), '10月1日');
      expect((feedOffset(tester) - offsetBefore).abs(), lessThan(1));

      // 复盘同样继承 10 月 1 日，并读出当天已存复盘。
      await tapText(tester, '打开按日复盘');
      expect(find.byType(ReviewContextPage), findsOneWidget);
      expect(find.text('已存复盘日期：2026-10-01'), findsOneWidget);
      expect(find.text('十月的第一步'), findsOneWidget);

      // 页内改到 10 月 2 日后，后台恢复不得改写正在编辑的日期。
      await selectLedgerDate(tester, '2026-10-02');
      await settleNative(tester);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      resumeAfterPause(tester);
      await settleNative(tester);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(find.text('已存复盘日期：2026-10-01'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review input survives within the session, resumes by choice and saves for real',
    (tester) async {
      final app = await openApp(tester, clock: DateTime(2026, 10, 2, 20));

      await tapText(tester, '打开按日复盘');
      expect(find.text('10月2日'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('review-open-form')));
      await settleNative(tester);
      expect(find.byType(ReviewForm), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('review-step')),
        '明天先写五分钟',
      );
      await tester.pump();
      await tester.tap(find.text('再写几句 ＋'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('review-summary')),
        '这一天的概述',
      );
      await tester.pump();

      // Q-012：离开页面保留当前会话输入，不写入正式复盘或旧持久化草稿库。
      final sessionStore = tester
          .widget<ReviewForm>(find.byType(ReviewForm))
          .controller
          .store;
      await tapText(tester, '返回');
      await settleNative(tester);
      final draft = await tester.runAsync(
        () => sessionStore.read(ReviewDraftContext.newEntry(date: day2)),
      );
      expect(draft!.tomorrowFirstStepText, '明天先写五分钟');
      expect(draft.summary, '这一天的概述');
      expect(
        (await tester.runAsync(
          () => app.db.customSelect('SELECT * FROM daily_reviews').get(),
        ))!.length,
        1,
      );

      // 重新进入明确选择继续填写，再用真实保存动作写入 DailyReview。
      await tester.tap(find.byKey(const ValueKey('review-open-form')));
      await settleNative(tester);
      expect(find.text('继续上次填写？'), findsOneWidget);
      await tester.tap(find.text('继续填写'));
      await settleNative(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('review-step')))
            .controller!
            .text,
        '明天先写五分钟',
      );
      await tester.tap(find.text('保存复盘'));
      await settleNative(tester);
      final rows = await tester.runAsync(
        () => app.db.customSelect('SELECT * FROM daily_reviews').get(),
      );
      expect(rows!.length, 2);
      expect(
        rows.map((row) => row.data['review_date']).contains('2026-10-02'),
        isTrue,
      );
      expect(find.text('已有复盘'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming the home refreshes today without changing reading position',
    (tester) async {
      var clock = DateTime(2026, 10, 2, 12);
      await openApp(tester, clock: clock, changingClock: () => clock);
      expect(coverageText(tester, '尚未记录'), '11 小时');
      final offset = feedOffset(tester);
      clock = DateTime(2026, 10, 2, 15);
      resumeAfterPause(tester);
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月2日');
      expect(coverageText(tester, '尚未记录'), '14 小时');
      expect(feedOffset(tester), closeTo(offset, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming after midnight follows today but preserves a historical day',
    (tester) async {
      var clock = DateTime(2026, 10, 2, 23, 59);
      await openApp(tester, clock: clock, changingClock: () => clock);
      clock = DateTime(2026, 10, 3, 0, 1);
      resumeAfterPause(tester);
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月3日');
      expect(coverageText(tester, '尚未记录'), '1 分钟');

      await tester.tap(find.byKey(const ValueKey('home-previous-day')));
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月2日');
      clock = DateTime(2026, 10, 4, 0, 1);
      resumeAfterPause(tester);
      await settleNative(tester);
      expect(homeDateTitle(tester), '10月2日');
      expect(coverageText(tester, '尚未记录'), '23 小时');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resuming across midnight keeps the review editor date and draft',
    (tester) async {
      var clock = DateTime(2026, 10, 2, 23, 59);
      await openApp(tester, clock: clock, changingClock: () => clock);
      await tapText(tester, '打开按日复盘');
      await tester.tap(find.byKey(const ValueKey('review-open-form')));
      await settleNative(tester);
      await tester.enterText(
        find.byKey(const ValueKey('review-step')),
        '先写五分钟',
      );
      await tester.pump();
      final form = tester.widget<ReviewForm>(find.byType(ReviewForm));
      expect(form.controller.date, day2);
      clock = DateTime(2026, 10, 3, 0, 1);
      resumeAfterPause(tester);
      await settleNative(tester);
      expect(form.controller.date, day2);
      expect(form.controller.firstStep, '先写五分钟');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('review-step')))
            .controller!
            .text,
        '先写五分钟',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick-panel entries navigate directly without waiting for the close animation',
    (tester) async {
      await openApp(tester, clock: DateTime(2026, 10, 2, 12));
      await tester.tap(find.byKey(const ValueKey('home-menu')));
      await settleNative(tester);
      await tester.tap(find.byKey(const ValueKey('menu-settings')));
      // 用户要求直接跳转：设置页在快捷区完全收拢前就已出现（过渡重叠），
      // 而不是等待收拢完成、回到首页之后才进入设置。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey('settings-back')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-quick-panel-scrim')),
        findsOneWidget,
      );
      await settleNative(tester);
      expect(find.byKey(const ValueKey('settings-back')), findsOneWidget);
      await tester.pageBack();
      await settleNative(tester);
      expect(find.byKey(const ValueKey('settings-back')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
