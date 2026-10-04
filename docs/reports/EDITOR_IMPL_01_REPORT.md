# EDITOR-IMPL-01 · 三编辑页实施

**后续用户验收：未通过。** 用户明确指出整体原型还原不足及组件间距错乱，不能验收。下述115项通过仅为工程证据，不代表视觉完成。返工设计及整体任务见 [实现设计](../planning/UI_IMPLEMENTATION_DESIGN.md)、[PAGE任务清单](../planning/UI_IMPLEMENTATION_TASKS.md)。

用户在R06通过后明确授权活动、睡眠、复盘编辑页。依据已确认 `docs/planning/editor-visual-spec.html`、输入校准稿及源提案§27。状态：核心展示/输入接线及相关回归已交付，视觉与设备验收待完成，未标旧UI-T完成。

## 修改

- `lib/core/widgets/editor_body.dart`：共享展示布局，正文独立滚动，保存条随Scaffold的IME避让位于键盘上方；超短窗口将动作纳入滚动内容。
- `lib/features/ledger/presentation/editor_time_page.dart`：两端时间和独立精度的临时工作副本，日期/时间选择器及手动原文入口，应用才返回草稿；取消不应用。日期选择器以调用方日期作为选择起点，不直接预填事实。
- `recording_form.dart`：活动主输入、紧凑时间、目标/节奏/补充内容展开、固定保存、更多中的返回/放弃；活动更正沿用原身份和收尾。
- `sleep_form.dart`：类型、日期时间卡片、完整时长、双端时间层、备注展开及固定保存；删除移入更多，仍走原确认/flush/删除/收尾。
- `review_form.dart`：第一步优先、再写几句、上一项/下一项/完成、事实上下文展开和继续写作、日期取消/应用、固定保存；原唯一性/草稿/删除/提交后失败合同保留。补回部分成功时菜单返回读取路径。
- `recording_optional_section.dart` 与 `recording_rhythm_input.dart`：有内容仍可折叠显示摘要，错误展开，移除常驻可选标签。
- 相关测试迁移到新的菜单、展开和时间层入口；新增 `test/app/editor_visual_sample_test.dart`。

## 验证

`flutter analyze --no-pub`通过；`git diff --check`通过。本轮Dart文件已执行dart format。

`TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc EDITOR_CAPTURE=/tmp/opencode/editor-implementation flutter test --no-pub`，以下16文件 **115项通过**，日志 `/tmp/opencode/editors-acceptance.log`：

- test/app/editor_visual_sample_test.dart
- test/features/ledger/presentation/recording_form_test.dart
- test/features/ledger/presentation/sleep_form_test.dart
- test/features/review/presentation/review_form_test.dart
- test/features/ledger/presentation/recording_form_controller_test.dart
- test/features/ledger/presentation/sleep_form_controller_test.dart
- test/features/review/presentation/review_form_controller_test.dart
- test/app/review_deletion_flow_test.dart
- test/app/review_submission_flow_test.dart
- test/app/sleep_editing_flow_test.dart
- test/features/ledger/presentation/recording_form_layout_test.dart
- test/features/ledger/presentation/recording_rhythm_test.dart
- test/features/ledger/presentation/recording_goal_test.dart
- test/features/ledger/presentation/recording_rhythm_details_test.dart
- test/app/sleep_submission_flow_test.dart
- test/app/review_form_entry_test.dart

覆盖320/360/412、1/1.5/2倍文字、模拟232高IME占位、时间取消、连续写作、真实仓储保存/删除/草稿恢复和部分成功重试。没有改动domain/application/data/controller或添加依赖；原工作区增量保留。

## 截图与限制

真实Flutter widget截图：`/tmp/opencode/editor-implementation/{activity-ime,sleep,sleep-time,review-ime,review-expanded}.png`。

截图夹具没有注入正式保存服务，保存按钮灰色是夹具真实状态，不能当作完整操作样例验收；睡眠夹具为已有输入的新建状态，并非HTML V02的正式更正状态。IME区域为空白占位，没有真实候选栏。仍需补齐同状态可保存截图、V06冲突视觉和平台中文IME/硬件键盘/安全区验收。目标/节奏目前为纵向展开入口、复盘再写几句与目标分行，与HTML的横向紧凑入口尚有差异；不宣称像素级还原。颜色按用户要求留最后集中微调。

本轮工程回归通过不替代用户视觉认可；三页最终验收尚未完成，不推进阅读/管理页。
