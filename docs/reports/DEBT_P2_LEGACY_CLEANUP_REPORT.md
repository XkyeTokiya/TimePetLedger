# 死代码批量清除报告（DEBT-LEGACY-01 · 债务清理 P2）

**日期：** 2026-10-11 ｜ **授权：** 债务清理 P0–P3 ｜ **提交：** `bcf347b`（主体）、`9a1add2`（孤立平台助手）

## 交付

**lib 删除 17 个生产不可达文件：**

- 旧日账本栈 7 件：`day_ledger_page` / `day_ledger_timeline` / `day_ledger_overview` / `day_ledger_time_bar` / `day_ledger_fact_details` / `day_date_selection` / `ledger_date_header`
- 旧输入与外观 4 件：`sleep_form`、`recording_form`、`time_ledger_theme`、`ledger_shell`
- 零引用件 2 件：`home_menu_page`、`goal_create_sheet`
- 重建后新发现的死角 4 件：`editor_body`、`recording_optional_section`、`goals_page`、`goal_rename_dialog`（原仅被已删旧表单 / 旧页面或测试引用）
- `recording_form.dart` 拆分：`formatRecordingTime` / `parseRecordingDate` 移入 `recording_time_format.dart`（现役 `fact_detail_page` / `activity_quick_sheet` / `day_ledger_date_dialog` 引用）。

**测试清理与迁移：**

- 删除 40 个旧界面测试文件 + 4 个旧导航助手（`app_sleep_navigation` / `app_recording_navigation` / `recording_fields` / `page_t01_fixture`）+ 5 个绑定已删界面的陈旧集成测试（`ui_t04` / `ui_t05` / `day_ledger_platform` / `summary_platform` / `goal_rhythm_platform`）+ 6 个孤立平台状态助手。
- 新增共享夹具：`test/support/ledger_view_fixtures.dart`（sample / mixedLedgerFacts）、`recording_draft_fixture.dart`（Queries / Fixture，数据与现役控制器）、`app_flow_helpers.dart`（BlockReadFailure / disposeApp）、`integration_test/support/platform_flow.dart`（真实 UI 等待 / 定位助手）。
- 保留有效覆盖：仅依赖现役 `SleepFormController` 的睡眠用例 6 项、迁移回滚安全用例 4 项（`failed vN-to-vN+1 migration rolls back…`）；删除旧契约的"草稿跨重开保留"用例。
- 现役测试更新：`goal_rhythm_closure`、`home_r1_visual`、`app_bootstrap`、`sleep_draft_entry`（删旧表单用例）等。

**旧场景覆盖映射（只读勘查结论）：**

- 睡眠：跨日新建 / 编辑 / 删除、冲突回滚、收尾失败重试、备注上限、缺失来源等由 `sleep_entry_saver_test` / `sleep_entry_editor_test`（应用层）与 `sleep/sleep_recording_page_test`（新页）覆盖；旧"文件草稿 + 摘要"端到端场景随 Q-012 废弃。
- 日账本：跨日切片编辑、冲突原子回滚、注解编辑 / 移除、目标元数据、读取失败重试、摘要重算由 `home_feed_flow_test`、`day_summary_*`、`recording_entry_*` / `sleep_entry_*`、domain 合同测试覆盖。
- 登记的覆盖缺口（非阻塞）：经 HomeShell 的 Gap 预填 / 冲突全流程、首页时间轴的 Goal 文本展示——可在后续任务补新界面端到端。

## 验证

| 检查 | 结果 |
| --- | --- |
| `flutter test`（全量） | **686 通过 / 6 跳过 / 25 失败**（P0 基线 141 → P1 116 → P2 25） |
| 差集核对 | 25 项全部为 P0 登记的 `needs_judgment`，**零新增** |
| `flutter analyze` | 0 问题 |
| `dart format` | 改动文件通过 |
| lib 可达性 | 从 `main.dart` 无死角（仅 `database_connection_web.dart` 为条件导出静态误报） |
| 受影响批次 | 睡眠控制器 / 迁移回滚 / goal_rhythm_closure / home_r1_visual / app_bootstrap 等全部通过 |

## 剩余 25 项（P3 = DEBT-REBASE-01）

- `summary_formatting_test` 5（"约"前缀移除未同步）
- `day_summary_sleep_test` 4 / `day_summary_coverage_test` 3 / `day_summary_page_test` 2 / `day_summary_goal_rhythm_test` 2 / `day_summary_entry_test` 1（摘要文案与结构陈旧）
- `app_bootstrap_test` 3（"日账本"字标 / 旧首页结构与文案）
- `sleep_time_prediction_loader_test` 2、`recording_time_automation_test` 1（应用层时间初值与反馈文案待判定）
- `home_feed_nav_capture_test` 2（首页渲染与复盘入口键陈旧）

## 限制

- 5 个集成测试因绑定已删除的旧界面且自 UI 重建以来不可运行而删除；平台验收覆盖需按新界面重建（`review_platform_test` 已在 P1 按新契约重写；保留的 `sleep_platform` / `recording_platform` / `time_automation` 等未在本环境验证）。
- 睡眠 / 日账本经 HomeShell 的端到端失败路径覆盖变薄（应用层覆盖完整）；如需恢复属新界面测试补充，不阻塞 P3。
