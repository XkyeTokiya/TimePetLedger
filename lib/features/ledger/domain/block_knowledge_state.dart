/// TimeBlock 活动内容的已知性，与时间精度独立（TB-004）。
///
/// Unknown 是已交代的时间事实；Gap 是尚未处理的派生区间，
/// 不属于已知性，也不代表记录失败。
enum BlockKnowledgeState {
  /// 知道这段时间大概做了什么。
  known,

  /// 知道时间已经过去，但无法恢复活动内容。
  unknown,
}
