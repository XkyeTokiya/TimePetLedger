import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_block.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _goalId = '87654321-4321-4abc-9123-123456789abc';

TimeBlock _block({
  String id = _id,
  int startedAt = 1001,
  int endedAt = 2002,
  TimePrecision startPrecision = TimePrecision.exact,
  TimePrecision endPrecision = TimePrecision.exact,
  BlockKnowledgeState knowledgeState = BlockKnowledgeState.known,
  String? title = '吃午饭',
  String? goalId,
  String? categoryId,
  String? note,
}) => TimeBlock(
  id: id,
  startedAt: startedAt,
  endedAt: endedAt,
  startPrecision: startPrecision,
  endPrecision: endPrecision,
  knowledgeState: knowledgeState,
  title: title,
  goalId: goalId,
  categoryId: categoryId,
  note: note,
  createdAt: 5005,
  updatedAt: 6006,
);

void main() {
  test('MODEL-001：普通事实不要求目标、分类、备注或节奏解释', () {
    final block = _block();
    expect(block.id, _id);
    expect(block.title, '吃午饭');
    expect(block.goalId, isNull);
    expect(block.categoryId, isNull);
    expect(block.note, isNull);
    // 元数据由调用方提供，不按事实边界或全局当前时间补写。
    expect(block.createdAt, 5005);
    expect(block.updatedAt, 6006);
  });

  test('TB-001：精确或近似边界都拒绝零时长和反向区间', () {
    for (final precision in TimePrecision.values) {
      for (final endedAt in [1001, 1000]) {
        expect(
          () => _block(endedAt: endedAt, startPrecision: precision),
          throwsArgumentError,
        );
      }
    }
  });

  test('TB-001：保留毫秒，按半开区间解释端点', () {
    final block = _block(startedAt: 1001, endedAt: 1002);
    expect(block.startedAt, 1001);
    expect(block.endedAt, 1002);
    expect(
      containsInstant(
        startedAt: block.startedAt,
        endedAt: block.endedAt,
        instant: 1001,
      ),
      isTrue,
    );
    expect(
      containsInstant(
        startedAt: block.startedAt,
        endedAt: block.endedAt,
        instant: 1002,
      ),
      isFalse,
    );
  });

  test('Q-016：允许很久以前、未来、跨日和长区间', () {
    for (final (start, end) in [
      (-2208988800000, -2208988799999),
      (4102444800000, 4102444800001),
      (86399999, 86400001),
      (-2208988800000, 4102444800000),
    ]) {
      final block = _block(startedAt: start, endedAt: end);
      expect(block.startedAt, start);
      expect(block.endedAt, end);
    }
  });

  test('TB-005：known 拒绝 null、空串和纯空白标题', () {
    for (final title in [null, '', '  ', '\t\n\r', '\u3000']) {
      expect(() => _block(title: title), throwsArgumentError);
    }
  });

  test('TB-006：unknown 空标题规范化为 null，不生成固定文案', () {
    for (final title in [null, '', ' \n\t ']) {
      final block = _block(
        knowledgeState: BlockKnowledgeState.unknown,
        title: title,
      );
      expect(block.title, isNull);
    }
  });

  test('TB-006：unknown 允许保留清理后的非空标题', () {
    final block = _block(
      knowledgeState: BlockKnowledgeState.unknown,
      title: '  只记得出过门  ',
    );
    expect(block.title, '只记得出过门');
  });

  test('TB-002–TB-004、Q-004：已知性、目标有无、起止精度相互独立', () {
    for (final state in BlockKnowledgeState.values) {
      for (final goalId in [null, _goalId]) {
        for (final start in TimePrecision.values) {
          for (final end in TimePrecision.values) {
            final block = _block(
              knowledgeState: state,
              goalId: goalId,
              startPrecision: start,
              endPrecision: end,
            );
            expect(block.knowledgeState, state);
            expect(block.goalId, goalId);
            expect(block.startPrecision, start);
            expect(block.endPrecision, end);
          }
        }
      }
    }
  });

  test('MODEL-002：清理首尾空白，保留内部空格、换行和段落', () {
    final block = _block(
      title: ' \t阅读  论文\n做笔记\n ',
      note: '\n 第一段  内容\n\n第二段\t内容 \t',
    );
    expect(block.title, '阅读  论文\n做笔记');
    expect(block.note, '第一段  内容\n\n第二段\t内容');
    for (final note in [null, '', ' \n\t ']) {
      expect(_block(note: note).note, isNull);
    }
  });

  test('MODEL-002：两种已知性的标题上限均为 200，清理后计数', () {
    for (final state in BlockKnowledgeState.values) {
      final title = '字' * 200;
      expect(_block(knowledgeState: state, title: ' $title ').title, title);
      expect(
        () => _block(knowledgeState: state, title: '$title字'),
        throwsArgumentError,
      );
    }
  });

  test('MODEL-002：备注上限为 2000，超限拒绝而非截断', () {
    final note = '记' * 2000;
    expect(_block(note: ' $note ').note, note);
    expect(() => _block(note: '$note记'), throwsArgumentError);
  });

  test('Q-015：补充平面 emoji 按一个码点计数，不按 UTF-16 单元计数', () {
    final title = '😀' * 200;
    final note = '😀' * 2000;
    expect(_block(title: title, note: note).title, title);
    expect(_block(title: title, note: note).note, note);
    expect(() => _block(title: '$title😀'), throwsArgumentError);
    expect(() => _block(note: '$note😀'), throwsArgumentError);
  });

  test('Q-015：组合字符逐码点计数，保留原始组合形式', () {
    final title = 'e\u0301' * 100;
    expect(_block(title: title).title, title);
    expect(() => _block(title: '${title}e'), throwsArgumentError);
    // 一个家庭 emoji 包含七个码点；不按一个可见字符计数。
    const family = '👨‍👩‍👧‍👦';
    expect(_block(title: family * 28).title, family * 28);
    expect(() => _block(title: family * 29), throwsArgumentError);
  });

  test('TB-009：分类扩展值原样保留，不执行分类查询或关联行为', () {
    final block = _block(categoryId: 'reserved-category');
    expect(block.categoryId, 'reserved-category');
  });

  test('Q-018：拒绝非法实体身份和非法 Goal 标识', () {
    expect(() => _block(id: 'not-a-uuid'), throwsArgumentError);
    expect(() => _block(goalId: 'not-a-uuid'), throwsArgumentError);
  });
}
