# HOME-NAV-02 · 首页导航与连续时间轴修复

2026-10-07。状态：本轮修复完成，相关检查通过；全仓库测试基线仍有103项既存失败。

依据与验收见[修复方案](../planning/HOME_NAV_FEED_FIXES.md)，授权及产品追溯见[Q-027](../domain/OPEN_QUESTIONS.md#q-027)与[Source of Truth](../../time-ledger-domain-model-v4-proposal.md)。本轮保留其他agent的首页改版，只修复独立验证中的边界问题与大字排版；不推进其他任务。

## 修复结果

| 问题 | 最终行为与实现 |
| --- | --- |
| 切日读取失败呈现假空态 | `ledger_feed_controller.dart`先读取目标窗口，成功后一起提交日期、范围、投影、上下文及定位请求；失败保留旧记录、统计、日期与阅读位置。重试继续原目标，过期成功 / 失败及dispose不会覆盖较新状态。 |
| 斜滑方向判断无效 | `home_shell.dart`使用原始指针的双轴位移，横向识别器负责手势竞争；保留水平≥64且大于垂直1.6倍、两侧32保留区，取消和多指不触发切日。 |
| 快速连续切日 | `home_day_header.dart`传递前 / 后一天的方向，与横滑一起从正在装载的目标推进；避免旧画面日期导致连续点击丢失一天。 |
| 重建后跨午夜失去跟随 | `home_shell.dart`的build不再写跟随状态，仅成功装载后更新观察到的今天；午夜后先重建、刷新失败再重试都能继续跟随今天，历史日期保持。 |
| 恢复前台统计不刷新 | `main_app.dart`在首页为当前路由且无编辑交互时，重读首页投影后重算建议；今天窗口随当前时刻更新。独立页 / 编辑器继续管理自己的日期与草稿。 |
| 窄屏大字标题被时长挤断 | `home_timeline_tab.dart`按实际字体、继承样式、缩放与可用宽度决定同行或上下排列；完整睡眠时长按数字与单位整体换行，保留完整无障碍语义。 |

领域口径不变：Unknown计入已交代，Gap仍为派生区间，今天未来部分不计Gap；跨日睡眠保留同一事实身份与完整起止，不拆持久化、不重复统计。没有修改repository、数据库、依赖或持久化事实。

## 正式回归证据

新增13项测试，修复验证副本中的发现进入正式测试；截图用例增加实际行框及无障碍语义断言。

- `test/features/ledger/presentation/ledger_feed_controller_test.dart`：5项，窗口原子提交、失败重试、陈旧响应、dispose、首读失败与真实空数据、历史焦点保持、同一now以及扩展不取消切日。
- `test/app/home_feed_flow_test.dart`：新增5项，水平识别先获胜后累计120×100的斜滑拒绝、短滑拒绝 / 明确横滑通过、切日失败保留记录 / 位置及按钮重试、午夜先重建 / 失败重试、历史日期保持、快速按钮与滑动从待定位日期推进。
- `test/app/home_navigation_flow_test.dart`：新增3项，12:00到15:00恢复后未记录从11小时更新为14小时、跨午夜跟随与历史日期保持、复盘编辑跨午夜恢复后日期与已输入草稿保持。生命周期用例使用完整合法状态转换。
- `test/app/home_feed_nav_capture_test.dart`：320宽 / 1.5倍字体下“主睡眠”及数字单位的实际文字框各为一行，完整睡眠时长仍可读出；360 / 320 / 大字截图无布局异常。

斜滑正式用例先移动(80,0)让水平识别器获胜，再移动(40,100)，避免将正常垂直滚动跨日期边界引起的浏览日变化混同为显式切日；原始位移的1.6倍方向约束在该用例中直接受到验证。

## 实际验证

均在仓库根目录执行，测试时区为Asia/Shanghai。

| 检查 | 结果 |
| --- | --- |
| 9个本轮涉及Dart文件，`dart format --output=none --set-exit-if-changed` | 退出0，0 changed |
| `flutter analyze --no-pub` | 退出0，No issues found |
| 首页专项4个文件 | 25项全部通过 |
| 下方11个相关测试文件 | 64项全部通过 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter json` | 792通过、7跳过、103失败，退出1；基线未通过 |
| 失败集合比对（文件 + 用例名） | 与修复前779通过 / 103失败的工作区，以及HEAD `f85ca46`的103项失败集合完全相同，无新增或消失的失败 |
| `flutter build web --no-pub` | 退出0，生成build/web，Wasm dry run成功 |
| `flutter build apk --debug --no-pub` | 退出0，生成build/app/outputs/flutter-apk/app-debug.apk |
| `git diff --check` | 退出0 |

相关测试实际命令：

```sh
TZ=Asia/Shanghai flutter test --no-pub test/app/home_feed_flow_test.dart test/app/home_navigation_flow_test.dart test/app/home_r1_visual_test.dart test/app/home_feed_nav_capture_test.dart test/app/home_suggestion_entry_test.dart test/app/review_context_entry_test.dart test/app/review_form_entry_test.dart test/app/review_submission_flow_test.dart test/app/review_draft_storage_test.dart test/features/ledger/presentation/home_summary_donut_test.dart test/features/ledger/presentation/ledger_feed_controller_test.dart --reporter expanded
TZ=Asia/Shanghai R1_CAPTURE_DIR=docs/reports/assets/home-feed-fixes flutter test --no-pub test/app/home_feed_flow_test.dart test/app/home_navigation_flow_test.dart test/app/home_feed_nav_capture_test.dart test/features/ledger/presentation/ledger_feed_controller_test.dart --reporter expanded
```

此次会话日志保存在`/tmp/timepet-home-nav-repair-{regression.log,focused.log,analyze.log,full.jsonl,web-build.log,apk-build.log}`，失败集合和逐条比对结果为`/tmp/timepet-home-nav-repair-failures.txt`、`/tmp/timepet-home-nav-repair-comparison.json`。基线JSON来自前一轮独立验证，HEAD通过临时archive副本执行，没有重置工作区。

## 视觉证据与限制

已重新生成并逐张查看：[首页360](assets/home-feed-fixes/home-360.png)、[首页320](assets/home-feed-fixes/home-320.png)、[320大字](assets/home-feed-fixes/home-320-large-text.png)、[历史日期](assets/home-feed-fixes/home-previous-day-360.png)、[摘要](assets/home-feed-fixes/summary-360.png)、[复盘](assets/home-feed-fixes/review-360.png)、[复盘表单](assets/home-feed-fixes/review-form-360.png)。大字下短标题完整显示，时长换行保留数字与单位；普通宽度保留紧凑同行排版。

组件截图和构建不等于真机或浏览器交互验收。本轮未安装APK、未验证真实系统返回手势，也未部署Web。103项既存失败（旧页面布局、旧导航及旧时长文案等）不在本轮修复范围，工程全量基线仍未通过。Web的CupertinoIcons字体提示、Android的Java native access提示为非阻断警告，未为此引入依赖或修改环境。用户及其他agent的既有改动保留，未提交或创建PR。
