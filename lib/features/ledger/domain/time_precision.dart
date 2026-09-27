/// 时间边界的可信精度（TB-002、TB-004、SL-003）。
///
/// TimeBlock 与 SleepSession 的起止边界分别表达精度。
/// 近似不表示活动内容未知，也不是对用户的质量评分。
enum TimePrecision {
  /// 精确边界。
  exact,

  /// 近似边界，仍有具体时间用于排序和计算。
  approximate,
}
