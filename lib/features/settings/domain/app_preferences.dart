import '../../../core/identity/entity_id.dart';

/// 目标热力图日期范围；本周为本自然周，本月为本自然月（Q-033）。
enum HeatRange { week, month }

/// 记录方式；问答引导与表单是两种既有输入路径（Q-026）。
enum RecordingMode { guided, form }

/// 本机偏好，不是正式领域事实，也不代表已提交的业务数据。
///
/// 字段可为 null 表示"用户尚未选择"；调用方不得用默认值替产品决定
/// 首次取值（Q-026 / Q-029 / Q-033）。
final class AppPreferences {
  const AppPreferences({
    this.commonGoalId,
    this.heatRange,
    this.recordingMode,
    this.reminders,
  });

  /// 用户显式指定的常用目标；归档 / 删除后清除（Q-025）。
  final EntityId? commonGoalId;

  /// 目标热力图日期范围；与目标详情共享同一偏好。
  final HeatRange? heatRange;

  /// 新记录的输入方式；既有草稿保留自身方式。
  final RecordingMode? recordingMode;

  /// 首页提醒 / 问候区域总开关。
  final bool? reminders;

  AppPreferences copyWith({
    EntityId? commonGoalId,
    bool clearCommonGoal = false,
    HeatRange? heatRange,
    RecordingMode? recordingMode,
    bool? reminders,
  }) => AppPreferences(
    commonGoalId: clearCommonGoal ? null : (commonGoalId ?? this.commonGoalId),
    heatRange: heatRange ?? this.heatRange,
    recordingMode: recordingMode ?? this.recordingMode,
    reminders: reminders ?? this.reminders,
  );
}

/// 偏好与常用目标的本地存取边界；失败不得表现为成功。
abstract interface class AppPreferencesStore {
  Future<AppPreferences> read();
  Future<void> write(AppPreferences preferences);
}

class AppPreferencesStorageException implements Exception {
  const AppPreferencesStorageException(this.cause);
  final Object cause;
  @override
  String toString() => 'Local preferences are unavailable.';
}
