import '../../../core/identity/entity_id.dart';

/// 高级设置的数据概况计数；只含业务数据，不含本机偏好（Q-034）。
final class DataCounts {
  const DataCounts({
    required this.activities,
    required this.sleep,
    required this.goals,
    required this.reviews,
    required this.drafts,
  });

  final int activities;
  final int sleep;
  final int goals;
  final int reviews;
  final int drafts;

  bool get isEmpty =>
      activities == 0 && sleep == 0 && goals == 0 && reviews == 0;
}

/// 高级设置的数据操作；清空保留设置，添加仅在空数据时执行。
abstract interface class DataMaintenance {
  Future<DataCounts> counts();

  Future<void> clear();

  Future<void> seed({
    required EntityId Function() newGoalId,
    required EntityId Function() newFactId,
    required int now,
  });
}

/// 已有数据时请求添加测试数据；调用方应据此给出“已有数据”说明。
class DataMaintenanceConflict implements Exception {
  const DataMaintenanceConflict();
  @override
  String toString() => 'Data already exists.';
}

class DataMaintenanceStorageException implements Exception {
  const DataMaintenanceStorageException(this.cause);
  final Object cause;
  @override
  String toString() => 'Data maintenance failed.';
}
