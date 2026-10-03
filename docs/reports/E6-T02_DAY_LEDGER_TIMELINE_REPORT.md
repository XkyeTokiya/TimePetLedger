# E6-T02 — 呈现事实切片与派生 Gap 时间轴

**Task / Status：E6-T02 / COMPLETE。** 日期：2026-10-01。

## 依据与前置

已阅读 AGENTS、完整 E6-T02、共同必读 SOT / OQ / MVP / PLAN，以及 DERIVED / segments、UnresolvedSpan、hasApproximation、RULES / LEDGER-001–LEDGER-005 和相邻 APP / presentation 边界。Q-014、Q-017、Q-021 为 DECIDED，切片与 Gap 独立近似、半开区间、最终分钟舍入及微小时长表达一致，无产品 blocker。

核对直接依赖的归档定义、完成报告和实现：E6-T01 的 DayLedgerLoader / controller / page / app 注入与一致正式读取；E3-T07 的 formatDerivedDuration、微小时长及独立近似展示映射。按 AGENTS 委派 code_mapper 做有界只读勘查，主 agent 检查对应实现并负责决策、编辑、集成、自审和验证。

## Changes

| 文件 | 本轮修改 |
| --- | --- |
| [day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) | 合排现有事实切片与 Gap，使用文字及图标区分已知、未知、主睡眠、小睡、尚未记录；显示切片 / Gap 自身起止、边界精度与时长 |
| [day_ledger_page.dart](../../lib/features/ledger/presentation/day_ledger_page.dart) | 成功取得正式投影时接入时间轴，包括没有事实但有全窗口 Gap 的 empty 状态 |
| [day_ledger_timeline_test.dart](../../test/features/ledger/presentation/day_ledger_timeline_test.dart) | 7 项 widget 场景，覆盖混合类型、源事实引用、排序、跨日、独立近似、空窗口、微小时长与实际日长 |
| [day_ledger_timeline_test.dart](../../test/app/day_ledger_timeline_test.dart) | 真实 SQLite → application → 日账本页面测试，核验切日、类型、同 id 的两类事实及原数据库行不变 |
| TASKS、COMPLETED_TASKS、本报告 | E6-T02 完成状态、归档与验证证据 |

时间轴只排序并渲染 DayLedgerView.segments 和 unresolvedSpans，未重新计算覆盖、Gap、切片或汇总。事实行保留完整 LedgerSegment，由其 reference 携带源事实类型 / id，source 仍为完整原事实；用于 Flutter 行匹配的 key 同样采用带类型的 reference，避免两类事实同 id 时冲突。Gap 行保留 UnresolvedSpan，不赋予事实 id 或持久化状态。

Unknown 只按 source.knowledgeState 识别；有标题的 Unknown 仍显示“未知 · 想不起来”及原标题，标题为“想不起来”的 known 仍显示“已知”。主睡眠与小睡直接按 SleepType 区分，不变为 recovery 或普通活动分类。各状态有文字和图标，不依赖颜色。

区间用现有设备时间格式化函数显示完整日期和分钟边界，次日零点可辨；“约”分别取自切片 / Gap 的实际起止精度。时长复用 E3-T07 的 formatDerivedDuration，不从原事实、完整睡眠摘要或全日近似标志借用精度，不重新舍入或计算事实。跨日只显示本窗口贡献，严格裁掉的近似边界不污染切片；与窗口边界相等的近似边界保留。正时长舍入为零仍显示“少于 1 分钟”或“约少于 1 分钟”。

首尾、内部及全空非空窗口 Gap 均显示“尚未记录”；未来和今天零点沿用现有空 W，不产生 Gap 或补账提示。没有 Goal / annotation 编辑、统计仪表盘、分数、Gap 持久化、Gap 点击补记或原事实编辑路由；后两者分别留 E6-T03 / E6-T04。

## Validation

在仓库根目录使用现有 SDK / 缓存依赖，未安装或更新依赖。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/presentation/day_ledger_timeline.dart lib/features/ledger/presentation/day_ledger_page.dart test/features/ledger/presentation/day_ledger_timeline_test.dart test/app/day_ledger_timeline_test.dart` | 退出 0 |
| 相同清单运行 `dart format --output=none --set-exit-if-changed` | 退出 0，4 文件，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/day_ledger_timeline_test.dart test/features/ledger/presentation/day_ledger_page_test.dart test/app/day_ledger_entry_test.dart` | 退出 0，10 项通过 |
| `TZ=America/New_York flutter test --no-pub test/features/ledger/presentation/day_ledger_timeline_test.dart test/app/day_ledger_timeline_test.dart` | 退出 0，8 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation test/features/ledger/domain/projection test/features/ledger/application/day_ledger_loader_test.dart test/app/day_ledger_entry_test.dart test/app/day_ledger_timeline_test.dart` | 退出 0，139 项通过，无跳过 |
| `git diff --check`、执行前 SHA-256 对照与文档归档 / 链接核对 | 通过，见 Self-review |

首轮静态分析指出测试的一处 if 缺少大括号；已修正并重跑分析和相关回归通过。没有将首轮分析问题当作通过。日志：`/tmp/e6_t02_analyze.log`、`/tmp/e6_t02_target.log`、`/tmp/e6_t02_ny.log`、`/tmp/e6_t02_regression.log`。

### 验收证据

- 混合未排序事实：已知、带标题 Unknown、主睡眠、小睡与首尾 / 内部 Gap 共 9 行，按起点排序、每片只呈现一次；同 id 的两种事实保留不同类型引用。known 的“想不起来”标题不会误判 Unknown。
- 跨日睡眠及跨 now 普通事实：只显示 W 内区间和时长，保留完整 source；被裁掉的近似边界不显示“约”；事实相接不制造 Gap。
- 近似边界恰等于窗口起点 / 截止 now 时，仍显示独立近似；另一端为 exact 的尾部 Gap 不借用事实的整体近似。Gap 实际采用相邻 approximate 端点时显示“约”。
- 全空历史整日和今天截至 now 的完整 Gap；未来、今天零点无事实切片和 Gap，不自动 Unknown、不出现补账提示。
- 微小时长 Unknown、小睡及 Gap 均保留存在性，精确 / 近似文案独立，不把正时长显示为 0 分钟。
- 同一跨日睡眠在两日分别显示 10 分钟与 460 分钟，引用及原始区间相同；纽约设备实际 23 / 25 小时日显示 1380 / 1500 分钟 Gap，上海同日期按当地 24 小时显示。
- 真实 Native SQLite 的正式写入后通过 app loader 展示 5 条事实与 2 个 Gap，切到前日、未来并返回当天后引用与切片正确。前后对照 TimeBlock / SleepSession 全部数据库行，包括原始区间、精度、备注和元数据，无任何变化；没有把整条跨日事实当本日片段或新增重复源事实。
- 回归现有 E3 投影和 E3-T07 格式化、E6-T01 读取及 controller / 页面生命周期、普通 / 睡眠表单，均通过。

## Self-review

完整检查新增生产与测试文件、页面增量、类型识别、源事实引用、排序、逐边界精度、微小时长、无数据与失败状态以及职责依赖。生产改动仅 ledger/presentation；原投影算法、repository、loader、controller、app 组装、schema、pubspec / lockfile 未改变。

执行前保存既有文件 SHA-256。代码完成时仅既有 day_ledger_page 改变（新增 import / 时间轴接入并移除旧任务占位注释）；其他所有既有代码、测试、集成与领域 / 架构 / PLAN 文档保持原样。收尾仅改 TASKS、COMPLETED_TASKS 并新增报告，保留已有工作区改动和未跟踪文件。格式化仅针对本轮 4 个 Dart 文件；不自动实施下一任务。

## Blockers / Open Questions

无 blocker，无新增产品问题。没有执行 Android / Web 设备端到端或实机运行中系统时区切换；本轮为 Flutter widget、真实 Native SQLite 及两个真实 TZ 进程证据，不声明 E6-T06 平台验收通过。

## Next executable task

E6-T03 — 接通 Gap 预填与明确确认 Unknown。其直接依赖 E6-T02、E4-T02、E4-T04、E4-T05 已有完成证据；需另行指定执行。本次在 E6-T02 完成后停止，未执行 E6-T03，未将 Epic 6 标记为完成。
