# E3-T05 — 实现完整睡眠摘要与已记录判定

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

直接依赖已核对：E3-T01 的[完成报告](E3-T01_PROJECTION_CONTRACT_REPORT.md)包含用户本机 31 项测试通过证据；E3-T02 的[完成报告](E3-T02_FACT_SLICING_REPORT.md)包含用户本机 57 项测试通过证据；E1-T04 依据负责人确认的 [Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)。已检查现有 SleepSession、窗口、切片、时长类型及相应测试，本次也实际运行相关回归，未补造历史验证结果。

已阅读 AGENTS、完整 Task、Source of Truth、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN，以及 DERIVED_MODELS / sleepSummary、DOMAIN_RULES / SL、DOMAIN_MODEL / SleepSession、APP_ARCHITECTURE / projection。Q-008、Q-010、Q-014、Q-021 均为 DECIDED，未发现冲突或缺失决定。按项目规则委派 code_mapper 有界只读勘查，由主 agent 核查证据、实现和验证。

## Changes

- [sleep_summary.dart](../../lib/features/ledger/domain/projection/sleep_summary.dart)：新增 projectSleepSummary、SleepSummary、SleepTypeSummary 和 hasRecordedMainSleepToday。
- [sleep_summary_test.dart](../../test/features/ledger/domain/projection/sleep_summary_test.dart)：新增 11 项行为测试。
- [TASKS.md](../../TASKS.md#e3-t05--实现完整睡眠摘要与已记录判定)：记录本任务实际完成状态及报告链接。
- 本报告：记录依据、实际验证、范围及后续任务。

调用方按当前设备时区提供目标自然日零点和次日零点的绝对时间；摘要按 endedAt 落入该完整日的半开区间选择所有原始记录，不接收裁剪后的 W。主睡眠、小睡分别返回按起点排序的不可修改列表，保留原对象、原始边界和独立精度；完整时长使用既有 SummaryDuration，分别携带 hasRecords、毫秒与 hasApproximation。逐段相加不计清醒，不逐条舍入。

已记录判定单独接收今天的当地日边界和 now；要求 now 在所提供的今天内，仅至少一条今天醒来且 endedAt ≤ now 的 mainSleep 返回 true。摘要仍包含匹配日期的未来结束记录，不能以摘要存在性替代已记录判定。日边界需递增，不固定为 24 小时；参数检查仅保护调用合同，不改变事实保存规则。

## Validation

以下命令由本 agent 在仓库根目录实际执行，均退出 0；使用现有 SDK，没有安装依赖。

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/domain/projection/sleep_summary.dart test/features/ledger/domain/projection/sleep_summary_test.dart` | 2 文件格式化 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection/sleep_summary.dart test/features/ledger/domain/projection/sleep_summary_test.dart` | 2 文件，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub test/core/time test/core/identity test/features/ledger/domain/projection test/features/ledger/domain/sleep_session_test.dart` | 86 项全部通过，包含本任务 11 项 |
| `git diff --check` | 通过 |

测试覆盖多段主睡眠、小睡单列、白天主睡眠、不计段间清醒、未排序输入及不可变输出、午夜醒来与空 W、次日零点排除、只有 nap / 未来主睡眠 / 其他日主睡眠、endedAt 与 now 的毫秒临界、任一已结束主睡眠、空集及无匹配、微小时长存在性、汇总后舍入、完整 7h50 与切片 7h40、两端独立精度、跨 now 的近似裁剪、UTC 与 UTC+8 显式日期重投影、23/25 小时日边界和长睡眠、非法调用参数。

## Self-review

已检查全部新增生产文件和测试，不从切片恢复摘要，不读全局时钟 / 设备时区，不引入 Flutter / 数据库依赖、查询、UI 文案、调度、评分或恢复关联。输入前提沿用合法、不重叠、身份唯一的事实快照，不制定非法数据修复政策。设备时区到当地日边界的转换由调用方负责，本任务不实现数据查询或平台时区适配。

修改前的 lib、test、docs 全部既有文件做 SHA-256 对照，实施与验证后均未改写；TASKS 仅追加 E3-T05 状态，保留此前工作区改动。新建未跟踪文件已纳入自查。没有修改依赖或开展 E3-T06。

## Blockers / Open Questions

无。本任务的格式、分析、相关测试均通过；纯投影任务不涉及新的持久化或平台接入，未声称完成 Android / Web 集成验收。

## Next executable task

E3-T06 — 组装 DayLedgerView 并核验派生关系。其 E3-T03、E3-T04 完成报告与本次 E3-T05 交付已具备，Epic 1 有整体完成记录。需用户另行指定后执行；本次至 E3-T05 停止。
