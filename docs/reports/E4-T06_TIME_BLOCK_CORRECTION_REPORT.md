# E4-T06 — 接通已有 TimeBlock 更正与删除

## Task / Status

**COMPLETE（2026-09-29）。** 仅执行 E4-T06，未执行 E4-T07。E4-T05、E1-T10、E2-T06 的完成状态与现有提交能力已核对；Q-003、Q-013、Q-018 均为 DECIDED，无阻塞性 Open Question。

依据 Source of Truth 的 TimeBlock、Unknown / Gap 与重叠结论，DOMAIN_STATE_MACHINES 的 TimeBlock 字段矩阵及通用更正删除、DOMAIN_RULES 的更正删除合同、DATA_ARCHITECTURE 的原子写入。没有改变领域模型、schema 或依赖。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `lib/features/ledger/domain/ledger_repository.dart`、`data/drift_ledger_repository.dart` | 增加按 id 读取完整 TimeBlock 与可选 RhythmAnnotation 的最小接口；真实存储在同一读取事务中获取完整源事实，不由自然日切片重建编辑对象 |
| `lib/features/ledger/application/recording_entry_editor.dart`、`recording_entry_saver.dart` | 编辑调用现有原子 `updateTimeBlock`，仅传表单展示字段，省略 Goal、category、note 与 annotation 以保留原值；删除调用现有原子 `deleteTimeBlock`；提交后分别清理编辑草稿并重读投影，收尾失败与正式写入失败分开反馈 |
| `lib/features/ledger/presentation/recording_form_controller.dart`、`recording_form.dart` | 加载源事实后恢复编辑草稿；缺失事实显示不存在且不重建；支持 known ↔ unknown、时间与精度更正；冲突保留输入并显示相关事实；新打开且未修改的编辑不产生草稿 |
| `lib/app/bootstrap/app_bootstrap.dart`、`lib/app/main_app.dart` | 组装编辑协调器；账本日期窗口中的普通记录提供更正与确认删除入口，展示源事实完整时间区间；操作后刷新覆盖与记录投影，删除后清理或刷新失败给出独立继续操作 |
| `test/features/ledger/application/recording_entry_editor_test.dart`、`test/features/ledger/presentation/recording_form_test.dart`、`test/app/bootstrap/app_bootstrap_test.dart` | 真实 SQLite 与 widget 验证跨日完整源、双向更正、归档 Goal 和解释保留、冲突回滚、未保存原事实不变、删除与 Gap 重算、缺失编辑、重复删除、编辑草稿恢复及应用入口 |
| `TASKS.md`、本报告 | 记录 E4-T06 完成状态和验证结果 |

底层 `updateTimeBlock` 保留 id；无实质变化时保持原 `updatedAt`。底层 `deleteTimeBlock` 在写事务中删除 TimeBlock 与解释，保留 DailyReview；上述行为由真实库测试读回核对。已提交后的清草稿 / 刷新失败不会提示用户重新更正或删除。

## Validation

在仓库根目录执行：

| 命令 | 结果 |
| --- | --- |
| `dart format`（本任务涉及的 11 个 Dart 文件） | 退出 0，0 changed |
| `dart format --output=none --set-exit-if-changed`（同 11 文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/ledger/application/recording_entry_editor_test.dart test/features/ledger/presentation/recording_form_test.dart test/app/bootstrap/app_bootstrap_test.dart` | 退出 0，25 项通过 |
| `flutter test --no-pub` | 最终退出 0，360 项通过、2 项 skip |
| `git diff --check` | 退出 0 |

## Self-review / Blockers / Open Questions

已检查任务范围、读写事务、完整源区间、保留未展示字段、删除连带关系、提交与收尾失败区分及新增未跟踪文件。进入任务前工作区已有大量前序任务的未提交与未跟踪改动；均予保留。没有引入 Sleep / Review 编辑、Goal / annotation 编辑 UI、历史版本、完整时间轴或新依赖。

无 blocker 或新增 Open Question。真实持久化验证使用本机 SQLite；设备端完整闭环属于后续任务，本报告不将其记为已验证。

## Next executable task

**E4-T07 — 验证普通记录完整应用闭环。** 本次完成 E4-T06 后停止。
