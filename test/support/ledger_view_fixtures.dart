import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

/// 从旧日账本布局测试迁出的投影夹具（P2）：不依赖已删除的旧页面。
String ledgerViewId(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final ledgerViewDayStart = DateTime(2026, 10, 2).millisecondsSinceEpoch;
final ledgerViewDayEnd = DateTime(2026, 10, 3).millisecondsSinceEpoch;
int ledgerViewAt(int minutes) =>
    ledgerViewDayStart + minutes * Duration.millisecondsPerMinute;

DayLedgerView sampleLedgerView({
  bool longText = false,
  bool approximateWake = false,
}) {
  final goal = Goal.create(
    id: ledgerViewId(10),
    name: longText ? List.filled(20, '毕业设计🐾').join() : '毕业设计',
    now: 1,
  );
  return projectDayLedgerView(
    date: CivilDate(year: 2026, month: 10, day: 2),
    relation: LedgerDateRelation.historical,
    dayStartedAt: ledgerViewDayStart,
    nextDayStartedAt: ledgerViewDayEnd,
    now: ledgerViewDayEnd,
    timeBlocks: [
      TimeBlock(
        id: ledgerViewId(1),
        startedAt: ledgerViewAt(440),
        endedAt: ledgerViewAt(480),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '早餐',
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: ledgerViewId(2),
        startedAt: ledgerViewAt(480),
        endedAt: ledgerViewAt(600),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: longText ? List.filled(20, '设计首页🐾').join() : '设计首页',
        goalId: goal.id,
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: ledgerViewId(3),
        startedAt: ledgerViewAt(600),
        endedAt: ledgerViewAt(630),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.unknown,
        title: '只记得出门办事',
        goalId: goal.id,
        createdAt: 1,
        updatedAt: 1,
      ),
      TimeBlock(
        id: ledgerViewId(4),
        startedAt: ledgerViewAt(660),
        endedAt: ledgerViewAt(690),
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '散步',
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    windowSleepSessions: [
      SleepSession(
        // Same ID as breakfast, different formal fact type.
        id: ledgerViewId(1),
        startedAt: ledgerViewAt(-20),
        endedAt: ledgerViewAt(440),
        startPrecision: approximateWake
            ? TimePrecision.exact
            : TimePrecision.approximate,
        endPrecision: approximateWake
            ? TimePrecision.approximate
            : TimePrecision.exact,
        type: SleepType.mainSleep,
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    annotations: [
      RhythmAnnotation(
        id: ledgerViewId(20),
        timeBlockId: ledgerViewId(2),
        state: RhythmState.progress,
        continuationHint: longText
            ? '${List.filled(20, '先画补记弹层🐾').join()}\n打开设计稿，继续核对时间轴。'
            : '先画补记弹层',
        createdAt: 1,
        updatedAt: 1,
      ),
      RhythmAnnotation(
        id: ledgerViewId(21),
        timeBlockId: ledgerViewId(3),
        state: RhythmState.stuck,
        continuationHint: '回想路线\n保留原有内容 🐾',
        createdAt: 1,
        updatedAt: 1,
      ),
      RhythmAnnotation(
        id: ledgerViewId(22),
        timeBlockId: ledgerViewId(4),
        state: RhythmState.recovery,
        createdAt: 1,
        updatedAt: 1,
      ),
    ],
    sleepSummaryCandidates: [],
    goals: [goal],
  );
}

/// 覆盖日摘要 / 首页视觉夹具使用的完整事实集合。
DayLedgerFacts mixedLedgerFacts({bool longText = false}) {
  final view = sampleLedgerView(longText: longText);
  final blocks = view.segments.whereType<TimeBlockSegment>().toList();
  return DayLedgerFacts(
    ledger: SleepLedgerSnapshot(
      windowFacts: LedgerSnapshot(
        timeBlocks: blocks.map((part) => part.source),
        sleepSessions: view.segments.whereType<SleepSessionSegment>().map(
          (part) => part.source,
        ),
        annotations: blocks.map((part) => part.annotation).nonNulls,
      ),
      sleepSummaryCandidates: [
        ...view.sleepSummary.mainSleep.records,
        ...view.sleepSummary.nap.records,
      ],
    ),
    goals: [
      for (final goal in view.goalSummaries)
        Goal.create(id: goal.goalId, name: goal.name, now: 1),
    ],
  );
}
