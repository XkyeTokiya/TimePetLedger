# UI-T01 — 日账本连续时间轴

**UI-T01 / COMPLETE（2026-10-03，Asia/Shanghai）。** 交付范围为现有日账本中的时间轴组件；整张主页及 UI-T02 / Epic 10 未实施。

## 依据与前置

完整阅读 AGENTS、UI_DIRECTION_3_IMPLEMENTATION_PLAN 的 UI-T01 / 共同约束、SOT、引用设计说明及相关 RULES / DERIVED / Q-014。实际查看原方案三和主页细化 v2。核对 E6-T02、E6-T04、E7-T05 的完成索引、报告与当前源码；无本任务产品阻塞。委派一次有界只读 code_mapper，主 agent 检查其引用的 timeline、segment、coverage、页面回调与测试证据后负责实施和验证。

开始时分支 main、HEAD dcb4946；唯一已有工作区内容是未跟踪的 `docs/planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md`。该文件全文 SHA-256 与执行前一致，未改写原计划。

## 修改文件

| 文件 | 修改 |
| --- | --- |
| [day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) | 局部深蓝 / 青色样式、稳定左时间列、贯穿轨道、标题与右侧时长、四状态文字 / 图标 / 节点、完整睡眠信息及自适应换行 |
| [timeline widget tests](../../test/features/ledger/presentation/day_ledger_timeline_test.dart) | 适配分开的时间列 / 时长；保留全部切片精度断言，新增完整睡眠独立精度断言 |
| [timeline app test](../../test/app/day_ledger_timeline_test.dart) | 适配新呈现，增加真实 SQLite 完整睡眠展示核验；保留跨日身份及数据库全行不变断言 |
| [layout tests](../../test/features/ledger/presentation/day_ledger_timeline_layout_test.dart) | 18 组布局与 guideline、整行 / 显式按钮回调身份、独立醒来精度、可选截图导出 |
| [Gap flow](../../test/app/gap_recording_flow_test.dart)、[resolution flow](../../test/app/day_ledger_resolution_flow_test.dart) | 仅替换 Unknown 展示文案断言为“想不起来 · 已交代” |
| 本报告 | 验证命令、截图索引、范围与未执行项 |

生产改动仅一个 presentation 文件。继续合排现有 `segments` / `unresolvedSpans`，使用相同带类型的 `segment.reference` 行 key；Goal 仍按源 goalId 匹配同一投影快照。编辑、普通事实删除、Gap 补记的整行及显式按钮仍传递同一对象；睡眠删除仍经现有完整编辑器。未改动 controller、投影、domain / application / data、schema、依赖、根导航、全局主题、日期头部、全天条或表单。

Known 使用活动名和通用活动图标；Sleep 使用月亮及主睡眠 / 小睡文字；Unknown 使用问号、灰实心节点及“想不起来 · 已交代”，保留已有 title / Goal / 节奏 / 接续点；Gap 使用加号、空心节点、虚线轨道及原“补一笔”动作。没有按内容推断分类图标或增加折叠。

时间列使用既有 `formatRecordingTime` 的时分部分，完整日期区间仍可通过 tooltip / 语义标签访问，次日零点仍表示为 00:00 并保留完整日期。时长继续使用 `formatDerivedDuration` 的分钟、舍入、微小时长及近似格式。大字或窄内容区时，时长换到标题下方并保持右对齐。所有正式文字无 maxLines / ellipsis 截断。

睡眠右侧值与“当日切片”来自 segment；入睡 / 醒来分别来自完整 source 的独立精度，完整时长沿用既有完整睡眠时长展示口径。因此前日约 23:00 → 当日准确 07:00 的完整睡眠显示约480分钟，而当日切片仍为准确420分钟；未删除旧切片断言，也未给准确醒来附加近似。

## 实际验证

使用已有 Flutter SDK 和缓存依赖，工程目录为 `/home/tokiya/Projects/21-TimePetLedger`（解析为 `/kiyodata/Projects/21-TimePetLedger`）。

| 命令 / 检查 | 最终结果 |
| --- | --- |
| `dart format` 本次 6 个 Dart 文件；同清单 `dart format --output=none --set-exit-if-changed` | 退出0；6 files / 0 changed |
| `flutter analyze --no-pub` | 退出0，No issues found |
| 下列 Shanghai 8 文件回归命令 | 退出0，38项通过，2项既有真实 DST 条件测试跳过 |
| 下列 New York 3 文件命令 | 退出0，12项通过，无跳过；覆盖上述23/25小时日场景 |
| 带本机中文 / emoji 字体的 layout 测试及截图导出 | 退出0，11项通过；其中9项分别覆盖短 / 长文本，共18组布局 |
| `git diff --check`；既有文件 SHA-256 对照 | 通过；只有表列既有5文件变化，原计划文档保留 |

```sh
TZ=Asia/Shanghai flutter test --no-pub \
  test/features/ledger/presentation/day_ledger_timeline_test.dart \
  test/features/ledger/presentation/day_ledger_timeline_layout_test.dart \
  test/app/day_ledger_timeline_test.dart \
  test/app/day_ledger_goal_rhythm_test.dart \
  test/app/day_ledger_editing_flow_test.dart \
  test/app/day_ledger_resolution_flow_test.dart \
  test/app/gap_recording_flow_test.dart \
  test/features/ledger/presentation/day_ledger_page_test.dart

TZ=America/New_York flutter test --no-pub \
  test/features/ledger/presentation/day_ledger_timeline_test.dart \
  test/app/day_ledger_timeline_test.dart \
  test/app/day_ledger_resolution_flow_test.dart

TZ=Asia/Shanghai \
UI_T01_CAPTURE_DIR=/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t01 \
UI_T01_FONT_PATH=/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc \
UI_T01_EMOJI_FONT_PATH=/usr/share/fonts/noto/NotoColorEmoji.ttf \
flutter test --no-pub test/features/ledger/presentation/day_ledger_timeline_layout_test.dart
```

布局矩阵为320 / 360 / 412逻辑像素、文字缩放1 / 1.5 / 2，每格混合四状态与长中文 / 多行 emoji 两组。检查左列宽度和位置一致、轨道与相邻行无断层、长文字无截断 / Flutter异常；逐行滚动到操作位置，执行当前 SDK 的 `androidTapTargetGuideline`、`labeledTapTargetGuideline`、`textContrastGuideline`，按钮至少48×48。

初轮新增测试的异步 guideline 等待、语义句柄释放和截图字体加载已修正；Gap 小字渲染对比度问题通过16字号 / 加粗并继承原字体修正。最终截图使用实际中文和 Material 图标字体，未把早期失败或测试字体方块记作通过。最终日志：`/tmp/ui-t01-layout-final.log`、`/tmp/ui-t01-regression.log`、`/tmp/ui-t01-dst.log`、`/tmp/ui-t01-analyze-final.log`。

## 截图与逐图对照

以下均为最终 Flutter widget 软件渲染截图，pixelRatio=2；不是 ImageGen 效果图或 Android / Web 设备截屏。截图字体只在测试中加载，没有添加生产字体资源或依赖。

- [混合四状态，360宽 / 1倍文字](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t01/mixed-360-scale-1.png)：完整时间轴，跨夜近似入睡 / 准确醒来、Known、带已有内容的 Unknown、Gap、目标 / 节奏 / 接续点及原操作。
- [长中文与多行emoji，320宽 / 2倍文字，全组件](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t01/long-320-scale-2.png)：长标题、目标及接续点持续换行，轨道随行高延续，末尾操作可滚动到达。
- [同一大字场景的800高视口](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t01/long-320-scale-2-viewport.png)：手机视口中的完整源边界换行和右侧时长。
- [准确入睡 / 近似醒来，360宽](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t01/approximate-wake.png)：当日切片末端、完整醒来及两个时长分别显示自身近似；入睡和切片起点不借用近似。

主 agent 已实际查看两张选定图及上述最终截图，对照时间左列、连续轨道、四类图标 / 节点、活动标题优先、右侧时长和次级可选信息。实现保留原编辑 / 删除入口、完整睡眠日期与现有分钟格式，因此行高随内容增长；参考图中未属于UI-T01的日期头、全天条、底栏和复盘卡不计入本组件验收。

## 限制与停止点

无本任务 blocker。未执行实体 Android 触控 / 系统返回 / TalkBack、浏览器运行或设备截图、平台强停 / Web刷新、全应用视觉验收；本任务没有修改存储或 controller 生命周期，留存的平台证据不作为本轮通过结果。没有提交或推送。

UI-T01 组件完成后停止。UI-T02 仍需其视觉标注门槛及单独授权；未执行 UI-T02 或 Epic 10。
