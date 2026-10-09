# 首页滚动标签稳定性与页头星期压缩报告

日期：2026-10-10（Asia/Shanghai）。任务：HOME-INTERACTION-IMPL-03（用户反馈修复）。范围：①滚动首页时时间轴文字闪烁（例如“尚未记录”）；②星期信息独占一行浪费空间。依据：[HOME-INTERACTION-01](../planning/HOME_INTERACTION_DESIGN.md)、[design.md §首页视觉细化](../../design.md#首页视觉细化2026-10-09用户九点反馈)、[HOME-DESIGN-01 标签位置推荐](../planning/HOME_PROPORTIONAL_TIMELINE_DESIGN.md)与Q-042–Q-044。结果：两项修复完成，工程回归与静态分析通过；真机帧稳定性与人工读屏仍沿HOME-INTERACTION-IMPL-02保持PARTIAL。

## 1. 问题与修复

### 1.1 滚动时时间轴文字闪烁

逐帧探测（临时测试，验证后删除）显示：长Gap进入视口时，同一段“尚未记录”先以单行状态词出现，随后在紧凑 / 完整形态之间切换（10sp↔12sp、行数与内容变化）；快速滑动时边缘文字会按上一帧视口延迟隐藏 / 出现。机制：

- 标签形态（单行 / 紧凑 / 完整）由“块与视口可见交集高度”在滚动中逐帧判定，跨越阈值时同一段文字反复变形。
- 可见视口在帧结束时才发布（`home_timeline_tab.dart` 原 `_publishViewport`），标签使用上一帧坐标：贴顶标签滞后、边缘隐藏偏晚，快速滑动时半截文字会闪出。

修复（不改块高、刻度、端点与语义节点）：

- `home_day_axis.dart`：`HomeAxisViewport` 改为发布滚动内容坐标下的可见波段，轴按 `pixels − 内容偏移` 换算局部交集；内容偏移经 `localToGlobal(ancestor: 视口直接子级)` 获得，滚动中稳定，标签与当前帧同坐标。`full` / `compactRange` 只由块高决定，滚动中不再变形；保留既有“视口交集不足一行不画半截文字”“小时标签整行可见才绘制”规则。
- `home_timeline_tab.dart`：`_onScroll` 同步发布波段（帧前更新），帧后布局发布复用同一函数；`HomeAxisViewport.update` 同值不重复通知，减少无效重建。

### 1.2 星期独占一行

`home_day_header.dart`：星期默认并入日期行（Wrap 居中成组，12sp辅助色）；展开与紧凑两个稳定态都放得下才并入，避免收放动画中途换行；放不下（窄屏、大字、跨年长日期或行内还需“返回今天”）时回退日期下方独立行。实际今天的页头没有“返回今天”，不再为星期保留第二行。行为已同步到 [design.md](../../design.md#首页视觉细化2026-10-09用户九点反馈)、[HOME_INTERACTION_DESIGN](../planning/HOME_INTERACTION_DESIGN.md) §2.2–§2.3与[HOME_PROPORTIONAL_TIMELINE_DESIGN](../planning/HOME_PROPORTIONAL_TIMELINE_DESIGN.md)日期区。

## 2. 验证

| 项目 | 命令 | 结果 |
| --- | --- | --- |
| 格式 | `dart format`（本轮改动的4个Dart文件） | 无额外改动 |
| 静态分析 | `flutter analyze` | `No issues found` |
| 相关回归 | `flutter test test/app/home_proportional_timeline_test.dart` | 19通过（含新增3项） |
| 相关回归 | `home_feed_flow / home_navigation_flow / home_motion / home_timeline_density / home_r1_visual / home_suggestion_entry / home_feed_nav_capture / ledger_feed_controller_test` | 49通过、1失败（既有基线下述） |
| 相关回归 | `settings_visual_test / drift_app_preferences_store_test` | 5通过 |
| Web构建 | `flutter build web` | 通过，`✓ Built build/web`（既有CupertinoIcons字体资产警告） |
| Android构建 | `flutter build apk --debug` | 通过，`build/app/outputs/flutter-apk/app-debug.apk`（既有Java native access警告） |
| 全量 | `flutter test --reporter compact` | 764通过 / 11跳过 / 141失败，对照记录基线 761 / 11 / 141：新增3项即本轮回归，失败集合与数量不变 |
| 截图检查 | `HOME_TIME_CAPTURE_DIR` 临时输出（不纳入仓库） | 360×1今天日期行含“周三 · 今天”、无第二行；320×1.5与320×1回退日期下方独立行；320×1紧凑态菜单并入日期行，均无溢出 |

新增回归（`test/app/home_proportional_timeline_test.dart`）：长Gap滚动全程标签形态稳定（不随可见交集退化为其他形态）；今天星期与日期同行且第二行不再保留；窄屏大字回退到日期下方。

既有失败说明：`home_feed_nav_capture_test` 的“capture home feed at 360 and 320 with large text”期望 `7 小时` 文本，当前数据下不存在。在干净HEAD检出（临时worktree）以完全相同的方式失败，属仓库既有141失败集合，不是本轮引入；未在本任务扩大修复。

## 3. 未完成 / 限制

未在物理设备验证滚动帧稳定性、惯性过程的观感、系统边缘手势与误触；TalkBack / VoiceOver人工读屏未执行，平台验收继续为PARTIAL。本轮不改领域对象、schema、依赖、提醒 / 初始化算法或其他任务状态。
