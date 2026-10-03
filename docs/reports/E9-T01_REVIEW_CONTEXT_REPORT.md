# E9-T01 — 接通按日复盘读取与上下文

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T01，完成后停止。

## 前置与规则依据

核对 AGENTS、Task 完整定义、SOT、OQ、MVP、PLAN、MODEL / DailyReview 与 TomorrowFirstStep、APP / review 依赖和 RULES / DR-001–DR-004。三项直接依赖 E2-T07、E8-T05、E7-T02 的归档定义、完成报告及相关实现已有证据；Q-001、Q-006、Q-008 均 DECIDED，与当前规则一致。

按 AGENTS 委派 code_mapper 做有界只读定位，主 agent 检查其代码证据后实施。现有 ReviewRepository 按 CivilDate 查找；TomorrowFirstStep 已提供下一自然日；DayLedgerLoader 及摘要组件可复用。没有补造产品决定。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/application/review_context_loader.dart` | 读取上下文合同，返回原 DailyReview、当前 DayLedgerView 及第一步原 Goal 元数据 |
| `lib/features/review/presentation/review_context_controller.dart` | 区分 idle / loading / absent / ready / failed，切日、重试、无效输入及释放后的旧响应隔离 |
| `lib/features/review/presentation/review_context_page.dart` | 历史日期、原复盘内容及日期展示、下一自然日和当前事实摘要；刷新、路由返回与前台恢复重读 |
| `lib/app/bootstrap/review_context.dart` | 外层事务协调 ReviewRepository、既有 DayLedgerLoader 与 GoalRepository.findById |
| `lib/app/bootstrap/app_bootstrap.dart`、`lib/app/main_app.dart` | 增量装配与主页直接“打开按日复盘”入口 |
| `test/features/review/application/review_context_loader_test.dart` | 真实 SQLite 读取、错误、两连接一致性、日期边界及 DST |
| `test/features/review/presentation/review_context_controller_test.dart` | 旧成功 / 失败、重试、无效输入 / 释放和模拟运行时时区变化 |
| `test/app/review_context_entry_test.dart` | 真实 bootstrap 页面读取与刷新、归档引用、事实变化不改文字、快速切日和失败反馈 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | 状态、原定义归档、完成依据 |

- 按 CivilDate 成功查到 null 才表示无复盘；复盘、摘要或目标读取失败均显示可重试错误，清除先前上下文，不伪装无复盘或泄露 SQL 错误。
- 已有复盘保留 id、date、createdAt、updatedAt、可空文字和下一步原文。展示已存日期及现有 TomorrowFirstStep.intendedDate；不使用系统今天或固定 24 小时计算意向日期。
- 当前选择固定为 CivilDate；刷新及前台恢复不因午夜或设备时区变化偷偷切日，“今天”由用户明确点击。事实窗口按当前设备时区重读，复盘日期独立保留。
- 摘要复用同一 DayLedgerView 和既有格式 / 睡眠 / 目标节奏组件。下一步 Goal 用原身份单独读取，包含只有复盘引用的 archived Goal，显示当前名字和归档标记；未将 archived Goal 作为新增关联候选。
- 复盘、事实投影及目标元数据在同一外层事务中取得，既有内层事务保持其合同。只有当前请求可发布整个上下文，不混用旧日期复盘和新日期摘要。
- 无复盘不生成 summary、reflection 或 TomorrowFirstStep；上下文缺口不设置复盘门槛。入口可直接打开，不要求先看统计。

## Validation

仓库根目录使用现有 Flutter / Dart 与依赖缓存，没有安装或更新工具 / 依赖。以下最终命令均退出 0：

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/app/main_app.dart lib/app/bootstrap/app_bootstrap.dart lib/app/bootstrap/review_context.dart lib/features/review/application lib/features/review/presentation test/features/review/application test/features/review/presentation test/app/review_context_entry_test.dart` | 格式化通过（后续仅对新增测试文件重排） |
| `dart format --output=none --set-exit-if-changed`（同上路径） | 9 文件，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/application test/features/review/presentation test/app/review_context_entry_test.dart` | 11 项通过，无跳过 |
| `TZ=America/New_York flutter test --no-pub test/features/review/application test/features/review/presentation test/app/review_context_entry_test.dart` | 11 项通过，无跳过；实际本机 23 / 25 小时自然日 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 593 项通过，3 项既有 DST 条件测试跳过 |
| `git diff --check`、开始前 SHA-256 对照、归档原定义与链接核对 | 通过 |

真实库覆盖成功 null、历史身份与完整文字、可空概述 / 反思、仅复盘引用的 Goal、原目标归档 / 改名、跨年 / 闰年 / 月末。事实新增 / 删除后摘要变化，原复盘原始八列保持不变。复盘 / 睡眠摘要 / Goal 查询注入错误后重试可恢复。两个真实文件库连接验证外层事务锁阻止中途提交，读取完整旧上下文；事务结束后提交修改，刷新完整取得新上下文。

Controller 和 widget 覆盖快速切日的旧成功与旧失败、错误重试、无效日期、释放期间响应，Controller 覆盖午夜和模拟运行时时区变化。两种进程时区验证真实设备日期适配与日期派生；不是在同一个运行进程中实际修改操作系统时区。

首轮定向测试中，同一执行器对象断言未通过，原因是既有 loader 的嵌套事务使用不同执行器包装。改以真实双连接隔离验证；进一步核实 Native SQLite 使用 BEGIN IMMEDIATE，第二连接在读取期间不能提交，测试据此验证锁及读取结束后的刷新。修正测试后，两种时区的最终定向及广回归通过，生产代码没有为测试改变事务合同。上海广回归的三项跳过来自既有 sleep_ledger_loader_test 的纽约 DST 场景和 day_ledger_resolution_flow_test 的两个 23 / 25 小时场景，不计为通过。

最终日志：`/tmp/e9-t01-target-final.log`、`/tmp/e9-t01-new-york.log`、`/tmp/e9-t01-analyze-final.log`、`/tmp/e9-t01-regression.log`。

## Self-review / Scope

执行前保存全部 346 个已有 tracked / untracked 文件的 SHA-256。代码验证后，仅两份原 app 文件发生本次增量变化；从当前文件移除本次入口与装配增量后，哈希与开始前完全一致。随后仅增量更新三份规划文档，E9-T01 原定义完整归档并添加 COMPLETE / 报告链接。检查全部新增文件及增量，无无关格式化或删除，保留全部已有修改和未跟踪文件。

生产代码限于 review/application、presentation 和 app；没有修改 domain、data、schema、生成代码、依赖或原摘要算法，没有接入复盘写入、草稿、编辑 / 删除或后续回看路由。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。Android 实际关闭重开、Web 浏览器刷新及实际操作系统时区切换未执行；本机真实 SQLite、widget 与进程 TZ 验证不外推为两平台生命周期验收，后者仍属 E9-T09。路由返回 / 前台恢复接线已实现，本轮以显式刷新验证当前事实重读，未把接线本身记为实际平台操作证据。

## Next executable task

**E9-T02 — 实现独立复盘本机草稿存储。** E2-T02、E2-T07、E1-T07 有完成依据，Q-012 / Q-015 已确定；仅报告，不执行。Epic 9 尚未整体验收，本次完成 E9-T01 后停止。
