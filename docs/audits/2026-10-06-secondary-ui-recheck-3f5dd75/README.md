# 已提交 UI 修改复核

本次复核提交 3f5dd75，并与 P1/P2 之前的 38f8ffe 对照。共捕获45个状态，40张截图接受为证据，5张因环境或过渡状态拒收。17个 UI 项中11项达到当前复核范围，6项仍部分完成；独立菜单页通过。未修改应用源码，未执行事实删除/归档/清空，未正式提交新目标或复盘。

## 逐项核对

| 编号 | 优先级 | 结论 | 核对位置 | 实际结果 | 证据步骤 | 源码 |
| --- | --- | --- | --- | --- | --- | --- |
| UI-01 | P1 | 通过 | 统一弹层与页面主题 | 根 MaterialApp 使用 homeTheme；目标校验、睡眠时段、日期/时分、确认弹窗与复盘均为浅色纸面。 | 2, 16, 24, 32, 33, 34, 37, 44 | lib/app/main_app.dart:78 |
| UI-02 | P1 | 部分完成 | 时间分布说明响应 | 390×844 可打开说明并关闭；844×390 下说明与刷新入口全部消失。高度小于 520 的 tight 分支将两者一起隐藏。 | 1, 2, 3, 4 | lib/features/ledger/presentation/home/home_shell.dart:153 |
| UI-03 | P1 | 通过 | 新建目标校验留在表单 | 空名称点击保存后，表单仍在，显示红色“先给目标起个名字”；没有创建目标。 | 42, 44 | lib/features/goals/presentation/goal_management_page.dart:1224 |
| UI-04 | P1 | 通过 | 编辑返回保留详情上下文 | 活动与睡眠从详情进入编辑，直接返回后均保留原详情；本次未提交实际修改。 | 25, 26, 27, 29, 30, 35 | lib/features/ledger/presentation/fact_detail_page.dart:79 |
| UI-05 | P2 | 通过 | 明确目标历史行职责 | 历史行呈阅读内容，提供标题/日期/区间/时长语义，没有按钮角色；不新增详情导航。 | 14, 45 | lib/features/goals/presentation/goal_management_page.dart:731 |
| UI-06 | P1 | 部分完成 | 窄屏日历完整一周 | 390px 稳定状态显示七列；320px 周日列在初始画面被裁切，仍需横向滚动。源码固定 336px 七格，不满足全部窄屏完整可见。 | 10, 41 | lib/features/ledger/presentation/day_ledger_date_dialog.dart:184 |
| UI-07 | P1 | 部分完成 | 详情辅助功能语义 | 标题与时长已进入辅助树；开始/结束及入睡/醒来仍是 disabled textbox，只暴露标签，没有实际日期时间值。只读 DOM 查询中对应 textarea.value 为空。 | 25, 27, 29, 35 | lib/features/ledger/presentation/fact_detail_page.dart:302 |
| UI-08 | P2 | 部分完成 | 统一删除/归档/清空确认 | 主题、主要对象和结果文案改善；睡眠显示完整跨夜区间。活动删除仍为整页，睡眠/目标/清空为弹窗；有引用目标的“删除”最终仍展示归档确认，入口职责未完全统一。所有确认均取消。 | 16, 17, 24, 28, 31 | lib/features/ledger/presentation/sleep/sleep_recording_page.dart:121 |
| UI-09 | P2 | 通过 | 设置去除重复标题 | 设置首页和界面设置不再重复展示同名大标题；关于正文保留产品名。 | 19, 20, 21 | lib/features/settings/presentation/settings_page.dart:208 |
| UI-10 | P2 | 通过 | 展示当前/未设置状态 | 设置摘要和热力图选项明确显示“未设置”，不暗中选择默认值。本次没有改变持久化偏好，已设值分支仅按源码核对。 | 19, 20 | lib/features/settings/presentation/settings_page.dart |
| UI-11 | P2 | 通过 | 复盘统一主题 | 复盘入口、表单、更多菜单和放弃确认均采用浅色主题；内容布局本身仍较密集，未视为本条范围内新增要求。 | 36, 37, 38, 39 | lib/features/review/presentation/review_form.dart |
| UI-12 | P2 | 部分完成 | 日期时间中文化 | 日期和时分选择器正文/按钮已中文；Back、Dismiss 与 Popup menu 等系统辅助名称仍为英文。原报告已承认 Back 边界，不能标为全面中文化。时分滚轮在辅助树中仅是数字 generic，键盘与真实读屏仍待测。 | 12, 27, 32, 33, 34 | lib/features/ledger/presentation/sleep/sleep_recording_page.dart |
| UI-13 | P2 | 部分完成 | 图表时长标尺与色阶 | 柱状图增加小时单位、顶部刻度和各日读数；热力图增加“少/多”色块及未来/无投入解释，但缺少色阶对应时长范围。源码分档为 <1h、<2h、<4h、≥4h，图例未说明。 | 14, 15, 45 | lib/features/goals/presentation/goal_management_page.dart:594 |
| UI-14 | P2 | 通过 | 演示目标创建日期 | 新端口自动演示数据中的目标显示创建于10月4日，与 10月6日测试日的前两天一致。旧数据库已存在的演示事实不会因源码调整自动重写。 | 14, 45 | lib/dev/seed_demo_data.dart:37 |
| UI-15 | P2 | 通过（当前版本） | 关于页显示应用版本 | 页面显示 0.1.0 · 构建 1，与 pubspec.yaml 的 0.1.0+1 一致；通过装配注入常量，没有自动读取构建元数据，后续升版需同步常量。 | 21, 22 | lib/app/app_version.dart:5 |
| UI-16 | P2 | 通过 | 桌面二级页最大宽度 | 1440×900 的关于页和目标详情正文居中收窄；目标/设置/详情源码均设置 maxWidth 640。390px 保持流式布局。 | 22, 45 | lib/features/goals/presentation/goal_management_page.dart:971 |
| UI-17 | P2 | 通过 | 复盘放弃草稿确认 | 选择放弃此复盘草稿后先出现确认；点击继续填写可返回表单，没有执行丢弃。 | 37, 38, 39 | lib/features/review/presentation/review_form.dart:149 |
| 菜单 | P1 | 通过 | 独立菜单页 | 独立页面仅有“我的目标 / 设置”；目标和设置采用替换菜单页方式，返回回到首页。 | 5, 12, 18, 19 | lib/features/ledger/presentation/home/home_menu_page.dart:27 |

## 验证

| 检查 | 结果 | 说明 |
| --- | --- | --- |
| 提交 | 核实 | 列出的5个提交确实存在；复核开始 git status 干净。最终新增本报告与证据，未再次提交。 |
| Web构建 | 通过 | flutter build web --no-pub 成功；有 wasm dry-run / Cupertino 字体提示。 |
| 格式 | 通过 | 对38f8ffe..HEAD的24个 Dart 文件检查，0 changed，退出码0。 |
| 分析 | 仅既存info | flutter analyze --no-pub lib test：2条 curly_braces_in_flow_control_structures info；退出码1，不等于零问题。 |
| 测试 | 基线一致，未全通过 | 当前与38f8ffe各782个可见测试：665通过、108失败、9跳过；失败文件+名称+结果逐条集合一致，新增0、修复0。 |
| 原报告947项 | 未复现 | 本次JSON共有917个 testDone 事件，含135个隐藏加载项；剔除后782个可见测试。947不是本次可确认的统计口径。 |

完整日志与失败集合：[validation](validation/test-comparison.json)。测试命令在当前工作区和 git archive 38f8ffe 的临时快照中分别运行，共用既有依赖缓存，没有安装依赖。

## 截图步骤

| 步骤 | 操作/位置 | 健康情况 | 观察 | 截图 |
| --- | --- | --- | --- | --- |
| 01 | 首页 390px | 通过 | 说明与刷新入口可见。 | [截图](screenshots/01-home-390.jpg) |
| 02 | 打开时间分布说明 | 通过 | 浅色弹窗且内容完整。 | [截图](screenshots/02-distribution-open.jpg) |
| 03 | 关闭说明 / 刷新 | 通过 | 回到首页，刷新响应。 | [截图](screenshots/03-distribution-close.jpg) |
| 04 | 首页 844×390 | 有问题 | 说明与刷新入口消失。 | [截图](screenshots/04-home-landscape-actions-hidden.jpg) |
| 05 | 独立菜单页 | 通过 | 仅目标与设置。 | [截图](screenshots/05-menu-page.jpg) |
| 06 | 目标页首次读取 | 拒收 | 调试服务器中断时读取失败；步骤13重新验证。 | [截图](screenshots/06-goals-list.jpg) |
| 07 | 首次新建目标 | 拒收 | 背景仍是读取失败，不作最终主题证据；步骤42替代。 | [截图](screenshots/07-goal-new-dialog.jpg) |
| 08 | 首次空名称校验 | 拒收 | 背景受环境失败影响；步骤44替代。 | [截图](screenshots/08-goal-empty-validation-stays.jpg) |
| 09 | 恢复后的首页 | 通过 | 新端口恢复，可正常加载演示数据。 | [截图](screenshots/09-recovered-home.jpg) |
| 10 | 日历 320px | 有问题 | 周日列被裁切，需要横向滚动。 | [截图](screenshots/10-calendar-320.jpg) |
| 11 | 日历切至 390px | 拒收 | 视口切换尚未稳定；步骤41替代。 | [截图](screenshots/11-calendar-390.jpg) |
| 12 | 恢复后的菜单 | 通过 | 独立菜单正常。 | [截图](screenshots/12-menu-recovered.jpg) |
| 13 | 目标列表加载 | 通过 | 演示目标读取成功。 | [截图](screenshots/13-goals-loaded.jpg) |
| 14 | 目标柱状图 / 日期 / 历史 | 基本通过 | 日期正确、小时标尺可读、历史行供阅读。 | [截图](screenshots/14-goal-bar-date-history.jpg) |
| 15 | 目标热力图图例 | 有问题 | 少/多色块没有时长范围。 | [截图](screenshots/15-goal-heat-legend.jpg) |
| 16 | 目标归档确认 | 通过 | 对象与保留历史说明清楚。 | [截图](screenshots/16-goal-archive-confirm.jpg) |
| 17 | 有引用目标删除确认 | 部分完成 | 实际结果为归档，入口仍叫删除。 | [截图](screenshots/17-goal-delete-confirm.jpg) |
| 18 | 目标列表返回首页 | 通过 | 不会重新返回菜单。 | [截图](screenshots/18-goals-back-home.jpg) |
| 19 | 设置首页 | 通过 | 单层标题和当前值摘要。 | [截图](screenshots/19-settings-values.jpg) |
| 20 | 界面设置未设置状态 | 通过 | 明确未设置，不自动选中。 | [截图](screenshots/20-interface-unset.jpg) |
| 21 | 关于版本 | 通过 | 0.1.0 · 构建1。 | [截图](screenshots/21-about-version.jpg) |
| 22 | 关于桌面布局 | 通过 | 正文居中收窄。 | [截图](screenshots/22-about-desktop.jpg) |
| 23 | 高级设置数量 | 通过 | 对象计数与清空入口清楚。 | [截图](screenshots/23-advanced-counts.jpg) |
| 24 | 清空确认 | 通过 | 删除范围与保留设置说明清楚；已取消。 | [截图](screenshots/24-clear-confirm.jpg) |
| 25 | 活动详情语义 | 有问题 | 可见区间值未进入辅助树。 | [截图](screenshots/25-activity-detail-semantics.jpg) |
| 26 | 活动编辑器 | 通过 | 浅色主题，保留草稿返回。 | [截图](screenshots/26-activity-edit.jpg) |
| 27 | 活动编辑返回详情 | 通过 | 原详情留在返回栈。 | [截图](screenshots/27-activity-edit-back-detail.jpg) |
| 28 | 活动删除确认 | 部分完成 | 整页确认，与其他弹窗形态不同；已取消。 | [截图](screenshots/28-activity-delete-confirm.jpg) |
| 29 | 睡眠详情语义 | 有问题 | 入睡/醒来值未进入辅助树。 | [截图](screenshots/29-sleep-detail-semantics.jpg) |
| 30 | 睡眠编辑器 | 通过 | 完整原区间与保存边界清楚。 | [截图](screenshots/30-sleep-editor.jpg) |
| 31 | 睡眠删除确认 | 通过 | 完整跨夜区间和跨日影响说明；已取消。 | [截图](screenshots/31-sleep-delete-confirm.jpg) |
| 32 | 睡眠日期时间弹层 | 基本通过 | 正文中文，Dismiss辅助名仍英文。 | [截图](screenshots/32-sleep-time-sheet.jpg) |
| 33 | 中文时分选择器 | 部分完成 | 正文已中文，滚轮数字的可操作语义待补。 | [截图](screenshots/33-chinese-time-picker.jpg) |
| 34 | 中文日期选择器 | 通过 | 月份、星期与动作中文。 | [截图](screenshots/34-chinese-date-picker.jpg) |
| 35 | 睡眠编辑返回详情 | 通过 | 保留原详情。 | [截图](screenshots/35-sleep-back-detail.jpg) |
| 36 | 复盘首页 | 通过 | 浅色主题，事实说明仍密集。 | [截图](screenshots/36-review-home.jpg) |
| 37 | 复盘表单 | 通过 | 主题一致；未正式保存。 | [截图](screenshots/37-review-form-theme.jpg) |
| 38 | 复盘更多菜单 | 通过 | 保留/放弃草稿两个动作明确。 | [截图](screenshots/38-review-more.jpg) |
| 39 | 复盘放弃确认 | 通过 | 继续填写可取消放弃。 | [截图](screenshots/39-review-discard-confirm.jpg) |
| 40 | 复盘返回首页 | 通过 | 退出表单正常。 | [截图](screenshots/40-review-return-home.jpg) |
| 41 | 390px 日历稳定状态 | 通过 | 完整七列可见。 | [截图](screenshots/41-calendar-390-stable.jpg) |
| 42 | 新目标稳定状态 | 通过 | 轻色表单保持主题。 | [截图](screenshots/42-new-goal-stable.jpg) |
| 43 | 空名称即时校验 | 拒收 | 动画中的错误文字透明度未稳定；步骤44替代。 | [截图](screenshots/43-new-goal-empty-validation.jpg) |
| 44 | 空名称校验稳定状态 | 通过 | 表单保留且错误文字红色可读。 | [截图](screenshots/44-new-goal-error-stable.jpg) |
| 45 | 目标桌面布局 | 通过 | 图表和历史正文约640px居中。 | [截图](screenshots/45-goal-desktop-width.jpg) |

## 证据限制

截图与浏览器辅助树不能证明完整无障碍合规；未使用真实读屏器，未穷举大字号/键盘/平台版本。事实提交成功、冲突处理及删除后的持久化效果由既有测试和源码核对，本次浏览器只验证确认与取消。UI-10已设值分支主要按源码核对。UI-15是人工同步常量，非自动构建版本读取。进入编辑器可能产生测试草稿，均未提交为事实。目标首次读取异常在新端口重新加载后消失，因此不登记产品失败。

自动审批曾拒绝将调试服务器绑定0.0.0.0，因为会将本机构建暴露到全部接口；后续127.0.0.1:8769已成功恢复复核，没有扩大网络暴露。

## 后续补修建议

| 项 | 建议验收 |
| --- | --- |
| UI-02 | 高度小于520的横屏也能找到说明与刷新入口。 |
| UI-06 | 320px初始日历完整显示七个星期列，保持足够触控与文字可读性；如改验收为可滑动，需明确调整完成标准。 |
| UI-07 | 辅助树同时读出字段名和完整值，特别是日期时间与解释字段；补真实读屏/键盘复核。 |
| UI-08 | 明确统一的确认层级及危险操作；有引用目标入口能清楚表达归档结果。 |
| UI-12 | 系统Back/Dismiss等名称中文化；时分滚轮有可识别、可操作的辅助语义。 |
| UI-13 | 图例列明颜色对应的小时范围，并与实际分档一致。 |
