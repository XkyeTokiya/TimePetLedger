# Derived Models

## 依据与职责

本文件回答“哪些数据怎么算出来？”，依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) §4–8、§18、§21、§23–25、§30–32，并遵循 [DOMAIN_MODEL](DOMAIN_MODEL.md) 与 [DOMAIN_RULES](DOMAIN_RULES.md)。未决口径集中在 [OPEN_QUESTIONS](OPEN_QUESTIONS.md)，事实操作及更正见 [DOMAIN_STATE_MACHINES](DOMAIN_STATE_MACHINES.md)。

**DayLedgerView 是一天时间窗口上的 projection，而不是数据库 Day entity。** 本文件的所有模型、切片、集合与统计字段均为 `Persistence: NO`；它们不成为独立事实源，不写回 DailyReview。输出字段是语义合同，不是 Dart 类型或数据库 schema。

下面给出已确定语义可推导的集合与时长关系。公式成立的前提会明确列出；摘要缺失按 Q-021 表达，不由数值零代替记录存在性。复盘文字、接续点、名称与原因不用于自动推断节奏状态，也不参与效率评分或因果分析。

## 公共输入与数学记号

| 记号 | 含义 |
| --- | --- |
| D | 待查询自然日期 |
| W | D 内本次实际纳入账本对账的窗口；按 Q-009 确定，可为空 |
| T / S | 与 W 有正时长交集的已保存 TimeBlock / SleepSession |
| A(t) | t 的唯一有效 RhythmAnnotation，或不存在；不是另一个时间区间 |
| I(x) | x 原始起止边界所表示的时间区间 |
| clip(x, W) | I(x) 与 W 的交集；起点为二者起点的较晚者，终点为二者终点的较早者；无正时长交集则不贡献时长 |
| d(x, W) | clip(x, W) 的时长 |
| C(W) | 所有 T 与 S 的切片区间的并集，即已覆盖区域 |
| U(W) | 所有 knowledgeState=unknown 的 T 的切片区间并集 |
| G(W) | W 中除去 C(W) 后未覆盖的区域 |
| μ(X) | 区间或若干不相交区间的总时长；内部按毫秒计算，展示时最终统一舍入到分钟 |

### 已确定的计算前提与政策

1. 主时间轴中的事实必须满足 LEDGER-004 不重叠原则；annotation 不另占覆盖时长。以下示例均使用有效、正时长的事实。TimeBlock 与 SleepSession 均允许未来区间和历史补录，不设置固定时长上下限。
2. 自然日时区按当前设备时区确定。按 Q-009，历史日 W 为当地当天零点至次日零点；今天 W 为当地当天零点至调用方提供的当前时刻；未来日期 W 为空。今天的未来区域不计入未记录时长、不提示补账；W 内首尾空白均纳入 Gap。日长按实际边界计算，不固定为 1440 分钟。
3. 时间区间采用半开区间 `[startedAt, endedAt)`；时间点内部以 UTC epoch milliseconds 表示，公式按毫秒计算，展示时最终统一舍入到分钟。相邻端点不能制造正时长 Gap 或重复时长。
4. C(W) 必须包含 W 内全部主要时间事实，包括无 Goal、无 annotation、Unknown 和睡眠。筛选某个 Goal 或节奏状态只能改变相应汇总的参与集，不能据此把其他合法事实算成全局 Gap。
5. 公式不提供非法重叠记录的容错政策。使用区间并集说明“覆盖”的数学含义，不代表允许重叠、自动合并事实或决定冲突归属；重叠事实在写入时按 Q-011 原子拒绝。

### 对账窗口边界示例（Q-009）

- 现在是当地 15:00：W 为 `[00:00, 15:00)`；若最后一条事实于 14:00 结束，则尾部 Gap 为 `[14:00, 15:00)`。
- 今天完全没有事实：00:00–15:00 整体为 Gap；历史日完全没有事实：整个当地自然日为 Gap。
- 当前恰为当天 00:00，或查看未来日期：对账窗口为空，没有正时长 Gap，未记录时长为 0。
- 事实跨过当前时刻时，仅在 W 内的部分参与本次对账覆盖；允许保存未来事实的规则不变。未来事实的展示不由此新增限制。

当前时刻由 application 显式注入，投影不读取全局时钟。上述窗口用于本文对账指标，不能混用完整日覆盖和截至当前时刻的缺口来验证分区等式。

## DayLedgerView

**Inputs:** 自然日期 D、按当前设备时区和已确定政策得到的 W、T、S，以及 T 对应的 annotation；Goal 元数据用于目标标识 / 名称展示，不用于判断是否推进。sleepSummary 按 Q-010 选择醒来日期为 D 的完整睡眠，可能需要对账窗口外的数据，不能仅从已切片结果恢复原事实。

**Derivation:** 查询相交事实，生成 segments；由全部事实的覆盖计算 unresolvedSpans；分别派生下文各时长、sleepSummary 与 goalSummaries。保留源事实与精度信息，不能将跨日切片当成新事实。睡眠与目标摘要分别遵循 Q-010、Q-020，不能混用窗口贡献和整次睡眠口径。

**Output:** 源文档概念字段 `date`、`segments`、`unresolvedSpans`、`sleepSummary`、`goalSummaries`、`accountedDuration`、`unknownDuration`、`unresolvedDuration`；节奏时长通过相应汇总表达。各摘要时长结果按 Q-021 分别携带记录存在性、实际时长与近似标志；这不是持久化 schema。

**Edge cases:** 完全无记录时 C(W) 为空；已交代为 0、未覆盖为 μ(W)；W 非空时整体形成一个 Gap，W 为空时没有 Gap。今天未来部分和未来日期不产生未记录提示（Q-009）。设备时区变化会改变历史事实的投影日期，但不修改原始事实；无记录不证明用户没睡觉（Q-021）。写入层已拒绝重叠事实，投影不负责用去重结果掩盖非法数据。

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

**Edge cases:** Unknown 的覆盖区域不会形成 Gap；睡眠也填补覆盖。事实连续相接不形成正时长空隙。W 的首尾空白均计入；当日尚未发生部分与未来日期不产生 Gap 或补账提示（Q-009）。不能只统计相邻记录间空隙而遗漏首尾。近似边界产生的空隙精度见 Q-014。

**Persistence: NO**

## sleepSummary

**Inputs:** SleepSession 原始起止、各自精度、SleepType、自然日期 D、当前设备时区，以及日对账窗口 W；提醒识别还需调用方提供当前时刻。

**Derivation（Q-010）：** 区分日窗口覆盖与按醒来日期归属的完整睡眠摘要：

- **日窗口睡眠贡献：** Σ d(s, W)，s 属于 S。只用于对应窗口的账本覆盖，包含 mainSleep 和 nap 的切片。
- **主睡眠摘要：** 选择 endedAt 在当前设备时区中自然日期为 D、type=mainSleep 的所有记录，分别列出原始起止并合计各自 endedAt−startedAt。不得只取最长或最近一条，不把段间清醒时间计入睡眠。
- **小睡摘要：** 同样按醒来日期选择 type=nap 的全部记录，单独列出并合计完整时长，不混入主睡眠。
- **已记录识别：** 当天存在至少一条醒来日期为今天且 endedAt 不晚于调用方提供的当前时刻的 mainSleep，即不再主动询问主睡眠起止。只有 nap，或只有结束时间在未来的 mainSleep，均不满足免打扰条件；沿用每日首次打开时的睡眠优先确认入口，不由本规则增加反复提醒。

**Output:** 摘要标题用“主睡眠”，兼容白天睡觉；主睡眠和小睡各自包含所选记录及完整时长合计，保留近似信息。缺失数据的具体返回结构与文案仍见 Q-021。不添加睡眠质量评分或因果评价。

**Edge cases:** 23:50–次日 07:40 完整时长为 7h50m；在醒来日且 W 已覆盖至 07:40 时，日窗口贡献为 7h40m，二者不可互换（假定无时区偏移变化）。恰在当地 00:00 醒来的记录归该醒来日期，即使对该日账本没有正时长贡献，也应纳入该日完整睡眠摘要；不能只靠 W 相交查询取得摘要输入。设备时区变化后按新时区重新确定醒来日期，不修改原始事实。没有主睡眠记录不能显示为用户实际睡了 0 小时；小睡记录不能替代主睡眠已记录判断。

**Persistence: NO**

## goalSummaries

**Inputs:** W 内按 `TimeBlock.goalId` 关联的记录、其 annotation、Goal 元数据及精度信息。

**Derivation:** 对一个已选定的 Goal g，定义 `Tg={t ∈ T | t.goalId=g.id}`。目标相关时长为 Σ d(t, W)，t 属于 Tg；明确推进和卡住再按 annotation.state 筛选，见各自条目。没有 annotation 的目标记录仍计入相关总时长，不归为任何 RhythmState。

恢复在产品输出中单独作为当天背景。若一个合法 TimeBlock 同时关联 g 并标 recovery，它按 goalId 归属语义仍贡献 g 的相关总时长，但不计作推进 / 卡住；不能把“总时长减推进减卡住”一律称作未标记。该组合已由领域合同允许，新增 archived Goal 关联仍受 Q-006 约束。

**Output（Q-020）：** 只列出 Tg 非空（在 W 内有正时长贡献）的 Goal，不列出无记录目标。归档目标同样纳入，并携带“已归档”标记；该历史摘要不使归档目标重新获得新增关联资格。每项包含 goalId、名称、归档标记、相关总时长，以及 progress / stuck / recovery / 无 annotation 四项时长，各项独立携带 hasApproximation。未标记时长仅来自无 annotation 的记录，不以“总时长−推进−卡住”替代。

**Edge cases:** 无 Goal 的 TimeBlock 不进入目标列表，也不构造“无目标”Goal，但照常参与账本与全局统计。一个目标可能全部未标记节奏或全部标记恢复，仍须显示；同名不同 id 不合并。SleepSession 没有 goalId，不摊入目标时间。全局 recoveryDuration 包含有 Goal 和无 Goal 的恢复，每目标恢复只是其对应子集，不与全局恢复再次相加。目标筛选不改变 accountedDuration 或 Gap。无匹配目标时列表为空，文案见 Q-021。

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

**Edge cases:** 全部覆盖时为 0；无事实且 W 已确定时等于 μ(W)。不能固定使用 `1440 分钟−已交代`，也不能在 accountedDuration 用完整日、unresolvedDuration 只用截至当前时刻的窗口。局部展示过滤不能冒充完整未记录总量；今天只计算截至当前时刻的 W，未来日期 W 为空，unresolvedDuration 为 0，不产生补账提示（Q-009）。

**Persistence: NO**

## progressDuration

**Inputs:** W、选定统计范围内的 T 与 A(t)；若按 Goal 查询，再限定 t.goalId=g.id。

**Derivation:** Σ d(t, W)，仅选取 A(t).state=progress 的记录。annotation 使用所附 TimeBlock 的时间贡献，不另设时长或独立起止。

**Output:** 所述范围内用户明确标记推进的时长及自身 hasApproximation。统计范围必须可辨，不能把全日与某 Goal 的值混用。

**Edge cases:** 无匹配记录时数值为 0，不代表用户没有任何推进，只代表无明确 progress 记录。无 annotation 不推断；approximate 合法。未绑定 Goal 的 annotation 合法；公式不添加额外组合权限。SleepSession 不贡献此项。

**Persistence: NO**

## stuckDuration

**Inputs:** 与 progressDuration 相同的范围参数，但选取 A(t).state=stuck 的 TimeBlock。

**Derivation:** Σ d(t, W)，仅计 stuck；stuckReasonCode 与 stuckReasonText 均为空也照常参与，不以原因完整性过滤。

**Output:** 该范围内明确标记卡住的时长及自身 hasApproximation，不是失败时长或无用功评分。

**Edge cases:** 无匹配记录时为 0；无 annotation 不补算 stuck；跨日仅取切片；切换解释后的统计依赖当前有效解释，不把旧新状态都算入。Goal 归属已允许无 Goal；解释 edit 合同见 Q-005。

**Persistence: NO**

## recoveryDuration

**Inputs:** W 内 T 中 A(t).state=recovery 的记录及其边界精度。

**Derivation:** Σ d(t, W)，仅计明确 recovery；不要求填写恢复方式或质量。不加入 SleepSession，不把普通午饭自动算恢复，也不从 progress / stuck 的前后顺序推断恢复。

**Output:** 当天对账窗口的恢复行为时长及自身 hasApproximation，单独作为背景描述；不计算恢复效率。Q-020 同时要求每 Goal 的恢复细分；全局恢复与各 Goal 恢复不重复相加。

**Edge cases:** 缺少恢复细节仍计入；没有 recovery 记录时为 0；nap 仍只贡献睡眠与账本覆盖。若同一记录合法关联 Goal，其 recoveryDuration 与目标相关总时长是不同维度，不能再相加为账本已交代总量。

**Persistence: NO**

## 摘要存在性与分钟展示（Q-021）

每个摘要时长结果分别保留 hasRecords（存在参与记录）、实际毫秒时长及 hasApproximation；hasRecords 由该项实际参与集判断，不能由四舍五入后的分钟数推导。具体编程类型可在实现时选择，但三种语义必须可分别读取。主睡眠、小睡和目标细分各自判断，不能借用另一项的存在性。

| 情况 | 表达 |
| --- | --- |
| 主睡眠无匹配记录 | 尚未记录主睡眠 |
| 小睡无匹配记录 | 尚未记录小睡 |
| goalSummaries 为空 | 这段时间还没有目标相关记录 |
| 已显示目标缺少 progress / stuck / recovery | 未记录推进 / 未记录卡住 / 未记录恢复 |
| 已显示目标没有无 annotation 的记录 | 没有未标记节奏的记录 |
| 存在正时长记录，但按 Q-017 舍入后为 0 分钟 | 少于 1 分钟；按2026-10-04用户决定，近似结果也不加“约”，hasApproximation仍保留 |

空参与集的数学和仍为 0，但不能因此显示用户实际睡眠或推进为零。普通分钟显示继续按 Q-017 在汇总后四舍五入；微小时长文案用于避免把存在的正时长显示成 0。覆盖 / Gap 的数值零依然表达窗口内数据状态，不将没有 Gap 解释为缺少活动记录。

**Persistence: NO**

## hasApproximation

**Inputs:** 具体结果实际采用的边界及其精度来源，包括事实边界、窗口裁剪边界与 Gap 相邻边界。

**Derivation（Q-014）：**

1. 完整事实时长：startPrecision 或 endPrecision 任一为 approximate，则 hasApproximation=true。
2. 切片时长：只使用切片保留的事实边界精度；严格位于窗口之外、被裁掉的边界不再传播。自然日边界与调用方提供的当前时刻本身不引入近似。事实边界恰与窗口边界相等时仍属于保留边界，不因数值恰好相等消除其近似来源。
3. Gap 时长：实际起止边界来自相邻事实时继承相应精度，来自窗口边界则不新增近似；任一采用的边界近似即标记该 Gap。
4. 汇总：对该项实际参与的正时长结果的 hasApproximation 做 OR。accountedDuration、unknownDuration、各目标和各节奏时长，以及主睡眠 / 小睡合计均独立计算，不从全日标志复制。
5. unresolvedDuration：对实际生成的 Gap 标志做 OR。即使数值也可用 μ(W)−accountedDuration 得到，标志仍从 Gap 的实际边界求得，不能直接继承 accountedDuration。完全覆盖时没有 Gap，不因事实内部近似边界将零缺口标为近似。

**Output:** 每个时间切片、Gap 和时长汇总结果各自携带 hasApproximation；它表示来源近似，不是置信度、误差范围或评分。原事实的 startPrecision / endPrecision 保持原样，裁剪不改写事实。

**Edge cases:** unknown 或未标记节奏不意味着 approximate；舍入得到整数小时不消除近似。无正时长参与项时，没有来源引入近似，标志为 false；缺失摘要如何呈现仍按 Q-021，不能把该值解释为用户实际活动精确为零。

**可核对示例：** 大约前日 23:00 至当日准确 07:00 的完整睡眠为“约 8 小时”；当日切片 00:00–07:00 为“7 小时”，因近似起点已被裁掉。上一条近似 14:00 结束、下一条准确 15:00 开始，Gap 为“约 1 小时”；只有这一缺口时 unresolvedDuration 同样为“约 1 小时”。

**Persistence: NO**

## 可核对的关系与例子

### 同一窗口中的关系

在 W 已确定、输入合法且覆盖完整查询的前提下：

- `0 ≤ unknownDuration ≤ accountedDuration ≤ μ(W)`。
- `accountedDuration + unresolvedDuration = μ(W)`；unknownDuration 已包含在左边的 accountedDuration 中。
- `accountedDuration = known TimeBlock 切片时长 + unknown TimeBlock 切片时长 + SleepSession 切片时长`。
- 同一统计范围内的 progress / stuck / recovery 互斥，因为一条 TimeBlock 最多一个有效 annotation；它们的和不要求等于全部 TimeBlock 时长，未标记部分仍合法。
- 对同一已选定 Goal，相关总时长等于其 progress、stuck、recovery 与无 annotation 四个参与集时长之和。按 Q-020 四项均为正式摘要输出；无 annotation 仍不引入 neutral 枚举。

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

结果：accountedDuration=210 分钟，unknownDuration=30 分钟，unresolvedDuration=30 分钟；progressDuration=60 分钟，stuckDuration=30 分钟，recoveryDuration=30 分钟；Goal A 相关时长=90 分钟；日窗口睡眠贡献=60 分钟。210+30=240，不能再额外加 unknown 的 30 分钟。此例未指定 SleepType，不能据此将睡眠记录归入主睡眠或小睡摘要；正式选择按 Q-010。

## 依赖与实施边界

本文件涉及的 Q-003、Q-005、Q-009、Q-010、Q-013、Q-014、Q-020、Q-021 均已确定；更正 / 删除完成后按当前事实重算。时间建议入口遵循 Q-023，不改写本文的事实覆盖算法。产品澄清不代表投影代码或测试已经实现。

本文件不选择数据库、缓存方案或统一派生框架。**Engineering Recommendation（不是产品要求）：** 以后将窗口和事实集合显式传给派生逻辑，用少量手算例子验证切片、覆盖分区与独立精度，避免把未决产品政策藏进默认参数。
