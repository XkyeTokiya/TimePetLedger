# E5-T06 — 实现每日首次打开的主睡眠确认

## Task / Status

**E5-T06 / COMPLETE，2026-09-30。** 仅执行本 Task，未执行 E5-T07。

读取 AGENTS、Task 全文、共同必读 SOT / OQ / MVP / PLAN，以及 RULES SL-004、DERIVED 已记录识别、SOT §29、APP 调用流程 / UI state / 失败处理和 DATA 本机输入草稿边界。核对 [E5-T01](E5-T01_SLEEP_LEDGER_READ_REPORT.md)、[E5-T04](E5-T04_SLEEP_SUBMISSION_REPORT.md)、[E5-T05](E5-T05_SLEEP_CORRECTION_REPORT.md) 的完成报告及实际实现。Q-008 / Q-010 / Q-012 均为 DECIDED，无来源冲突或新的产品阻塞。

按 AGENTS 委派 code_mapper 有界只读定位 app 启动、睡眠判定、草稿路由和本机存储所有权；主 agent 检查证据，负责实现、集成、自审及最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [sleep_opening_store.dart](../../lib/features/ledger/domain/sleep_opening_store.dart) | 最小本机交互存取合同；原子登记某设备日期首次已检查，失败不能冒充已打开 |
| [drift_sleep_opening_store.dart](../../lib/features/ledger/data/drift_sleep_opening_store.dart) | 独立连接内存储已检查日期，以日期唯一键和单条 INSERT 原子竞争首次资格 |
| [sleep_first_open.dart](../../lib/features/ledger/application/sleep_first_open.dart) | 先读取当前正式事实并复用 E3 判定，再登记已检查日期；输出是否优先确认 |
| [sleep_openings.dart](../../lib/app/bootstrap/sleep_openings.dart) | 使用已批准的本机持久化能力打开独立交互存储 |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 注入协调器，懒打开并持有一条交互连接，失败可重试，dispose 或晚完成时关闭 |
| [main_app.dart](../../lib/app/main_app.dart) | 首帧及 resumed 检查、可跳过的确认、失败重试、当前设备日期传递、跨午夜和返回处理 |
| [sleep_first_open_test.dart](../../test/features/ledger/application/sleep_first_open_test.dart) | 12 项真实库 / 文件持久化的判定、交互标记、失败及草稿隔离测试 |
| [sleep_first_open_flow_test.dart](../../test/app/sleep_first_open_flow_test.dart) | 8 项真实文件库的 app / widget 启动、恢复、跨日、失败及连接释放测试 |
| [checked_sleep_opening.dart](../../test/app/support/checked_sleep_opening.dart) | 为既有流程测试提供隔离的“今日已经检查”存储，避免访问真实应用存储 |
| 既有 app 测试（见格式清单） | 显式注入上述存储，保留普通记录、睡眠保存 / 更正 / 草稿及 bootstrap 原有断言 |
| [recording_platform_test.dart](../../integration_test/recording_platform_test.dart) | 既有 E4 平台测试使用 runId 隔离的交互库，并允许首次确认后继续账本；本轮未执行平台运行 |
| TASKS、COMPLETED_TASKS、本报告 | 完成索引、原锚点与完整 Task 归档、可追溯证据 |

启动或回到首页时，用注入的 now 和 `deviceDateOfInstant` 取得当前设备日期，交给已有 SleepLedgerLoader。`recordedMainSleepToday` 仍来自 E3 `hasRecordedMainSleepToday`：当天醒来且 endedAt ≤ now 的 mainSleep 才满足；小睡、未来结束主睡眠及草稿均不能替代。历史查询不用于首次打开资格，更正 / 删除后的识别重新读取当前事实，不缓存“已记录”布尔值。

成功读取正式事实后，独立本机库 `time_pet_ledger_sleep_openings` 的 `sleep_openings` 表登记年月日。该标记只表示此日期已成功检查，不表示睡眠存在，也不进入正式五表或草稿表。即使首次打开已经有主睡眠，也登记该日期，随后删除睡眠不会引发反复提醒。同日重开或返回仍可读取当前事实，但不再次主动询问；新的自然日拥有独立资格。没有提醒计时器、通知、后台任务或时区覆盖设置。

未记录且首次检查时显示“确认主睡眠”，用户可直接继续账本，或通过当前日期的既有睡眠新建入口确认起止。不填默认时间 / 精度 / 类型，不改草稿。已有同上下文的不完整原始文本、类型（包括 nap）及独立精度由既有表单读取恢复；其他新建日期和编辑 id 草稿保持隔离，按其原入口恢复。离开与主动放弃、正式保存及失败行为均沿用 E5-T03–E5-T05。

事实读取或交互存储失败时，显示明确的检查失败及重试入口，允许继续普通记账，不输出“尚未记录”假结果，也不把失败登记为正常已检查。检查在途防重复；首页以外不弹确认。输入页跨日后返回，会检查新的设备日期；等待存储时跨午夜的旧日期结果不显示旧确认，改为检查当前日期。确认进入睡眠表单时同步查看日期，避免路由日期与显示结果不一致。

未改变正式 schema、原子创建 / 更正 / 删除、纯睡眠判定公式、草稿 schema 或领域决定；未新增依赖或强制睡眠成为普通记账前提。

## Validation

使用现有依赖与环境；最终实际命令及结果：

| 命令 | 结果 |
| --- | --- |
| `dart format`（下列 15 个 Dart 文件） | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同 15 文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/application/sleep_first_open_test.dart test/app/sleep_first_open_flow_test.dart` | 修正后退出 0，18 项通过（当时 app 有 6 项） |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/sleep_first_open_flow_test.dart` | 增补跨日边界后退出 0，8 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，451 项通过，1 项纽约 DST 定向用例按时区条件跳过 |
| `git diff --check` | 退出 0 |
| Task 原锚点、归档定义、数量及本次文档链接核对 | 通过 |

格式化 / 格式检查清单：

```sh
dart format --output=none --set-exit-if-changed lib/features/ledger/domain/sleep_opening_store.dart lib/features/ledger/data/drift_sleep_opening_store.dart lib/features/ledger/application/sleep_first_open.dart lib/app/bootstrap/sleep_openings.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart test/features/ledger/application/sleep_first_open_test.dart test/app/sleep_first_open_flow_test.dart test/app/support/checked_sleep_opening.dart test/app/bootstrap/app_bootstrap_test.dart test/app/basic_recording_flow_test.dart test/app/sleep_draft_entry_test.dart test/app/sleep_editing_flow_test.dart test/app/sleep_submission_flow_test.dart integration_test/recording_platform_test.dart
```

真实 SQLite 测试首次 / 同日再次 / 次日、已结束主睡眠（含零点）、小睡、未来主睡眠及恰好结束、修改类型 / 醒来日期及删除后的正式判断。时区测试注入两套日边界，同一绝对睡眠与 now 在不同时区重新归日，原始事实不变，返回已经检查的日期也不重复询问。历史日期拒绝登记。损坏正式行令读取失败，修正后仍可取得首次资格；标记失败也可重试。所有正式五表保持原职责，草稿未改写。

真实文件交互库验证并发请求只有一次首次结果、关闭重开同日不重复、次日可登记；故障触发器让登记失败且表仍为空，移除后仍为首次。错误路径、未支持版本和关闭后操作返回存储错误，不返回 false。真实草稿库保存的不完整新建 / 编辑输入不算事实，确认协调后字段仍原样保留。

app 测试使用真实文件正式库、文件草稿和文件标记：首次可继续普通账本，同日销毁并重建整个 widget / 连接后免打扰，下一日 resume 只提示一次；已有 mainSleep 首次跳过，删除后 resume 显示当前缺失而不再询问。确认进入表单恢复已有 nap / 未完成原始文本 / 混合精度，不创建事实。读取失败不打开标记库、重试恢复首次确认；标记打开失败不暴露原始诊断，仍可进入普通记账，恢复后只持有一个连接。输入页跨午夜及等待打开时跨午夜均使用新日期。app 销毁后才完成打开的连接仍关闭且不登记。

初次静态分析修正多行 if 大括号与 nullable 日期捕获。初版 widget 测试使用不完整生命周期转换和错误的恢复文案断言，修正为合法转换序列及既有文案；存储故障测试修正 File 参数。返回流程限制为跨日才追加检查，避免同日页面返回自动重复重试失败的检查。所有受影响路径随后定向与全量通过。最终日志为 `/tmp/e5_t06_analyze_final.log`、`/tmp/e5_t06_all_tests.log`；定向成功日志为 `/tmp/e5_t06_related_retry_2.log`、`/tmp/e5_t06_app_final.log`，均为本机临时日志。

全量日志中有 5 条既存 Drift 多 AppDatabase 实例调试警告，来自已有独立连接 / 存储测试；与 E5-T05 全量日志数量及来源一致。本轮新增定向测试无该警告，未关闭全局警告或将其改写为分析失败。

## Self-review

检查全部新增 / 修改文件（包括未跟踪文件），核对 E3 调用、显式日期 / now、标记与事实区分、读失败与正常缺失区分、草稿不覆盖、原子首次登记、重复检查锁、路由 / 生命周期、跨日旧结果、晚完成连接关闭及错误文案。application 不依赖 Flutter、SQL 或全局当前时间；data 不依赖页面，UI 不取得正式数据库连接。

对照本轮开始的文件内容及 SHA-256 快照：原有文件只改 app_bootstrap / main_app、5 份既有 app 测试、1 份受入口影响的平台测试及 Task / 归档；新增 4 份实现、3 份测试 / 支持文件和本报告。保留既有 E2–E5 工作区改动、未跟踪文件与文档；未修改 IMPLEMENTATION_PLAN、领域规范、OQ、pubspec / lockfile、生成代码、正式 schema 或平台配置。任务归档只追加 E5-T06 和更新计数，既有完整任务内容保留。

## Blockers / Open Questions

无新增 blocker。Q-008 / Q-010 / Q-012 状态不变。

本轮真实文件连接重开及 widget 重建不能替代 Android 实际关闭重开 / Web 实际刷新；E5-T08 保留两平台的首次标记、恢复与免打扰验收。本轮未执行或重跑平台测试，recording_platform_test 的适配仅由格式 / 静态分析核对，不写为平台通过。纽约 DST 用例本轮跳过，不写为通过；不标记 Epic 5 整体验收完成。

## Next executable task

**E5-T07 — 验证睡眠记录应用闭环。** E5-T05 / E5-T06 已有完成证据；执行时须重读完整 Task 与来源。本轮完成后停止，未开始 E5-T07。
