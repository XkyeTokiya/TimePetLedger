/// UTC epoch 毫秒时间点（Q-017），沿用 int，不另建包装层。
///
/// 不是自然日期，也不是分钟数；不隐式读取时钟或量化到分钟。
/// exact / approximate 描述边界可信度，独立于这里的毫秒分辨率。
typedef InstantMilliseconds = int;

/// 返回严格正区间的毫秒时长，不对单条记录舍入（Q-016、Q-017）。
int intervalMilliseconds({
  required InstantMilliseconds startedAt,
  required InstantMilliseconds endedAt,
}) {
  if (startedAt >= endedAt) {
    throw ArgumentError('startedAt must be before endedAt');
  }
  return endedAt - startedAt;
}

/// 判断时间点是否落在半开区间 [startedAt, endedAt) 内（Q-017）。
///
/// 只表达端点合同；不执行跨事实冲突检查或日账本窗口选择。
bool containsInstant({
  required InstantMilliseconds startedAt,
  required InstantMilliseconds endedAt,
  required InstantMilliseconds instant,
}) {
  intervalMilliseconds(startedAt: startedAt, endedAt: endedAt);
  return startedAt <= instant && instant < endedAt;
}

/// 将已汇总的非负毫秒时长四舍五入为展示分钟（Q-017）。
///
/// 仅在最终展示时调用；中间计算与求和保留毫秒，分钟级 UI 输入
/// 不改变内部数值分辨率。这里不推导 hasApproximation。
int roundedDisplayMinutes(int totalMilliseconds) {
  if (totalMilliseconds < 0) {
    throw ArgumentError.value(totalMilliseconds, 'totalMilliseconds');
  }
  final wholeMinutes = totalMilliseconds ~/ Duration.millisecondsPerMinute;
  final remainder = totalMilliseconds % Duration.millisecondsPerMinute;
  return wholeMinutes + (remainder >= 30000 ? 1 : 0);
}
