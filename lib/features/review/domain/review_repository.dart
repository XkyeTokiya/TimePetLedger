import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/time/time_contract.dart';
import 'daily_review.dart';

/// 按日读取；显式创建与更正，不以 upsert 覆盖同日另一份复盘。
/// 成功返回代表已提交；身份和当前时间由调用方提供。
abstract interface class ReviewRepository {
  Future<DailyReview?> findByDate(CivilDate date);
  Future<DailyReview> create({
    required EntityId id,
    required CivilDate date,
    required String tomorrowFirstStepText,
    required InstantMilliseconds now,
    String? summary,
    String? reflection,
    EntityId? tomorrowFirstStepGoalId,
  });

  /// 省略可空字段保留，(value: null) 清空；日期冲突拒绝，不覆盖。
  Future<DailyReview> update({
    required EntityId id,
    required InstantMilliseconds now,
    CivilDate? date,
    ({String? value})? summary,
    ({String? value})? reflection,
    String? tomorrowFirstStepText,
    ({EntityId? value})? tomorrowFirstStepGoalId,
  });

  /// 缺失时幂等完成，不删除当天事实。
  Future<void> delete(EntityId id);
}

class ReviewAlreadyExistsException implements Exception {
  const ReviewAlreadyExistsException(this.id);
  final EntityId id;
  @override
  String toString() => 'Review identity already exists.';
}

class ReviewNotFoundException implements Exception {
  const ReviewNotFoundException(this.id);
  final EntityId id;
  @override
  String toString() => 'Review no longer exists.';
}

class ReviewDataException implements Exception {
  const ReviewDataException();
  @override
  String toString() => 'Stored review or referenced Goal data is invalid.';
}

class ReviewStorageException implements Exception {
  const ReviewStorageException(this.cause);

  /// 仅供诊断，不能将底层 SQL 作为用户错误消息展示。
  final Object cause;
  @override
  String toString() => 'Review storage operation failed.';
}
