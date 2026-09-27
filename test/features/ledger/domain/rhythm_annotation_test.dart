import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_association.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _blockId = '22345678-1234-4abc-8123-123456789abc';
const _goalId = '32345678-1234-4abc-8123-123456789abc';

RhythmAnnotation _annotation({
  String id = _id,
  String timeBlockId = _blockId,
  RhythmState state = RhythmState.progress,
  StuckReasonCode? reason,
  String? text,
  RecoveryMethod? method,
  RecoveryQuality? quality,
  String? hint,
}) => RhythmAnnotation(
  id: id,
  timeBlockId: timeBlockId,
  state: state,
  createdAt: 1001,
  updatedAt: 2002,
  stuckReasonCode: reason,
  stuckReasonText: text,
  recoveryMethod: method,
  recoveryQuality: quality,
  continuationHint: hint,
);

TimeBlock _block({
  String id = _blockId,
  BlockKnowledgeState knowledge = BlockKnowledgeState.known,
  String? goalId,
}) => TimeBlock(
  id: id,
  startedAt: 100,
  endedAt: 200,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  knowledgeState: knowledge,
  title: knowledge == BlockKnowledgeState.known ? '查论文' : null,
  goalId: goalId,
  createdAt: 300,
  updatedAt: 400,
);

Goal _goal({bool archived = false, String id = _goalId}) => Goal.reconstitute(
  id: id,
  name: '毕业设计',
  status: archived ? GoalStatus.archived : GoalStatus.active,
  archivedAt: archived ? 500 : null,
  createdAt: 300,
  updatedAt: 500,
);

void main() {
  test('RH-006–008：三种解释均允许细节全空，保留身份和元数据', () {
    for (final state in RhythmState.values) {
      final annotation = _annotation(state: state);
      expect(annotation.id, _id);
      expect(annotation.timeBlockId, _blockId);
      expect(annotation.state, state);
      expect(annotation.createdAt, 1001);
      expect(annotation.updatedAt, 2002);
      expect(annotation.stuckReasonCode, isNull);
      expect(annotation.stuckReasonText, isNull);
      expect(annotation.recoveryMethod, isNull);
      expect(annotation.recoveryQuality, isNull);
      expect(annotation.continuationHint, isNull);
    }
  });

  test('Q-005：跨状态细节保留，只使用当前适用细节，接续点全部适用', () {
    for (final state in RhythmState.values) {
      final annotation = _annotation(
        state: state,
        reason: StuckReasonCode.unclearNextStep,
        text: '问题还没想清楚',
        method: RecoveryMethod.walk,
        quality: RecoveryQuality.partlyRecovered,
        hint: '  下次先画表结构  ',
      );
      expect(annotation.stuckReasonCode, StuckReasonCode.unclearNextStep);
      expect(annotation.stuckReasonText, '问题还没想清楚');
      expect(annotation.recoveryMethod, RecoveryMethod.walk);
      expect(annotation.recoveryQuality, RecoveryQuality.partlyRecovered);
      expect(annotation.continuationHint, '下次先画表结构');
      expect(
        annotation.applicableStuckReasonCode,
        state == RhythmState.stuck ? StuckReasonCode.unclearNextStep : null,
      );
      expect(
        annotation.applicableStuckReasonText,
        state == RhythmState.stuck ? '问题还没想清楚' : null,
      );
      expect(
        annotation.applicableRecoveryMethod,
        state == RhythmState.recovery ? RecoveryMethod.walk : null,
      );
      expect(
        annotation.applicableRecoveryQuality,
        state == RhythmState.recovery ? RecoveryQuality.partlyRecovered : null,
      );
    }
  });

  test('Q-007：文字可独立填写或补充任一原因，other 不强制文字', () {
    expect(_annotation(text: '补充原因').stuckReasonText, '补充原因');
    for (final reason in StuckReasonCode.values) {
      expect(_annotation(reason: reason).stuckReasonText, isNull);
      expect(_annotation(reason: reason, text: '补充').stuckReasonText, '补充');
    }
  });

  test('Q-007：恢复方式和效果彼此独立可选', () {
    for (final method in RecoveryMethod.values) {
      final annotation = _annotation(
        state: RhythmState.recovery,
        method: method,
      );
      expect(annotation.applicableRecoveryMethod, method);
      expect(annotation.applicableRecoveryQuality, isNull);
    }
    for (final quality in RecoveryQuality.values) {
      final annotation = _annotation(
        state: RhythmState.recovery,
        quality: quality,
      );
      expect(annotation.applicableRecoveryQuality, quality);
      expect(annotation.applicableRecoveryMethod, isNull);
    }
  });

  test('Q-015：可选空白文字归一 null，内部格式保留', () {
    for (final text in [null, '', ' \t\n', '\u3000']) {
      final annotation = _annotation(text: text, hint: text);
      expect(annotation.stuckReasonText, isNull);
      expect(annotation.continuationHint, isNull);
    }
    const text = ' \t第一段  内容\n\n第二段\t内容\n ';
    final annotation = _annotation(text: text, hint: text);
    expect(annotation.stuckReasonText, '第一段  内容\n\n第二段\t内容');
    expect(annotation.continuationHint, annotation.stuckReasonText);
  });

  test('Q-015：两字段独立执行清理后 2000 码点上限，不按 UTF-16 计数', () {
    for (final state in RhythmState.values) {
      for (final character in ['字', '😀']) {
        final text = character * 2000;
        final annotation = _annotation(
          state: state,
          text: ' $text ',
          hint: ' $text ',
        );
        expect(annotation.stuckReasonText, text);
        expect(annotation.continuationHint, text);
        expect(
          () => _annotation(state: state, text: '$text$character'),
          throwsArgumentError,
        );
        expect(
          () => _annotation(state: state, hint: '$text$character'),
          throwsArgumentError,
        );
      }
    }
  });

  test('Q-015：组合字符逐码点计数，保留原始形式', () {
    final text = 'e\u0301' * 1000;
    expect(_annotation(text: text, hint: text).stuckReasonText, text);
    expect(_annotation(text: text, hint: text).continuationHint, text);
    expect(() => _annotation(text: '${text}e'), throwsArgumentError);
    expect(() => _annotation(hint: '${text}e'), throwsArgumentError);
  });

  test('Q-018：身份和事实引用均验证 UUID', () {
    expect(() => _annotation(id: 'invalid'), throwsArgumentError);
    expect(() => _annotation(timeBlockId: 'invalid'), throwsArgumentError);
  });

  test('Q-004：known/unknown、Goal 有无与所有解释状态均可组合', () {
    for (final knowledge in BlockKnowledgeState.values) {
      for (final goal in [null, _goal()]) {
        for (final state in RhythmState.values) {
          for (final isNew in [false, true]) {
            expect(
              () => validateRhythmAssociation(
                annotation: _annotation(state: state),
                timeBlock: _block(knowledge: knowledge, goalId: goal?.id),
                goal: goal,
                isNewGoalAssociation: isNew,
              ),
              returnsNormally,
            );
          }
        }
      }
    }
  });

  test('RH-001：拒绝缺失事实与错配的 TimeBlock', () {
    for (final block in [null, _block(id: _id)]) {
      expect(
        () => validateRhythmAssociation(
          annotation: _annotation(),
          timeBlock: block,
          goal: null,
          isNewGoalAssociation: false,
        ),
        throwsArgumentError,
      );
    }
  });

  test('关联 Goal 必须存在且匹配 TimeBlock.goalId', () {
    for (final goal in [null, _goal(id: _id)]) {
      expect(
        () => validateRhythmAssociation(
          annotation: _annotation(),
          timeBlock: _block(goalId: _goalId),
          goal: goal,
          isNewGoalAssociation: false,
        ),
        throwsArgumentError,
      );
    }
  });

  test('Q-006：归档目标保留已有归属，可添加解释，但拒绝新增目标归属', () {
    for (final knowledge in BlockKnowledgeState.values) {
      for (final state in RhythmState.values) {
        final annotation = _annotation(state: state);
        final block = _block(knowledge: knowledge, goalId: _goalId);
        final goal = _goal(archived: true);
        expect(
          () => validateRhythmAssociation(
            annotation: annotation,
            timeBlock: block,
            goal: goal,
            isNewGoalAssociation: false,
          ),
          returnsNormally,
        );
        expect(
          () => validateRhythmAssociation(
            annotation: annotation,
            timeBlock: block,
            goal: goal,
            isNewGoalAssociation: true,
          ),
          throwsArgumentError,
        );
        expect(block.goalId, _goalId);
        expect(annotation.state, state);
      }
    }
  });
}
