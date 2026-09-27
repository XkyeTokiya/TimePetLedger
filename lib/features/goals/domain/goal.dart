import 'package:time_pet_ledger/core/identity/entity_id.dart';
import 'package:time_pet_ledger/core/time/time_contract.dart';
import 'package:time_pet_ledger/core/time/timestamps.dart';

import 'goal_status.dart';

/// 简单时间归属对象（GO-001），不要求名称唯一或拥有相关记录。
///
/// 构造校验字段，归档 / 恢复返回不可变的待保存对象，不执行 I/O。
/// data 仅在保存成功后发布返回值；失败保留原对象及其全部元数据。
/// 状态操作始终保留 id，data 不得删除或清空 TimeBlock / DailyReview
/// 的既有引用；新增关联须使用当前 Goal 状态校验（Q-006）。
final class Goal {
  /// 新目标只能为 active，时间由调用方显式提供（Q-006、Q-018）。
  factory Goal.create({
    required EntityId id,
    required String name,
    required InstantMilliseconds now,
  }) {
    final timestamps = timestampsForCreation(now: now);
    return Goal.reconstitute(
      id: id,
      name: name,
      status: GoalStatus.active,
      createdAt: timestamps.createdAt,
      updatedAt: timestamps.updatedAt,
    );
  }

  /// 从明确字段还原已有对象；不代表新建、状态转换或成功保存。
  ///
  /// Q-006：active 没有归档时间；archived 必须保留归档时间。
  /// 不读取时钟、不补写元数据，也不增加时间戳顺序约束。
  Goal.reconstitute({
    required EntityId id,
    required String name,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  }) : id = requireUuidV4(id),
       name = _normalizeName(name) {
    if ((status == GoalStatus.archived) != (archivedAt != null)) {
      throw ArgumentError.value(
        archivedAt,
        'archivedAt',
        'GO-002: Required for archived; must be null for active',
      );
    }
  }

  final EntityId id;

  /// 清理首尾空白后的必填短文本，最多 200 个 Unicode 码点。
  final String name;
  final GoalStatus status;
  final InstantMilliseconds createdAt;
  final InstantMilliseconds updatedAt;
  final InstantMilliseconds? archivedAt;

  /// Q-015 / Q-018：规范化后名称未变时不刷新时间；允许与其他目标同名。
  Goal rename({required String name, required InstantMilliseconds now}) {
    final normalized = _normalizeName(name);
    if (normalized == this.name) return this;
    return Goal.reconstitute(
      id: id,
      name: normalized,
      status: status,
      createdAt: createdAt,
      updatedAt: now,
      archivedAt: archivedAt,
    );
  }

  /// active → archived；写入同一次显式取时，保留名称、身份与创建时间。
  /// 已归档时幂等返回原对象，不重写 archivedAt / updatedAt。
  /// 已有引用继续有效，归档后禁止新增关联；本方法不查询或改写引用。
  Goal archive({required InstantMilliseconds now}) {
    if (status == GoalStatus.archived) return this;
    return Goal.reconstitute(
      id: id,
      name: name,
      status: GoalStatus.archived,
      createdAt: createdAt,
      updatedAt: now,
      archivedAt: now,
    );
  }

  /// archived → active；清除归档时间，恢复新增关联资格。
  /// 已 active 时幂等返回原对象，不更新元数据。
  /// 与 archive 一样仅产生待保存值，不表示已经提交成功（Q-018）。
  Goal restore({required InstantMilliseconds now}) {
    if (status == GoalStatus.active) return this;
    return Goal.reconstitute(
      id: id,
      name: name,
      status: GoalStatus.active,
      createdAt: createdAt,
      updatedAt: now,
    );
  }
}

String _normalizeName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.runes.length > 200) {
    throw ArgumentError.value(
      value,
      'name',
      'MODEL-002: Must contain 1 to 200 Unicode code points after trimming',
    );
  }
  return normalized;
}
