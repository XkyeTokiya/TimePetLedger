import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/review_context.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/application/review_entry_saver.dart';
import 'package:time_pet_ledger/features/review/application/review_session_service.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/data/session_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_repository.dart';
import 'package:time_pet_ledger/features/review/presentation/review_flow_page.dart';

import 'native_flow.dart';

String flowId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

/// 只让指定操作失败的仓库包装；其余调用保持真实 SQLite 行为。
class FlakyReviewRepository implements ReviewRepository {
  FlakyReviewRepository(this.inner);

  final ReviewRepository inner;
  bool failCreate = false;
  bool failUpdate = false;
  bool failDelete = false;
  Completer<void>? createGate;

  @override
  Future<DailyReview?> findByDate(CivilDate date) => inner.findByDate(date);

  @override
  Future<DailyReview> create({
    required String id,
    required CivilDate date,
    required String tomorrowFirstStepText,
    required int now,
    String? summary,
    String? reflection,
    String? tomorrowFirstStepGoalId,
  }) async {
    await createGate?.future;
    if (failCreate) throw StateError('private SQL');
    return inner.create(
      id: id,
      date: date,
      tomorrowFirstStepText: tomorrowFirstStepText,
      now: now,
      summary: summary,
      reflection: reflection,
      tomorrowFirstStepGoalId: tomorrowFirstStepGoalId,
    );
  }

  @override
  Future<DailyReview> update({
    required String id,
    required int now,
    CivilDate? date,
    ({String? value})? summary,
    ({String? value})? reflection,
    String? tomorrowFirstStepText,
    ({String? value})? tomorrowFirstStepGoalId,
  }) {
    if (failUpdate) throw StateError('private SQL');
    return inner.update(
      id: id,
      now: now,
      date: date,
      summary: summary,
      reflection: reflection,
      tomorrowFirstStepText: tomorrowFirstStepText,
      tomorrowFirstStepGoalId: tomorrowFirstStepGoalId,
    );
  }

  @override
  Future<void> delete(String id) {
    if (failDelete) throw StateError('private SQL');
    return inner.delete(id);
  }
}

/// 四步复盘新流程的应用级夹具：真实 SQLite（内存）+ 会话快照存储。
class ReviewFlowHarness {
  ReviewFlowHarness({CivilDate? date})
    : date = date ?? CivilDate(year: 2026, month: 10, day: 11);

  final CivilDate date;
  late AppDatabase db;
  late SessionReviewDraftStore drafts;
  late DriftLedgerRepository repo;
  late DriftGoalRepository goals;
  late ReviewContextLoader loader;
  late ReviewEntrySaver saver;
  late ActivityUnderstandingService understanding;
  late ReviewSessionService session;
  int clock = DateTime(2026, 10, 11, 22, 10).millisecondsSinceEpoch;
  int ids = 0;

  int at(int hour, int minute) => DateTime(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).millisecondsSinceEpoch;

  Future<void> open(
    WidgetTester t, {
    bool seedFact = true,
    ReviewRepository Function(ReviewRepository base)? wrapReviews,
    ReviewContextLoader Function(ReviewContextLoader base)? wrapLoader,
  }) async {
    db = (await t.runAsync(() => AppDatabase.open(NativeDatabase.memory())))!;
    drafts = SessionReviewDraftStore();
    repo = DriftLedgerRepository(db);
    goals = DriftGoalRepository(db);
    final baseLoader = createReviewContextLoader(db);
    loader = wrapLoader?.call(baseLoader) ?? baseLoader;
    final baseReviews = DriftReviewRepository(db);
    saver = ReviewEntrySaver(
      repository: wrapReviews?.call(baseReviews) ?? baseReviews,
      drafts: drafts,
      refresh: loader.load,
      newId: () => flowId(800 + ids++),
      now: () => clock,
    );
    understanding = ActivityUnderstandingService(
      repository: repo,
      now: () => clock,
      newId: () => flowId(900 + ids++),
    );
    session = ReviewSessionService(
      repository: repo,
      saver: saver,
      now: () => clock,
      newId: () => flowId(700 + ids++),
    );
    if (seedFact) {
      await t.runAsync(() async {
        await repo.createTimeBlock(
          id: flowId(11),
          startedAt: at(9, 0),
          endedAt: at(10, 0),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.known,
          title: '写方案',
          now: 1,
        );
      });
    }
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

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

  Future<void> openPage(WidgetTester t) async {
    await t.pumpWidget(page());
    await t.tap(find.byKey(const ValueKey('open-review')));
    await settleNative(t);
  }

  /// 第 1 步 → 第 3 步。
  Future<void> toStepThree(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('review-next')));
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('review-next')));
    await settleNative(t);
  }
}
