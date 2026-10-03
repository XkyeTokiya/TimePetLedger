# E5-T09 — 提供睡眠可选备注入口

## Task / Status

**COMPLETE（2026-09-30）。** 仅执行 E5-T09。已核对 E5-T05 的完整事实更正、遗漏 note 的事务内保留及完成报告；E5-T08 的真实平台恢复测试与报告也已核对。Q-012、Q-015 均为 DECIDED，相关来源一致，无新增 blocker。

共同必读 AGENTS、Source of Truth、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN，以及 DOMAIN_MODEL / SleepSession、DOMAIN_RULES / MODEL-002 已读取。依据现有可选 note 合同：首尾 trim、空白归一为 null、保留内部换行，trim 后最多 2,000 Unicode 码点。按 AGENTS 委派有界只读代码勘查，主 agent 核对实际证据后实施和验证。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `lib/features/ledger/presentation/sleep_form.dart`、`sleep_form_controller.dart` | 增加可选多行备注，支持恢复、修改、清空和提交前长度提示；原始输入自动存入草稿，超长输入也保留，避免截断 |
| `lib/features/ledger/domain/sleep_draft_store.dart`、`data/drift_sleep_draft_store.dart` | 独立睡眠草稿库 v1 → v2，增加原始 note 和 noteProvided；两条升级 SQL 在同一事务执行，旧新建 / 编辑草稿可读且不丢失原有字段 |
| `lib/features/ledger/application/sleep_entry_saver.dart`、`sleep_entry_editor.dart` | 复用正式 create / update 的 note 参数及校验；残留草稿恢复匹配包含规范化后的备注，备注不同的草稿不会被误认成已提交 |
| `test/app/sleep_note_flow_test.dart`、`test/features/ledger/data/sleep_note_migration_test.dart` | 新增真实文件库应用闭环、v1 迁移与升级失败回滚验证 |
| `test/features/ledger/data/sleep_draft_store_test.dart`、`application/sleep_entry_saver_test.dart` | 增加原始备注写入失败保留、非法兼容标记、绕过 UI 的超长正式写入拒绝，以及提交后清理失败的匹配与防重复创建验证 |
| `test/features/ledger/presentation/sleep_form_test.dart`、`sleep_submission_test.dart`、`test/app/sleep_editing_flow_test.dart`、`sleep_recording_flow_test.dart` | 更新新增字段后的滚动定位、编辑时备注展示预期及 v2 草稿探针；保留原有回滚、冲突、重复点击及提交后失败断言 |
| `integration_test/sleep_platform_test.dart` | 在既有八阶段协议中补充备注的实际跨启动 / 刷新恢复、失败保留、正式读回、修改、清空与放弃；短 Web 视口下从摘要顶部查找编辑目标 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、本报告 | 更新完成索引并归档完整任务定义 |

noteProvided 只在用户实际编辑备注后变为 true。旧草稿及未触碰备注的更正继续遗漏 note 参数，由正式事务保留当前备注；显式清空则传入空值并正式保存为 null。这避免旧草稿清空已有备注，也避免只更正时间时覆盖同时发生的备注变化。

正式 SleepSession 字段、数据库表、repository API 和文本规范直接复用；没有新增领域字段、依赖、质量输入、TimeBlock、recovery 或时间轴。已有工作区未提交和未跟踪改动保留。

## Validation

仓库根目录 `/kiyodata/Projects/21-TimePetLedger`：

| 命令 / 场景 | 实际结果 |
| --- | --- |
| `dart format`（本次 15 个 Dart 文件）及 `dart format --output=none --set-exit-if-changed`（相同文件） | 退出 0；最终 0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub` | 最终退出 0，460 项通过、3 项按时区条件跳过 |
| `TZ=America/New_York flutter test --no-pub test/app/time/device_recording_date_test.dart test/features/ledger/application/sleep_ledger_loader_test.dart` | 退出 0，12 项通过，补跑上述 3 项时区条件测试，无 skip |
| `flutter test --no-pub test/features/ledger/data/sleep_note_migration_test.dart` | 退出 0，2 项通过；真实 v1 文件保留两类上下文及原始输入；第二条 ALTER 以真实 SQLite 重复列错误失败后，第一条 ALTER 回滚、版本仍为 1，移除故障后同文件重试成功 |
| `git diff --check` 及本轮起始文件快照核对 | 退出 0；无范围外源文件变化、删除、依赖变化或正式 schema 修改；仅本任务文件及验证生成的 ignored Gradle 缓存发生变化 |

真实文件库 widget 测试覆盖：两类睡眠留空 / 空白保存，多行首尾规范化，内部空格 / 换行保留；仅修改 note 后离开并恢复不会被误判已提交；AFTER UPDATE 的 ABORT 触发器拒绝正式更正并保留草稿，随后恢复重试成功；显式空白清空；2,001 个 emoji 保留草稿并拒绝提交，trim 后 2,000 个 emoji 可正式写入和读回。application 测试另行绕过 UI 核对正式层拒绝超长备注且五张事实表不变。

### E5-T08 后的受影响平台补充

沿用既有隔离数据库、实际 AppBootstrap 和八阶段协议。脚本及输出中的 E5-T08 标识表示复用协议，本次 run ID 和新增断言属于 E5-T09。每个阶段通过后才持久化阶段标记；没有卸载或清除数据来代替恢复验证。

| 平台 | 环境、命令及操作 | 结果 |
| --- | --- | --- |
| Android | `Medium_Phone`，Android 13 / API 33，`emulator-5554`；`python3 tool/e5_t08_relaunch_android.py --run-id e5t09_android_20260930_final3 --device emulator-5554`；首次启动后七次 `am force-stop` 与 Activity 重开 | 八阶段全部通过，脚本退出 0 |
| Web | Chromium / ChromeDriver `153.0.8010.52`，独立临时 profile，同一 `http://127.0.0.1:7369/` 标签页；服务命令 `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7369 -t integration_test/sleep_platform_test.dart --dart-define=E5_T08_RUN_ID=e5t09_web_20260930_final3`；`python3 tool/e5_t08_refresh_web.py --url http://127.0.0.1:7369/ --run-id e5t09_web_20260930_final3 --driver-port 9529`，七次真实刷新 | 八阶段全部通过，脚本退出 0 |

平台断言覆盖原始多行备注跨重开恢复和正式规范化；编辑备注与未完成时间一起恢复；保存前新事实导致两类冲突，原事实备注不变、失败草稿含备注；真实正式更正回滚与后续成功；正式提交后真实草稿清理失败只继续清理，不增加记录；主动放弃同时清备注；主睡眠和小睡备注跨启动读回；小睡显式清空后正式 null 在后续启动保持；省略备注的新建仍成功。原有精度、跨日、覆盖、每日首次免打扰、删除和无其他事实断言均保留。

初次回归及 Web 补测暴露了新增字段后的列表缓存 / 滚动定位问题，以及旧测试的“备注不可见”预期。已修正测试定位和预期，最终全量与两平台均通过。真实库多连接测试仍打印 Drift 的多实例调试警告；连接各自独立，不共享 executor，未屏蔽警告。最终日志见 `/tmp/e5_t09_full_test_verified.log`、`/tmp/e5_t09_analyze_verified.log`、`/tmp/e5_t09_timezone_test.log`、`/tmp/e5_t09_android_final3.log`、`/tmp/e5_t09_web_final3.log`。

## Self-review / Blockers / Open Questions

已以任务开始前的哈希和内容快照检查本轮修改，包括新建未跟踪文件、升级事务、文本规则、草稿兼容标记、提交恢复比较和完成归档。没有覆盖已有修改、扩大功能范围或修改来源决定。Q-012 / Q-015 无冲突，无新增 blocker / Open Question。平台证据限上述 Android 模拟器和 Chromium 环境，不代表其他设备或发布验收。

## Next executable task

**E6-T01 — 接通日账本页面的日期选择与读取状态。** 所列前置 E4-T01、E5-T01、E3-T06 已完成，Q-008 / Q-009 已决定。本次到 E5-T09 停止，未执行 E6-T01。
