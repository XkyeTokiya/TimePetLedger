# E7-T03 — 接通普通记录的可选目标归属

## Task / Status

**E7-T03 / COMPLETE（2026-10-01，Asia/Shanghai）。** 仅执行 E7-T03；未执行 E7-T04 或后续任务，Epic 7 未标记为完成。

已核对 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，SOT §11、§26–27，RULES / TB-003、GO-002，DATA / 本机输入草稿，以及 MODEL / UI Models、APP 的分层与 goals/domain 读取边界。E7-T02、E4-T06、E6-T04 的完整归档定义、完成报告与实际代码已核对。Q-003、Q-004、Q-006、Q-012 均为 DECIDED；身份、文本继续遵守 Q-018、Q-019、Q-015。无来源冲突或产品阻塞。

按 AGENTS 委派 code_mapper 做有界只读调用路径勘查，主 agent 检查实际草稿、保存 / 更正协调器与正式写事务后实现。既有 createTimeBlock / updateTimeBlock 在事务内重读 Goal，检查新增关联必须 active、既有 archived 引用可保留；本任务复用该合同，没有重复领域校验。

## Changes

| 文件 | 本任务交付 |
| --- | --- |
| [recording_form.dart](../../lib/features/ledger/presentation/recording_form.dart) | 可选目标选择 / 明确移除、同名候选身份区分、原有归档目标显示、加载 / 空 / 失败与重试反馈；目标时间突出供确认，独立近似精度保持 |
| [recording_form_controller.dart](../../lib/features/ledger/presentation/recording_form_controller.dart) | 注入 GoalRepository；目标元数据读取不覆盖输入，延迟读取不恢复已清空的归属；选择按 id，意图区分保留 / 设置 / 清空，串行自动保存 |
| [recording_draft_store.dart](../../lib/features/ledger/domain/recording_draft_store.dart)、[drift_recording_draft_store.dart](../../lib/features/ledger/data/drift_recording_draft_store.dart) | DTO 增加 goalId / goalProvided；仅独立草稿库升级至版本 3，支持 v1 / v2 到 v3 的事务迁移，旧行缺省保留原引用 |
| [recording_entry_saver.dart](../../lib/features/ledger/application/recording_entry_saver.dart)、[recording_entry_editor.dart](../../lib/features/ledger/application/recording_entry_editor.dart) | 新建传目标 id；更正仅在显式意图时传设置 / 清空，否则省略保留；已提交草稿恢复比较目标 id / 清空意图，避免误清未提交输入 |
| [main_app.dart](../../lib/app/main_app.dart)、[app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 将真实 GoalRepository 注入普通、Gap、日时间轴原事实编辑及主页更正四处 RecordingForm |
| [recording_goal_test.dart](../../test/features/ledger/presentation/recording_goal_test.dart) | 13 项真实库 widget / controller 测试：空目标可记录、同名按 id、Unknown 保留输入、选后归档 / 删除、新建 / 编辑失败重试、原归档引用、清空、SQL 回滚、读取失败 / 延迟、提交后清理与安全恢复 |
| [recording_goal_migration_test.dart](../../test/features/ledger/data/recording_goal_migration_test.dart) | 3 项真实文件库测试：v1 / v2 迁移保留输入和隐藏字段、选择 / 清空重开、DDL 故障回滚与重试，正式五表与版本不变 |
| [recording_goal_flow_test.dart](../../test/app/recording_goal_flow_test.dart) | 2 项真实 AppBootstrap 组合测试：普通选择、正式库 / 草稿库文件重开、主页更正清空；Gap 区间、时间轴编辑及原归档引用保留 / 移除 |
| [recording_draft_store_test.dart](../../test/features/ledger/data/recording_draft_store_test.dart)、[basic_recording_flow_test.dart](../../test/app/basic_recording_flow_test.dart)、[day_ledger_editing_flow_test.dart](../../test/app/day_ledger_editing_flow_test.dart) | 草稿探针与不支持版本夹具随 v3 更新；新增目标区块后滚动定位时间控件，保留原行为断言 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原 Task 完整归档、稳定锚点索引与进度同步 |

## Acceptance evidence

- known / unknown 均可选择或不选 Goal。active 列表为空时有明确反馈，仍可正式保存；普通 / 睡眠既有无 Goal 路径在回归中通过。同名候选以完整 id 区分，保存、草稿与读回均使用 id，不合并名称。
- 原 archived 引用可以显示、保留、明确移除；选择列表仅包含 active。原 Goal 在 known→unknown 更正中保留，category、annotation、note、id / createdAt 同样保留。清空草稿重开后仍是明确清空，保存前原正式关联不变。
- 独立草稿存选择 id 和 goalProvided：false 表示保留原关联，true + null 表示清空，true + id 表示设置。v1 / v2 旧草稿新增字段默认 false，不把原未展示归属写成 null。迁移、输入 / note、时间、精度与编辑身份真实文件重开后保留；迁移第二条 ALTER 故障回滚第一条 ALTER，版本保持 2，解除故障可重试。
- 目标时间提供突出区间与“请确认”提示，保存按钮仍是用户确认提交；不增加 exact 门槛、不改变时间建议。Gap 仍沿用原预填区间，两端 approximate 可直接保存；切换知识状态或选择目标不暗改时间或精度。
- 提交沿用真实 LedgerRepository 的写事务重新校验当前 Goal。新增选择在提交前被归档 / 物理删除时，新建和编辑分别拒绝提交，原事实及草稿输入保留；刷新目标后重新选择可重试成功。真实 SQLite AFTER INSERT + RAISE(FAIL) 也回滚正式事实，解除故障后成功。
- 读取失败与空 active 列表可辨；读取重试不重置活动、时间或选择。读取延迟期间明确移除，旧请求不会恢复该关联。
- 新增目标字段纳入提交恢复匹配，目标不同或待清空时不误认作已提交。真实提交后草稿清理失败，新建选择与编辑清空均能恢复已提交状态；只重试清理 / 读取，SQL 计数确认没有第二次正式 INSERT / UPDATE。

## Validation

在仓库根目录使用已有 Dart / Flutter 与缓存依赖执行，没有安装或更新包。

本次 14 个 Dart 文件：

```text
lib/features/ledger/application/recording_entry_editor.dart
lib/features/ledger/application/recording_entry_saver.dart
lib/features/ledger/data/drift_recording_draft_store.dart
lib/features/ledger/domain/recording_draft_store.dart
lib/features/ledger/presentation/recording_form.dart
lib/features/ledger/presentation/recording_form_controller.dart
lib/app/bootstrap/app_bootstrap.dart
lib/app/main_app.dart
test/features/ledger/data/recording_draft_store_test.dart
test/app/basic_recording_flow_test.dart
test/app/day_ledger_editing_flow_test.dart
test/features/ledger/data/recording_goal_migration_test.dart
test/features/ledger/presentation/recording_goal_test.dart
test/app/recording_goal_flow_test.dart
```

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format` 上述文件（分批） | 退出 0 |
| `dart format --output=none --set-exit-if-changed` 上述 14 文件 | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/recording_goal_test.dart test/features/ledger/data/recording_goal_migration_test.dart test/app/recording_goal_flow_test.dart` | 退出 0，18 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/data/recording_draft_store_test.dart test/app/basic_recording_flow_test.dart test/app/day_ledger_editing_flow_test.dart` | 退出 0，14 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/features/goals test/app test/core/time` | 退出 0，474 项通过、3 项既有时区条件测试跳过 |
| `git diff --check`、执行前 SHA-256 对照、归档原定义和文档链接检查 | 通过 |

过程中修复新增测试编译、if 大括号、fake async 中直接调用 controller 的测试等待问题；迁移故障用例暴露的部分 ALTER 留存问题已通过事务升级修复。初次广回归的 7 项失败来自旧草稿探针版本和 UI 懒构建 / 滚动定位，夹具及定位更新后定向与广回归均通过。未将初轮失败或中断运行记为通过。

3 项 skip 为上海时区不满足的既有 DST 条件测试，未视为通过。日志：`/tmp/e7-t03-focused-final.log`、`/tmp/e7-t03-regression-repair.log`、`/tmp/e7-t03-regression-final.log`、`/tmp/e7-t03-analyze-final.log`。

## Self-review / Scope

检查全部本任务生产改动、三个新增测试和三个既有测试的增量 diff，核对字段意图、保存事务、失败不清除、读取失败、提交恢复和原事实隔离。执行前 SHA-256 对照确认其他既有文件（包括未跟踪文件）保持原样，既有工作区修改未覆盖。正式 AppDatabase 仍为版本 2 / 五表；没有修改正式 schema、生成文件、pubspec / lockfile、时间建议或领域校验，没有增加 annotation 输入、通用框架、目标统计或后续生命周期 UI。

归档保留 E7-T03 原依赖、范围、验收与 Validation，新增 COMPLETE 和报告链接。TASKS 索引及 PLAN 只同步本次完成状态，后续任务定义保持不变。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。本轮文件重开是 Native SQLite / Flutter 组合证据；未执行 Android 应用关闭或 Web 刷新恢复，不外推为两平台验证。目标新增输入的两平台生命周期证据仍属 E7-T07。

## Next executable task

**E7-T04 — 接通可选节奏解释与接续点。** E7-T03、E2-T06、E1-T11 已有完成依据，相关问题已 DECIDED；仅报告，不执行。E7-T03 完成后停止。
