# E5-T07 — 验证睡眠记录应用闭环

## Task / Status

**E5-T07 / COMPLETE，2026-09-30。** 本轮只执行 E5-T07，未开始 E5-T08。

已阅读 AGENTS、Task 全文、共同必读 SOT / OQ / MVP / PLAN，以及 DERIVED 的 sleepSummary / hasApproximation；结合 RULES 的 SL / LEDGER-004、DATA 原子写入和 APP 失败处理核对调用。核对 [E5-T05](E5-T05_SLEEP_CORRECTION_REPORT.md)、[E5-T06](E5-T06_FIRST_SLEEP_CONFIRMATION_REPORT.md) 的完成证据与实际实现，并检查前序保存 / 投影测试。相关 Q-008 / Q-009 / Q-010 / Q-011 / Q-012 / Q-014 / Q-017 / Q-018 / Q-021 均为 DECIDED，未发现来源冲突或新的产品阻塞。

按 AGENTS 委派 code_mapper 有界只读定位现有睡眠 app 测试、bootstrap 组装及故障注入边界；主 agent 检查证据并负责测试实现、自审和最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [sleep_recording_flow_test.dart](../../test/app/sleep_recording_flow_test.dart) | 4 项真实文件 SQLite + 实际 AppBootstrap / 页面交互的闭环测试 |
| [TASKS](../../TASKS.md)、[COMPLETED_TASKS](../planning/COMPLETED_TASKS.md) | E5-T07 完成索引、完整定义归档，保留原锚点 |
| 本报告 | 验收证据、失败修正与限制 |

没有发现需要修复的生产实现缺陷。未改生产代码、正式或草稿 schema、依赖、生成代码、领域规范或平台配置。

## Acceptance evidence

1. **实际首次入口 → 草稿 → 恢复 → 正式保存 → 读回 → 更正 / 删除。** 从“确认主睡眠”进入现有表单，填写 23:50–次日 07:40、入睡近似 / 醒来准确，保留草稿后正式库仍为空，摘要仍缺失、覆盖仍为 0；重新进入恢复输入并保存。正式库只保存一条完整 SleepSession。醒来日主睡眠摘要为约 470 分钟（7h50m），日覆盖为准确 460 分钟（7h40m），待补记准确 260 分钟；前一日覆盖约 10 分钟而主睡眠摘要缺失。新建第二段主睡眠及结束近似的小睡后，主睡眠分别列出并汇总约 530 分钟，小睡单列约 20 分钟，覆盖 / 待补记分别约 540 / 180 分钟。更正前原事实不变，更正保留 id / createdAt；依次删除后汇总、覆盖和缺失表达同步更新。
2. **午夜醒来不被窗口切片遗漏。** 前日 23:00–当天 00:00 的主睡眠在醒来日摘要有约 60 分钟，醒来日覆盖为 0，前一日覆盖约 60 分钟。仍能从完整摘要进入更正，改为 23:50–00:00 后摘要约 10 分钟；删除后显示“尚未记录主睡眠”。不把切片零贡献视为缺少正式睡眠记录。
3. **事实变化、两类冲突、手动修正及真实回滚。** 表单草稿形成后，通过正式 repository 插入 TimeBlock 与 SleepSession；提交显示两条带来源类型 / id 的冲突，正式五表与提交前逐行相同，草稿仍在。离开再进入恢复，手动改为与已有睡眠相接的合法区间。正式库的 AFTER INSERT 触发器以 SQLite ABORT 令写入失败，五表没有残留或部分变化、草稿可继续修改；移除故障后提交成功。更正同一睡眠再次覆盖两类冲突并保留原事实，手动修正后成功，删除只移除该睡眠，五表恢复为预先放入的事实。
4. **提交后的清理 / 刷新失败不会重复写入。** 实际新建、更正和删除依次执行；独立草稿库的 BEFORE DELETE 触发器令清理失败，正式事务提交之后才启用查询拦截器令摘要 / 账本读取失败。页面明确显示“已保存 / 已删除”，锁定输入并提供“继续清理并刷新”。故障仍在时重试、移除故障后再次重试，正式五表快照和 INSERT / UPDATE / DELETE 次数均不变；总计恰为各一次。恢复后草稿清空、返回账本，最终摘要缺失且覆盖为 0、待补记 720 分钟。

上述测试通过实际 application 协调及原有 repository / E3 投影运行，未 mock 正式写入结果或计算。读故障仅拦截测试连接的提交后查询；其他 SQL 实际执行。正式回滚和草稿清理故障均由真实 SQLite 触发器制造，触发器只存在于隔离临时测试库。需要检查在途草稿时复用当前真实草稿连接；离开后使用新连接读回，不关闭全局 Drift 警告。

所有正常路径均不依赖 Goal。每条测试核对正式五表：除冲突场景明确预置的一条 TimeBlock 外，没有新增普通块；Goal、RhythmAnnotation、DailyReview 为空，没有生成 recovery。缺失显示“尚未记录主睡眠 / 小睡”，不声称未睡觉。近似核验包括原始边界、完整摘要、被裁掉的近似入睡边界、保留近似边界的日贡献，以及剩余记录精度改变后的汇总。

## Validation

使用现有依赖与工程环境，最终实际命令及结果：

| 命令 | 结果 |
| --- | --- |
| `dart format test/app/sleep_recording_flow_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed test/app/sleep_recording_flow_test.dart` | 退出 0，1 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/sleep_recording_flow_test.dart` | 退出 0，4 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，455 项通过，1 项纽约 DST 定向用例按时区条件跳过 |
| `git diff --check` | 退出 0 |
| Task 原锚点、完整定义、归档数量及本次文档链接核对 | 通过 |

首次运行因 Drift / Flutter 的 Table 名称冲突编译失败，修正测试导入后重跑。删除后故障用例原先重复输入原值，没有产生编辑草稿，故清理实际上成功；改为先输入不同时间、形成真实编辑草稿，再注入清理故障。此后定向和全量测试通过，未为错误夹具修改生产行为。

最终日志为 `/tmp/e5_t07_flow_tests_3.log`、`/tmp/e5_t07_analyze_final.log`、`/tmp/e5_t07_all_tests.log`，是本机临时日志。新增定向测试无 Drift 多实例警告；全量仍有 5 条既存独立 AppDatabase 连接测试的调试警告，与 E5-T06 数量相同。纽约 DST 定向用例本轮未执行，不写为通过。

## Self-review

检查新建未跟踪测试全文、真实存储连接所有权与释放、SQL 故障触发时点、五表快照、写次数、实际入口 / 草稿恢复、日边界 / 显式 now、E3 汇总与近似边界、缺失文案、手动冲突修正、更正身份、删除及恢复后的结果。故障代码只在 test，未加入应用故障入口或改变依赖方向。没有实现完整时间轴、备注、长期趋势或后续 Epic 页面。

对照本轮开始的文件内容与 SHA-256 快照：既有文件仅更新 TASKS 和 COMPLETED_TASKS；新增此测试和本报告。保留已有跟踪 / 未跟踪的 E2–E5 工作区改动。归档仅追加 E5-T07 和更新任务数，既有任务定义保留；E5-T08 及后续 Task 状态与正文不变。

## Blockers / Open Questions

无新增 blocker，相关问题状态未改变。本轮为真实文件数据库结合 widget / app 交互验证；未执行 Android 实际关闭重开或 Web 实际刷新，不把本机验证作为平台证据。E5-T08 保留这些验收，不声明 Epic 5 或全 MVP 整体验收完成。

## Next executable task

**E5-T08 — 验证 Android 与 Web 睡眠保存和恢复。** E5-T07 与 E2-T08 已有完成证据；Q-012 / Q-022 当前为 DECIDED，执行时重读 Task 与来源并核对平台环境。本轮完成后停止，未开始 E5-T08。
