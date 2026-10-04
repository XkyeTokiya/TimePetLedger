import '../../../support/recording_fields.dart';

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
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 1);
final start = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 1, 11).millisecondsSinceEpoch;
final editContext = RecordingDraftContext.edit(date: date, timeBlockId: id(8));
final newContext = RecordingDraftContext.newEntry(date: date);

class Queries extends QueryInterceptor {
  bool failClear = false;
  bool failSave = false;
  int writes = 0;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failSave && sql.contains('INSERT INTO recording_drafts')) {
      throw StateError('draft save');
    }
    if (failClear && sql.startsWith('DELETE FROM recording_drafts')) {
      throw StateError('cleanup');
    }
    return executor.runCustom(sql, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runInsert(sql, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runUpdate(sql, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    writes++;
    return executor.runDelete(sql, args);
  }
}

class Fixture {
  Fixture(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  late final repo = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  late final loader = RecordingLedgerLoader(
    repository: repo,
    resolveDate: resolveDeviceRecordingDate,
  );
  int ids = 100;
  bool failRefresh = false;
  late final saver = RecordingEntrySaver(
    repository: repo,
    drafts: drafts,
    refresh: ({required date, required now}) {
      if (failRefresh) throw StateError('refresh');
      return loader.load(date: date, now: now);
    },
    newId: () => id(ids++),
    now: () => end + 1,
  );
  late final editor = RecordingEntryEditor(
    repository: repo,
    drafts: drafts,
    saver: saver,
  );
  static Future<Fixture> open({Queries? formal, Queries? draft}) async =>
      Fixture(
        await AppDatabase.open(
          formal == null
              ? NativeDatabase.memory()
              : NativeDatabase.memory().interceptWith(formal),
        ),
        await DriftRecordingDraftStore.open(
          draft == null
              ? NativeDatabase.memory()
              : NativeDatabase.memory().interceptWith(draft),
        ),
      );
  Future<void> close() async {
    await drafts.close();
    await db.close();
  }

  Future<void> source({
    RhythmState? state,
    bool details = true,
  }) => repo.createTimeBlock(
    id: id(8),
    startedAt: start,
    endedAt: end,
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '原活动',
    note: '原备注',
    categoryId: '原分类',
    now: 1,
    annotation: state == null
        ? null
        : AddAnnotation(
            id: id(7),
            state: state,
            continuationHint: '原接续点',
            stuckReasonCode: details ? StuckReasonCode.unclearNextStep : null,
            stuckReasonText: details ? '原原因' : null,
            recoveryMethod: details ? RecoveryMethod.walk : null,
            recoveryQuality: details ? RecoveryQuality.partlyRecovered : null,
          ),
  );
  RecordingFormController controller(RecordingDraftContext context) =>
      RecordingFormController(
        context: context,
        store: drafts,
        entrySaver: saver,
        entryEditor: editor,
        goals: goals,
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
                entrySaver: saver,
                entryEditor: editor,
                goals: goals,
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
  Future<List<Object?>> snapshot() async => [
    for (final table in [
      'time_blocks',
      'rhythm_annotations',
      'goals',
      'sleep_sessions',
      'daily_reviews',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  ];
}

Future<Fixture> openWidget(WidgetTester t) async {
  final f = (await t.runAsync(Fixture.open))!;
  addTearDown(f.close);
  return f;
}

Future<void> show(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await t.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    final position = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
      position.jumpTo(
        (position.pixels + 160).clamp(0, position.maxScrollExtent),
      );
      await t.pumpAndSettle();
    }
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder target) async {
  await show(t, target);
  await t.tap(target.first);
  await t.pumpAndSettle();
}

Future<void> textTap(WidgetTester t, String text) async {
  if (['保留草稿并返回', '放弃草稿'].contains(text) &&
      find.text(text).evaluate().isEmpty) {
    await t.tap(find.byTooltip('更多'));
    await t.pumpAndSettle();
  }
  if (text == '选择目标' && find.text(text).evaluate().isEmpty) {
    await tap(t, find.byKey(const ValueKey('recording-goal-toggle')));
  }
  await revealRecordingField(t, text);
  await tap(t, find.text(text));
}

Future<void> stateTap(WidgetTester t, RhythmState? state) async {
  if (find
      .byKey(ValueKey('rhythm-${state?.name ?? 'none'}'))
      .evaluate()
      .isEmpty) {
    await tap(t, find.byKey(const ValueKey('recording-rhythm-toggle')));
  }
  await tap(t, find.byKey(ValueKey('rhythm-${state?.name ?? 'none'}')));
}

Future<void> enter(WidgetTester t, String key, String value) async {
  await revealRecordingField(t, key);
  final target = find.byKey(ValueKey(key));
  await show(t, target);
  await t.enterText(target, value);
  await t.pumpAndSettle();
}

void main() {
  test('all knowledge/Goal/state combinations create only the requested optional annotation without details', () async {
    for (final knowledge in BlockKnowledgeState.values) {
      for (final withGoal in [false, true]) {
        for (final state in [null, ...RhythmState.values]) {
          final f = await Fixture.open();
          try {
            if (withGoal) await f.goals.create(id: id(1), name: '目标', now: 1);
            final c = f.controller(newContext);
            await c.initialize();
            c.setTitle('午饭');
            c.setKnowledge(knowledge);
            if (withGoal) c.selectGoal(id(1));
            if (state != null) c.setRhythmState(state);
            await c.submit();
            expect(c.committed!.complete, isTrue);
            final saved = (await f.repo.readTimeBlock(
              c.committed!.timeBlock.id,
            ))!;
            expect(saved.timeBlock.goalId, withGoal ? id(1) : null);
            expect(saved.timeBlock.knowledgeState, knowledge);
            expect(saved.timeBlock.startPrecision, TimePrecision.approximate);
            expect(saved.annotation?.state, state);
            expect(saved.annotation?.stuckReasonCode, isNull);
            expect(saved.annotation?.recoveryMethod, isNull);
            expect(saved.annotation?.continuationHint, isNull);
            c.dispose();
          } finally {
            await f.close();
          }
        }
      }
    }
  });

  for (final from in RhythmState.values) {
    for (final to in RhythmState.values.where((s) => s != from)) {
      testWidgets(
        '$from -> $to changes only annotation, retains hidden details and continuation',
        (t) async {
          final f = await openWidget(t);
          await t.runAsync(() => f.source(state: from));
          final before = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
          await t.pumpWidget(f.app(editContext));
          await textTap(t, '打开');
          await stateTap(t, to);
          if (to == RhythmState.stuck) {
            expect(
              t
                  .widget<ChoiceChip>(
                    find.byKey(const ValueKey('stuck-reason-unclearNextStep')),
                  )
                  .selected,
              isTrue,
            );
            expect(
              t
                  .widget<TextField>(
                    find.byKey(const ValueKey('stuck-reason-text')),
                  )
                  .controller!
                  .text,
              '原原因',
            );
            expect(
              find.byKey(const ValueKey('recovery-method-walk')),
              findsNothing,
            );
          } else if (to == RhythmState.recovery) {
            expect(
              t
                  .widget<ChoiceChip>(
                    find.byKey(const ValueKey('recovery-method-walk')),
                  )
                  .selected,
              isTrue,
            );
            expect(
              t
                  .widget<ChoiceChip>(
                    find.byKey(
                      const ValueKey('recovery-quality-partlyRecovered'),
                    ),
                  )
                  .selected,
              isTrue,
            );
            expect(
              find.byKey(const ValueKey('stuck-reason-unclearNextStep')),
              findsNothing,
            );
          } else {
            expect(
              find.byKey(const ValueKey('recovery-method-walk')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('stuck-reason-unclearNextStep')),
              findsNothing,
            );
          }
          await revealRecordingField(t, 'continuation-hint');
          await show(t, find.byKey(const ValueKey('continuation-hint')));
          expect(
            t
                .widget<TextField>(
                  find.byKey(const ValueKey('continuation-hint')),
                )
                .controller!
                .text,
            '原接续点',
          );
          expect(await t.runAsync(f.snapshot), isNotEmpty);
          expect(
            (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!
                .annotation!
                .state,
            from,
          );
          await textTap(t, '保存更正');
          final after = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
          expect(after.timeBlock.updatedAt, before.timeBlock.updatedAt);
          expect(after.timeBlock.startedAt, before.timeBlock.startedAt);
          expect(after.timeBlock.categoryId, '原分类');
          expect(after.annotation!.id, id(7));
          expect(after.annotation!.createdAt, 1);
          expect(after.annotation!.state, to);
          expect(after.annotation!.updatedAt, end + 1);
          expect(
            after.annotation!.stuckReasonCode,
            StuckReasonCode.unclearNextStep,
          );
          expect(after.annotation!.stuckReasonText, '原原因');
          expect(after.annotation!.recoveryMethod, RecoveryMethod.walk);
          expect(
            after.annotation!.recoveryQuality,
            RecoveryQuality.partlyRecovered,
          );
          expect(after.annotation!.continuationHint, '原接续点');
        },
      );
    }
  }

  for (final state in RhythmState.values) {
    testWidgets(
      '$state hint accepts 2000 runes, keeps raw draft across states and blank clears only the hint',
      (t) async {
        final f = await openWidget(t);
        await t.pumpWidget(f.app(newContext));
        await textTap(t, '打开');
        await textTap(t, '想不起来');
        await stateTap(t, state);
        final text = '  ${'🐾' * 1998}\n中  ';
        await enter(t, 'continuation-hint', text);
        await stateTap(t, RhythmState.values.firstWhere((s) => s != state));
        await stateTap(t, null);
        await stateTap(t, state);
        await revealRecordingField(t, 'continuation-hint');
        await show(t, find.byKey(const ValueKey('continuation-hint')));
        expect(
          t
              .widget<TextField>(
                find.byKey(const ValueKey('continuation-hint')),
              )
              .controller!
              .text,
          text,
        );
        await textTap(t, '保留草稿并返回');
        final draft = (await t.runAsync(() => f.drafts.read(newContext)))!;
        expect(draft.continuationHint, text);
        expect(draft.annotationIntent, RecordingAnnotationIntent.add);
        await textTap(t, '打开');
        await revealRecordingField(t, 'continuation-hint');
        await show(t, find.byKey(const ValueKey('continuation-hint')));
        expect(
          t
              .widget<TextField>(
                find.byKey(const ValueKey('continuation-hint')),
              )
              .controller!
              .text,
          text,
        );
        await textTap(t, '保存到账本');
        final saved = (await t.runAsync(() => f.repo.readTimeBlock(id(101))))!;
        expect(saved.annotation!.id, draft.annotationId);
        expect(saved.annotation!.continuationHint, text.trim());
        final context = RecordingDraftContext.edit(
          date: date,
          timeBlockId: saved.timeBlock.id,
        );
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
        await t.pumpWidget(f.app(context));
        await textTap(t, '打开');
        await enter(t, 'continuation-hint', ' \n ');
        await textTap(t, '保存更正');
        final cleared = (await t.runAsync(
          () => f.repo.readTimeBlock(saved.timeBlock.id),
        ))!;
        expect(cleared.annotation!.state, state);
        expect(cleared.annotation!.continuationHint, isNull);
        expect(cleared.timeBlock.updatedAt, saved.timeBlock.updatedAt);
      },
    );
  }

  testWidgets(
    'oversized raw hint survives failed validation; correcting it permits save',
    (t) async {
      final f = await openWidget(t);
      await t.pumpWidget(f.app(newContext));
      await textTap(t, '打开');
      await textTap(t, '想不起来');
      await stateTap(t, RhythmState.stuck);
      await enter(t, 'continuation-hint', '🐾' * 2001);
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      expect(find.text('接续点最多 2000 个字符。'), findsOneWidget);
      await textTap(t, '保存到账本');
      expect(find.text('请确认活动和时间后再保存。'), findsOneWidget);
      expect(
        (await t.runAsync(() => f.drafts.read(newContext)))!.continuationHint,
        '🐾' * 2001,
      );
      expect(
        (await t.runAsync(
          () => f.repo.readWindow(startedAt: start, endedAt: end),
        ))!.timeBlocks,
        isEmpty,
      );
      await enter(t, 'continuation-hint', '修正\n保留内部格式');
      await textTap(t, '保存到账本');
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(101))))!
            .annotation!
            .continuationHint,
        '修正\n保留内部格式',
      );
    },
  );

  testWidgets(
    'explicit remove leaves fact identity, metadata and coverage unchanged',
    (t) async {
      final f = await openWidget(t);
      await t.runAsync(() => f.source(state: RhythmState.stuck));
      final before = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!
          .timeBlock;
      final coverage = (await t.runAsync(
        () => f.loader.load(date: date, now: end + 1),
      ))!.coverage.accountedDuration.milliseconds;
      await t.pumpWidget(f.app(editContext));
      await textTap(t, '打开');
      await stateTap(t, null);
      expect(find.byKey(const ValueKey('continuation-hint')), findsNothing);
      await textTap(t, '保留草稿并返回');
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!.annotation,
        isNotNull,
      );
      await textTap(t, '打开');
      await textTap(t, '保存更正');
      final after = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
      expect(after.annotation, isNull);
      expect(after.timeBlock.id, before.id);
      expect(after.timeBlock.updatedAt, before.updatedAt);
      expect(after.timeBlock.title, before.title);
      expect(
        (await t.runAsync(() => f.loader.load(date: date, now: end + 1)))!
            .coverage
            .accountedDuration
            .milliseconds,
        coverage,
      );
    },
  );

  for (final operation in ['add', 'edit', 'remove']) {
    testWidgets(
      '$operation SQL failure rolls back combined TimeBlock change, keeps draft, retries atomically',
      (t) async {
        final f = await openWidget(t);
        await t.runAsync(
          () => f.source(state: operation == 'add' ? null : RhythmState.stuck),
        );
        final before = await t.runAsync(f.snapshot);
        final sqlOperation = switch (operation) {
          'add' => 'INSERT',
          'edit' => 'UPDATE',
          _ => 'DELETE',
        };
        await t.runAsync(
          () => f.db.customStatement(
            "CREATE TEMP TRIGGER reject_rhythm AFTER $sqlOperation ON rhythm_annotations BEGIN SELECT RAISE(FAIL,'failure'); END",
          ),
        );
        await t.pumpWidget(f.app(editContext));
        await textTap(t, '打开');
        await enter(t, 'activity', '原活动改动');
        await stateTap(t, operation == 'remove' ? null : RhythmState.recovery);
        if (operation != 'remove') {
          await enter(t, 'continuation-hint', '保存失败不能丢');
        }
        await textTap(t, '保存更正');
        expect(find.text('正式保存失败，输入和草稿已保留，请重试。'), findsOneWidget);
        expect(await t.runAsync(f.snapshot), before);
        expect(
          (await t.runAsync(() => f.drafts.read(editContext)))!
              .annotationIntent,
          switch (operation) {
            'add' => RecordingAnnotationIntent.add,
            'edit' => RecordingAnnotationIntent.edit,
            _ => RecordingAnnotationIntent.remove,
          },
        );
        await t.runAsync(
          () => f.db.customStatement('DROP TRIGGER reject_rhythm'),
        );
        await textTap(t, '保存更正');
        final after = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
        expect(after.timeBlock.title, '原活动改动');
        expect(
          after.annotation?.state,
          operation == 'remove' ? null : RhythmState.recovery,
        );
        expect(
          (await t.runAsync(
            () => f.db.customSelect('SELECT * FROM rhythm_annotations').get(),
          ))!.length,
          operation == 'remove' ? 0 : 1,
        );
      },
    );
  }

  testWidgets(
    'combined time conflict keeps both formal objects; manual correction saves both',
    (t) async {
      final f = await openWidget(t);
      await t.runAsync(() async {
        await f.source(state: RhythmState.stuck);
        await f.repo.createSleepSession(
          id: id(6),
          startedAt: end,
          endedAt: end + 3600000,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        );
      });
      final before = await t.runAsync(f.snapshot);
      await t.pumpWidget(f.app(editContext));
      await textTap(t, '打开');
      await stateTap(t, RhythmState.progress);
      await textTap(t, '结束时间');
      await enter(t, 'time-dialog-input', '2026-10-01 11:30');
      await textTap(t, '确认');
      await textTap(t, '应用时间');
      await textTap(t, '保存更正');
      expect(find.textContaining('重叠区间为'), findsOneWidget);
      expect(await t.runAsync(f.snapshot), before);
      await textTap(t, '调整当前记录时间');
      await textTap(t, '结束时间');
      await enter(t, 'time-dialog-input', '2026-10-01 11:00');
      await textTap(t, '确认');
      await textTap(t, '应用时间');
      await textTap(t, '保存更正');
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!
            .annotation!
            .state,
        RhythmState.progress,
      );
    },
  );

  for (final duplicate in [true, false]) {
    testWidgets(
      '${duplicate ? 'duplicate add' : 'missing edit'} preserves explicit intent and reports correct relation failure',
      (t) async {
        final f = await openWidget(t);
        await t.runAsync(
          () => f.source(state: duplicate ? null : RhythmState.stuck),
        );
        await t.pumpWidget(f.app(editContext));
        await textTap(t, '打开');
        await stateTap(t, RhythmState.progress);
        await enter(t, 'activity', '不应提前改写');
        await t.runAsync(
          () => f.repo.updateTimeBlock(
            id: id(8),
            now: 2,
            annotation: duplicate
                ? AddAnnotation(id: id(5), state: RhythmState.progress)
                : const RemoveAnnotation(),
          ),
        );
        final before = await t.runAsync(f.snapshot);
        await textTap(t, '保存更正');
        expect(
          find.text(
            duplicate
                ? '此记录已有节奏解释，请重新打开后编辑；输入和草稿已保留。'
                : '节奏解释已不存在，请重新打开后添加；输入和草稿已保留。',
          ),
          findsOneWidget,
        );
        expect(await t.runAsync(f.snapshot), before);
        expect(
          (await t.runAsync(() => f.drafts.read(editContext)))!
              .annotationIntent,
          duplicate
              ? RecordingAnnotationIntent.add
              : RecordingAnnotationIntent.edit,
        );
        await textTap(t, '保留草稿并返回');
        await textTap(t, '打开');
        // Restored intent stays add/edit; merely reopening must not silently upsert.
        await textTap(t, '保存更正');
        expect(await t.runAsync(f.snapshot), before);
        await stateTap(t, RhythmState.progress);
        await textTap(t, '保存更正');
        expect(
          (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!
              .timeBlock
              .title,
          '不应提前改写',
        );
      },
    );
  }

  test('draft storage failure keeps raw annotation input and old draft; retry persists before formal save', () async {
    final draft = Queries();
    final f = await Fixture.open(draft: draft);
    addTearDown(f.close);
    final c = f.controller(newContext);
    addTearDown(c.dispose);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.unknown);
    await c.flush();
    draft.failSave = true;
    c.setRhythmState(RhythmState.stuck);
    c.setContinuationHint('  原始接续点\n🐾  ');
    expect(await c.flush(), isFalse);
    final before = await f.snapshot();
    expect(await c.submit(), isNull);
    expect(c.continuationHint, '  原始接续点\n🐾  ');
    expect(c.annotationIntent, RecordingAnnotationIntent.add);
    expect(
      (await f.drafts.read(newContext))!.annotationIntent,
      RecordingAnnotationIntent.keep,
    );
    expect(await f.snapshot(), before);
    draft.failSave = false;
    expect(await c.retrySave(), isTrue);
    await c.submit();
    expect(c.committed!.complete, isTrue);
    expect(
      (await f.repo.readTimeBlock(c.committed!.timeBlock.id))!
          .annotation!
          .continuationHint,
      '原始接续点\n🐾',
    );
  });

  test(
    'deleted original cannot be recreated from restored annotation draft',
    () async {
      final f = await Fixture.open();
      addTearDown(f.close);
      await f.source(state: RhythmState.stuck);
      var c = f.controller(editContext);
      await c.initialize();
      c.setRhythmState(RhythmState.progress);
      c.setContinuationHint('保留输入');
      await c.flush();
      c.dispose();
      await f.repo.deleteTimeBlock(id(8));
      c = f.controller(editContext);
      await c.initialize();
      expect(c.missingOriginal, isTrue);
      expect(c.editable, isFalse);
      expect(await c.submit(), isNull);
      expect((await f.drafts.read(editContext))!.continuationHint, '保留输入');
      expect(await f.repo.readTimeBlock(id(8)), isNull);
      c.dispose();
    },
  );

  for (final operation in ['create', 'add', 'edit', 'remove']) {
    test(
      '$operation commit with cleanup/refresh failures recovers and finishes without any repeated SQL write',
      () async {
        final formal = Queries(), draft = Queries()..failClear = true;
        final f = await Fixture.open(formal: formal, draft: draft);
        addTearDown(f.close);
        if (operation != 'create') {
          await f.source(state: operation == 'add' ? null : RhythmState.stuck);
        }
        final context = operation == 'create' ? newContext : editContext;
        var c = f.controller(context);
        await c.initialize();
        if (operation == 'create') c.setKnowledge(BlockKnowledgeState.unknown);
        c.setRhythmState(operation == 'remove' ? null : RhythmState.progress);
        if (operation != 'remove') c.setContinuationHint('已提交接续点');
        f.failRefresh = true;
        await c.submit();
        expect(c.committed, isNotNull);
        expect(c.committed!.draftCleared, isFalse);
        expect(c.committed!.refreshed, isNull);
        final writes = formal.writes;
        c.dispose();
        c = f.controller(context);
        await c.initialize();
        expect(c.committed, isNotNull);
        expect(c.editable, isFalse);
        expect(await c.submit(), isNull);
        draft.failClear = false;
        f.failRefresh = false;
        await c.retryFinish();
        expect(c.committed!.complete, isTrue);
        expect(formal.writes, writes);
        expect(await f.drafts.read(context), isNull);
        c.dispose();
      },
    );
  }
}
