/// 用户对部分时间事实的可选节奏解释（RH-002）。
///
/// 不标记由 RhythmAnnotation 不存在表达，不产生 neutral 状态。
/// 节奏不是 TimeBlock 的活动类别，也不是自动生产力判断。
enum RhythmState {
  /// 主要产生了用户能够确认的目标推进。
  progress,

  /// 尝试推进目标相关事情，但主要消耗于阻力、停滞或反复尝试。
  stuck,

  /// 主要作用是从无法继续的状态重新获得继续行动的可能。
  recovery,
}
