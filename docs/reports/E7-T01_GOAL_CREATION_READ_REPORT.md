# E7-T01 — 接通简单目标创建与读取

## Task / Status

**E7-T01 / COMPLETE（2026-10-01，Asia/Shanghai）。** 只交付本任务，未执行 E7-T02 或后续任务，未标记 Epic 7 或全 MVP 完成。

已阅读 AGENTS、Task 完整定义、Source of Truth、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN，以及 MODEL / Goal、RULES / MODEL-002、GO-001–GO-002、APP / goals 边界。核对 COMPLETED_TASKS 中 E2-T04、E4-T07、E6-T01 的完整定义、对应完成报告和实际 repository、app、真实库测试实现。按 AGENTS 委派 code_mapper 做有界只读定位，主 agent 检查报告所指代码证据并负责实施、自审和验证。

Q-006、Q-015、Q-018、Q-019 均为 DECIDED：新建仅 active；名称首尾 trim、必填、最多 200 个 Unicode 码点且保留内部格式；本地 UUID v4 与注入的 UTC 毫秒时间；同名合法且按 id 独立。来源与现有实现一致，无阻塞性问题。

## Changes

| 文件 | 交付 |
| --- | --- |
| [goals_page.dart](../../lib/features/goals/presentation/goals_page.dart) | 直接依赖 GoalRepository 的局部 UI state；active 列表、创建、加载 / 空 / 失败、刷新 / 重试；复用 repository 内 Goal 领域校验 |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart)、[main_app.dart](../../lib/app/main_app.dart) | 从主页独立打开目标页，使用 app 已持有数据库的 DriftGoalRepository；复用既有本地 UUID v4 生成函数，注入 app 当前时间 |
| [goals_page_test.dart](../../test/features/goals/presentation/goals_page_test.dart) | 七项 widget + 真实 SQLite / DriftGoalRepository 测试，包含领域边界与真实写失败回滚 |
| [goal_entry_test.dart](../../test/app/goal_entry_test.dart) | 一项真实 AppBootstrap 组装交互测试：创建、返回 / 重开读回、身份与时间戳、其他正式表不受影响 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、稳定锚点索引、完整任务归档及当前进度同步 |

验收对应：

- 初始无 active Goal 明确显示空列表；已有 archived Goal 不出现。普通记录 / 睡眠入口独立，回归测试仍覆盖无 Goal 正式保存。
- 创建通过已有 GoalRepository.create，只创建 active；界面不复制 trim、长度或唯一性算法，不使用 TextField 字素长度截断来代替码点校验。
- 同名两次创建后分别显示两行，每行使用 Goal.id 作为 key；真实库检查独立 id、active、archivedAt 为 null 与注入的 createdAt / updatedAt。
- 名称全空白、201 emoji 被领域拒绝，原始输入保留；首尾空白包围的 200 emoji 合法，内部空格 / 换行保存不丢失。
- 保存中禁止修改输入、重复提交及并行手动刷新。捕获旧按钮回调后重复调用仍只产生一次 INSERT，提交后重新 SELECT。
- 真实 SQLite TEMP TRIGGER 在 INSERT 后产生失败，repository 事务回滚；不显示保存成功，原始输入保留；解除测试故障后重试只保存一个 Goal。
- 加载与读取失败不显示空列表，不暴露 SQL 诊断；读取重试保留正在输入的名称。成功 create 后清空本次输入并重读；提交后读取失败同时明确“目标已保存”和“目标列表读取失败”，重试读取不再 INSERT。
- 页面销毁后的异步读取不会更新已销毁的 state。目标页返回 / 重开从同一 app 数据库读回，不建立新正式数据库。

未新增归属表单、统计、项目管理字段、生命周期 UI、通用 use-case 层、依赖或 schema。目标输入只在本次页面交互中保留；Q-012 对普通记录 / 睡眠 / 复盘的本机草稿合同未扩展到 Goal。

## Validation

全部在仓库根目录执行，沿用已有 Flutter / Dart 与缓存依赖。

本轮 Dart 清单：`lib/features/goals/presentation/goals_page.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart test/features/goals/presentation/goals_page_test.dart test/app/goal_entry_test.dart`。

| 实际命令 | 结果 |
| --- | --- |
| `dart format` 上述五文件 | 退出 0，最终 0 changed |
| `dart format --output=none --set-exit-if-changed` 上述五文件 | 退出 0，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/goals/presentation/goals_page_test.dart test/app/goal_entry_test.dart` | 修正测试导入后退出 0，8 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/goals test/app` | 最终退出 0，85 项通过、2 项 skip；包含刷新互斥的最终断言 |
| `git diff --check`、文件 SHA-256 基线对照、归档 / 报告链接和任务定义核验 | 通过，见 Self-review |

首轮分析与定向测试因 Drift / matcher 的 isNull 导入重名失败，已用 hide isNull 修正并重跑。两项 skip 是既有 day_ledger_resolution_flow_test 中要求真实 23 / 25 小时自然日的场景，上海时区不满足跳过条件；本任务没有新增或改变日期计算，未将跳过项记为通过。目标相关新增八项没有跳过。

测试成功读写实际执行真实 SQLite；初始 / 提交后读取失败和 in-flight 状态通过测试专用 QueryInterceptor 在 SQL 执行边界注入，未使用 fake repository 或伪造提交成功结果。TEMP TRIGGER 仅位于测试专用内存库，不改变生产 schema。

日志：`/tmp/e7-t01-tests.log`、`/tmp/e7-t01-analyze-final.log`、`/tmp/e7-t01-regression.log`。

## Self-review

检查新建生产 / 测试文件、app 接线、异步状态、失败输入保留、已提交后的单独读取重试、id 身份和领域校验复用。特别限制保存中刷新，避免提交前读取覆盖提交后的列表。

开始前记录既有文件 SHA-256。代码阶段仅 main_app / app_bootstrap 两个既有文件变化；在内存中移除本轮新增接线文本，两个文件都精确重现执行前的 SHA-256，证明前序改动未被格式化或覆盖。全部其他既有生产 / 测试 / 集成文件及领域 / 架构文档、pubspec / lockfile、正式 schema / 生成代码保持原样。收尾只增量更新 TASKS / COMPLETED_TASKS / PLAN 和本报告，保留工作区原有改动及未跟踪文件；归档全文保留原依赖、范围、验收和 Validation，仅新增完成状态与报告链接。

## Blockers / Open Questions

无 blocker，无新增 Open Question。当前证据是本机 Flutter widget、真实 Native SQLite 和 app 交互回归；未运行 Android 设备或 Web 浏览器的目标创建 / 重启验证，该阶段属于 E7-T07。未将本机页面重开称为 Android 关闭或 Web 刷新。

## Next executable task

**E7-T02 — 接通目标改名归档恢复与删除。** E7-T01 已完成，E2-T07 有完成报告；相关决定已确定。本次只报告，不执行；E7-T01 完成后停止。
