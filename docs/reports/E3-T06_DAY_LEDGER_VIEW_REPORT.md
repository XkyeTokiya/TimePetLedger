# E3-T06 — 组装 DayLedgerView 并核验派生关系

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

直接依赖 [E3-T03](E3-T03_LEDGER_COVERAGE_REPORT.md)、[E3-T04](E3-T04_GOAL_RHYTHM_SUMMARY_REPORT.md)、[E3-T05](E3-T05_SLEEP_SUMMARY_REPORT.md) 均有 COMPLETE 报告：分别包含用户本机 35 项、77 项及 agent 实际运行 86 项测试通过证据。Epic 1 依据 [Epic 0 / 1 完成记录](EPIC_0_1_COMPLETION.md)。已核查实际窗口、切片、覆盖、节奏 / 目标、睡眠实现及相关测试，不以报告替代实现检查。

遵循 AGENTS，阅读完整 Task、Source of Truth、OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN、DERIVED_MODELS / DayLedgerView 与可核对关系、DOMAIN_MODEL / Derived Models、APP_ARCHITECTURE / projection。Q-008、Q-009、Q-010、Q-014、Q-017、Q-020、Q-021 的相关计算合同已确定；无新的阻塞问题。按项目规则委派 code_mapper 有界只读勘查，主 agent 检查证据、决策、编辑和验证。

## Changes

| 文件 | 修改 |
| --- | --- |
| [day_ledger_view.dart](../../lib/features/ledger/domain/projection/day_ledger_view.dart) | 新增不可变 DayLedgerView 及 projectDayLedgerView 纯组合入口 |
| [day_ledger_view_test.dart](../../test/features/ledger/domain/projection/day_ledger_view_test.dart) | 新增 8 项组合行为测试 |
| [TASKS.md](../../TASKS.md#e3-t06--组装-dayledgerview-并核验派生关系) | 追加本任务完成状态和报告链接 |
| 本报告 | 实际交付、验证及边界 |

入口接收显式 date、日期关系、当地日边界、now，以及普通事实、窗口睡眠事实、解释、完整睡眠摘要候选和 Goal 元数据。使用同一组日期参数调用既有窗口选择和完整睡眠摘要算法；只生成一次切片，供覆盖、目标和全局节奏共同使用，没有复制计算公式。

结果提供 date、window、segments、unresolvedSpans、sleepSummary、goalSummaries、accountedDuration、unknownDuration、unresolvedDuration；全局三项节奏经 rhythmSummary 取得。覆盖结果经 coverage 保留，概念字段以 getter 访问同一结果，不另存重复数值。集合沿用既有不可修改输出。

窗口事实必须覆盖 W 内全部主要事实，不按目标或节奏过滤。睡眠摘要候选独立包含按醒来日期所需的完整记录，可在 W 外；不从切片恢复、不合并两个输入集合。两集合中的同一事实必须来自一致快照。完整性、合法不重叠与同类型身份唯一继续作为调用前提，不在组合层制定非法事实修复策略。Goal 元数据缺失、重复及重复解释等既有错误原样抛出。

## Validation

本 agent 在仓库根目录实际执行以下命令；使用现有 SDK，未安装或更新依赖。

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/domain/projection/day_ledger_view.dart test/features/ledger/domain/projection/day_ledger_view_test.dart` | 退出 0；2 文件，1 文件格式化 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection/day_ledger_view.dart test/features/ledger/domain/projection/day_ledger_view_test.dart` | 退出 0；2 文件，0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/core/time test/core/identity test/features/ledger/domain test/features/goals/domain` | 退出 0；206 项全部通过，含本任务新增 8 项 |
| `git diff --check` | 退出 0 |
| projection 依赖检索（命令见下） | 无匹配；rg 退出 1 表示无命中 |

```sh
rg -n 'flutter|drift|dart:io|DateTime.now|toLocal\(' lib/features/ledger/domain/projection
```

该检查未发现 Flutter、数据库驱动、I/O、全局时钟或隐式本地时区读取；另人工检查新增文件全部导入均为纯 domain / core。

### 验收覆盖

1. DERIVED 固定窗口例子整体平移到 00:00–04:00，以遵守实际 today 从当地零点开始的合同；保留所有相对区间，验证 accounted=210、unknown=30、unresolved=30 分钟，以及 progress=60、stuck=30、recovery=30、Goal 总量=90 分钟。原文未指定 SleepType，测试明确选 nap，不从例子推断产品答案。
2. 混合跨日睡眠、Unknown、内部 / 尾部 Gap、同名但不同 id 的 active / archived Goal、未标记、三种节奏和小睡。验证窗口覆盖 13h、Gap 3h、Unknown 1h，完整主睡眠约 8h 与精确日贡献 7h 分开；各项近似独立，归档目标保留。
3. 午夜醒来仅入摘要、次日醒来只贡献当日切片，两个候选范围不互相代替或重复计时。
4. 未来日和今天零点 W 为空，切片、覆盖、目标与节奏无贡献，完整睡眠摘要仍存在。
5. 仅更换或移除解释后，节奏与目标细分改变，覆盖、Gap 和原解释不变。
6. 推进 now 后重新裁剪、更新近似和 Gap，旧投影及原事实不变。
7. 显式 UTC / UTC+8 日界改变窗口贡献和醒来日期归属；23 / 25 小时空历史日按实际边界产生完整 Gap。
8. 缺失 Goal、重复元数据、重复解释、非法日边界 / today now 的失败路径，确认组合层不静默降级。

各适用场景核验 `accounted + unresolved = μ(W)`、`0 ≤ unknown ≤ accounted`、切片时长之和等于覆盖，以及目标 progress / stuck / recovery / 无 annotation 四项合计为总量；检查未排序输入、源对象身份与不可修改输出。

## Self-review

已检查新增生产文件、测试、输入边界、所有概念输出、独立摘要口径、同窗分区、精度来源和失败路径。新增逻辑仅负责组合，不修改既有算法，不实现持久化、查询、UI、提醒、评分、去重或重叠合并。

实施和代码验证结束后，对本轮开始时 lib、test、docs、TASKS、pubspec 文件的 SHA-256 对照均无变化；之后仅追加 TASKS 的 E3-T06 状态并新增本报告。此前工作区修改和未跟踪文件均保留。新文件完整纳入 self-review，无无关格式化或依赖变更。

## Blockers / Open Questions

无。全部适用代码验证通过。平台时区解析、数据快照加载仍由调用方负责，本任务不涉及新的持久化或平台接入；未将纯领域测试外推为 Android / Web 集成验收。

## Next executable task

E3-T07 — 实现摘要展示语义的纯映射。其直接依赖 E3-T06 已完成，需另行授权后执行。本次不执行 E3-T07，也不将尚未全部交付的 Epic 3 标为完成。
