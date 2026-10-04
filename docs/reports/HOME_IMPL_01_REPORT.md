# HOME-IMPL-01 · 主页样板实施进展

## R06 对齐修订（取代第二轮的睡眠详情布局）

**用户视觉验收：通过。** 用户查看本轮结果后明确回复“可以通过”。确认范围为本轮按R06还原的睡眠详情；配色最终微调、设备验收及其他页面实施仍按各自范围推进。以下“待视觉确认”为本轮提交审阅时的历史状态，由此记录更新。

用户明确要求直接落实已确认HTML原型，现有功能阶段UI字段不是必须常驻的清单。依据 `reading-management-visual-spec.html` R06：睡眠面板标题改为主睡眠/小睡；当日片段、当日时长在前，分隔线后为完整睡眠的入睡、醒来、完整时长。采用左右信息行，大字/窄屏自动上下排列；删去重复正文标题和端点精度说明，端点约字独立保留。源日期跨年时补年份。有效备注仍可读，管理与删除使用次级主题文字色并进入原睡眠编辑流程。调色仍留最后。

修改文件：`lib/features/ledger/presentation/day_ledger_fact_details.dart`、`test/app/home_visual_sample_test.dart`、`test/features/ledger/presentation/day_ledger_timeline_layout_test.dart`及本报告。主页概览沿用已精简版本。

实际验证：
- 三个Dart文件format检查0 changed；`flutter analyze --no-pub`通过。
- `TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc HOME_CAPTURE=/tmp/opencode/home-r06 flutter test --no-pub test/app/home_visual_sample_test.dart test/features/ledger/presentation/day_ledger_timeline_layout_test.dart test/app/sleep_editing_flow_test.dart`：14通过，日志`/tmp/opencode/home-r06.log`。
- 随后扩展样板测试，在320/360/412与1/1.5/2倍字的所有组合打开睡眠详情并进入编辑；`TZ=Asia/Shanghai flutter test --no-pub test/app/home_visual_sample_test.dart`通过，日志`/tmp/opencode/home-r06-matrix.log`。
- 已查看真实Flutter截图 `/tmp/opencode/home-r06/sleep-details-360.png`：标题、左右信息行及两分组符合R06结构。截图来自widget渲染；用户视觉确认及平台验收仍待完成。

## 第二轮：详情信息重排与文案精简

用户明确要求减少解释性文字，并将配色微调留到最后。本轮沿用 `lib/app/theme/time_ledger_theme.dart` 的 ThemeData/ColorScheme；详情和概览继续消费主题，不加入局部硬编码颜色。颜色尚未获最终认可。

- `day_ledger_fact_details.dart`：完整活动/睡眠名称、两端完整日期时间和完整时长成组呈现；去掉逐行“开始/结束/准确/大约/睡眠类型”等重复标签。约字紧贴对应时间，独立端点精度保留。只有当日切片不同于完整事实时显示“计入月日”及片段时长；同区间不重复。已有目标、节奏、适用细节与备注保留，编辑删除回调不变。
- `day_ledger_overview.dart`：主页简化为“其中想不起来…”，包含关系继续在时间分布说明层解释。
- `day_ledger_timeline_layout_test.dart`：更新详情读取断言，继续核验近似醒来/准确入睡及当日归属。
- 实际执行：三文件格式检查0 changed；`flutter analyze --no-pub`通过；`TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc HOME_CAPTURE=/tmp/opencode/home-round2 flutter test --no-pub test/app/home_visual_sample_test.dart test/features/ledger/presentation/day_ledger_timeline_layout_test.dart test/app/day_ledger_editing_flow_test.dart`，17项通过。截图为真实Flutter widget渲染，位于`/tmp/opencode/home-round2/{home-360,sleep-details-360}.png`。
- 第二轮待视觉审阅；仍不表示Android平台验收或整项完成。第一轮下述报告作为历史保留。

2026-10-04。状态：**实现与局部工程验证已交付；Android平台与用户视觉验收待完成，不标Task完成。**

用户确认节点三第二批后要求继续，授权主页样板。依据 `docs/planning/home-visual-calibration-spec.html` 和 `PRODUCT_PAGE_SYSTEM_DESIGN.md`；后续UI-T未自动实施。

## 本轮增量

- `day_ledger_page.dart`：紧凑主页、成功提示移除、完整睡眠折叠、日期层与更多接线；独立页面菜单关闭不重复刷新。
- `day_ledger_timeline.dart`：移除常驻图标/编辑删除行，时长按内容占宽，标题不足四字宽时换行；整行详情，Gap直接补记；保留原锚点和源身份。
- 新增 `day_ledger_fact_details.dart`：只读已提交快照，完整源时间、端点精度、目标、解释、备注和适用原因/恢复细节；编辑/删除回原流程。睡眠管理与删除进入原睡眠表单，不新增删除服务。
- `ledger_date_header.dart`、`day_ledger_date_dialog.dart`：主页紧凑日期，手动输入/今天/跟随状态移入选择层，其他调用保留原显示。
- `day_ledger_overview.dart`、`day_ledger_time_bar.dart`：主页紧凑覆盖/12高比例条，窗口与图例进入说明；投影与刻度算法沿用。非主页默认概览保留。
- `day_read_scroll.dart`：仅新增可配置padding，主页去掉顶部额外16；会话锚点合同沿用。
- `lib/app/main_app.dart`、`lib/app/navigation/ledger_shell.dart`：主页更多提供刷新与说明，主页48高顶栏和底部主动作圆角；保留首次睡眠、日期共享和草稿路由。
- 新增 `test/app/home_visual_sample_test.dart`，更新相关主页/时间轴/日期/导航/Gap/睡眠/编辑测试及 `test/support/{ledger_date_selection,root_navigation}.dart`，适配新层级并保留持久化与失败断言。

没有修改领域、application、data、数据库、依赖及表单实现。当前工作区大量既有未提交增量保留，没有reset或提交。

## 实际验证

- `dart format --output=none --set-exit-if-changed <本轮24个Dart文件>`：0 changed。
- `flutter analyze --no-pub`：No issues found。
- `git diff --check`：通过。
- `TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc HOME_CAPTURE=/tmp/opencode/home-implementation flutter test --no-pub` 加下列文件：48通过、2跳过（非对应DST时区用例），日志 `/tmp/opencode/home-validation.log`：
  - `test/app/home_visual_sample_test.dart`
  - `test/features/ledger/presentation/day_ledger_page_test.dart`
  - `test/features/ledger/presentation/day_ledger_overview_layout_test.dart`
  - `test/features/ledger/presentation/day_ledger_timeline_layout_test.dart`
  - `test/features/ledger/presentation/day_ledger_time_bar_test.dart`
  - `test/app/day_ledger_editing_flow_test.dart`
  - `test/app/gap_recording_flow_test.dart`
  - `test/app/sleep_editing_flow_test.dart`
  - `test/app/sleep_first_open_flow_test.dart`
- `TZ=Asia/Shanghai flutter test --no-pub test/app/ui_t04_navigation_test.dart`：通过，`/tmp/opencode/home-nav-final.log`。
- `day_ledger_timeline_test.dart`（feature）及 `day_ledger_resolution_flow_test.dart`（app）：后续运行通过，`/tmp/opencode/home-legacy4.log` 中当时剩余另一app时间轴旧文案失败已修正；`TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_timeline_test.dart` 最后通过，`/tmp/opencode/home-timeline-app.log`。
- 矩阵覆盖320/360/412和1/1.5/2倍率，时间轴长文本、48触控/标签/对比度，主页状态与详情跳转；跨日源ID、删除回滚/幂等/收尾、Gap草稿及首次睡眠沿用真实仓储回归。

## 截图与未完成验收

- `/tmp/opencode/home-implementation/home-360.png`
- `/tmp/opencode/home-implementation/sleep-details-360.png`

这两张为实际Flutter组件在widget测试中的渲染，不是HTML也不是Android设备截图。样例修正为主页已确认数据（Unknown准确、无标题/目标/解释；睡眠近似入睡且准确醒来），已交代11小时、Unknown30分钟、Gap13小时。视口360×800、模拟系统inset上/下各24、注入时间10月4日09:41。

尚存视觉差异：首条轨道约y274（稿y264）；Gap补记按钮的下部接近底栏，目标稿首段Gap应完整可见；底栏中央宽度仍略窄于168目标，选中态仍有下划线；详情采用82%高面板，信息纵向间距较目标稿宽。需继续局部校准并由用户确认，不能凭测试通过替代视觉认可。

`adb devices`无连接设备。未执行本轮Android触控、安全区、系统返回和真实设备截图；未完成新的Web平台验收、未运行全仓测试。两个DST时区专项跳过不算通过。本轮只交付主页样板进展，不推广其他页面，不更新旧UI-T完成状态。
