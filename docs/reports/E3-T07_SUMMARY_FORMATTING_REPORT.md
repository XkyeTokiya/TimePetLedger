# E3-T07 — 实现摘要展示语义的纯映射

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

直接依赖 [E3-T06](E3-T06_DAY_LEDGER_VIEW_REPORT.md) 已完成，具有 206 项相关测试通过证据；已核查实际 DayLedgerView、SummaryDuration、DerivedDuration、GoalSummary 和舍入接口。

遵循 AGENTS，阅读完整 Task、Source of Truth、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN、DERIVED_MODELS / 摘要存在性与分钟展示、DOMAIN_RULES / 摘要缺失表达、APP_ARCHITECTURE / presentation。Q-017、Q-021 均为 DECIDED，文案和计算合同一致，无新增 blocker。按项目规则委派 code_mapper 有界只读勘查，主 agent 检查其证据后实施与验证。

## Changes

| 文件 | 修改 |
| --- | --- |
| [summary_formatting.dart](../../lib/features/ledger/presentation/summary_formatting.dart) | 新增不依赖 Widget 的三项纯映射及展示用 SummaryDurationKind |
| [summary_formatting_test.dart](../../test/features/ledger/presentation/summary_formatting_test.dart) | 新增 7 项测试，含真实 DayLedgerView 输出映射 |
| [TASKS.md](../../TASKS.md#e3-t07--实现摘要展示语义的纯映射) | 追加 E3-T07 完成状态与报告链接 |
| 本报告 | 记录实际验证及 Epic 3 验收核对 |

`formatSummaryDuration` 接收单项投影，先检查 hasRecords；缺失时分别返回“尚未记录主睡眠”“尚未记录小睡”“未记录推进”“未记录卡住”“未记录恢复”“没有未标记节奏的记录”。有记录才格式化实际时长，不能将缺失睡眠或推进表示为实际活动为零。

`formatDerivedDuration` 读取 DerivedDuration.roundedMinutes，继续复用 core/time 的最终四舍五入；不重新计算或汇总事实。实际正时长舍入为零显示“少于 1 分钟”，本项近似时显示“约少于 1 分钟”。普通时长采用 `N 分钟`，近似为 `约N 分钟`；这是最小展示格式，不改变领域时间单位或计算。覆盖 / Unknown / Gap 的实际零值显示“0 分钟”，Gap 的零保持无缺口语义。

`goalSummariesEmptyMessage` 对空目标列表返回“这段时间还没有目标相关记录”，非空返回 null（无需空列表提示）。展示分类仅存在于 presentation，不新增领域枚举或持久化值。

## Validation

本 agent 从仓库根目录实际执行，均退出 0；未安装依赖。

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/presentation/summary_formatting.dart test/features/ledger/presentation/summary_formatting_test.dart` | 2 文件格式化 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/summary_formatting.dart test/features/ledger/presentation/summary_formatting_test.dart` | 2 文件，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub test/core/time test/features/ledger/domain/projection test/features/ledger/presentation` | 90 项全部通过，含本次新增 7 项 |
| `git diff --check` | 通过 |

测试覆盖六种缺失文案、每类 1ms / 20s / 29999ms 的精确及近似表达、29999 / 30000 / 30001 和 89999 / 90000 / 90001ms 舍入边界、60 秒和 90 分钟普通表达、20s+20s 与 30s+30s 汇总后舍入、真实零与微小时长区分、空日投影、空 / 非空目标列表，以及真实混合投影中逐项存在性和近似提示的独立性。混合例验证目标缺失恢复不能借用全局恢复；近似覆盖不能把精确 Gap 显示为近似。

## Self-review

检查新增生产文件和测试全部内容、文案、舍入调用与依赖方向。生产文件仅导入投影结果类型，没有 Widget、Flutter、I/O、数据库、全局时钟、事实查询或重复时长算法。domain 未加入 UI 文案，未实现统计页面、设计系统或国际化框架。

对本轮开始时 lib、test、docs、TASKS、pubspec 文件做 SHA-256 对照，实施和代码验证后均未改写；随后仅追加 TASKS 的 E3-T07 状态并新增本报告。既有工作区修改均保留，新建未跟踪文件已纳入检查。

## Epic 3 验收核对

按 TASKS 的 Epic 完成规则，核对 IMPLEMENTATION_PLAN / Epic 3：

- Epic 1 已有[整体完成记录](EPIC_0_1_COMPLETION.md)。E3-T01–E3-T06 均有对应 COMPLETE 报告，本次 E3-T07 完成；本轮测试覆盖现有全部 projection 与展示映射测试。
- 窗口、时长和切片见 [E3-T01](E3-T01_PROJECTION_CONTRACT_REPORT.md)、[E3-T02](E3-T02_FACT_SLICING_REPORT.md)；支持历史 / 今天 / 未来、实际日长、跨日事实及独立精度。
- 覆盖分区、Unknown 子集、Gap 见 [E3-T03](E3-T03_LEDGER_COVERAGE_REPORT.md)；目标 / 节奏、同名归档、未标记见 [E3-T04](E3-T04_GOAL_RHYTHM_SUMMARY_REPORT.md)。
- 完整睡眠与窗口外记录见 [E3-T05](E3-T05_SLEEP_SUMMARY_REPORT.md)；组合、手算和混合输入不变见 [E3-T06](E3-T06_DAY_LEDGER_VIEW_REPORT.md)。
- 本任务补齐缺失与微小时长展示；没有新增持久化 Day / Gap / 聚合、UI 页面或评分。

据此 Epic 3 的既定纯投影及展示语义验收已满足。此结论不扩展为后续 UI、真实设备日期适配或 Android / Web 功能集成已完成。

## Blockers / Open Questions

无。全部适用检查通过。

## Next executable task

E4-T01 — 接通普通记录的日期上下文与投影读取。其直接依赖 E2-T05、E3-T03、E3-T06 均有完成报告；[E2-T05](E2-T05_LEDGER_READ_REPORT.md) 的状态已核对。本次停止，不执行 Epic 4。
