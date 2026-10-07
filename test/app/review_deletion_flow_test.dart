import '../support/ledger_date_selection.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import '../features/review/application/review_deletion_test.dart';
import '../features/review/application/review_correction_saver_test.dart'
    show editContext;
import '../features/review/application/review_entry_saver_test.dart'
    show reviewDate;
import 'review_form_entry_test.dart' show settleNative, tapText;
import 'review_submission_flow_test.dart' show enter;
import 'support/checked_sleep_opening.dart';

void main() {
  late DeletionHarness h;
  setUp(() async {
    h = DeletionHarness();
    await h.open();
  });

  Future<void> sized(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  Future<void> unmount(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    var closed = false;
    late Future<void> pending;
    await t.runAsync(() async {
      pending = h.close().then((_) => closed = true);
    });
    for (var i = 0; i < 100 && !closed; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(
      closed,
      true,
      reason: 'Drain native and fake-async continuations before close.',
    );
    await t.runAsync(() => pending);
  }

  Future<void> host(WidgetTester t) async {
    final routes = RouteObserver<ModalRoute<void>>();
    await t.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        home: ReviewContextPage(
          loader: createReviewContextLoader(h.db),
          drafts: h.drafts,
          saver: deletionSaver(h),
          goals: DriftGoalRepository(h.db),
          now: () => h.clock,
          dateOfInstant: (_) => reviewDate,
          initialDate: reviewDate,
          routeObserver: routes,
        ),
      ),
    );
    await settleNative(t);
    await tapText(t, '编辑复盘草稿');
  }

  Future<void> confirm(WidgetTester t) async {
    await tapText(t, '删除复盘');
    await tapText(t, '确认删除');
  }

  testWidgets(
    'actual bootstrap confirms stored source date; cancel retains facts, delete removes only review/edit draft and returns correct day',
    (t) async {
      await sized(t);
      await t.runAsync(() => deletionScene(h));
      final before = (await t.runAsync(() => formalFacts(h)))!;
      h.clock = DateTime(2025, 12, 31, 12).millisecondsSinceEpoch;
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => h.db,
          openDrafts: () async => recording,
          openReviewDrafts: () async => h.drafts,
          openSleepOpenings: () => openCheckedSleepOpening(
            DateTime.fromMillisecondsSinceEpoch(h.clock),
          ),
          now: () => DateTime.fromMillisecondsSinceEpoch(h.clock),
        ),
      );
      await settleNative(t);
      await tapText(t, '打开按日复盘');
      await tapText(t, '编辑复盘草稿');
      await enter(
        t,
        'review-date',
        '2026-01-01',
      ); // Another stored review: still delete source ID.
      await tapText(t, '删除复盘');
      expect(find.textContaining('将删除 2025-12-31 的已存复盘'), findsOneWidget);
      await tapText(t, '取消');
      expect(await t.runAsync(() => formalFacts(h)), before);
      expect(find.byType(ReviewForm), findsOneWidget);
      await confirm(t);
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-context-date')),
          matching: find.textContaining('12月31日'),
        ),
        findsOneWidget,
      );
      final after = (await t.runAsync(() => formalFacts(h)))!;
      for (final table in [
        'goals',
        'time_blocks',
        'sleep_sessions',
        'rhythm_annotations',
      ]) {
        expect(after[table], before[table]);
      }
      expect((after['daily_reviews'] as List<Map<String, dynamic>>).length, 1);
      expect(await t.runAsync(() => h.drafts.read(editContext)), isNull);
      await t.runAsync(() => expectOtherDrafts(h));
      await tapText(t, '填写复盘');
      expect(find.text('删除复盘'), findsNothing);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-step')))
            .controller!
            .text,
        '同日独立新建草稿',
      );
      await tapText(t, '再写几句 ＋');
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('review-reflection')))
            .controller!
            .text,
        '',
      );
      await tapText(t, '返回');
      expect(await t.runAsync(() => h.reviews.findByDate(reviewDate)), isNull);
      await selectLedgerDate(t, '2026-01-01');
      await settleNative(t);
      expect(find.text('其他复盘第一步'), findsOneWidget);
      await unmount(t);
    },
  );

  testWidgets(
    'real formal delete failure keeps raw invalid edit and all facts, retry succeeds without saving corrections',
    (t) async {
      await sized(t);
      await t.runAsync(() => deletionScene(h));
      final before = (await t.runAsync(() => formalFacts(h)))!;
      await host(t);
      await enter(t, 'review-reflection', '  故障时保留原输入\n\n😀  ');
      await enter(t, 'review-date', '未完成');
      await enter(t, 'review-step', '');
      await t.runAsync(() => deleteFault(h, true));
      await confirm(t);
      expect(find.textContaining('删除复盘失败，当前输入仍保留'), findsOneWidget);
      expect(find.text('此复盘已删除。'), findsNothing);
      expect(await t.runAsync(() => formalFacts(h)), before);
      final draft = (await t.runAsync(() => h.drafts.read(editContext)))!;
      expect(draft.dateInput, '未完成');
      expect(draft.date, isNull);
      expect(draft.tomorrowFirstStepText, '');
      expect(draft.reflection, '  故障时保留原输入\n\n😀  ');
      await t.runAsync(() => deleteFault(h, false));
      await confirm(t);
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(h.deletion.deletes, 2);
      expect(h.deletion.updates, 0);
      expect(h.deletion.creates, 0);
      await unmount(t);
    },
  );

  testWidgets(
    'fast delete/dialog callbacks run once; committed cleanup/read failures freeze old edit and retry only finish',
    (t) async {
      await sized(t);
      await t.runAsync(() => deletionScene(h));
      await host(t);
      await t.runAsync(() => h.failClear(true));
      h.failRefresh = true;
      final menu = t.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      void openDialog() => menu.onSelected!('删除复盘');
      openDialog();
      openDialog();
      await settleNative(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      final answer = t
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认删除'))
          .onPressed!;
      answer();
      answer();
      await settleNative(t);
      expect(find.byType(ReviewForm), findsOneWidget);
      expect(find.text('已删除'), findsOneWidget);
      expect(find.textContaining('本地收尾和读回失败'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      expect(find.text('删除复盘'), findsNothing);
      expect(
        t.widget<TextField>(find.byKey(const ValueKey('review-step'))).enabled,
        false,
      );
      await t.tap(find.byTooltip('更多'));
      await settleNative(t);
      expect(
        t
            .widget<PopupMenuItem<String>>(
              find.widgetWithText(PopupMenuItem<String>, '放弃此复盘草稿'),
            )
            .enabled,
        isFalse,
      );
      await t.binding.handlePopRoute();
      await settleNative(t);
      expect(await t.runAsync(() => h.reviews.findByDate(reviewDate)), isNull);
      await t.runAsync(() => h.failClear(false));
      await tapText(t, '重试删除收尾');
      expect(find.textContaining('复盘已删除，但读回失败'), findsOneWidget);
      expect(await t.runAsync(() => h.drafts.read(editContext)), isNull);
      h.failRefresh = false;
      await tapText(t, '重试删除收尾');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      expect(h.deletion.deletes, 1);
      expect(h.deletion.updates, 0);
      expect(h.deletion.creates, 0);
      await t.runAsync(() => expectOtherDrafts(h));
      await unmount(t);
    },
  );

  testWidgets(
    'return after cleanup failure and reopen new-entry form cannot revive residual old-ID edit draft',
    (t) async {
      await sized(t);
      await t.runAsync(() => deletionScene(h));
      await host(t);
      await enter(t, 'review-date', '2024-02-29');
      await t.runAsync(() => h.failClear(true));
      await confirm(t);
      expect(find.textContaining('复盘已删除，但本地收尾失败'), findsOneWidget);
      await tapText(t, '返回复盘读取');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      await unmount(t);
    },
  );
}
