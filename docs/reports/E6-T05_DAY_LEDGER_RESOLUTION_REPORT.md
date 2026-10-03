# E6-T05 — 验证时间轴与补账完整应用闭环

**Task / Status：E6-T05 / COMPLETE（2026-10-01）。**

## 依据与前置

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 DERIVED 的可核对关系、窗口、切片、睡眠摘要与独立近似示例。核对 [E6-T03](E6-T03_GAP_RECORDING_REPORT.md)、[E6-T04](E6-T04_TIMELINE_EDITING_REPORT.md)、[E4-T07](E4-T07_BASIC_RECORDING_FLOW_REPORT.md)、[E5-T07](E5-T07_SLEEP_RECORDING_FLOW_REPORT.md) 的归档定义、报告和现有应用 / 测试实现。相关 Q-008–Q-014、Q-017、Q-018、Q-021、Q-023 均为 DECIDED，无来源冲突或新的产品 blocker。

按 AGENTS 委派 code_mapper 有界只读定位既有闭环测试、实际 app 入口及覆盖缺口；主 agent 核对证据后负责测试实现、自审与验证。已有分项测试保留，本轮新增同一真实应用中串联全部操作的证据。

## Changes

| 文件 | 本轮职责 |
| --- | --- |
| [day_ledger_resolution_flow_test.dart](../../test/app/day_ledger_resolution_flow_test.dart) | 新增 4 个场景：完整时间轴补账闭环；冲突手动修正、提交后读取重试与日期上下文；23 小时与 25 小时历史日的实际补账。 |
| [TASKS](../../TASKS.md)、[COMPLETED_TASKS](../planning/COMPLETED_TASKS.md) | 完成索引、完整任务定义归档，保留原 Task 锚点。 |
| 本报告 | 验收证据、验证结果与平台限制。 |

未发现需要修复的生产实现缺陷；未改生产代码、领域规范、正式 / 草稿 schema、依赖或平台配置。

## Acceptance evidence

1. **同一实际应用串联睡眠、known、Unknown、更正与删除。** 从首次主睡眠确认表单保存前日 23:50–当天 07:40 的完整事实，入睡近似、醒来准确；醒来日截至 12:00 的切片贡献 460 分钟且准确，完整主睡眠摘要约 470 分钟。点击尾部 Gap，保留近似建议并填 known 到 09:00；再将部分 Gap 明确确认为无标题 Unknown 到 10:00，保留 10:00–12:00 未解决 Gap。Unknown 保存前离开仅保留草稿，正式覆盖不变；恢复后保存，accounted=600 分钟、unknown=60 分钟、unresolved=120 分钟，Unknown 未重复相加。界面同时显示已知、未知和尚未记录。
2. **首尾 / 中间 Gap 随当前事实重算。** 将 known 结束时间更正为 08:30 后，中间产生 08:30–09:00 Gap，尾部 Gap 仍保留。删除 Unknown 后两段剩余空白重算为 08:30–12:00；删除完整睡眠后再出现 00:00–07:40 的头部 Gap。更正仍为同一身份且 createdAt 保留，最后仅有一条 known。关闭本机连接并重开文件数据库 / app 后，时间轴仍由这条正式事实重新派生，原行内容保持一致。
3. **失败不成为 Unknown，提交后重试不重复写入。** 草稿形成后，真实 repository 加入竞争小睡；提交原子冲突失败，正式五表逐行不变，输入 / 草稿保留，没有新块。用户在同一表单手动把结束时间改为与小睡起点相接的 09:00。正式写入提交后才注入读取失败，表单明确显示已保存并移除再次提交按钮；故障期间及恢复后的“继续清理并刷新”只做收尾，INSERT 总计一次，草稿清除。完整日投影读回正确，Unknown 为 0。
4. **显式 now、未来与历史窗口。** 将注入时刻从 12:00 改为 13:00 并刷新，仅尾部 Gap 扩展到 13:00；选择未来日期得到空窗口，无 Gap 或补账入口。重访前一历史日展示完整日窗口，跨日睡眠贡献 10 分钟，完整摘要不归入前日。
5. **实际 23 / 25 小时日。** 在纽约设备进程时区下，2026-03-08 和 2026-11-01 分别按当地相邻零点取得 23 / 25 小时历史窗口。从全空 Gap 补 known 00:00–04:00，实际时长分别 3 / 5 小时；相接再补 Unknown 04:00–05:00，保留 05:00–次日零点 Gap。最终两种窗口分别已交代 4 / 6 小时、Unknown 1 小时、未解决 19 小时，均使用真实 app、设备日期适配和正式 SQLite，不使用固定 1440 分钟。

每个时间轴检查点都断言相同窗口下 `accounted + unresolved = window`、`0 ≤ unknown ≤ accounted`、全部主要事实切片时长之和等于 accounted，以及 UI 事实 / Gap 数量、边界和“尚未记录”标签。Unknown 是 accounted 的子集。正式库始终仅五张事实表；检查无 Day、Gap、统计或聚合表，正常闭环不产生 Goal / annotation / review 数据。草稿连接独立于正式库。

## Validation

在工程根目录使用现有环境执行：

| 实际命令 | 结果 |
| --- | --- |
| `dart format test/app/day_ledger_resolution_flow_test.dart` | 退出 0。 |
| `dart format --output=none --set-exit-if-changed test/app/day_ledger_resolution_flow_test.dart` | 退出 0，1 文件、0 changed。 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found。 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_resolution_flow_test.dart` | 退出 0，2 项通过、2 项 DST 场景按时区条件跳过。 |
| `TZ=America/New_York flutter test --no-pub test/app/day_ledger_resolution_flow_test.dart test/app/time/device_recording_date_test.dart` | 退出 0，8 项全部通过，包含上述 2 个 DST 场景及前序纽约日期定向测试。 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，491 项通过、3 项时区专用场景跳过；这些场景已在上一条纽约命令中执行通过。 |
| `git diff --check`、Task 状态 / 归档和文档链接、任务开始前 SHA-256 对照 | 通过。 |

正式库、普通草稿、睡眠草稿和首次打开标记均为真实 Native SQLite 文件。正式写入、冲突检查及投影均执行现有代码；测试拦截器只在成功提交后使读取失败，不替代 repository、投影或正式结果。目录 / 文件 I/O 在 tester.runAsync 中执行，连接由现有 app 生命周期和测试收尾释放。

初轮测试缺少 Drift 的 ApplyInterceptor 扩展导入；known 夹具最初只填写标题，没有明确选择认知状态，合法校验阻止了提交。补上扩展导入和实际“记得做了什么”交互后重跑通过，未为错误夹具改变产品行为。短暂诊断时的语法错误已修正，诊断输出已移除。最终定向测试没有 Drift 多实例警告；全量测试有 6 条前序多连接测试的同类调试提示，无测试失败或新增静态问题。

日志：`/tmp/e6_t05_target.log`、`/tmp/e6_t05_ny.log`、`/tmp/e6_t05_analyze.log`、`/tmp/e6_t05_all.log`（本机临时验证日志）。

## Self-review

已检查新增测试全文：实际入口、显式认知选择、日期与时间上下文、原始完整睡眠、独立近似、草稿与事实分离、失败触发时点、五表快照、写入次数、同窗关系、非 24 小时边界和连接重开。测试复用现有交互 helpers，不重写投影计算，不替代前序单元测试。

对照任务开始前 SHA-256，既有文件仅改变 TASKS 和 COMPLETED_TASKS；生产代码、已有测试、PLAN、领域文档、pubspec / lockfile 及平台配置均保持原样，工作区已有修改与未跟踪文件保留。E6-T06 保持 NOT STARTED，未标记 Epic 6 或全 MVP 整体完成。

## Blockers / Open Questions

无。未执行 Android 实际关闭重开 / Web 实际刷新或运行中系统时区切换；本机文件重开与真实 TZ 进程测试不视为两平台验收。平台闭环留 E6-T06。

## Next executable task

E6-T06 — 验证 Android 与 Web 时间轴补账集成。未执行；本次完成 E6-T05 后停止。
