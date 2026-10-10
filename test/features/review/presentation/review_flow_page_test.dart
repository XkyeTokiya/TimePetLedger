import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/app/bootstrap/review_submission.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/application/review_session_service.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/data/session_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_flow_page.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 11);
int at(int h, int m) => DateTime(2026, 10, 11, h, m).millisecondsSinceEpoch;
final nowMs = DateTime(2026, 10, 11, 22, 10).millisecondsSinceEpoch;

/// Q-012 会话快照：四步向导的继续 / 重新选择、基线清除与失败体验（R2-14）。
void main() {
  testWidgets('new-entry wizard keeps a session snapshot and offers to '
      'continue on reopen', (t) async {
    final h = await openHarness(t);
    await openPage(t, h);
    expect(find.text('整理今天'), findsOneWidget);

    await t.tap(find.text('下一步'));
    await settle(t);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '明天先写五分钟',
    );
    await t.pump();
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);

    await t.pumpWidget(const SizedBox());
    await flush(t);
    final saved = await t.runAsync(
      () => h.drafts.read(ReviewDraftContext.newEntry(date: date)),
    );
    expect(saved, isNotNull);
    expect(saved!.tomorrowFirstStepText, '明天先写五分钟');
    expect(saved.flowStep, 2);

    await openPage(t, h);
    expect(find.text('继续上次填写？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-recovery-continue')));
    await settle(t);
    expect(find.text('今天关心过的事情'), findsOneWidget);
    await t.tap(find.text('下一步'));
    await settle(t);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('review-next-step')))
          .controller!
          .text,
      '明天先写五分钟',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('restart clears the snapshot and returns to the opening state', (
    t,
  ) async {
    final h = await openHarness(t);
    await openPage(t, h);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '临时第一步');
    await t.pump();
    await t.pumpWidget(const SizedBox());
    await flush(t);

    await openPage(t, h);
    expect(find.text('继续上次填写？'), findsOneWidget);
    await t.tap(find.text('重新填写'));
    await settle(t);
    expect(find.text('整理今天'), findsOneWidget);
    expect(
      await t.runAsync(
        () => h.drafts.read(ReviewDraftContext.newEntry(date: date)),
      ),
      isNull,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('returning to the baseline clears the snapshot', (t) async {
    final h = await openHarness(t);
    await openPage(t, h);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), 'x');
    await t.pump();
    await settle(t);
    expect(
      await t.runAsync(
        () => h.drafts.read(ReviewDraftContext.newEntry(date: date)),
      ),
      isNotNull,
    );

    await t.enterText(find.byKey(const ValueKey('review-next-step')), '');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    expect(find.text('整理今天'), findsOneWidget);
    expect(
      await t.runAsync(
        () => h.drafts.read(ReviewDraftContext.newEntry(date: date)),
      ),
      isNull,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('reflow offers to continue modifying an unfinished session', (
    t,
  ) async {
    final h = await openHarness(t);
    await t.runAsync(
      () => h.session.complete(
        date: date,
        original: null,
        nextStep: '原来的下一步',
        nextStepGoalId: null,
      ),
    );
    await openPage(t, h);
    expect(find.text('今天 · 已回顾'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settle(t);
    expect(find.text('整理今天'), findsOneWidget);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.enterText(find.byKey(const ValueKey('review-next-step')), '改后的第一步');
    await t.pump();
    await t.pumpWidget(const SizedBox());
    await flush(t);

    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(date),
    );
    final saved = await t.runAsync(
      () => h.drafts.read(ReviewDraftContext.edit(reviewId: review!.id)),
    );
    expect(saved, isNotNull);
    expect(saved!.tomorrowFirstStepText, '改后的第一步');
    expect(saved.flowStep, 3);

    await openPage(t, h);
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settle(t);
    expect(find.text('继续上次修改？'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-recovery-continue')));
    await settle(t);
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('review-next-step')))
          .controller!
          .text,
      '改后的第一步',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('committed residuals are finished without offering recovery', (
    t,
  ) async {
    final h = await openHarness(t);
    await t.runAsync(
      () => h.session.complete(
        date: date,
        original: null,
        nextStep: '已经保存',
        nextStepGoalId: null,
      ),
    );
    await t.runAsync(
      () => h.drafts.save(
        ReviewDraft(
          context: ReviewDraftContext.newEntry(date: date),
          date: date,
          tomorrowFirstStepText: '已经保存',
          flowStep: 2,
        ),
      ),
    );

    await openPage(t, h);
    expect(find.text('今天 · 已回顾'), findsOneWidget);
    expect(find.text('继续上次填写？'), findsNothing);
    expect(
      await t.runAsync(
        () => h.drafts.read(ReviewDraftContext.newEntry(date: date)),
      ),
      isNull,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('matching edit residual is cleared when reflow opens', (t) async {
    final h = await openHarness(t);
    await t.runAsync(
      () => h.session.complete(
        date: date,
        original: null,
        nextStep: '原来的下一步',
        nextStepGoalId: null,
      ),
    );
    final review = await t.runAsync(
      () => DriftReviewRepository(h.db).findByDate(date),
    );
    final reviewId = review!.id;
    await t.runAsync(
      () => h.drafts.save(
        ReviewDraft(
          context: ReviewDraftContext.edit(reviewId: reviewId),
          date: null,
          tomorrowFirstStepText: '原来的下一步',
          flowStep: 3,
        ),
      ),
    );

    await openPage(t, h);
    await t.tap(find.byKey(const ValueKey('review-menu')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('review-reflow')));
    await settle(t);
    expect(find.text('继续上次修改？'), findsNothing);
    expect(find.text('整理今天'), findsOneWidget);
    expect(
      await t.runAsync(
        () => h.drafts.read(ReviewDraftContext.edit(reviewId: reviewId)),
      ),
      isNull,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('snapshot sync failure asks before leaving', (t) async {
    final flaky = FlakyStore(SessionReviewDraftStore());
    final h = await openHarness(t, drafts: flaky);
    await openPage(t, h);
    await t.tap(find.text('下一步'));
    await settle(t);
    await t.tap(find.text('下一步'));
    await settle(t);

    flaky.failSave = true;
    await t.enterText(
      find.byKey(const ValueKey('review-next-step')),
      '未保留的第一步',
    );
    await t.pump();
    await settle(t);
    expect(find.text('本次填写暂时无法保留，输入仍在此页，请重试。'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    expect(find.text('整理今天'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    expect(find.text('本次填写暂时无法保留'), findsOneWidget);
    await t.tap(find.text('继续填写'));
    await settle(t);
    expect(find.byType(ReviewFlowPage), findsOneWidget);

    flaky.failSave = false;
    await t.tap(find.byKey(const ValueKey('review-flow-retry')));
    await settle(t);
    expect(find.text('本次填写暂时无法保留，输入仍在此页，请重试。'), findsNothing);

    await t.tap(find.byKey(const ValueKey('review-back')));
    await settle(t);
    expect(find.byType(ReviewFlowPage), findsNothing);
    expect(t.takeException(), isNull);
  });
}

class Harness {
  Harness(this.db, this.session, this.drafts);

  final AppDatabase db;
  final ReviewSessionService session;
  final ReviewDraftStore drafts;

  Widget page() => MaterialApp(
    home: Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('open-review'),
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => reviewPage())),
          child: const Text('打开复盘'),
        ),
      ),
    ),
  );

  Widget reviewPage() => ReviewFlowPage(
    loader: loader,
    session: session,
    understanding: understanding,
    drafts: drafts,
    goals: goals,
    initialDate: date,
  );

  late final ReviewContextLoader loader;
  late final ActivityUnderstandingService understanding;
  late final DriftGoalRepository goals;
}

Future<void> openPage(WidgetTester t, Harness h) async {
  await t.pumpWidget(h.page());
  await t.tap(find.byKey(const ValueKey('open-review')));
  await settle(t);
}

Future<Harness> openHarness(WidgetTester t, {ReviewDraftStore? drafts}) async {
  final db = (await t.runAsync(
    () => AppDatabase.open(NativeDatabase.memory()),
  ))!;
  final store = drafts ?? SessionReviewDraftStore();
  final repo = DriftLedgerRepository(db);
  final loader = createReviewContextLoader(db);
  final saver = createReviewEntrySaver(
    database: db,
    drafts: store,
    loader: loader,
    clock: () => DateTime(2026, 10, 11, 22, 10),
  );
  var nextId = 100;
  final harness = Harness(
    db,
    ReviewSessionService(
      repository: repo,
      saver: saver,
      now: () => nowMs,
      newId: () => id(nextId++),
    ),
    store,
  );
  harness.loader = loader;
  harness.goals = DriftGoalRepository(db);
  harness.understanding = ActivityUnderstandingService(
    repository: repo,
    now: () => nowMs,
    newId: () => id(nextId++),
  );
  await t.runAsync(() async {
    await repo.createTimeBlock(
      id: id(11),
      startedAt: at(9, 0),
      endedAt: at(10, 0),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      knowledgeState: BlockKnowledgeState.known,
      title: '写方案',
      now: 1,
    );
  });
  return harness;
}

class FlakyStore implements ReviewDraftStore {
  FlakyStore(this.inner);

  final ReviewDraftStore inner;
  bool failSave = false;

  @override
  Future<ReviewDraft?> read(ReviewDraftContext context) => inner.read(context);

  @override
  Future<void> save(ReviewDraft draft) async {
    if (failSave) {
      throw ReviewDraftStorageException(
        ReviewDraftOperation.save,
        StateError('offline'),
      );
    }
    await inner.save(draft);
  }

  @override
  Future<void> clear(ReviewDraftContext context) => inner.clear(context);
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  await t.pumpAndSettle();
}

Future<void> flush(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await t.pump();
}
