/// 独立睡眠事实 SleepSession 的类型（SL-003）。
///
/// 类型与起止边界精度独立，不表达睡眠质量或恢复方式，
/// 也不规定用于自动分类的时长阈值。
enum SleepType {
  /// 主睡眠。
  mainSleep,

  /// 午睡或小睡。
  nap,
}
