# E9-T08 — 验证复盘完整应用闭环与失败恢复

**Task / Status：E9-T08 / COMPLETE（2026-10-03，Asia/Shanghai）。** 本次仅执行 E9-T08，完成后停止；未执行 E9-T09 或 Epic 10。

## 依据与前置

核对 AGENTS、Task 完整定义、共同必读 SOT / OQ / MVP / PLAN，以及 MVP 的 M-06 / M-07 与闭环验收、PLAN / Epic 9、DATA / daily_reviews 与独立草稿。按职责核对 MODEL / DailyReview 与 TomorrowFirstStep、RULES / DR-001–DR-004 与 MODEL-002、STATES / 通用更正及 DailyReview、APP / 一致读取与写入后重读。

直接依赖的原归档定义、[E9-T07 回看路由报告](E9-T07_REVIEW_ROUTE_REPORT.md)、[E7-T06 目标节奏闭环报告](E7-T06_GOAL_RHYTHM_CLOSURE_REPORT.md)、[E8-T05 摘要重算报告](E8-T05_SUMMARY_RECALCULATION_REPORT.md) 及实际装配 / 测试均有完成证据。Q-001、Q-006、Q-008、Q-012、Q-013、Q-015、Q-018 均 DECIDED，相关规范一致；没有新增产品决定或用测试固化未决答案。

按 AGENTS 委派 code_mapper 只读核对现有 review 测试的覆盖和夹具。主 agent 检查对应实现与证据后，选择三个跨步骤组合场景；没有重复全套前序测试。当前生产实现满足本任务的组合合同，未发现需修复的缺陷。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [review_closure_flow_test.dart](../../test/app/review_closure_flow_test.dart) | 3 项真实 AppBootstrap / widget / 文件 SQLite 组合闭环测试，包含第二正式库连接、故障注入、完整卸载 / 文件重开及 SQL 写入审计 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 原定义归档、完成索引、进度与逐项验收依据 |

正式库、复盘草稿、普通记录草稿分别使用临时 SQLite 文件。所有正式约束、事务和 repository 操作均真实执行；故障由测试库中的 SQLite 触发器和窗口查询拦截器注入，没有 mock 正式约束、正式写入结果或投影。

AppBootstrap、ReviewContextPage、ReviewForm、ReviewEntrySaver 与 repositories 使用现有生产装配。完整重开时卸载 widget 树、关闭连接，再打开原文件并重新创建 bootstrap / repositories / controllers；只有测试时钟、故障设置和 SQL 审计计数保留。睡眠首次确认夹具沿用“今日已确认”，不改睡眠产品流程。

### 组合 1：完整字段、失败保留、更正与删除

- 真实历史日 `2024-02-28` 包含近似跨日主睡眠、关联 Goal 的 progress TimeBlock / 接续点和无 Goal 的 Unknown。从主页 → 基础摘要 → 该日复盘 → 表单，Unknown 为 30 分钟，仍留 930 分钟 Gap；下一步初始为空。
- 同时填写 summary、reflection、下一步及 Goal。2,001 个非 BMP 字符的下一步不能正式保存；离页后五张正式表全行不变，完整文件重开后原始空白、内部格式和超长内容恢复。
- 用真实草稿 `AFTER UPDATE` 触发器中止自动保留：磁盘保留旧的 2,001 字符输入，内存保留修正后的 2,000 字符输入；提交被阻止，没有正式 INSERT。解除故障并明确重试草稿后，继续按当前 Goal 状态校验。
- 表单所选 Goal 后来归档，正式保存被拒绝且原始草稿保留。重新读取目标、明确改选活跃 Goal 后保存成功。正式复盘清理首尾空白、保留内部格式，合法保存 2,000 个 Unicode 码点；草稿按入口键清除。
- 已保存的原 Goal 后来归档，读回标识正确。按原 ID 编辑、更正日期到 `2024-03-01`、清空 summary 并修改 reflection / 下一步，允许保留原归档引用；id / createdAt 不变，旧日查询为空，下一自然日为 `2024-03-02`。
- 从新日期日账本回看后明确删除。TimeBlock、SleepSession、RhythmAnnotation 完整 SQL 行不变；源编辑草稿清除，其他日期的未完成草稿仍保留。该闭环只有一次成功创建、一次更正、一次删除。

### 组合 2：正式提交后双故障与跨重开恢复

- 从 `2024-02-28` 的新建入口把复盘日期改为闰日 `2024-02-29`，填写全部文字及 Goal。正式 INSERT 成功后，独立草稿 DELETE 触发器失败，目标日事实读取也失败。
- UI 明确“复盘已保存，但草稿清理和读回失败”，移除再次保存入口；故障期间收尾重试不再 INSERT / UPDATE。返回读回页显示读取失败，不显示无复盘或成功旧快照。
- 在故障仍存在、原 Goal 已归档、注入时钟跨午夜后，卸载整个 app 并重开正式 / 草稿文件。从原新建入口恢复其改后日期草稿，识别为已提交记录，冻结旧输入；intendedDate 仍为 `2024-03-01`。跨重开 SQL 审计始终只有一次正式 INSERT，正式复盘全行保持原值。
- 先恢复清理、保留读故障：收尾清除该入口草稿但继续报告读回失败。再恢复读取：仅重读，返回正确闰日内容及归档 Goal。创建计数仍为 1，更正计数为 0。
- 恢复后明确更正文字、删除，再重开文件并从该日日账本进入，仍无复盘。原时间事实和无关日期草稿保留；最终审计为一次创建、一次更正、一次删除。

### 组合 3：另一连接抢占日期与源身份过期

- 在新建表单读取后，另一真实 SQLite 连接用正式 repository 抢占所选闰日。保存被当前唯一合同拒绝，不覆盖竞争者；正式五表快照保持，完整原始草稿保留。
- 完整重开后，从原入口恢复草稿。因内容与竞争者不同，不把竞争者误认成该草稿已提交；仍提供新建保存，重新提交仍被唯一性拒绝。
- 用户明确改到空日期 `2024-03-01` 后，以真实 `AFTER INSERT` 故障中止正式写入。UI 不显示成功，正式表全行仍不变，输入和改后日期草稿保留；解除故障后同页重试保存成功。
- 编辑该新记录时，另一连接删除源 ID 并在同日创建另一 ID。旧编辑的更正提示源已不存在，不更新替代者、不重新创建；旧 ID 草稿按身份保留。
- 返回读回当前替代复盘；完整重开后打开它的编辑页，只读入替代 ID / 文字，不串用旧 ID 的编辑草稿。竞争者日期、替代复盘及时间事实全行保持；成功 INSERT 仅竞争者、用户记录、替代者三次，过期编辑没有 UPDATE。

## 核心验收对照

| 核心要求 | 本次证据 |
| --- | --- |
| 事实 / 摘要 → 草稿 → 提交 → 更正日期 / 内容 → 回看 / 删除 | 组合 1，实际 UI 全链路；组合 2 从双故障恢复后继续更正 / 删除 |
| 可选 summary / reflection、一个下一步、可选 Goal，允许 Gap | 组合 1 的完整字段及清空可选文字；E9-T07 同批验证的仅下一步 / 无 Goal / 留 Gap 路由场景 |
| 接续点与明天第一步独立，不自动评价 | 原事实接续点存在时表单下一步仍为空；已存复盘文字只来自用户输入；无新增自动评价功能。E9-T07 同批验证分别显示两个来源 |
| 不持久化摘要、不让草稿成为事实 | 组合 1 离页 / 重开前后正式五表相同；daily_reviews 严格核对既有 8 列，没有统计、intendedDate、状态或投影字段；三个组合中时间事实全行保留 |
| 每日唯一、失败不覆盖 | 组合 3 的独立连接抢占、重开后再次拒绝及竞争者全行保持 |
| 原归档引用保留、新关联按当前状态验证 | 组合 1 的选后归档拒绝、原引用归档后更正保留；组合 2 提交后归档仍可恢复读回 |
| 正式 / 草稿写入失败保留 | 组合 1 草稿写故障阻止正式提交并保留内存 / 磁盘各自输入；组合 3 正式写失败全表回滚并保留草稿 |
| 提交成功后的清理 / 读取失败安全恢复 | 组合 2 双故障、返回读取失败、完整文件重开、逐项修复后仅收尾，SQL 审计无重复创建 |
| 过期编辑按源身份拒绝、不重建或换对象 | 组合 3 原 ID 删除、同日另一 ID 替代、跨重开草稿隔离 |
| 文本边界与跨自然日 | 组合 1 的 2,001 拒绝 / 2,000 合法 Unicode 码点、规范化与原始草稿；闰日 / 跨月与组合 2 午夜后的历史 CivilDate 保持；E9-T07 同批验证年边界 |
| 事实 / Goal 变化不改写复盘 | 组合 2 归档前后正式复盘整行不变；E9-T07 与 E8-T05 同批验证实际事实更正后重算、复盘原文不变 |

## Validation

仓库根目录使用已有 SDK 与缓存依赖，以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format test/app/review_closure_flow_test.dart` | 1 文件格式化通过 |
| `dart format --output=none --set-exit-if-changed test/app/review_closure_flow_test.dart` | 1 file，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/review_closure_flow_test.dart` | 3 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/review_closure_flow_test.dart test/app/review_route_flow_test.dart test/app/goal_rhythm_closure_test.dart test/app/day_summary_recalculation_flow_test.dart` | 12 项通过，无跳过；含本次 3 项及直接依赖的 9 项闭环 / 路由测试 |
| `git diff --check`、新增文件空白、自审增量、执行前 SHA-256 对照、原定义归档 / 后续任务 / 链接检查 | 通过 |

初轮 2 项通过，1 项因新增测试使用了错误按钮文字“重试提交收尾”而无法定位；按实际生产控件“重试复盘收尾”修正测试，并补入草稿写故障组合后，3 项及上述定向回归均通过。未修改生产行为、放宽约束或掩盖读取失败。

实际日志：`/tmp/e9-t08-target-initial.log`、`/tmp/e9-t08-target-second.log`、`/tmp/e9-t08-analyze-final.log`、`/tmp/e9-t08-regression.log`。本任务没有重跑前序全部测试，未将历史报告中的测试数量计入本次结果。

## Self-review / Scope

检查新增测试全文、生产调用路径、独立文件与实际约束、失败注入时点、SQL 审计、原身份与元数据、草稿内容和清理键、关闭 / 重开及核心验收对照。执行前 380 个文件的 SHA-256 对照，仅完成状态相关的三份文档改变；其他既有已跟踪及未跟踪文件原样保留。新增一个测试文件及本报告。

未修改任何生产代码、domain、schema、依赖、生成文件、平台驱动、其他任务报告或已决问题。Task 原定义完整归档，只增加 COMPLETE 与报告链接。Epic 9 尚待 E9-T09 两平台验收，未标记整体验收完成。

## Blockers / Open Questions / Limitations

无 blocker，无新增未决问题。本次是 Flutter widget + 真实 Native SQLite 文件和完整 bootstrap 重开验证；没有执行 Android 实际关闭重开、Web 同源刷新或系统时区切换，不将文件重开外推为平台生命周期证据。两平台正式保存与草稿恢复按 E9-T09 取得证据。

## Next executable task

**E9-T09 — 验证 Android 与 Web 复盘保存和恢复。** E9-T08 已完成，E7-T07、E8-T06 已有两平台完成依据；仅报告，不执行。E9-T08 完成后停止。
