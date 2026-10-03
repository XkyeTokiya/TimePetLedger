# E3-T04 — 实现节奏与目标时间汇总

**Status：COMPLETE。** 执行日期：2026-09-28。

实现、12 项新增测试及 self-review 已完成；格式检查和静态分析通过。agent 沙箱内相关 Flutter 测试因本地套接字权限而在加载阶段失败；用户随后提供本机同一相关测试命令的 `00:01 +77: All tests passed!` 结果，补齐正式验收证据。

## 前置与依据

用户明确授权 E3-T04。E3-T02 依据[切片报告](E3-T02_FACT_SLICING_REPORT.md)为 COMPLETE，E1-T05、E1-T06 依据 [Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)。测试中的覆盖不变检查复用已完成 E3-T03 的纯覆盖接口，不修改其实现。

已核对 Task 全部定义、Source of Truth §18 / §30、MVP_SCOPE / M-04–05、IMPLEMENTATION_PLAN / Epic 3、APP_ARCHITECTURE / 纯派生逻辑、DERIVED_MODELS / goalSummaries 和三项全局节奏、DOMAIN_RULES / LEDGER-006–007 与 §18 算术一致性记录，以及 OPEN_QUESTIONS / Q-019、Q-020、Q-021。相关问题为 DECIDED；无新产品冲突或缺失。按 AGENTS 委派 code_mapper 只读核查接口、Goal 字段及来源，主 agent 检查证据后实施。

## Changes

| 文件 | 职责 |
| --- | --- |
| [goal_rhythm_summary.dart](../../lib/features/ledger/domain/projection/goal_rhythm_summary.dart) | RhythmSummary、GoalSummary 及两个纯汇总入口 |
| [goal_rhythm_summary_test.dart](../../test/features/ledger/domain/projection/goal_rhythm_summary_test.dart) | 12 项行为测试、细分分区及覆盖口径核对 |
| 本报告 | 实施范围、验证和限制 |

`projectRhythmSummary` 从同一窗口的全部普通事实切片汇总明确 progress、stuck、recovery，包含无 Goal 记录；不计入睡眠，不从标题、已知性或可选细节推断 / 过滤节奏。

`projectGoalSummaries` 显式接收切片和 Goal 元数据。仅列有正时长贡献的 Goal，按 id 分组并保留名称、归档标记；无记录目标省略，同名不同 id 不合并，无 Goal 不构造替代目标。每项包含 totalDuration 及 progress / stuck / recovery / unannotatedDuration 四项，全部使用 SummaryDuration 独立保存实际毫秒、hasRecords 和 hasApproximation。

未标记只取无 annotation 参与集，不能用总量减推进减卡住替代。全局恢复包含有 / 无 Goal 的恢复；每目标恢复是相应子集，两个范围不重复相加。汇总不修改输入或账本覆盖，也不查库或生成 UI 文案。

工程输入合同：切片必须来自同一窗口的完整合法事实；所需 Goal 元数据必须齐全且 id 唯一，缺失被引用目标或重复 id 抛 ArgumentError，不丢弃贡献、猜测名称或任意覆盖。额外无记录 Goal 合法。输出不可修改，沿用调用方元数据顺序；这不是新增 UI 排序或产品筛选规则。

## 测试与验收映射

1. SOT §18 五段原时间区间按校正总量验证：5h / progress 3h30m / stuck 40m / unannotated 50m，recovery 缺失，不复制原 4h30m 算术错误。
2. 全未标记目标仍显示，标题包含节奏文字也不自动分类。
3. 全 recovery 目标仍显示且未标记缺失，恢复方式和质量为空不排除贡献。
4. 无 Goal 的三种节奏均进入全局；Unknown、原因为空同样计入。
5. 同名不同 id 分开，归档保留标记，无记录目标不占行；输出不可修改。
6. 窗口外、仅相接和空窗口没有目标贡献，全局各项独立缺失。
7. 四项分别近似时仅影响自身及总量，不将全局标志复制到细分。
8. 一毫秒贡献仍保留目标、实际时长与存在性，其他细分保持缺失，分钟舍入为零不丢失记录。
9. 有 / 无 Goal recovery 与两类睡眠混合；全局恢复和目标恢复口径分开，目标列表选择不改完整账本覆盖和 Gap。
10. 跨窗口 / now 的贡献只算切片；被裁掉的近似不传播，20 秒加 20 秒先按毫秒汇总再舍入为 1 分钟。
11. 更换有效解释、Goal 改名 / 归档后重算使用当前快照，不累计旧解释或改写旧结果。
12. 缺少所需 Goal、重复元数据 id 明确拒绝，验证调用输入失败路径。

## Validation

沿用现有 SDK 及 E3-T01 的 `/tmp/time_pet_ledger_e3_sdk` 临时可写缓存入口，不安装或解析依赖。以下变量仅为实际命令路径简写：

```sh
task_dart=/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart
task_flutter=/tmp/time_pet_ledger_e3_sdk/bin/cache/flutter_tools.snapshot
```

| 实际命令 / 检查 | 结果 |
| --- | --- |
| `$task_dart format lib/features/ledger/domain/projection/goal_rhythm_summary.dart test/features/ledger/domain/projection/goal_rhythm_summary_test.dart` | 退出 0；2 文件格式化 |
| `$task_dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection/goal_rhythm_summary.dart test/features/ledger/domain/projection/goal_rhythm_summary_test.dart` | 退出 0；2 文件、0 changed |
| `env -u HOME DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics analyze --no-pub` | 退出 0；No issues found |
| `DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics test --no-pub test/features/ledger/domain/projection test/features/goals/domain test/features/ledger/domain/rhythm_annotation_test.dart` | 退出 1；8 文件加载失败，0 用例执行；127.0.0.1 server socket 被沙箱禁止 |
| `git diff --check` | 退出 0 |
| 全部既有跟踪 / 未跟踪文件 SHA-256 对照 | 无既有文件改写或删除 |

沙箱失败日志在 `/tmp/e3_t04_flutter_tests.log`，保留上述失败历史，不将用户执行记作 agent 执行。

**用户本机执行证据：** 用户在本次对话回传以下命令的最终输出 `00:01 +77: All tests passed!`，77 项相关测试全部通过，包含本任务新增 12 项及 projection、Goal 和 RhythmAnnotation 回归。收到结果后仅更新本报告，未再修改生产代码或测试。

```sh
flutter test --no-pub test/features/ledger/domain/projection test/features/goals/domain test/features/ledger/domain/rhythm_annotation_test.dart
```

## Self-review / Blockers / Next executable task

已检查新生产文件及测试完整内容、分组与选择范围、存在性和精度、毫秒求和、目标身份 / 元数据、缺失失败路径、覆盖不变、报告链接及工作区范围。只新增本任务三个文件，不改动实体、E3-T01–03、规划、TASKS、存储、依赖或其他既有工作区修改。

无产品未决项或剩余验收 blocker。沙箱本地通信限制仍存在，但用户本机测试通过证据已补齐。下一可执行开发 Task 为 E3-T05（其 E3-T01、E3-T02、E1-T04 前置已有完成证据）；本次未执行该任务或其他后续实现。
