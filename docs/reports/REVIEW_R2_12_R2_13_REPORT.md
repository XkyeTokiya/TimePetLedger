# 复盘遗留清理与重基线报告（REVIEW-R2-14 / R2-12 / R2-13 · 债务清理 P1）

**日期：** 2026-10-11 ｜ **授权：** 用户授权债务清理 P0–P3；P4 未授权 ｜ **提交：** `935014d`（R2-14）、`3698d22`（R2-12）

## 范围与顺序

P1 = REVIEW-R2-14（复盘会话快照与继续提示移植）→ REVIEW-R2-12（旧复盘界面测试重基线 / 旧页面清理）→ REVIEW-R2-13（平台构建与全仓回归）。R2-14 先于 R2-12 的旧页面删除执行，行为不丢。

## REVIEW-R2-14 — 会话快照与继续提示移植

- `ReviewDraft` 增加向导会话字段（step、手动关注记录、先留着的缺口、卡住选择、未提交的卡住原因），仅会话快照使用；正式提交构造的草稿不设置这些字段（Q-012）。
- `ReviewFlowPage`：打开时读取快照并询问"继续上次填写？/ 继续上次修改？"；基线比较（回到基线清除快照）；串行写入 + epoch 防止已提交后的陈旧写入复活快照；已提交残留识别（新建态经 saver 的 `recoverCommittedDraft` 收尾，编辑态按规范化内容匹配后静默清除）；快照读 / 写失败显示提示与重试；快照未保留时离开需确认"仍然离开"（PopScope）。
- `ReviewSessionService.recoverCommittedDraft`；`MainApp` 接通此前声明未消费的 `reviewDrafts`。
- 顺带修正：`_finish` / `_deleteReview` 仅在写入成功后重置步骤与跟踪；失败时留在页面并保留输入（Q-012"正式保存失败留在页面且保留输入"）。`_write` 返回是否成功。
- 新增组件测试 `test/features/review/presentation/review_flow_page_test.dart`（7 项）：继续、重新、基线清除、两种已提交残留、重新整理恢复、同步失败离开确认。

## REVIEW-R2-12 — 测试重基线 / 旧页面清理

**删除：** 旧复盘页面 5 件（`review_context_controller/page`、`review_facts_view`、`review_form`、`review_form_controller`）、旧测试 3 件、`test/support/review_date_picker.dart`。`lib` 中已无旧复盘引用。

**重写（7 个 app 流程文件，24 项测试）：**

| 文件 | 覆盖 |
| --- | --- |
| `review_submission_flow_test` | 完成向导与 Detail、空下一步、忙碌锁、日期冲突保留输入、真实存储失败重试、选择后归档目标拒绝新建 |
| `review_context_entry_test` | 向导 / Detail 分流、读取失败重试、归档目标显示"已归档" |
| `review_correction_flow_test` | 重新整理保持身份与创建时间、缺失来源不重建、归档引用保留（Q-006） |
| `review_deletion_flow_test` | 确认 / 取消、失败重试、会话快照清理、事实保留 |
| `review_form_entry_test` | 只写会话 store 不写正式表、继续恢复并真实保存、跨 store 实例不恢复 |
| `review_route_flow_test` | 首页入口继承浏览日期、缺口"想不起来"刷新时间轴 |
| `review_closure_flow_test` | 整理→完成→Detail→重新整理→删除、闰日、超长文本保留输入 |

**移植：** 3 个 application 测试去除旧控制器耦合（改驱动 saver / 会话服务）；2 个旧控件测试删除。

**基础设施：** `settleNative` / `tapText` 迁到 `test/support/native_flow.dart`（14 个引用更新）；新增 `test/support/review_flow_app.dart`（四步流程应用级夹具 + 故障注入仓库）与 `app_fixture.dart`（RouteApp）。

**连带更新：** `home_navigation_flow_test` 3 个复盘用例重写；`ui_t04_navigation_test`、`page_t01_visual_fixture_test`（移除 V03/V04）、`editor_visual_sample_test`（移除 review-IME 样张）、`operation_latency_probe`、`direct_date_fields_test`（保留 summary 变体）、`integration_test/review_platform_test`（按新契约重写为会话边界阶段测试）、`goal_rhythm_platform_test` / `ui_t04`（集成）引用更新。

**旧场景处置（无新流程对应，逐条移除并记录）：** 页内改复盘日期（新流程日期固定为入口浏览日期，Q-042；saver 层改日能力仍由 application 测试覆盖）；概述 / 反思输入（R2-00 决定舍弃）；"草稿写盘失败阻断提交"（Q-012 下快照与正式提交解耦）；提交后"收尾重试"UI（残留由下次进入识别收尾）；复盘页阅读位置跨进入恢复（见发现的问题 3）。

## REVIEW-R2-13 — 全仓与平台回归

| 检查 | 结果 |
| --- | --- |
| `flutter test`（全量） | **+797 ~11 -116**；P0 基线 141 → 116（修复 26、净新增 0） |
| 差集核对 | 与 `docs/audits/2026-10-11-test-baseline-bb5051c/failures.json` 逐条对比：26 项修复，唯一"新增"为 `ui_t04` 旧复盘用例改名（同一测试、同一基线原因，净零） |
| `flutter analyze` | 0 问题 |
| `dart format` | 改动文件通过（撤销 2 个无关文件的格式化器重排） |
| Android | `flutter build apk --debug` 通过（`build/app/outputs/flutter-apk/app-debug.apk`） |
| Web | `flutter build web` 通过（`build/web`） |

修复的 26 项：7 个复盘 app 文件 19、application 3、`home_navigation_flow_test` 3、`ui_t04` 复盘用例 1（改名配对，见下）。

## 发现的问题（未在本次修复，供决策）

1. **"重新整理"完成后停留在向导**（step 1 + 横幅），未回到 Detail；`_reflow` 无复位路径。建议一行修复（`_finish` 成功后 `_reflow = false`），确认后可在后续任务处理。
2. **超长"下一步"的错误文案不准确**：invalidInput 统一映射为"下一步需要写一句再完成。"，对 2000+ 字输入不贴切。
3. **复盘页阅读位置跨进入不恢复**：旧页面有 read-scroll 恢复，新页面每次从顶部开始；`ui_t04` 的相应断言已移除。
4. **`ui_t04_navigation_test` 第一条用例为基线既有失败**：mount 时 `pumpAndSettle` 超时（与复盘无关，`bb5051c` 已失败），改名后表现为"修复 + 新增"配对，实际净零。
5. **集成测试相对当前 UI 陈旧**：`ui_t04`（集成）仍引用旧根键；`review_platform_test` 已按新契约重写但未在设备上执行。

## 限制

- 真机 / 读屏 / Web 平台会话边界未验证（INPUT-RECOVERY-04 保持 PENDING）；`integration_test` 需要设备 / 浏览器按 phase 运行。
- P0 基线中 `needs_judgment` 20 项及其余旧夹具失败属 P2 / P3 范围，未在本次处理。
- 全量失败数 116 仍高于目标；P2（DEBT-LEGACY-01）预计降至约 50，P3（DEBT-REBASE-01）清零。
