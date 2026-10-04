# UI-T02 深蓝主题与基础视觉样式

2026-10-04（Asia/Shanghai）。UI-T02 已完成，交付为共享主题及其接入，不代表整个主页或 UI 改造完成。未执行 UI-T03 或 Epic 10。

## 依据和前置证据

核对了 AGENTS、完整 Source of Truth、UI-T02、共同约束、相关架构和问题状态；阅读方案三设计说明，并实际查看原图和细化 v2。UI-T01 前置证据见 [时间轴报告](UI_T01_TIMELINE_REPORT.md)，本次也检查了其当前源码、测试与未提交修改。

按 AGENTS 委派 theme_recon / code_mapper 做有界只读勘查，定位正常 / 加载 / 失败入口、时间轴局部主题和启动测试；主 agent 阅读对应证据后自行作实施、编辑及最终验证。未委派编辑。

UI-N 原缺视觉标注。负责人在本次对话明确选择「采纳草案并继续 UI-T02（推荐）」，已将决定和最小标注记录于 [UI-N 视觉部分](../planning/ui-direction-3-navigation-spec.md)。只完成该视觉部分；其日期头、全天条和导航部分仍未确认，不视为 UI-T03 / UI-T04 前置已齐全。

## 本次修改文件

| 文件 | 修改 |
| --- | --- |
| [time_ledger_theme.dart](../../lib/app/theme/time_ledger_theme.dart) | 单一深蓝 ThemeData；主次文字、青色动作、输入表面、禁用、焦点、错误、选择与基础控件样式；触控目标最低 48；错误文字最多 8 行，避免原单行省略 |
| [main_app.dart](../../lib/app/main_app.dart) | 正常 MaterialApp 接入主题，原 observer / 注入 / 路由保留 |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 加载、失败 MaterialApp 接入同一主题；原消息、进度指示、连接及失败恢复方式保留 |
| [day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) | 移除 T01 局部 Theme 与重复色值；读取全局背景、主次色、睡眠蓝和 Unknown 灰；轨道擦除背景也随主题读取 |
| [app_bootstrap_test.dart](../../test/app/bootstrap/app_bootstrap_test.dart) | 实际加载 / 正常 / 失败路径使用同一主题的集成断言，保留资源关闭和正式存储流程检查 |
| [time_ledger_theme_test.dart](../../test/app/theme/time_ledger_theme_test.dart) | 启动状态、真实 SQLite 组装的正常入口、原日期错误；现有活动表单的焦点 / 禁用 / 原时间对话框错误与取消；布局、guideline 和可选截图 |
| [day_ledger_timeline_layout_test.dart](../../test/features/ledger/presentation/day_ledger_timeline_layout_test.dart) | 截图与布局宿主改用共享主题，保留原矩阵和身份 / 回调断言 |
| [ui-direction-3-navigation-spec.md](../planning/ui-direction-3-navigation-spec.md) | 新增已采纳的 UI-N 视觉部分，明确其他部分未确认 |
| 本报告 | 命令、结果、实际截图与限制 |

时间轴仍复用现有投影、格式化及回调；未改变事实身份、独立精度、完整睡眠 / 当日切片、Unknown / Gap 语义。没有修改 controller / domain / application / data、表单源码、导航、日期头、全天条、pubspec、字体资产或依赖。UI-T02 开始快照位于 /tmp/ui-t02-before；只有上述 5 个已有文件发生本任务增量，另外 6 个开始时存在的文件逐字节保持，包括原计划、UI-T01 报告和其他已有测试改动。UI-T01 的时间轴实现和布局测试增量已保留。

## 实际验证

使用现有 SDK /home/tokiya/Projects/00-develop/flutter/bin；以下 `dart` / `flutter` 均指该 SDK。

```sh
dart format --output=none --set-exit-if-changed \
  lib/app/theme/time_ledger_theme.dart lib/app/main_app.dart \
  lib/app/bootstrap/app_bootstrap.dart \
  lib/features/ledger/presentation/day_ledger_timeline.dart \
  test/app/bootstrap/app_bootstrap_test.dart \
  test/app/theme/time_ledger_theme_test.dart \
  test/features/ledger/presentation/day_ledger_timeline_layout_test.dart
flutter analyze --no-pub
TZ=Asia/Shanghai flutter test --no-pub \
  test/app/bootstrap/app_bootstrap_test.dart \
  test/app/theme/time_ledger_theme_test.dart \
  test/features/ledger/presentation/recording_form_test.dart \
  test/features/ledger/presentation/sleep_form_test.dart \
  test/features/ledger/presentation/day_ledger_timeline_test.dart \
  test/features/ledger/presentation/day_ledger_timeline_layout_test.dart \
  test/app/day_ledger_timeline_test.dart \
  test/app/day_ledger_editing_flow_test.dart \
  test/app/day_ledger_resolution_flow_test.dart \
  test/app/gap_recording_flow_test.dart
TZ=America/New_York flutter test --no-pub \
  test/features/ledger/presentation/day_ledger_timeline_test.dart \
  test/app/day_ledger_resolution_flow_test.dart
git diff --check
```

- 格式检查：7 个 Dart 文件，0 个需重排；静态分析：No issues found；空白检查通过。
- 上海相关回归：67 项通过，2 项 DST 条件跳过。纽约补跑：11 项通过，无跳过，覆盖 23 / 25 小时日。
- 主题字体 / 截图测试：13 项通过。表单 320 / 360 / 412 宽、文字缩放 1 / 1.5 / 2；启动和正常入口另覆盖 360×1 与 320×2。错误文字无省略，取消不应用无效时间，原禁用保存仍不可提交。
- 全局主题下时间轴字体 / 截图测试：11 项通过，含 18 个短 / 长中文、多行 emoji 的布局组合，以及原对象回调和独立精度检查。
- Android 触控目标与标签 guideline 通过。原加载页没有文字或交互目标，其对应检查为无目标，并不证明进度指示的语义信息增加了。
- 启动加载 / 失败的 Flutter 内置 textContrastGuideline 通过；表单与正常页补充使用实际 RenderParagraph / RenderEditable 文字颜色及截图中该文字范围的背景像素检查，包含禁用文字，均通过。没有为颜色常量编写镜像 getter 测试。

首轮 Flutter 内置像素文字对比度检查在紧邻控件的表单子集未通过：例如“不标记”报告 2.72、草稿说明报告 1.47。SDK accessibility.dart 会将文字区域向外膨胀 4 像素，按两组像素众数推断前景 / 背景；检查与截图确认它计入了邻近 chip / 禁用按钮表面和抗锯齿颜色。该子集不记为内置检查通过。补充检查读取实际渲染文字色，使用文字自身范围的背景，不跳过禁用文字；它与人工截图核验共同支持可读性结论。这不是全部 WCAG 或人工无障碍验收。

截图命令（只在测试时加载宿主已有字体，没有加入生产字体资产）：

```sh
TZ=Asia/Shanghai \
UI_T02_CAPTURE_DIR=/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02 \
UI_T02_FONT_PATH=/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc \
flutter test --no-pub test/app/theme/time_ledger_theme_test.dart
TZ=Asia/Shanghai \
UI_T01_CAPTURE_DIR=/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/timeline \
UI_T01_FONT_PATH=/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc \
UI_T01_EMOJI_FONT_PATH=/usr/share/fonts/noto/NotoColorEmoji.ttf \
flutter test --no-pub test/features/ledger/presentation/day_ledger_timeline_layout_test.dart
```

日志：/tmp/ui-t02-analyze.log、/tmp/ui-t02-regression.log、/tmp/ui-t02-dst.log、/tmp/ui-t02-theme.log、/tmp/ui-t02-timeline-layout.log。测试数量有重叠，不相加为唯一用例总数。

## 实际效果截图

以下均为真实 Flutter widget 渲染截图，已实际打开查看；不是生成图。正常入口通过 AppBootstrap 和真实 SQLite 内存库组装，表单禁用状态使用无正式 saver 的测试宿主以呈现原有禁用按钮。debug 角标来自测试的原 MaterialApp 设置。

| 状态 | 实际截图 |
| --- | --- |
| 启动中，360 / 1 | [加载截图](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/loading-360.0-1.0.png) |
| 启动失败，320 / 2 | [原重启消息](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/failure-320.0-2.0.png) |
| 正常入口，360 / 1 | [现有主页主题](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/ready-360.0-1.0.png) |
| 活动表单焦点 / 禁用，360 / 1 | [表单状态](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/form-disabled-360.0-1.0.png) |
| 时间对话框错误，320 / 2 | [完整大字错误消息](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/dialog-error-320.0-2.0.png) |
| 混合时间轴，360 / 1 | [全局主题下时间轴](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/timeline/mixed-360-scale-1.png) |
| 长内容，320 / 2 | [时间轴大字视口](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t02/timeline/long-320-scale-2-viewport.png) |

核验结果：深蓝背景在入口与时间轴一致；焦点青色、错误粉色均配合原文字 / 轮廓；禁用按钮仍与活动按钮有可见差别；睡眠蓝、Unknown 灰和 Gap 空心虚线保留；大字原错误消息可完整显示，连续轨道、时长和动作在时间轴换行后保持可访问。

## 未执行与停止点

没有执行 Android 实机 / 模拟器操作、键盘弹出和强停重开，也没有执行 Web 同页刷新或宽屏矩阵；widget 截图不能外推为这些平台或人工验收通过。没有重跑整个仓库的所有旧测试。

本任务无领域阻塞。UI-N 其余部分、各表单页面设计及完整主页改造仍待单独指定和确认；UI-T03 尚缺日期头 / 全天条规格。完成 UI-T02 后停止，不自动补齐 UI-T03、其他 UI Task 或 Epic 10。
