# E7-T06 — 验证目标与节奏完整应用闭环

## Task / Status

**E7-T06 / COMPLETE（2026-10-02，Asia/Shanghai）。** 本次仅执行 E7-T06；未执行 E7-T07、E7-T08 或 Epic 8 / 9，Epic 7 未标记完成。

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，核对 M-01、M-04、M-07 与 Epic 7，以及 Goal / annotation 的 MODEL、RULES、STATES、DERIVED 和 APP / DATA 边界。E7-T01–E7-T05、E6-T05 的归档定义、报告及实际实现已检查。Q-003、Q-004、Q-005、Q-006、Q-007、Q-012、Q-013、Q-014、Q-015、Q-018、Q-019、Q-020、Q-021、Q-022 均为 DECIDED；没有借默认值回答产品问题。

按 AGENTS 委派 code_mapper 有界只读核查 bootstrap、目标管理、表单、提交收尾及现有测试的调用路径；主 agent 检查证据后实现、验证与自审。当前 UI、repository 和原子事务合同足以完成闭环，没有发现本任务需要修复的生产缺陷。

## Changes

| 文件 | 交付 |
| --- | --- |
| [goal_rhythm_closure_test.dart](../../test/app/goal_rhythm_closure_test.dart) | 新增 3 项真实 AppBootstrap / widget / 文件 SQLite 闭环测试；复用已有交互辅助方法与提交后读取故障拦截器 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原任务全文归档、稳定锚点索引与进度同步 |

测试通过真实首页进入目标和普通记录，再通过真实时间轴打开完整源记录进行更正。正式库与普通草稿使用不同 SQLite 文件；完整卸载 AppBootstrap 后重开文件并重新组装 repositories / controllers，不复用内存状态。睡眠首次确认夹具沿用现有“当日已确认”入口，睡眠存储使用隔离内存连接，未打开开发者实际 app 数据。

## Acceptance evidence

- 没有任何 Goal 时先通过 UI 保存 08:00–09:00 的 Unknown、两端 approximate、无解释事实；目标、解释、睡眠、复盘表为空。之后通过目标页创建两个同名目标，并通过 id 选择其中一个，为 10:00–11:00 的 approximate known 记录添加 progress 和多行接续点。另一个同名目标无记录，不进入当前目标摘要。
- 未提交的原始活动、目标 id、解释添加意图、稳定 annotation id 和含首尾空白 / 换行 / 补充平面字符的接续点保存在独立普通草稿文件；正式五表不变。完整重开 bootstrap 后 UI 恢复原输入，提交复用解释身份，领域层执行已有文本规范化，成功清草稿。
- 目标记录按当前投影计入一小时相关总量和明确 progress；全局已交代两小时，Unknown 为一小时，近似标识来自原事实。通过时间轴将解释改为 stuck / 新接续点后，progress 不再有参与记录，stuck 变为一小时；只有 annotation updatedAt 变化，id / createdAt 保持，TimeBlock SQL 全行不变。无变化重复保存，即使注入 now 前进，正式五表仍不变。
- 在已有事实中用 repository 设置原分类、原卡住原因与恢复方式 / 效果作为未展示字段夹具。实际核心表单的解释更正保留这些字段及原备注、精度、区间和 TimeBlock 元数据，没有新增原因 / 恢复细节 UI，也没有把 Should Have 变成门槛。
- 通过目标页归档后，历史时间轴与编辑器仍显示原引用及“已归档”；当前摘要保持相关时长。实际表单明确移除解释后，原目标、TimeBlock 全行、已交代时长保持，无 annotation 时长变为一小时，原 stuck 不再计入。目标页恢复后完整重开库，历史摘要读到 active 当前状态。
- 真实 SQLite `AFTER INSERT ON rhythm_annotations` 触发器中止创建：整个事实 / 解释事务回滚，正式五表快照保持，UI 显示保存失败，原输入、目标和 progress 草稿保留。解除故障后同页重试成功，只有一个 TimeBlock 和一个 annotation，草稿清除。
- 真实 `AFTER UPDATE ON rhythm_annotations` 触发器中止组合更正：拟修改的事实标题、解释 state / hint 以及变化的 now 一起回滚，正式五表快照保持。更正草稿仍保留，并与已清除的新建草稿隔离。离页、卸载整个 app、重开后，日投影仍是原 progress，编辑器恢复失败输入；重试后事实和解释同时更新，原 createdAt / annotation id 保留，当前 recovery 投影为一小时。
- 正式创建事务提交后，同时阻断普通草稿 DELETE 和账本刷新 SELECT；事实与解释完整存在，表单分别提示两种收尾失败且隐藏再次提交。未解除故障的收尾重试不写事实；随后恢复读取、保持清理故障，完整重开 bootstrap，实际表单识别原已提交输入并仍锁定创建。恢复清理后只清草稿和读取，正式五表（含元数据）始终不变；跨重开 SQL 审计仅一次 TimeBlock INSERT，最终投影正确。

本次广回归还运行既有 E7 / E6 测试，覆盖六向节奏转换、同块唯一 / 已有解释拒绝 add / 缺失解释拒绝 edit、解释删除失败回滚、同名生命周期、目标归档 / 删除后的选择失效、无 Goal 的解释、Gap 入口、旧草稿迁移、跨日完整源事实更正、睡眠独立、复盘旧字段保持及读取失败独立重试。没有重新实现领域校验。

## Validation

在仓库根目录使用已有 Flutter / Dart 与缓存依赖，没有安装或更新包。

| 实际命令 | 最终结果 |
| --- | --- |
| `TZ=Asia/Shanghai dart format test/app/goal_rhythm_closure_test.dart` | 退出 0 |
| `TZ=Asia/Shanghai dart format --output=none --set-exit-if-changed test/app/goal_rhythm_closure_test.dart` | 退出 0，1 file / 0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/goal_rhythm_closure_test.dart` | 最终退出 0，3 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/features/goals test/app test/core/time` | 退出 0，513 项通过、3 项既有时区条件测试跳过 |
| `git diff --check`、新增 / 修改文件 whitespace、自审增量、开始前 SHA-256 对照、归档全文 / 后续任务定义 / 文档链接检查 | 通过 |

初轮测试错误使用了草稿不存在的 activity getter，已按实际 DTO title 修正；两处恢复后懒构建控件改为先滚动定位，编辑草稿按已有显式 edit 意图核对，不假定携带只用于 add 的 annotation id。修正后的三项测试通过，再补充失败反馈、失败更正草稿完整重开、未展示字段与元数据断言后，定向和广回归均通过。未为使测试通过改变生产行为或放宽领域合同。3 项跳过来自上海时区不满足的既有 DST 条件场景，未记为通过。

日志：`/tmp/e7-t06-focused.log`、`/tmp/e7-t06-focused-final.log`、`/tmp/e7-t06-analyze.log`、`/tmp/e7-t06-regression.log`。

## Self-review / Scope

检查新增测试全文、真实 app / repository 调用与任务文档增量，核对完整源身份、原子提交、元数据、可选组合、草稿隔离和提交后收尾。开始前保留全部 310 个既有文件 SHA-256 与内容副本；本次仅修改完成记录相关三份文档，新增测试与报告，其他既有已跟踪及未跟踪文件原样保留。

生产代码、正式 schema 2 / 五表、普通草稿 v4、依赖、生成文件和平台配置均未改动；没有增加统计 / 复盘页面、原因 / 恢复细节控件、通用框架或后续生命周期功能。原 E7-T06 全文归档，仅补 COMPLETE 与报告链接；后续任务定义未改变。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。本次是 Flutter widget + 真实 Native SQLite 文件验证；未执行 Android 实际关闭重开或 Web 浏览器刷新，也未将完整 bootstrap / 文件重开说成两平台验收。E7-T07 保留其两平台验证门槛，Epic 7 仍未完成。

## Next executable task

**E7-T07 — 验证 Android 与 Web 目标节奏集成。** E7-T06、E6-T06 已有完成依据，Q-012、Q-022 为 DECIDED；仅报告，不执行。E7-T06 完成后停止。
