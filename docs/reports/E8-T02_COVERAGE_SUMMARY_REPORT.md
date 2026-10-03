# E8-T02 — 呈现账本覆盖与 Unknown 摘要

**Task / Status：E8-T02 / COMPLETE。** 日期：2026-10-02。

## 依据与依赖

核对 AGENTS 工作方式、完整 Task、SOT 的 Unknown / Gap、日投影与描述性统计合同、OQ、MVP / M-05、PLAN / Epic 8、DERIVED 的三项覆盖时长及 RULES / LEDGER-005–LEDGER-009。Q-009、Q-014、Q-017、Q-021 均为 DECIDED，无来源冲突或缺失产品决定。

直接依赖 E8-T01 的完整归档、COMPLETE 报告及现有摘要页、loader、controller 已核对。复用基础 E3-T03 的 coverage 及 E3-T07 的格式映射实现与完成证据已核查。本轮范围是已知页面的小型接线，无未知跨文件定位需求，按成本规则跳过额外勘查委派。

## Changes

- `lib/features/ledger/presentation/day_summary_page.dart`：摘要覆盖区块直接展示 DayLedgerView 的 accountedDuration、unknownDuration、unresolvedDuration；三项各自调用已有 formatDerivedDuration。使用“已交代”“其中未知”“尚未记录”，补充“未知已包含在已交代时间中。”；非空窗口零 Gap 明确为“此账本窗口没有未记录缺口。”，空窗口明确不产生缺口，不暗示完成成绩。
- `test/features/ledger/presentation/day_summary_coverage_test.dart`：6 项 widget 测试、多组手算事实夹具；经现有 DayLedgerLoader / projectDayLedgerView 生成实际投影，核对实际毫秒和展示结果。
- `test/app/day_summary_entry_test.dart`：真实 Native SQLite AppBootstrap 入口增加空库、跨零点及成功保存 Unknown 后刷新断言；草稿仍保留且不计入。
- TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告：完成索引、完整定义归档、证据及 Epic 8 局部状态更新。

没有更改领域计算、loader、controller、格式映射、持久化或依赖；没有完整度比例、固定 1440 分母、补账新入口或后续 Task 内容。现有同一窗口覆盖包括睡眠和 Unknown，Unknown 没有再次相加。

## 验收证据

- 全空 23 / 25 小时历史日分别显示 1380 / 1500 分钟尚未记录；今天 15:00 只显示截至 now 的 900 分钟。
- 今天零点及未来空窗口：三项为精确零，窗口外近似 Unknown 不贡献、不制造补账提示。
- 手算混合睡眠、known、Unknown、Gap：240 分钟窗口中已交代 210、其中未知 30、尚未记录 30；Unknown 是已交代子集。
- 全覆盖但内部近似：已交代约100、其中未知约50、Gap 精确零，零 Gap 仅表达数据状态。
- 已交代近似不扩散给精确 Unknown / Gap；另验证近似 Gap 与精确 Unknown 并存。
- 跨日近似起点被裁掉后当天覆盖精确，未来事实不影响今天截至 now 的结果。
- 正 20 秒分别显示少于 1 分钟及约少于 1 分钟；两段 20 秒汇总显示 1 分钟，不逐条先舍入。70 秒窗口中覆盖 40 秒、Gap 30 秒均显示 1 分钟，测试只在毫秒层验证分区，未强制展示数相等。
- 真实库：摘要独有午夜醒来睡眠不贡献当天覆盖；创建近似结束的 20 秒 Unknown 后刷新，显示已交代 / 其中未知均“约少于 1 分钟”，40 秒 Gap 显示“约1 分钟”。原睡眠边界和精度不变，本机草稿保留。

## Validation

仓库根目录使用现有 SDK / 已安装依赖，无工具或包安装。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_coverage_test.dart` | 退出 0，2 文件，1 changed |
| `dart format test/app/day_summary_entry_test.dart` | 退出 0，1 文件，1 changed |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_coverage_test.dart test/app/day_summary_entry_test.dart` | 退出 0，3 文件，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/day_summary_coverage_test.dart test/features/ledger/presentation/day_summary_page_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/features/ledger/presentation/summary_formatting_test.dart test/features/ledger/domain/projection test/app/day_summary_entry_test.dart` | 最终退出 0，84 项通过，无跳过 |
| `git diff --check`、基线 SHA-256 对照、文档链接 / 归档检查 | 通过 |

首轮分析与同测试清单通过；补充真实库 Unknown 刷新断言后重跑最终分析及上述测试，均通过。日志 `/tmp/e8_t02_analyze_final.log`、`/tmp/e8_t02_tests_final.log`。

## Self-review

检查新增测试全文、页面与入口测试增量、毫秒关系 / 舍入 / 精度 / 窗口、空数据与错误状态及范围。执行前记录已有文件 SHA-256，代码验证结束对照仅 day_summary_page.dart 与 day_summary_entry_test.dart 两个既有文件改变；所有其他已有代码、测试、集成文件、文档及 pubspec / lockfile 内容保留。随后只作上述三个规划文件状态更新及新增报告。没有覆盖既有未跟踪文件、无关格式化、新依赖或下一 Task 实现。

## Blockers / Open Questions

无阻塞，无新增未决问题。未执行 Android / Web 端到端或真实系统时区切换；本轮实际证据为 Flutter widget、已有纯投影回归及 Native SQLite 应用入口，不外推为平台验收。平台摘要验收仍属于 E8-T06。

## Next executable task

E8-T03 — 呈现完整睡眠背景摘要。前置 E8-T01、E5-T07 有完成依据，相关 Q 已决定。仅报告，不执行；完成 E8-T02 后停止，Epic 8 未标完成。
