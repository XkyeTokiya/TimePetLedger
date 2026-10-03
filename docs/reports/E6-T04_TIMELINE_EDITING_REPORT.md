# E6-T04 — 接通时间轴原事实更正与删除

**Task / Status：E6-T04 / COMPLETE（2026-10-01）。**

## 依据与依赖

已核对 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 STATES 的通用更正删除、TimeBlock 字段策略、SleepSession；APP 的调用流程、写入后重读与 UI state；DERIVED 的 segments / 源事实边界。Q-003、Q-013、Q-018 均为 DECIDED，无来源冲突或新增产品问题。

直接依赖 [E6-T02](E6-T02_DAY_LEDGER_TIMELINE_REPORT.md)、[E6-T03](E6-T03_GAP_RECORDING_REPORT.md)、[E4-T06](E4-T06_TIME_BLOCK_CORRECTION_REPORT.md)、[E5-T05](E5-T05_SLEEP_CORRECTION_REPORT.md) 的归档定义、报告和现有实现均已检查。按 AGENTS 委派 code_mapper 做有界只读定位；主 agent 检查事实身份、完整加载及提交后收尾证据后完成实现与验证。

## Changes

| 文件 | 本轮职责 |
| --- | --- |
| [day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) | 事实切片可点击进入完整编辑器；提供明确的更正入口和普通事实删除入口，保留带类型的身份及切片显示。 |
| [day_ledger_page.dart](../../lib/features/ledger/presentation/day_ledger_page.dart) | 传递当前日与原事实身份，防止重复打开；普通事实删除需确认，复用既有 editor 原子删除及收尾重试；返回 / 删除后重读完整日投影，独立呈现读取失败。 |
| [main_app.dart](../../lib/app/main_app.dart) | 按 TimeBlockSegment / SleepSessionSegment 分别组装既有 RecordingForm / SleepEntry，并注入已有 RecordingEntryEditor。 |
| [day_ledger_editing_flow_test.dart](../../test/app/day_ledger_editing_flow_test.dart) | 5 项真实 SQLite + widget 场景，验证两日同源编辑、双向认知更正、跨类型同 id、醒来日迁移、删除、冲突、缺失源事实与收尾失败。 |
| TASKS、COMPLETED_TASKS、本报告 | 记录完成状态、归档完整定义与实际验证证据。 |

两个编辑器按 id 重新加载完整源事实，不使用切片边界生成新记录。普通记录的已归档 Goal、category 和 annotation 保留；note、独立精度与 id / createdAt 保留，无变化保存不更新 updatedAt。睡眠删除使用原编辑器内的确认流程。删除 TimeBlock 原子移除附属解释，复盘保持原状。

页面只将编辑器返回的非空结果作为提交完成提示，不把局部 RecordingLedger / SleepLedger 赋给完整日投影。取消 / 返回也取得新的时间上下文并重新读取。更正移出当前窗口或迁移醒来日期后，重新访问旧 / 新日期均从当前正式事实读取，不维护日缓存。

普通记录删除失败保留原事实并显示失败；提交后草稿清理或局部读取失败保留收尾状态，重试只调用 finishDelete，不再次 delete。期间禁用新的事实操作，避免覆盖待收尾结果。完整日读取失败另有“重试读取”，不撤销提交成功反馈、不显示旧切片。

未新增领域行为、schema、依赖、投影算法、Goal / annotation 编辑 UI、历史版本或复盘自动改写。

## Validation

在工程根目录使用现有环境执行：

| 命令 | 结果 |
| --- | --- |
| `dart format lib/app/main_app.dart lib/features/ledger/presentation/day_ledger_page.dart lib/features/ledger/presentation/day_ledger_timeline.dart test/app/day_ledger_editing_flow_test.dart`（分批） | 退出 0。 |
| 相同 4 文件运行 `dart format --output=none --set-exit-if-changed` | 退出 0，0 changed。 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found。 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_editing_flow_test.dart` | 退出 0，5 项通过；最终额外睡眠冲突检查包含在下列回归中。 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time` | 退出 0，406 项通过、1 项纽约时区专用测试跳过。 |
| `TZ=America/New_York flutter test --no-pub test/app/day_ledger_editing_flow_test.dart test/app/time/device_recording_date_test.dart` | 退出 0，9 项通过，无跳过。 |
| `git diff --check`、文档链接 / Task 状态核对、既有文件 SHA-256 对照 | 通过。 |

新增测试使用真实正式库、独立草稿库和原应用组装；删除 / 更正失败注入使用 SQLite 触发器或读取 / 清理边界。测试审计触发器确认已提交更正与删除的收尾重试没有再次执行正式写入。两个类型使用相同 id 验证路由不混淆。覆盖 TimeBlock known↔unknown、原始跨日区间、移出窗口、未展示字段、解释删除与复盘保留；SleepSession 从两日访问同一完整源、类型和醒来日期迁移、note / 精度保留、删除后旧 / 新窗口及摘要重读；两类编辑冲突、缺失源事实和保留草稿。

初次运行发现测试复盘夹具误用数据库列名，改为现有 DriftReviewRepository 后通过；首轮静态分析的大括号与尚未使用的测试 import 已在最终版本消除。测试中并行打开的睡眠草稿库均为独立 NativeDatabase.memory executor，仅关闭 Drift 同类多实例调试提示并在测试结束恢复该设置。没有将初轮失败记录为通过。

## Self-review

已检查三个生产文件相对任务开始前副本的 diff、新建测试、完整源加载和返回结果类型、提交 / 读取失败区分、删除在途及待收尾操作锁、日期切换和草稿上下文。对照开始前 SHA-256：除本轮三个生产文件与任务索引 / 归档外，既有代码、测试、领域文档、PLAN、pubspec / lockfile、生成文件及平台文件保持原样。工作区原有修改与未跟踪文件保留。修复完成索引中既有多余空行，使 E6-T03 / E6-T04 处于同一表格。

## Blockers / Open Questions

无。未执行 Android / Web 设备端操作或平台关闭 / 刷新恢复，不将真实 Native SQLite 与 TZ 进程测试记为平台验收；两平台新增路由验证留 E6-T06。

## Next executable task

E6-T05 — 验证时间轴与补账完整应用闭环。未执行；本次完成 E6-T04 后停止。
