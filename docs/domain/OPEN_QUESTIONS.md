# Open Questions

本文件只登记 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) 无法唯一回答的问题。Phase 1 建立；编号稳定，后续阶段可追加。Possible options 是用于澄清的候选，不是产品决定，也不是已批准的 Engineering Recommendation。Blocks implementation 只指所列局部能力，不表示必须暂停全部工作。

**当前状态（2026-09-25）：** Q-001–Q-023 全部 DECIDED。本轮通过逐项问答确认剩余 12 项；决定已同步对应职责文档，未执行功能开发。各项 Why it matters / Possible options 保留问题提出时的背景，当前结论以 Decision 和 Current status 为准。

已经确定的事项不重新提问：Unknown 是合法持久化事实；Gap 不持久化；节奏解释可选；卡住原因与恢复细节可选；Goal 仅为时间归属；自然日是投影边界；主时间轴暂不支持并行主要事实。

## Q-001

**Question:** TomorrowFirstStep 的 intendedDate 如何确定与保存？

**Why it matters:** §22 明确包含 intendedDate，§33 的 daily_reviews 示例却没有对应列；补写历史复盘时，“明天”与当前日期可能不同。

**Related domain objects:** DailyReview、TomorrowFirstStep

**Possible options:** 显式保存且限定为 review.date 的次日；按 review.date 派生；允许用户明确选择意向日期。源文档没有唯一选择。

**Decision:** `intendedDate` 固定为 `DailyReview.date` 的下一自然日；领域对象提供该值，但数据库不单独保存 `intendedDate` 列，由 `review.date + 1` 派生。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：日期关系和存储方式已确定。

## Q-002

**Question:** 第一版是否实际保留 categoryId？

**Why it matters:** §5、§33 列出可选字段，§10 又明确分类不进入核心，允许早期完全不提供分类管理；保留扩展点不等于已决定首版字段与外键。

**Related domain objects:** TimeBlock

**Possible options:** 首版省略该字段；保留可空扩展字段但不实现分类能力。任何选项都不引入复杂分类系统。

**Decision:** 首版保留可空 `categoryId`；不建立 Category 实体、分类管理或分类入口，暂不为该字段建立外键约束。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：首版字段存在性和不提供分类能力已确定。

## Q-003

**Question:** known 与 unknown 的双向更正是否均开放，各有什么前置条件，现有字段如何处理？

**Why it matters:** §7–8 定义两者语义，§33 允许 unknown 的 title 为 null，但没有规定转换时 title、goalId、note、annotation 的保留或清理；unknown 可空不代表强制清空。Phase 3 进一步确认：合法目标状态不等于已确定所有转换权限；若 categoryId 首版保留，其处理同样待定，区间 / 精度能否同次更正也需明确。

**Related domain objects:** TimeBlock、RhythmAnnotation

**Possible options:** 由用户明确修正相关字段；保留仍有意义的字段；按已确认的组合规则清理不适用字段。具体字段策略待决定。

**Decision:** 允许 known ↔ unknown 双向更正，不设置额外转换门槛。转为 known 时必须填写满足文本规则的活动名称；转为 unknown 时保留原有 title、goalId、note、categoryId 和 RhythmAnnotation，不因状态切换自动清空或重置，用户可自行修改或清空可选内容。同一次编辑允许修改时间区间和起止精度，保存结果仍须满足严格正区间、不重叠、文本规则及既有引用约束。通用删除、更正和关联操作合同仍由 Q-013 决定。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述规则。

**Current status:** DECIDED

**Blocks implementation:** 否：双向认知更正与转换字段策略已确定；相关实现仍需遵守 Q-013 的通用操作合同。

## Q-004

**Question:** knowledgeState、goalId 与 RhythmAnnotation 的哪些组合合法？

**Why it matters:** §13 将 progress / stuck 定义为目标相关解释，但恢复例子没有 Goal；源文档没有明确解释存在时是否必须关联 Goal，也未说明 unknown 能否保留目标和解释。

**Related domain objects:** TimeBlock、Goal、RhythmAnnotation

**Possible options:** progress / stuck 必须显式关联 Goal而 recovery 可不关联；允许目标相关语义不绑定 Goal 实体。另需分别决定 unknown 的目标与解释组合。

**Decision:** `knowledgeState`、`goalId` 和 `RhythmAnnotation` 不设额外组合限制。`known` / `unknown` 均可有或无 `Goal`，均可有或无节奏解释；`progress`、`stuck`、`recovery` 均不强制要求 `Goal`。仍遵守 annotation 必须附属于 TimeBlock、一个 TimeBlock 最多一份 annotation，以及 Q-006 对 archived Goal 不得新增关联的约束。

**Decision source:** 产品负责人于 2026-09-25 逐项确认。

**Current status:** DECIDED

**Blocks implementation:** 否：已确认已知性、目标归属和节奏解释之间的组合合同。

## Q-005

**Question:** RhythmAnnotation 的 state 之间是否可自由更正、有什么前置条件，切换时附属字段如何处理；recovery 能否填写 continuationHint？

**Why it matters:** §14 罗列可选字段，§20 明确接续点可附于 progress / stuck，但未说明 recovery；也没有规定切换状态后原因、恢复细节、接续点的保留规则。三种解释不是阶段顺序，源文档未给出六个有向切换组合的开放条件，不能仅凭合法枚举值认定任意切换均已确定。

**Related domain objects:** RhythmAnnotation

**Possible options:** 保留字段但只使用当前状态适用字段；切换时清理不适用字段；要求用户确认。recovery 的接续点可允许或限制，尚无结论。

**Decision:** progress、stuck、recovery 允许任意双向更正，没有先后顺序或额外转换门槛。切换状态时保留已填附属字段，只展示和使用当前状态适用的细节：卡住原因仅在 stuck 使用，恢复方式与质量仅在 recovery 使用；切回对应状态可重新显示原值。三种状态均允许填写 continuationHint，切换时不清空接续点。字段仍为可选，具体值域由 Q-007 确定；通用编辑 / 移除操作合同仍见 Q-013。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述三条规则。

**Current status:** DECIDED

**Blocks implementation:** 否：状态更正、字段保留和 recovery 接续点合同已确定；值域及通用操作仍受 Q-007、Q-013 约束。

## Q-006

**Question:** Goal 的归档、恢复、删除以及既有引用如何处理？

**Why it matters:** §11 确定 active / archived 和可选 archivedAt，但未给出可逆性、删除策略或归档后是否还能补记 / 关联时间。Phase 3 还需明确新建默认状态、是否直接创建 archived、归档 / 恢复前置条件、archivedAt 的写入清理及重复请求处理。

**Related domain objects:** Goal、TimeBlock、TomorrowFirstStep

**Possible options:** 归档后允许或禁止新增关联；支持或不支持恢复；删除可禁止、限制为未引用目标或解除引用保留事实。每个维度需分别决定。

**Decision:** Goal 只能以 `active` 创建；支持 `active ↔ archived` 双向切换。归档写入当前 UTC `archivedAt`，恢复时清除；相同状态的重复请求幂等且不更新 `updatedAt`。已有 TimeBlock / DailyReview 引用保留，archived Goal 不可用于新增关联，并可仅在已有时间记录中显示。未被引用的 Goal 可物理删除；有引用的 Goal 的界面删除操作执行归档并隐藏，保留引用且支持恢复和改名。改名实时作用于历史记录，不保存名称快照；不新增 `deleted` 状态。

**Decision source:** 产品负责人于 2026-09-25 逐项确认。

**Current status:** DECIDED

**Blocks implementation:** 否：Goal 生命周期、引用、删除和改名语义已确定。

## Q-007

**Question:** 可选原因与恢复细节的正式值域是什么？

**Why it matters:** §15 的卡住原因是例子，§17 恢复方式是候选集合，recoveryQuality 没有值域定义；不能据此发明分级或把示例当封闭枚举。Phase 4 中 recovery_quality 的物理类型也取决于答案，不能用任意整数等级或文字编码代替产品定义；stuck_reason_code / recovery_method 的候选值不直接生成数据库封闭 CHECK。

**Related domain objects:** RhythmAnnotation

**Possible options:** 确定固定代码及含义；允许自由文字；采用代码与文字组合，并明确质量字段的取值。

**Decision:** 卡住原因可单选“任务太大、不知道下一步、困、脑雾、焦虑、被打断、说不清、其他”，另可填写文字补充；允许只写文字，选择“其他”不强制补充。恢复方式可单选“散步、吃饭、洗澡、放空、娱乐、切换任务、拆小任务、寻求帮助、其他”，睡眠继续独立记录。恢复效果可单选“没缓过来、缓过来一些、可以继续了”，表示用户主观感受，不换算分数。以上所有细节均可不填；切换时的保留和使用遵循 Q-005。正式代码映射见 DOMAIN_MODEL，持久化采用可空 TEXT 代码，恢复效果不采用数值评分。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述选项与填写规则；内部代码命名与存储映射为对应的工程落实。

**Current status:** DECIDED

**Blocks implementation:** 否：可选细节的值域、单选语义和填写规则已确定。

## Q-008

**Question:** 自然日按哪个时区确定，跨时区或时区变化怎样处理？

**Why it matters:** §4、§23 确定自然日为查询与投影边界，但没有指定时区归属；它影响时间切片与复盘日期。Phase 4 需同时确认该政策是否要求持久化记录时的时区名称或偏移上下文；单独保存 UTC 时间点无法重建原记录时区，相关附加列不能被自动省略或自行加入。

**Related domain objects:** TimeBlock、SleepSession、DailyReview、DayLedgerView

**Possible options:** 按当前设备时区投影；按固定用户时区；按记录时的日期上下文。

**Decision:** 自然日按当前设备时区确定。TimeBlock 和 SleepSession 的起止时间保存为绝对时间；设备时区变化后，历史事实按新时区重新投影，原始时间事实不变。账本时区覆盖能力列入后续开发；未设置覆盖时使用设备时区。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：自然日投影和跨设备行为已确定；时区覆盖属于后续能力。

## Q-009

**Question:** 当天未结束时，未处理时间的计算窗口截止于何时？

**Why it matters:** §23 展示完整自然日窗口，§28 展示相邻记录之间补账，未说明当前日尚未发生的时间是否排除，也未明确首尾无记录区间的提示口径。

**Related domain objects:** DayLedgerView、UnresolvedSpan

**Possible options:** 历史日用完整自然日，当天截至当前时刻；统一完整日窗口但区分未来区域；由明确的回顾窗口决定。

**Decision:** 按当前设备时区，历史日期检查当天 00:00 至次日 00:00；今天只检查当天 00:00 至当前时刻；未来日期不产生未记录缺口或补账提示。今天尚未发生的时间不计入 unresolvedDuration，也不提示补账。检查范围内第一条事实之前、最后一条事实之后的空白均为 Gap；完全无记录时整个检查范围为 Gap。TimeBlock（含 Unknown）和 SleepSession 都能覆盖时间。当前时刻由调用方显式提供，纯领域计算不读取全局时钟。此决定不改变 Q-016 允许保存未来正区间的规则。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述四条规则及 15:00 时提示 14:00–15:00 缺口的示例。

**Current status:** DECIDED

**Blocks implementation:** 否：当前日截止、未来区域排除和首尾缺口口径已确定；近似传播仍见 Q-014。

## Q-010

**Question:** “昨晚睡眠”的选择、归属及多段睡眠汇总口径是什么？

**Why it matters:** §4 要求跨日完整保存，§24 提供 sleepSummary，§30 展示昨晚睡眠；日窗口切片与整次睡眠时长并不相同，多次 mainSleep / nap 的展示归属也未定义。

**Related domain objects:** SleepSession、DayLedgerView、sleepSummary

**Possible options:** 日账本按窗口切片，昨晚摘要按醒来日期选择整次主睡眠；按开始日期或明确的睡眠窗口选择；多段分别展示或按明确规则汇总。

**Decision:** 睡眠摘要按当前设备时区中的醒来日期（endedAt 的自然日期）归属，并计算整次睡眠时长；日账本覆盖仍按对账窗口切片，二者分开。同一醒来日期的多段 mainSleep 分别列出并合计各段实际时长，不计段间清醒时间；nap 单独列出并汇总，不混入主睡眠。摘要标题使用“主睡眠”，兼容白天睡觉。当天已有至少一条结束时间不晚于当前时刻的 mainSleep，则不再主动询问主睡眠起止；只有 nap 不满足免打扰条件，仍可提示补记主睡眠。无匹配记录的具体输出结构与文案仍见 Q-021。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述五条规则；23:50–次日 07:40 在醒来日摘要计 7h50m、日账本覆盖计 7h40m（当天对账窗口已覆盖该睡眠部分）。

**Current status:** DECIDED

**Blocks implementation:** 否：日期归属、多段主睡眠 / 小睡汇总与已记录识别已确定；缺失表达仍见 Q-021。

## Q-011

**Question:** 违反主时间轴不重叠原则时，用户如何修正？

**Why it matters:** §32 明确一段时间最多一个主要 TimeBlock / SleepSession，但未决定保存冲突时拒绝、引导编辑或允许确认后调整；approximate 也没有自动覆盖其他事实的授权。

**Related domain objects:** TimeBlock、SleepSession

**Possible options:** 阻止保存并提示冲突；引导用户手动调整；提供可确认的区间修正方案。无选项允许并行主时间轴。

**Decision:** 发生 TimeBlock / SleepSession 重叠时原子拒绝保存并提示冲突记录，由用户手动调整；不自动截断、拆分、覆盖或移动已有事实。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：冲突保存结果和用户修正边界已确定。

## Q-012

**Question:** 是否需要持久化未完成记录 / 复盘草稿？

**Why it matters:** §28 有预填草稿，§21 的正式 DailyReview 包含 tomorrowFirstStep，但未定义未完成输入的保存与恢复行为；不能自行添加 draft 状态或将必需字段改为可空。

**Related domain objects:** UI Models、TimeBlock、DailyReview

**Possible options:** 草稿仅保留于当前交互；另存临时草稿并与正式领域实体分开。

**Decision:** 普通记录、睡眠记录和每日复盘的未保存输入自动保留到本机，离开页面、关闭应用或刷新网页后仍可恢复。草稿与正式记录分开，不参与账本覆盖、统计或重叠判断；不为正式领域实体新增 draft 状态或放宽必填字段。编辑已有记录时，正式记录保持原样，点击保存且正式写入成功后才应用修改。成功保存或用户主动放弃后清除对应草稿；保存失败不清除。恢复的草稿正式保存时仍须按当前事实执行完整校验。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受自动本机保存、独立草稿、编辑隔离和清除时机四条规则。

**Current status:** DECIDED

**Blocks implementation:** 否：本机草稿保留和恢复行为已确定；具体存储与任务拆分在对应实现阶段落实，本次仅更新文档。

## Q-013

**Question:** 时间事实、节奏解释和每日复盘支持哪些删除 / 更正操作，如何作用于关联数据及处理重复 / 缺失操作对象？

**Why it matters:** 源文档定义事实与可选解释，但未说明删除 TimeBlock 是否自动删除 annotation、移除解释是否保留任何历史，以及事实修正后如何对待已有复盘文字。Phase 3 区分操作语义与操作权限：是否提供 remove、更正范围、是否原地更正、已有 annotation 时重复 add、无 annotation 时 edit / remove、能否同时编辑事实与解释等合同尚未确定。

**Related domain objects:** TimeBlock、RhythmAnnotation、SleepSession、DailyReview

**Possible options:** 删除事实并移除依附解释；有引用时限制删除或要求确认。复盘文字可保持原文或提示用户回顾，不擅自自动重写。具体操作合同待决定。

**Decision:** TimeBlock、SleepSession、DailyReview 均允许修改和删除；修改保留原记录身份，不另存历史版本，元数据遵循 Q-018。复盘日期允许修改，但同一天仍最多一份，intendedDate 随 review.date 按 Q-001 派生。删除 TimeBlock 时一并删除依附的 RhythmAnnotation；单独移除解释时保留 TimeBlock。修改或删除时间事实不自动改写复盘文字，删除复盘不删除当天时间事实。允许一次修改 TimeBlock 及其解释，全部成功或全部失败。重复删除已不存在的对象视为已完成；修改不存在的对象返回“记录已不存在”，不自动重建。已有解释时再次 add 提示改用编辑；无解释时 edit 提示先添加，不静默覆盖。保存仍遵守已确认的字段、时间、引用与唯一性规则。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述六条规则。

**Current status:** DECIDED

**Blocks implementation:** 否：更正、删除、依附解释处理、组合编辑及重复 / 缺失对象处理已确定，不新增历史版本架构。

## Q-014

**Question:** 近似边界经切片、Gap / 补集和聚合后，hasApproximation 如何传播及承载？

**Why it matters:** §6 确定聚合需诚实携带近似信息，但未说明跨日切片只涉及原记录部分区间时，未落入该片段的近似边界是否仍影响标志。Phase 3 还需处理 Gap 起止来自相邻近似事实、unresolvedDuration 来自覆盖补集的传播方式，以及标志放在各个时长结果还是其他输出层级；不能丢失参与结果的近似信息，也不能一律从全日标志推断所有子项。

**Related domain objects:** TimeBlock、SleepSession、DayLedgerView、hasApproximation

**Possible options:** 只要参与记录含近似边界就标记；根据实际参与切片的边界及其不确定性传播。对 Gap / 补集明确哪些来源边界影响标志，并选择能准确区分各结果近似性的输出结构。

**Decision:** 按实际参与计算的边界传播近似，每项时长结果独立携带 hasApproximation。完整记录任一起止边界近似则其时长近似；切片只考虑保留下来的事实边界，被裁掉的近似边界不影响切片。Gap 沿用相邻事实的近似边界时，其时长也近似；自然日边界和显式当前时刻本身不引入近似。汇总任一参与时长近似，则该汇总近似；目标、睡眠、Unknown、Gap 等分别判断，不使用全日统一标志覆盖子项。unresolvedDuration 从其实际 Gap 时长及近似标志汇总，不直接套用 accountedDuration 的标志。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受四条规则；“大约昨晚 23:00 至今天准确 07:00”的完整睡眠为约 8 小时，当天 00:00–07:00 覆盖为 7 小时；近似 14:00 至准确 15:00 的 Gap 为约 1 小时。

**Current status:** DECIDED

**Blocks implementation:** 否：切片、Gap / 补集和逐项汇总的近似传播及承载方式已确定。

<!-- Phase 2：补充规则提取中发现的未决校验边界。 -->

## Q-015

**Question:** 文本字段的空白、长度与规范化规则是什么？

**Why it matters:** §33 只明确 known 的 title must not be empty、unknown 的 title may be null；没有说明全空白是否视为空、是否 trim、最大长度或空串与 null 是否归一。Goal.name、TomorrowFirstStep.text 等必需字段的存在性也不自动给出这些校验。

**Related domain objects:** TimeBlock、Goal、RhythmAnnotation、SleepSession、DailyReview、TomorrowFirstStep

**Possible options:** 分别确定必需文字的非空白语义；保留原文或规范化空白；为空的可选文字保留空串或统一 null；按字段决定是否设置长度限制。

**Decision:** 保存前清理首尾空白；必填文本清理后不得为空；可选空文本保存为 `null`；内部空格、换行和段落格式保留。短文本最多 200 个字符，长文本最多 2,000 个字符；清理后按 Unicode 码点（Dart `runes`）计数，不按 UTF-16 代码单元或用户可见字素簇计数。长度由领域 / 应用校验，数据库使用普通 `TEXT`。代码和值域字段由 Q-007 的独立决定定型，不由本条文本规则推导。

**Decision supplement source:** 产品负责人于 2026-09-25 执行 E1-T03 时明确选择“按 Unicode 码点计数（Dart runes，无需新增依赖）”。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：已确认文本规范化、必填语义和长度策略。

## Q-016

**Question:** SleepSession 的起止合法性以及时间事实的额外取值范围如何规定？

**Why it matters:** §33 的 started_at < ended_at 只明确列于 time_blocks；§4 的睡眠例子均为正时长但未列完整校验。源文档未定义睡眠零时长处理，也未规定 TimeBlock / SleepSession 的最短或最长持续时间、可补录的历史范围及未来时间限制。

**Related domain objects:** SleepSession、TimeBlock

**Possible options:** 为 SleepSession 明确采用严格正区间；分别确定是否需要持续时长上下限，以及未来 / 历史时间的拒绝或提示政策。未决定前不把候选边界写成既定要求。

**Decision:** TimeBlock 和 SleepSession 均采用严格正区间；不设置固定最短或最长持续时长；允许未来正区间；不设置历史补录上限。

**Decision source:** 产品负责人于 2026-09-25 确认。

**Current status:** DECIDED

**Blocks implementation:** 否：睡眠区间及两类时间事实的取值范围已确定。

## Q-017

**Question:** 时间区间的端点约定、数值分辨率和时长舍入规则是什么？

**Why it matters:** §5–6 要求具体边界支持计算并保留近似，§23–24 要求日窗口切片，§32 禁止主要事实重叠；未指定区间端点表示、秒 / 毫秒的存储与输入精度、舍入发生在单条还是汇总后。相邻记录示例不构成完整算法规范。

**Related domain objects:** TimeBlock、SleepSession、UnresolvedSpan、DayLedgerView、派生时长

**Possible options:** 明确使用半开区间或其他能正确处理相邻端点的约定；保留较细时间值仅显示时舍入，或明确输入量化方式；选择并说明汇总舍入规则。精度表示不等于要求用户按分钟精确追踪。

**Decision:** 时间区间采用半开区间 `[startedAt, endedAt)`；时间点以 UTC epoch milliseconds 存储；用户界面采用分钟级输入；内部按毫秒计算和汇总，最终展示时统一四舍五入到分钟，不对单条记录先行舍入。

**Decision source:** 产品负责人于 2026-09-25 逐项确认。

**Current status:** DECIDED

**Blocks implementation:** 否：重叠、切片、边界 Gap 和时长展示的时间合同已确定。

## Q-018

**Question:** 实体标识与 createdAt / updatedAt 的技术合同如何确定？

**Why it matters:** 源文档列出 id、createdAt、updatedAt，但未指定标识格式及生成方式、时间戳表示与来源、是否要求 createdAt ≤ updatedAt、何种编辑更新 updatedAt。不能从字段名称推导全部数据库或编辑约束。Phase 4 对不透明 TEXT 标识、UTC 整数时间编码及集中取时提出 Engineering Recommendation，但未解决标识生成、id 更正策略、更新触发和时钟回拨处理；完整物理设计仍需明确这些合同。

**Related domain objects:** Goal、TimeBlock、RhythmAnnotation、SleepSession、DailyReview

**Possible options:** 标识生成与时间戳表示可在架构阶段提出明确标注的 Engineering Recommendation；更新时间触发条件和顺序约束需单独确认。Goal.archivedAt 的状态联动继续见 Q-006。

**Decision:** 实体标识采用本地生成的 UUID v4，并以不透明字符串保存。`createdAt`、`updatedAt` 和 `archivedAt` 使用 UTC epoch milliseconds；`createdAt` 创建后不变，`updatedAt` 仅在实体内容实际发生变化并成功保存后更新。查询、失败写入和无变化的重复请求不更新 `updatedAt`；当前时间由调用方注入。

**Decision source:** 产品负责人于 2026-09-25 逐项确认。

**Current status:** DECIDED

**Blocks implementation:** 否：标识、时间戳表示和更新时间触发条件已确定。

## Q-019

**Question:** Goal.name 是否要求唯一，若需要如何判定重复？

**Why it matters:** §11 与 §33 没有 Goal.name UNIQUE 或重复名称行为。DailyReview.review_date 的唯一性不能外推到 Goal；归档目标是否参与重名判定也未定义。

**Related domain objects:** Goal

**Possible options:** 允许同名且以 id 区分；仅 active 名称唯一；所有状态名称唯一。若约束唯一，还需确定大小写与空白的比较方式（关联 Q-015）。

**Decision:** Goal 允许同名，以各自 id 区分；创建和改名不因重名而拒绝，active 和 archived 均适用。不同 id 的同名目标，其记录和统计保持独立，不自动合并。name 不设唯一约束，仍遵守 Q-015 的文本规范化、非空白与长度规则。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受同名目标规则。

**Current status:** DECIDED

**Blocks implementation:** 否：允许重名、按 id 区分与不设置名称唯一约束已确定。

<!-- Phase 3：补充派生输出边界；既有状态与精度问题已在原编号内细化。 -->

## Q-020

**Question:** goalSummaries 选择哪些目标，哪些细分作为正式输出？

**Why it matters:** §18、§30 确定目标相关总时长、明确推进、明确卡住以及未标记时间的区别，并将恢复单独作为当天背景；但未决定是否列出无记录目标、归档目标的展示过滤、缺少目标归属时的呈现，以及是否额外展示每 Goal 的恢复分量。不能用列表筛选偷偷改变账本全局覆盖。

**Related domain objects:** Goal、TimeBlock、RhythmAnnotation、goalSummaries

**Possible options:** 仅显示窗口内有归属事实的 Goal，或显示指定目标集合并明确零记录；归档目标明确纳入或提供可辨的过滤；保持全日恢复背景，是否增加每 Goal 的细分另行决定。无 Goal 时间不构造新的 Goal 实体。

**Decision:** goalSummaries 只显示当天对账窗口内有正时长记录贡献的 Goal，没有记录的目标不占一行；archived Goal 有对应记录时同样显示，并标注“已归档”。每个目标输出相关总时长及 progress、stuck、recovery、无 annotation 四项细分，四项合计为总时长，各自按 Q-014 携带近似标志。无 Goal 的时间不进入目标列表，不合成“无目标”Goal，但正常参与账本与全局统计。当天恢复总时长继续单独展示，包括有 Goal 和无 Goal 的 recovery；与每目标恢复属于不同观察范围，不重复相加。不同 id 的同名目标保持独立（Q-019）。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受上述五条规则。

**Current status:** DECIDED

**Blocks implementation:** 否：目标选择、归档显示、四项细分及无目标记录边界已确定；无匹配记录的表达仍见 Q-021。

## Q-021

**Question:** 摘要中无匹配记录、尚未记录与数值零如何表达？

**Why it matters:** 空参与集的时长和为 0，但没有 SleepSession 不证明用户没有睡觉，没有 progress annotation 也不证明用户没有推进。源文档未定义 sleepSummary / goalSummaries 在无记录、多条候选或未能选定摘要时的空值结构与文案。

**Related domain objects:** DayLedgerView、sleepSummary、goalSummaries、派生时长

**Possible options:** 用空摘要并呈现尚未记录；用明确区分记录存在性的输出结构；在记录时长为 0 的展示旁说明数据范围。最终表示必须避免把缺少记录当成不存在活动。多条睡眠的选择仍由 Q-010 决定。

**Decision:** 没有主睡眠记录显示“尚未记录主睡眠”，没有小睡记录显示“尚未记录小睡”，分别判断，不显示实际睡了 0 小时。没有目标相关记录时目标列表为空，显示“这段时间还没有目标相关记录”。有目标记录但缺少某节奏细分时，以“未记录推进”等表达记录缺失，不声称没有发生该活动；卡住、恢复及未标记项同样明确表达记录情况。有记录的正时长若在分钟展示中会成为 0 分钟，显示“少于 1 分钟”，近似时显示“约少于 1 分钟”。计算结果分别保留记录是否存在、实际时长及 hasApproximation，不以数值 0 判断缺失。一般时长仍遵循 Q-017 的最终汇总后四舍五入。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受缺失记录文案、微小时长显示与独立存在性标志五条规则。

**Current status:** DECIDED

**Blocks implementation:** 否：摘要缺失表达、正时长舍入为零的展示及返回结果的独立存在性已确定。

<!-- Phase 4：平台范围影响持久化驱动；已有字段与存储语义问题沿原编号补充。 -->

## Q-022

**Question:** 第一版需要正式支持哪些运行平台？

**Why it matters:** Source of Truth 没有指定移动端、桌面或 Web 的首发范围。当前 Flutter 工程中的平台目录不代表发布承诺；本地持久化驱动的运行支持、部署条件与集成验证依赖此答案。架构可以建议本地 SQLite，但不能据此直接选包或承诺所有平台。

**Related domain objects:** 全部持久化领域对象；运行环境与数据访问实现

**Possible options:** 首版聚焦明确列出的移动平台；移动加指定桌面平台；包含 Web 并明确其本地数据保存要求。需由产品确认具体平台清单，再做驱动选择。

**Decision:** 第一版正式支持 Android 和 Web。iOS、Linux、macOS、Windows 不纳入首发支持与验收范围。此决定只确定平台范围，不直接选择持久化驱动、具体包、浏览器兼容矩阵或部署方案。

**Decision source:** 产品负责人于 2026-09-25 明确确认。

**Current status:** DECIDED

**Blocks implementation:** 否。平台范围已确定；持久化驱动仍须针对 Android 与 Web 完成技术核验，两个平台的接入及发布验证仍须在对应 Task 中取得实际证据。

<!-- Phase 5：核心记录入口的验收依赖明确的时间建议合同。 -->

## Q-023

**Question:** 非 Gap 入口的普通补记如何产生默认建议时间区间，缺少前序记录或存在多个候选区间时如何处理？

**Why it matters:** §27 明确“时间是系统提出的可修改假设，活动是用户主要输入”，§28 明确 Gap 入口可直接预填缺口区间；但没有唯一规定普通记录入口如何选择起止、使用当前时间还是历史浏览日期，以及系统建议的初始 startPrecision / endPrecision。不能以实现默认值决定这些产品行为。

**Related domain objects:** TimeBlock、TimePrecision、DayLedgerView、UnresolvedSpan；普通记录 UI 输入模型

**Possible options:** 按已选缺口建议；按所浏览日期和已有记录提出候选后由用户确认；根据明确的上下文规则建议并在无法推断时请求时间输入。需分别确定适用条件与精度初值；这些选项均不得取消用户修改时间的能力。

**Decision:** 普通“补一笔”在查看今天且当天已有事实、存在延伸至当前时刻的尾部 Gap 时，直接建议该 Gap。没有此尾部 Gap 或查看历史日期时，展示该日 Gap 供选择，只有一个也先确认；当天对账窗口完全无记录时不默认覆盖从午夜到当前时刻，而要求手动填写开始与结束。没有 Gap 或查看未来日期时，同样手动填写。点击具体 Gap 的“补一笔”直接预填该 Gap，属于明确选择，不受普通入口无记录分支影响。系统建议或 Gap 预填的新草稿起止精度均默认 approximate；手动填写或修改时间不自动变为 exact，精度由用户分别明确选择。所有建议均可修改，正式保存仍执行正区间、不重叠等校验。

**Decision source:** 产品负责人于 2026-09-25 在逐项澄清中明确接受六条规则；上一条 14:00 结束、现在 15:20 时，普通入口可预填尾部缺口 14:00–15:20。

**Current status:** DECIDED

**Blocks implementation:** 否：普通入口、Gap 入口、缺少前序记录、多候选及初始精度合同已确定；复用该算法的其他入口同样遵循此合同。
