# E9-T05 — 接通复盘原地更正与日期变更

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T05，完成后停止。

## 前置与依据

核对 AGENTS、Task 完整定义、SOT / §21–22、OQ、MVP、PLAN、STATES / 通用更正及 DailyReview、DATA / daily_reviews 和独立草稿、RULES / DR-001–DR-004、MODEL / DailyReview 与 TomorrowFirstStep，以及 APP / 依赖方向、写入与装配流程。

直接依赖 [E9-T04 报告](E9-T04_REVIEW_SUBMISSION_REPORT.md)及其归档定义 / 实现齐备。E1-T12 的完整归档定义、纯更正实现与测试已核对，完成状态由 [Epic 0 / 1 负责人确认](EPIC_0_1_COMPLETION.md)覆盖，不补造历史日志。另核对既有 [E2-T07 repository 完成报告](E2-T07_REVIEW_REPOSITORY_REPORT.md)与真实库更正合同测试。

Q-001、Q-006、Q-012、Q-013、Q-018 均 DECIDED，职责规范已同步：下一自然日随复盘日期派生；保留已有归档 Goal 合法，新关联需当前有效；草稿独立并在失败时保留；更正保留身份，缺失源不重建；只有实际变化成功保存才更新 updatedAt。继承 Q-015 文本规则及 E1-T07 的长度补充，没有新增产品决定。

按 AGENTS 委派 code_mapper 有界只读定位 update、Goal 引用与表单 / app 调用。主 agent 检查其路径证据；实现、集成、自检与最终验证由主 agent 执行。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/application/review_entry_saver.dart` | 编辑快照按源 reviewId 调用既有 update；明确传递可选字段保留值 / 清空；映射缺失源失败，复用提交后收尾 |
| `lib/features/review/presentation/review_form_controller.dart` | 开放编辑提交，复用最新草稿排空、提交锁与失败保留；显示原复盘不存在的反馈 |
| `lib/features/review/presentation/review_form.dart` | 编辑入口显示“保存更正”，复用已提交状态、冻结输入和收尾重试 |
| `test/features/review/application/review_correction_saver_test.dart` | 9 项真实正式文件库 / 草稿文件、冲突、元数据、引用、清空、缺失源、故障、恢复和重复操作测试 |
| `test/app/review_correction_flow_test.dart` | 3 项实际 bootstrap / 表单交互、改日期回看、无变化保存、冲突 / 缺失源及收尾失败测试 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | T05 状态、原定义归档与完成依据 |

- 草稿是完整快照。编辑提交使用 context.reviewId，日期、下一步和当前可选值直接传递；summary / reflection / Goal 使用 `(value: ...)` 表达当前值，null 明确清空，不因缺省参数回填旧值。仍先保留最新完整草稿并等待已接受的写入。
- 复用 ReviewRepository.update 的既有事务，按当前库读取源身份、占用日期和 Goal；correctDailyReview 保留 id / createdAt，规范化后内容不变时不执行 SQL UPDATE，也不改变 updatedAt。没有复制更正规则或新增 upsert。
- 改日期仍为同一条复盘，旧日期查询为空，新日期读到原 ID；intendedDate 随新 CivilDate 的下一自然日派生。复用 T04 已有路由返回值，成功回看实际已存日期。
- 日期占用、无效 Goal、文本错误及存储故障保留输入和对应编辑草稿，不留下部分修改。原 ID 已删除时明确反馈“原复盘已不存在”，不调用 create，也不把同日另一条记录作为源对象。
- 已有归档 Goal 可保留；新的归属按提交时当前状态重新校验，选择后归档或删除均拒绝。概述 / 反思和 Goal 可明确清空，下一步仍需非空白；不要求补齐 Gap、先看统计或填写可选解释。
- 编辑使用同一提交锁，重复点击不会并发 update。正式更正成功后只清源 ID 的编辑草稿并重读；清理 / 重读失败进入已提交状态、冻结输入，重试只调用既有 finishCommitted，不再次 update 或 create，也不改变正式时间戳。
- 原有编辑草稿恢复完整快照，正式保存前原复盘不变。本次未改变草稿 schema、领域模型、正式 repository 或 app 装配；未接通 E9-T06 删除功能。

## Validation

在仓库根目录使用已有 Flutter / Dart 与缓存依赖。以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format`（上述 3 个生产文件与 2 个测试文件） | 通过 |
| `dart format --output=none --set-exit-if-changed`（同上 5 个文件） | 5 files，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/application/review_correction_saver_test.dart test/app/review_correction_flow_test.dart` | 12 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 649 项通过，3 项既有条件跳过 |
| `git diff --check`、新增文件空白检查、执行前 SHA-256 对照、原定义归档和文档链接检查 | 通过 |

验收证据：

1. 真实正式文件库将历史复盘移至 2024-02-29，保留源 ID / createdAt，更新实际变化时间，下一自然日为 2024-03-01；旧日期为空、新日期同一 ID。清理只影响该编辑键，另一编辑草稿与新建草稿保留；daily_reviews 仍为既有 8 列，没有 intendedDate 或统计列。
2. 真实 SQLite BEFORE UPDATE 的拒绝触发器证明规范化后的无变化保存不发出 SQL UPDATE，updatedAt 保持原值；实际 bootstrap 更正成功后再次无变化保存同样保留时间戳。
3. 打开编辑后另一个写入占用目标日期，整次更正拒绝，两个正式复盘及时间戳均不变，草稿保留改后的日期、空字段和原始文字。应用反馈明确未覆盖，页面仍可修正。
4. 真实库保留原归档 Goal 合法；新关联的 Goal 在选择后归档 / 删除均拒绝，正式值不变。成功明确清空概述、反思及 Goal。空白下一步以及三个字段各自 2,001 emoji 码点均拒绝，未截断或清除原始草稿。
5. 源记录在读取后被删除，且原日期被另一 ID 占用时，按旧源 ID 更正返回缺失源；不修改替代复盘、不新建、不生成 ID。widget 验证提示、输入保留与返回后当前日期读取一致。
6. SQLite AFTER UPDATE 的 RAISE(FAIL) 验证正式事务回滚，日期与全部原文保持原值，草稿保留；恢复存储后用户重试修改同一 ID，只有一行。
7. 正式文件和草稿文件实际关闭 / 重开，按原 ID 恢复改日期、清空可选文字与原始下一步；提交前原正式反思不变，明确保存后新日期读到同一身份。实际 app 入口也恢复清空输入和原归档 Goal，并成功回看新日期。
8. 延迟 update 的 controller 测试与同一帧两次点击的 widget 测试覆盖提交锁。SQLite 草稿 AFTER DELETE 清理故障及读取异常分别重试，正式 update 计数始终为 1、create 为 0，ID / createdAt / 已提交 updatedAt 保持不变。

首轮新增应用层 8 项测试和 widget 3 项测试均通过；补充编辑文本失败测试后，最终 12 项定向及相关回归全部通过。静态分析首轮和最终均无问题。3 项 skip 是上海时区下既有 sleep_ledger_loader_test 的纽约 DST 条件测试，以及 day_ledger_resolution_flow_test 的 23 / 25 小时条件场景，未计为通过。本次未改变自然日投影。

日志：`/tmp/e9-t05-unit-initial.log`、`/tmp/e9-t05-widget-initial.log`、`/tmp/e9-t05-target-final.log`、`/tmp/e9-t05-analyze-final.log`、`/tmp/e9-t05-regression.log`。

## Self-review / Scope

检查相对执行前备份的全部生产差异及新增未跟踪测试文件。执行前 372 个既有文件 SHA-256 对照，仅本任务所列 3 个生产文件及 3 个任务状态文档改变；其他既有修改和未跟踪内容均保留。新增 2 个测试文件与本报告；未修改其他任务报告、pubspec、schema、纯领域、更正持久化实现或已决问题，未新增依赖。

编辑分支复用既有更正合同及 T04 的提交 / 收尾状态，没有引入另一套统计、历史版本、自动覆盖或缺失源重建。当前 Task 原定义保持不变归档，仅增加完成状态与报告链接；Epic 9 尚未整体验收。

## Blockers / Open Questions

无 blocker，无新增产品问题。当前 Task 的共用代码、真实文件库及 widget 验证完成。未执行 Android 实际关闭重开或 Web 同源刷新验收；文件重开和界面交互不作为平台生命周期证据，实际两平台恢复仍由 E9-T09 交付。

## Next executable task

E9-T06 — 接通复盘删除与返回读取。前置 E9-T05 已完成，Q-012、Q-013 已决。仅报告，未执行；E9-T05 完成后停止。
