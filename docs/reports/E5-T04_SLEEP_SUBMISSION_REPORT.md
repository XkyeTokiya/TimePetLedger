# E5-T04 — 接通睡眠新建、冲突反馈与刷新

## Task / Status

**E5-T04 / COMPLETE，2026-09-30。** 仅执行本 Task，未执行 E5-T05。

读取 AGENTS、Task 全文、共同必读 SOT / OQ / MVP / PLAN，以及 DATA 原子写入和草稿合同、RULES SL / LEDGER-004、APP 失败处理、MODEL 睡眠与 UI Models、DERIVED sleepSummary。核对 [E5-T03 报告](E5-T03_SLEEP_FORM_REPORT.md)、[E2-T06 报告](E2-T06_ATOMIC_LEDGER_WRITE.md) 和实际实现：睡眠草稿与输入已有，`createSleepSession` 在写事务内读取两类事实、检查冲突、插入并在成功提交后返回。Q-011、Q-012、Q-018 均为 DECIDED，与职责来源一致，无新 blocker。

按 AGENTS 委派 code_mapper 做有界只读定位，范围为睡眠输入 / 读取、普通提交模式、app 组装及相关测试；主 agent 检查证据，负责所有实现、集成和验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [sleep_entry_saver.dart](../../lib/features/ledger/application/sleep_entry_saver.dart) | 新建睡眠的正式提交、明确失败 / 已提交结果、清理与摘要 / 日投影刷新、残留草稿恢复检测 |
| [sleep_form_controller.dart](../../lib/features/ledger/presentation/sleep_form_controller.dart) | 提交前排空草稿写入、输入和重复请求锁定、冲突 / 失败反馈、仅清理读取的重试 |
| [sleep_form.dart](../../lib/features/ledger/presentation/sleep_form.dart) | 确认保存、两类冲突身份和完整区间、已提交后的明确提示与继续处理 / 返回 |
| [sleep_summary_view.dart](../../lib/features/ledger/presentation/sleep_summary_view.dart) | 主睡眠 / 小睡分列，原始起止、独立精度、完整时长、合计及缺失信息 |
| [sleep_submission.dart](../../lib/app/bootstrap/sleep_submission.dart) | 注入正式 repository、独立草稿、睡眠 loader、现有本地 UUID v4 生成器和时钟 |
| [sleep_entry.dart](../../lib/app/bootstrap/sleep_entry.dart) | app 拥有的路由注入提交协调器，沿用排空草稿和关闭连接的生命周期 |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 组装睡眠 loader / saver 并注入首页与路由 |
| [main_app.dart](../../lib/app/main_app.dart) | 消费睡眠路由刷新结果，显示睡眠摘要和覆盖；查看日期时用一致的睡眠上下文快照加载摘要 / 日投影 |
| [sleep_entry_saver_test.dart](../../test/features/ledger/application/sleep_entry_saver_test.dart) | 7 项真实 SQLite / 真实草稿存储的新建、冲突、相接、回滚与提交后失败测试 |
| [sleep_submission_test.dart](../../test/features/ledger/presentation/sleep_submission_test.dart) | 8 项 controller / widget 的重复点击、排队写入、输入保留、恢复检测、冲突列表和清理 / 刷新失败测试 |
| [sleep_submission_flow_test.dart](../../test/app/sleep_submission_flow_test.dart) | 2 项真实库 app 组装 / 文件草稿与摘要 widget 验证 |
| TASKS、本报告 | 完成状态及可追溯证据 |

正式新建只调用 `createSleepSession`，没有 UI 冲突预检写入旁路。跨日保留一条完整 SleepSession；与 TimeBlock 或 SleepSession 重叠均原子拒绝，列出类型、身份和完整区间供用户手动修改。Approximate 不豁免冲突；相接合法。不自动截断、拆分、覆盖、移动已有事实，也不生成 TimeBlock 或 RhythmAnnotation。

提交先等待已排队的草稿写入，草稿保存失败不进入正式写入。正式写入失败保留输入和草稿；在途提交禁止修改、重复保存、放弃和返回。正式写入成功之后才清草稿、调用 SleepLedgerLoader，重读一致快照并重算睡眠摘要、segments 和覆盖。清理 / 读取错误保持“已提交”结果，表单锁定新建，只允许继续清理和刷新；不提示再次保存。返回首页前完整成功的结果直接用于展示。

残留的新建草稿恢复时读取当前事实，只有原始起止、两端精度、类型和本任务的空 note 均一致才识别为已有正式事实并继续清理 / 刷新；不再次生成身份或创建。不同类型、精度或已有 note 不冒充同一次输入。此检测只是恢复识别，每次新建仍由正式事务执行当前完整校验。恢复检测读取失败阻止输入写入，允许重试，不用空事实兜底。

摘要按醒来日期区分主睡眠 / 小睡，列出每段完整原始区间和时长并合计，使用 E3 `formatSummaryDuration` / `formatDerivedDuration` 表达缺失、近似及正时长不足一分钟。跨日 23:50–07:40 的完整摘要为约 470 分钟，醒来日覆盖为 460 分钟：被裁掉的近似入睡边界不污染醒来日覆盖；前一日覆盖约 10 分钟。没有记录时显示“尚未记录主睡眠 / 小睡”，不推断用户没睡。没有完整时间轴、提醒、更正 / 删除或 note 输入入口。

## Validation

使用已有 Flutter / Dart 和依赖，无安装或依赖变更。最终实际命令与结果：

| 命令 | 结果 |
| --- | --- |
| `dart format`（本次 11 个 Dart 文件，清单见下） | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同 11 个文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/ledger/application/sleep_entry_saver_test.dart test/features/ledger/presentation/sleep_form_controller_test.dart test/features/ledger/presentation/sleep_form_test.dart test/app/sleep_draft_entry_test.dart` | 退出 0，21 项通过 |
| `flutter test --no-pub test/features/ledger/presentation/sleep_submission_test.dart` | 退出 0，8 项通过 |
| `flutter test --no-pub test/app/sleep_submission_flow_test.dart` | 最终退出 0，2 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，412 项通过，1 项纽约 DST 定向测试按时区条件跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app`（最终 app 状态复核后） | 退出 0，18 项通过 |
| `git diff --check` | 退出 0 |

格式化 / 格式检查文件清单：

```sh
dart format --output=none --set-exit-if-changed lib/features/ledger/application/sleep_entry_saver.dart lib/features/ledger/presentation/sleep_form_controller.dart lib/features/ledger/presentation/sleep_form.dart lib/features/ledger/presentation/sleep_summary_view.dart lib/app/bootstrap/sleep_submission.dart lib/app/bootstrap/sleep_entry.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart test/features/ledger/application/sleep_entry_saver_test.dart test/features/ledger/presentation/sleep_submission_test.dart test/app/sleep_submission_flow_test.dart
```

真实 SQLite 检查两种类型新建、跨日单行、相接 TimeBlock / SleepSession 均合法、起止精度和元数据、成功清除真实草稿、两日覆盖及摘要、小睡单列。先写草稿 / 读取空事实，再插入正式 TimeBlock 和 SleepSession，提交时返回两个当前冲突且五张正式表逐行不变；失败草稿可手动修正后提交。测试库 `AFTER INSERT` 故障触发器令正式 INSERT 抛错，检查尝试行回滚、五表原状与草稿保留，移除测试触发器后可保存。没有修改正式 schema。

controller / widget 检查等待草稿队列后才正式提交、重复点击 / 返回 / 放弃 / 改类型被阻止、正式失败保留可编辑输入、无效输入或草稿失败不调用 create、两类冲突列表、清理失败 / 刷新失败 / 同时失败的已提交反馈和仅继续处理、恢复检测读失败重试，以及残留草稿识别后不重复 create。app 组装测试真实 SQLite、真实文件草稿输入后保存主睡眠和小睡，确认首页摘要 / 覆盖更新，草稿文件关闭重开后为空，其他四张正式表为空；切换前一日按切片贡献显示，摘要不错误归到入睡日。额外摘要 widget 检查多段主睡眠、午夜醒来和微小时长存在性。

初次分析发现一处多行 if 缺大括号，修正后通过。初版 app 测试滚动定位命中了多个 Scrollable，指定账本列表后定向和全量测试均通过。失败记录与最终结果分别保留在 `/tmp/e5_t04_analyze.log`、`/tmp/e5_t04_app_tests.log`、`/tmp/e5_t04_app_tests_retry.log`；最终验证日志见 `/tmp/e5_t04_analyze_final.log`、`/tmp/e5_t04_all_tests.log`、`/tmp/e5_t04_app_final.log`，仅为本机临时日志。

## Self-review

检查全部本次文件（包含新增 / 未跟踪文件）的事务边界、提交与失败状态、草稿排空 / 清除顺序、恢复匹配、连接所有权、摘要完整时长与日切片区别、近似 / 缺失文案及 app 调用路径。最后核对首页状态：普通块删除成功保留未改变的睡眠摘要，删除后读取失败清除旧快照，避免覆盖回退到陈旧结果；该小幅状态调整后再次检查 11 文件格式、静态分析和全部 18 项 app 测试。纯 application 不依赖 Flutter、SQL 或全局当前时间；presentation 不获得正式数据库连接。

本轮开始保存 lib / test / integration_test / docs / tool 和 Task / 配置文件 SHA-256 清单，最终对照：已有文件只改变 sleep_form_controller、sleep_form、sleep_entry、app_bootstrap、main_app 和 TASKS；新增本表三个实现文件、三个测试文件与报告。保留既有 E2–E5 工作区改动和全部既存未跟踪文件；未改 DATA / RULES / MODEL / OQ、IMPLEMENTATION_PLAN、repository / mapping、正式 schema、生成代码、pubspec / lockfile 或平台配置。Task 顶部状态与 E5-T04 状态一致，后续任务仍未执行。

## Blockers / Open Questions

无。任务所需本机真实库与 controller / widget 验证通过。

本轮没有执行 Android 关闭重开或 Web 刷新恢复验收，也未重跑 E2-T06 平台事务矩阵；现有原子 API 的前置平台证据见 E2-T06 报告。E5-T04 的真实库证据来自本机 SQLite，文件草稿重开不等同平台端到端验证。睡眠平台恢复任务仍留 E5-T08；本轮不将 Epic 5 标为整体完成。纽约 DST 定向用例本轮因上海时区跳过，不写为通过。

## Next executable task

**E5-T05 — 接通睡眠更正与删除。** E5-T04 已完成；E1-T12 具备 [Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)与实现，E2-T06 具备前置实现及报告，Q-013 / Q-018 均为 DECIDED。完成本任务后停止，未开始 E5-T05。
