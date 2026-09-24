# Derived Models

## 依据与职责

本文件回答“哪些数据怎么算出来？”，依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) §4–8、§18、§21、§23–25、§30–32，并遵循 [DOMAIN_MODEL](DOMAIN_MODEL.md) 与 [DOMAIN_RULES](DOMAIN_RULES.md)。未决口径集中在 [OPEN_QUESTIONS](OPEN_QUESTIONS.md)，事实操作及更正见 [DOMAIN_STATE_MACHINES](DOMAIN_STATE_MACHINES.md)。

**DayLedgerView 是一天时间窗口上的 projection，而不是数据库 Day entity。** 本文件的所有模型、切片、集合与统计字段均为 `Persistence: NO`；它们不成为独立事实源，不写回 DailyReview。输出字段是语义合同，不是 Dart 类型或数据库 schema。

下面给出已确定语义可推导的集合与时长关系。公式成立的前提会明确列出；尚未确定的窗口选择、筛选、空值展示和近似传播不以默认值补齐。复盘文字、接续点、名称与原因不用于自动推断节奏状态，也不参与效率评分或因果分析。

## 公共输入与数学记号

| 记号 | 含义 |
| --- | --- |
| D | 待查询自然日期 |
| W | D 内本次实际纳入账本对账的连续时间窗口，具有明确起止边界 |
| T / S | 与 W 有正时长交集的已保存 TimeBlock / SleepSession |
| A(t) | t 的唯一有效 RhythmAnnotation，或不存在；不是另一个时间区间 |
| I(x) | x 原始起止边界所表示的时间区间 |
| clip(x, W) | I(x) 与 W 的交集；起点为二者起点的较晚者，终点为二者终点的较早者；无正时长交集则不贡献时长 |
| d(x, W) | clip(x, W) 的时长 |
| C(W) | 所有 T 与 S 的切片区间的并集，即已覆盖区域 |
| U(W) | 所有 knowledgeState=unknown 的 T 的切片区间并集 |
| G(W) | W 中除去 C(W) 后未覆盖的区域 |
| μ(X) | 区间或若干不相交区间的总时长；内部按毫秒计算，展示时最终统一舍入到分钟 |

### 已确定的计算前提与待定的政策

1. 主时间轴中的事实必须满足 LEDGER-004 不重叠原则；annotation 不另占覆盖时长。以下示例均使用有效、正时长的事实。TimeBlock 与 SleepSession 均允许未来区间和历史补录，不设置固定时长上下限。
2. 自然日时区按当前设备时区确定。完整日窗口是该设备时区下当日零点至次日零点；当前日截止、首尾 Gap 的纳入和提示口径由 Q-009 决定。本文使用已明确边界的 W 推导，不把“现在”或固定 1440 分钟偷偷设成常量。
3. 时间区间采用半开区间 `[startedAt, endedAt)`；时间点内部以 UTC epoch milliseconds 表示，公式按毫秒计算，展示时最终统一舍入到分钟。相邻端点不能制造正时长 Gap 或重复时长。
4. C(W) 必须包含 W 内全部主要时间事实，包括无 Goal、无 annotation、Unknown 和睡眠。筛选某个 Goal 或节奏状态只能改变相应汇总的参与集，不能据此把其他合法事实算成全局 Gap。
5. 公式不提供非法重叠记录的容错政策。使用区间并集说明“覆盖”的数学含义，不代表允许重叠、自动合并事实或决定冲突归属；重叠事实在写入时按 Q-011 原子拒绝。

## DayLedgerView

**Inputs:** 自然日期 D、按当前设备时区和已确定政策得到的 W、T、S，以及 T 对应的 annotation；Goal 元数据用于目标标识 / 名称展示，不用于判断是否推进。sleepSummary 的整次睡眠选择可能需要日窗口外数据，取决于 Q-010，不能仅从已切片结果恢复原事实。

**Derivation:** 查询相交事实，生成 segments；由全部事实的覆盖计算 unresolvedSpans；分别派生下文各时长、sleepSummary 与 goalSummaries。保留源事实与精度信息，不能将跨日切片当成新事实。摘要选择尚未确定时，不能借用另一种口径冒充结果。

**Output:** 源文档概念字段 `date`、`segments`、`unresolvedSpans`、`sleepSummary`、`goalSummaries`、`accountedDuration`、`unknownDuration`、`unresolvedDuration`；节奏时长通过相应汇总表达。具体返回结构及空值表现不是本轮已批准的 schema。

**Edge cases:** 完全无记录时 C(W) 为空；若 W 已明确是本次完整对账范围，则已交代为 0、未覆盖为 μ(W)，但不能据此决定今天未来时间也应算 Gap（Q-009）。设备时区变化会改变历史事实的投影日期，但不修改原始事实；无记录不证明用户没睡觉（Q-021）。写入层已拒绝重叠事实，投影不负责用去重结果掩盖非法数据。

**Persistence: NO**

## segments（时间切片）

**Inputs:** W 与 T、S 的原始起止边界和精度；TimeBlock 的内容、Goal、可选 annotation 或 SleepSession 的类型等用于展示。

**Derivation:** 每个相交事实取 clip(x, W)，仅在 W 内展示其贡献；事实的活动 / 类型和解释仍来自原对象，不由切片重写。按时间边界组织时间线。

**Output:** 自然日时间片段集合。**Engineering Recommendation（不是产品要求）：** 每片携带源对象类型 / id、显示起止和原始精度来源，便于跳回完整事实及正确处理近似；具体字段名和表示方式不在本轮定型。

**Edge cases:** 23:50–次日 07:40 的睡眠在两天分别贡献 10 分钟与 7 小时 40 分钟（例子假定没有时区偏移变化）；原事实始终一条。仅在端点相接无正时长贡献。半开区间保证相接不重叠。裁剪边界的近似传播见 Q-014。annotation 没有独立起止字段，不能臆造“只覆盖半个 TimeBlock”的切片规则。

**Persistence: NO**

## UnresolvedSpan

**Inputs:** W 与 C(W)，不是仅筛选后的目标记录。

**Derivation:** 取 G(W)=W 中未被 C(W) 覆盖的区域；其中每段连续且具有正时长的空隙形成一个 UnresolvedSpan。补记后从新事实集合重新计算，不保存或更新 Gap 实体。

**Output:** 未处理区间集合 `unresolvedSpans`。**Engineering Recommendation（不是产品要求）：** 用起止边界表达每段空隙即可，不需要持久化 id 或生命周期字段。

**Edge cases:** Unknown 的覆盖区域不会形成 Gap；睡眠也填补覆盖。事实连续相接不形成正时长空隙。W 的首尾及当日尚未发生部分是否纳入当前对账范围 / 提示见 Q-009；不能擅自只统计相邻记录间空隙却称其为完整日缺口。近似边界产生的空隙精度见 Q-014。

**Persistence: NO**

## sleepSummary

**Inputs:** SleepSession 原始起止、各自精度、SleepType，以及日窗口 W；如果输出“昨晚睡眠”，还需 Q-010 决定的选择 / 归属上下文。

**Derivation:** 必须区分两个可描述的量：

- **日窗口睡眠贡献：** Σ d(s, W)，s 属于 S。它用于账本覆盖，包含窗口内睡眠事实的贡献，不依赖将某次睡眠称作“昨晚”。
- **某次完整睡眠：** 在已选定一条记录 s 的前提下，时长为 endedAt−startedAt，并保留原始入睡 / 醒来时间与精度。

源文档未决定 sleepSummary 最终选哪些记录、采用整次还是日贡献，以及多个 mainSleep / nap 如何呈现，见 Q-010。两种计算不能混成一个未说明口径的“昨晚时长”。

**Output:** 描述性的睡眠摘要，能表达所选睡眠的时长与入睡 / 醒来信息并诚实显示近似；最终单条或多条结构待 Q-010、Q-021。不添加睡眠质量评分、睡眠造成效率变化的结论。

**Edge cases:** 23:50–次日 07:40 完整时长为 7h50m，次日日窗口贡献为 7h40m，二者不可互换；例子假定没有时区偏移变化。多段主睡眠、仅有 nap、无符合“昨晚”选择的记录均不能自行选择最长 / 最近一条。没有睡眠记录时，窗口贡献的数学和为 0，但不能把它呈现为用户实际睡了 0 小时，缺失展示见 Q-021。

**Persistence: NO**

## goalSummaries

**Inputs:** W 内按 `TimeBlock.goalId` 关联的记录、其 annotation、Goal 元数据及精度信息。

**Derivation:** 对一个已选定的 Goal g，定义 `Tg={t ∈ T | t.goalId=g.id}`。目标相关时长为 Σ d(t, W)，t 属于 Tg；明确推进和卡住再按 annotation.state 筛选，见各自条目。没有 annotation 的目标记录仍计入相关总时长，不归为任何 RhythmState。

恢复在产品输出中单独作为当天背景。若一个合法 TimeBlock 同时关联 g 并标 recovery，它按 goalId 归属语义仍贡献 g 的相关总时长，但不计作推进 / 卡住；不能把“总时长减推进减卡住”一律称作未标记。此组合的合法条件仍受 Q-004 约束，不由公式批准。

**Output:** 按目标描述相关时长、明确推进、明确卡住，以及目标相关但未标记的时间差异；各项保留自身近似信息。没有 Goal 的 TimeBlock 不凭 title 推测 Goal，也不产生合成 Goal 实体。输出哪些目标、是否显示无记录目标或额外恢复细分等见 Q-020。

**Edge cases:** 一个目标的记录可能全部没有 annotation；这仍是有归属的时间，不等于无效时间。归档不自动授权抹去历史归属（Q-006、Q-020）。名称相同不能作为自动合并不同 id 的依据。SleepSession 没有 goalId，不摊入目标相关时间。目标筛选不会改变全局 accountedDuration 或 Gap。

**Persistence: NO**

## accountedDuration

**Inputs:** W 内所有 TimeBlock 与 SleepSession 的覆盖区域 C(W)。

**Derivation:** `accountedDuration=μ(C(W))`。对于符合不重叠规则的事实，等价于 Σ d(t, W)+Σ d(s, W)。包括 known、unknown 和睡眠；annotation 不再加一次时长。

**Output:** W 内已被事实交代的总时长，必要时携带近似标志；不是完成率或分数。

**Edge cases:** 空事实集合为 0；仅有 unknown 仍有已交代时长；跨日仅计 W 内部分；用户改节奏解释但不改事实区间，不改变此数值。不能用 known TimeBlock 时长加 unknown 就遗漏睡眠，也不能把 unknownDuration 再加到本值上。

**Persistence: NO**

## unknownDuration

**Inputs:** `T` 中 knowledgeState=unknown 的切片，即 U(W)。

**Derivation:** `unknownDuration=μ(U(W))`；不重叠前提下等价于这些 TimeBlock 切片时长之和。U(W) 是 C(W) 的子集。

**Output:** 已交代时间中内容未知的时长；不是尚未记录时长。

**Edge cases:** 无 unknown 时为 0；unknown 的 title 可空也可有说明，不根据文字匹配“想不起来”判断状态。若仅将一条 unknown 更正为 known、区间不变，本值减少而 accountedDuration 不变；此处描述条件性派生结果，转换权限与字段处理仍见 Q-003。

**Persistence: NO**

## unresolvedDuration

**Inputs:** 在同一 W 下得到的 unresolvedSpans，即 G(W)。

**Derivation:** `unresolvedDuration=μ(G(W))`，等于所有空隙时长之和；当 W 的全部区域均按上述覆盖 / 未覆盖语义纳入计算时，等于 `μ(W)−accountedDuration`。

**Output:** 当前对账窗口中尚未记录的总时长，必要时表达近似；不包含已确认的 Unknown。

**Edge cases:** 全部覆盖时为 0；无事实且 W 已确定时等于 μ(W)。不能固定使用 `1440 分钟−已交代`，也不能在 accountedDuration 用完整日、unresolvedDuration 只用截至当前时刻的窗口。局部展示过滤不能冒充完整未记录总量；Q-009 未决前不确定今天的最终窗口。

**Persistence: NO**

## progressDuration

**Inputs:** W、选定统计范围内的 T 与 A(t)；若按 Goal 查询，再限定 t.goalId=g.id。

**Derivation:** Σ d(t, W)，仅选取 A(t).state=progress 的记录。annotation 使用所附 TimeBlock 的时间贡献，不另设时长或独立起止。

**Output:** 所述范围内用户明确标记推进的时长及自身 hasApproximation。统计范围必须可辨，不能把全日与某 Goal 的值混用。

**Edge cases:** 无匹配记录时数值为 0，不代表用户没有任何推进，只代表无明确 progress 记录。无 annotation 不推断；approximate 合法。未绑定 Goal 的 annotation 是否允许见 Q-004；公式不添加组合权限。SleepSession 不贡献此项。

**Persistence: NO**

## stuckDuration

**Inputs:** 与 progressDuration 相同的范围参数，但选取 A(t).state=stuck 的 TimeBlock。

**Derivation:** Σ d(t, W)，仅计 stuck；stuckReasonCode 与 stuckReasonText 均为空也照常参与，不以原因完整性过滤。

**Output:** 该范围内明确标记卡住的时长及自身 hasApproximation，不是失败时长或无用功评分。

**Edge cases:** 无匹配记录时为 0；无 annotation 不补算 stuck；跨日仅取切片；切换解释后的统计依赖当前有效解释，不把旧新状态都算入。Goal 关联约束与 edit 合同分别见 Q-004、Q-005。

**Persistence: NO**

## recoveryDuration

**Inputs:** W 内 T 中 A(t).state=recovery 的记录及其边界精度。

**Derivation:** Σ d(t, W)，仅计明确 recovery；不要求填写恢复方式或质量。不加入 SleepSession，不把普通午饭自动算恢复，也不从 progress / stuck 的前后顺序推断恢复。

**Output:** 当天对账窗口的恢复行为时长及自身 hasApproximation，单独作为背景描述；不计算恢复效率。每 Goal 的额外恢复展示不是已确定核心输出（Q-020）。

**Edge cases:** 缺少恢复细节仍计入；没有 recovery 记录时为 0；nap 仍只贡献睡眠与账本覆盖。若同一记录合法关联 Goal，其 recoveryDuration 与目标相关总时长是不同维度，不能再相加为账本已交代总量。

**Persistence: NO**

## hasApproximation

**Inputs:** 某个具体派生结果实际使用的时间事实边界及 startPrecision / endPrecision；裁剪、空隙或补集结果还涉及其边界来源。

**Derivation:** 对直接汇总完整记录时长的结果，只要任一参与记录的 startPrecision 或 endPrecision 为 approximate，就需要表达近似；所有参与边界均 exact 时没有由这些记录带来的近似。对切片后的被裁掉边界、Gap 的相邻边界以及补集结果，具体传播政策未定（Q-014），不能用一个无条件 OR 公式宣称已解决。

**Output:** 表示结果是否涉及近似的派生标志，源文档以 `hasApproximation` 命名；它不是置信度、误差范围或数据质量评分。**Engineering Recommendation（不是产品要求）：** 每个聚合结果各自携带该标志，以免将某项近似误扩散到其他无关统计；具体输出层级继续由 Q-014 跟踪。

**Edge cases:** unknown 不意味着 approximate；未标记节奏不意味着 approximate；切片出的午夜边界不是用户确认 exact 的新事实。计算得到恰好整数小时不消除来源近似。空参与集的时长和为 0，但摘要是否存在、怎样展示应遵守 Q-021，而非伪装成一次精确记录。尚未确定的传播路径不能默认返回 false。

**Persistence: NO**

## 可核对的关系与例子

### 同一窗口中的关系

在 W 已确定、输入合法且覆盖完整查询的前提下：

- `0 ≤ unknownDuration ≤ accountedDuration ≤ μ(W)`。
- `accountedDuration + unresolvedDuration = μ(W)`；unknownDuration 已包含在左边的 accountedDuration 中。
- `accountedDuration = known TimeBlock 切片时长 + unknown TimeBlock 切片时长 + SleepSession 切片时长`。
- 同一统计范围内的 progress / stuck / recovery 互斥，因为一条 TimeBlock 最多一个有效 annotation；它们的和不要求等于全部 TimeBlock 时长，未标记部分仍合法。
- 对同一已选定 Goal，相关总时长等于其 progress、stuck、recovery 与无 annotation 四个参与集时长之和。这里的四项是集合分解，不引入 neutral 枚举，也不要求产品新增四栏展示（Q-020）。组合是否合法先遵守 Q-004。

### 固定窗口示例

此例只校核公式：假设 W 为同日 08:00–12:00，所有边界 exact、无时区偏移变化、无其他事实。它不决定真实应用的日窗口政策。

| 区间 | 事实 | 归属与解释 | 分钟 |
| --- | --- | --- | --- |
| 08:00–09:00 | SleepSession | 无 Goal，无 annotation | 60 |
| 09:00–10:00 | known TimeBlock | Goal A，progress | 60 |
| 10:00–10:30 | unknown TimeBlock | 无 Goal，无 annotation | 30 |
| 10:30–11:00 | 无事实 | 派生 Gap | 30 |
| 11:00–11:30 | known TimeBlock | Goal A，stuck，原因留空 | 30 |
| 11:30–12:00 | known TimeBlock | recovery，恢复细节留空 | 30 |

结果：accountedDuration=210 分钟，unknownDuration=30 分钟，unresolvedDuration=30 分钟；progressDuration=60 分钟，stuckDuration=30 分钟，recoveryDuration=30 分钟；Goal A 相关时长=90 分钟；日窗口睡眠贡献=60 分钟。210+30=240，不能再额外加 unknown 的 30 分钟。仅凭这条睡眠记录及本例窗口不选择“昨晚睡眠”。

## 依赖与实施边界

| 未决问题 | 影响 |
| --- | --- |
| Q-004 | 关联组合；不在统计中自行修正事实 |
| Q-009 | 当前日截止、首尾 Gap 纳入和提示口径 |
| Q-010、Q-021 | 睡眠摘要选择、多段与缺失数据表达 |
| Q-013 | 更正 / 删除支持方式；操作完成后依当前事实重算 |
| Q-014 | 裁剪与 Gap 精度传播，以及标志承载层级 |
| Q-020 | goalSummaries 的目标选择与输出细分 |

本文件不选择数据库、缓存方案或统一派生框架。**Engineering Recommendation（不是产品要求）：** 以后将窗口和事实集合显式传给派生逻辑，用少量手算例子验证切片、覆盖分区与独立精度，避免把未决产品政策藏进默认参数。
