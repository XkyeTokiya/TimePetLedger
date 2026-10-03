import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
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
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

import '../features/ledger/presentation/recording_rhythm_test.dart' show show;
import 'recording_goal_flow_test.dart' show disposeApp;
import 'support/checked_sleep_opening.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
CivilDate day(int n) => CivilDate(year: 2026, month: 9, day: n);
int at(int d, int h, [int m = 0]) =>
    DateTime(2026, 9, d, h, m).millisecondsSinceEpoch;
final now = DateTime(2026, 10, 1, 12);
Finder tile(int n) =>
    find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id(n))));
Finder textIn(int n, String text) =>
    find.descendant(of: tile(n), matching: find.text(text));
Future<void> tap(WidgetTester t, Finder finder) async {
  await show(t, finder);
  await t.tap(finder.first);
  await t.pumpAndSettle();
}

Future<void> textTap(WidgetTester t, String text) => tap(t, find.text(text));
Future<void> select(WidgetTester t, int n) async {
  final input = find.widgetWithText(TextField, '账本日期');
  await show(t, input);
  await t.enterText(input, '2026-09-$n');
  await t.pumpAndSettle();
}

Future<void> stateTap(WidgetTester t, String state) =>
    tap(t, find.byKey(ValueKey('rhythm-$state')));
Future<void> hint(WidgetTester t, String value) async {
  final input = find.byKey(const ValueKey('continuation-hint'));
  await show(t, input);
  await t.enterText(input, value);
  await t.pumpAndSettle();
}

class Queries extends QueryInterceptor {
  bool failGoalRead = false;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failGoalRead && sql.contains('FROM goals WHERE id')) {
      throw StateError('private SQL failure');
    }
    return executor.runSelect(sql, args);
  }
}

class Fixture {
  Fixture(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  late final repo = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  static Future<Fixture> open(WidgetTester t, {Queries? queries}) async =>
      (await t.runAsync(
        () async => Fixture(
          await AppDatabase.open(
            queries == null
                ? NativeDatabase.memory()
                : NativeDatabase.memory().interceptWith(queries),
          ),
          await DriftRecordingDraftStore.open(NativeDatabase.memory()),
        ),
      ))!;
  Future<void> source(WidgetTester t, {bool annotated = true}) =>
      t.runAsync(() async {
        await goals.create(id: id(10), name: '同名目标', now: 1);
        await repo.createTimeBlock(
          id: id(1),
          startedAt: at(29, 23, 30),
          endedAt: at(30, 0, 30),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '跨日写作',
          goalId: id(10),
          note: '原备注',
          categoryId: '原分类',
          now: 1,
          annotation: annotated
              ? AddAnnotation(
                  id: id(20),
                  state: RhythmState.progress,
                  continuationHint: '画出字段\n然后补关系 🐾',
                )
              : null,
        );
      });
  Future<void> mount(WidgetTester t) async {
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openSleepOpenings: () => openCheckedSleepOpening(now),
        now: () => now,
      ),
    );
    await t.pumpAndSettle();
    await textTap(t, '打开日账本');
    await select(t, 30);
  }

  Future<List<Object?>> snapshot() async => [
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      'daily_reviews',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  ];
  Future<Map<String, Object?>> factRow() async =>
      (await db
              .customSelect(
                'SELECT * FROM time_blocks WHERE id = ?',
                variables: [Variable(id(1))],
              )
              .getSingle())
          .data;
  Future<List<Map<String, Object?>>> reviews() async =>
      (await db.customSelect('SELECT * FROM daily_reviews ORDER BY id').get())
          .map((r) => r.data)
          .toList();
  Future<void> seedReviews(WidgetTester t) => t.runAsync(() async {
    for (final n in [29, 30]) {
      await DriftReviewRepository(db).create(
        id: id(n),
        date: day(n),
        summary: '原复盘$n',
        reflection: '保留文字',
        tomorrowFirstStepText: '独立的明日第一步$n',
        tomorrowFirstStepGoalId: id(10),
        now: 1,
      );
    }
  });
}

void main() {
  testWidgets(
    'same names use distinct ids, current metadata reloads and absent annotations/sleep carry no implied rhythm',
    (t) async {
      final f = await Fixture.open(t);
      await f.source(t);
      await t.runAsync(() async {
        await f.goals.create(id: id(11), name: '同名目标', now: 1);
        await f.repo.createTimeBlock(
          id: id(2),
          startedAt: at(30, 1),
          endedAt: at(30, 2),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.unknown,
          goalId: id(11),
          annotation: AddAnnotation(
            id: id(21),
            state: RhythmState.recovery,
            continuationHint: '下次继续',
          ),
          now: 1,
        );
        await f.goals.archive(id: id(11), now: 2);
        await f.repo.createTimeBlock(
          id: id(3),
          startedAt: at(30, 2),
          endedAt: at(30, 3),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '午饭',
          goalId: id(10),
          now: 1,
        );
        await f.repo.createTimeBlock(
          id: id(4),
          startedAt: at(30, 3),
          endedAt: at(30, 4),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.unknown,
          annotation: AddAnnotation(id: id(22), state: RhythmState.stuck),
          now: 1,
        );
        await f.repo.createSleepSession(
          id: id(5),
          startedAt: at(30, 4),
          endedAt: at(30, 5),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        );
      });
      final before = await t.runAsync(f.snapshot);
      await f.mount(t);
      expect(textIn(1, '目标：同名目标'), findsOneWidget);
      expect(textIn(2, '目标：同名目标（已归档）'), findsOneWidget);
      expect(textIn(1, '节奏：推进'), findsOneWidget);
      expect(textIn(2, '节奏：恢复'), findsOneWidget);
      expect(textIn(4, '节奏：卡住'), findsOneWidget);
      expect(textIn(1, '接续点：画出字段\n然后补关系 🐾'), findsOneWidget);
      expect(
        find.descendant(of: tile(3), matching: find.textContaining('节奏：')),
        findsNothing,
      );
      expect(
        find.descendant(of: tile(4), matching: find.textContaining('目标：')),
        findsNothing,
      );
      final sleep = find.byKey(
        ValueKey((type: LedgerFactType.sleepSession, id: id(5))),
      );
      expect(
        find.descendant(of: sleep, matching: find.textContaining('节奏：')),
        findsNothing,
      );
      expect(find.textContaining('失败'), findsNothing);
      expect(await t.runAsync(f.snapshot), before);
      await t.runAsync(() => f.goals.rename(id: id(10), name: '新名称', now: 3));
      await textTap(t, '刷新账本');
      expect(textIn(1, '目标：新名称'), findsOneWidget);
      expect(textIn(3, '目标：新名称'), findsOneWidget);
      expect(textIn(2, '目标：同名目标（已归档）'), findsOneWidget);
      await t.runAsync(() => f.goals.archive(id: id(10), now: 4));
      await select(t, 29);
      expect(textIn(1, '目标：新名称（已归档）'), findsOneWidget);
      await t.runAsync(() => f.goals.restore(id: id(10), now: 5));
      await select(t, 30);
      expect(textIn(1, '目标：新名称'), findsOneWidget);
      await disposeApp(t);
    },
  );

  testWidgets(
    'both day slices edit the complete annotation, clear hint/remove and delete reread without rewriting reviews',
    (t) async {
      final f = await Fixture.open(t);
      await f.source(t);
      await f.seedReviews(t);
      final reviews = await t.runAsync(f.reviews);
      final fact = await t.runAsync(f.factRow);
      await t.runAsync(() => f.goals.archive(id: id(10), now: 2));
      await f.mount(t);
      await select(t, 29);
      await tap(t, tile(1));
      final form = t.widget<RecordingForm>(find.byType(RecordingForm));
      expect(form.context.timeBlockId, id(1));
      expect(form.context.date, day(29));
      await show(t, find.text('结束时间'));
      expect(find.text('2026-09-29 23:30'), findsOneWidget);
      expect(find.text('2026-09-30 00:30'), findsOneWidget);
      await stateTap(t, 'stuck');
      await hint(t, '  先看方案\n再继续 🐾  ');
      await textTap(t, '保存更正');
      expect(textIn(1, '节奏：卡住'), findsOneWidget);
      expect(textIn(1, '接续点：先看方案\n再继续 🐾'), findsOneWidget);
      expect(await t.runAsync(f.factRow), fact);
      await select(t, 30);
      expect(textIn(1, '节奏：卡住'), findsOneWidget);
      expect(textIn(1, '目标：同名目标（已归档）'), findsOneWidget);
      await tap(t, tile(1));
      expect(
        t.widget<RecordingForm>(find.byType(RecordingForm)).context.timeBlockId,
        id(1),
      );
      await stateTap(t, 'recovery');
      await hint(t, '  ');
      await textTap(t, '保存更正');
      expect(textIn(1, '节奏：恢复'), findsOneWidget);
      expect(
        find.descendant(of: tile(1), matching: find.textContaining('接续点：')),
        findsNothing,
      );
      final updated = (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!;
      expect(updated.annotation!.id, id(20));
      expect(updated.annotation!.createdAt, 1);
      expect(updated.annotation!.continuationHint, isNull);
      expect(await t.runAsync(f.factRow), fact);
      await tap(t, tile(1));
      await stateTap(t, 'none');
      await textTap(t, '保存更正');
      expect(
        find.descendant(of: tile(1), matching: find.textContaining('节奏：')),
        findsNothing,
      );
      expect(textIn(1, '目标：同名目标（已归档）'), findsOneWidget);
      await select(t, 29);
      expect(
        find.descendant(of: tile(1), matching: find.textContaining('节奏：')),
        findsNothing,
      );
      expect(await t.runAsync(f.factRow), fact);
      await tap(t, tile(1));
      await stateTap(t, 'progress');
      await hint(t, '删除连带移除的接续点');
      await textTap(t, '保存更正');
      expect(textIn(1, '接续点：删除连带移除的接续点'), findsOneWidget);
      expect(await t.runAsync(f.factRow), fact);
      await tap(
        t,
        find.descendant(of: tile(1), matching: find.byTooltip('删除记录')),
      );
      await textTap(t, '删除记录');
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      expect(find.byType(LedgerGapTimelineTile), findsOneWidget);
      await select(t, 30);
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      expect(await t.runAsync(() => f.repo.readTimeBlock(id(1))), isNull);
      expect(
        await t.runAsync(
          () => f.db.customSelect('SELECT * FROM rhythm_annotations').get(),
        ),
        isEmpty,
      );
      expect(await t.runAsync(f.reviews), reviews);
      await disposeApp(t);
    },
  );

  testWidgets(
    'long Unicode Goal and multiline continuation stay readable on narrow scaled timeline without truncating stored text',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final f = await Fixture.open(t);
      await f.source(t);
      final name = List.filled(200, '目').join();
      final continuation = '${List.filled(1998, '🐾').join()}\n中';
      await t.runAsync(() async {
        await f.goals.rename(id: id(10), name: name, now: 2);
        await f.repo.updateTimeBlock(
          id: id(1),
          annotation: EditAnnotation(continuationHint: (value: continuation)),
          now: 2,
        );
      });
      final observer = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: DayLedgerPage(
            loader: createDayLedgerLoader(f.db),
            now: () => now.millisecondsSinceEpoch,
            dateOfInstant: deviceDateOfInstant,
            initialDate: day(30),
            routeObserver: observer,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(textIn(1, '目标：$name'), findsOneWidget);
      expect(textIn(1, '接续点：$continuation'), findsOneWidget);
      expect(textIn(1, '节奏：推进'), findsOneWidget);
      expect(t.takeException(), isNull);
      final text = t.widget<Text>(textIn(1, '接续点：$continuation'));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!
            .annotation!
            .continuationHint,
        continuation,
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await f.drafts.close();
        await f.db.close();
      });
    },
  );

  testWidgets(
    'real Goal read failure hides stale timeline; retry reads current metadata without any formal write',
    (t) async {
      final queries = Queries();
      final f = await Fixture.open(t, queries: queries);
      await f.source(t);
      await f.mount(t);
      expect(textIn(1, '目标：同名目标'), findsOneWidget);
      await t.runAsync(
        () => f.goals.rename(id: id(10), name: '重新读取名称', now: 2),
      );
      final before = await t.runAsync(f.snapshot);
      queries.failGoalRead = true;
      await textTap(t, '刷新账本');
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      expect(find.textContaining('private SQL'), findsNothing);
      queries.failGoalRead = false;
      await textTap(t, '重试读取');
      expect(textIn(1, '目标：重新读取名称'), findsOneWidget);
      expect(textIn(1, '节奏：推进'), findsOneWidget);
      expect(await t.runAsync(f.snapshot), before);
      await disposeApp(t);
    },
  );

  testWidgets(
    'committed annotation refresh failure retries reads only, including independent full-day Goal failure',
    (t) async {
      final queries = Queries();
      final f = await Fixture.open(t, queries: queries);
      await f.source(t);
      await f.seedReviews(t);
      var failPartial = true;
      final recording = RecordingLedgerLoader(
        repository: f.repo,
        resolveDate: resolveDeviceRecordingDate,
      );
      final saver = RecordingEntrySaver(
        repository: f.repo,
        drafts: f.drafts,
        refresh: ({required date, required now}) {
          if (failPartial) throw StateError('partial read failure');
          queries.failGoalRead = true;
          return recording.load(date: date, now: now);
        },
        newId: () => throw StateError('edit must not create'),
        now: () => now.millisecondsSinceEpoch,
      );
      final editor = RecordingEntryEditor(
        repository: f.repo,
        drafts: f.drafts,
        saver: saver,
      );
      final observer = RouteObserver<ModalRoute<void>>();
      await t.runAsync(() async {
        await f.db.customStatement('CREATE TEMP TABLE operations (name TEXT)');
        await f.db.customStatement(
          "CREATE TEMP TRIGGER audit_annotation AFTER UPDATE ON rhythm_annotations BEGIN INSERT INTO operations VALUES ('annotation'); END",
        );
        await f.db.customStatement(
          "CREATE TEMP TRIGGER audit_fact AFTER UPDATE ON time_blocks BEGIN INSERT INTO operations VALUES ('fact'); END",
        );
      });
      final reviews = await t.runAsync(f.reviews);
      await t.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: createDayLedgerLoader(f.db),
            now: () => now.millisecondsSinceEpoch,
            dateOfInstant: deviceDateOfInstant,
            initialDate: day(30),
            routeObserver: observer,
            recordingEditor: editor,
            factEntry: (date, segment) => RecordingForm(
              context: RecordingDraftContext.edit(
                date: date,
                timeBlockId: segment.reference.id,
              ),
              store: f.drafts,
              entryEditor: editor,
              goals: f.goals,
              loadSuggestion: () async => const ManualTimeEntry(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await tap(t, tile(1));
      await stateTap(t, 'stuck');
      await hint(t, '已提交接续点');
      await textTap(t, '保存更正');
      expect(find.text('更正已保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      final afterCommit = await t.runAsync(f.snapshot);
      await textTap(t, '继续清理并刷新');
      expect(await t.runAsync(f.snapshot), afterCommit);
      failPartial = false;
      await textTap(t, '继续清理并刷新');
      expect(find.byType(RecordingForm), findsNothing);
      expect(find.text('记录更改已应用。'), findsOneWidget);
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      queries.failGoalRead = false;
      await textTap(t, '重试读取');
      expect(textIn(1, '节奏：卡住'), findsOneWidget);
      expect(textIn(1, '接续点：已提交接续点'), findsOneWidget);
      expect(await t.runAsync(f.snapshot), afterCommit);
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(1),
      );
      expect(await t.runAsync(f.reviews), reviews);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await f.drafts.close();
        await f.db.close();
      });
    },
  );
}
