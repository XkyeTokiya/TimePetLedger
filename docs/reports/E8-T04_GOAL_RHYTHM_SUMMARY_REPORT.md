# E8-T04 — 呈现目标四项细分与全局节奏摘要

**Task / Status：E8-T04 / COMPLETE。** 日期：2026-10-02。

## 依据与依赖

核对 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 DERIVED / goalSummaries 与节奏时长、RULES / LEDGER-006、MVP / M-05。Q-019–Q-021、Q-014、Q-017 均为 DECIDED。直接依赖 E8-T01、E7-T05、E3-T04 的完成定义、对应 COMPLETE 报告与 loader / 投影 / 元数据实现已核查，未发现来源冲突或新产品阻塞。

按 AGENTS 委派 code_mapper 有界只读定位真实 SQLite fixture、Goal 更正及 TimeBlock + annotation 写入 API；主 agent 检查证据，负责实施、集成、自审和最终验证。

## Changes

- `lib/features/ledger/presentation/goal_rhythm_summary_view.dart`：展示现有目标投影列表；目标名、已归档标记、相关总量、明确推进 / 卡住 / 目标内恢复 / 未标记节奏四项；卡片 key 使用 Goal id。同一组件展示全局推进 / 卡住 / 恢复，并说明全局包含无目标记录、目标内恢复已包含在全局恢复中。
- `lib/features/ledger/presentation/day_summary_page.dart`：组合上述视图，传入同一 DayLedgerView.goalSummaries / rhythmSummary；读取状态移到摘要顶部，避免新增内容使状态提示落到屏幕外。
- `test/features/ledger/presentation/day_summary_goal_rhythm_test.dart`：3 项真实 Native SQLite + 摘要 widget 测试，覆盖同名 / 归档 / 无记录目标、四项分区、无 Goal 三种节奏、缺失、微小时长、独立近似、改名 / 归档后刷新和窄屏长名称。
- TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告：完成索引、归档全文、Epic 8 局部状态与证据。

逐项使用既有 formatSummaryDuration，相关总量使用 formatDerivedDuration；空列表使用 goalSummariesEmptyMessage。未新增查询 / 统计算法 / 派生存储 / 依赖，元数据仍由原同事务读取组装取得。未实现效率比例、同名合并、合成无目标 Goal、自动节奏推断或 E8-T05 内容。

## 验收证据

- 两个同名 Goal 按 id 分为两卡；归档目标保留“已归档”，无窗口贡献目标不列出。目标相关 160 秒来自推进20秒、卡住60秒、恢复60秒、未标记20秒；每个目标在实际毫秒层验证四项合计等于总量，未用舍入后的显示强制分区。
- 目标推进近似20秒显示“约少于 1 分钟”，其他细分保持自己的精度；总量约3分钟不被当成推进。另一个全恢复目标缺少推进 / 卡住分别显示“未记录推进 / 卡住”，未标记项显示“没有未标记节奏的记录”。
- 无 Goal 的三种节奏均进入全局：推进80秒、卡住120秒、恢复180秒，分别显示约1、约2、3分钟。全局恢复180秒已经包含两目标恢复120秒，不再相加。全账本覆盖400秒包含全部普通事实。
- 空列表正确提示；全未标记目标合法显示、推进 / 卡住 / 恢复保持缺失，不从活动标题推断。近似20秒恢复在目标及全局均显示“约少于 1 分钟”，存在性保持 true；未来空窗口重读后列表与全局重新呈现缺失。
- Goal 改名并归档后手动刷新取得新名称 / 状态，另一同名 id 保持不变，旧投影元数据不变。200码点名称在360px视口不截断，无 Flutter 布局异常。
- 现有摘要读取 / 日期、覆盖、睡眠、纯投影、格式映射，以及 E7-T05 真实元数据读取失败 / 只读重试与同源编辑测试本轮通过。

## Validation

仓库根目录使用现有 SDK / 已安装依赖，无安装或更新。

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format lib/features/ledger/presentation/goal_rhythm_summary_view.dart lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_goal_rhythm_test.dart` | 退出 0，3 文件，3 changed |
| 状态提示位置修正后 `dart format lib/features/ledger/presentation/day_summary_page.dart` | 退出 0，0 changed |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/goal_rhythm_summary_view.dart lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_goal_rhythm_test.dart` | 退出 0，3 文件，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/day_summary_goal_rhythm_test.dart test/features/ledger/presentation/day_summary_sleep_test.dart test/features/ledger/presentation/day_summary_coverage_test.dart test/features/ledger/presentation/day_summary_page_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/features/ledger/presentation/summary_formatting_test.dart test/features/ledger/domain/projection test/app/day_summary_entry_test.dart test/app/day_ledger_goal_rhythm_test.dart` | 最终退出 0，96 项通过，无跳过 |
| `git diff --check`、基线 SHA-256 对照、文档链接 / 归档检查 | 通过 |

首轮新增测试通过，但新增内容使既有读取状态在默认视口下尚未构建，导致2项旧 widget 断言失败；将读取状态放到摘要顶部后重跑相同清单及分析，全部通过。没有改写旧测试或减少断言。日志 `/tmp/e8_t04_analyze_final.log`、`/tmp/e8_t04_tests_final.log`。

## Self-review

检查新增组件与测试全文、页面接线、Goal id / 元数据 / 贡献选择、四项毫秒关系、hasRecords / 近似独立、恢复观察范围、刷新与长名称布局，确认无计算或存储扩张。执行前记录既有文件 SHA-256，代码验证结束仅既有 day_summary_page.dart 改变；其他已有生产 / 测试 / 集成 / 文档 / pubspec / lockfile 均保留。之后只更新三个规划文件并新增报告，没有覆盖原未跟踪文件、无关格式化、依赖或后续 Task 实现。

## Blockers / Open Questions

无阻塞，无新增未决问题。未执行 Android / Web 端到端或实际系统时区切换；本轮为 Flutter widget、真实 Native SQLite 与相关纯投影回归，不外推为平台验收。平台摘要验证仍属于 E8-T06。

## Next executable task

E8-T05 — 验证摘要随事实与解释变化重算。其前置 E8-T02–E8-T04、E7-T06、E6-T05 有完成依据。仅报告，不执行；完成 E8-T04 后停止，Epic 8 未标完成。
