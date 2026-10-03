import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';

import '../features/review/data/review_draft_store_test.dart' show mutate;
import 'review_form_entry_test.dart' show settleNative;
import 'support/checked_sleep_opening.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final sourceDay = CivilDate(year: 2024, month: 2, day: 28);
final leapDay = CivilDate(year: 2024, month: 2, day: 29);
final marchDay = CivilDate(year: 2024, month: 3, day: 1);
final entry = ReviewDraftContext.newEntry(date: sourceDay);
final sibling = ReviewDraftContext.newEntry(
  date: CivilDate(year: 2025, month: 12, day: 31),
);

/// Audit real writes across database reopen; faults affect only a chosen window.
class ReviewAudit extends QueryInterceptor {
  int creates = 0;
  int updates = 0;
  int deletes = 0;
  int? failWindowStart;
  int? failWindowAfterInsert;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failWindowStart != null &&
        sql.contains('FROM time_blocks ') &&
        args.length == 2 &&
        args[1] == failWindowStart) {
      throw StateError('private fact read fault');
    }
    return executor.runSelect(sql, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(sql, args);
    if (sql.contains('daily_reviews')) {
      creates++;
      failWindowStart = failWindowAfterInsert;
    }
    return result;
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(sql, args);
    if (sql.contains('daily_reviews')) updates++;
    return result;
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runDelete(sql, args);
    if (sql.contains('daily_reviews')) deletes++;
    return result;
  }
}

class ClosureApp {
  ClosureApp(this.dir);
  final Directory dir;
  final audit = ReviewAudit();
  late AppDatabase db;
  late DriftRecordingDraftStore recording;
  late DriftReviewDraftStore drafts;
  late DriftSleepOpeningStore openings;
  DateTime clock = DateTime(2026, 10, 3, 12);
  File get factsFile => File('${dir.path}/facts.sqlite');
  File get draftFile => File('${dir.path}/review.sqlite');
  DriftReviewRepository get reviews => DriftReviewRepository(db);
  DriftGoalRepository get goals => DriftGoalRepository(db);

  Future<void> connect() async {
    db = await AppDatabase.open(NativeDatabase(factsFile).interceptWith(audit));
    recording = await DriftRecordingDraftStore.open(
      NativeDatabase(File('${dir.path}/recording.sqlite')),
    );
    drafts = await DriftReviewDraftStore.open(NativeDatabase(draftFile));
    openings = await openCheckedSleepOpening(clock);
  }

  static Future<ClosureApp> open(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = (await t.runAsync(() async {
      final app = ClosureApp(
        await Directory.systemTemp.createTemp('review_closure_'),
      );
      await app.connect();
      return app;
    }))!;
    addTearDown(() async {
      await app.unmount(t);
      await t.runAsync(() => app.dir.delete(recursive: true));
    });
    return app;
  }

  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => recording,
        openReviewDrafts: () async => drafts,
        openSleepOpenings: () async => openings,
        now: () => clock,
      ),
    );
    await settleNative(t);
  }

  Future<void> unmount(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    var closed = false;
    late Future<void> pending;
    await t.runAsync(() async {
      pending =
          Future.wait([
            db.close(),
            recording.close(),
            drafts.close(),
            openings.close(),
          ]).then((_) {
            closed = true;
          });
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
      reason: 'Drain real and fake-async close continuations.',
    );
    await t.runAsync(() => pending);
  }

  Future<void> reopen(WidgetTester t) async {
    await unmount(t);
    await t.runAsync(connect);
    await mount(t);
  }

  Future<Map<String, List<Map<String, Object?>>>> snapshot() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  };

  Future<void> seed() async {
    await goals.create(id: id(1), name: '原事实目标', now: 1);
    await goals.create(id: id(2), name: '另一个下一步目标', now: 1);
    final ledger = DriftLedgerRepository(db);
    await ledger.createSleepSession(
      id: id(3),
      startedAt: DateTime(2024, 2, 27, 23).millisecondsSinceEpoch,
      endedAt: DateTime(2024, 2, 28, 7).millisecondsSinceEpoch,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      now: 2,
    );
    await ledger.createTimeBlock(
      id: id(4),
      startedAt: DateTime(2024, 2, 28, 9).millisecondsSinceEpoch,
      endedAt: DateTime(2024, 2, 28, 10).millisecondsSinceEpoch,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '当天事实',
      goalId: id(1),
      now: 3,
      annotation: AddAnnotation(
        id: id(5),
        state: RhythmState.progress,
        continuationHint: '原事实接续点',
      ),
    );
    await ledger.createTimeBlock(
      id: id(6),
      startedAt: DateTime(2024, 2, 28, 10).millisecondsSinceEpoch,
      endedAt: DateTime(2024, 2, 28, 10, 30).millisecondsSinceEpoch,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.unknown,
      now: 4,
    );
    await drafts.save(
      ReviewDraft(
        context: sibling,
        date: null,
        dateInput: '未完成',
        tomorrowFirstStepText: '其他日期的独立输入',
      ),
    );
  }

  Future<void> clearFault(bool enabled) => mutate(
    draftFile,
    (db) => db.customStatement(
      enabled
          ? "CREATE TRIGGER fail_clear AFTER DELETE ON review_drafts BEGIN SELECT RAISE(FAIL,'private clear fault'); END"
          : 'DROP TRIGGER fail_clear',
    ),
  );

  Future<void> createFault(bool enabled) => db.customStatement(
    enabled
        ? "CREATE TRIGGER fail_create AFTER INSERT ON daily_reviews BEGIN SELECT RAISE(FAIL,'private write fault'); END"
        : 'DROP TRIGGER fail_create',
  );

  Future<void> peer(Future<void> Function(DriftReviewRepository) action) async {
    final peer = await AppDatabase.open(
      NativeDatabase(factsFile).interceptWith(audit),
    );
    try {
      await action(DriftReviewRepository(peer));
    } finally {
      await peer.close();
    }
  }
}

Future<void> show(WidgetTester t, Finder finder) async {
  t.testTextInput.hide();
  await settleNative(t);
  if (finder.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(t.element(finder.first), alignment: .5);
  await settleNative(t);
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await show(t, finder);
  await t.tap(finder.first);
  await settleNative(t);
}

Future<void> text(WidgetTester t, String value) => tap(t, find.text(value));
Future<void> enter(WidgetTester t, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await show(t, finder);
  await t.enterText(finder, value);
  await settleNative(t);
}

Future<void> homeDate(WidgetTester t, String value) async {
  final finder = find.widgetWithText(TextField, '查看日期');
  await show(t, finder);
  await t.enterText(finder, value);
  await settleNative(t);
}

Future<void> back(WidgetTester t) async {
  await t.pageBack();
  await settleNative(t);
}

Future<void> goal(WidgetTester t, int n) async {
  await text(t, '选择下一步目标');
  await tap(t, find.byKey(ValueKey('review-goal-option-${id(n)}')));
}

Future<void> source(WidgetTester t) async {
  await homeDate(t, '2024-02-28');
  await text(t, '打开基础摘要');
  await text(t, '打开此日复盘');
  await text(t, '填写复盘');
}

String input(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
void unchangedFacts(
  Map<String, List<Map<String, Object?>>> after,
  Map<String, List<Map<String, Object?>>> before,
) {
  for (final table in ['time_blocks', 'sleep_sessions', 'rhythm_annotations']) {
    expect(
      after[table],
      before[table],
      reason: '$table remains a separate fact source.',
    );
  }
}

void main() {
  testWidgets(
    'real mixed summary to raw draft, Unicode limit and changed Goal failure, full-field create/edit/move/delete preserve facts',
    (t) async {
      final app = await ClosureApp.open(t);
      await t.runAsync(app.seed);
      final original = (await t.runAsync(app.snapshot))!;
      await app.mount(t);
      await source(t);
      expect(find.text('其中未知：30 分钟'), findsOneWidget);
      expect(find.text('尚未记录：930 分钟'), findsOneWidget);
      expect(input(t, 'review-step'), '');
      final rawSummary = '  概述\n\n内部   空格😀  ';
      final rawReflection = '  用户反思\n保留段落  ';
      final over = '  ${'😀' * 2001}  ';
      await enter(t, 'review-summary', rawSummary);
      await enter(t, 'review-reflection', rawReflection);
      await enter(t, 'review-step', over);
      await goal(t, 2);
      await text(t, '保存复盘');
      expect(find.textContaining('请检查复盘日期与文字'), findsOneWidget);
      expect(app.audit.creates, 0);
      await text(t, '保留草稿并返回');
      expect(await t.runAsync(app.snapshot), original);
      await app.reopen(t);
      await source(t);
      expect(input(t, 'review-summary'), rawSummary);
      expect(input(t, 'review-reflection'), rawReflection);
      expect(input(t, 'review-step'), over);
      final limit = '😀' * 2000;
      await t.runAsync(
        () => mutate(
          app.draftFile,
          (db) => db.customStatement(
            "CREATE TRIGGER fail_draft_write AFTER UPDATE ON review_drafts BEGIN SELECT RAISE(FAIL,'private draft fault'); END",
          ),
        ),
      );
      await enter(t, 'review-step', '  $limit  ');
      await text(t, '保存复盘');
      expect(find.textContaining('草稿尚未保留成功'), findsOneWidget);
      expect(app.audit.creates, 0);
      expect(
        (await t.runAsync(() => app.drafts.read(entry)))!.tomorrowFirstStepText,
        over,
      );
      expect(input(t, 'review-step'), '  $limit  ');
      await t.runAsync(
        () => mutate(
          app.draftFile,
          (db) => db.customStatement('DROP TRIGGER fail_draft_write'),
        ),
      );
      await text(t, '重试保存草稿');
      await t.runAsync(() => app.goals.archive(id: id(2), now: 5));
      await text(t, '保存复盘');
      expect(find.textContaining('目标已归档或不存在'), findsOneWidget);
      expect(
        (await t.runAsync(() => app.drafts.read(entry)))!.tomorrowFirstStepText,
        '  $limit  ',
      );
      expect(app.audit.creates, 0);
      final form = t.widget<ReviewForm>(find.byType(ReviewForm)).controller;
      await t.runAsync(form.loadGoals);
      await settleNative(t);
      await goal(t, 1);
      await text(t, '保存复盘');
      expect(find.byType(ReviewForm), findsNothing);
      expect(find.text('已存复盘日期：2024-02-28'), findsOneWidget);
      expect(find.text('下一自然日：2024-02-29'), findsOneWidget);
      final created = (await t.runAsync(
        app.snapshot,
      ))!['daily_reviews']!.single;
      expect(created.keys.toSet(), {
        'id',
        'review_date',
        'summary',
        'reflection',
        'tomorrow_first_step_text',
        'tomorrow_first_step_goal_id',
        'created_at',
        'updated_at',
      });
      expect(created['summary'], rawSummary.trim());
      expect(created['reflection'], rawReflection.trim());
      expect(created['tomorrow_first_step_text'], limit);
      expect(created['tomorrow_first_step_goal_id'], id(1));
      expect(await t.runAsync(() => app.drafts.read(entry)), isNull);
      await t.runAsync(() => app.goals.archive(id: id(1), now: 6));
      await text(t, '刷新复盘上下文');
      expect(find.text('第一步目标：原事实目标（已归档）'), findsOneWidget);
      await text(t, '编辑复盘草稿');
      await enter(t, 'review-date', '2024-03-01');
      await enter(t, 'review-summary', ' \n ');
      await enter(t, 'review-reflection', '  明确更正\n保留内部空格  ');
      await enter(t, 'review-step', '  更正后的下一步  ');
      await text(t, '保存更正');
      expect(find.text('已存复盘日期：2024-03-01'), findsOneWidget);
      expect(find.text('下一自然日：2024-03-02'), findsOneWidget);
      final updated = (await t.runAsync(
        app.snapshot,
      ))!['daily_reviews']!.single;
      expect(updated['id'], created['id']);
      expect(updated['created_at'], created['created_at']);
      expect(updated['summary'], isNull);
      expect(updated['reflection'], '明确更正\n保留内部空格');
      expect(updated['tomorrow_first_step_goal_id'], id(1));
      expect(await t.runAsync(() => app.reviews.findByDate(sourceDay)), isNull);
      await back(t);
      await back(t);
      await homeDate(t, '2024-03-01');
      await text(t, '打开日账本');
      await text(t, '打开此日复盘');
      expect(find.text('更正后的下一步'), findsOneWidget);
      await text(t, '编辑复盘草稿');
      await text(t, '删除复盘');
      await text(t, '确认删除');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      final after = (await t.runAsync(app.snapshot))!;
      expect(after['daily_reviews'], isEmpty);
      unchangedFacts(after, original);
      expect(
        (await t.runAsync(() => app.drafts.read(sibling)))!.dateInput,
        '未完成',
      );
      expect(
        await t.runAsync(
          () => app.drafts.read(
            ReviewDraftContext.edit(reviewId: created['id']! as String),
          ),
        ),
        isNull,
      );
      expect(
        (app.audit.creates, app.audit.updates, app.audit.deletes),
        (1, 1, 1),
      );
    },
  );

  testWidgets(
    'committed leap-day review with simultaneous cleanup/read faults recovers through full bootstrap reopen and retries only finish before edit/delete',
    (t) async {
      final app = await ClosureApp.open(t);
      await t.runAsync(app.seed);
      final original = (await t.runAsync(app.snapshot))!;
      await app.mount(t);
      await source(t);
      await enter(t, 'review-date', '2024-02-29');
      await enter(t, 'review-summary', '  已提交概述  ');
      await enter(t, 'review-reflection', '  已提交反思\n\n段落  ');
      await enter(t, 'review-step', '  已提交第一步😀  ');
      await goal(t, 1);
      await t.runAsync(() => app.clearFault(true));
      app.audit.failWindowAfterInsert = DateTime(
        2024,
        2,
        29,
      ).millisecondsSinceEpoch;
      await text(t, '保存复盘');
      expect(find.textContaining('草稿清理和读回失败'), findsOneWidget);
      expect(find.text('保存复盘'), findsNothing);
      final committed = (await t.runAsync(app.snapshot))!;
      expect(committed['daily_reviews']!.length, 1);
      expect((await t.runAsync(() => app.drafts.read(entry)))!.date, leapDay);
      await text(t, '重试复盘收尾');
      expect((app.audit.creates, app.audit.updates), (1, 0));
      await text(t, '返回复盘读取');
      expect(find.text('复盘上下文读取失败，请重试。'), findsOneWidget);
      await t.runAsync(() => app.goals.archive(id: id(1), now: 5));
      app.clock = DateTime(2026, 10, 4, 0, 5);
      await app.reopen(t);
      await source(t);
      expect(find.textContaining('草稿清理和读回失败'), findsOneWidget);
      expect(input(t, 'review-date'), '2024-02-29');
      expect(find.text('下一自然日：2024-03-01'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byKey(const ValueKey('review-step'))).enabled,
        false,
      );
      expect(find.text('保存复盘'), findsNothing);
      expect((app.audit.creates, app.audit.updates), (1, 0));
      expect(
        (await t.runAsync(app.snapshot))!['daily_reviews'],
        committed['daily_reviews'],
      );
      await t.runAsync(() => app.clearFault(false));
      await text(t, '重试复盘收尾');
      expect(find.textContaining('复盘已保存，但读回失败'), findsOneWidget);
      expect(await t.runAsync(() => app.drafts.read(entry)), isNull);
      app.audit.failWindowStart = null;
      await text(t, '重试复盘收尾');
      expect(find.text('已存复盘日期：2024-02-29'), findsOneWidget);
      expect(find.text('已提交第一步😀'), findsOneWidget);
      expect(find.text('第一步目标：原事实目标（已归档）'), findsOneWidget);
      expect(
        (await t.runAsync(app.snapshot))!['daily_reviews'],
        committed['daily_reviews'],
      );
      expect((app.audit.creates, app.audit.updates), (1, 0));
      await text(t, '编辑复盘草稿');
      await enter(t, 'review-reflection', '恢复后明确更正');
      await text(t, '保存更正');
      await text(t, '编辑复盘草稿');
      await text(t, '删除复盘');
      await text(t, '确认删除');
      await app.reopen(t);
      await homeDate(t, '2024-02-29');
      await text(t, '打开日账本');
      await text(t, '打开此日复盘');
      expect(find.text('这一天尚无复盘。'), findsOneWidget);
      final after = (await t.runAsync(app.snapshot))!;
      unchangedFacts(after, original);
      expect(after['daily_reviews'], isEmpty);
      expect(
        (app.audit.creates, app.audit.updates, app.audit.deletes),
        (1, 1, 1),
      );
      expect(
        (await t.runAsync(() => app.drafts.read(sibling)))!
            .tomorrowFirstStepText,
        '其他日期的独立输入',
      );
    },
  );

  testWidgets(
    'independent SQLite writer wins selected date, restored failed draft stays distinct; write retry and deleted stale source never retarget a replacement',
    (t) async {
      final app = await ClosureApp.open(t);
      await t.runAsync(app.seed);
      final facts = (await t.runAsync(app.snapshot))!;
      await app.mount(t);
      await source(t);
      await enter(t, 'review-date', '2024-02-29');
      await enter(t, 'review-summary', '  保留的新建概述  ');
      await enter(t, 'review-reflection', '  保留的新建反思\n内部   格式  ');
      await enter(t, 'review-step', '  和竞争者不同的下一步  ');
      await t.runAsync(
        () => app.peer((repo) async {
          await repo.create(
            id: id(90),
            date: leapDay,
            tomorrowFirstStepText: '竞争者第一步',
            now: 10,
          );
        }),
      );
      final occupied = (await t.runAsync(app.snapshot))!;
      await text(t, '保存复盘');
      expect(find.textContaining('该日期已有复盘，未覆盖'), findsOneWidget);
      expect(await t.runAsync(app.snapshot), occupied);
      await text(t, '保留草稿并返回');
      await app.reopen(t);
      await source(t);
      expect(input(t, 'review-step'), '  和竞争者不同的下一步  ');
      expect(find.text('保存复盘'), findsOneWidget);
      expect(find.textContaining('此复盘已正式保存'), findsNothing);
      await text(t, '保存复盘');
      expect(find.textContaining('该日期已有复盘，未覆盖'), findsOneWidget);
      await enter(t, 'review-date', '2024-03-01');
      await t.runAsync(() => app.createFault(true));
      await text(t, '保存复盘');
      expect(find.textContaining('正式保存失败，输入和草稿已保留'), findsOneWidget);
      expect(find.textContaining('private write'), findsNothing);
      expect(await t.runAsync(app.snapshot), occupied);
      expect((await t.runAsync(() => app.drafts.read(entry)))!.date, marchDay);
      await t.runAsync(() => app.createFault(false));
      await text(t, '保存复盘');
      expect(find.text('已存复盘日期：2024-03-01'), findsOneWidget);
      final created = (await t.runAsync(
        () => app.reviews.findByDate(marchDay),
      ))!;
      await text(t, '编辑复盘草稿');
      await enter(t, 'review-reflection', '  过期编辑仍保留的输入  ');
      await t.runAsync(
        () => app.peer((repo) async {
          await repo.delete(created.id);
          await repo.create(
            id: id(91),
            date: marchDay,
            tomorrowFirstStepText: '替代复盘的步骤',
            now: 20,
          );
        }),
      );
      final replaced = (await t.runAsync(app.snapshot))!;
      await text(t, '保存更正');
      expect(find.textContaining('原复盘已不存在'), findsOneWidget);
      expect(await t.runAsync(app.snapshot), replaced);
      final staleKey = ReviewDraftContext.edit(reviewId: created.id);
      expect(
        (await t.runAsync(() => app.drafts.read(staleKey)))!.reflection,
        '  过期编辑仍保留的输入  ',
      );
      await text(t, '保留草稿并返回');
      expect(find.text('替代复盘的步骤'), findsOneWidget);
      await app.reopen(t);
      await homeDate(t, '2024-03-01');
      await text(t, '打开日账本');
      await text(t, '打开此日复盘');
      await text(t, '编辑复盘草稿');
      expect(input(t, 'review-step'), '替代复盘的步骤');
      expect(input(t, 'review-reflection'), '');
      expect(
        t
            .widget<ReviewForm>(find.byType(ReviewForm))
            .controller
            .context
            .reviewId,
        id(91),
      );
      expect(
        (await t.runAsync(() => app.reviews.findByDate(leapDay)))!.id,
        id(90),
      );
      expect(
        (await t.runAsync(() => app.reviews.findByDate(marchDay)))!.id,
        id(91),
      );
      expect(await t.runAsync(app.snapshot), replaced);
      unchangedFacts(replaced, facts);
      expect(
        (await t.runAsync(() => app.drafts.read(staleKey)))!.reflection,
        '  过期编辑仍保留的输入  ',
      );
      expect(
        (app.audit.creates, app.audit.updates, app.audit.deletes),
        (3, 0, 1),
      );
    },
  );
}
