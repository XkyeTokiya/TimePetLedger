# Open Questions

本文件只登记 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) 无法唯一回答的问题。Phase 1 建立；编号稳定，后续阶段可追加。Possible options 是用于澄清的候选，不是产品决定，也不是已批准的 Engineering Recommendation。Blocks implementation 只指所列局部能力，不表示必须暂停全部工作。

已经确定的事项不重新提问：Unknown 是合法持久化事实；Gap 不持久化；节奏解释可选；卡住原因与恢复细节可选；Goal 仅为时间归属；自然日是投影边界；主时间轴暂不支持并行主要事实。

## Q-001

**Question:** TomorrowFirstStep 的 intendedDate 如何确定与保存？

**Why it matters:** §22 明确包含 intendedDate，§33 的 daily_reviews 示例却没有对应列；补写历史复盘时，“明天”与当前日期可能不同。

**Related domain objects:** DailyReview、TomorrowFirstStep

**Possible options:** 显式保存且限定为 review.date 的次日；按 review.date 派生；允许用户明确选择意向日期。源文档没有唯一选择。

**Current status:** UNDECIDED

**Blocks implementation:** 是：日期校验、存储设计及历史复盘行为；不阻塞保留概念字段。

## Q-002

**Question:** 第一版是否实际保留 categoryId？

**Why it matters:** §5、§33 列出可选字段，§10 又明确分类不进入核心，允许早期完全不提供分类管理；保留扩展点不等于已决定首版字段与外键。

**Related domain objects:** TimeBlock

**Possible options:** 首版省略该字段；保留可空扩展字段但不实现分类能力。任何选项都不引入复杂分类系统。

**Current status:** UNDECIDED

**Blocks implementation:** 是：TimeBlock 首版最终字段与 schema；不阻塞核心活动记录语义。

## Q-003

**Question:** known 与 unknown 的双向更正是否均开放，各有什么前置条件，现有字段如何处理？

**Why it matters:** §7–8 定义两者语义，§33 允许 unknown 的 title 为 null，但没有规定转换时 title、goalId、note、annotation 的保留或清理；unknown 可空不代表强制清空。Phase 3 进一步确认：合法目标状态不等于已确定所有转换权限；若 categoryId 首版保留，其处理同样待定，区间 / 精度能否同次更正也需明确。

**Related domain objects:** TimeBlock、RhythmAnnotation

**Possible options:** 由用户明确修正相关字段；保留仍有意义的字段；按已确认的组合规则清理不适用字段。具体字段策略待决定。

**Current status:** UNDECIDED

**Blocks implementation:** 是：内容状态切换、编辑行为及相关校验。

## Q-004

**Question:** knowledgeState、goalId 与 RhythmAnnotation 的哪些组合合法？

**Why it matters:** §13 将 progress / stuck 定义为目标相关解释，但恢复例子没有 Goal；源文档没有明确解释存在时是否必须关联 Goal，也未说明 unknown 能否保留目标和解释。

**Related domain objects:** TimeBlock、Goal、RhythmAnnotation

**Possible options:** progress / stuck 必须显式关联 Goal而 recovery 可不关联；允许目标相关语义不绑定 Goal 实体。另需分别决定 unknown 的目标与解释组合。

**Current status:** UNDECIDED

**Blocks implementation:** 是：关联校验、记录表单与解释保存。

## Q-005

**Question:** RhythmAnnotation 的 state 之间是否可自由更正、有什么前置条件，切换时附属字段如何处理；recovery 能否填写 continuationHint？

**Why it matters:** §14 罗列可选字段，§20 明确接续点可附于 progress / stuck，但未说明 recovery；也没有规定切换状态后原因、恢复细节、接续点的保留规则。三种解释不是阶段顺序，源文档未给出六个有向切换组合的开放条件，不能仅凭合法枚举值认定任意切换均已确定。

**Related domain objects:** RhythmAnnotation

**Possible options:** 保留字段但只使用当前状态适用字段；切换时清理不适用字段；要求用户确认。recovery 的接续点可允许或限制，尚无结论。

**Current status:** UNDECIDED

**Blocks implementation:** 是：解释编辑与状态相关校验。

## Q-006

**Question:** Goal 的归档、恢复、删除以及既有引用如何处理？

**Why it matters:** §11 确定 active / archived 和可选 archivedAt，但未给出可逆性、删除策略或归档后是否还能补记 / 关联时间。Phase 3 还需明确新建默认状态、是否直接创建 archived、归档 / 恢复前置条件、archivedAt 的写入清理及重复请求处理。

**Related domain objects:** Goal、TimeBlock、TomorrowFirstStep

**Possible options:** 归档后允许或禁止新增关联；支持或不支持恢复；删除可禁止、限制为未引用目标或解除引用保留事实。每个维度需分别决定。

**Current status:** UNDECIDED

**Blocks implementation:** 是：Goal 生命周期与引用处理；不阻塞定义两个已有状态。

## Q-007

**Question:** 可选原因与恢复细节的正式值域是什么？

**Why it matters:** §15 的卡住原因是例子，§17 恢复方式是候选集合，recoveryQuality 没有值域定义；不能据此发明分级或把示例当封闭枚举。Phase 4 中 recovery_quality 的物理类型也取决于答案，不能用任意整数等级或文字编码代替产品定义；stuck_reason_code / recovery_method 的候选值不直接生成数据库封闭 CHECK。

**Related domain objects:** RhythmAnnotation

**Possible options:** 确定固定代码及含义；允许自由文字；采用代码与文字组合，并明确质量字段的取值。

**Current status:** UNDECIDED

**Blocks implementation:** 是：这些可选字段的类型、表单及校验；不阻塞仅标记节奏。

## Q-008

**Question:** 自然日按哪个时区确定，跨时区或时区变化怎样处理？

**Why it matters:** §4、§23 确定自然日为查询与投影边界，但没有指定时区归属；它影响时间切片与复盘日期。Phase 4 需同时确认该政策是否要求持久化记录时的时区名称或偏移上下文；单独保存 UTC 时间点无法重建原记录时区，相关附加列不能被自动省略或自行加入。

**Related domain objects:** TimeBlock、SleepSession、DailyReview、DayLedgerView

**Possible options:** 按当前设备时区投影；按固定用户时区；按记录时的日期上下文。

**Current status:** UNDECIDED

**Blocks implementation:** 是：自然日查询、跨日统计与日期一致性。

## Q-009

**Question:** 当天未结束时，未处理时间的计算窗口截止于何时？

**Why it matters:** §23 展示完整自然日窗口，§28 展示相邻记录之间补账，未说明当前日尚未发生的时间是否排除，也未明确首尾无记录区间的提示口径。

**Related domain objects:** DayLedgerView、UnresolvedSpan

**Possible options:** 历史日用完整自然日，当天截至当前时刻；统一完整日窗口但区分未来区域；由明确的回顾窗口决定。

**Current status:** UNDECIDED

**Blocks implementation:** 是：当前日 Gap、未记录时长和补账入口；不改变 Gap 非持久化的结论。

## Q-010

**Question:** “昨晚睡眠”的选择、归属及多段睡眠汇总口径是什么？

**Why it matters:** §4 要求跨日完整保存，§24 提供 sleepSummary，§30 展示昨晚睡眠；日窗口切片与整次睡眠时长并不相同，多次 mainSleep / nap 的展示归属也未定义。

**Related domain objects:** SleepSession、DayLedgerView、sleepSummary

**Possible options:** 日账本按窗口切片，昨晚摘要按醒来日期选择整次主睡眠；按开始日期或明确的睡眠窗口选择；多段分别展示或按明确规则汇总。

**Current status:** UNDECIDED

**Blocks implementation:** 是：睡眠摘要及“已记录则不打扰”的识别；不阻塞完整睡眠事实保存。

## Q-011

**Question:** 违反主时间轴不重叠原则时，用户如何修正？

**Why it matters:** §32 明确一段时间最多一个主要 TimeBlock / SleepSession，但未决定保存冲突时拒绝、引导编辑或允许确认后调整；approximate 也没有自动覆盖其他事实的授权。

**Related domain objects:** TimeBlock、SleepSession

**Possible options:** 阻止保存并提示冲突；引导用户手动调整；提供可确认的区间修正方案。无选项允许并行主时间轴。

**Current status:** UNDECIDED

**Blocks implementation:** 是：冲突处理交互与保存流程；不阻塞继承不重叠原则。

## Q-012

**Question:** 是否需要持久化未完成记录 / 复盘草稿？

**Why it matters:** §28 有预填草稿，§21 的正式 DailyReview 包含 tomorrowFirstStep，但未定义未完成输入的保存与恢复行为；不能自行添加 draft 状态或将必需字段改为可空。

**Related domain objects:** UI Models、TimeBlock、DailyReview

**Possible options:** 草稿仅保留于当前交互；另存临时草稿并与正式领域实体分开。

**Current status:** UNDECIDED

**Blocks implementation:** 否：已完成领域事实建模；是：若要实现退出后恢复草稿的能力。

## Q-013

**Question:** 时间事实、节奏解释和每日复盘支持哪些删除 / 更正操作，如何作用于关联数据及处理重复 / 缺失操作对象？

**Why it matters:** 源文档定义事实与可选解释，但未说明删除 TimeBlock 是否自动删除 annotation、移除解释是否保留任何历史，以及事实修正后如何对待已有复盘文字。Phase 3 区分操作语义与操作权限：是否提供 remove、更正范围、是否原地更正、已有 annotation 时重复 add、无 annotation 时 edit / remove、能否同时编辑事实与解释等合同尚未确定。

**Related domain objects:** TimeBlock、RhythmAnnotation、SleepSession、DailyReview

**Possible options:** 删除事实并移除依附解释；有引用时限制删除或要求确认。复盘文字可保持原文或提示用户回顾，不擅自自动重写。具体操作合同待决定。

**Current status:** UNDECIDED

**Blocks implementation:** 是：删除与更正流程、外键删除策略；不要求新增历史记录架构。

## Q-014

**Question:** 近似边界经切片、Gap / 补集和聚合后，hasApproximation 如何传播及承载？

**Why it matters:** §6 确定聚合需诚实携带近似信息，但未说明跨日切片只涉及原记录部分区间时，未落入该片段的近似边界是否仍影响标志。Phase 3 还需处理 Gap 起止来自相邻近似事实、unresolvedDuration 来自覆盖补集的传播方式，以及标志放在各个时长结果还是其他输出层级；不能丢失参与结果的近似信息，也不能一律从全日标志推断所有子项。

**Related domain objects:** TimeBlock、SleepSession、DayLedgerView、hasApproximation

**Possible options:** 只要参与记录含近似边界就标记；根据实际参与切片的边界及其不确定性传播。对 Gap / 补集明确哪些来源边界影响标志，并选择能准确区分各结果近似性的输出结构。

**Current status:** UNDECIDED

**Blocks implementation:** 是：跨日派生精度的最终算法；不阻塞保留起止独立精度。

<!-- Phase 2：补充规则提取中发现的未决校验边界。 -->

## Q-015

**Question:** 文本字段的空白、长度与规范化规则是什么？

**Why it matters:** §33 只明确 known 的 title must not be empty、unknown 的 title may be null；没有说明全空白是否视为空、是否 trim、最大长度或空串与 null 是否归一。Goal.name、TomorrowFirstStep.text 等必需字段的存在性也不自动给出这些校验。

**Related domain objects:** TimeBlock、Goal、RhythmAnnotation、SleepSession、DailyReview、TomorrowFirstStep

**Possible options:** 分别确定必需文字的非空白语义；保留原文或规范化空白；为空的可选文字保留空串或统一 null；按字段决定是否设置长度限制。

**Current status:** UNDECIDED

**Blocks implementation:** 是：超出 known.title 明确非空要求的文本校验、表单反馈与存储限制。

## Q-016

**Question:** SleepSession 的起止合法性以及时间事实的额外取值范围如何规定？

**Why it matters:** §33 的 started_at < ended_at 只明确列于 time_blocks；§4 的睡眠例子均为正时长但未列完整校验。源文档未定义睡眠零时长处理，也未规定 TimeBlock / SleepSession 的最短或最长持续时间、可补录的历史范围及未来时间限制。

**Related domain objects:** SleepSession、TimeBlock

**Possible options:** 为 SleepSession 明确采用严格正区间；分别确定是否需要持续时长上下限，以及未来 / 历史时间的拒绝或提示政策。未决定前不把候选边界写成既定要求。

**Current status:** UNDECIDED

**Blocks implementation:** 是：SleepSession 区间校验及两类事实的额外时间范围校验；TimeBlock 的严格正区间已确定，不重新开放。

## Q-017

**Question:** 时间区间的端点约定、数值分辨率和时长舍入规则是什么？

**Why it matters:** §5–6 要求具体边界支持计算并保留近似，§23–24 要求日窗口切片，§32 禁止主要事实重叠；未指定区间端点表示、秒 / 毫秒的存储与输入精度、舍入发生在单条还是汇总后。相邻记录示例不构成完整算法规范。

**Related domain objects:** TimeBlock、SleepSession、UnresolvedSpan、DayLedgerView、派生时长

**Possible options:** 明确使用半开区间或其他能正确处理相邻端点的约定；保留较细时间值仅显示时舍入，或明确输入量化方式；选择并说明汇总舍入规则。精度表示不等于要求用户按分钟精确追踪。

**Current status:** UNDECIDED

**Blocks implementation:** 是：重叠、切片、边界 Gap 与时长展示的最终计算合同；禁止并行主要事实的原则已确定。

## Q-018

**Question:** 实体标识与 createdAt / updatedAt 的技术合同如何确定？

**Why it matters:** 源文档列出 id、createdAt、updatedAt，但未指定标识格式及生成方式、时间戳表示与来源、是否要求 createdAt ≤ updatedAt、何种编辑更新 updatedAt。不能从字段名称推导全部数据库或编辑约束。Phase 4 对不透明 TEXT 标识、UTC 整数时间编码及集中取时提出 Engineering Recommendation，但未解决标识生成、id 更正策略、更新触发和时钟回拨处理；完整物理设计仍需明确这些合同。

**Related domain objects:** Goal、TimeBlock、RhythmAnnotation、SleepSession、DailyReview

**Possible options:** 标识生成与时间戳表示可在架构阶段提出明确标注的 Engineering Recommendation；更新时间触发条件和顺序约束需单独确认。Goal.archivedAt 的状态联动继续见 Q-006。

**Current status:** UNDECIDED

**Blocks implementation:** 是：标识与时间戳的具体实现及额外校验；不阻塞既定字段存在性。

## Q-019

**Question:** Goal.name 是否要求唯一，若需要如何判定重复？

**Why it matters:** §11 与 §33 没有 Goal.name UNIQUE 或重复名称行为。DailyReview.review_date 的唯一性不能外推到 Goal；归档目标是否参与重名判定也未定义。

**Related domain objects:** Goal

**Possible options:** 允许同名且以 id 区分；仅 active 名称唯一；所有状态名称唯一。若约束唯一，还需确定大小写与空白的比较方式（关联 Q-015）。

**Current status:** UNDECIDED

**Blocks implementation:** 是：目标创建 / 改名验证以及是否添加名称唯一约束。

<!-- Phase 3：补充派生输出边界；既有状态与精度问题已在原编号内细化。 -->

## Q-020

**Question:** goalSummaries 选择哪些目标，哪些细分作为正式输出？

**Why it matters:** §18、§30 确定目标相关总时长、明确推进、明确卡住以及未标记时间的区别，并将恢复单独作为当天背景；但未决定是否列出无记录目标、归档目标的展示过滤、缺少目标归属时的呈现，以及是否额外展示每 Goal 的恢复分量。不能用列表筛选偷偷改变账本全局覆盖。

**Related domain objects:** Goal、TimeBlock、RhythmAnnotation、goalSummaries

**Possible options:** 仅显示窗口内有归属事实的 Goal，或显示指定目标集合并明确零记录；归档目标明确纳入或提供可辨的过滤；保持全日恢复背景，是否增加每 Goal 的细分另行决定。无 Goal 时间不构造新的 Goal 实体。

**Current status:** UNDECIDED

**Blocks implementation:** 是：目标摘要的最终输出列表、空项和额外细分；不阻塞对一个已选定 Goal 按事实求和。

## Q-021

**Question:** 摘要中无匹配记录、尚未记录与数值零如何表达？

**Why it matters:** 空参与集的时长和为 0，但没有 SleepSession 不证明用户没有睡觉，没有 progress annotation 也不证明用户没有推进。源文档未定义 sleepSummary / goalSummaries 在无记录、多条候选或未能选定摘要时的空值结构与文案。

**Related domain objects:** DayLedgerView、sleepSummary、goalSummaries、派生时长

**Possible options:** 用空摘要并呈现尚未记录；用明确区分记录存在性的输出结构；在记录时长为 0 的展示旁说明数据范围。最终表示必须避免把缺少记录当成不存在活动。多条睡眠的选择仍由 Q-010 决定。

**Current status:** UNDECIDED

**Blocks implementation:** 是：摘要的缺失数据表现与返回结构；不阻塞已明确参与集的数学和，也不改变 Unknown / Gap 的领域区分。

<!-- Phase 4：平台范围影响持久化驱动；已有字段与存储语义问题沿原编号补充。 -->

## Q-022

**Question:** 第一版需要正式支持哪些运行平台？

**Why it matters:** Source of Truth 没有指定移动端、桌面或 Web 的首发范围。当前 Flutter 工程中的平台目录不代表发布承诺；本地持久化驱动的运行支持、部署条件与集成验证依赖此答案。架构可以建议本地 SQLite，但不能据此直接选包或承诺所有平台。

**Related domain objects:** 全部持久化领域对象；运行环境与数据访问实现

**Possible options:** 首版聚焦明确列出的移动平台；移动加指定桌面平台；包含 Web 并明确其本地数据保存要求。需由产品确认具体平台清单，再做驱动选择。

**Current status:** UNDECIDED

**Blocks implementation:** 是：持久化驱动最终选择、平台接入及发布验证；不阻塞纯领域模型、规则和已明确窗口下的派生逻辑。

<!-- Phase 5：核心记录入口的验收依赖明确的时间建议合同。 -->

## Q-023

**Question:** 非 Gap 入口的普通补记如何产生默认建议时间区间，缺少前序记录或存在多个候选区间时如何处理？

**Why it matters:** §27 明确“时间是系统提出的可修改假设，活动是用户主要输入”，§28 明确 Gap 入口可直接预填缺口区间；但没有唯一规定普通记录入口如何选择起止、使用当前时间还是历史浏览日期，以及系统建议的初始 startPrecision / endPrecision。不能以实现默认值决定这些产品行为。

**Related domain objects:** TimeBlock、TimePrecision、DayLedgerView、UnresolvedSpan；普通记录 UI 输入模型

**Possible options:** 按已选缺口建议；按所浏览日期和已有记录提出候选后由用户确认；根据明确的上下文规则建议并在无法推断时请求时间输入。需分别确定适用条件与精度初值；这些选项均不得取消用户修改时间的能力。

**Current status:** UNDECIDED

**Blocks implementation:** 是：非 Gap 普通记录入口的时间建议与对应验收；不阻塞领域模型、事实持久化或明确 Gap 区间的预填。若其他入口复用该算法，也需遵循最终合同。
