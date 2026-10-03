# E5-T03 — 实现独立睡眠表单与草稿生命周期

**Task / Status：E5-T03 / COMPLETE。** 日期：2026-09-29。

## 依据与前置

用户授权顺序执行 E5-T02，确认无误后继续 E5-T03。本轮先完成 [E5-T02](E5-T02_SLEEP_DRAFT_STORE_REPORT.md)，格式 / 分析 / 12 项草稿测试通过并更新状态，再开始本任务。[E5-T01](E5-T01_SLEEP_LEDGER_READ_REPORT.md) 已完成且本轮相关回归再次通过。

已核对 AGENTS、Task 全文及共同来源、SOT §4 / §29、RULES / SL-001–SL-005、MODEL / SleepSession / UI Models，以及 Q-012 / Q-016 / Q-017。睡眠是独立跨日事实，类型不按时长推断，正区间允许历史 / 未来且无时长阈值；草稿与事实分离。未发现阻塞产品问题。沿用本轮 code_mapper 有界只读定位，主 agent 核查证据、实现并验证。

## Changes

| 文件 | 修改 |
| --- | --- |
| [sleep_form_controller.dart](../../lib/features/ledger/presentation/sleep_form_controller.dart) | 独立睡眠输入状态、优先恢复、串行自动保存、等待写入 / 放弃、错误和重试 |
| [sleep_form.dart](../../lib/features/ledger/presentation/sleep_form.dart) | mainSleep / nap、分钟日期时间、独立精度、恢复和保留 / 放弃操作 |
| [sleep_time_input.dart](../../lib/features/ledger/presentation/sleep_time_input.dart) | 当前设备当地时间的分钟输入解析 / 显示；拒绝无效日历进位和不存在的当地时间 |
| [sleep_entry.dart](../../lib/app/bootstrap/sleep_entry.dart) | app 所有的睡眠路由组装；打开专用草稿连接、失败重试、迟到连接释放、排空写入后关闭 |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 注入睡眠草稿 opener 和独立路由 builder |
| [main_app.dart](../../lib/app/main_app.dart) | 日期上下文下增加“记录睡眠”最小入口，无需 Goal |
| [sleep_form_controller_test.dart](../../test/features/ledger/presentation/sleep_form_controller_test.dart) | 7 项输入 / 恢复 / 并发 / 错误测试 |
| [sleep_form_test.dart](../../test/features/ledger/presentation/sleep_form_test.dart) | 4 项 widget 场景 |
| [sleep_draft_entry_test.dart](../../test/app/sleep_draft_entry_test.dart) | 3 项 app / 真实存储 / 原事实不变与释放测试 |
| TASKS 与本报告 | 状态及交付证据 |

新建时不猜测睡眠时间、类型或精度；用户分别确认类型和两端精度，未选择状态仅属于输入模型，不改变正式 SleepSession 必填合同。修改时间或切换类型不改精度。允许跨日、很久以前、未来和任意正时长；零 / 反向 / 缺失端点显示输入提示，但仍自动保留草稿。未完成或格式无效的文本也能恢复。

初始化先读草稿，读失败阻止输入写入，不用空值覆盖原草稿；成功初始化后不重复恢复覆盖当前输入。编辑上下文可注入完整原事实用于初始展示；存在草稿时，即使某端点未填也优先恢复该草稿，不以原事实补满用户清空的字段。本 Task 的正式可达入口只提供新建草稿；已有睡眠的更正路由和提交留 E5-T05。

每次用户修改立即排队保存完整输入快照，按修改顺序执行；放弃先等待写入完成再清除，禁止旧写入在清除后复活。普通返回只 flush，不清草稿；写失败阻止返回且保留输入供重试。清除失败保留页面与草稿。连接由 app 路由拥有，presentation 只接收 controller；页面释放时排空已有写入再关闭，异步打开完成前页面已释放则直接关闭迟到连接。

本任务没有正式保存按钮或伪装保存成功。页面明确说明输入尚未计入账本；正式新建、冲突反馈、提交后清草稿与摘要刷新属于 E5-T04。没有 Goal / annotation / 睡眠质量 / timer / note 入口，也没有复用普通记录 Q-023 推断。

## Validation

使用现有 Flutter / Dart 和依赖，未安装新包。实际验证：

| 命令 | 结果 |
| --- | --- |
| 对本任务上表 9 个 Dart 文件运行 `dart format` | 退出 0 |
| 对 E5-T02 + E5-T03 全部 13 个 Dart 文件运行 `dart format --output=none --set-exit-if-changed` | 退出 0，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `flutter test --no-pub test/features/ledger/presentation/sleep_form_controller_test.dart test/features/ledger/presentation/sleep_form_test.dart` | 退出 0，11 项通过 |
| `flutter test --no-pub test/app/sleep_draft_entry_test.dart` | 最终退出 0，3 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time` | 退出 0，312 项通过，1 项纽约 DST 定向测试因时区条件跳过 |
| `git diff --check` | 退出 0 |

格式检查完整文件清单：

```sh
dart format --output=none --set-exit-if-changed lib/features/ledger/domain/sleep_draft_store.dart lib/features/ledger/data/drift_sleep_draft_store.dart lib/app/bootstrap/sleep_drafts.dart lib/features/ledger/presentation/sleep_time_input.dart lib/features/ledger/presentation/sleep_form_controller.dart lib/features/ledger/presentation/sleep_form.dart lib/app/bootstrap/sleep_entry.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart test/features/ledger/data/sleep_draft_store_test.dart test/features/ledger/presentation/sleep_form_controller_test.dart test/features/ledger/presentation/sleep_form_test.dart test/app/sleep_draft_entry_test.dart
```

覆盖跨日和分钟输入、mainSleep / nap 切换、混合精度、改时间不改精度、零 / 反向 / 缺少端点、历史至未来正区间、未选类型 / 精度、部分文本恢复、重复初始化不覆盖已填输入、串行自动保存与放弃竞态、read/save/clear 失败、重试和错误文案不暴露底层诊断。真实文件库经页面返回关闭后重新打开，恢复输入再主动放弃；正式五表仍为空。编辑 widget 注入真实库完整 SleepSession，输入后原行逐字段保持不变，只有独立编辑草稿改变。连接打开失败可重试，widget 已释放时迟到连接确认被关闭。

首次分析发现两处多行 if 缺大括号，修正后通过。真实库 widget 测试的首版将文件 I/O 和 fake async 混用，曾挂起 / 未完成返回断言；已调整为 runAsync 中打开真实文件连接、在 widget 调度中注入已打开连接，最终三个场景通过。该测试仍真实关闭 / 重开 SQLite 文件，不以 fake store 替代持久化验证。

纽约 DST 用例未在本轮上海命令中执行；其 E5-T01 验证证据仍见对应报告。本轮未执行 Android 关闭应用 / Web 刷新场景，不将 widget / 文件库重开称为平台端到端验收；按 Task 留 E5-T08。

## Self-review

核对新增文件及 app 增量修改、控制器与连接所有权、异步恢复 / 释放、串行保存、输入字段与本机存储合同；检查无正式写入路径、依赖变化、普通编辑器耦合或范围外提交操作。

以本轮开始 SHA-256 对照，已有文件只变化 MainApp、AppBootstrap 与 TASKS；其它已存在 lib / test / docs / integration_test / pubspec / lockfile 均未改变。既有 Epic 2–4 和 E5-T01 工作区改动及未跟踪文件全部保留，IMPLEMENTATION_PLAN 原改动未触碰。新建文件均纳入检查。

## Blockers / Open Questions

无。E5-T02、E5-T03 适用验证全部通过，未扩大到正式睡眠保存或平台恢复验收。

## Next executable task

E5-T04 — 接通睡眠新建、冲突反馈与刷新。其 E5-T03 已完成，E2-T06 具备[原子写入完成报告](E2-T06_ATOMIC_LEDGER_WRITE.md)及既有实现。本轮授权到 E5-T03 为止，现停止，不执行 E5-T04，不将 Epic 5 标为整体完成。
