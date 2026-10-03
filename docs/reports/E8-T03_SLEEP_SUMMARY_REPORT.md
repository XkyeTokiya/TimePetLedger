# E8-T03 — 呈现完整睡眠背景摘要

**Task / Status：E8-T03 / COMPLETE。** 日期：2026-10-02。

## 依据与依赖

核对 AGENTS、完整 Task、SOT / 睡眠独立与自然日投影、共同必读 OQ / MVP / PLAN，以及 DERIVED / sleepSummary、RULES / SL-001–SL-005、MVP / M-05。Q-010、Q-014、Q-017、Q-021 均为 DECIDED，无来源冲突或产品阻塞。直接依赖 E8-T01、E5-T07 的完整归档、COMPLETE 报告及实际摘要入口 / 睡眠闭环实现已核查。

按 AGENTS 委派 code_mapper 有界只读勘查更正睡眠与测试入口；主 agent 检查 repository 更正签名及返回事实、现有 SleepSummaryView 和 loader，再负责实现、集成和验证。

## Changes

- `lib/features/ledger/presentation/day_summary_page.dart`：新增“睡眠背景”及醒来日期 / 窗口贡献口径说明，直接组合 `SleepSummaryView(summary: view.sleepSummary)`。主睡眠、小睡各自列出完整记录与合计，使用现有缺失 / 微小时长 / 近似映射；摘要页不提供新增编辑路由。
- `test/features/ledger/presentation/day_summary_sleep_test.dart`：4 项真实 Native SQLite + 摘要 widget 测试，涵盖跨日、多条主睡眠、小睡、独立近似、缺失、微小时长、今日午夜醒来、未来空窗口，以及正式更正醒来日期后的两日重读。
- TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告：完成索引、完整定义归档、局部 Epic 状态及验证证据。

沿用 E8-T01 同事务事实快照和 DayLedgerView.sleepSummary；不从窗口切片恢复完整睡眠，不新建计算、存储或重复查询。未改 SleepSummaryView、repository、schema、依赖或睡眠提醒政策；未实现质量输入、趋势、因果分析、nap / recovery 联动或 E8-T04 内容。

## 验收证据

- 23:50–次日 07:40 的主睡眠保留完整近似 470 分钟与原始两端；第二条主睡眠 60 分钟全部列出，主睡眠合计约530 分钟；20 分钟 nap 单列，覆盖为精确540 分钟（460+60+20），不计段间清醒时间。
- 无记录时主睡眠 / 小睡分别显示尚未记录；精确 20 秒主睡眠显示“少于 1 分钟”，近似 20 秒 nap 显示“约少于 1 分钟”。两条 20 秒主睡眠合计 40 秒显示 1 分钟，不逐条先舍入。
- 今日零点醒来的跨日主睡眠仍显示完整约60 分钟，今天零点空窗口覆盖为零；未来日期已有完整主睡眠显示480 分钟而覆盖 / Gap 仍为零，缺失 nap 独立提示。
- 经正式 repository 将同一睡眠的起止更正到下一醒来日期，刷新原日主睡眠变为尚未记录，但仍有新睡眠入睡日约60 分钟切片；切换新日显示完整约480 分钟与精确420 分钟日贡献。保留 id / createdAt、updatedAt 正确更新；旧结果不变，正式库仍只有一条完整睡眠。
- 检查摘要读取未改原始睡眠边界 / 精度，没有创建 TimeBlock、RhythmAnnotation 或 DailyReview。现有 E8-T01 / E8-T02 入口及覆盖测试、E5-T07 真实文件库睡眠应用闭环本轮均重跑通过。

## Validation

仓库根目录使用已有 SDK / 依赖，无安装或更新。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_sleep_test.dart` | 退出 0，2 文件，1 changed |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_sleep_test.dart` | 退出 0，2 文件，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/day_summary_sleep_test.dart test/features/ledger/presentation/day_summary_coverage_test.dart test/features/ledger/presentation/day_summary_page_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/app/day_summary_entry_test.dart test/app/sleep_recording_flow_test.dart test/features/ledger/domain/projection/sleep_summary_test.dart` | 退出 0，30 项通过，无跳过 |
| `git diff --check`、基线 SHA-256 对照、文档链接 / 归档检查 | 通过 |

日志 `/tmp/e8_t03_analyze.log`、`/tmp/e8_t03_tests.log`。没有失败后未修复的验证项。

## Self-review

检查新增测试全文、摘要页增量、完整记录 / 合计与窗口口径、独立近似与存在性、真实 SQLite 更正和读取、连接释放、事实身份、范围及依赖。执行前记录已有文件 SHA-256，代码验证结束时仅既有 day_summary_page.dart 改变；其余已有代码 / 测试 / 集成文件 / 文档 / pubspec / lockfile 保留。随后只更新三个规划文件与新增报告；未覆盖现有未跟踪文件、无关格式化或依赖改动。

## Blockers / Open Questions

无阻塞，无新增未决问题。本轮为 Flutter widget、真实 Native SQLite 与现有真实文件库应用闭环验证，未执行 Android / Web 端到端或实际系统时区切换，不将本机证据外推为平台验收。平台摘要验证仍属于 E8-T06。

## Next executable task

E8-T04 — 呈现目标四项细分与全局节奏摘要。前置 E8-T01、E7-T05、E3-T04 有完成依据，相关 Q 已决定。仅报告，不执行；完成 E8-T03 后停止，Epic 8 未标完成。
