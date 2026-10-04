# UI-T03 日账本头部与时间分布交付报告

日期：2026-10-04（Asia/Shanghai）。状态：**COMPLETE — 仅 UI-T03**。当前日账本入口已交付日期头、覆盖和只读全天时间条；整个主页、根导航和跨页日期所有权尚未完成。本次没有执行 UI-T04 或 Epic 10，没有提交或推送。

## 依据与范围

完整核对更新后的 [实施计划](../planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md) UI-T03、共同约束及 UI-D01 / D02 / D07 / D09；沿用 [UI-N 视觉规格](../planning/ui-direction-3-navigation-spec.md)。已重读领域来源和 Q-009 / Q-014 / Q-017 / Q-021，并再次实际查看两张选定效果图。此前有界只读 code_mapper 勘查了日期控制器、加载调用和相关测试，主 agent 检查引用源码后实施；本次重读补齐计划，没有让勘查 agent 编辑文件。

执行前快照为 /tmp/ui-t03-implementation-before。UI-T01 / UI-T02 的现有改动保留；根入口、共享主题生产代码、时间轴生产代码、旧报告、UI-N、pubspec 和锁文件与该快照字节一致。更新后的计划只追加 UI-T03 交付状态，不更改 UI-D 决策。外部旧 header-time-bar-proposal.md 未作为本次设计依据。

## 交付行为

- 日期按钮打开日历；箭头移动 CivilDate 自然日，选择后固定日期。日历确认今天也固定；“今天”恢复 null / 跟随今天。取消保留选择模式，并在返回读取页时刷新，支持跨午夜。保留原 YYYY-MM-DD 解析器；手动日期确认前不应用错误输入，10000 年与负年份不受日历显示范围限制。
- 日期头按可测文字宽度换行，箭头和动作保持至少48×48。日历使用48像素日单元；窄屏水平滚动查看整周，并有提示和滚动条，内容在大字 / 限高下可纵向滚动。取消和 Escape 不应用临时日期。
- 头部顺序为日期、实际范围、已交代 / 尚未记录、Unknown 子集、时间条。今天显示读取快照的“截至 HH:mm”，历史日保留实际起止日期时间，未来日明确无对账窗口。
- 控制器只新增 presentation 的 dateContext：在原 DayLedgerLoader 流程中捕获同一次解析的边界和 now，不在 I/O 后重新解析时区。一次请求仍只解析和读取一次；上下文与 view 一起清除、发布，并受原请求序号隔离。
- 时间条直接绘制既有 segments / unresolvedSpans。分母为该日实际起止 epoch 毫秒；没有再次计算 Gap / coverage。睡眠蓝、活动青、Unknown灰实心、Gap空心虚线。今天未发生区间和未来整条使用中性表面，不计入 Gap 或统计，不提供编辑 / 补记操作。
- 条高16，刻度间距8。刻度按实际 instant 定位，重复时刻附 UTC 偏移；重复零点也保留两个偏移。拥挤时减少中间标签，首尾和完整语义保留。1毫秒片段未人为增宽，精度文字各自来自投影，准确操作仍由下方时间轴承担。
- 统一格式仅把已有 roundedMinutes 转为小时分钟；59 / 60 / 61、半分钟边界、25小时、微小时长、零值、hasRecords 缺失和逐项“约”均保持原合同。睡眠、时间轴、摘要、复盘及原主页数字自动复用；没有改原始时长或输入精度。
- 原事实更正 / 删除 / Gap 回调和提交收尾流程保留。加载 / 失败不显示旧范围数值，完整睡眠但空窗口的状态仍使用原存在性判断。导航 shell、表单重排、日期共享根状态和正式复盘卡留在各自任务中。

## 修改文件

6份生产 Dart、29份测试 / 测试辅助 Dart；计划状态与本报告为文档改动。以下清单是相对执行前快照的 UI-T03 增量，不把已有 UI-T01 / UI-T02 文件改动重复算作本次实施。

| 文件 | 本次职责 |
| --- | --- |
| [lib/features/ledger/presentation/summary_formatting.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/summary_formatting.dart) | 最终舍入分钟转小时分钟 |
| [lib/features/ledger/presentation/day_ledger_controller.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_controller.dart) | 同请求展示上下文与旧请求隔离 |
| [lib/features/ledger/presentation/day_ledger_page.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_page.dart) | 日期头、日历 / 手动入口、覆盖接入；保留原操作与刷新 |
| [lib/features/ledger/presentation/day_ledger_time_bar.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_time_bar.dart) | 新增毫秒比例、DST刻度和只读语义 |
| [lib/features/ledger/presentation/day_ledger_overview.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_overview.dart) | 新增范围、覆盖与 Unknown 子集展示 |
| [lib/features/ledger/presentation/day_ledger_date_dialog.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_date_dialog.dart) | 新增可滚动日历、手动确认和自然日移动 |
| [test/app/basic_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/basic_recording_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/sleep_submission_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_submission_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/sleep_editing_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_editing_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/sleep_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_recording_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/day_ledger_timeline_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_timeline_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/gap_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/gap_recording_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/day_ledger_editing_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_editing_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/day_ledger_resolution_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_resolution_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/day_ledger_goal_rhythm_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_goal_rhythm_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/day_summary_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_summary_entry_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/review_context_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_context_entry_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/review_form_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_form_entry_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/review_submission_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_submission_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/review_route_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_route_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/review_closure_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_closure_flow_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/support/ledger_date_selection.dart](/kiyodata/Projects/21-TimePetLedger/test/support/ledger_date_selection.dart) | 新增日期确认测试辅助 |
| [test/support/rendered_text_contrast.dart](/kiyodata/Projects/21-TimePetLedger/test/support/rendered_text_contrast.dart) | 提取已有段落对比度验证，主题与新头部实际复用 |
| [test/app/bootstrap/app_bootstrap_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/bootstrap/app_bootstrap_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/app/theme/time_ledger_theme_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/theme/time_ledger_theme_test.dart) | 复用提取后的对比度验证，无主题生产变化 |
| [test/features/ledger/presentation/summary_formatting_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/summary_formatting_test.dart) | 小时边界、舍入、25小时及原存在性 / 精度回归 |
| [test/features/ledger/presentation/day_ledger_controller_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_controller_test.dart) | 上下文同请求、一次解析、失败及失效回归 |
| [test/features/ledger/presentation/day_ledger_page_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_page_test.dart) | 日期模式、取消 / 午夜、闰日、失败不残留与竞争请求 |
| [test/features/ledger/presentation/day_ledger_timeline_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_timeline_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/features/ledger/presentation/day_summary_page_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_summary_page_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/features/ledger/presentation/day_summary_coverage_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_summary_coverage_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/features/ledger/presentation/day_summary_sleep_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_summary_sleep_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/features/ledger/presentation/day_ledger_timeline_layout_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_timeline_layout_test.dart) | 共享单位断言 / 日期入口定位回归，保留原事实与草稿断言 |
| [test/features/ledger/presentation/day_ledger_time_bar_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_time_bar_test.dart) | 新增图例比例、微小时长、中性空窗口、DST及重复零点验证 |
| [test/features/ledger/presentation/day_ledger_overview_layout_test.dart](/kiyodata/Projects/21-TimePetLedger/test/features/ledger/presentation/day_ledger_overview_layout_test.dart) | 新增手机 / 大字状态、长文本、弹窗、guideline及截图验证 |

文档：[UI_DIRECTION_3_IMPLEMENTATION_PLAN.md](../planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md) 仅更新交付状态；[UI_T03_OVERVIEW_REPORT.md](UI_T03_OVERVIEW_REPORT.md) 为本次新报告。

## 实际验证

Flutter / Dart：/home/tokiya/Projects/00-develop/flutter/bin；所有 Flutter 命令使用 --no-pub，无依赖安装。

| 命令 / 范围 | 实际结果 | 日志 |
| --- | --- | --- |
| dart format --output=none --set-exit-if-changed，35份改动 Dart | 35份，0需格式化 | /tmp/ui-t03-format.log |
| flutter analyze --no-pub | No issues found | /tmp/ui-t03-analyze.log |
| TZ=Asia/Shanghai flutter test --no-pub test/app test/features/ledger/presentation test/features/review/presentation | 广回归279通过、3项按时区跳过 | /tmp/ui-t03-regression.log |
| 最终局部复核：day_ledger_overview_layout_test.dart、day_ledger_time_bar_test.dart、day_ledger_page_test.dart，Asia/Shanghai，实际CJK / emoji字体与截图 | 16通过、2项DST时区条件跳过；覆盖最后的日期弹窗和刻度增量 | /tmp/ui-t03-capture.log |
| TZ=America/New_York flutter test --no-pub，day_ledger_time_bar_test.dart、day_ledger_timeline_test.dart、test/app/day_ledger_resolution_flow_test.dart | 14通过；Havana专用项跳过，纽约23/25小时及真实SQLite闭环均执行 | /tmp/ui-t03-dst.log |
| TZ=America/Havana flutter test --no-pub day_ledger_time_bar_test.dart --plain-name 'repeated midnight' | 重复零点1项通过，显式25小时展示上下文，不外推其他适配器能力 | /tmp/ui-t03-midnight-dst.log |
| git diff --check | 通过 | 本次终端检查 |

广回归包含规定的 page / controller / app-entry / summary-formatting，以及睡眠、摘要、复盘、原启动主题与更正 / 删除 / Gap / 草稿失败流程。随后只重跑最终日期弹窗 / 刻度改动的受影响部分；表中数量是各次实际运行结果，存在测试重叠，不相加宣称唯一用例数。

布局矩阵：320 / 360 / 412，文字1 / 1.5 / 2；每组验证混合、长中文 / 多行emoji、历史空日、今天、午夜零窗口、未来、加载、失败，共72组头部状态。长列表能滚到末段原Gap操作；日期弹窗另测320宽 / 650高 / 2倍文字、水平选择周日、纵向读取选择、非法手动日期、取消、Escape、超日历范围年份。图例原始汇总660 / 30 / 780分钟，对应11 / 30分钟 / 13小时；现有夹具的Unknown近似端点使覆盖与Gap分别保留“约”。比例按实际毫秒逐段校验，非通过截图猜宽度。

Android触控目标与标签guideline通过。SDK textContrastGuideline已实际执行：Ahem路径通过，实际CJK的小字号“今天 / 刷新账本”采样仍出现2.00 / 1.56的估计失败，不能记作SDK全面通过。所有实际字体状态同时通过共享 RenderedTextContrast：读取有效 RenderParagraph / RenderEditable文字颜色，采样段落内实际背景，按3 / 4.5门槛验证，包含禁用文字；该方法不把相邻表面或抗锯齿中间色作为前景。这是检测限制，原失败诊断保留在捕获日志，未修改全局配色来绕过。

截图捕获复现命令：

```sh
TZ=Asia/Shanghai \
UI_T03_FONT_PATH=/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc \
UI_T03_EMOJI_FONT_PATH=/usr/share/fonts/noto/NotoColorEmoji.ttf \
UI_T03_CAPTURE_DIR=/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03 \
/home/tokiya/Projects/00-develop/flutter/bin/flutter test --no-pub \
test/features/ledger/presentation/day_ledger_overview_layout_test.dart \
test/features/ledger/presentation/day_ledger_time_bar_test.dart \
test/features/ledger/presentation/day_ledger_page_test.dart
```

## 实际效果截图

以下为生产 Flutter 组件实际渲染，2倍像素捕获；使用本机CJK / emoji字体仅使证据可读，没有给生产应用增加字体或依赖。混合夹具与选定图同日，now显式注入2026-10-03，故10月2日显示“昨天”；其他状态同样由投影 / 控制器生成，不是新效果图或设备屏幕截图。

- [历史混合，360宽 / 1倍文字](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/mixed-360-scale-1.0.png)。
- [320宽 / 2倍文字](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/mixed-320-scale-2.0.png)。
- [今天，截至now后中性](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/today-360-scale-1.0.png)。
- [未来，不产生Gap动作](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/future-360-scale-1.0.png)。
- [读取失败，不残留数值](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/failure-320-scale-2.0.png)。
- [大字日历与横向 / 纵向滚动后选择](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/calendar-scrolled-320-scale-2.png)。
- [手动日期失败保留输入](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/manual-error-320-scale-2.png)。

![UI-T03 历史混合实际渲染](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t03/mixed-360-scale-1.0.png)

人工实际查看上述状态、日历滚动前后及两张选定图：数值层级、日期换行、连续时间轴、实心事实 / 虚线Gap / 中性未来区和未截断文本符合当前任务。保留原刷新 / 复盘入口，未把组件交付描述成完整主页。

## 未执行与停止点

未运行实际Android设备 / 模拟器触摸、系统键盘、旋转、强停重开或真实Web浏览器刷新 / Tab交互；本次截图和键盘事件为widget验证，不能外推平台体验验收。新根导航、根层跨页日期 / 滚动所有权、表单重排、复盘卡与宽屏均未实施。没有未解决的本任务领域决策；SDK原始对比度采样限制按上文留存。

UI-T03已完成并停止。后续任务须由负责人另行指定，不自动执行UI-T04或Epic 10。
