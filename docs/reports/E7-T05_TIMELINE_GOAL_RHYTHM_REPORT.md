# E7-T05 — 在时间轴呈现目标节奏与接续点

## Task / Status

**E7-T05 / COMPLETE（2026-10-02，Asia/Shanghai）。** 仅执行 E7-T05，未执行 E7-T06 或后续任务；Epic 7 未标记完成。

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，核对 SOT §12–20、APP 的跨 feature 读取与写入后重读、STATES 的通用更正删除合同。依照 Q-003、Q-005、Q-006、Q-013（均 DECIDED）落实；同名身份遵守 Q-019、文本遵守 Q-015。E7-T04、E6-T04 的完整归档定义、报告与实际时间轴、编辑路由、保存 / 删除收尾实现已检查。

按 AGENTS 委派 code_mapper 有界只读定位日账本读取、元数据及更正 / 刷新调用路径，主 agent 检查实际证据后实施。现有 app 组装已在同一事务中读取完整事实、解释及被引用 Goal，DayLedgerView 的 goalSummaries 已保留按 id 区分的当前 name / isArchived；本次仅使用其中目标元数据，不新增统计展示、算法、持久化字段或投影模型。

## Changes

| 文件 | 本次交付 |
| --- | --- |
| [day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) | 以 source.goalId 匹配同一快照的目标元数据；普通事实切片显示当前目标名及“已归档”、明确节奏文字、可选多行接续点；复用既有节奏中文标签、时间精度及源事实操作回调 |
| [day_ledger_goal_rhythm_test.dart](../../test/app/day_ledger_goal_rhythm_test.dart) | 新增 5 项真实 SQLite / repository / widget 测试：同名与当前元数据、两日同源编辑和删除、窄屏长文本、真实 Goal 读取故障、提交成功后的分层刷新失败与只读重试 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原任务全文归档、稳定锚点索引及进度同步 |

无需改动已有 loader、app 编辑组装或 controller。TimeBlockSegment 已持有原始完整 TimeBlock 和当前 annotation；点击切片仍按原类型 / id 打开既有完整编辑器。页面已有返回后、手动刷新、日期切换和恢复时的重新读取，以及失败时清除旧视图 / 单独重试读取路径，本次通过真实组合测试验证。

## Acceptance evidence

- 两个同名但不同 id 的 Goal 分别显示 active 名称和 archived 标识，metadata 匹配使用 id；更名只改变对应 id 的时间记录名称，另一个同名 Goal 保持原名。归档、恢复、刷新及重新访问历史日取得当前名称 / 状态，不保存名称快照。
- progress / stuck / recovery 均以“节奏：推进 / 卡住 / 恢复”文字表达，不依赖颜色。接续点显示正式读回的多行文本；所有状态均可显示。无解释时只呈现已有事实内容，不加入 neutral、失败标签或自动推断；无 Goal 的解释正常显示。Unknown 保留目标与解释，SleepSession 不附加节奏。
- 9 月 29 日 23:30 至 9 月 30 日 00:30 的两日切片都路由至同一完整 TimeBlock id，编辑器加载原始两端而非切片边界。从两日分别更正节奏 / 接续点后，重新访问另一日即显示新解释；annotation id / createdAt 保留，TimeBlock 全行（包括 note、category、精度、metadata）不变。
- 清空接续点后不再显示旧文字；明确移除解释后两日均无节奏和接续点，原归档目标和事实保持。重新从编辑器添加解释 / 接续点，再从切片删除完整事实后，两日重读均不显示原事实、目标或接续点，依附解释确实删除，Gap 重新派生。两个日期的 DailyReview SQL 全行均保持原样，未将接续点复制成明日第一步。
- 窄屏 360 px、1.5 倍文本缩放下，200 码点目标名与 2000 码点含补充平面字符 / 换行的接续点正常布局，无 Flutter 异常；Text 不设行数截断或 ellipsis，正式原文保持。
- 真实 Goal SQL 读取失败时显示可重试读取失败，旧时间轴被移除，不以空目标或过期名称冒充成功；解除故障后重新加载最新名字和解释。前后正式五表快照不变，不显示私有 SQL 错误。
- annotation 更正已经提交，但编辑器局部刷新失败时禁用再次保存，只能继续清理 / 刷新；收尾成功而完整日 Goal 读取另行失败时，仍区分“更改已应用”和日账本读取失败。单独“重试读取”读回新解释；正式五表快照不变，SQL 审计仅一条 annotation UPDATE、无 TimeBlock UPDATE，复盘同样不变。

## Validation

在仓库根目录使用现有 Flutter / Dart 与缓存依赖，未安装或更新包。

| 实际命令 | 最终结果 |
| --- | --- |
| `TZ=Asia/Shanghai dart format lib/features/ledger/presentation/day_ledger_timeline.dart test/app/day_ledger_goal_rhythm_test.dart` | 退出 0 |
| `TZ=Asia/Shanghai dart format --output=none --set-exit-if-changed lib/features/ledger/presentation/day_ledger_timeline.dart test/app/day_ledger_goal_rhythm_test.dart` | 退出 0，2 files / 0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_goal_rhythm_test.dart` | 退出 0，5 项通过；随后补充的删除关联断言包含在下一行定向及广回归中 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_goal_rhythm_test.dart test/app/day_ledger_timeline_test.dart test/app/day_ledger_editing_flow_test.dart test/app/recording_rhythm_flow_test.dart` | 退出 0，13 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/features/goals test/app test/core/time` | 退出 0，510 项通过、3 项既有时区条件测试跳过 |
| `git diff --check`、本任务新增 / 修改行 whitespace、开始前 SHA-256 对照、归档全文 / 后续定义 / 文档链接检查 | 通过 |

首轮测试一处误将编辑器独立显示的精度当作时间文本前缀，改为定位现有时间控件并核对原始两端，未改变产品显示或降低事实断言。静态分析的一个未使用测试 import 已移除后通过。3 项 skip 为上海时区不满足的既有 DST 条件测试，未记为通过；未将初轮失败记录为通过。

日志：`/tmp/e7-t05-focused.log`、`/tmp/e7-t05-focused-final.log`、`/tmp/e7-t05-analyze-final.log`、`/tmp/e7-t05-regression.log`。

## Self-review / Scope

自审唯一生产文件的任务增量 diff、新建测试及现有读取 / 写入 / 路由证据，核对 metadata id、当前名称与状态、无解释语义、多行展示、完整源身份和读取失败边界。开始前记录了全部 308 个既有文件的 SHA-256 和内容副本，确认仅本次时间轴及完成文档修改，其他既有已跟踪 / 未跟踪内容保留。

正式 schema 仍为 2 / 五表，草稿仍为 v4；未修改领域、repository、算法、正式 / 草稿 schema、依赖、生成文件或平台配置。未增加原因 / 恢复细节输入、统计页面、自动评价、切片副本写入、明日第一步生成、复盘改写或后续任务。原 E7-T05 全文归档，仅补充 COMPLETE / 报告链接；后续任务定义保持原样。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。本次是共用 Flutter widget 与真实 Native SQLite 组合验证；未执行 Android / Web 设备验收，不将此结果写作两平台完成。两平台目标 / 节奏集成仍属 E7-T07。

## Next executable task

**E7-T06 — 验证目标与节奏完整应用闭环。** E7-T01–E7-T05 和 E6-T05 已有完成依据；仅报告，不执行。E7-T05 完成后停止。
