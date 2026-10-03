import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/day_ledger.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/goal_rhythm_summary_view.dart';

import 'day_summary_sleep_test.dart' show database, open, instant, date, id;

Future<void> goal(
  WidgetTester tester,
  AppDatabase db,
  int n,
  String name,
) async {
  await tester.runAsync(
    () => DriftGoalRepository(db).create(id: id(n), name: name, now: 1),
  );
}

Future<void> block(
  WidgetTester tester,
  AppDatabase db,
  int n,
  int start,
  int end, {
  int? goalId,
  RhythmState? state,
  bool approximate = false,
}) async {
  await tester.runAsync(
    () => DriftLedgerRepository(db).createTimeBlock(
      id: id(n),
      startedAt: start,
      endedAt: end,
      startPrecision: approximate
          ? TimePrecision.approximate
          : TimePrecision.exact,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '活动',
      goalId: goalId == null ? null : id(goalId),
      now: 1,
      annotation: state == null
          ? null
          : AddAnnotation(id: id(n + 100), state: state),
    ),
  );
}

Future<GoalRhythmSummaryView> section(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(GoalRhythmSummaryView));
  await tester.pumpAndSettle();
  return tester.widget<GoalRhythmSummaryView>(
    find.byType(GoalRhythmSummaryView),
  );
}

Finder card(int n) => find.byKey(ValueKey('summary-goal-${id(n)}'));
void label(int n, String text) => expect(
  find.descendant(of: card(n), matching: find.text(text)),
  findsOneWidget,
);

void main() {
  testWidgets(
    'same-name archived Goals remain separate; four subsets and global rhythm use independent contributions',
    (tester) async {
      final db = await database(tester);
      await goal(tester, db, 1, '同名');
      await goal(tester, db, 2, '同名');
      await goal(tester, db, 3, '没有记录');
      var cursor = instant(2, 1);
      var number = 10;
      for (final item in [
        (1, RhythmState.progress, 20, true),
        (1, RhythmState.stuck, 60, false),
        (1, RhythmState.recovery, 60, false),
        (1, null, 20, false),
        (2, RhythmState.recovery, 60, false),
        (null, RhythmState.progress, 60, false),
        (null, RhythmState.stuck, 60, true),
        (null, RhythmState.recovery, 60, false),
      ]) {
        final end = cursor + item.$3 * 1000;
        await block(
          tester,
          db,
          number++,
          cursor,
          end,
          goalId: item.$1,
          state: item.$2,
          approximate: item.$4,
        );
        cursor = end;
      }
      await tester.runAsync(
        () => DriftGoalRepository(db).archive(id: id(2), now: 2),
      );
      await open(tester, db, 2, instant(2, 12));
      final view = await section(tester);
      expect(view.goals.map((g) => g.goalId).toSet(), {id(1), id(2)});
      expect(find.text('同名'), findsNWidgets(2));
      expect(find.text('没有记录'), findsNothing);
      label(1, '目标相关：约3 分钟');
      label(1, '明确推进：约少于 1 分钟');
      label(1, '明确卡住：1 分钟');
      label(1, '目标内恢复：1 分钟');
      label(1, '未标记节奏：少于 1 分钟');
      label(2, '已归档');
      label(2, '明确推进：未记录推进');
      label(2, '明确卡住：未记录卡住');
      label(2, '未标记节奏：没有未标记节奏的记录');
      expect(find.text('全局推进：约1 分钟'), findsOneWidget);
      expect(find.text('全局卡住：约2 分钟'), findsOneWidget);
      expect(find.text('全局恢复：3 分钟'), findsOneWidget);
      for (final g in view.goals) {
        expect(
          g.progressDuration.duration.milliseconds +
              g.stuckDuration.duration.milliseconds +
              g.recoveryDuration.duration.milliseconds +
              g.unannotatedDuration.duration.milliseconds,
          g.totalDuration.milliseconds,
        );
      }
      expect(view.goals.first.totalDuration.milliseconds, 160000);
      expect(view.rhythm.progressDuration.duration.milliseconds, 80000);
      expect(view.rhythm.stuckDuration.duration.milliseconds, 120000);
      expect(
        view.rhythm.recoveryDuration.duration.milliseconds,
        180000,
      ); // 未重复加目标恢复。
      final loaded = (await tester.runAsync(
        () =>
            createDayLedgerLoader(db).load(date: date(2), now: instant(2, 12)),
      ))!;
      expect(loaded.accountedDuration.milliseconds, 400000);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('无目标'), findsNothing);
    },
  );

  testWidgets(
    'empty and unannotated-only Goals preserve missing labels and positive subminute recovery',
    (tester) async {
      final db = await database(tester);
      await goal(tester, db, 1, '未标记');
      await goal(tester, db, 2, '恢复');
      await open(tester, db, 2, instant(2, 12));
      await section(tester);
      expect(find.text('这段时间还没有目标相关记录'), findsOneWidget);
      expect(find.text('全局推进：未记录推进'), findsOneWidget);
      expect(find.text('全局卡住：未记录卡住'), findsOneWidget);
      expect(find.text('全局恢复：未记录恢复'), findsOneWidget);
      await block(
        tester,
        db,
        10,
        instant(2, 1),
        instant(2, 1) + 20000,
        goalId: 1,
      );
      await block(
        tester,
        db,
        11,
        instant(2, 2),
        instant(2, 2) + 20000,
        goalId: 2,
        state: RhythmState.recovery,
        approximate: true,
      );
      await tester.ensureVisible(find.text('刷新摘要'));
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      final view = await section(tester);
      label(1, '目标相关：少于 1 分钟');
      label(1, '明确推进：未记录推进');
      label(1, '明确卡住：未记录卡住');
      label(1, '目标内恢复：未记录恢复');
      label(1, '未标记节奏：少于 1 分钟');
      label(2, '目标内恢复：约少于 1 分钟');
      label(2, '未标记节奏：没有未标记节奏的记录');
      expect(view.rhythm.progressDuration.hasRecords, isFalse);
      expect(view.rhythm.recoveryDuration.hasRecords, isTrue);
      expect(find.text('全局恢复：约少于 1 分钟'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '2026-10-03');
      await tester.pumpAndSettle();
      await section(tester);
      expect(find.text('这段时间还没有目标相关记录'), findsOneWidget);
      expect(find.text('全局恢复：未记录恢复'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh reads current rename and archive metadata; long names wrap on narrow screen',
    (tester) async {
      final db = await database(tester);
      await goal(tester, db, 1, '同名');
      await goal(tester, db, 2, '同名');
      await block(tester, db, 10, instant(2, 1), instant(2, 2), goalId: 1);
      await block(tester, db, 11, instant(2, 2), instant(2, 3), goalId: 2);
      await open(tester, db, 2, instant(2, 12));
      final old = (await section(tester)).goals;
      final longName = '目标' * 100;
      await tester.runAsync(() async {
        final repo = DriftGoalRepository(db);
        await repo.rename(id: id(1), name: longName, now: 2);
        await repo.archive(id: id(1), now: 3);
      });
      await tester.ensureVisible(find.text('刷新摘要'));
      await tester.tap(find.text('刷新摘要'));
      await tester.pumpAndSettle();
      await section(tester);
      label(1, longName);
      label(1, '已归档');
      label(2, '同名');
      expect(old.first.name, '同名');
      expect(old.first.isArchived, isFalse);
      await tester.binding.setSurfaceSize(const Size(360, 700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(card(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final nameText = tester.widget<Text>(find.text(longName));
      expect(nameText.maxLines, isNull);
      expect(nameText.overflow, isNot(TextOverflow.ellipsis));
    },
  );
}
