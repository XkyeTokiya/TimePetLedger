# TIME-02 — 日期与时间独立修改交付

日期：2026-10-07（Asia/Shanghai）。基准HEAD：`55bca8017c98377343760c844b25f187dbd01e77`。本轮用户明确授权补齐完整提示词；实现已交付，存在既存回归与Android验证限制，不标全部平台COMPLETE。未提交Git，保留工作区TIME-01及其他文档阶段改动。

## 交付行为

按源提案后续决定及Q-038，点击日期直接开日历，点击时间直接开原中文时分滚轮。开始 / 结束各自独立，确定立即应用当前字段并关闭，不接第二个选择器或总时间面板。取消和打开不改草稿；初值为当前输入，无值使用入口日期与12:00。日期修改保留时分 / 秒 / 毫秒，时分修改保留日期 / 秒 / 毫秒及另一端；不自动换日。重复当地时刻的未改值保留原绝对时间，不存在的当地时刻提示重新选择。

当前活动 / 睡眠、RecordingForm / SleepForm / GuidedRecordingPage / ActivityEditor、睡眠 / 复盘提醒均已统一直接选择；复盘表单、独立复盘上下文、基础摘要日期改为直接日历。首页 / 日账本 / 嵌入复盘原直达日期路径核查后保留。目标 / 详情日期为事实显示或既有范围选择，没有遗漏的总日期时间编辑面板。

当前活动 / 睡眠布局和样式保留，只拆开点击区域；旧页面在原时间区域展示独立日期 / 时分按钮，原精度能力保留。备注、事项、节奏、类型、目标、草稿、提交、错误与跨事实原子校验保持。进入表单的自动初始化、时长正推 / 反推、现有事实及提交后恢复沿已有实现；未实施Q-037其余预测模型 / 元数据 / schema。

## 修改范围

| 职责 | 文件 |
| --- | --- |
| 独立日期、时分与复用字段 | `lib/features/ledger/presentation/recording_time_picker.dart` |
| 当前记录入口 | `activity/activity_recording_page.dart`、`sleep/sleep_recording_page.dart` |
| 保留旧表单与开发预览 | `recording_form.dart`、`sleep_form.dart`、`guided_recording_page.dart`、`activity_editor.dart` |
| 全应用其他编辑入口 | `lib/features/settings/presentation/settings_page.dart`、`lib/features/review/presentation/review_form.dart`、`review_context_page.dart`、`lib/features/ledger/presentation/day_summary_page.dart` |
| 删除无效代码 | 旧`activity_time_sheet.dart`、`guided_recording_time_sheet.dart`、`editor_time_page.dart`；RecordingForm旧手工日期时间对话框、展开状态与无效路由；复盘 / 摘要旧文本输入控制器和临时无效日期状态 |
| 测试 | 当前活动 / 睡眠、选择器、四种旧页面、提醒偏好、复盘日期 / 保存与摘要日期测试；相关测试帮助函数与Web集成目标 |
| 决定与交接 | 源提案、Q-038、DOMAIN_RULES、PRODUCT_PRINCIPLES、DATE_TIME_EDITING、UI_REBUILD_PLAN、TASKS、DOCUMENT_REGISTER；仅纠正算法设计文档中的手动选择串联描述 |

TIME-01已删除的生产`activity/activity_time_sheet.dart`没有恢复。无新增依赖、事实字段或数据库迁移。

## 实际验证

使用已安装Flutter工具snapshot执行，避免受限包装脚本更新SDK stamp；未安装或升级环境。命令前缀：

```sh
FLUTTER_ROOT=/kiyodata/Projects/00-develop/flutter FLUTTER_ALREADY_LOCKED=true \
/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart \
/kiyodata/Projects/00-develop/flutter/bin/cache/flutter_tools.snapshot \
--suppress-analytics --no-version-check <子命令>
```

| 验证 | 结果 |
| --- | --- |
| 全仓库`analyze --no-pub`最终代码 | 退出0，No issues found |
| SDK `dart format --output=none --set-exit-if-changed`全部46个新增 / 修改Dart文件 | 退出0，0文件改变；随后最后日期测试单独确认0改变 |
| `git diff --check` | 退出0 |
| 13文件相关回归，`test --no-pub ... --reporter expanded` | 100项，97通过、3失败；同名3失败均在未修改HEAD复现 |
| 最终字段焦点改动后RecordingForm / SleepForm / GuidedRecordingPage及新增日期页 | 旧表单 / 预览31项通过；两个新增日期页的最终结果见下一行 |
| 最终`direct_date_fields_test.dart`和`recording_form_layout_test.dart` | 9通过、1同一既存布局测试失败；两个新日期页和取消后的Escape焦点均通过 |
| `TZ=America/New_York ... test --no-pub test/features/ledger/presentation/recording_time_picker_test.dart --reporter expanded` | 9通过，无跳过；包含跨年、秒毫秒、不存在 / 重复当地时刻、320 / 360宽及2倍字体 |
| 真实Chromium Web集成 | 退出0；独立时分 / 日期、跨年邻居读取、重开草稿、正式保存及清草稿通过 |
| 扩大5个旧应用闭环文件，原始HEAD对照 | 12项失败同名在HEAD全部复现；尚不能视为旧应用回归通过 |
| `adb devices`（允许本机服务的执行环境） | 无连接设备，Android设备实测未执行 |

13个相关文件参数：

```text
test/features/ledger/presentation/recording_time_picker_test.dart
test/features/ledger/presentation/activity/activity_recording_page_test.dart
test/features/ledger/presentation/sleep/sleep_recording_page_test.dart
test/features/ledger/presentation/recording_form_test.dart
test/features/ledger/presentation/sleep_form_test.dart
test/features/ledger/presentation/guided_recording_test.dart
test/features/ledger/presentation/recording_form_layout_test.dart
test/features/ledger/presentation/recording_rhythm_test.dart
test/features/review/presentation/review_form_test.dart
test/app/rebuild_pages_test.dart
test/app/review_form_entry_test.dart
test/app/review_submission_flow_test.dart
test/app/review_context_entry_test.dart
```

真实Web命令：

```text
drive --no-pub --driver=test_driver/integration_test.dart
  --target=integration_test/time_automation_test.dart -d web-server
  --web-port=7396 --browser-name=chrome --chrome-binary=/usr/bin/chromium
  --driver-port=4444 --browser-dimension=390x844 --headless --timeout=180
```

相关最终失败仅为：RecordingForm旧折叠节奏字段显示，以及RecordingRhythm两个重复 / 缺失解释关系失败后的旧标题预期；原始HEAD对应用例也失败。未为通过旧测试改变日期时间范围以外的产品行为。扩大回归另12项主要依赖旧根页面路径，基准副本同名复现；此次未修复整套旧导航。

[证据目录](assets/time02/)含实际日志与失败名称对照。当前结果支持本次交互交付，不等于全仓库、Android或全部平台验收通过。TIME-01历史报告不改写；Q-037学习算法及其他任务没有自动启动。
