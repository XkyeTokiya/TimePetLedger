# PAGE-T02 · 活动编辑返工

## 弹层与选择交互修订

修复活动弹层外层padding与内部Scaffold重复扣减键盘高度：仅弹层模式关闭内部resize，独立睡眠时间页仍正常resize。目标/节奏入口增加底色及展开强调，普通操作互斥展开；目标内容增加统一面板和间距。标签再次点击清除选择，移除空值选项；原因文本通过编辑直接清空，删除清空按钮。未添加保存提醒。目标面板属于本任务，不推给后续管理页。

表单测试、节奏细节测试通过，静态分析通过（测试辅助最后迁移后未再次分析）；手机部署命令成功。键盘修复来自重复inset定位，尚未完成现场截图复核；错误自动展开仍有独立逻辑，完整互斥错误路径与布局矩阵待验证，不宣称全任务完成。

## 底部时间层与平铺节奏首版

按用户确认的设计制作首版：活动正常/冲突时间入口共用底部弹层，支持拖动关闭、遮罩关闭及应用返回；键盘inset让位，内部内容可滚动。节奏外层仍可折叠，内部取消接续点/卡住/恢复的嵌套折叠；当前状态适用字段直接显示，原因快捷选项保留，接续点移到细节之后并标注选填。切换状态的原输入保留规则不变。

`flutter test test/features/ledger/presentation/recording_form_test.dart test/features/ledger/presentation/recording_rhythm_details_test.dart`通过；`flutter analyze`通过；改动Dart格式化完成。`flutter run -d 10AE9F37AJ000F0 --debug --no-resident`成功，新版已部署手机供体验。此次未完成完整布局矩阵和真机交互验收，任务仍待确认。

## 默认记得与直接时间输入

按用户本轮决定，新建且无草稿的活动默认选中“记得”；已有草稿及记录仍恢复原状态。删除“请选择是否记得…”提示。选择组边框改为前景绘制，避免子控件背景覆盖圆角边线。活动时间页进入即显示开始/结束日期时间输入，日历按钮是可选辅助，不再要求先开单端对话框；取消/应用及独立精度保留。睡眠页维持原入口。

验证：`flutter test test/features/ledger/presentation/recording_form_test.dart`通过，新增默认选中断言并迁移直接输入路径；`flutter analyze`通过。`flutter run -d 10AE9F37AJ000F0 --debug --no-resident`本轮成功，手机运行新版；完整时间操作及其他旧导航测试尚未完成回归，不标全任务完成。

## 手机现场检查（最新）

用户更换手机后识别V2417A，ADB序列10AE9F37AJ000F0。APK安装成功，Flutter等待debug连接失败，但ADB确认MainActivity处于RESUMED且实际显示新版。设备物理1260×2800、density560（3.5），逻辑360×800。通过实际点击Gap进入补记，再点击输入框唤起微信输入法；[未弹键盘截图](assets/page-t02/phone-editor.png)、[真实IME截图](assets/page-t02/phone-ime.png)。

观察确认：端点`00:00 → 20:46`无“约”，时长`约20小时46分钟`；初次进入不自动弹键盘；点击后真实键盘出现，保存条在IME上方。输入法高度与模拟232不同，目标/节奏在该状态需滚动。截图是10月4日空库的当前日Gap，不冒充V01固定30分钟样例。未正式保存示例事实，未验证中文候选输入/冲突闭环/旋转；仅上述现场检查有证据，不标全平台验收通过。debug连接失败日志`/tmp/opencode/page-t02-phone.log`。

## 时长近似显示与真机连接（最新补充）

按用户明确决定，活动摘要端点不显示“约”，只在近似时长前显示一次；两个精度字段和时间编辑层保持独立。夹具新增`10:30 → 11:00`与`约30分钟`断言，4项测试通过。

真实设备检测到TGR W10 / Android12 API31 / 39HUN24C28G04658。运行`flutter run -d 39HUN24C28G04658 --debug --no-resident`：APK构建成功，安装阶段ADB失败；随后`adb ... install -r -t --no-streaming ...`报告device not found，`adb devices -l`无连接设备。未启动新版、未取得真机截图、未验证真实IME。需恢复设备连接后继续；日志`/tmp/opencode/page-t02-device.log`。不将此尝试记为平台通过。

## 原型基准重做（最新）

用户否决此前局部调整，要求以原型效果重做。重新逐条读取HTML CSS：正文顶部12、标题20/起点64、主输入最小100及圆角12、记忆单外框连体组、时间上下12及底线、目标/节奏间8/顶部12、补充低强调展开行、保存条上下12。实现采用现有主题语义色，不添加局部颜色常量。

活动页启用EditorBody的可选prototypeSpacing，其他编辑页默认不变；补充组件新增可选disclosure形态。记忆文案改为“记得”，对应测试只迁移入口文案。技术编号入口已移除；原有同源冲突、草稿和保存结果断言保留。最新V01/V06图片替换本报告链接所指文件。

明确偏差：V06保留上一轮反馈决定的底部“调整当前记录时间”，不恢复原型高亮保存；冲突文案显示实际交集；错误底色、选中底色仍来自当前主题，与HTML有差异。IME仅模拟，不绘制系统键帽。尚不声称像素一致或用户视觉通过。

验证：六组专项首次69通过、1项触控高度失败，修正记忆组点击高度后复跑夹具+完整布局+旧三编辑页矩阵全部通过；静态分析无问题；16个改动Dart文件格式复查无变化。后续应用流程文件仅迁移“记得”入口文字，既存应用级失败未宣称解决。日志`/tmp/opencode/page-t02-redo-tests.log`、`page-t02-redo-final.log`。本轮停止等待视觉反馈，不推进下一任务。

## V06用户反馈修订

后续用户提供交互评审并授权吸纳。冲突时底部主动作改为“调整当前记录时间”，不再显示可提交的保存按钮；顶部与时间摘要的重复调整入口移除。统一进入双端时间层，取消保留冲突，应用后重新允许正式校验。冲突提示直接给出交集区间，近似输入明确为“按当前填写的估算时间”和“估算边界”，不改原子拒绝合同、不提供强制覆盖。“记录标识”改为低强调的“查看冲突记录编号”，详情明确技术编号用途。V06截图已更新，下文旧差异描述属于首轮记录。

修订验证：夹具、布局、表单与节奏共48项在最终对应运行中通过（初次运行46通过、2条旧文案断言失败，迁移后分别复跑；节奏旧时间入口亦改为明确调整入口）。新增断言验证冲突态没有保存/重复修改入口、交集11:00–11:15可读，真实调整后保存仍成功。flutter analyze无问题。状态仍待视觉确认，既存应用级失败状态不变。

2026-10-04。状态：实现及专项验证已交付，**待用户视觉审阅；应用级基线8项失败，整项未标完成**。

## 实现

修改 `lib/features/ledger/presentation/recording_form.dart`：

- 日期/入口轻量上下文、圆角主输入、同组记忆控件；Unknown隐藏输入但保留controller和草稿原文，原文有校验错误时仍可显示并修复。
- 时间行同排显示区间、独立近似和时长、修改入口；同日省略重复日期，跨日保留日期。
- 目标/节奏入口标准宽度并排，长目标或大字纵向；展开内容全宽。真实节奏错误才强制展开，冲突不再顺带展开节奏。
- 补充内容保留摘要、折叠错误定位。保存条显示草稿写入中、失败和保留状态。
- 冲突名称由现有repository只读补齐，读取失败回退事实类型/区间；FutureBuilder按冲突实例隔离，迟到结果不会覆盖新冲突。Unknown显示“想不起来”。技术ID通过“记录标识”对话框查看。
- 保留原保存、离开、草稿、部分成功和独立精度合同。未改领域、应用服务、数据库、依赖及主题色。

输入文本、时间、引用、冲突与草稿依据源提案§5–8、§27–28及Q-003/004/011/012/014；结构依据UI_IMPLEMENTATION_DESIGN§3–4及PAGE-T01冻结清单。

## 截图对照

360×800，DPR1，文字1倍，Asia/Shanghai，固定2026-10-02 12:00。沿用PAGE-T01真实SQLite场景；模拟安全区24/24，V01模拟IME232，V06无IME。不是实机截图。

| 屏 | 原型 | 返工后 |
| --- | --- | --- |
| V01 | [原型](assets/page-t01/prototype-V01.png) | [Flutter](assets/page-t02/V01.png) |
| V06 | [原型](assets/page-t01/prototype-V06.png) | [Flutter](assets/page-t02/V06.png) |

结构自查：主输入、记忆组、紧凑时间、并排目标/节奏、补充、保存条顺序一致。页面负责主区块16及上下文12；组内并排8；输入内边距14/16。原型差异仍需审阅：记忆控件沿用“记得做了什么”文字；补充入口沿用现有折叠按钮；冲突保留次级标识入口及独立调整按钮，因此卡片较原型高。颜色留T08；HTML键帽与Flutter空白IME占位不比较像素。

## 实际验证

```sh
flutter test test/app/page_t01_visual_fixture_test.dart test/features/ledger/presentation/recording_form_layout_test.dart test/features/ledger/presentation/recording_form_test.dart test/features/ledger/presentation/recording_goal_test.dart test/features/ledger/presentation/recording_rhythm_test.dart test/features/ledger/presentation/recording_rhythm_details_test.dart
env TZ=Asia/Shanghai HOME_FONT=/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc EDITOR_CAPTURE=/tmp/opencode/page-t02 flutter test test/app/page_t01_visual_fixture_test.dart
flutter analyze
```

- 专项70项通过：包含320/360/412、1/1.5/2倍、IME、模态取消、目标/节奏、草稿失败、正式冲突、提交后收尾。
- 新增并排几何、可读冲突名称、首层无技术ID断言；Unknown测试转为验证隐藏及SQLite原文，保留正式保存语义断言。新增断言后夹具4项复跑通过。
- 5个改动Dart文件格式复查0变化；静态分析No issues found。
- 另跑 `test/app/{recording_goal_flow_test,recording_rhythm_flow_test,gap_recording_flow_test}.dart`：1通过、8失败。独立worktree `/tmp/opencode/page-t02-baseline` 检出改动前 `af93dc2` 重跑同命令，亦1通过、同8项失败；旧入口直接找折叠字段/更多菜单动作及旧时间摘要。未删除业务断言或将失败计为通过。尝试的入口迁移已撤回，三个文件保持原样。
- 原始日志：`/tmp/opencode/page-t02-verified.log`、`page-t02-capture.log`、`page-t02-analyze.log`、`page-t02-final-tests.log`、`page-t02-baseline.log`。

## 停止点

请求用户审阅V01/V06。视觉尚未确认，应用级基线未全绿，PAGE-T02不能标整项完成。中文IME/真实设备未验收。此次提交交付当前返工及证据，不启动PAGE-T03。
