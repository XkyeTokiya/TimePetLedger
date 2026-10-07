import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/settings/data/drift_data_maintenance.dart';
import 'package:time_pet_ledger/features/settings/domain/data_overview.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

int at2026(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;

DateTime civilDayOf(int milliseconds) {
  final value = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return DateTime(value.year, value.month, value.day);
}

Future<AppDatabase> openEmpty() => AppDatabase.open(NativeDatabase.memory());

void main() {
  test('seed covers the click day and the six days before it', () async {
    final db = await openEmpty();
    addTearDown(db.close);
    final maintenance = DriftDataMaintenance(db);
    var nextId = 1;
    final now = at2026(7, 15);
    await maintenance.seed(
      newGoalId: () => id(nextId++),
      newFactId: () => id(nextId++),
      now: now,
    );

    final counts = await maintenance.counts();
    expect(counts.goals, 1);
    // 15:00 点击时当天只有已经结束的三条，其余留给用户自己填。
    expect(counts.activities, 46);
    expect(counts.sleep, 8);
    expect(counts.reviews, 6);

    final facts = await DriftLedgerRepository(db)
        .readWindow(startedAt: at2026(1, 0), endedAt: at2026(8, 0));
    final blockDays = facts.timeBlocks.map((block) {
      return civilDayOf(block.startedAt);
    }).toSet();
    for (var day = 1; day <= 7; day++) {
      expect(
        blockDays,
        contains(DateTime(2026, 10, day)),
        reason: '缺少 10 月 $day 日的活动',
      );
    }
    // 一周痕迹以点击时刻收尾，不出现未来条目。
    expect(facts.timeBlocks.every((block) => block.endedAt <= now), isTrue);
    expect(facts.sleepSessions.every((sleep) => sleep.endedAt <= now), isTrue);

    final reviews = DriftReviewRepository(db);
    for (var day = 1; day <= 6; day++) {
      expect(
        await reviews.findByDate(CivilDate(year: 2026, month: 10, day: day)),
        isNotNull,
        reason: '缺少 10 月 $day 日的复盘',
      );
    }
    expect(
      await reviews.findByDate(CivilDate(year: 2026, month: 10, day: 7)),
      isNull,
    );
  });

  test('seed writes nothing after the click moment on the same day', () async {
    final db = await openEmpty();
    addTearDown(db.close);
    var nextId = 1;
    await DriftDataMaintenance(db).seed(
      newGoalId: () => id(nextId++),
      newFactId: () => id(nextId++),
      now: at2026(7, 6),
    );

    final facts = await DriftLedgerRepository(db)
        .readWindow(startedAt: at2026(1, 0), endedAt: at2026(8, 0));
    final today = DateTime(2026, 10, 7);
    expect(
      facts.timeBlocks.where((block) => civilDayOf(block.startedAt) == today),
      isEmpty,
    );
    expect(
      facts.sleepSessions.where((sleep) => civilDayOf(sleep.endedAt) == today),
      isEmpty,
    );
    final blockDays = facts.timeBlocks.map((block) {
      return civilDayOf(block.startedAt);
    }).toSet();
    for (var day = 1; day <= 6; day++) {
      expect(blockDays, contains(DateTime(2026, 10, day)));
    }
  });

  test('seed keeps a realistic mix of facts, goals and annotations', () async {
    final db = await openEmpty();
    addTearDown(db.close);
    var nextId = 1;
    await DriftDataMaintenance(db).seed(
      newGoalId: () => id(nextId++),
      newFactId: () => id(nextId++),
      now: at2026(7, 15),
    );

    final goal = (await DriftGoalRepository(db).listActive()).single;
    final facts = await DriftLedgerRepository(db)
        .readWindow(startedAt: at2026(1, 0), endedAt: at2026(8, 0));
    expect(facts.timeBlocks.any((block) => block.goalId == goal.id), isTrue);
    expect(facts.timeBlocks.any((block) => block.goalId == null), isTrue);
    expect(
      facts.timeBlocks.any(
        (block) => block.knowledgeState == BlockKnowledgeState.unknown,
      ),
      isTrue,
    );
    expect(facts.timeBlocks.any((block) => block.note != null), isTrue);

    expect(
      facts.sleepSessions.where((sleep) => sleep.type == SleepType.mainSleep),
      hasLength(7),
    );
    expect(
      facts.sleepSessions.where((sleep) => sleep.type == SleepType.nap),
      hasLength(1),
    );

    final states = facts.annotations.map((annotation) {
      return annotation.state;
    }).toSet();
    expect(states, {
      RhythmState.progress,
      RhythmState.stuck,
      RhythmState.recovery,
    });
    final stuck = facts.annotations.firstWhere(
      (annotation) => annotation.state == RhythmState.stuck,
    );
    expect(stuck.stuckReasonCode, StuckReasonCode.unclearNextStep);
    final recovery = facts.annotations.firstWhere(
      (annotation) => annotation.state == RhythmState.recovery,
    );
    expect(recovery.recoveryMethod, RecoveryMethod.walk);
    expect(recovery.recoveryQuality, RecoveryQuality.partlyRecovered);
    final progress = facts.annotations.firstWhere(
      (annotation) => annotation.state == RhythmState.progress,
    );
    expect(progress.continuationHint, isNotNull);
  });

  test('seed refuses when business data already exists', () async {
    final db = await openEmpty();
    addTearDown(db.close);
    final maintenance = DriftDataMaintenance(db);
    var nextId = 1;
    await DriftGoalRepository(db)
        .create(id: id(nextId++), name: '已有目标', now: at2026(1, 9));
    final countsBefore = await maintenance.counts();
    await expectLater(
      () => maintenance.seed(
        newGoalId: () => id(nextId++),
        newFactId: () => id(nextId++),
        now: at2026(7, 15),
      ),
      throwsA(isA<DataMaintenanceConflict>()),
    );
    final countsAfter = await maintenance.counts();
    expect(countsAfter.goals, countsBefore.goals);
    expect(countsAfter.activities, 0);
    expect(countsAfter.sleep, 0);
    expect(countsAfter.reviews, 0);
  });
}
