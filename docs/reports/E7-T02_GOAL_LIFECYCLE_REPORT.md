# E7-T02 — 接通目标改名归档恢复与删除

## Task / Status

**E7-T02 / COMPLETE（2026-10-01，Asia/Shanghai）。** 仅执行本任务；未执行 E7-T03 或后续任务，Epic 7 未标记为完成。

核对 AGENTS、Task 完整定义、SOT / Goal、OQ、MVP、PLAN，STATES / Goal、DATA / goals 和引用策略、RULES / GO-001–GO-002、MODEL / Goal 及 APP / goals 边界。E7-T01 与 E2-T07 的归档完整定义、完成报告和实际代码已核对。Q-006、Q-018、Q-019 为 DECIDED，文本继续遵守 Q-015；来源与 repository 合同一致，无产品阻塞。

按 AGENTS 委派 code_mapper 做有界只读勘查，主 agent 检查目标与复盘引用代码、事务和共用真实库测试证据后实施。现有 rename / archive / restore / delete 已满足领域与引用合同，只扩展归档列表查询和 UI。

## Changes

| 文件 | 本任务交付 |
| --- | --- |
| [goal_repository.dart](../../lib/features/goals/domain/goal_repository.dart)、[drift_goal_repository.dart](../../lib/features/goals/data/drift_goal_repository.dart) | 新增 listArchived，严格还原归档 Goal，保留同名身份；listActive 和既有写事务原样保留 |
| [goals_page.dart](../../lib/features/goals/presentation/goals_page.dart) | 每个目标按 id 的管理菜单：改名、归档 / 恢复、删除；独立归档管理路由，返回后重读 active；成功 / 失败 / 已提交后的读取失败分别反馈 |
| [goal_rename_dialog.dart](../../lib/features/goals/presentation/goal_rename_dialog.dart) | 领域校验复用、失败保留原始改名输入、缺失对象拒绝重建、保存期间阻止重复提交和关闭 |
| [archived_goals_test.dart](../../test/features/goals/data/archived_goals_test.dart) | 两项真实 SQLite 查询测试：同名归档身份与元数据、恢复后筛选、坏数据 / 关闭连接失败 |
| [goal_management_test.dart](../../test/features/goals/presentation/goal_management_test.dart) | 十项 widget + 真实 repository 交互测试，覆盖生命周期、引用保护、回滚、过期对象、安全读取重试及加载状态 |
| [goal_entry_test.dart](../../test/app/goal_entry_test.dart) | 扩展既有 AppBootstrap 真实库闭环，验证主页入口→改名→归档管理→恢复→返回 active，注入时间与其他正式表不受影响 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、完整定义归档、稳定锚点索引与进度同步 |

没有修改 app 生产组装：复用 E7-T01 已注入的 repository / UUID / now。没有新增归属表单、目标统计、状态、实体版本、依赖、索引或正式 schema。

## Acceptance evidence

- 改名允许同名，名称校验由既有 Goal.rename 执行。规范化后无变化不执行 UPDATE、不刷新 updatedAt。真实历史日账本读取使用当前目标名称，复盘下一步继续引用原 id；原 TimeBlock / DailyReview 等行逐字段保持不变。
- active 归档写入注入的 UTC 毫秒时间；恢复清除 archivedAt，保留 id / createdAt。实际变化才更新 updatedAt。UI 基于过期列表重复请求相同状态时，repository 重新读取当前对象，测试确认无 UPDATE、元数据不变。
- 归档目标仅位于独立管理入口，不进入 active 列表。归档目标可改名、恢复或删除，恢复后 listActive 重新读到相同 id；返回 active 页面重读，未提交创建名称保留。
- 删除先由界面说明并确认，最终引用判断仍位于 repository 写事务。TimeBlock 引用和 TomorrowFirstStep 引用分别导致归档，反馈明确“已有记录引用，已归档”；两类事实行均保持原样。无引用才物理删除，反馈“目标已删除”；已不存在反馈“目标已不存在”，不虚报发生了物理删除。取消不写库。
- 对已归档、仍有引用的目标重复删除不重写归档时间。缺失对象的改名 / 归档 / 恢复失败明确，不自动 create。
- 测试专用 AFTER UPDATE / DELETE + RAISE(FAIL) 在真实 SQLite 语句已改变数据后制造故障，repository 外层事务回滚。改名输入原样保留；归档 / 恢复 / 删除失败不出现成功反馈。解除故障后可重试。
- 保存期间 UI 与旧菜单回调都拒绝重复写入及手动刷新。每种管理操作提交成功后的列表读取失败仍保留已成功反馈；页面只重试 SELECT，测试计数确认不再 UPDATE / DELETE。
- 归档页 loading、empty、failed 可辨；失败不显示空列表，重试可恢复。所有成功读写均使用真实 DriftGoalRepository / SQLite，SQL 查询边界的测试注入只用于等待和读取失败，不伪造正式成功结果。

## Validation

在仓库根目录执行，使用已有 Flutter / Dart 与缓存依赖；没有安装或更新包。

本轮七个 Dart 文件：`lib/features/goals/domain/goal_repository.dart lib/features/goals/data/drift_goal_repository.dart lib/features/goals/presentation/goals_page.dart lib/features/goals/presentation/goal_rename_dialog.dart test/features/goals/data/archived_goals_test.dart test/features/goals/presentation/goal_management_test.dart test/app/goal_entry_test.dart`。

| 实际命令 | 结果 |
| --- | --- |
| `dart format` 上述七文件 | 退出 0，最终 0 changed |
| `dart format --output=none --set-exit-if-changed` 上述七文件 | 退出 0，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/goals/presentation/goal_management_test.dart test/features/goals/data/archived_goals_test.dart test/app/goal_entry_test.dart` | 最终退出 0，13 项通过、无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/goals test/features/review test/app` | 最终退出 0，134 项通过、2 项既有 DST 测试跳过 |
| `git diff --check`、执行前 SHA-256 对照、文档链接与归档原定义核对 | 通过 |

过程中修复了新增测试的 Drift / matcher isNotNull 导入重名、路由加载断言缺少一次 pump，以及读取私有菜单回调时的泛型强转问题；最终定向和广回归命令均重跑通过。两项 skip 为既有 day_ledger_resolution_flow_test 的真实 23 / 25 小时自然日场景，上海时区不满足运行条件；未将跳过项记为通过，本任务未改变日期计算。

日志：`/tmp/e7-t02-management-final.log`、`/tmp/e7-t02-analyze-final.log`、`/tmp/e7-t02-regression-final.log`。前序目标 lifecycle / repository 和 review 真实库合同包含在最终回归中，普通与睡眠的无 Goal 路径继续通过。

## Self-review / Scope

以执行前 SHA-256 快照检查全部已有文件（包括未跟踪文件）。代码修改仅目标 repository 接口 / 实现、目标页及既有 app 目标测试；新增文件限于改名 UI、归档查询测试、目标管理测试。本轮完整 diff 与新增文件已检查；保留原目标创建行为、错误输入保留和提交后读取重试。原 Goal 领域实体、五表 schema、生成代码、app 生产组装、其他 feature、前序测试与报告、依赖文件均保持原样。

收尾仅增量更新 TASKS / COMPLETED_TASKS / PLAN 并新增本报告；归档保留 E7-T02 原依赖、范围、验收和 Validation，新增 COMPLETE 与报告链接。未覆盖既有工作区改动或未跟踪文件，未执行后续任务。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。恢复后重新进入 active 候选的合同已由真实查询验证；普通表单中的实际目标选择仍属 E7-T03。本轮未执行 Android / Web 平台目标管理及应用重启验证，留 E7-T07；本机 Flutter widget / Native SQLite 证据不外推为平台验收。

## Next executable task

**E7-T03 — 接通普通记录的可选目标归属。** E7-T02、E4-T06、E6-T04 已完成，相关产品决定已确定；仅报告，不执行。E7-T02 完成后停止。
