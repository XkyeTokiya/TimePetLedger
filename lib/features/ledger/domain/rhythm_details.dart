/// 可选单选原因（Q-007）；other 不要求补充文字。
enum StuckReasonCode {
  taskTooLarge,
  unclearNextStep,
  sleepy,
  brainFog,
  anxious,
  interrupted,
  unsure,
  other,
}

/// 可选单选恢复方式（Q-007）；睡眠是独立事实。
enum RecoveryMethod {
  walk,
  meal,
  shower,
  empty,
  entertainment,
  switchTask,
  breakDownTask,
  askForHelp,
  other,
}

/// 用户主观恢复效果，不转换为数值评分（Q-007）。
enum RecoveryQuality { notRecovered, partlyRecovered, readyToContinue }
