# E6-T03 — 接通 Gap 预填与明确确认 Unknown

- Task / Status：E6-T03 / COMPLETE（2026-10-01）。
- 直接依赖：已核对 E6-T02、E4-T02、E4-T04、E4-T05 的归档定义、完成报告及实现；Q-011、Q-012、Q-023 均为 DECIDED，无冲突或新增阻塞。
- 依据：SOT §8、§28；DOMAIN_RULES 时间建议合同、TB-004–TB-006；DATA_ARCHITECTURE 原子写入与独立本机草稿。共同必读 SOT、OQ、MVP、PLAN 与 AGENTS 已核对。

## Changes

| 文件 | 修改 |
| --- | --- |
| `lib/features/ledger/presentation/day_ledger_timeline.dart` | 为派生 Gap 提供点击与“补一笔”入口，传递现有 UnresolvedSpan。 |
| `lib/features/ledger/presentation/day_ledger_page.dart` | 以当前投影日期和原 Gap 边界建立草稿上下文；防止重复打开；返回后重读完整日，正式提交与完整日刷新失败分别呈现。 |
| `lib/app/main_app.dart` | 组装既有 RecordingForm、时间建议、草稿和原子提交；明确 Gap 作为建议参数，不另建编辑器。 |
| `test/app/gap_recording_flow_test.dart` | 新增 5 项 widget / 真实 SQLite 场景，涵盖入口分支、历史与未来、Unknown、部分补账、草稿恢复、过期冲突及提交后收尾失败。 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md` | 更新完成索引并归档完整任务定义。 |

全空日明确点击 Gap 直接预填窗口；普通入口仍使用原手动输入分支。新建议两端 approximate，既有草稿的用户输入及独立精度优先恢复。Unknown 必须明确选择，可无标题；打开或离开表单不创建正式事实。

部分补账后剩余 Gap 由原投影重算；过期 Gap 由真实数据库当前事实原子拒绝，草稿保留，可手动修正。提交成功后清理 / 读取失败只重试收尾，不再次写入；完整日读取失败显示独立重试入口，同时保留提交成功提示。

未修改投影算法、领域合同、数据库结构或依赖。草稿上下文继续保留原 Gap 边界，不把 Gap 持久化。竞争事实的边界和备注在冲突后保持不变。

## Validation

以下命令均在工程根目录执行：

- `dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/day_ledger_timeline.dart lib/features/ledger/presentation/day_ledger_page.dart lib/app/main_app.dart test/app/gap_recording_flow_test.dart`：通过，4 文件、0 改动。
- `flutter analyze --no-pub`：通过，No issues found。
- `TZ=Asia/Shanghai flutter test --no-pub test/app/gap_recording_flow_test.dart`：初版 4 项通过；首次运行发现恢复提示断言文案不符，修正断言后通过。随后新增历史全空日用例，包含在下列最终回归中。
- `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time`：401 项通过、1 项纽约时区专用测试跳过。
- `TZ=America/New_York flutter test --no-pub test/app/gap_recording_flow_test.dart test/app/time/device_recording_date_test.dart`：9 项全部通过，包含最终 5 项 Gap 用例及纽约时区专用测试。
- `git diff --check`：通过。

真实库用例使用正式 repository 和独立草稿库，包含文件关闭后重新打开、部分区间保存、竞争睡眠冲突，以及已提交后的清理 / 读取失败注入；确认重试仅创建一条事实。文件 I/O 在 widget 测试的 runAsync 中执行。

已完成 self-review：核对三个生产文件相对任务开始前副本的差异及新增测试；比对任务开始前文件哈希，保留既有工作区改动，无其他既有代码文件被修改。任务报告链接与归档状态已检查。

## Blockers / Open Questions

无。Android 关闭 / Web 刷新与设备操作未执行，不能用本机文件重开或进程时区测试替代；两平台集成属于 E6-T06。

## Next executable task

E6-T04 — 接通时间轴原事实更正与删除。未执行；本次在 E6-T03 完成后停止。
