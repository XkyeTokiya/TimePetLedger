# E4-T02 — 实现普通入口的时间建议分支

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

前置 [E4-T01](E4-T01_RECORDING_LEDGER_READ_REPORT.md) 已 COMPLETE；本轮检查实际 RecordingLedgerLoader、日期上下文与 E3 覆盖输出，并回归其真实 SQLite 读取测试。依据 AGENTS、TASKS / E4-T02、Source of Truth §27–28、DOMAIN_RULES / 时间建议合同、DOMAIN_MODEL / UI Models 和 OPEN_QUESTIONS / Q-023（DECIDED），并沿用当前上下文已核对的 MVP / PLAN 范围。无冲突或缺失产品决定。

本次为接口和实现已在当前上下文中明确的小型纯逻辑变更，没有跨目录未知调用链定位或外部资料需求，按 AGENTS 的委派例外不重复委派勘查。

## Changes

| 文件 | 交付 |
| --- | --- |
| [recording_time_suggestion.dart](../../lib/features/ledger/application/recording_time_suggestion.dart) | 纯建议函数、三种互斥结果和可修改时间输入值 |
| [recording_time_suggestion_test.dart](../../test/features/ledger/application/recording_time_suggestion_test.dart) | 12 项建议与精度行为测试 |
| [TASKS.md](../../TASKS.md#e4-t02--实现普通入口的时间建议分支)、本报告 | 仅追加本任务状态与验证证据 |

suggestRecordingTime 接收同一日期的 relation 与 LedgerCoverage，可直接使用 E4-T01 输出；explicitGap 参数用于用户明确点击 Gap 的预填，供 Epic 6 复用。调用方必须提供所选日期全部正式事实的 E3 投影；本函数不查库、不读取时钟、不重新计算 Gap。

按 Q-023 顺序返回：

1. 明确 Gap：DirectTimeSuggestion，预填该 Gap。
2. 普通入口未来日、无 Gap 或 accounted 毫秒为零：ManualTimeEntry，起止未填写。
3. 今天已有事实且最后一个 Gap 截至窗口结束（显式 now）：DirectTimeSuggestion，只建议尾部 Gap。
4. 其余情况：TimeCandidates，保留全部 Gap 的时间顺序，无预选；一个候选也要用户确认。

RecordingTimeInput 为非持久化的时间输入值，非完整草稿存储实现。新建默认两端 approximate，不继承 Gap 的 exact。withTimes 可修改或清空起止，保留两端精度；withPrecisions 只通过显式参数改变对应端精度。输入过程中允许未完成或暂时无效的区间，正式保存校验仍由后续任务负责；本任务不保存任何事实。

## Validation

本 agent 在仓库根目录实际执行：

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/application/recording_time_suggestion.dart test/features/ledger/application/recording_time_suggestion_test.dart` | 退出 0；2 文件格式化 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/application/recording_time_suggestion.dart test/features/ledger/application/recording_time_suggestion_test.dart` | 退出 0；2 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/features/ledger/application` | 退出 0；17 项全部通过，含新增 12 项与 E4-T01 的 5 项真实 SQLite 回归 |
| `git diff --check` | 退出 0 |
| 开始时全部跟踪 / 未跟踪文件 SHA-256 对照 | 代码交付与验证后既有文件 0 改动；收尾仅追加 TASKS / E4-T02 状态 |

测试日志：本机临时文件 `/tmp/e4_t02_tests.log`。

测试使用真实 E3 窗口、切片与覆盖输出，不手工伪造 Gap。覆盖决策表全部分支：今天全空与明确点击同一整窗 Gap；明确选择优先于普通尾部建议；未来、今天零点、历史全空；无 Gap / 事实跨 now；混合睡眠与 Unknown 的多个 Gap，尾部精确截至显式 now；仅睡眠或仅 Unknown 均算正式事实；今天无尾部的单候选与多候选；历史单个尾部候选仍需确认及历史多候选；只有窗口外未来事实时仍手填。

精度测试验证手填、直接建议、明确 Gap 和候选均为 approximate，修改 / 清空时间不变更精度，两端可独立明确选择，输入和不可修改候选列表不被原地变更。

## Self-review / Blockers / Open Questions

已检查两个新增文件完整内容、决策顺序、E3 输出前提、空窗 / 空事实区别、近似精度及修改行为。无全局时钟、数据库 / Flutter 依赖、重复投影算法、自动 exact、自动保存或持久化建议；未扩展完整时间轴、草稿存储或表单。

既有用户改动和未跟踪文件保留；未改 E4-T01、领域算法、repository、依赖、平台文件或其他任务状态。无 blocker 或新增 Open Question。纯逻辑任务不涉及新增平台操作，本次不声明 Android / Web 表单闭环通过。

## Next executable task

**E4-T03 — 实现普通记录本机草稿存储**。其前置 E4-T02 已完成，E2-T02 有既有完成报告；具体持久化复用边界在执行该任务时核验。本次仅执行 E4-T02，未开始后续任务。
