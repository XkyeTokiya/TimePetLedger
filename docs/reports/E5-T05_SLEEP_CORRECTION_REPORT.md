# E5-T05 — 接通睡眠更正与删除

## Task / Status

**E5-T05 / COMPLETE，2026-09-30。** 仅执行本 Task，未执行 E5-T06。

读取 AGENTS、Task 全文及共同必读 SOT / OQ / MVP / PLAN，核对 STATES 的 SleepSession 与通用更正删除、DATA 事务、DERIVED sleepSummary，以及 MODEL / RULES / APP 的相关合同。前置证据为 [E5-T04 报告](E5-T04_SLEEP_SUBMISSION_REPORT.md)、[Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)（E1-T12）、[E2-T06 报告](E2-T06_ATOMIC_LEDGER_WRITE.md)及实际实现。Q-013 / Q-018 均为 DECIDED，职责来源一致，无新增领域阻塞。

按 AGENTS 委派 code_mapper 有界只读定位睡眠编辑相关调用、既有更正事务及测试；主 agent 检查证据并完成实现、集成、自审和最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [ledger_repository.dart](../../lib/features/ledger/domain/ledger_repository.dart)、[drift_ledger_repository.dart](../../lib/features/ledger/data/drift_ledger_repository.dart) | 按身份读取完整 SleepSession，缺失返回 null，区分损坏事实与存储读取失败 |
| [sleep_entry_editor.dart](../../lib/features/ledger/application/sleep_entry_editor.dart) | 完整源事实加载、更正 / 删除协调、相关日期刷新、已提交残留草稿识别和仅清理 / 读取重试 |
| [sleep_entry_saver.dart](../../lib/features/ledger/application/sleep_entry_saver.dart) | 复用提交后处理，支持多个日期及部分读取失败，不混淆正式失败与已提交结果 |
| [sleep_form_controller.dart](../../lib/features/ledger/presentation/sleep_form_controller.dart)、[sleep_form.dart](../../lib/features/ledger/presentation/sleep_form.dart) | 恢复编辑草稿、源事实缺失反馈、更正 / 删除确认、在途及已提交锁定、失败保留和继续清理刷新 |
| [sleep_summary_view.dart](../../lib/features/ledger/presentation/sleep_summary_view.dart)、[main_app.dart](../../lib/app/main_app.dart) | 摘要与入睡日原始记录均可按同一身份进入完整编辑器；操作后展示重读结果 |
| [sleep_entry.dart](../../lib/app/bootstrap/sleep_entry.dart)、[sleep_submission.dart](../../lib/app/bootstrap/sleep_submission.dart)、[app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart)、[device_recording_date.dart](../../lib/app/time/device_recording_date.dart) | app 注入 editor、既有 repository / loader / 草稿，以及当前设备时区的绝对时间日期映射 |
| [sleep_entry_editor_test.dart](../../test/features/ledger/application/sleep_entry_editor_test.dart) | 9 项真实 SQLite / 真实草稿测试 |
| [sleep_editing_test.dart](../../test/features/ledger/presentation/sleep_editing_test.dart) | 8 项 controller / widget 编辑、删除和失败交互测试 |
| [sleep_editing_flow_test.dart](../../test/app/sleep_editing_flow_test.dart) | 2 项真实库、文件草稿与 app 组装闭环测试 |
| [sleep_form_test.dart](../../test/features/ledger/presentation/sleep_form_test.dart) | 调整已有滚动点击帮助方法，确保新增按钮后目标实际可点击 |
| TASKS、COMPLETED_TASKS、本报告 | 按现有任务索引 / 归档结构记录完成证据，保持原 Task 锚点与定义 |

更正只调用既有 `updateSleepSession`，删除只调用既有 `deleteSleepSession`；未改写 E2-T06 的原子写入实现。按 id 重新加载完整事实，不从日切片拼回事实。更正保留 id / createdAt，无变化时 updatedAt 不变；可修改时间、类型及两端独立精度。保存不传 note，从事务中当前原事实保留未展示 note，包括打开表单后由其他写入改变的 note。未保存输入仅写独立草稿，不改正式睡眠或复盘。

正式事务依据提交时的当前事实判定冲突。冲突或写入失败保留输入和草稿；源事实缺失报不存在，不调用 create。删除缺失身份沿用幂等事务。删除入口明确确认整次睡眠；在途操作等待草稿排空并锁定输入、重复保存 / 删除及放弃。已提交结果锁定新的正式操作，清理或读取失败仅重试清理 / 读取，文案明确已保存或已删除。

成功后重读当前查看日、原始起止日期及更正后的起止日期，覆盖旧 / 新醒来日摘要。各日期使用已有 SleepLedgerLoader 一致快照，重算覆盖、Gap 与完整睡眠摘要；任一请求日期读取失败均作为提交后失败，即使当前查看日已成功也不会宣称全部完成。app 只持有当前查看日；其余受影响中间日期没有缓存，再次打开时从正式事实重新读取，因此不枚举任意长的跨日区间。跨日入睡日的入口与醒来日摘要入口均使用同一 SleepSession id。

没有新增依赖、正式 schema、历史版本、note 输入、完整时间轴或自动处理其他事实；没有修改复盘，也没有生成 TimeBlock / recovery。

## Validation

使用现有环境和依赖，实际命令及最终结果：

| 命令 | 结果 |
| --- | --- |
| `dart format`（下列 16 文件） | 退出 0，最终 0 changed |
| `dart format --output=none --set-exit-if-changed`（同 16 文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/ledger/application/sleep_entry_editor_test.dart test/features/ledger/presentation/sleep_form_controller_test.dart test/features/ledger/presentation/sleep_submission_test.dart test/app/sleep_draft_entry_test.dart` | 退出 0，27 项通过 |
| `flutter test --no-pub test/features/ledger/presentation/sleep_editing_test.dart` | 退出 0，8 项通过 |
| `flutter test --no-pub test/app/sleep_editing_flow_test.dart test/app/sleep_submission_flow_test.dart test/app/sleep_draft_entry_test.dart` | 退出 0，7 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，431 项通过；1 项纽约 DST 定向用例按时区条件跳过 |
| `git diff --check` | 退出 0 |
| Task 归档正文、原锚点及本次文档链接核对 | 通过 |

格式检查文件清单：

```sh
dart format --output=none --set-exit-if-changed lib/features/ledger/domain/ledger_repository.dart lib/features/ledger/data/drift_ledger_repository.dart lib/features/ledger/application/sleep_entry_saver.dart lib/features/ledger/application/sleep_entry_editor.dart lib/features/ledger/presentation/sleep_form_controller.dart lib/features/ledger/presentation/sleep_form.dart lib/features/ledger/presentation/sleep_summary_view.dart lib/app/bootstrap/sleep_entry.dart lib/app/bootstrap/sleep_submission.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart lib/app/time/device_recording_date.dart test/features/ledger/presentation/sleep_form_test.dart test/features/ledger/application/sleep_entry_editor_test.dart test/features/ledger/presentation/sleep_editing_test.dart test/app/sleep_editing_flow_test.dart
```

真实 SQLite 检查完整按 id 读取、缺失、损坏数据及关闭连接失败；跨日更正移到新醒来日、mainSleep↔nap、独立精度、元数据和 note 保留。无变化测试设置禁止 UPDATE 的触发器，证明未执行 UPDATE 且毫秒边界 / updatedAt 不变。保存前新增 TimeBlock 与另一 SleepSession，提交返回两类冲突，五张正式表逐行不变、草稿保留。测试 `AFTER UPDATE` / `AFTER DELETE` 故障触发器证明失败回滚；未改正式 schema。删除重算当前 / 原醒来日 Gap 和摘要，复盘原状，重复删除成功；源事实已删除的更正不重建。

controller / widget 覆盖重复保存与删除、在途输入 / 放弃锁定、删除取消、正式更正 / 删除失败、恢复不完整草稿、读取失败重试、保存前源事实移除和恢复时缺失。更正与删除均模拟草稿清理失败及仅另一日期读取失败，确认已提交文案、禁止重复写入，恢复后只清理 / 读取；残留已提交编辑草稿重开不会再次 update。

app 测试使用真实 SQLite 与真实文件草稿：入睡日进入完整编辑，未提交原事实不变，关闭草稿存储再打开可恢复；将 28→29 日主睡眠更正为 29→30 日小睡，原日覆盖归零、旧醒来日摘要缺失、新醒来日完整小睡 470 分钟而日贡献 460 分钟；再更正为主睡眠并删除，Gap / 覆盖 / 摘要同步更新。note、id / createdAt 保留，其他事实未生成。另验证摘要残留但源事实已删除时不重建、编辑草稿保留，返回重读覆盖归零。

初次静态分析发现测试 / 实现的多行 if 缺大括号，修正后通过。初次定向测试出现旧点击帮助方法目标在屏外的警告，改为确保目标滚动可见后，后续 app 测试和全量测试通过。最终日志在 `/tmp/e5_t05_analyze_final.log`、`/tmp/e5_t05_all_tests.log`；定向日志为 `/tmp/e5_t05_first_tests.log`、`/tmp/e5_t05_editing_tests.log`、`/tmp/e5_t05_app_tests.log`，均为本机临时日志。

## Self-review

逐项检查新增 / 已改文件的身份与完整事实读取、事务调用、note 遗漏字段合同、源事实缺失、草稿生命周期、重复请求锁、提交后失败分类及旧 / 新醒来日刷新。application 不依赖 Flutter / SQL 或全局当前时间；presentation 不获得数据库连接。

对照本轮开始的文件内容与 SHA-256 快照，仅改变上表本任务代码和文档；保留既有 E2–E5 改动、未跟踪文件及 IMPLEMENTATION_PLAN / mapping / 测试等原状态。工作期间 TASKS 被并行整理为完成索引和 COMPLETED_TASKS 归档，保留这项改动，按其结构追加 E5-T05 完成记录；没有覆盖既有归档内容。未改领域文档、OQ、pubspec / lockfile、生成代码、正式 schema 或平台配置。

## Blockers / Open Questions

无新增 blocker；Q-013 / Q-018 不变。真实库和交互验证通过。

本轮未执行 Android 关闭重开 / Web 刷新平台验收，也未重跑 E2-T06 平台事务矩阵；前置平台证据见 E2-T06 报告。真实文件草稿重开不等同平台端到端验证，新增睡眠平台恢复仍留 E5-T08。本轮不标记 Epic 5 整体验收完成。纽约 DST 定向用例跳过，不写为通过。

## Next executable task

**E5-T06 — 实现每日首次打开的主睡眠确认。** E5-T01 / E5-T04 / E5-T05 已有实现与完成证据，Q-008 / Q-010 / Q-012 均为 DECIDED；实际执行仍需重读对应来源。完成 E5-T05 后停止，未开始 E5-T06。
