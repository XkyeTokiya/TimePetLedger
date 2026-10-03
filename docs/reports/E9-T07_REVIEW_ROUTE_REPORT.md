# E9-T07 — 贯通日账本复盘与下一步回看

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T07，完成后停止。

## 前置与依据

核对 AGENTS、Task 完整定义、共同必读 SOT / OQ / MVP / PLAN、SOT §20–22、MVP / M-06、APP / feature 调用流程与依赖方向，以及 MODEL / DailyReview、TomorrowFirstStep 和 RULES / DR-001–DR-004。直接依赖的归档定义、[E9-T04](E9-T04_REVIEW_SUBMISSION_REPORT.md)、[E9-T05](E9-T05_REVIEW_CORRECTION_REPORT.md)、[E9-T06](E9-T06_REVIEW_DELETION_REPORT.md)、[E8-T05](E8-T05_SUMMARY_RECALCULATION_REPORT.md)、[E7-T05](E7-T05_TIMELINE_GOAL_RHYTHM_REPORT.md) 完成报告和相关实现 / 测试均有前置证据。

Q-001、Q-006、Q-012、Q-013 均 DECIDED，规范已同步：已存复盘 CivilDate 不随设备时区改写，intendedDate 取该日期的下一自然日；既有归档 Goal 引用保留；草稿独立；已有对象更正保留身份，事实变化不自动改写复盘文字。没有新增产品决定或修改已决问题。

按 AGENTS 委派 code_mapper 有界只读定位 app / 摘要 / 日账本 / 复盘的日期传递、路由返回刷新和真实库测试夹具。主 agent 检查相关证据后完成实现、测试、集成与自检。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/app/main_app.dart` | 三个入口共用复盘页面装配；向日账本和摘要注入按 CivilDate 打开的复盘页面回调 |
| `lib/features/ledger/presentation/day_ledger_page.dart` | “打开此日复盘”入口、重复点击保护、返回后重读日账本 |
| `lib/features/ledger/presentation/day_summary_page.dart` | “打开此日复盘”入口、重复点击保护、返回后重读摘要 |
| `test/app/review_route_flow_test.dart` | 4 项实际 AppBootstrap + 真实文件 SQLite 路由集成测试 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成索引、原定义归档和验收依据 |

- 入口传递页面当前所选的 CivilDate，不从系统今天、主页旧日期或尚未完成的投影结果推断日期。复盘页取得明确日期；来源页选择“今天”时保留其既有返回刷新行为，历史选择保持原日。
- 有效日期即可进入复盘，不要求摘要已读取成功、账本有记录、没有 Gap 或存在 Goal。日期无效禁用入口；同一帧重复回调只打开一个页面。
- 阅读 / 新建 / 更正 / 删除复用已有 ReviewContextPage、ReviewForm 和 application / repository 合同。已有日期读回当前复盘并按原 ID 更正；保存后显示已存 CivilDate、一个明天第一步和它的下一自然日。改日期后，复盘读回页跟随实际保存日，来源账本 / 摘要保持原选择；旧日和新日重新进入均按数据库当前值读取。
- 接续点继续由时间轴原 TimeBlock 的 RhythmAnnotation 展示为“接续点”；明天第一步继续从 DailyReview.tomorrowFirstStep 读回。新建表单不从接续点或统计生成下一步、概述或反思。
- 从复盘返回时重读当前事实投影，不把旧摘要缓存带回。事实更正和 Goal 元数据变化刷新展示，已存复盘文字和身份保持不变。
- ledger presentation 仅接收 app 注入的页面回调，不导入 review 的 controller / application；未改变领域对象、派生计算、持久化或 schema。

## Validation

在仓库根目录使用已有 Flutter / Dart。以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format lib/app/main_app.dart lib/features/ledger/presentation/day_ledger_page.dart lib/features/ledger/presentation/day_summary_page.dart test/app/review_route_flow_test.dart` | 4 个本次改动文件格式化通过 |
| `dart format --output=none --set-exit-if-changed`（同上 4 文件） | 4 files，0 changed |
| `flutter analyze` | No issues found |
| `flutter test test/app/review_route_flow_test.dart` | 4 项通过，无跳过 |
| 下列相关回归命令 | 209 项通过，5 项既有条件跳过 |
| 执行前 SHA-256 对照、任务原定义 / 文档链接 / 锚点及空白检查 | 通过 |

相关回归的完整实际命令：

```sh
flutter test test/features/review test/app test/features/ledger/presentation/day_ledger_controller_test.dart test/features/ledger/presentation/day_ledger_page_test.dart test/features/ledger/presentation/day_ledger_timeline_test.dart test/features/ledger/presentation/day_summary_controller_test.dart test/features/ledger/presentation/day_summary_page_test.dart test/features/ledger/presentation/day_summary_coverage_test.dart test/features/ledger/presentation/day_summary_goal_rhythm_test.dart test/features/ledger/presentation/day_summary_sleep_test.dart
```

验收证据：

1. 真实文件库的历史日 `2025-12-31`，从主页 → 摘要 → 对应日复盘 → 新建表单，只填下一步即保存成功。该日剩余 1380 分钟 Gap，无 Goal，概述 / 反思为空；原记录已有接续点，下一步输入仍初始为空。读回显示 `2026-01-01`，返回摘要后可以再次读回已有内容。
2. 从该历史日的日账本进入已有复盘，默认读回并按原身份更正。迁移到 `2026-01-01` 后保留 id / createdAt，读回下一自然日 `2026-01-02`；来源账本仍是 `2025-12-31`，旧日入口显示无复盘，新日入口显示同一份已存行动。
3. 从新日入口明确删除后，读取页、返回账本后重新进入和新建表单均没有被删文字，不复活旧编辑输入。四张非复盘正式表的完整快照保持原值。
4. 时间轴“接续点”和复盘“明天第一步”分别读到不同原始文字。已有复盘引用的归档 Goal 可以读回 / 打开编辑；Goal 改名后显示当前名称和归档标识，复盘 SQL 行保持完全不变。
5. 使用实际 app 装配的原事实编辑路由，在复盘之上更正原 TimeBlock 的结束时间及接续点；返回复盘自动刷新，已交代由 60 变为 120 分钟，Gap 由 1380 变为 1320 分钟。返回来源账本、再从摘要进入均读到新事实；概述、反思、下一步及整行 daily_reviews 原值不变，另一真实 SQLite 连接也读到同样的已存文字。
6. 摘要和账本两条当前日入口分别验证：无效日期不能打开；事实读取失败后仍能用有效所选日进入独立读取的复盘；时钟从 `2026-10-02` 越过午夜后，点击仍传递页面所选 `2026-10-02`，保存的复盘日期不自动换日，下一自然日为 `2026-10-03`。同一帧两次回调只有一个复盘路由。返回跟随今天的来源页刷新到新日，新日无复盘，明确选择旧日可读回原行动。

新增测试的初轮编译发现 CivilDate 使用了不适用的 const，已改为 final；随后一项夹具重挂载时错误地保留了“跟随今天”，已让其从实际历史入口装配后再验证路由返回。修正均只涉及新增测试；最终 4 项及相关回归全部通过。回归实际日志：`/tmp/e9-t07-regression.log`。

回归运行时没有显式设置 TZ，本机本地时间为 CST。5 项 skip 是已有 device_recording_date_test 的 2 项显式时区条件、day_ledger_timeline_test 的 1 项显式时区条件、day_ledger_resolution_flow_test 的 23 / 25 小时条件场景；未计为通过。未改日期解析或 DST 计算。

## Self-review / Scope

检查相对执行前备份的 3 个生产文件完整差异和新增未跟踪测试 / 报告。执行前 378 个文件的 SHA-256 对照，仅本任务所列 3 个生产文件与 3 个状态文档改变；其他既有修改和未跟踪内容保留。新增 1 个测试文件及本报告。

未修改其他任务报告、pubspec、domain、application、repository、schema 或未决问题。没有提醒、打卡、行动完成状态、每 Goal 计划或自动接续点搬运。Task 原定义完整归档，仅补完成状态及报告；Epic 9 仍待 E9-T08 / E9-T09 验收。

## Blockers / Open Questions

无 blocker，无新增产品问题。当前 Task 的共用代码、真实 SQLite 和 widget 路由验证完成。未执行 Android 关闭重开或 Web 同源刷新验收；widget 路由、模拟午夜和第二数据库连接读回不作为平台生命周期证据。两平台恢复按 E9-T09 执行。

## Next executable task

E9-T08 — 验证复盘完整应用闭环与失败恢复。仅报告，未执行；E9-T07 完成后停止。
