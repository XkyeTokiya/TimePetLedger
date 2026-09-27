import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation_operations.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _blockId = '12345678-1234-4abc-8123-123456789abc';
const _annotationId = '87654321-4321-4abc-9123-123456789abc';

TimeBlock _block({
  BlockKnowledgeState knowledge = BlockKnowledgeState.known,
  String? goalId,
}) => TimeBlock(
  id: _blockId,
  startedAt: 86399999,
  endedAt: 86400001,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  knowledgeState: knowledge,
  title: knowledge == BlockKnowledgeState.known ? '写论文' : null,
  goalId: goalId,
  createdAt: 100,
  updatedAt: 200,
);

RhythmAnnotation _existing({
  RhythmState state = RhythmState.stuck,
  String blockId = _blockId,
}) => RhythmAnnotation(
  id: _annotationId,
  timeBlockId: blockId,
  state: state,
  stuckReasonCode: StuckReasonCode.unclearNextStep,
  stuckReasonText: '问题  描述\n\n说明',
  recoveryMethod: RecoveryMethod.walk,
  recoveryQuality: RecoveryQuality.partlyRecovered,
  continuationHint: '先列出问题',
  createdAt: 101,
  updatedAt: 201,
);

RhythmAnnotationOperationResult _edit(
  TimeBlock block,
  RhythmAnnotation? existing, {
  Goal? goal,
  int now = 300,
  RhythmState? state,
  ({StuckReasonCode? value})? stuckReasonCode,
  ({String? value})? stuckReasonText,
  ({RecoveryMethod? value})? recoveryMethod,
  ({RecoveryQuality? value})? recoveryQuality,
  ({String? value})? continuationHint,
}) => editRhythmAnnotation(
  timeBlock: block,
  existing: existing,
  goal: goal,
  now: now,
  state: state,
  stuckReasonCode: stuckReasonCode,
  stuckReasonText: stuckReasonText,
  recoveryMethod: recoveryMethod,
  recoveryQuality: recoveryQuality,
  continuationHint: continuationHint,
);

void main() {
  test('add：三种节奏均允许无细节、无 Goal，known/unknown 都可附加', () {
    for (final knowledge in BlockKnowledgeState.values) {
      for (final state in RhythmState.values) {
        final block = _block(knowledge: knowledge);
        final result = addRhythmAnnotation(
          timeBlock: block,
          existing: null,
          goal: null,
          id: _annotationId,
          state: state,
          now: 300,
        );
        expect(result.timeBlock, same(block));
        expect(result.changed, isTrue);
        final annotation = result.annotation!;
        expect(annotation.state, state);
        expect(annotation.id, _annotationId);
        expect(annotation.timeBlockId, block.id);
        expect((annotation.createdAt, annotation.updatedAt), (300, 300));
        expect(annotation.stuckReasonCode, isNull);
        expect(annotation.stuckReasonText, isNull);
        expect(annotation.recoveryMethod, isNull);
        expect(annotation.recoveryQuality, isNull);
        expect(annotation.continuationHint, isNull);
        expect(
          (block.startedAt, block.endedAt, block.updatedAt),
          (86399999, 86400001, 200),
        );
      }
    }
  });

  test('Q-013：重复 add 拒绝并提示编辑，不覆盖原解释', () {
    final block = _block();
    final existing = _existing();
    for (final id in [_annotationId, _blockId]) {
      expect(
        () => addRhythmAnnotation(
          timeBlock: block,
          existing: existing,
          goal: null,
          id: id,
          state: RhythmState.progress,
          now: 300,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('改用编辑'),
          ),
        ),
      );
    }
    expect(existing.state, RhythmState.stuck);
    expect(existing.updatedAt, 201);
  });

  test('Q-013：缺失 edit 提示先添加，不自动创建', () {
    expect(
      () => _edit(_block(), null, state: RhythmState.progress),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('先添加')),
      ),
    );
  });

  for (final from in RhythmState.values) {
    for (final to in RhythmState.values) {
      test('Q-005：$from → $to 保留全部细节，身份和事实不变', () {
        final block = _block();
        final original = _existing(state: from);
        final result = _edit(block, original, state: to);
        final annotation = result.annotation!;
        expect(result.timeBlock, same(block));
        expect(result.changed, from != to);
        expect(annotation.state, to);
        expect(annotation.id, original.id);
        expect(annotation.timeBlockId, original.timeBlockId);
        expect(annotation.createdAt, original.createdAt);
        expect(annotation.updatedAt, from == to ? 201 : 300);
        expect(annotation.stuckReasonCode, original.stuckReasonCode);
        expect(annotation.stuckReasonText, original.stuckReasonText);
        expect(annotation.recoveryMethod, original.recoveryMethod);
        expect(annotation.recoveryQuality, original.recoveryQuality);
        expect(annotation.continuationHint, original.continuationHint);
        expect(
          annotation.applicableStuckReasonText,
          to == RhythmState.stuck ? original.stuckReasonText : null,
        );
        expect(
          annotation.applicableRecoveryMethod,
          to == RhythmState.recovery ? original.recoveryMethod : null,
        );
        final back = _edit(
          block,
          annotation,
          state: from,
          now: 400,
        ).annotation!;
        expect(
          back.applicableStuckReasonText,
          original.applicableStuckReasonText,
        );
        expect(
          back.applicableRecoveryQuality,
          original.applicableRecoveryQuality,
        );
        expect(original.state, from);
        expect(original.updatedAt, 201);
      });
    }
  }

  test('同状态编辑：各细节可独立变化，保留未指定字段', () {
    final block = _block();
    final original = _existing();
    final results = [
      _edit(block, original, stuckReasonCode: (value: StuckReasonCode.other)),
      _edit(block, original, stuckReasonText: (value: '新原因')),
      _edit(block, original, recoveryMethod: (value: RecoveryMethod.meal)),
      _edit(
        block,
        original,
        recoveryQuality: (value: RecoveryQuality.readyToContinue),
      ),
      _edit(block, original, continuationHint: (value: '新接续点')),
    ];
    for (final result in results) {
      expect(result.changed, isTrue);
      expect(result.annotation!.state, RhythmState.stuck);
      expect(result.annotation!.updatedAt, 300);
      expect(result.annotation!.id, original.id);
      expect(result.timeBlock, same(block));
    }
    expect(results.first.annotation!.stuckReasonText, original.stuckReasonText);
    expect(results.last.annotation!.recoveryMethod, original.recoveryMethod);
  });

  test('显式清空所有可选字段仍为合法解释，不能被解释为 remove', () {
    final block = _block();
    for (final state in RhythmState.values) {
      final result = _edit(
        block,
        _existing(),
        state: state,
        stuckReasonCode: (value: null),
        stuckReasonText: (value: ' \n '),
        recoveryMethod: (value: null),
        recoveryQuality: (value: null),
        continuationHint: (value: null),
      );
      final annotation = result.annotation!;
      expect(result.changed, isTrue);
      expect(annotation.state, state);
      expect(annotation.stuckReasonCode, isNull);
      expect(annotation.stuckReasonText, isNull);
      expect(annotation.recoveryMethod, isNull);
      expect(annotation.recoveryQuality, isNull);
      expect(annotation.continuationHint, isNull);
      expect(result.timeBlock, same(block));
    }
  });

  test('Q-018：空编辑、规范化后相同与重复请求保留原时间戳', () {
    final block = _block();
    final original = _existing();
    expect(_edit(block, original).annotation, same(original));
    final normalized = _edit(
      block,
      original,
      stuckReasonText: (value: '  问题  描述\n\n说明  '),
      continuationHint: (value: '  先列出问题\n'),
    );
    expect(normalized.changed, isFalse);
    expect(normalized.annotation, same(original));
    final changed = _edit(block, original, continuationHint: (value: '先打开文件'));
    final repeated = _edit(
      block,
      changed.annotation,
      continuationHint: (value: '  先打开文件 '),
      now: 999,
    );
    expect(repeated.changed, isFalse);
    expect(repeated.annotation, same(changed.annotation));
    expect(repeated.annotation!.updatedAt, 300);
  });

  test('remove：只移除解释，重复请求幂等，事实和输入解释保持不变', () {
    final block = _block();
    final original = _existing();
    final removed = removeRhythmAnnotation(
      timeBlock: block,
      existing: original,
    );
    expect(removed.timeBlock, same(block));
    expect(removed.annotation, isNull);
    expect(removed.changed, isTrue);
    final repeated = removeRhythmAnnotation(
      timeBlock: block,
      existing: removed.annotation,
    );
    expect(repeated.annotation, isNull);
    expect(repeated.changed, isFalse);
    expect(repeated.timeBlock, same(block));
    expect(
      (block.startedAt, block.endedAt, block.createdAt, block.updatedAt),
      (86399999, 86400001, 100, 200),
    );
    expect(original.state, RhythmState.stuck);
    expect(original.updatedAt, 201);
  });

  test('RH-001：edit/remove 拒绝另一事实的解释，不转移归属', () {
    final block = _block();
    final wrong = _existing(blockId: _annotationId);
    expect(() => _edit(block, wrong), throwsArgumentError);
    expect(
      () => removeRhythmAnnotation(timeBlock: block, existing: wrong),
      throwsArgumentError,
    );
    expect(wrong.timeBlockId, _annotationId);
  });

  test('已有 archived Goal 引用允许 add/edit，移除解释也不解除目标归属', () {
    final goal = Goal.create(
      id: _annotationId,
      name: '目标',
      now: 0,
    ).archive(now: 1);
    final block = _block(goalId: goal.id);
    final added = addRhythmAnnotation(
      timeBlock: block,
      existing: null,
      goal: goal,
      id: _annotationId,
      state: RhythmState.progress,
      now: 300,
    );
    final edited = _edit(
      block,
      added.annotation,
      goal: goal,
      state: RhythmState.recovery,
    );
    final removed = removeRhythmAnnotation(
      timeBlock: block,
      existing: edited.annotation,
    );
    expect(removed.timeBlock, same(block));
    expect(block.goalId, goal.id);
    expect(block.updatedAt, 200);
  });

  test('有 Goal 归属时 add/edit 拒绝缺失或错配的目标快照', () {
    final block = _block(goalId: _annotationId);
    for (final goal in [
      null,
      Goal.create(id: _blockId, name: '另一目标', now: 0),
    ]) {
      expect(
        () => addRhythmAnnotation(
          timeBlock: block,
          existing: null,
          goal: goal,
          id: _annotationId,
          state: RhythmState.stuck,
          now: 300,
        ),
        throwsArgumentError,
      );
      expect(() => _edit(block, _existing(), goal: goal), throwsArgumentError);
    }
  });

  test('Q-015：add/edit 两文本清理后允许 2000 码点，2001 拒绝', () {
    final block = _block();
    for (final text in ['😀' * 2000, 'e\u0301' * 1000]) {
      final added = addRhythmAnnotation(
        timeBlock: block,
        existing: null,
        goal: null,
        id: _annotationId,
        state: RhythmState.recovery,
        now: 300,
        stuckReasonCode: StuckReasonCode.other,
        recoveryMethod: RecoveryMethod.walk,
        recoveryQuality: RecoveryQuality.readyToContinue,
        stuckReasonText: ' $text ',
        continuationHint: ' $text ',
      );
      expect(added.annotation!.stuckReasonText, text);
      expect(added.annotation!.continuationHint, text);
      expect(added.annotation!.stuckReasonCode, StuckReasonCode.other);
      expect(added.annotation!.recoveryMethod, RecoveryMethod.walk);
      expect(
        added.annotation!.recoveryQuality,
        RecoveryQuality.readyToContinue,
      );
      final edited = _edit(
        block,
        _existing(),
        stuckReasonText: (value: ' $text '),
        continuationHint: (value: ' $text '),
      );
      expect(edited.annotation!.stuckReasonText, text);
      expect(edited.annotation!.continuationHint, text);
      for (final reason in [true, false]) {
        expect(
          () => addRhythmAnnotation(
            timeBlock: block,
            existing: null,
            goal: null,
            id: _annotationId,
            state: RhythmState.stuck,
            now: 300,
            stuckReasonText: reason ? '${text}x' : null,
            continuationHint: reason ? null : '${text}x',
          ),
          throwsArgumentError,
        );
        expect(
          () => _edit(
            block,
            _existing(),
            stuckReasonText: reason ? (value: '${text}x') : null,
            continuationHint: reason ? null : (value: '${text}x'),
          ),
          throwsArgumentError,
        );
      }
    }
  });

  test('Q-018：add 拒绝非法 id，不生成替代身份', () {
    expect(
      () => addRhythmAnnotation(
        timeBlock: _block(),
        existing: null,
        goal: null,
        id: 'invalid',
        state: RhythmState.stuck,
        now: 300,
      ),
      throwsArgumentError,
    );
  });

  test('Q-018：显式时间允许回拨，候选不改写原解释和事实', () {
    final block = _block();
    final original = _existing();
    final candidate = _edit(
      block,
      original,
      state: RhythmState.progress,
      now: -1,
    );
    expect(candidate.annotation!.updatedAt, -1);
    expect(candidate.annotation!.createdAt, 101);
    expect(original.updatedAt, 201);
    expect(original.state, RhythmState.stuck);
    expect(block.updatedAt, 200);
  });
}
