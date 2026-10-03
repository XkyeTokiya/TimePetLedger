# E8-T01 — 接通摘要日期上下文与一致读取

**Task / Status：E8-T01 / COMPLETE。** 日期：2026-10-02。

## 依据与依赖

已阅读 AGENTS、完整 Task、SOT、OQ、MVP、PLAN、APP 读取流程、DATA 一致读取及 DERIVED DayLedgerView；核对 COMPLETED_TASKS 中 E3-T06、E3-T07、E5-T01、E6-T01 完整定义、对应 COMPLETE 报告与实际代码。Q-008–Q-010 均为 DECIDED，无来源冲突或阻塞。依项目规则委派 code_mapper 有界只读定位，主 agent 检查其证据并负责实现和验证。

现有 DayLedgerLoader 调用 projectDayLedgerView；createDayLedgerLoader 的外层事务包含 readSleepContext 的窗口事实、完整醒来日睡眠候选与引用 Goal 元数据。摘要直接复用此组装及 DayLedgerController，没有另建 application loader、读取事务或投影算法。

## Changes

- `lib/features/ledger/presentation/day_summary_page.dart`：新增基础摘要日期入口，复用完整 DayLedgerView 与 controller。提供日期选择、今天、刷新、加载、空数据、失败重试；返回路由及恢复前台重新获取上下文。窗口长度使用现有 summary_formatting 格式映射，不固定 1440 分钟。
- `lib/app/main_app.dart`：新增“打开基础摘要”路由，传入已由 AppBootstrap 组装的 dayLedger、显式时钟、设备日期适配与 RouteObserver。当前日期跟随今天，明确历史 / 未来选择保留。
- `test/features/ledger/presentation/day_summary_page_test.dart`：加载 / 空 / 错误 / 重试、快速切日、非法输入、跨零点、路由返回、前台恢复及 23 / 25 小时窗口。
- `test/features/ledger/presentation/day_summary_controller_test.dart`：直接验证共用 controller 的完整跨日睡眠 8h 与窗口贡献 7h、独立近似标志、刷新裁剪为 1h、旧投影不变。
- `test/app/day_summary_entry_test.dart`：真实 Native SQLite AppBootstrap 摘要入口、跨零点刷新、草稿保留且不参与事实、午夜醒来仅进入摘要也为 ready、原始睡眠边界与精度不变。
- TASKS、COMPLETED_TASKS、本报告：完成状态、完整定义归档及证据。

历史完整日、今天截至 now、未来空窗口沿用原投影；完整睡眠按 endedAt 的醒来日期查询，与窗口切片分开。每次刷新取得新 now / 日界，旧成功和旧失败由共用 controller 请求序号淘汰。读取错误不会伪装为空集合。摘要页没有草稿依赖。

本任务只交付日期上下文及读取入口；没有实施 E8-T02 覆盖 / Unknown 摘要内容、E8-T03 睡眠展示或后续目标 / 节奏展示，没有统计表、schema、依赖、周月报或时区设置。

## Validation

仓库根目录使用现有 SDK / 依赖，未安装或更新工具。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/app/main_app.dart lib/features/ledger/presentation/day_summary_page.dart test/features/ledger/presentation/day_summary_page_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/app/day_summary_entry_test.dart` | 退出 0，5 文件，4 changed |
| 同清单运行 `dart format --output=none --set-exit-if-changed` | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=America/New_York flutter test --no-pub test/features/ledger/application/day_ledger_loader_test.dart test/features/ledger/presentation/day_ledger_controller_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/features/ledger/presentation/day_summary_page_test.dart test/app/day_summary_entry_test.dart` | 退出 0，11 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time` | 退出 0，483 项通过，3 项依既有时区条件跳过 |
| `git diff --check`、基线 SHA-256 对照、文档链接检查 | 通过 |

纽约定向覆盖真实设备日期适配的 23 / 25 小时日。既有 loader 测试本轮重跑，验证与现有 projectDayLedgerView 一致、完整醒来日睡眠与窗口不同、历史 / 今天 / 未来 / 零点窗口、空 W 时存储失败，以及两个独立文件连接的读取一致性；竞争写入在读取事务中被 SQLite busy 拒绝，释放读取后重读得到新快照。双连接测试的 Drift 多实例 debug 提示属刻意构造的真实独立连接场景，测试通过。

日志：`/tmp/e8_t01_analyze.log`、`/tmp/e8_t01_ny.log`、`/tmp/e8_t01_shanghai.log`。

## Self-review

检查新增页面及三份测试完整内容、app 增量、日期选择与刷新、生命周期释放、状态 / 错误文案、投影复用和范围。基线 SHA-256 对照确认代码验证结束时仅已有 main_app.dart 改变；移除本轮新增 import、方法、按钮后其内容哈希与执行前完全一致。其余已有生产 / 测试 / 文档 / integration_test / pubspec / lockfile 均保留。之后只更新 TASKS、COMPLETED_TASKS 并新增报告；没有无关格式化或覆盖原未跟踪文件。

## Blockers / Open Questions

无阻塞，无新增未决问题。没有执行 Android / Web 端到端、实际系统运行中时区切换或平台生命周期验证；本轮证据为 Flutter controller / widget、真实 Native SQLite 与两个 TZ 进程，平台摘要验收留 E8-T06。

## Next executable task

E8-T02 — 呈现账本覆盖与 Unknown 摘要。依赖 E8-T01 已完成，Q-009、Q-014、Q-017、Q-021 已决定。仅报告，不执行；本次完成 E8-T01 后停止，不将 Epic 8 标记完成。
