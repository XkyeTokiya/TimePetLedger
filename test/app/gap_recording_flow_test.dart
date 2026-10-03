import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/app/bootstrap/recording_ledger.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import 'support/checked_sleep_opening.dart';

final date = CivilDate(year: 2026, month: 10, day: 1);
int at(int hour) => DateTime(2026, 10, 1, hour).millisecondsSinceEpoch;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
RecordingDraftContext gapContext(int from, int to) =>
    RecordingDraftContext.gap(date: date, startedAt: at(from), endedAt: at(to));

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> enterTime(WidgetTester tester, String label, String value) async {
  await tap(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tap(tester, '确认');
}

Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
}

Future<void> mount(
  WidgetTester tester,
  AppDatabase db,
  DriftRecordingDraftStore drafts,
) async {
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async => db,
      openDrafts: () async => drafts,
      openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 10, 1)),
      now: () => DateTime(2026, 10, 1, 12),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> mainSleep(WidgetTester tester, AppDatabase db) =>
    tester.runAsync(() async {
      await DriftLedgerRepository(db).createSleepSession(
        id: id(1),
        startedAt: at(0),
        endedAt: at(8),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        now: 1,
      );
    });
Future<void> openGap(WidgetTester tester) async {
  await tap(tester, '打开日账本');
  await tap(tester, '补一笔');
}

void main() {
  testWidgets(
    'empty ordinary entry stays manual but explicit full-day Gap prefills approximate and saves untitled Unknown only after confirmation',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await mount(tester, db, drafts);
      await tap(tester, '补一笔');
      expect(find.text('未填写'), findsNWidgets(2));
      await tap(tester, '保留草稿并返回');
      await openGap(tester);
      expect(find.text('2026-10-01 00:00'), findsOneWidget);
      expect(find.text('2026-10-01 12:00'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始大约'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '结束大约'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '想不起来'))
            .selected,
        isFalse,
      );
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ))!,
        isEmpty,
      );
      await tap(tester, '想不起来');
      await tap(tester, '确认并保存到账本');
      expect(find.text('未知 · 想不起来'), findsOneWidget);
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      final view = tester
          .widget<DayLedgerTimeline>(find.byType(DayLedgerTimeline))
          .view;
      expect(view.accountedDuration.milliseconds, 12 * 3600000);
      expect(
        view.unknownDuration.milliseconds,
        view.accountedDuration.milliseconds,
      );
      final facts = (await tester.runAsync(
        () =>
            DriftLedgerRepository(db)
                .readWindow(startedAt: at(0), endedAt: at(24)),
      ))!;
      expect(facts.timeBlocks, hasLength(1));
      expect(facts.timeBlocks.single.title, isNull);
      expect(
        facts.timeBlocks.single.knowledgeState,
        BlockKnowledgeState.unknown,
      );
      expect(facts.timeBlocks.single.startPrecision, TimePrecision.approximate);
      expect(facts.timeBlocks.single.endPrecision, TimePrecision.approximate);
      expect(
        await tester.runAsync(() => drafts.read(gapContext(0, 12))),
        isNull,
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'empty historical Gap prefills full calendar day; future date exposes no Gap action',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await mount(tester, db, drafts);
      await tester.enterText(find.byType(TextField), '2026-09-30');
      await openGap(tester);
      expect(find.text('2026-09-30 00:00'), findsOneWidget);
      expect(find.text('2026-10-01 00:00'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始大约'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '结束大约'))
            .selected,
        isTrue,
      );
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ))!,
        isEmpty,
      );
      await tap(tester, '保留草稿并返回');
      await tester.enterText(find.byType(TextField), '2026-10-02');
      await tester.pumpAndSettle();
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      expect(find.text('补一笔'), findsNothing);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'Gap partial known draft survives leaving and file reopen, existing precision wins, ordinary draft remains separate, save leaves remainder',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('gap_recording_'),
      ))!;
      addTearDown(
        () => tester.runAsync(() => directory.delete(recursive: true)),
      );
      final dbFile = File('${directory.path}/facts.sqlite');
      final draftFile = File('${directory.path}/drafts.sqlite');
      var db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase(dbFile)),
      ))!;
      var drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase(draftFile)),
      ))!;
      await mainSleep(tester, db);
      final ordinary = RecordingDraftContext.newEntry(date: date);
      await tester.runAsync(
        () => drafts.save(
          RecordingDraft(
            context: ordinary,
            title: '普通入口未保存输入',
            startedAt: at(9),
            endedAt: at(11),
            startPrecision: TimePrecision.exact,
            endPrecision: TimePrecision.exact,
            knowledgeState: BlockKnowledgeState.known,
          ),
        ),
      );
      await mount(tester, db, drafts);
      await openGap(tester);
      await tap(tester, '记得做了什么');
      await tester.enterText(find.byKey(const ValueKey('activity')), '读书');
      await enterTime(tester, '结束时间', '2026-10-01 10:00');
      await tap(tester, '开始准确');
      await tap(tester, '保留草稿并返回');
      expect(
        find.byType(LedgerFactTimelineTile),
        findsOneWidget,
      ); // Only formal sleep.
      expect(
        tester
            .widget<DayLedgerTimeline>(find.byType(DayLedgerTimeline))
            .view
            .unresolvedDuration
            .milliseconds,
        4 * 3600000,
      );
      final draft = (await tester.runAsync(
        () => drafts.read(gapContext(8, 12)),
      ))!;
      expect(draft.endedAt, at(10));
      expect(draft.context.gapEndedAt, at(12));
      expect(draft.startPrecision, TimePrecision.exact);
      expect(
        (await tester.runAsync(() => drafts.read(ordinary)))!.title,
        '普通入口未保存输入',
      );
      await disposeApp(tester);
      db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase(dbFile)),
      ))!;
      drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase(draftFile)),
      ))!;
      await mount(tester, db, drafts);
      await openGap(tester);
      expect(find.text('已恢复上次输入'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('activity')))
            .controller!
            .text,
        '读书',
      );
      expect(find.text('2026-10-01 10:00'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始准确'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '结束大约'))
            .selected,
        isTrue,
      );
      await tap(tester, '确认并保存到账本');
      expect(find.text('读书'), findsOneWidget);
      expect(find.byType(LedgerGapTimelineTile), findsOneWidget);
      final remaining = tester
          .widget<LedgerGapTimelineTile>(find.byType(LedgerGapTimelineTile))
          .gap;
      expect((remaining.startedAt, remaining.endedAt), (at(10), at(12)));
      expect(
        await tester.runAsync(() => drafts.read(gapContext(8, 12))),
        isNull,
      );
      expect(
        (await tester.runAsync(() => drafts.read(ordinary)))!.title,
        '普通入口未保存输入',
      );
      final fact = (await tester.runAsync(
        () =>
            DriftLedgerRepository(db)
                .readWindow(startedAt: at(0), endedAt: at(24)),
      ))!.timeBlocks.single;
      expect(fact.knowledgeState, BlockKnowledgeState.known);
      expect((fact.startedAt, fact.endedAt), (at(8), at(10)));
      expect(
        (fact.startPrecision, fact.endPrecision),
        (TimePrecision.exact, TimePrecision.approximate),
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'stale Gap conflicts atomically with new sleep, retains input and draft until manual correction succeeds',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      await mainSleep(tester, db);
      await mount(tester, db, drafts);
      await openGap(tester);
      await tap(tester, '记得做了什么');
      await tester.enterText(find.byKey(const ValueKey('activity')), '写作');
      final competitor = (await tester.runAsync(
        () => DriftLedgerRepository(db).createSleepSession(
          id: id(2),
          startedAt: at(8),
          endedAt: at(9),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          note: '后来提交的事实',
          now: 2,
        ),
      ))!;
      await tap(tester, '确认并保存到账本');
      expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
      expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
      expect(find.byType(RecordingForm), findsOneWidget);
      expect(
        (await tester.runAsync(() => drafts.read(gapContext(8, 12))))!.title,
        '写作',
      );
      expect(
        (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').get(),
        ))!,
        isEmpty,
      );
      final unchanged = (await tester.runAsync(
        () => DriftLedgerRepository(db).readSleepSession(competitor.id),
      ))!;
      expect(
        (unchanged.startedAt, unchanged.endedAt, unchanged.note),
        (at(8), at(9), '后来提交的事实'),
      );
      await enterTime(tester, '开始时间', '2026-10-01 09:00');
      await tap(tester, '确认并保存到账本');
      expect(find.text('写作'), findsOneWidget);
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      final facts = (await tester.runAsync(
        () =>
            DriftLedgerRepository(db)
                .readWindow(startedAt: at(0), endedAt: at(24)),
      ))!;
      expect(facts.timeBlocks, hasLength(1));
      expect(facts.sleepSessions, hasLength(2));
      expect(facts.timeBlocks.single.startedAt, at(9));
      expect(
        await tester.runAsync(() => drafts.read(gapContext(8, 12))),
        isNull,
      );
      await disposeApp(tester);
    },
  );
  testWidgets(
    'committed Gap cleanup and refresh failures retry only finishing; full-day refresh failure is separately retryable',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final draftDb = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      addTearDown(() => tester.runAsync(db.close));
      addTearDown(() => tester.runAsync(draftDb.close));
      final drafts = _FailingClear(draftDb);
      final repository = DriftLedgerRepository(db);
      final recording = createRecordingLedgerLoader(db);
      var failFinishRead = true;
      var failDayRead = false;
      var creations = 0;
      final saver = RecordingEntrySaver(
        repository: repository,
        drafts: drafts,
        newId: () => id(++creations),
        now: () => at(12),
        refresh: ({required date, required now}) {
          if (failFinishRead) throw StateError('finish read');
          return recording.load(date: date, now: now);
        },
      );
      final full = createDayLedgerLoader(db);
      final loader = DayLedgerLoader(
        resolveDate: full.resolveDate,
        readFacts: (context) {
          if (failDayRead) throw StateError('full day read');
          return full.readFacts(context);
        },
      );
      final observer = RouteObserver<ModalRoute<void>>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: DayLedgerPage(
            loader: loader,
            now: () => at(12),
            dateOfInstant: deviceDateOfInstant,
            routeObserver: observer,
            gapEntry: (context, gap) => RecordingForm(
              context: context,
              store: drafts,
              entrySaver: saver,
              loadSuggestion: () async {
                final ledger = await recording.load(
                  date: context.date,
                  now: at(12),
                );
                return suggestRecordingTime(
                  relation: ledger.context.relation,
                  coverage: ledger.coverage,
                  explicitGap: gap,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '补一笔');
      await tap(tester, '想不起来');
      await tap(tester, '确认并保存到账本');
      expect(find.text('已正式保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('确认并保存到账本'), findsNothing);
      expect(find.text('草稿清理失败，旧草稿仍可能显示；请重试清理。'), findsOneWidget);
      expect(find.text('账本刷新失败，记录已保存；请重试刷新。'), findsOneWidget);
      expect(creations, 1);
      expect(
        (await tester.runAsync(
          () => repository.readWindow(startedAt: at(0), endedAt: at(24)),
        ))!.timeBlocks,
        hasLength(1),
      );
      expect(
        await tester.runAsync(() => draftDb.read(gapContext(0, 12))),
        isNotNull,
      );
      await tap(tester, '继续清理并刷新');
      expect(creations, 1);
      drafts.fail = false;
      failFinishRead = false;
      failDayRead = true;
      await tap(tester, '继续清理并刷新');
      expect(find.byType(RecordingForm), findsNothing);
      expect(find.text('账本读取失败，请重试。'), findsOneWidget);
      expect(find.text('已保存到账本。'), findsOneWidget);
      expect(creations, 1);
      expect(
        await tester.runAsync(() => draftDb.read(gapContext(0, 12))),
        isNull,
      );
      failDayRead = false;
      await tap(tester, '重试读取');
      expect(find.text('未知 · 想不起来'), findsOneWidget);
      expect(find.byType(LedgerGapTimelineTile), findsNothing);
      expect(creations, 1);
      expect(
        (await tester.runAsync(
          () => repository.readWindow(startedAt: at(0), endedAt: at(24)),
        ))!.timeBlocks,
        hasLength(1),
      );
      await disposeApp(tester);
    },
  );
}

class _FailingClear implements RecordingDraftStore {
  _FailingClear(this.inner);
  final RecordingDraftStore inner;
  bool fail = true;
  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) =>
      inner.read(context);
  @override
  Future<void> save(RecordingDraft draft) => inner.save(draft);
  @override
  Future<void> clear(RecordingDraftContext context) {
    if (fail) throw StateError('clear failure');
    return inner.clear(context);
  }
}
