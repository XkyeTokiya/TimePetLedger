import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 1);
final start = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 1, 11).millisecondsSinceEpoch;

class GoalQueries extends QueryInterceptor {
  bool fail = false;
  Completer<void>? gate;
  int blockWrites = 0;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (sql.contains('time_blocks')) blockWrites++;
    return executor.runInsert(sql, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (sql.contains('time_blocks')) blockWrites++;
    return executor.runUpdate(sql, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    if (sql.contains('FROM goals WHERE status')) {
      await gate?.future;
      if (fail) throw StateError('test Goal read failure');
    }
    return executor.runSelect(sql, args);
  }
}

class DraftQueries extends QueryInterceptor {
  bool failClear = true;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failClear && sql.startsWith('DELETE FROM recording_drafts')) {
      throw StateError('test cleanup failure');
    }
    return executor.runCustom(sql, args);
  }
}

class Harness {
  Harness(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  late final goals = DriftGoalRepository(db);
  late final ledger = DriftLedgerRepository(db);
  late final loader = RecordingLedgerLoader(
    repository: ledger,
    resolveDate: resolveDeviceRecordingDate,
  );
  late final saver = RecordingEntrySaver(
    repository: ledger,
    drafts: drafts,
    refresh: loader.load,
    newId: () => id(9),
    now: () => end + 1,
  );
  late final editor = RecordingEntryEditor(
    repository: ledger,
    drafts: drafts,
    saver: saver,
  );

  Future<void> source({String? goalId}) async {
    await ledger.createTimeBlock(
      id: id(8),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '原活动',
      goalId: goalId,
      categoryId: '原分类',
      note: '原备注',
      annotation: AddAnnotation(
        id: id(7),
        state: RhythmState.stuck,
        continuationHint: '接续点',
      ),
      now: 1,
    );
  }

  RecordingFormController controller(RecordingDraftContext context) =>
      RecordingFormController(
        context: context,
        store: drafts,
        goals: goals,
        entrySaver: saver,
        entryEditor: editor,
        loadSuggestion: () async => DirectTimeSuggestion(
          RecordingTimeInput(startedAt: start, endedAt: end),
        ),
      );

  Widget app(RecordingDraftContext context) => MaterialApp(
    home: Builder(
      builder: (outer) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            outer,
            MaterialPageRoute<void>(
              builder: (_) => RecordingForm(
                context: context,
                store: drafts,
                goals: goals,
                entrySaver: saver,
                entryEditor: editor,
                loadSuggestion: () async => DirectTimeSuggestion(
                  RecordingTimeInput(startedAt: start, endedAt: end),
                ),
              ),
            ),
          ),
          child: const Text('打开'),
        ),
      ),
    ),
  );
}

Future<Harness> open(WidgetTester tester) async {
  final h = (await tester.runAsync(
    () async => Harness(
      await AppDatabase.open(NativeDatabase.memory()),
      await DriftRecordingDraftStore.open(NativeDatabase.memory()),
    ),
  ))!;
  addTearDown(() async {
    await h.drafts.close();
    await h.db.close();
  });
  return h;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> textTap(WidgetTester tester, String text) async {
  if (['保留草稿并返回', '放弃草稿'].contains(text) &&
      find.text(text).evaluate().isEmpty) {
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
  }
  await tap(tester, find.text(text));
  if (text == '打开' &&
      find
          .byKey(const ValueKey('recording-goal-toggle'))
          .evaluate()
          .isNotEmpty &&
      find.text('选择目标').evaluate().isEmpty) {
    await tap(tester, find.byKey(const ValueKey('recording-goal-toggle')));
  }
}

Future<void> choose(WidgetTester tester, int n) async {
  await textTap(tester, '选择目标');
  await tap(tester, find.byKey(ValueKey('goal-option-${id(n)}')));
}

void main() {
  for (final editing in [false, true]) {
    test(
      '${editing ? 'clear existing' : 'create selected'} committed Goal draft recovers after cleanup failure without a second formal write',
      () async {
        final queries = GoalQueries();
        final draftQueries = DraftQueries();
        final h = Harness(
          await AppDatabase.open(
            NativeDatabase.memory().interceptWith(queries),
          ),
          await DriftRecordingDraftStore.open(
            NativeDatabase.memory().interceptWith(draftQueries),
          ),
        );
        addTearDown(() async {
          await h.drafts.close();
          await h.db.close();
        });
        await (() async {
          await h.goals.create(id: id(1), name: '提交目标', now: 1);
          if (editing) await h.source(goalId: id(1));
        })();
        final context = editing
            ? RecordingDraftContext.edit(date: date, timeBlockId: id(8))
            : RecordingDraftContext.newEntry(date: date);
        var c = h.controller(context);
        await c.initialize();
        if (editing) {
          c.clearGoal();
        } else {
          c.setKnowledge(BlockKnowledgeState.unknown);
          c.selectGoal(id(1));
        }
        await c.submit();
        expect(c.committed, isNotNull);
        expect(c.committed!.draftCleared, isFalse);
        final writes = queries.blockWrites;
        c.dispose();
        c = h.controller(context);
        await c.initialize();
        expect(c.committed, isNotNull);
        expect(c.editable, isFalse);
        expect(c.committed!.timeBlock.goalId, editing ? isNull : id(1));
        draftQueries.failClear = false;
        await c.retryFinish();
        expect(c.committed!.complete, isTrue);
        expect(queries.blockWrites, writes);
        expect(await h.drafts.read(context), isNull);
        c.dispose();
      },
    );
  }

  testWidgets(
    'Goal read failure stays distinct from empty and retries without replacing activity or association',
    (tester) async {
      final queries = GoalQueries();
      final h = (await tester.runAsync(
        () async => Harness(
          await AppDatabase.open(
            NativeDatabase.memory().interceptWith(queries),
          ),
          await DriftRecordingDraftStore.open(NativeDatabase.memory()),
        ),
      ))!;
      addTearDown(() async {
        await h.drafts.close();
        await h.db.close();
      });
      await tester.runAsync(
        () => h.goals.create(id: id(1), name: '保留选择', now: 1),
      );
      final context = RecordingDraftContext.newEntry(date: date);
      await tester.pumpWidget(h.app(context));
      await textTap(tester, '打开');
      await tester.enterText(find.byKey(const ValueKey('activity')), '未完成文字');
      await choose(tester, 1);
      queries.fail = true;
      await textTap(tester, '刷新目标');
      expect(find.text('目标读取失败，请重试；当前归属和输入已保留。'), findsOneWidget);
      expect(find.text('暂无可选目标，可直接记录。'), findsNothing);
      expect(
        (await tester.runAsync(() => h.drafts.read(context)))!.goalId,
        id(1),
      );
      queries.fail = false;
      await textTap(tester, '重试读取目标');
      expect(find.text('保留选择'), findsNWidgets(2));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '未完成文字',
      );
      // A delayed read must not restore the selection after an explicit clear.
      queries.gate = Completer<void>();
      await tester.tap(find.text('刷新目标'));
      await tester.pump();
      expect(find.text('正在读取目标…'), findsOneWidget);
      await textTap(tester, '移除目标归属');
      queries.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('未关联目标'), findsOneWidget);
      expect(
        (await tester.runAsync(() => h.drafts.read(context)))!.goalId,
        isNull,
      );
    },
  );

  for (final knowledge in BlockKnowledgeState.values) {
    testWidgets(
      '$knowledge can save without a Goal from the empty active list',
      (tester) async {
        final h = await open(tester);
        await tester.pumpWidget(
          h.app(RecordingDraftContext.newEntry(date: date)),
        );
        await textTap(tester, '打开');
        expect(find.text('暂无可选目标，可直接记录。'), findsOneWidget);
        await textTap(
          tester,
          knowledge == BlockKnowledgeState.known ? '记得做了什么' : '想不起来',
        );
        if (knowledge == BlockKnowledgeState.known) {
          await tester.enterText(
            find.byKey(const ValueKey('activity')),
            '普通生活',
          );
        }
        await textTap(tester, '保存到账本');
        final saved = (await tester.runAsync(
          () => h.ledger.readTimeBlock(id(9)),
        ))!.timeBlock;
        expect(saved.goalId, isNull);
        expect(saved.knowledgeState, knowledge);
      },
    );
  }

  testWidgets(
    'same names select by id; Unknown retains title and approximate Goal time; draft leaves and resumes',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        for (final n in [1, 2]) {
          await h.goals.create(id: id(n), name: '同名', now: 1);
        }
        await h.goals.create(id: id(3), name: '归档候选', now: 1);
        await h.goals.archive(id: id(3), now: 2);
      });
      final context = RecordingDraftContext.newEntry(date: date);
      await tester.pumpWidget(h.app(context));
      await textTap(tester, '打开');
      await tester.enterText(
        find.byKey(const ValueKey('activity')),
        '  保留活动  ',
      );
      await textTap(tester, '记得做了什么');
      await textTap(tester, '选择目标');
      expect(find.text('同名'), findsNWidgets(2));
      expect(find.byKey(ValueKey('goal-option-${id(3)}')), findsNothing);
      await tap(tester, find.byKey(ValueKey('goal-option-${id(2)}')));
      await textTap(tester, '想不起来');
      await textTap(tester, '保留草稿并返回');
      final draft = await tester.runAsync(() => h.drafts.read(context));
      expect(draft!.goalId, id(2));
      expect(draft.goalProvided, isTrue);
      expect(
        await tester.runAsync(() => h.ledger.readTimeBlock(id(9))),
        isNull,
      );
      await textTap(tester, '打开');
      expect(
        find.byKey(const ValueKey('goal-time-confirmation')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('goal-time-confirmation')),
          matching: find.textContaining('约 ${formatRecordingTime(start)}'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '  保留活动  ',
      );
      await textTap(tester, '保存到账本');
      final saved = (await tester.runAsync(
        () => h.ledger.readTimeBlock(id(9)),
      ))!.timeBlock;
      expect(saved.goalId, id(2));
      expect(saved.knowledgeState, BlockKnowledgeState.unknown);
      expect(saved.title, '保留活动');
      expect(saved.startPrecision, TimePrecision.approximate);
      expect(await tester.runAsync(() => h.drafts.read(context)), isNull);
    },
  );

  for (final editing in [false, true]) {
    for (final mutation in ['archive', 'delete']) {
      testWidgets(
        '${editing ? 'edit' : 'new'} selection then $mutation refuses save, keeps input, permits replacement retry',
        (tester) async {
          final h = await open(tester);
          await tester.runAsync(() async {
            await h.goals.create(id: id(1), name: '选择后失效', now: 1);
            await h.goals.create(id: id(2), name: '可重选', now: 1);
            if (editing) await h.source();
          });
          final context = editing
              ? RecordingDraftContext.edit(date: date, timeBlockId: id(8))
              : RecordingDraftContext.newEntry(date: date);
          await tester.pumpWidget(h.app(context));
          await textTap(tester, '打开');
          await tester.enterText(
            find.byKey(const ValueKey('activity')),
            '修改但未提交',
          );
          await textTap(tester, '记得做了什么');
          await choose(tester, 1);
          await tester.runAsync(() async {
            if (mutation == 'archive') {
              await h.goals.archive(id: id(1), now: 2);
            } else {
              await h.goals.delete(id: id(1), now: 2);
            }
          });
          await textTap(tester, editing ? '保存更正' : '保存到账本');
          expect(find.text('正式保存失败，输入和草稿已保留，请重试。'), findsOneWidget);
          final draft = (await tester.runAsync(() => h.drafts.read(context)))!;
          expect(draft.goalId, id(1));
          expect(draft.title, '修改但未提交');
          final unchanged = await tester.runAsync(
            () => h.ledger.readTimeBlock(id(editing ? 8 : 9)),
          );
          if (editing) {
            expect(unchanged!.timeBlock.title, '原活动');
            expect(unchanged.timeBlock.goalId, isNull);
          } else {
            expect(unchanged, isNull);
          }
          await textTap(tester, '刷新目标');
          if (mutation == 'archive') {
            expect(find.text('此目标已归档，请重新选择或移除后保存。'), findsOneWidget);
          } else {
            expect(find.textContaining('已不存在'), findsOneWidget);
          }
          await choose(tester, 2);
          await textTap(tester, editing ? '保存更正' : '保存到账本');
          final saved = (await tester.runAsync(
            () => h.ledger.readTimeBlock(id(editing ? 8 : 9)),
          ))!.timeBlock;
          expect(saved.goalId, id(2));
          expect(saved.title, '修改但未提交');
        },
      );
    }
  }

  testWidgets(
    'archived original survives known-to-Unknown edit, explicit clear persists and applies only on save',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        await h.goals.create(id: id(1), name: '历史目标', now: 1);
        await h.source(goalId: id(1));
        await h.goals.archive(id: id(1), now: 2);
      });
      final context = RecordingDraftContext.edit(
        date: date,
        timeBlockId: id(8),
      );
      await tester.pumpWidget(h.app(context));
      await textTap(tester, '打开');
      expect(find.text('历史目标（已归档）'), findsOneWidget);
      await textTap(tester, '想不起来');
      await textTap(tester, '保存更正');
      final retained = (await tester.runAsync(
        () => h.ledger.readTimeBlock(id(8)),
      ))!;
      expect(retained.timeBlock.goalId, id(1));
      expect(retained.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
      expect(retained.annotation!.continuationHint, '接续点');
      await textTap(tester, '打开');
      await textTap(tester, '移除目标归属');
      await textTap(tester, '保留草稿并返回');
      final pending = (await tester.runAsync(() => h.drafts.read(context)))!;
      expect(pending.goalProvided, isTrue);
      expect(pending.goalId, isNull);
      expect(
        (await tester.runAsync(() => h.ledger.readTimeBlock(id(8))))!
            .timeBlock
            .goalId,
        id(1),
      );
      await textTap(tester, '打开');
      expect(find.text('未关联目标'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('goal-time-confirmation')),
        findsNothing,
      );
      await textTap(tester, '保存更正');
      final cleared = (await tester.runAsync(
        () => h.ledger.readTimeBlock(id(8)),
      ))!;
      expect(cleared.timeBlock.goalId, isNull);
      expect(cleared.timeBlock.categoryId, '原分类');
      expect(cleared.timeBlock.createdAt, 1);
      expect(cleared.annotation!.id, id(7));
    },
  );

  testWidgets(
    'SQL save failure retains Goal input and retry succeeds after rollback',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        await h.goals.create(id: id(1), name: '待保存', now: 1);
        await h.db.customStatement(
          "CREATE TEMP TRIGGER reject_block AFTER INSERT ON time_blocks BEGIN SELECT RAISE(FAIL, 'test failure'); END",
        );
      });
      final context = RecordingDraftContext.newEntry(date: date);
      await tester.pumpWidget(h.app(context));
      await textTap(tester, '打开');
      await textTap(tester, '想不起来');
      await choose(tester, 1);
      await textTap(tester, '保存到账本');
      expect(find.text('正式保存失败，输入和草稿已保留，请重试。'), findsOneWidget);
      expect(
        (await tester.runAsync(() => h.drafts.read(context)))!.goalId,
        id(1),
      );
      expect(
        await tester.runAsync(() => h.ledger.readTimeBlock(id(9))),
        isNull,
      );
      await tester.runAsync(
        () => h.db.customStatement('DROP TRIGGER reject_block'),
      );
      await textTap(tester, '保存到账本');
      expect(
        (await tester.runAsync(() => h.ledger.readTimeBlock(id(9))))!
            .timeBlock
            .goalId,
        id(1),
      );
    },
  );

  testWidgets(
    'recovery matches Goal id and explicit clear instead of discarding unsubmitted association changes',
    (tester) async {
      final h = await open(tester);
      await tester.runAsync(() async {
        await h.goals.create(id: id(1), name: '目标', now: 1);
        await h.source(goalId: id(1));
      });
      final context = RecordingDraftContext.edit(
        date: date,
        timeBlockId: id(8),
      );
      var c = h.controller(context);
      await tester.runAsync(c.initialize);
      c.clearGoal();
      await tester.runAsync(c.flush);
      c.dispose();
      c = h.controller(context);
      await tester.runAsync(c.initialize);
      expect(c.committed, isNull);
      expect(c.goalId, isNull);
      expect(await tester.runAsync(() => h.drafts.read(context)), isNotNull);
      c.dispose();
      final newContext = RecordingDraftContext.newEntry(date: date);
      await tester.runAsync(
        () => h.drafts.save(
          RecordingDraft(
            context: newContext,
            title: '原活动',
            startedAt: start,
            endedAt: end,
            startPrecision: TimePrecision.approximate,
            endPrecision: TimePrecision.exact,
            knowledgeState: BlockKnowledgeState.known,
            note: '原备注',
            noteProvided: true,
            goalProvided: true,
          ),
        ),
      );
      expect(
        await tester.runAsync(
          () async =>
              h.saver.recoverCommittedDraft((await h.drafts.read(newContext))!),
        ),
        isNull,
      );
    },
  );
}
