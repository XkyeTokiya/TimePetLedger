import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_annotation.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block_correction.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _goalId = '87654321-4321-4abc-9123-123456789abc';

TimeBlock _block({
  BlockKnowledgeState state = BlockKnowledgeState.known,
  String? title = '写论文',
  String? goalId,
}) => TimeBlock(
  id: _id,
  startedAt: 1000,
  endedAt: 2000,
  startPrecision: TimePrecision.approximate,
  endPrecision: TimePrecision.exact,
  knowledgeState: state,
  title: title,
  goalId: goalId,
  note: '第一段\n\n接着写',
  categoryId: 'reserved',
  createdAt: 100,
  updatedAt: 200,
);

RhythmAnnotation _annotation({String blockId = _id}) => RhythmAnnotation(
  id: _id,
  timeBlockId: blockId,
  state: RhythmState.stuck,
  stuckReasonText: '问题尚不清楚',
  continuationHint: '先列出问题',
  createdAt: 101,
  updatedAt: 201,
);

TimeBlockCorrectionResult _correct(
  TimeBlock? original, {
  RhythmAnnotation? annotation,
  Goal? goal,
  Iterable<LedgerFactInterval> existing = const [],
  int now = 300,
  BlockKnowledgeState? state,
  int? start,
  int? end,
  TimePrecision? startPrecision,
  TimePrecision? endPrecision,
  ({String? value})? title,
  ({String? value})? goalId,
  ({String? value})? categoryId,
  ({String? value})? note,
}) => correctTimeBlock(
  original: original,
  annotation: annotation,
  goal: goal,
  existing: existing,
  now: now,
  knowledgeState: state,
  startedAt: start,
  endedAt: end,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  title: title,
  goalId: goalId,
  categoryId: categoryId,
  note: note,
);

void main() {
  test('Q-003：known → unknown 保留所有内容、边界精度与原解释', () {
    final goal = Goal.create(id: _goalId, name: '论文', now: 0).archive(now: 1);
    final original = _block(goalId: goal.id);
    final annotation = _annotation();
    final result = _correct(
      original,
      annotation: annotation,
      goal: goal,
      state: BlockKnowledgeState.unknown,
    );
    final block = result.timeBlock;
    expect(result.changed, isTrue);
    expect(block.knowledgeState, BlockKnowledgeState.unknown);
    expect(block.title, original.title);
    expect(block.goalId, original.goalId);
    expect(block.note, original.note);
    expect(block.categoryId, original.categoryId);
    expect((block.startedAt, block.endedAt), (1000, 2000));
    expect(
      (block.startPrecision, block.endPrecision),
      (TimePrecision.approximate, TimePrecision.exact),
    );
    expect((block.id, block.createdAt, block.updatedAt), (_id, 100, 300));
    expect(result.annotation, same(annotation));
    expect(annotation.updatedAt, 201);
    expect(original.knowledgeState, BlockKnowledgeState.known);
    expect(original.updatedAt, 200);
  });

  test('Q-003：unknown → known 接受明确名称或已有合法名称，不生成解释', () {
    for (final oldTitle in [null, '原有说明']) {
      final original = _block(
        state: BlockKnowledgeState.unknown,
        title: oldTitle,
      );
      final result = _correct(
        original,
        state: BlockKnowledgeState.known,
        title: oldTitle == null ? (value: '  想起来了\n写论文  ') : null,
      );
      expect(result.timeBlock.knowledgeState, BlockKnowledgeState.known);
      expect(result.timeBlock.title, oldTitle ?? '想起来了\n写论文');
      expect(result.annotation, isNull);
    }
  });

  test('TB-005：转为 known 时拒绝缺失、清空和纯空白名称', () {
    final original = _block(state: BlockKnowledgeState.unknown, title: null);
    expect(
      () => _correct(original, state: BlockKnowledgeState.known),
      throwsArgumentError,
    );
    for (final text in [null, '', ' \n\t ', '\u3000']) {
      expect(
        () => _correct(
          original,
          state: BlockKnowledgeState.known,
          title: (value: text),
        ),
        throwsArgumentError,
      );
      expect(
        () => _correct(_block(), title: (value: text)),
        throwsArgumentError,
      );
    }
  });

  test('Q-003：显式清空可选内容，不清除原解释或擅自保留旧目标', () {
    final original = _block(goalId: _goalId);
    final annotation = _annotation();
    final result = _correct(
      original,
      annotation: annotation,
      state: BlockKnowledgeState.unknown,
      title: (value: null),
      goalId: (value: null),
      categoryId: (value: null),
      note: (value: ' \n '),
    );
    expect(result.timeBlock.title, isNull);
    expect(result.timeBlock.goalId, isNull);
    expect(result.timeBlock.categoryId, isNull);
    expect(result.timeBlock.note, isNull);
    expect(result.annotation, same(annotation));
    expect(original.goalId, _goalId);
    expect(original.title, '写论文');
  });

  test('Q-003：同次修改跨日区间和两端精度，状态不自动改变', () {
    final original = _block();
    final result = _correct(
      original,
      start: 86399999,
      end: 86400001,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
    );
    expect(
      (result.timeBlock.startedAt, result.timeBlock.endedAt),
      (86399999, 86400001),
    );
    expect(result.timeBlock.knowledgeState, BlockKnowledgeState.known);
    expect(
      (result.timeBlock.startPrecision, result.timeBlock.endPrecision),
      (TimePrecision.exact, TimePrecision.approximate),
    );
  });

  test('Q-018：每个业务字段单独变化都更新待保存时间，不改变身份', () {
    final original = _block();
    final goal = Goal.create(id: _goalId, name: '目标', now: 0);
    final results = [
      _correct(original, state: BlockKnowledgeState.unknown),
      _correct(original, start: 999),
      _correct(original, end: 2001),
      _correct(original, startPrecision: TimePrecision.exact),
      _correct(original, endPrecision: TimePrecision.approximate),
      _correct(original, title: (value: '新标题')),
      _correct(original, goalId: (value: goal.id), goal: goal),
      _correct(original, categoryId: (value: 'new-category')),
      _correct(original, note: (value: '新备注')),
    ];
    for (final result in results) {
      expect(result.changed, isTrue);
      expect(result.timeBlock.updatedAt, 300);
      expect(result.timeBlock.createdAt, 100);
      expect(result.timeBlock.id, _id);
    }
  });

  test('Q-018：无修改与规范化后相同请求均保留原对象和时间戳', () {
    final original = _block();
    expect(_correct(original).timeBlock, same(original));
    final result = _correct(
      original,
      title: (value: '  写论文\n'),
      note: (value: '  第一段\n\n接着写  '),
      now: 999,
    );
    expect(result.changed, isFalse);
    expect(result.timeBlock, same(original));
    expect(result.timeBlock.updatedAt, 200);
    final changed = _correct(original, state: BlockKnowledgeState.unknown);
    final repeated = _correct(
      changed.timeBlock,
      state: BlockKnowledgeState.unknown,
      now: 999,
    );
    expect(repeated.changed, isFalse);
    expect(repeated.timeBlock, same(changed.timeBlock));
    expect(repeated.timeBlock.updatedAt, 300);
  });

  test('Q-018：时钟回拨不修正注入的时间，未采用结果不改变原事实', () {
    final original = _block();
    final result = _correct(original, note: (value: '新备注'), now: -1);
    expect(result.timeBlock.updatedAt, -1);
    expect(result.timeBlock.createdAt, 100);
    expect(original.updatedAt, 200);
    expect(original.note, '第一段\n\n接着写');
  });

  test('Q-013：缺失事实明确拒绝，不自动创建', () {
    expect(
      () => _correct(null),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('记录已不存在'),
        ),
      ),
    );
  });

  test('RH-001：拒绝错配解释，不把解释转移到其他事实', () {
    final annotation = _annotation(blockId: _goalId);
    expect(
      () => _correct(_block(), annotation: annotation),
      throwsArgumentError,
    );
    expect(annotation.timeBlockId, _goalId);
  });

  test('TB-001：精确和近似区间的零时长、反向更正都拒绝', () {
    for (final precision in TimePrecision.values) {
      for (final end in [1000, 999]) {
        expect(
          () => _correct(_block(), end: end, endPrecision: precision),
          throwsArgumentError,
        );
      }
    }
  });

  test('MODEL-002：更正复用码点上限，保留内部格式，拒绝超限', () {
    final title = '😀' * 200;
    final note = 'e\u0301' * 1000;
    final result = _correct(
      _block(),
      title: (value: ' $title '),
      note: (value: ' $note '),
    );
    expect(result.timeBlock.title, title);
    expect(result.timeBlock.note, note);
    expect(
      () => _correct(_block(), title: (value: '$title字')),
      throwsArgumentError,
    );
    expect(
      () => _correct(_block(), note: (value: '$note字')),
      throwsArgumentError,
    );
  });

  for (final withAnnotation in [false, true]) {
    test('Q-006：有解释=$withAnnotation；保留归档引用，拒绝新增归档引用', () {
      final active = Goal.create(id: _goalId, name: '目标', now: 0);
      final archived = active.archive(now: 1);
      final annotation = withAnnotation ? _annotation() : null;
      final original = _block(goalId: _goalId);
      final retained = _correct(
        original,
        annotation: annotation,
        goal: archived,
        state: BlockKnowledgeState.unknown,
      );
      expect(retained.timeBlock.goalId, _goalId);
      final added = _correct(
        _block(),
        annotation: annotation,
        goal: active,
        goalId: (value: _goalId),
      );
      expect(added.timeBlock.goalId, _goalId);
      expect(
        () => _correct(
          _block(),
          annotation: annotation,
          goal: archived,
          goalId: (value: _goalId),
        ),
        throwsArgumentError,
      );
      final switched = _block(goalId: _id);
      expect(
        () => _correct(
          switched,
          annotation: annotation,
          goal: archived,
          goalId: (value: _goalId),
        ),
        throwsArgumentError,
      );
      for (final wrongGoal in [
        null,
        Goal.create(id: _id, name: '另一目标', now: 0),
      ]) {
        expect(
          () => _correct(original, annotation: annotation, goal: wrongGoal),
          throwsArgumentError,
        );
      }
    });
  }

  test('Q-018：拒绝非法 Goal 身份，分类扩展值仍原样保留', () {
    expect(
      () => _correct(_block(), goalId: (value: 'invalid')),
      throwsArgumentError,
    );
    expect(
      _correct(
        _block(),
        categoryId: (value: '  reserved-new  '),
      ).timeBlock.categoryId,
      '  reserved-new  ',
    );
  });

  test('LEDGER-004：排除旧自身但拒绝另一 TimeBlock 与同 id SleepSession 冲突', () {
    final original = _block();
    final old = LedgerFactInterval.fromTimeBlock(original);
    final other = LedgerFactInterval.fromTimeBlock(
      TimeBlock(
        id: _goalId,
        startedAt: 2000,
        endedAt: 3000,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.unknown,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    final sleep = LedgerFactInterval.fromSleepSession(
      SleepSession(
        id: _id,
        startedAt: 2000,
        endedAt: 3000,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        type: SleepType.nap,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    expect(_correct(original, existing: [old, other, sleep]).changed, isFalse);
    expect(
      () => _correct(original, end: 2001, existing: [old, other, sleep]),
      throwsA(
        isA<TimeBlockCorrectionConflict>().having(
          (error) => error.conflicts,
          'conflicts',
          [other, sleep],
        ),
      ),
    );
    expect(original.endedAt, 2000);
    expect(original.updatedAt, 200);
  });

  test('LEDGER-004：无内容变化也不绕过当前冲突检查', () {
    final original = _block();
    final overlap = LedgerFactInterval.fromSleepSession(
      SleepSession(
        id: _id,
        startedAt: 1000,
        endedAt: 2000,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.exact,
        type: SleepType.mainSleep,
        createdAt: 0,
        updatedAt: 0,
      ),
    );
    expect(
      () => _correct(original, existing: [overlap]),
      throwsA(isA<TimeBlockCorrectionConflict>()),
    );
  });
}
