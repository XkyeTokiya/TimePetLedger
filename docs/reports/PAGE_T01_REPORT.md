# PAGE-T01 · 还原清单与可操作视觉夹具

2026-10-04。用户授权执行PAGE-T01，并要求每个任务完成后提交。**本任务交付完成；页面视觉验收未通过，继续保持原状态。**

## 交付

- [冻结清单](../planning/PAGE_T01_RESTORATION_CHECKLIST.md)：六屏区块树、显隐/并排、间距归属、数据和路由。
- `test/support/page_t01_fixture.dart`：独立真实SQLite、固定时钟/ID，生产仓储及服务。
- `test/app/page_t01_visual_fixture_test.dart`：4项可重现测试，覆盖六屏和真实保存/冲突/取消。
- `tool/capture_page_t01_prototypes.py`：使用已安装Chromium截取原型六屏，不修改原型。
- `docs/reports/assets/page-t01/`：6张Flutter现状与6张HTML原型，均为360×800。

## 六屏截图与返工基线

| 屏号 | 原型 | Flutter现状 | 明确待返工差异 |
| --- | --- | --- | --- |
| V01 | [原型](assets/page-t01/prototype-V01.png) | [现状](assets/page-t01/V01.png) | 目标/节奏纵向；时间上下留白偏大；上下文/时长呈现不足；状态文字不是原型的草稿反馈 |
| V02 | [原型](assets/page-t01/prototype-V02.png) | [现状](assets/page-t01/V02.png) | 正式更正态已真实接入；端点卡与日期层级仍待T03还原 |
| V03 | [原型](assets/page-t01/prototype-V03.png) | [现状](assets/page-t01/V03.png) | 再写几句/目标未并排；最简输入的说明与空隙待T04整理 |
| V04 | [原型](assets/page-t01/prototype-V04.png) | [现状](assets/page-t01/V04.png) | 缺原型的第一步摘要构图，附件与保存条顺序不同；结构待T04 |
| V05 | [原型](assets/page-t01/prototype-V05.png) | [现状](assets/page-t01/V05.png) | 真实双端编辑/取消可用；卡片日期时间布局、完整时长提示待T03 |
| V06 | [原型](assets/page-t01/prototype-V06.png) | [现状](assets/page-t01/V06.png) | 冲突来自真实仓储；当前首层显示技术ID、未显示散步名称，目标/节奏纵向，待T02 |

这些截图是**Flutter widget测试渲染**与**Chromium HTML渲染**。IME、状态栏及安全区均为模拟；没有Android设备截图。Flutter键盘区域为空白，占位高度已注入；HTML键帽是原型示意。不得以本轮证据声称中文IME/平台验收通过。

## 数据与行为结果

- V01两端approximate，30分钟，SQLite草稿确实存在，保存服务可用。
- V06实际提交45分钟区间触发原子冲突，散步源ID/时间未改变，整理桌面未进入正式库，标题和时间仍在草稿；调整回30分钟后成功落库、清除草稿。
- V02完整跨日460分钟，起点approximate、终点exact；更正保存保持原ID和单条事实。
- V05改变时间及精度后取消，不改变controller、草稿及保存后的源事实。
- V03只凭合法第一步完成真实保存，次日为10月3日；V04展开聚焦概述，概述/反思能够真实保存。
- 各初始路由无自动键盘；表单通过真实Navigator push/pop，服务未缺失而禁用主保存。

规则依据：TB-002独立精度、Q-001次日、Q-011重叠原子拒绝、Q-012草稿隔离、Q-013完整源更正、Q-014近似传播、Q-023 Gap建议；未改变领域合同。

## 实际验证与复现

```sh
dart format test/support/page_t01_fixture.dart test/app/page_t01_visual_fixture_test.dart
dart format --output=none --set-exit-if-changed test/support/page_t01_fixture.dart test/app/page_t01_visual_fixture_test.dart
env TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc EDITOR_CAPTURE=/tmp/opencode/page-t01 flutter test test/app/page_t01_visual_fixture_test.dart
python3 tool/capture_page_t01_prototypes.py /tmp/opencode/page-t01
flutter analyze
```

结果：4项测试全部通过；静态分析No issues found；截图12张生成；Dart格式复查0处变化；三个本任务文档的相对链接全部存在，12张PNG均为360×800。首次调试修正了测试对现有冲突文字的查找、CivilDate字段断言和原生SQLite关闭时的异步排空；未据此修改生产行为。

## 工作区与限制

任务开始时已有大量已修改及未跟踪的页面、测试、设计和历史报告。此次新增独立夹具，保留旧`editor_visual_sample_test.dart`；本次提交只纳入PAGE-T01交付及任务清单状态，既有页面实现不归入本任务。本轮验证基于当前完整工作区，依赖其中已有的编辑页/主题等未提交工作；单独检出本任务提交不能当作完整UI实现快照。

T02–T04返工、T05用户视觉验收、T09实机验收仍待执行。未自动推进下一任务。
