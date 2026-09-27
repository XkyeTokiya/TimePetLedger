import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _otherId = '87654321-4321-4abc-9123-123456789abc';

Goal _existing({
  String id = _id,
  String name = '毕业设计',
  GoalStatus status = GoalStatus.active,
  int? archivedAt,
}) => Goal.reconstitute(
  id: id,
  name: name,
  status: status,
  createdAt: 1001,
  updatedAt: 2002,
  archivedAt: archivedAt,
);

void main() {
  test('Q-006、Q-018：新建固定 active，无归档时间，元数据使用显式取时', () {
    final goal = Goal.create(id: _id, name: ' 毕业设计 ', now: 3003);
    expect(goal.id, _id);
    expect(goal.name, '毕业设计');
    expect(goal.status, GoalStatus.active);
    expect(goal.archivedAt, isNull);
    expect(goal.createdAt, 3003);
    expect(goal.updatedAt, 3003);
  });

  test('GO-002：还原两种合法状态，保留身份和全部元数据', () {
    for (final (status, archivedAt) in [
      (GoalStatus.active, null),
      (GoalStatus.archived, 1505),
    ]) {
      final goal = _existing(status: status, archivedAt: archivedAt);
      expect(goal.id, _id);
      expect(goal.status, status);
      expect(goal.archivedAt, archivedAt);
      expect(goal.createdAt, 1001);
      expect(goal.updatedAt, 2002);
    }
  });

  test('GO-002：拒绝 active 带归档时间或 archived 缺归档时间', () {
    expect(() => _existing(archivedAt: 1505), throwsArgumentError);
    expect(() => _existing(status: GoalStatus.archived), throwsArgumentError);
  });

  test('Q-018：还原不偷偷修正时钟回拨后的元数据', () {
    final goal = Goal.reconstitute(
      id: _id,
      name: '毕业设计',
      status: GoalStatus.archived,
      createdAt: 3003,
      updatedAt: 1001,
      archivedAt: 0,
    );
    expect(goal.createdAt, 3003);
    expect(goal.updatedAt, 1001);
    expect(goal.archivedAt, 0);
  });

  test('Q-015：新建和已有对象均拒绝空串及纯空白名称', () {
    for (final name in ['', ' ', '\t\n\r', '\u3000']) {
      expect(
        () => Goal.create(id: _id, name: name, now: 1001),
        throwsArgumentError,
      );
      expect(() => _existing(name: name), throwsArgumentError);
      expect(
        () => _existing(
          name: name,
          status: GoalStatus.archived,
          archivedAt: 1505,
        ),
        throwsArgumentError,
      );
    }
  });

  test('MODEL-002：首尾清理，内部空格、换行、段落与大小写保留', () {
    const name = ' \tGoal  论文\n\n第一章\t内容\n ';
    const normalized = 'Goal  论文\n\n第一章\t内容';
    expect(Goal.create(id: _id, name: name, now: 1001).name, normalized);
    expect(_existing(name: name).name, normalized);
  });

  test('Q-015：清理后接受 200 码点，拒绝 201，补充平面字符计一个', () {
    for (final character in ['字', '😀']) {
      final name = character * 200;
      expect(Goal.create(id: _id, name: ' $name ', now: 1001).name, name);
      expect(
        () => Goal.create(id: _id, name: '$name$character', now: 1001),
        throwsArgumentError,
      );
      for (final status in GoalStatus.values) {
        final archivedAt = status == GoalStatus.archived ? 1505 : null;
        expect(
          _existing(
            name: ' $name ',
            status: status,
            archivedAt: archivedAt,
          ).name,
          name,
        );
        expect(
          () => _existing(
            name: '$name$character',
            status: status,
            archivedAt: archivedAt,
          ),
          throwsArgumentError,
        );
      }
    }
  });

  test('Q-015：组合字符按码点计数，原始组合形式保留', () {
    final name = 'e\u0301' * 100;
    expect(_existing(name: name).name, name);
    expect(() => _existing(name: '${name}e'), throwsArgumentError);
  });

  test('Q-019：新建和已有状态均允许同名，按各自 id 区分', () {
    final first = Goal.create(id: _id, name: '毕业设计', now: 1001);
    final second = Goal.create(id: _otherId, name: '毕业设计', now: 1001);
    expect(first.name, second.name);
    expect(first.id, isNot(second.id));
    for (final status in GoalStatus.values) {
      // 表达改名后的合法字段结果，不执行改名或保存操作。
      final renamed = _existing(
        id: _otherId,
        name: first.name,
        status: status,
        archivedAt: status == GoalStatus.archived ? 1505 : null,
      );
      expect(renamed.name, first.name);
      expect(renamed.id, _otherId);
    }
  });

  test('Q-018：新建及还原均拒绝非法身份', () {
    expect(
      () => Goal.create(id: 'invalid', name: '毕业设计', now: 1001),
      throwsArgumentError,
    );
    expect(() => _existing(id: 'invalid'), throwsArgumentError);
  });
}
