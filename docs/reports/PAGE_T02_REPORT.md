# PAGE-T02 · 活动编辑返工

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
