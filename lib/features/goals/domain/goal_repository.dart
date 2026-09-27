import '../../../core/identity/entity_id.dart';
import '../../../core/time/time_contract.dart';
import 'goal.dart';

/// Goal 存取边界；调用方提供身份和取时，成功返回代表事务已提交。
///
/// 非法输入抛 ArgumentError；存储失败抛 GoalStorageException，不报告成功。
/// 不提供任意 save/upsert，以免覆盖身份、创建时间或绕过生命周期。
abstract interface class GoalRepository {
  /// 普通目标选择仅包含 active；返回顺序不构成产品排序合同。
  Future<List<Goal>> listActive();

  /// 历史引用 / 恢复操作可按身份读到 archived；不存在返回 null。
  Future<Goal?> findById(EntityId id);

  /// 只能创建 active；重复身份抛 GoalAlreadyExistsException，不覆盖。
  Future<Goal> create({
    required EntityId id,
    required String name,
    required InstantMilliseconds now,
  });

  /// 以下更正读取当前已提交对象；缺失抛 GoalNotFoundException。
  Future<Goal> rename({
    required EntityId id,
    required String name,
    required InstantMilliseconds now,
  });
  Future<Goal> archive({
    required EntityId id,
    required InstantMilliseconds now,
  });
  Future<Goal> restore({
    required EntityId id,
    required InstantMilliseconds now,
  });

  /// 在同一写事务内查两类引用：有引用归档，无引用物理删除。
  /// notFound 明确表示未找到对象，调用方不会误认为发生了物理删除。
  Future<GoalDeleteResult> delete({
    required EntityId id,
    required InstantMilliseconds now,
  });
}

enum GoalDeleteResult { deleted, archived, notFound }

class GoalNotFoundException implements Exception {
  const GoalNotFoundException(this.id);
  final EntityId id;
  @override
  String toString() => 'Goal no longer exists.';
}

class GoalAlreadyExistsException implements Exception {
  const GoalAlreadyExistsException(this.id);
  final EntityId id;
  @override
  String toString() => 'Goal identity already exists.';
}

/// 已存值不满足类型 / 领域合同，不静默补默认值或修复数据。
class GoalDataException implements Exception {
  const GoalDataException();
  @override
  String toString() => 'Stored Goal data is invalid.';
}

class GoalStorageException implements Exception {
  const GoalStorageException(this.cause);

  /// 仅供诊断；用户反馈使用异常类型，不直接显示驱动信息。
  final Object cause;
  @override
  String toString() => 'Goal storage operation failed.';
}
