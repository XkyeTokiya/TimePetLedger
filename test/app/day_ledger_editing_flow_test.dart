import '../support/recording_fields.dart';
import '../support/ledger_date_selection.dart';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_shell.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form.dart';

import 'gap_recording_flow_test.dart' show tap, enterTime, disposeApp;
import 'support/checked_sleep_opening.dart';
import '../features/ledger/application/recording_entry_editor_test.dart'
    show FailingClearStore;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
CivilDate day(int n) => CivilDate(year: 2026, month: 9, day: n);
int at(int d, int h, [int m = 0]) =>
    DateTime(2026, 9, d, h, m).millisecondsSinceEpoch;
final now = DateTime(2026, 10, 1, 12);

DayLedgerController controller(WidgetTester t) => t
    .widgetList<ListenableBuilder>(
      find.byType(ListenableBuilder, skipOffstage: false),
    )
    .map((builder) => builder.listenable)
    .whereType<DayLedgerController>()
    .first;

/// 首页改版后时间轴由 feed 控制器驱动，不再挂 [DayLedgerController]；
/// 独立摘要 / 复盘页仍然挂。优先取直接控制器，否则读首页聚焦投影。
DayLedgerView ledgerView(WidgetTester t) {
  final direct = t
      .widgetList<ListenableBuilder>(
        find.byType(ListenableBuilder, skipOffstage: false),
      )
      .map((builder) => builder.listenable)
      .whereType<DayLedgerController>()
      .map((controller) => controller.view)
      .whereType<DayLedgerView>();
  if (direct.isNotEmpty) return direct.first;
  return t
      .state<HomeShellState>(find.byType(HomeShell, skipOffstage: false))
      .feed
      .focusView!;
}

Future<void> select(WidgetTester t, int date) async {
  await selectLedgerDate(t, '2026-09-${date.toString().padLeft(2, '0')}');
  await t.pumpAndSettle();
}

Future<void> editFact(
  WidgetTester t,
  LedgerFactType type,
  String factId,
) async {
  final tile = find.byKey(ValueKey((type: type, id: factId)));
  await Scrollable.ensureVisible(t.element(tile), alignment: .5);
  await t.pumpAndSettle();
  await t.tap(tile);
  await t.pumpAndSettle();
  await t.tap(find.text('编辑完整记录'));
  await t.pumpAndSettle();
}

Future<void> deleteBlock(
  WidgetTester t,
  String factId, {
  bool cancel = false,
}) async {
  final tile = find.byKey(
    ValueKey((type: LedgerFactType.timeBlock, id: factId)),
  );
  await Scrollable.ensureVisible(t.element(tile), alignment: .5);
  await t.pumpAndSettle();
  await t.tap(tile);
  await t.pumpAndSettle();
  await t.tap(find.text('删除记录'));
  await t.pumpAndSettle();
  await t.tap(find.text(cancel ? '取消' : '删除记录'));
  await t.pumpAndSettle();
}

class Fixture {
  Fixture(this.db, this.drafts, this.sleepStores);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  final List<DriftSleepDraftStore> sleepStores;
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  static Future<Fixture> open(WidgetTester t) async => (await t.runAsync(
    () async => Fixture(
      await AppDatabase.open(NativeDatabase.memory()),
      await DriftRecordingDraftStore.open(NativeDatabase.memory()),
      [
        for (var i = 0; i < 5; i++)
          await DriftSleepDraftStore.open(NativeDatabase.memory()),
      ],
    ),
  ))!;
  Future<void> mount(WidgetTester t) async {
    addTearDown(() async {
      for (final store in sleepStores) {
        await store.close();
      }
    });
    await t.pumpWidget(
      AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => drafts,
        openReviewDrafts: emptyLegacyReviewDrafts,
        openSleepDrafts: () async => sleepStores.removeAt(0),
        openSleepOpenings: () => openCheckedSleepOpening(now),
        now: () => now,
      ),
    );
    await t.pumpAndSettle();
    await tap(t, '打开日账本');
  }

  Future<void> block(WidgetTester t, {int? start, int? end}) =>
      t.runAsync(() async {
        await repo.createTimeBlock(
          id: id(1),
          startedAt: start ?? at(28, 23, 30),
          endedAt: end ?? at(29, 0, 30),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '写作',
          now: 1,
        );
      });
  Future<void> sleep(WidgetTester t, {int? start, int? end}) =>
      t.runAsync(() async {
        await repo.createSleepSession(
          id: id(1),
          startedAt: start ?? at(28, 23, 50),
          endedAt: end ?? at(29, 7, 40),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          note: '完整睡眠备注',
          now: 1,
        );
      });
}

void main() {
  final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning,
  );
  testWidgets(
    'cross-day TimeBlock edits one complete identity from both days; hidden fields survive both knowledge transitions and move; delete removes annotation only',
    (t) async {
      final f = await Fixture.open(t);
      await t.runAsync(() async {
        final goals = DriftGoalRepository(f.db);
        await goals.create(id: id(2), name: '论文', now: 1);
        await f.repo.createTimeBlock(
          id: id(1),
          startedAt: at(28, 23, 30),
          endedAt: at(29, 0, 30),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '写作',
          goalId: id(2),
          categoryId: 'legacy',
          note: '备注',
          annotation: AddAnnotation(id: id(3), state: RhythmState.progress),
          now: 1,
        );
        await goals.archive(id: id(2), now: 2);
        // Same id across types must dispatch to separate editors.
        await f.repo.createSleepSession(
          id: id(1),
          startedAt: at(29, 23, 50),
          endedAt: at(30, 7, 40),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.mainSleep,
          now: 1,
        );
        await DriftReviewRepository(f.db).create(
          id: id(4),
          date: day(29),
          tomorrowFirstStepText: '继续写作',
          reflection: '原复盘',
          now: 1,
        );
      });
      await f.mount(t);
      await select(t, 28);
      await editFact(t, LedgerFactType.timeBlock, id(1));
      await revealRecordingField(t, '结束时间');
      await t.scrollUntilVisible(
        find.text('结束时间'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(find.text('2026-09-28 23:30'), findsOneWidget);
      expect(find.text('2026-09-29 00:30'), findsOneWidget);
      final context28 = t
          .widget<RecordingForm>(find.byType(RecordingForm))
          .context;
      expect(context28.date, day(28));
      await tap(t, '保存更正'); // No-op must not change metadata.
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!
            .timeBlock
            .updatedAt,
        1,
      );
      await select(t, 29);
      await editFact(t, LedgerFactType.timeBlock, id(1));
      expect(
        t.widget<RecordingForm>(find.byType(RecordingForm)).context.date,
        day(29),
      );
      expect(
        recordingTimeSummaryContaining('2026-09-28 23:30'),
        findsOneWidget,
      );
      await tap(t, '想不起来');
      await tap(t, '保存更正');
      final unknown = (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!;
      expect(unknown.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
      expect(
        (
          unknown.timeBlock.title,
          unknown.timeBlock.goalId,
          unknown.timeBlock.categoryId,
          unknown.timeBlock.note,
        ),
        ('写作', id(2), 'legacy', '备注'),
      );
      expect(unknown.annotation!.id, id(3));
      expect(controller(t).view!.unknownDuration.milliseconds, 30 * 60000);
      await editFact(t, LedgerFactType.timeBlock, id(1));
      await tap(t, '记得');
      await enterTime(t, '开始时间', '2026-09-30 10:00');
      await enterTime(t, '结束时间', '2026-09-30 11:00');
      await tap(t, '保存更正');
      expect(
        controller(t).view!.segments.whereType<TimeBlockSegment>(),
        isEmpty,
      );
      await select(t, 28);
      expect(controller(t).view!.segments, isEmpty);
      await select(t, 30);
      final updated = (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!;
      expect(updated.timeBlock.id, id(1));
      expect(updated.timeBlock.createdAt, 1);
      expect(updated.timeBlock.knowledgeState, BlockKnowledgeState.known);
      expect(updated.timeBlock.goalId, id(2));
      expect(updated.timeBlock.categoryId, 'legacy');
      expect(updated.timeBlock.note, '备注');
      expect(updated.annotation!.id, id(3));
      await deleteBlock(t, id(1), cancel: true);
      expect(await t.runAsync(() => f.repo.readTimeBlock(id(1))), isNotNull);
      await deleteBlock(t, id(1));
      expect(await t.runAsync(() => f.repo.readTimeBlock(id(1))), isNull);
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM rhythm_annotations').get(),
        ))!,
        isEmpty,
      );
      expect(
        (await t.runAsync(
          () => f.db
              .customSelect('SELECT reflection FROM daily_reviews')
              .getSingle(),
        ))!.read<String>('reflection'),
        '原复盘',
      );
      expect(
        controller(t).view!.segments.whereType<TimeBlockSegment>(),
        isEmpty,
      );
      expect(controller(t).view!.unresolvedSpans.last.startedAt, at(30, 7, 40));
      await select(t, 29);
      await editFact(t, LedgerFactType.sleepSession, id(1));
      expect(
        t.widget<SleepForm>(find.byType(SleepForm)).controller.original!.id,
        id(1),
      );
      await tap(t, '返回');
      await disposeApp(t);
    },
  );

  testWidgets(
    'cross-day SleepSession enters complete editor from both slices; moving wake date and deleting refresh all revisited projections',
    (t) async {
      final f = await Fixture.open(t);
      await f.sleep(t);
      await f.mount(t);
      await select(t, 28);
      await editFact(t, LedgerFactType.sleepSession, id(1));
      var model = t.widget<SleepForm>(find.byType(SleepForm)).controller;
      expect(model.context.date, day(28));
      expect((model.startedAt, model.endedAt), (at(28, 23, 50), at(29, 7, 40)));
      await tap(t, '保存更正');
      expect(
        (await t.runAsync(() => f.repo.readSleepSession(id(1))))!.updatedAt,
        1,
      );
      await select(t, 29);
      await editFact(t, LedgerFactType.sleepSession, id(1));
      model = t.widget<SleepForm>(find.byType(SleepForm)).controller;
      expect(model.context.date, day(29));
      expect(model.startedAt, at(28, 23, 50));
      await t.enterText(
        find.byKey(const ValueKey('sleep-start')),
        '2026-09-29 23:50',
      );
      await t.enterText(
        find.byKey(const ValueKey('sleep-end')),
        '2026-09-30 07:40',
      );
      await tap(t, '小睡');
      await tap(t, '保存更正');
      expect(controller(t).view!.sleepSummary.mainSleep.records, isEmpty);
      expect(controller(t).view!.sleepSummary.nap.records, isEmpty);
      await select(t, 28);
      expect(controller(t).view!.segments, isEmpty);
      await select(t, 30);
      expect(controller(t).view!.sleepSummary.nap.records.single.id, id(1));
      final changed = (await t.runAsync(() => f.repo.readSleepSession(id(1))))!;
      expect(
        (changed.id, changed.createdAt, changed.note),
        (id(1), 1, '完整睡眠备注'),
      );
      expect(
        (changed.startPrecision, changed.endPrecision),
        (TimePrecision.approximate, TimePrecision.exact),
      );
      await editFact(t, LedgerFactType.sleepSession, id(1));
      await tap(t, '删除睡眠');
      await t.tap(find.text('确认删除'));
      await t.pumpAndSettle();
      expect(controller(t).view!.segments, isEmpty);
      expect(controller(t).view!.sleepSummary.nap.records, isEmpty);
      expect(
        controller(t).view!.unresolvedSpans.single.duration.milliseconds,
        24 * 3600000,
      );
      await select(t, 29);
      expect(controller(t).view!.segments, isEmpty);
      expect(await t.runAsync(() => f.repo.readSleepSession(id(1))), isNull);
      await disposeApp(t);
    },
  );

  testWidgets(
    'stale TimeBlock save conflicts atomically, retains draft and rejects missing source; missing Sleep slice cannot recreate saved draft',
    (t) async {
      final f = await Fixture.open(t);
      await f.sleep(t);
      await f.block(t, start: at(29, 8), end: at(29, 9));
      await f.mount(t);
      await select(t, 29);
      await editFact(t, LedgerFactType.sleepSession, id(1));
      await t.enterText(
        find.byKey(const ValueKey('sleep-end')),
        '2026-09-29 09:00',
      );
      await tap(t, '保存更正');
      expect(find.textContaining('普通记录 ${id(1)}：'), findsOneWidget);
      expect(
        (await t.runAsync(() => f.repo.readSleepSession(id(1))))!.endedAt,
        at(29, 7, 40),
      );
      expect(
        t.widget<SleepForm>(find.byType(SleepForm)).controller.draft.endedAt,
        at(29, 9),
      );
      await tap(t, '返回');
      await editFact(t, LedgerFactType.timeBlock, id(1));
      await enterTime(t, '结束时间', '2026-09-29 10:00');
      await t.runAsync(
        () => f.repo.createSleepSession(
          id: id(9),
          startedAt: at(29, 9),
          endedAt: at(29, 10),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 2,
        ),
      );
      await tap(t, '保存更正');
      expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
      expect(find.text('记录更改已应用。'), findsNothing);
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!
            .timeBlock
            .endedAt,
        at(29, 9),
      );
      final context = t
          .widget<RecordingForm>(find.byType(RecordingForm))
          .context;
      expect(
        (await t.runAsync(() => f.drafts.read(context)))!.endedAt,
        at(29, 10),
      );
      await t.runAsync(() => f.repo.deleteTimeBlock(id(1)));
      await tap(t, '保存更正');
      expect(find.textContaining('记录已不存在'), findsOneWidget);
      await tap(t, '返回');
      expect(
        controller(t).view!.segments.whereType<TimeBlockSegment>(),
        isEmpty,
      );
      // The next editor re-reads identity rather than trusting the stale slice.
      final sleepStore = f.sleepStores.first;
      final sleepContext = SleepDraftContext.edit(
        date: day(29),
        sleepSessionId: id(1),
      );
      await t.runAsync(() async {
        await sleepStore.save(
          SleepDraft(
            context: sleepContext,
            startedAt: at(28, 23),
            endedAt: at(29, 8),
            startPrecision: TimePrecision.approximate,
            endPrecision: TimePrecision.exact,
            type: SleepType.mainSleep,
          ),
        );
        await f.repo.deleteSleepSession(id(1));
      });
      await editFact(t, LedgerFactType.sleepSession, id(1));
      expect(find.textContaining('记录已不存在'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      expect(await t.runAsync(() => f.repo.readSleepSession(id(1))), isNull);
      expect(await t.runAsync(() => sleepStore.read(sleepContext)), isNotNull);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(
        controller(t).view!.segments
            .whereType<SleepSessionSegment>()
            .single
            .source
            .id,
        id(9),
      );
      await disposeApp(t);
    },
  );
  testWidgets(
    'daily deletion rolls back on storage failure, handles stale repeated delete and retries committed cleanup/read without another deletion',
    (t) async {
      final f = await Fixture.open(t);
      await f.block(t, start: at(29, 8), end: at(29, 9));
      final failing = FailingClearStore(f.drafts);
      var failPartial = false;
      var failDay = false;
      final recording = RecordingLedgerLoader(
        repository: f.repo,
        resolveDate: resolveDeviceRecordingDate,
      );
      final saver = RecordingEntrySaver(
        repository: f.repo,
        drafts: failing,
        refresh: ({required date, required now}) {
          if (failPartial) throw StateError('read failed');
          return recording.load(date: date, now: now);
        },
        newId: () => throw StateError('cannot create'),
        now: () => now.millisecondsSinceEpoch,
      );
      final editor = RecordingEntryEditor(
        repository: f.repo,
        drafts: failing,
        saver: saver,
      );
      final realDay = createDayLedgerLoader(f.db);
      final loader = DayLedgerLoader(
        resolveDate: realDay.resolveDate,
        readFacts: (context) {
          if (failDay) throw StateError('day read failed');
          return realDay.readFacts(context);
        },
      );
      await t.runAsync(
        () => f.db.customStatement(
          "CREATE TEMP TRIGGER reject_delete BEFORE DELETE ON time_blocks BEGIN SELECT RAISE(ABORT, 'failure'); END",
        ),
      );
      await mountPage(t, loader, editor);
      await deleteBlock(t, id(1));
      expect(find.text('删除失败，记录未改变，请重试。'), findsOneWidget);
      expect(find.text('记录已删除。'), findsNothing);
      expect(await t.runAsync(() => f.repo.readTimeBlock(id(1))), isNotNull);
      await t.runAsync(() async {
        await f.db.customStatement('DROP TRIGGER reject_delete');
        await f.db.customStatement('CREATE TEMP TABLE operations (name TEXT)');
        await f.db.customStatement(
          "CREATE TEMP TRIGGER audit_delete AFTER DELETE ON time_blocks BEGIN INSERT INTO operations VALUES ('delete'); END",
        );
      });
      failPartial = true;
      await deleteBlock(t, id(1));
      expect(await t.runAsync(() => f.repo.readTimeBlock(id(1))), isNull);
      expect(controller(t).view!.segments, isEmpty);
      expect(
        controller(t).view!.unresolvedSpans.single.duration.milliseconds,
        24 * 3600000,
      );
      expect(find.textContaining('记录已删除，但'), findsOneWidget);
      await tap(t, '继续清理并刷新');
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(1),
      );
      failing.failClear = false;
      failPartial = false;
      failDay = true;
      await tap(t, '继续清理并刷新');
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.text('继续清理并刷新'), findsNothing);
      failDay = false;
      await tap(t, '重试读取');
      expect(controller(t).view!.segments, isEmpty);
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(1),
      );
      // A stale tile whose source was removed still performs idempotent deletion.
      await f.block(t, start: at(29, 8), end: at(29, 9));
      await t.tap(find.byTooltip('更多'));
      await t.pumpAndSettle();
      await tap(t, '刷新账本');
      await t.runAsync(() => f.repo.deleteTimeBlock(id(1)));
      await deleteBlock(t, id(1));
      expect(find.text('删除失败，记录未改变，请重试。'), findsNothing);
      expect(controller(t).view!.segments, isEmpty);
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(2),
      );
      await closePage(t, f);
    },
  );

  testWidgets(
    'committed edit retries only reading then full-day read can fail independently and recover without changing fact again',
    (t) async {
      final f = await Fixture.open(t);
      await f.block(t, start: at(29, 8), end: at(29, 9));
      var failPartial = true;
      var failDay = false;
      final recording = RecordingLedgerLoader(
        repository: f.repo,
        resolveDate: resolveDeviceRecordingDate,
      );
      final saver = RecordingEntrySaver(
        repository: f.repo,
        drafts: f.drafts,
        refresh: ({required date, required now}) {
          if (failPartial) throw StateError('read failed');
          return recording.load(date: date, now: now);
        },
        newId: () => throw StateError('cannot create'),
        now: () => now.millisecondsSinceEpoch,
      );
      final editor = RecordingEntryEditor(
        repository: f.repo,
        drafts: f.drafts,
        saver: saver,
      );
      final realDay = createDayLedgerLoader(f.db);
      final loader = DayLedgerLoader(
        resolveDate: realDay.resolveDate,
        readFacts: (context) {
          if (failDay) throw StateError('day read failed');
          return realDay.readFacts(context);
        },
      );
      await t.runAsync(() async {
        await f.db.customStatement('CREATE TEMP TABLE operations (name TEXT)');
        await f.db.customStatement(
          "CREATE TEMP TRIGGER audit_update AFTER UPDATE ON time_blocks BEGIN INSERT INTO operations VALUES ('update'); END",
        );
      });
      await mountPage(t, loader, editor, drafts: f.drafts);
      await editFact(t, LedgerFactType.timeBlock, id(1));
      await tap(t, '想不起来');
      await tap(t, '保存更正');
      expect(find.text('更正已保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('保存更正'), findsNothing);
      await tap(t, '继续清理并刷新');
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(1),
      );
      failPartial = false;
      failDay = true;
      await tap(t, '继续清理并刷新');
      expect(find.byType(RecordingForm), findsNothing);
      expect(find.text('记录更改已应用。'), findsOneWidget);
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.byType(LedgerFactTimelineTile), findsNothing);
      failDay = false;
      await tap(t, '重试读取');
      expect(controller(t).view!.segments.single.reference.id, id(1));
      expect(controller(t).view!.unknownDuration.milliseconds, 3600000);
      expect(
        (await t.runAsync(
          () => f.db.customSelect('SELECT * FROM operations').get(),
        ))!,
        hasLength(1),
      );
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(1))))!
            .timeBlock
            .createdAt,
        1,
      );
      await closePage(t, f);
    },
  );
}

Future<void> mountPage(
  WidgetTester t,
  DayLedgerLoader loader,
  RecordingEntryEditor editor, {
  RecordingDraftStore? drafts,
}) async {
  await t.pumpWidget(
    MaterialApp(
      home: DayLedgerPage(
        loader: loader,
        now: () => now.millisecondsSinceEpoch,
        dateOfInstant: deviceDateOfInstant,
        initialDate: day(29),
        routeObserver: RouteObserver<ModalRoute<void>>(),
        recordingEditor: editor,
        factEntry: drafts == null
            ? null
            : (date, segment) => RecordingForm(
                context: RecordingDraftContext.edit(
                  date: date,
                  timeBlockId: segment.reference.id,
                ),
                store: drafts,
                entryEditor: editor,
                loadSuggestion: () async => const ManualTimeEntry(),
              ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> closePage(WidgetTester t, Fixture f) async {
  await disposeApp(t);
  await t.runAsync(() async {
    await f.drafts.close();
    await f.db.close();
    for (final store in f.sleepStores) {
      await store.close();
    }
  });
}
