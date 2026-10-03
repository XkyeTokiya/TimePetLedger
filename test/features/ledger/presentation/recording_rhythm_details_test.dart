import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';

import 'recording_rhythm_test.dart' as support;

Future<void> choice(WidgetTester t, String prefix, Enum? value) =>
    support.tap(t, find.byKey(ValueKey('$prefix-${value?.name ?? 'none'}')));
Future<void> mount(
  WidgetTester t,
  support.Fixture f,
  RecordingDraftContext c,
) async {
  await t.pumpWidget(f.app(c));
  await support.textTap(t, '打开');
}

void main() {
  testWidgets(
    'every optional code maps through single-select UI and real repository',
    (t) async {
      final f = await support.openWidget(t);
      await t.runAsync(
        () => f.source(state: RhythmState.stuck, details: false),
      );
      for (final code in StuckReasonCode.values) {
        await mount(t, f, support.editContext);
        await choice(t, 'stuck-reason', code);
        expect(
          t
              .widget<ChoiceChip>(
                find.byKey(ValueKey('stuck-reason-${code.name}')),
              )
              .selected,
          isTrue,
        );
        await support.textTap(t, '保存更正');
        final result = (await t.runAsync(
          () => f.repo.readTimeBlock(support.id(8)),
        ))!;
        expect(result.annotation!.stuckReasonCode, code);
        expect(
          result.annotation!.stuckReasonText,
          isNull,
        ); // other needs no text.
      }
      for (final method in RecoveryMethod.values) {
        await mount(t, f, support.editContext);
        await support.stateTap(t, RhythmState.recovery);
        await choice(t, 'recovery-method', method);
        await support.textTap(t, '保存更正');
        expect(
          (await t.runAsync(() => f.repo.readTimeBlock(support.id(8))))!
              .annotation!
              .recoveryMethod,
          method,
        );
      }
      for (final quality in RecoveryQuality.values) {
        await mount(t, f, support.editContext);
        await choice(t, 'recovery-quality', quality);
        await support.textTap(t, '保存更正');
        final rows = await t.runAsync(
          () => f.db
              .customSelect('SELECT recovery_quality FROM rhythm_annotations')
              .get(),
        );
        expect(rows!.single.data['recovery_quality'], quality.name);
      }
    },
  );

  testWidgets(
    'new unknown without Goal can save text alone; inactive input survives state changes and leave',
    (t) async {
      final f = await support.openWidget(t);
      await mount(t, f, support.newContext);
      await support.textTap(t, '想不起来');
      await support.stateTap(t, RhythmState.stuck);
      await support.enter(t, 'stuck-reason-text', '  只有文字\n 🐾  ');
      await support.stateTap(t, RhythmState.recovery);
      expect(find.byKey(const ValueKey('stuck-reason-text')), findsNothing);
      await choice(t, 'recovery-method', RecoveryMethod.other);
      await choice(t, 'recovery-quality', RecoveryQuality.readyToContinue);
      await support.stateTap(t, RhythmState.progress);
      expect(find.byKey(const ValueKey('recovery-method-other')), findsNothing);
      await support.stateTap(t, null);
      await support.textTap(t, '保留草稿并返回');
      await mount(t, f, support.newContext);
      await support.stateTap(t, RhythmState.stuck);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('stuck-reason-text')))
            .controller!
            .text,
        '  只有文字\n 🐾  ',
      );
      await support.stateTap(t, RhythmState.recovery);
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('recovery-method-other')),
            )
            .selected,
        isTrue,
      );
      await support.stateTap(t, RhythmState.stuck);
      await support.textTap(t, '确认并保存到账本');
      final saved = (await t.runAsync(
        () => f.repo.readWindow(startedAt: support.start, endedAt: support.end),
      ));
      expect(saved!.timeBlocks, isNotEmpty);
      final annotation = (await t.runAsync(
        () => f.repo.readTimeBlock(saved.timeBlocks.single.id),
      ))!.annotation!;
      expect(annotation.stuckReasonCode, isNull);
      expect(annotation.stuckReasonText, '只有文字\n 🐾');
      expect(annotation.recoveryMethod, RecoveryMethod.other);
      expect(annotation.applicableRecoveryMethod, isNull);
      expect(annotation.recoveryQuality, RecoveryQuality.readyToContinue);
      expect(await t.runAsync(() => f.drafts.read(support.newContext)), isNull);
    },
  );

  testWidgets(
    'explicit individual clearing keeps unrelated fields and TimeBlock unchanged',
    (t) async {
      final f = await support.openWidget(t);
      await t.runAsync(() => f.source(state: RhythmState.stuck));
      final before = (await t.runAsync(
        () => f.repo.readTimeBlock(support.id(8)),
      ))!;
      await mount(t, f, support.editContext);
      await choice(t, 'stuck-reason', null);
      await support.tap(
        t,
        find.byKey(const ValueKey('clear-stuck-reason-text')),
      );
      await support.stateTap(t, RhythmState.recovery);
      await choice(t, 'recovery-method', null);
      await choice(t, 'recovery-quality', null);
      await support.textTap(t, '保留草稿并返回');
      final draft = (await t.runAsync(
        () => f.drafts.read(support.editContext),
      ))!;
      expect([
        draft.stuckReasonCodeProvided,
        draft.stuckReasonTextProvided,
        draft.recoveryMethodProvided,
        draft.recoveryQualityProvided,
      ], everyElement(isTrue));
      await mount(t, f, support.editContext);
      await support.textTap(t, '保存更正');
      final result = (await t.runAsync(
        () => f.repo.readTimeBlock(support.id(8)),
      ))!;
      expect(result.annotation!.stuckReasonCode, isNull);
      expect(result.annotation!.stuckReasonText, isNull);
      expect(result.annotation!.recoveryMethod, isNull);
      expect(result.annotation!.recoveryQuality, isNull);
      expect(result.annotation!.continuationHint, '原接续点');
      expect(result.annotation!.id, before.annotation!.id);
      expect(result.timeBlock.updatedAt, before.timeBlock.updatedAt);
      expect(result.timeBlock.categoryId, '原分类');
    },
  );

  testWidgets(
    'reason text uses domain Unicode boundary; inactive overflow remains visible as feedback; blank clears',
    (t) async {
      final f = await support.openWidget(t);
      await t.runAsync(() => f.source(state: RhythmState.stuck));
      await mount(t, f, support.editContext);
      final tooLong = '  ${'🐾' * 2001}  ';
      await support.enter(t, 'stuck-reason-text', tooLong);
      await support.stateTap(t, RhythmState.progress);
      await support.textTap(t, '保存更正');
      expect(find.textContaining('请切回卡住'), findsOneWidget);
      expect(
        (await t.runAsync(() => f.drafts.read(support.editContext)))!
            .stuckReasonText,
        tooLong,
      );
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(support.id(8))))!
            .annotation!
            .stuckReasonText,
        '原原因',
      );
      await support.stateTap(t, RhythmState.stuck);
      final boundary = '${'🐾' * 1998}\n字';
      await support.enter(t, 'stuck-reason-text', '  $boundary  ');
      await support.textTap(t, '保存更正');
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(support.id(8))))!
            .annotation!
            .stuckReasonText,
        boundary,
      );
      await mount(t, f, support.editContext);
      await support.enter(t, 'stuck-reason-text', ' \n\t ');
      await support.textTap(t, '保存更正');
      expect(
        (await t.runAsync(() => f.repo.readTimeBlock(support.id(8))))!
            .annotation!
            .stuckReasonText,
        isNull,
      );
    },
  );

  testWidgets(
    'real formal transaction failure keeps all raw details then reopen and retry',
    (t) async {
      final f = await support.openWidget(t);
      await t.runAsync(() => f.source(state: RhythmState.stuck));
      final before = await t.runAsync(f.snapshot);
      await t.runAsync(
        () => f.db.customStatement(
          "CREATE TRIGGER fail_details AFTER UPDATE ON rhythm_annotations BEGIN SELECT RAISE(FAIL, 'details fault'); END",
        ),
      );
      await mount(t, f, support.editContext);
      await choice(t, 'stuck-reason', StuckReasonCode.other);
      await support.enter(t, 'stuck-reason-text', '  失败输入 🐾  ');
      await support.stateTap(t, RhythmState.recovery);
      await choice(t, 'recovery-method', RecoveryMethod.shower);
      await choice(t, 'recovery-quality', RecoveryQuality.notRecovered);
      await support.textTap(t, '保存更正');
      expect(await t.runAsync(f.snapshot), before);
      await support.textTap(t, '保留草稿并返回');
      await mount(t, f, support.editContext);
      expect(find.textContaining('请不要再次提交'), findsNothing);
      await support.show(
        t,
        find.byKey(const ValueKey('recovery-method-shower')),
      );
      expect(
        t
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('recovery-method-shower')),
            )
            .selected,
        isTrue,
      );
      await t.runAsync(() => f.db.customStatement('DROP TRIGGER fail_details'));
      await support.textTap(t, '保存更正');
      final a = (await t.runAsync(() => f.repo.readTimeBlock(support.id(8))))!
          .annotation!;
      expect(
        (
          a.stuckReasonCode,
          a.stuckReasonText,
          a.recoveryMethod,
          a.recoveryQuality,
        ),
        (
          StuckReasonCode.other,
          '失败输入 🐾',
          RecoveryMethod.shower,
          RecoveryQuality.notRecovered,
        ),
      );
    },
  );

  test('draft write failure does not formally submit; retry keeps every current detail', () async {
    final queries = support.Queries();
    final f = await support.Fixture.open(draft: queries);
    addTearDown(f.close);
    final c = f.controller(support.newContext);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.unknown);
    c.setRhythmState(RhythmState.stuck);
    c.setStuckReasonCode(StuckReasonCode.anxious);
    c.setStuckReasonText('previous');
    await c.flush();
    queries.failSave = true;
    c.setStuckReasonText('  current 🐾  ');
    c.setRhythmState(RhythmState.recovery);
    c.setRecoveryMethod(RecoveryMethod.askForHelp);
    c.setRecoveryQuality(RecoveryQuality.partlyRecovered);
    expect(await c.submit(), isNull);
    expect(
      (await f.repo.readWindow(
        startedAt: support.start,
        endedAt: support.end,
      )).timeBlocks,
      isEmpty,
    );
    expect(
      (await f.drafts.read(support.newContext))!.stuckReasonText,
      'previous',
    );
    queries.failSave = false;
    await c.retrySave();
    expect(await c.submit(), isNotNull);
    final b = (await f.repo.readWindow(
      startedAt: support.start,
      endedAt: support.end,
    )).timeBlocks.single;
    final a = (await f.repo.readTimeBlock(b.id))!.annotation!;
    expect(a.stuckReasonText, 'current 🐾');
    expect(a.recoveryMethod, RecoveryMethod.askForHelp);
    expect(a.recoveryQuality, RecoveryQuality.partlyRecovered);
    c.dispose();
  });

  test('same state/hint with different details is not a recovered commit; committed details lock duplicate submit', () async {
    final draftQueries = support.Queries();
    final formalQueries = support.Queries();
    final f = await support.Fixture.open(
      draft: draftQueries,
      formal: formalQueries,
    );
    addTearDown(f.close);
    await f.source(state: RhythmState.stuck);
    var c = f.controller(support.editContext);
    await c.initialize();
    c.setStuckReasonText('different details only');
    await c.flush();
    c.dispose();
    c = f.controller(support.editContext);
    await c.initialize();
    expect(c.committed, isNull);
    draftQueries.failClear = true;
    f.failRefresh = true;
    expect(await c.submit(), isNull);
    expect(c.committed, isNotNull);
    c.dispose();
    final writes = formalQueries.writes;
    c = f.controller(support.editContext);
    await c.initialize();
    expect(c.committed, isNotNull);
    expect(c.editable, isFalse);
    expect(await c.submit(), isNull);
    draftQueries.failClear = false;
    f.failRefresh = false;
    expect(await c.retryFinish(), isNotNull);
    expect(formalQueries.writes, writes);
    c.dispose();
  });

  test('omitted fields preserve another writer while one explicitly edited field replaces only itself', () async {
    final f = await support.Fixture.open();
    addTearDown(f.close);
    await f.source(state: RhythmState.stuck);
    final c = f.controller(support.editContext);
    await c.initialize();
    c.setStuckReasonText('my edit');
    await f.repo.updateTimeBlock(
      id: support.id(8),
      now: 2,
      annotation: const EditAnnotation(
        stuckReasonCode: (value: StuckReasonCode.interrupted),
        recoveryMethod: (value: RecoveryMethod.meal),
      ),
    );
    expect(await c.submit(), isNotNull);
    final a = (await f.repo.readTimeBlock(support.id(8)))!.annotation!;
    expect(a.stuckReasonText, 'my edit');
    expect(a.stuckReasonCode, StuckReasonCode.interrupted);
    expect(a.recoveryMethod, RecoveryMethod.meal);
    c.dispose();
  });
  test('new commit recovery rejects each changed detail even with the same stable id, state and hint', () async {
    final queries = support.Queries()..failClear = true;
    final f = await support.Fixture.open(draft: queries);
    addTearDown(f.close);
    final c = f.controller(support.newContext);
    await c.initialize();
    c.setKnowledge(BlockKnowledgeState.unknown);
    c.setRhythmState(RhythmState.stuck);
    c.setStuckReasonCode(StuckReasonCode.anxious);
    c.setStuckReasonText('  matching text 🐾  ');
    c.setRhythmState(RhythmState.recovery);
    c.setRecoveryMethod(RecoveryMethod.meal);
    c.setRecoveryQuality(RecoveryQuality.readyToContinue);
    f.failRefresh = true;
    expect(await c.submit(), isNull);
    final draft = (await f.drafts.read(support.newContext))!;
    final blockId = c.committed!.timeBlock.id;
    const matching = EditAnnotation(
      stuckReasonCode: (value: StuckReasonCode.anxious),
      stuckReasonText: (value: 'matching text 🐾'),
      recoveryMethod: (value: RecoveryMethod.meal),
      recoveryQuality: (value: RecoveryQuality.readyToContinue),
    );
    for (final change in [
      const EditAnnotation(stuckReasonCode: (value: null)),
      const EditAnnotation(stuckReasonText: (value: null)),
      const EditAnnotation(recoveryMethod: (value: null)),
      const EditAnnotation(recoveryQuality: (value: null)),
    ]) {
      await f.repo.updateTimeBlock(id: blockId, now: 2, annotation: matching);
      await f.repo.updateTimeBlock(id: blockId, now: 3, annotation: change);
      expect(await f.saver.recoverCommittedDraft(draft), isNull);
      expect(await f.drafts.read(support.newContext), isNotNull);
    }
    await f.repo.updateTimeBlock(id: blockId, now: 4, annotation: matching);
    queries.failClear = false;
    f.failRefresh = false;
    final recovered = await f.saver.recoverCommittedDraft(draft);
    expect(recovered!.complete, isTrue);
    expect(await f.drafts.read(support.newContext), isNull);
    expect(
      (await f.repo.readWindow(
        startedAt: support.start,
        endedAt: support.end,
      )).timeBlocks,
      hasLength(1),
    );
    c.dispose();
  });
}
