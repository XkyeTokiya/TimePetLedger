# E3-T01 — 对账窗口与派生时长基础合同

**Status：COMPLETE。** 执行日期：2026-09-28；同日补充用户本机测试证据。

实现和测试已交付；格式检查、静态分析、补充纯 Dart 合同检查通过。agent 沙箱内 Flutter 测试未能运行；用户随后提供相同相关测试命令的本机输出，31 项全部通过，补齐验收。下文保留原始失败记录，不将用户执行结果记作 agent 执行。

## 依据与前置

已阅读源提案、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN、DERIVED_MODELS、DOMAIN_RULES / LEDGER、APP_ARCHITECTURE 及完整 Task。Q-008、Q-009、Q-014、Q-017、Q-021 均为 DECIDED，没有发现本任务的来源冲突或缺失决定。

E1-T02 前置依据 [Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)，并检查实际 CivilDate、InstantMilliseconds、intervalMilliseconds、containsInstant、roundedDisplayMinutes、时间戳和身份输入实现及测试。没有补造历史测试结果。依 AGENTS 委派 code_mapper 有界只读勘查，主 agent 检查证据后实施。

## Changes

| 文件 | 交付 |
| --- | --- |
| [reconciliation_window.dart](../../lib/features/ledger/domain/projection/reconciliation_window.dart) | 显式 CivilDate、日期关系、当地日边界和 now；历史日完整，今天截至 now，未来日和今天零点为空；按边界毫秒差计算 |
| [derived_duration.dart](../../lib/features/ledger/domain/projection/derived_duration.dart) | DerivedDuration 独立携带实际毫秒和近似；SummaryDuration 另保留 hasRecords；正时长贡献按毫秒求和并 OR 近似；最终分钟舍入复用 core/time |
| [reconciliation_window_test.dart](../../test/features/ledger/domain/projection/reconciliation_window_test.dart) | 5 项测试：历史、今天、未来、零点、23/25 小时边界、毫秒精度及非法调用输入 |
| [derived_duration_test.dart](../../test/features/ledger/domain/projection/derived_duration_test.dart) | 7 项测试：空集、零参与、逐项近似、汇总后舍入、正时长舍入为零、单次遍历及负值拒绝 |
| 本报告 | 实际验证、环境限制和后续门槛 |

窗口用半开区间，空窗口表示为 `[dayStartedAt, dayStartedAt)`；调用方负责当地日期与边界对应关系。日边界必须严格递增；today 的 now 必须在该日半开区间内，不一致输入抛 ArgumentError，不静默夹取。这是调用输入检查，不是新增事实保存限制。

摘要从实际正时长参与项判断存在性，不从展示分钟推导。零时长不引入近似；每项汇总独立判断。完整睡眠与切片的选择留给后续任务，当前仅提供时长合同。没有增加 UI 文案、切片、Gap、数据库、依赖或全局时钟读取。

## Validation

所有命令从仓库根目录执行。由于 SDK 原路径只读，格式化直接调用现有 SDK 二进制；Flutter 工具使用相同现有 snapshot，在 `/tmp/time_pet_ledger_e3_sdk` 建立临时 SDK 入口：缓存普通文件复制到可写目录，SDK 其余内容链接到现有安装。没有下载、安装或更新依赖。

下列变量仅为复现命令的路径简写：

```sh
task_dart=/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart
task_flutter=/tmp/time_pet_ledger_e3_sdk/bin/cache/flutter_tools.snapshot
```

| 实际检查 | 结果 |
| --- | --- |
| `$task_dart format lib/features/ledger/domain/projection test/features/ledger/domain/projection` | 退出 0，4 文件中 2 文件被格式化 |
| `$task_dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection test/features/ledger/domain/projection` | 退出 0，4 文件、0 changed |
| `env -u HOME DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics analyze --no-pub` | 退出 0，No issues found |
| `DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics test --no-pub test/core/time test/core/identity test/features/ledger/domain/projection` | 退出 1；6 个测试文件均在加载时失败，0 用例执行，原因是监听 127.0.0.1 被禁止 |
| `$task_dart /tmp/e3_t01_contract_check.dart` | 退出 0，44 项补充纯 Dart 检查通过；直接导入生产实现，不需要 Flutter 测试通信 |
| `git diff --check` | 退出 0 |
| 全部既有跟踪 / 未跟踪文件 SHA-256 对照 | 无既有文件改写或删除 |

补充合同检查覆盖三种日期关系、23/24/25 小时显式日长、零点、空集、近似、正时长舍入零、汇总后舍入、非法日边界 / now / 负时长。脚本位于本次环境 `/tmp/e3_t01_contract_check.dart`，不是正式测试套件的替代品。

前期工具失败如实记录：普通 `dart format` 包装脚本写 SDK engine stamp 被只读文件系统拒绝；直接 Flutter snapshot 打开 SDK lockfile 被拒绝；临时缓存解决后，分析服务器仍尝试写用户目录 telemetry log。最后分析命令仅对子进程移除 HOME 输入以禁用该目录发现，未修改用户环境或遥测配置，分析随后通过。测试的本地套接字限制仍未解决，未将其计为通过。

## Self-review

已逐项核对新生产文件和测试的边界、字段、空集近似及摘要存在性，验证只有 core/time 导入，无设备时区或全局当前时间、固定日长生产常量、Flutter / SQL 依赖。没有进入 E3-T02。既有 TASKS、IMPLEMENTATION_PLAN 及 E2 工作区改动均保留；本任务仅新增上述 5 个文件。

## Blockers / Open Questions / Next executable task

产品未决项：无。原验收 blocker 已由用户本机执行结果解除：2026-09-28 用户在本次对话提供 `flutter test --no-pub test/core/time test/core/identity test/features/ledger/domain/projection` 输出，末行为 `00:01 +31: All tests passed!`。这覆盖本任务 12 项测试及 core/time / identity 19 项回归；没有将其外推为 E3-T02 新增测试通过。

下一开发 Task 为 E3-T02（其余 E1 前置已有负责人完成记录）；用户已明确授权继续，由 E3-T02 单独报告其交付和验证。
