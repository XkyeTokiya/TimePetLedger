import 'time_contract.dart';

/// 实体的创建与更新时间；不包含事实起止，也不是实体基类（Q-018）。
///
/// 读回已有记录时显式提供两个值，不根据事实时间或当前时间补默认值。
typedef Timestamps = ({
  InstantMilliseconds createdAt,
  InstantMilliseconds updatedAt,
});

/// 新建记录使用调用方提供的同一次取时。
///
/// 返回待保存值；只有保存成功才能将其发布为已提交元数据。
Timestamps timestampsForCreation({required InstantMilliseconds now}) =>
    (createdAt: now, updatedAt: now);

/// 根据明确的保存结果返回已提交时间戳（Q-018）。
///
/// 调用方判断内容是否实际变化，并负责事务及提交；本函数不执行 I/O。
/// 失败或无变化均保留原值，读取直接使用原值。createdAt 始终不变。
/// 不额外施加时间戳顺序约束或时钟回拨修正规则。
Timestamps timestampsAfterSave({
  required Timestamps previous,
  required InstantMilliseconds now,
  required bool contentChanged,
  required bool saveSucceeded,
}) => contentChanged && saveSucceeded
    ? (createdAt: previous.createdAt, updatedAt: now)
    : previous;
