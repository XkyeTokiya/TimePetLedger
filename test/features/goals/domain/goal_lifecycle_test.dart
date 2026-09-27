import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_association.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_goal_association.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _recordId = '87654321-4321-4abc-9123-123456789abc';

Goal _active() => Goal.reconstitute(
  id: _id,
  name: '毕业设计  第一章\n补充说明',
  status: GoalStatus.active,
  createdAt: 1001,
  updatedAt: 2002,
);

void main() {
  test('Q-006：归档写入显式毫秒，身份、名称、创建时间不变', () {
    final original = _active();
    final archived = original.archive(now: 3003);
    expect(archived.status, GoalStatus.archived);
    expect(archived.archivedAt, 3003);
    expect(archived.updatedAt, 3003);
    expect(archived.id, original.id);
    expect(archived.name, original.name);
    expect(archived.createdAt, original.createdAt);
    expect(original.status, GoalStatus.active);
    expect(original.archivedAt, isNull);
    expect(original.updatedAt, 2002);
  });

  test('Q-006：恢复清除 archivedAt 并保持身份、名称、创建时间', () {
    final archived = _active().archive(now: 3003);
    final restored = archived.restore(now: 4004);
    expect(restored.status, GoalStatus.active);
    expect(restored.archivedAt, isNull);
    expect(restored.updatedAt, 4004);
    expect(restored.id, archived.id);
    expect(restored.name, archived.name);
    expect(restored.createdAt, archived.createdAt);
    expect(archived.status, GoalStatus.archived);
    expect(archived.archivedAt, 3003);
    expect(archived.updatedAt, 3003);
  });

  test('Q-006、Q-018：两种同状态请求幂等，不刷新任何时间戳', () {
    final active = _active();
    final archived = active.archive(now: 3003);
    for (final now in [-1, 0, 3003, 5005]) {
      expect(active.restore(now: now), same(active));
      expect(archived.archive(now: now), same(archived));
      expect(active.updatedAt, 2002);
      expect(active.archivedAt, isNull);
      expect(archived.updatedAt, 3003);
      expect(archived.archivedAt, 3003);
    }
  });

  test('Q-006：恢复后再次归档使用新的归档时间', () {
    final active = _active();
    final rearchived = active
        .archive(now: 3003)
        .restore(now: 4004)
        .archive(now: 5005);
    expect(rearchived.status, GoalStatus.archived);
    expect(rearchived.archivedAt, 5005);
    expect(rearchived.updatedAt, 5005);
    expect(rearchived.createdAt, active.createdAt);
    expect(rearchived.id, active.id);
    expect(rearchived.name, active.name);
  });

  test('Q-018：时钟回拨、零值和相同取时不阻止真实状态变化', () {
    for (final now in [-1001, 0, 2002]) {
      final archived = _active().archive(now: now);
      expect(archived.status, GoalStatus.archived);
      expect(archived.archivedAt, now);
      expect(archived.updatedAt, now);
      expect(archived.createdAt, 1001);
      final restored = archived.restore(now: now);
      expect(restored.status, GoalStatus.active);
      expect(restored.archivedAt, isNull);
      expect(restored.updatedAt, now);
      expect(restored.createdAt, 1001);
    }
  });

  test('Q-018：未采用候选结果时原对象不变，重新计算使用新的取时', () {
    final original = _active();
    // 不模拟数据库成功；这里只验证待保存结果与原对象完全独立。
    original.archive(now: 3003);
    expect(original.status, GoalStatus.active);
    expect(original.updatedAt, 2002);
    expect(original.archivedAt, isNull);
    final retry = original.archive(now: 4004);
    expect(retry.updatedAt, 4004);
    expect(retry.archivedAt, 4004);
    retry.restore(now: 5005);
    expect(retry.status, GoalStatus.archived);
    expect(retry.updatedAt, 4004);
    expect(retry.archivedAt, 4004);
  });

  test('Q-006：从持久化字段还原的 Goal 支持转换及重复请求', () {
    final archived = Goal.reconstitute(
      id: _id,
      name: '论文',
      status: GoalStatus.archived,
      createdAt: 1001,
      updatedAt: 4004,
      archivedAt: 3003,
    );
    expect(archived.archive(now: 5005), same(archived));
    final restored = archived.restore(now: 6006);
    expect(restored.archivedAt, isNull);
    expect(restored.updatedAt, 6006);
    expect(restored.createdAt, 1001);
  });

  test('Q-006：归档保留两类历史引用、拒绝新增；恢复后重新允许', () {
    final original = _active();
    final archived = original.archive(now: 3003);
    final restored = archived.restore(now: 4004);
    final block = TimeBlock(
      id: _recordId,
      startedAt: 1001,
      endedAt: 2002,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '写论文',
      goalId: original.id,
      createdAt: 1001,
      updatedAt: 1001,
    );
    final annotation = RhythmAnnotation(
      id: _recordId,
      timeBlockId: block.id,
      state: RhythmState.progress,
      createdAt: 1001,
      updatedAt: 1001,
    );
    final date = CivilDate(year: 2026, month: 9, day: 26);
    final review = DailyReview(
      id: _recordId,
      date: date,
      tomorrowFirstStep: TomorrowFirstStep(
        reviewDate: date,
        text: '继续第一章',
        goalId: original.id,
      ),
      createdAt: 1001,
      updatedAt: 1001,
    );
    for (final goal in [original, archived, restored]) {
      for (final isNew in [false, true]) {
        void validateBlock() => validateRhythmAssociation(
          annotation: annotation,
          timeBlock: block,
          goal: goal,
          isNewGoalAssociation: isNew,
        );
        void validateReview() => validateReviewGoalAssociation(
          review: review,
          goal: goal,
          isNewGoalAssociation: isNew,
        );
        if (identical(goal, archived) && isNew) {
          expect(validateBlock, throwsArgumentError);
          expect(validateReview, throwsArgumentError);
        } else {
          validateBlock();
          validateReview();
        }
      }
    }
    expect(block.goalId, original.id);
    expect(review.tomorrowFirstStep.goalId, original.id);
    expect(block.updatedAt, 1001);
    expect(review.updatedAt, 1001);
  });
}
