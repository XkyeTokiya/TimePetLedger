import '../support/recording_fields.dart';

import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';

import 'review_form_entry_test.dart' show settleNative;
import '../support/ledger_date_selection.dart';
import '../support/root_navigation.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/checked_sleep_opening.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

const sleepId = '00000000-0000-4000-8000-000000000001';
const earlierBlockId = '00000000-0000-4000-8000-000000000002';
final today = CivilDate(year: 2026, month: 9, day: 29);
final yesterday = CivilDate(year: 2026, month: 9, day: 28);

int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

Future<void> tapVisible(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) {
    return;
  }
  final target = text == '更正完整记录' || text == '删除完整时间记录'
      ? find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is LedgerFactTimelineTile &&
                widget.segment is TimeBlockSegment,
          ),
          matching: find.byTooltip(text == '删除完整时间记录' ? '删除记录' : text),
        )
      : find.text(text);
  tester.testTextInput.hide();
  await settleNative(tester);
  if (target.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await settleNative(tester);
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await settleNative(tester);
  await tester.tap(target.first);
  await settleNative(tester);
}

Future<void> enterTime(WidgetTester tester, String label, String value) async {
  await revealRecordingField(tester, label);
  await tapVisible(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tapVisible(tester, '确认');
}

void main() {
  testWidgets(
    'sleep-only today suggests tail; mixed precision survives draft, save, edit and delete',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final repository = DriftLedgerRepository(db);
      await tester.runAsync(
        () => repository.createSleepSession(
          id: sleepId,
          startedAt: at(29, 8),
          endedAt: at(29, 9),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        ),
      );
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, '查看记录');
      expect(ledgerFactCount(tester, '睡眠'), 1);
      expect(ledgerDuration('已交代', '1 小时'), findsOneWidget);
      await tapVisible(tester, '记录活动');
      expect(
        recordingTimeSummaryContaining('2026-09-29 09:00'),
        findsOneWidget,
      );
      expect(
        recordingTimeSummaryContaining('2026-09-29 12:00'),
        findsOneWidget,
      );
      expect(find.text('选择要补记的时间，也可以手动填写：'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始大约'))
            .selected,
        isTrue,
      );
      await enterTime(tester, '结束时间', '2026-09-29 10:00');
      await tapVisible(tester, '结束准确');
      await tapVisible(tester, '记得做了什么');
      await tester.enterText(find.byKey(const ValueKey('activity')), '读书');
      await tester.pumpAndSettle();
      final draft = (await tester.runAsync(
        () => drafts.read(RecordingDraftContext.newEntry(date: today)),
      ))!;
      expect(draft.startedAt, at(29, 9));
      expect(draft.endedAt, at(29, 10));
      expect(draft.startPrecision, TimePrecision.approximate);
      expect(draft.endPrecision, TimePrecision.exact);
      expect(
        (await tester.runAsync(
          () => repository.readWindow(startedAt: at(29, 0), endedAt: at(30, 0)),
        ))!.timeBlocks,
        isEmpty,
      );
      await tapVisible(tester, '保存到账本');
      expect(ledgerDuration('已交代', '约2 小时'), findsOneWidget);
      expect(ledgerFactCount(tester, '睡眠'), 1);
      expect(
        find.byTooltip('约2026-09-29 09:00 → 2026-09-29 10:00'),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(
          () => drafts.read(RecordingDraftContext.newEntry(date: today)),
        ),
        isNull,
      );
      final saved = (await tester.runAsync(
        () => repository.readWindow(startedAt: at(29, 0), endedAt: at(30, 0)),
      ))!;
      expect(saved.sleepSessions, hasLength(1));
      expect(saved.timeBlocks, hasLength(1));
      final id = saved.timeBlocks.single.id;
      expect(saved.timeBlocks.single.goalId, isNull);
      expect(saved.timeBlocks.single.categoryId, isNull);
      expect(saved.annotations, isEmpty);
      expect(saved.timeBlocks.single.startPrecision, TimePrecision.approximate);
      expect(saved.timeBlocks.single.endPrecision, TimePrecision.exact);

      await tapVisible(tester, '更正完整记录');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '结束准确'))
            .selected,
        isTrue,
      );
      await tapVisible(tester, '想不起来');
      await tapVisible(tester, '保存更正');
      expect(find.text('其中想不起来：约1 小时（已含在已交代中）'), findsOneWidget);
      expect(find.text('想不起来 · 已交代'), findsOneWidget);
      expect(find.text('读书'), findsOneWidget);
      final corrected = (await tester.runAsync(
        () => repository.readTimeBlock(id),
      ))!;
      expect(corrected.timeBlock.id, id);
      expect(corrected.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
      expect(corrected.timeBlock.title, '读书');
      expect(corrected.timeBlock.endPrecision, TimePrecision.exact);
      await tapVisible(tester, '删除完整时间记录');
      await tapVisible(tester, '删除记录');
      expect(ledgerDuration('已交代', '1 小时'), findsOneWidget);
      expect(ledgerDuration('尚未记录', '11 小时'), findsOneWidget);
      expect(ledgerFactCount(tester, '睡眠'), 1);
      expect(ledgerFactCount(tester, '普通'), 0);
      expect(await tester.runAsync(() => repository.readTimeBlock(id)), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'historical candidate requires choice; invalid and sleep conflict can be corrected',
    (tester) async {
      final db = (await tester.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final drafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final repository = DriftLedgerRepository(db);
      await tester.runAsync(() async {
        await repository.createSleepSession(
          id: sleepId,
          startedAt: at(28, 10),
          endedAt: at(28, 11),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        );
        await repository.createTimeBlock(
          id: earlierBlockId,
          startedAt: at(28, 13),
          endedAt: at(28, 14),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '已有活动',
          now: 1,
        );
      });
      await tester.pumpWidget(
        AppBootstrap(
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 9, 29)),
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          now: () => DateTime(2026, 9, 29, 12),
        ),
      );
      await tester.pumpAndSettle();
      await selectLedgerDate(tester, '2026-09-28');
      await tapVisible(tester, '记录活动');
      expect(find.text('选择要补记的时间，也可以手动填写：'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('结束时间'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, '未填写'), findsNWidgets(2));
      await tapVisible(
        tester,
        '${formatRecordingTime(at(28, 11))} → ${formatRecordingTime(at(28, 13))}',
      );
      expect(
        recordingTimeSummaryContaining('2026-09-28 11:00'),
        findsOneWidget,
      );
      await tapVisible(tester, '记得做了什么');
      await tapVisible(tester, '保存到账本');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('activity')),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('请填写活动内容。'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('activity')), '整理');
      await enterTime(tester, '开始时间', '2026-09-28 10:30');
      await enterTime(tester, '结束时间', '2026-09-28 12:00');
      await tapVisible(tester, '保存到账本');
      expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
      expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
      expect(find.text('已保存到账本。'), findsNothing);
      final failedDraft = (await tester.runAsync(
        () => drafts.read(RecordingDraftContext.newEntry(date: yesterday)),
      ))!;
      expect(failedDraft.startedAt, at(28, 10, 30));
      expect(failedDraft.title, '整理');
      expect(
        (await tester.runAsync(
          () => repository.readWindow(startedAt: at(28, 0), endedAt: at(29, 0)),
        ))!.timeBlocks,
        hasLength(1),
      );
      await enterTime(tester, '开始时间', '2026-09-28 11:00');
      await tapVisible(tester, '保存到账本');
      expect(find.text('已保存到账本。'), findsOneWidget);
      expect(ledgerDuration('已交代', '约3 小时'), findsOneWidget);
      final saved = (await tester.runAsync(
        () => repository.readWindow(startedAt: at(28, 0), endedAt: at(29, 0)),
      ))!;
      expect(saved.timeBlocks, hasLength(2));
      expect(saved.sleepSessions, hasLength(1));
      expect(saved.annotations, isEmpty);
      expect(
        saved.timeBlocks
            .singleWhere((block) => block.id != earlierBlockId)
            .goalId,
        isNull,
      );
      expect(
        await tester.runAsync(
          () => drafts.read(RecordingDraftContext.newEntry(date: yesterday)),
        ),
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
