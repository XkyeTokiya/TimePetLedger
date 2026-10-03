# E4-T07 — 验证普通记录完整应用闭环

## Task / Status

**COMPLETE（2026-09-29）。** 仅执行 E4-T07，未执行 E4-T08。E4-T06 与 E3-T07 在 `TASKS.md` 中标为 COMPLETE，交付报告和实际代码、测试均已核对。Q-003、Q-012、Q-013、Q-014、Q-023 等相关问题均为 DECIDED；没有阻塞性 Open Question。

依据 Source of Truth 的回顾式账本、Unknown / Gap、睡眠独立性、近似精度及主时间轴不重叠结论，以及 MVP_SCOPE / M-01、M-07，IMPLEMENTATION_PLAN / Epic 4，DOMAIN_RULES / LEDGER-001–005、LEDGER-007、LEDGER-010 和 Q-023 时间建议合同。按 `AGENTS.md` 委派有界只读代码勘查；主 agent 核对入口、读写、草稿和投影链路后实施与验证。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `lib/app/main_app.dart` | 最小账本结果展示复用现有 `formatDerivedDuration`，分别呈现已交代、其中 Unknown、待补记的近似标志；普通记录的独立起止精度在时间行可见，Unknown 行明确标识，睡眠事实存在时显示其记录数；不增加完整时间轴或睡眠输入 |
| `test/app/basic_recording_flow_test.dart` | 新增两条使用真实内存 SQLite、独立草稿库和 `AppBootstrap` 的交互闭环：仅有睡眠的今天给尾部建议；混合精度从草稿到正式事实、投影和更正保持一致，再删除重算 Gap；历史日期需确认候选，非法标题与睡眠冲突可修正重试，保存路径无 Goal / annotation |
| `test/app/bootstrap/app_bootstrap_test.dart` | 补充全空账本手填与默认近似精度断言；既有记录从真实入口打开后被删除，编辑入口报告不存在且不重建；调整 Unknown 覆盖显示断言以核对近似语义 |
| `TASKS.md`、本报告 | 记录 E4-T07 状态、证据与验证边界 |

测试从同一应用入口实际经过日期账本、建议 / 手填、Known / Unknown、草稿、正式提交、读回投影、更正与删除。仅有 SleepSession 时，建议算法将其视为已覆盖事实；冲突发生后正式事实不增加，草稿和输入仍保留，手动改正后再提交。成功保存的记录不要求 Goal、category 或 RhythmAnnotation。

## Validation

在仓库根目录执行：

| 命令 | 结果 |
| --- | --- |
| `dart format lib/app/main_app.dart test/app/basic_recording_flow_test.dart test/app/bootstrap/app_bootstrap_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同 3 文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/app/basic_recording_flow_test.dart test/app/bootstrap/app_bootstrap_test.dart` | 退出 0，9 项通过 |
| `flutter test --no-pub` | 退出 0，362 项通过、2 项 skip |
| `git diff --check` | 退出 0 |

## Self-review / Blockers / Open Questions

已检查新增测试、展示差异和 `TASKS.md` 状态。结果展示只使用现有同次投影的时长与事实集合，不添加派生事实源；近似提示来自各自投影或事实精度，不从整体覆盖反推单条精度。没有修改领域模型、数据库 schema、依赖或前序任务能力；工作区原有未提交和未跟踪改动均保留。

无 blocker 或新增 Open Question。本任务的交互持久化验证使用真实本机 SQLite；没有执行 Android 应用关闭再打开或 Web 页面刷新，因此不把 E4-T08 的平台恢复合同记作已验证。

## Next executable task

**E4-T08 — 验证 Android 与 Web 的保存和草稿恢复。** 其另一前置 E2-T08 有 COMPLETE 报告和 Android / Web 存储重开证据，尽管 `TASKS.md` 的 E2-T08 条目未写状态行；本次不改写前序任务记录。完成 E4-T07 后停止。
