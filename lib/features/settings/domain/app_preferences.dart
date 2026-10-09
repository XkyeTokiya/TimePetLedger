import '../../../core/identity/entity_id.dart';

/// 目标热力图日期范围；本周为本自然周，本月为本自然月（Q-033）。
enum HeatRange { week, month }

/// 记录方式；问答引导与表单是两种既有输入路径（Q-026）。
enum RecordingMode { guided, form }

/// 主题配色方案（Q-041）；读取时 null 按 [ThemeScheme.defaultM3] 解析。
enum ThemeScheme { defaultM3, blue, green, orange, teal, warmPaper, dynamic }

/// 外观模式三态（Q-041）；读取时 null 按 [AppThemeMode.system] 解析。
enum AppThemeMode { system, light, dark }

/// 字体选项（Q-041）；读取时 null 按 [AppFontChoice.system] 解析。
enum AppFontChoice { system, serif }

/// 首页快捷区所在侧（Q-042）；读取时 null 按左侧解析。
enum HomeQuickPanelSide { left, right }

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
    this.sleepReminderMinutes,
    this.reviewReminderMinutes,
    this.themeScheme,
    this.themeMode,
    this.fontChoice,
    this.homeQuickPanelSide,
  });

  /// 用户显式指定的常用目标；归档 / 删除后清除（Q-025）。
  final EntityId? commonGoalId;

  /// 目标热力图日期范围；与目标详情共享同一偏好。
  final HeatRange? heatRange;

  /// 新记录的输入方式；既有草稿保留自身方式。
  final RecordingMode? recordingMode;

  /// 首页提醒 / 问候区域总开关。
  final bool? reminders;

  /// 睡眠建议时点（当地时刻的分钟数）；null 表示尚未选择，按 08:00 展示（Q-029）。
  final int? sleepReminderMinutes;

  /// 复盘建议时点（当地时刻的分钟数）；null 表示尚未选择，按 22:00 展示（Q-029）。
  final int? reviewReminderMinutes;

  /// 主题配色方案（Q-041）；null 按默认 M3 解析。
  final ThemeScheme? themeScheme;

  /// 外观模式（Q-041）；null 按跟随系统解析。
  final AppThemeMode? themeMode;

  /// 字体选项（Q-041）；null 按系统字体解析。
  final AppFontChoice? fontChoice;

  /// 首页快捷区位置；是本机界面偏好，不进入账本事实。
  final HomeQuickPanelSide? homeQuickPanelSide;

  AppPreferences copyWith({
    EntityId? commonGoalId,
    bool clearCommonGoal = false,
    HeatRange? heatRange,
    RecordingMode? recordingMode,
    bool? reminders,
    int? sleepReminderMinutes,
    int? reviewReminderMinutes,
    ThemeScheme? themeScheme,
    AppThemeMode? themeMode,
    AppFontChoice? fontChoice,
    HomeQuickPanelSide? homeQuickPanelSide,
  }) => AppPreferences(
    commonGoalId: clearCommonGoal ? null : (commonGoalId ?? this.commonGoalId),
    heatRange: heatRange ?? this.heatRange,
    recordingMode: recordingMode ?? this.recordingMode,
    reminders: reminders ?? this.reminders,
    sleepReminderMinutes: sleepReminderMinutes ?? this.sleepReminderMinutes,
    reviewReminderMinutes: reviewReminderMinutes ?? this.reviewReminderMinutes,
    themeScheme: themeScheme ?? this.themeScheme,
    themeMode: themeMode ?? this.themeMode,
    fontChoice: fontChoice ?? this.fontChoice,
    homeQuickPanelSide: homeQuickPanelSide ?? this.homeQuickPanelSide,
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
