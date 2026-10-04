# UI-T04 根导航交付报告

日期：2026-10-04（Asia/Shanghai）。Task：UI-T04 / 回看、记录、复盘根入口。状态：**已交付；验证限制如下**。仅本任务完成，整个主页和方案三UI改造仍未完成。

## 依据、勘查与工作区

完整读取本任务、共同约束、UI-D01–UI-D03 / UI-D09、UI-N视觉规格、设计说明和相关来源；实际查看原方案三及主页细化v2两张选定图。重读AGENTS、SOT、APP，核对Q-010 / Q-012 / Q-023及其余问题状态，检查TASKS、Epic 9和UI-T01–UI-T03交付证据。两条有界只读code_mapper分别勘查根路由 / 首次睡眠和读取页 / 日期 / 滚动路径；主agent检查引用源码后独立作出实现决策、编辑及最终验证。

实际工程为/kiyodata/Projects/21-TimePetLedger，/home/tokiya/Projects/21-TimePetLedger指向同一工程。main / HEAD dcb4946保持。实施前403份已跟踪及非忽略未跟踪文件存于/tmp/ui-t04-before，已有UI-T01–UI-T03增量保留；本报告的文件清单相对该快照计算，不能用相对HEAD的全部diff当成本任务改动。没有提交、推送、新依赖、schema、领域 / data / controller改写或主题改动。

## 实际行为

- 默认日账本，底栏“回看 / ＋记录一笔 / 复盘”。左右是读取目的地，中央仅打开活动 / 睡眠 / 取消模态；取消不实例化表单、不创建草稿。更多只提供当日摘要和目标管理，刷新和手动日期仍可达。
- 根层持有null跟随今天或明确CivilDate；账本、复盘、摘要共用选择。明确日期跨午夜保留，今天恢复跟随。复盘仅在原编辑页返回正式savedDate后固定根日期；仅编辑日期、保留草稿或取消不会更新根选择。
- 原事实类型＋源ID、独立起止精度、投影、格式化与编辑 / 删除 / Gap回调保持。普通创建沿用Q-023建议；明确Gap仍带原边界。原完整睡眠摘要和编辑入口留在账本下方，以保留当天窗口没有切片的醒来日完整睡眠能力；没有新睡眠聚合或正式复盘结果卡。
- 返回先由平台关闭键盘，再关闭模态或返回子页；根复盘返回回看并保留日期，根回看交回系统。子页无根底栏，原表单flush、草稿队列及提交 / 收尾语义继续使用；不额外创建编辑controller。
- 首次睡眠复用原协调器和设备今天、首帧 / resumed / 返回钩子及去重。模态 / 编辑期间延后提示，返回后核对事实；若已保存主睡眠，清除待提示。普通目的地切换不新建协调器或重复提示。
- 账本 / 复盘按目的地＋解析日期保留会话位置，最近7日期之外淘汰。事实以类型＋ID、Gap以原边界作锚点；刷新、子页返回、切换及尺寸变化恢复可见源，源删除回到最近保留项 / 可用范围。首次进入另一日期为顶部，无浏览状态磁盘写入。
- 底栏基础内容高度76，加底部SafeArea，水平16、间隔12；大字按实际内容增高，Scaffold为正文留实际栏高。选中态同时有文字、图标和下划线，状态无需仅靠颜色判断。

## 修改文件

本任务共42份文件：9份生产Dart、29份测试 / 辅助Dart、1份Android集成Dart、1份Python驱动、2份文档；共39份Dart。

| 生产文件 | 职责 |
| --- | --- |
| [lib/app/main_app.dart](/kiyodata/Projects/21-TimePetLedger/lib/app/main_app.dart) | 根入口、共享日期 / 滚动会话、创建 / 更多路由、返回和原首次睡眠协调器接入；保留原注入与表单构建合同 |
| [lib/app/navigation/ledger_shell.dart](/kiyodata/Projects/21-TimePetLedger/lib/app/navigation/ledger_shell.dart) | 新增三段底栏、更多入口、选中语义、实际SafeArea及随大字增长的栏高 |
| [lib/features/ledger/presentation/day_date_selection.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_date_selection.dart) | 新增会话内null跟随今天 / 明确CivilDate选择，无持久化 |
| [lib/features/ledger/presentation/day_read_scroll.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_read_scroll.dart) | 新增最近7日期、分目的地源锚点保存 / 恢复，尺寸改变及源删除回退 |
| [lib/features/ledger/presentation/ledger_date_header.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/ledger_date_header.dart) | 提取UI-T03日期头供两个根读取页共用，保留原测量、换行和手动日期能力 |
| [lib/features/ledger/presentation/day_ledger_page.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_page.dart) | 嵌入根shell、共享日期 / 忙碌状态 / 滚动；原事实编辑、删除、Gap操作和完整睡眠入口 |
| [lib/features/ledger/presentation/day_ledger_timeline.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_ledger_timeline.dart) | 仅为原事实 / Gap行包装源锚点；原样式、格式化和回调不变 |
| [lib/features/ledger/presentation/day_summary_page.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/ledger/presentation/day_summary_page.dart) | 用原控制器承接根选择，摘要改日 / 今天同步回根层 |
| [lib/features/review/presentation/review_context_page.dart](/kiyodata/Projects/21-TimePetLedger/lib/features/review/presentation/review_context_page.dart) | 根读取入口与日期 / 滚动适配；仅正式savedDate更新根选择，原表单flush及读取展示保留 |

现有app回归入口改为实际根控件 / 更多 / 创建选择器；旧诊断文案断言改为等价投影 / 源身份 / 覆盖断言。原正式事实、原始草稿、冲突、独立精度、提交后收尾与删除断言保留。共享测试辅助只负责定位，Gap操作继续直接走原入口。相对快照检查没有既有测试减少expect数量，但这只是辅助检查，最终仍逐项自审语义和源身份。

测试、辅助与平台文件完整清单：

- [integration_test/ui_t04_navigation_test.dart](/kiyodata/Projects/21-TimePetLedger/integration_test/ui_t04_navigation_test.dart)
- [test/app/basic_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/basic_recording_flow_test.dart)
- [test/app/bootstrap/app_bootstrap_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/bootstrap/app_bootstrap_test.dart)
- [test/app/day_ledger_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_entry_test.dart)
- [test/app/day_ledger_goal_rhythm_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_ledger_goal_rhythm_test.dart)
- [test/app/day_summary_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_summary_entry_test.dart)
- [test/app/day_summary_recalculation_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/day_summary_recalculation_flow_test.dart)
- [test/app/gap_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/gap_recording_flow_test.dart)
- [test/app/goal_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/goal_entry_test.dart)
- [test/app/goal_rhythm_closure_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/goal_rhythm_closure_test.dart)
- [test/app/recording_goal_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/recording_goal_flow_test.dart)
- [test/app/recording_rhythm_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/recording_rhythm_flow_test.dart)
- [test/app/review_closure_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_closure_flow_test.dart)
- [test/app/review_context_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_context_entry_test.dart)
- [test/app/review_deletion_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_deletion_flow_test.dart)
- [test/app/review_form_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_form_entry_test.dart)
- [test/app/review_route_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_route_flow_test.dart)
- [test/app/review_submission_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/review_submission_flow_test.dart)
- [test/app/sleep_draft_entry_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_draft_entry_test.dart)
- [test/app/sleep_editing_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_editing_flow_test.dart)
- [test/app/sleep_first_open_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_first_open_flow_test.dart)
- [test/app/sleep_note_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_note_flow_test.dart)
- [test/app/sleep_recording_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_recording_flow_test.dart)
- [test/app/sleep_submission_flow_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/sleep_submission_flow_test.dart)
- [test/app/theme/time_ledger_theme_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/theme/time_ledger_theme_test.dart)
- [test/app/ui_t04_navigation_test.dart](/kiyodata/Projects/21-TimePetLedger/test/app/ui_t04_navigation_test.dart)
- [test/support/app_recording_navigation.dart](/kiyodata/Projects/21-TimePetLedger/test/support/app_recording_navigation.dart)
- [test/support/app_sleep_navigation.dart](/kiyodata/Projects/21-TimePetLedger/test/support/app_sleep_navigation.dart)
- [test/support/ledger_date_selection.dart](/kiyodata/Projects/21-TimePetLedger/test/support/ledger_date_selection.dart)
- [test/support/root_navigation.dart](/kiyodata/Projects/21-TimePetLedger/test/support/root_navigation.dart)
- [tool/ui_t04_android_navigation.py](/kiyodata/Projects/21-TimePetLedger/tool/ui_t04_android_navigation.py)

文档：本报告及[UI_DIRECTION_3_IMPLEMENTATION_PLAN.md](../planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md)，仅更新UI-T04交付状态和追加执行记录，其他UI-D决定及历史阶段记录保留。

## 验证结果

Flutter / Dart路径：/home/tokiya/Projects/00-develop/flutter/bin。全部Flutter命令带--no-pub，无依赖安装。

| 实际命令 / 范围 | 结果 | 日志 |
| --- | --- | --- |
| dart format 本次39份Dart；dart format --output=none --set-exit-if-changed 同一集合 | 最终各39份、0需格式化 | /tmp/ui-t04-format-final.log |
| flutter analyze --no-pub | No issues found | /tmp/ui-t04-analyze-final.log |
| TZ=Asia/Shanghai flutter test --no-pub test/app test/features/ledger/presentation test/features/review/presentation | 282通过，4项按时区条件跳过 | /tmp/ui-t04-regression-final.log |
| TZ=Asia/Shanghai flutter test --no-pub test/app/ui_t04_navigation_test.dart，实际CJK字体和截图环境见下方 | 3通过，9组手机 / 大字布局；原始SDK对比度估计失败另记 | /tmp/ui-t04-capture.log |
| python3 tool/ui_t04_android_navigation.py --screenshots 下方截图目录；驱动运行flutter run --no-pub -d emulator-5554 -t integration_test/ui_t04_navigation_test.dart | 1个实际Android场景及框架tearDown通过，15个真实操作阶段 | /tmp/ui-t04-android-driver.log、/tmp/ui-t04-android-flutter.log |
| git diff --check；本次增量 / 新文件自审；文档引用与截图路径检查 | 通过 | 最终终端检查 |

282项集合包含指定的day_ledger_entry、gap_recording_flow、sleep_first_open_flow、review_route_flow、goal_entry，以及启动、活动 / 睡眠 / 复盘草稿、事实更正 / 删除、摘要重算和提交后失败闭环。时区条件跳过是既有DST / 特定日长用例，不把跳过写成通过；本任务未改日期边界算法，UI-T03的DST平台证据作为前置留存，没有重跑其不同TZ专用集合。各次测试有重叠，不相加声称唯一用例数。

新增三个app场景使用真实原生SQLite / 文件草稿夹具：共享日期、创建取消、根返回、摘要改日、复盘草稿日期与正式savedDate分界、午夜固定 / 跟随；源锚点在重读 / 模态 / 子页 / 切页 / resize / 删除后的恢复和7日期淘汰；320 / 360 / 412宽×文字1 / 1.5 / 2、长中文 / 多行emoji与底部安全区。账本、复盘、创建、更多各捕获9组，共36张widget截图。正文底部、按钮至少48、无布局异常有断言。

Android模拟器Medium_Phone，emulator-5554，1080×2400、density420。实际adb触摸打开创建 / 取消、复盘 / 返回、更多 / 摘要 / 返回、活动表单，触摸文本框并用系统输入123456；第一次BACK关闭真实键盘并保持同一个表单及输入，第二次BACK返回并确认草稿已flush、正式事实数量不变；再实际旋转横屏并恢复竖屏，日期和动作保持、没有首次睡眠重复提示。测试注入隔离NativeDatabase.memory真实SQLite，不读取 / 写入用户正式库或用户草稿；此证据不等价于强停后的磁盘恢复。驱动恢复原旋转设置，结束自身Flutter启动进程。

Android触控目标、标签guideline通过；SDK textContrastGuideline实际执行，默认Ahem测试路径通过。实际CJK捕获下，“今天 / 刷新账本”和“记录一笔”仍有采样估计失败（主动作估计2.80，日志保留）；不能记作SDK全部通过。共享RenderedTextContrast按有效RenderParagraph / RenderEditable前景颜色与实际背景验证3 / 4.5门槛通过。未为消除采样诊断改动已采纳主题。这是检测限制，未外推为所有字体 / 平台的全面对比度验收。

截图复现命令：

```sh
TZ=Asia/Shanghai \
UI_T04_FONT_PATH=/usr/share/fonts/wenquanyi/wqy-zenhei/wqy-zenhei.ttc \
UI_T04_CAPTURE_DIR=/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04 \
/home/tokiya/Projects/00-develop/flutter/bin/flutter test --no-pub \
test/app/ui_t04_navigation_test.dart
```

/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04替换为下节绝对目录。字体仅由测试FontLoader加载，没有添加生产字体 / pubspec依赖。widget中部分emoji仍为缺字方框，原始多行内容及布局断言保留；实际Android系统字体的🐾字形已在设备截图核对，不能用widget缺字截图声称所有emoji字形完整。

## 实际截图与人工核验

目录：/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04。

以下为生产MainApp / AppBootstrap实际渲染，不是生成效果图。Android为adb屏幕捕获，11张；文件名是即将执行的操作，截图在该操作之前拍摄，下面标签按实际画面说明。Android now显式注入2026-10-03 12:00，widget长文本夹具固定2026-10-02；不是把日期文案写死。

- [Android根账本，返回及旋转后](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-finished.png)
- [Android创建选择器](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-cancel_creation.png)
- [Android根复盘读取](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-back_to_ledger.png)
- [Android更多选择器](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-summary.png)
- [Android活动表单与真实键盘](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-keyboard_back.png)
- [Android键盘关闭后的同一表单](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-form_back.png)
- [Android横屏根布局](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-restore_portrait.png)
- [320宽 / 2倍文字账本](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/ledger-320.0-2.0.png)
- [320宽 / 2倍文字创建选择器](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/create-320.0-2.0.png)
- [360宽 / 1倍文字复盘长文本](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/review-360.0-1.0.png)

![UI-T04 Android根账本实际截图](/home/tokiya/.codex/visualizations/2026/10/03/01a10254-baa9-7300-b570-bc4cd8fcd15a/ui-t04/android-finished.png)

实际查看上述代表画面并对照两张选定图：三段底栏与中央较宽青色主动作已落地，日期头 / 连续时间轴保持，创建 / 更多功能分组、根复盘与编辑返回清楚。大字底栏增长、日期换行，正文在可滚动区域内；横屏为同一手机shell，不提前实现Web宽屏方案。原表单展示尚未改造，正式复盘结果卡尚未加入。

## 未执行项与停止点

- 未运行实体手机、真实Web浏览器Tab / Escape / resize / 同源刷新、Android强停重开与磁盘草稿恢复。UI-T04改变根读取会话和入口，复用原表单controller与flush；本次平台证据限实际导航、键盘 / 返回、旋转和当前进程内SQLite草稿写入。
- 未重跑全MVP / 全平台发布验收；旧Epic平台集成驱动的七按钮定位未在本任务迁移，也没有将其算作本次通过。UI-T12须按入口变化更新并执行对应平台闭环。
- SDK实际CJK原始文字对比度采样失败及widget部分emoji缺字按上文留存，没有未解决的本任务产品 / 领域决定。
- 未执行UI-T05–UI-T12或Epic 10，未改主题 / 表单 / 数据层，未提交或推送。下一可指定任务为UI-T05；需负责人另行指定。

UI-T04完成后停止。整个主页和方案三改造不标记完成。
