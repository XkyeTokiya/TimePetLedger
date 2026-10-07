# Open Questions

本文件只登记 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) 无法唯一回答的问题。Phase 1 建立；编号稳定，后续阶段可追加。Possible options 是用于澄清的候选，不是产品决定，也不是已批准的 Engineering Recommendation。Blocks implementation 只指所列局部能力，不表示必须暂停全部工作。

**当前状态（2026-09-25）：** Q-001–Q-023 全部 DECIDED。本轮通过逐项问答确认剩余 12 项；决定已同步对应职责文档，未执行功能开发。各项 Why it matters / Possible options 保留问题提出时的背景，当前结论以 Decision 和 Current status 为准。

已经确定的事项不重新提问：Unknown 是合法持久化事实；Gap 不持久化；节奏解释可选；卡住原因与恢复细节可选；Goal 仅为时间归属；自然日是投影边界；主时间轴暂不支持并行主要事实。

> 展示决定追溯补充（2026-10-04）：本文件Q-014/Q-017/Q-018等历史决定中“约”前缀示例，仅其数值呈现部分已被用户“首版全应用不显示约”决定取代。Q-018中的“约少于1分钟”现为“少于1分钟”。记录存在性、舍入、精度字段及传播均不变，权威现行规则见DOMAIN_RULES LEDGER-007及摘要显示规则。历史Decision文本留作追溯，不作为旧前缀验收依据。

当前补充（2026-10-06）：Q-001–Q-030为DECIDED；Q-031旧精度数据处理、Q-032睡眠区间建议为UNDECIDED。Q-030替代Q-003 / Q-023 / Q-026中由用户选择起止精度的要求；旧Decision保留追溯，不能用于恢复精度选择。Q-029建议执行边界与与首次睡眠检查的衔接已由用户本轮决定。具体交互仍须原型验证；决定登记不标记实现完成，不自动启动Flutter任务。

当前补充（2026-10-07）：Q-032睡眠区间建议与Q-035活动 / 睡眠时间日期自动化已DECIDED，并获授权实施TIME-01。Q-035替代Q-023的初始化规则和两端时间编辑中间层；Q-031继续UNDECIDED。实现与验证状态见[TIME-01](../planning/TIME_RECORDING_AUTOMATION.md)。

同日后续复审：用户要求深入审视多日断记与漏睡眠，随后明确最首要要求为直接完整预填、约80%无需时间选择 / 调整、其余也给可改端点，且学习个人睡眠、无历史用常规作息。Q-036据此DECIDED，替代“先选候选才填值 / 缺少确定信息留空”的复审方案；Q-035缓存 / 日期 / 合法性合同保留，其旧初始化仅供追溯。确切默认时刻、学习来源 / 参数、活动估计及评分 / 冲突策略登记Q-037 UNDECIDED；Q-031仍未决。本轮只设计与文档，候选见[算法设计稿](../planning/TIME_RECORDING_AUTOMATION_REVIEW.md)。

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

**Question:** 未完成记录 / 复盘输入需要保留到什么时候？

**Why it matters:** §28 有预填草稿，§21 的正式 DailyReview 包含 tomorrowFirstStep，但未定义未完成输入的保存与恢复行为；不能自行添加 draft 状态或将必需字段改为可空。

**Related domain objects:** UI Models、TimeBlock、DailyReview

**Possible options:** 草稿仅保留于当前交互；另存临时草稿并与正式领域实体分开。

**Decision:** 2026-10-08用户明确取消“草稿”的产品概念，取代之前的跨关闭 / 跨刷新恢复决定。活动、睡眠和每日复盘的新建、Gap补记及已有事实更正，仅在当前应用 / 网页会话内自动保留未完成输入快照。同一context再次进入时，表单展示前询问继续上次填写 / 修改，或重新填写 / 编辑。Android后台切换和页面内导航仍属当前会话；冷启动、进程重启、Web刷新或重新打开都不恢复旧输入。

只有相对初始基线发生实际修改才建立快照；恢复到基线后自动清除。“继续”恢复文本、选择及活动步骤，但新建 / 补记的时间初值仍按Q-036重算；“重新”清除快照并从当前事实、目标和时间建议开始。正式保存失败留在页面且保留输入；已提交残留先识别结果并收尾，不得重复提交。原事实或context失效时自动忽略并清除快照。快照不属于正式事实，不参与账本、统计、冲突或睡眠学习；睡眠学习反馈独立持久化。界面不提供草稿状态、数量、列表、开关或技术清理错误。

**Decision source:** 产品负责人于2026-10-08在评估后要求采用“会话内输入恢复”方案；该决定明确取代2026-09-25的自动本机持久化草稿合同。

**Current status:** DECIDED

**Blocks implementation:** 否：会话边界、恢复选择、失效处理和睡眠学习分层已确定；实施按INPUT-RECOVERY-01–04追踪。

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

**Decision supplement (E1-T06):** RhythmAnnotation.stuckReasonText 与 continuationHint 均为可选长文本，清理后最多 2,000 个 Unicode 码点；沿用首尾空白清理、空值归一为 null 和内部格式保留规则。

**E1-T06 supplement source:** 产品负责人于 2026-09-25 明确授权 agent 选择适合的长度分类并继续；agent 选择两个字段均为长文本，以容纳多行原因说明与接续上下文。

**Decision supplement (E1-T07):** DailyReview.summary、reflection 均为可选长文本，TomorrowFirstStep.text 为必填长文本，清理后均最多 2,000 个 Unicode 码点。沿用首尾空白清理、可选空文本归一为 null、必填文本非空和内部格式保留规则；下一步仍为单一行动意向。

**E1-T07 supplement source:** 产品负责人于 2026-09-26 明确授权 agent 自主决定这三个字段的长度分类；agent 选择均为长文本，以容纳多行概述、反思与具体行动说明。

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

## Q-024

**Question:** 无效时间原文能否应用，取消、重开和重启如何恢复？

**Source sections:** §27–28；UI_IMPLEMENTATION_DESIGN未完成原文要求；2026-10-05基线审查第4项。

**Why it matters:** 活动草稿保存解析后的时间，无效文本返回后变为null。睡眠原文合同不能自动扩展为活动草稿存储政策。

**Related domain objects:** RecordingDraft、SleepDraft、临时时间输入。

**Possible options:** A（建议）：无效原文留在弹层，应用时报错且不关闭；修正后应用，取消丢弃本次临时改动，重开显示上次已应用值。B：允许应用无效原文，父草稿保存原文并支持重开/重启，需要授权活动草稿结构及兼容迁移。正式写入校验均不变。

**Decision:** 用户于2026-10-05选择A。无效原文归弹层临时输入所有；应用时报字段错误、不关闭、不改父草稿，修正有效才应用。取消/返回/关闭丢弃本次临时修改；重开或重启显示上次已应用值（未填仍空），不恢复未应用原文。父表单其他草稿仍按Q-012恢复。不新增活动草稿原文字段或迁移。覆盖旧允许未完成/无效时间原文应用的要求；不删除历史草稿，恢复无效旧值仍须修正后应用。正式保存的冲突等业务校验保持不变。

**Current status:** DECIDED

**Blocks implementation:** 否；应用合同已确认，不等于授权启动RB-01。


## Q-025

**Question:** 新活动记录的常用目标如何确定，是否允许每笔调整？

**Why it matters:** 长期目标需要提供稳定上下文，但从上一笔或单个活跃目标自动选择会擅自决定时间归属；普通生活和恢复草稿也不能被常用设置无条件覆盖。

**Related domain objects:** Goal、TimeBlock；本机UI偏好与活动输入草稿。

**Possible options:** 用户明确指定常用目标；沿用上一笔目标；不预选，由用户在第一幕选择。

**Decision:** 用户选择“由用户明确指定一个常用目标，每笔可更换或取消关联”。它是新活动的可修改初值，目标在问答过程中持续显示；更正已有记录及恢复草稿以原关联为准，本笔调整不隐式修改常用目标设置。目标仍为可选时间归属，活跃 / 归档引用继续遵守Q-006，不创建长期目标之外的任务模型。

**Decision supplement（2026-10-06目标管理）：** 成功归档常用目标时清除常用选择；恢复目标后需手动再设，不自动恢复常用或选择其他目标。有引用的删除按Q-006转为归档，适用相同清除；未引用目标被物理删除时也不保留该常用选择。原记录和活动草稿的自身关联保持原合同，不因偏好清除自动取消历史关联。失败不声称目标已归档或常用选择已清除。

**Decision source:** 用户于2026-10-05在记录体验讨论中，通过异步问题明确选择上述选项。

**Supplement source:** 用户于2026-10-06通过异步问题选择“清除常用选择；恢复目标后需手动再设”。

**Current status:** DECIDED

**Blocks implementation:** 否：常用目标来源、本笔可更换 / 取消、归档后的清除与恢复后手动再设已确定。不能新增归档引用，不因此授权正式偏好存储 / 应用开发。

## Q-026

**Question:** 初版活动记录以何种交互顺序填写，旧表单如何保留，时间选择以何种基础组件落实？

**Why it matters:** 仅靠折叠目标和节奏不能保障复盘所需解释可见；第一幕的引导也不能把可选节奏变成保存门槛。时间的可点击入口不等于完整路径无需键盘。

**Related domain objects:** TimeBlock、RhythmAnnotation、Goal；活动presentation与本机UI偏好。

**Possible options:** 继续表单布局；活动优先问答；节奏优先问答并保留另一种表单方式。

**Decision:** 初版优先问答引导，顺序为第一幕节奏、第二幕事项、第三幕时间；目标至少在第一幕出现，本次设计采用持续显示。原表单设计可保留，用户在设置中切换。时间完整调整路径可不依靠键盘；大部分基础元件优先使用Material 3成熟组件。三种节奏和无解释、Unknown、起止精度、时间建议、原子保存等领域合同不变；可选解释不得因问答顺序成为必答项。

**Decision source:** 用户于2026-10-05明确提出问答优先、三幕顺序、目标出现、设置切换、无键盘时间调整及MD3组件基线；随后回复“设计基本符合我的想法”，并要求先更新文档。

**Current status:** DECIDED

**Blocks implementation:** 否：基本设计已获认可，[三幕规格](../planning/GUIDED_RECORDING_DESIGN.md)作为原型基线。按钮推进方式、补充内容位置、模式切换生效时点及组件布局仍待原型验证；认可基本设计不等于逐项视觉 / 平台验收通过，Flutter实施仍以明确任务授权为准。


## Q-027

**Question:** 新首页的导航与摘要第一版以什么为设计基线？

**Why it matters:** 旧页面计划和摘要参考图不能替代用户本轮决定，也不能由示例引入目标分级、评价或新的统计口径。

**Related domain objects:** DayLedgerView、SleepSession、Goal、RhythmAnnotation；首页presentation。

**Decision:** 首页整体布局和风格沿用户第一张参考；仅跨年显示年份，只有点击日期选日，右上入口暂缓。首页横滑时间线 / 摘要 / 复盘，共享所选日期；时间线保持参考。菜单承接目标与设置，记录可从详情编辑 / 删除，Gap整行及“补记”可进入，底部保持记录睡眠和记录一笔。摘要以一天时间构成和各目标时间构成环图为第一版，完整睡眠、目标节奏和全局恢复作为补充，沿既有投影 / 缺失 / 精度合同，不照搬第二参考的周月筛选或目标分层。复盘暂不细化，AI仅未来意向。用户认可摘要信息量与建议区域位置；具体视觉仍可打磨。

2026-10-07补充：删除首页顶部“其中想不起来……（已包含在已交代时间中）”整段辅助说明；保留已交代 / 尚未记录概览、摘要中的Unknown分类及既有统计口径。

同日后续补充：用户采用推荐的fl_chart圆环及Material 3 ListTile图例，明确授权完成首页一天时间构成 / 目标时间构成两种图表替换与该依赖接入。手机纵向放置圆环和图例，宽屏有足够空间时并排；保留实际毫秒占比、中心汇总、图例选择占比、Gap虚线及既有摘要缺失语义。允许圆环分段点击与图例联动，不改变数据或统计来源。

同日后续补充（首页导航与三页改版）：用户以交互原型为视觉与交互参考，明确取消首页“时间线 / 摘要 / 复盘”标签页——首页只保留时间账本，摘要与每日复盘改为侧边栏独立页面，目标、设置入口保留。首页采用跨日期连续时间轴：按日期分组、吸顶日期提示、上下连续滚动、左右滑动切日（边缘留给侧边栏 / 系统返回）、点击日期打开日历、历史日期提供“回到今天”。顶部日期代表当前浏览日期，“已交代 / 尚未记录”只统计该日，跨日滚动 / 滑动切日 / 日历跳转共用同一日期规则。摘要页在既有真实统计与fl_chart图例上重排，不新增效率评分；复盘页按DailyReview与下一步合同组织阅读、填写与正式保存并保留当天记录入口。从首页进入摘要 / 复盘继承当前日期，进入后各页独立管理；返回首页恢复原日期与阅读位置。本补充取代上文“首页横滑时间线 / 摘要 / 复盘，共享所选日期”的标签页方案；跨日事实不拆持久化、不重复统计，Unknown仍计入已交代，Gap保持派生。

**Decision source:** 2026-10-05用户逐项回复、委托细化、要求推进，并在交互预览后回复“合适”。素材与证据见[交接](../planning/UI_REBUILD_PLAN.md)。

2026-10-07修复授权：独立验证复现切日失败假空态、斜滑判定失效、重建后跨午夜跟随失效，并确认恢复前台统计不刷新及大字排版问题。用户随后要求“请你制定方案并修复”，授权[HOME-NAV-02](../planning/HOME_NAV_FEED_FIXES.md)：读取成功后整体提交窗口、失败保留旧阅读并可重试、真实双轴滑动判定、稳定日期跟随、首页恢复前台重读，以及标题 / 时长自适应排版。保持独立页日期 / 草稿和领域统计合同。

同日动效反馈：用户指出“当前缺少动效，切换的时候很多数字和文字还会闪烁”，授权[HOME-NAV-03](../planning/HOME_NAV_MOTION.md)继续修复重复定位 / 焦点闪回，并添加首页时间轴、日期和时长的过渡。只调整展示，真实统计值、退出视图隔离、系统关闭动画、失败保留与阅读位置合同保持。

补充来源：2026-10-07用户明确要求完全删除上述首页辅助说明；本轮实施授权仅覆盖此文案调整。

后续实施来源：用户在fl_chart / Syncfusion选型建议后明确要求“请你使用这个来彻底完成吧”，采用推荐的fl_chart + Material 3 ListTile方案。

补充来源（首页导航与三页改版）：2026-10-07用户指定交互原型并明确授权取消首页标签页、摘要 / 复盘独立页面、跨日期连续时间轴、摘要与复盘重排；实施与验证见[前端交接](../planning/UI_REBUILD_PLAN.md#首页导航与三页改版2026-10-07后续授权)与[实施报告](../reports/HOME_NAV_FEED_REPORT.md)。

**Current status:** DECIDED

**Blocks implementation:** 否：设计方向已定；2026-10-07首页文案删除与fl_chart / ListTile图表替换已由用户单独授权，其余范围不自动获准实施。真实平台视觉验收仍需对应证据。

## Q-028

**Question:** 首页建议区域的优先级、阈值、默认时点和开关是什么？

**Why it matters:** 原参考卡片并非复盘专属，用户需要打开应用时合适的记录入口；不能解释为新任务管理实体或系统通知授权。

**Related domain objects:** SleepSession、派生Gap、DailyReview；本机UI偏好。

**Decision:** 优先级睡眠 > 记录 > 复盘。连续尾部Gap直到打开应用达到2小时，提供记录建议；默认睡眠时点08:00、晚间复盘22:00。整体功能默认开启，设置提供整体开关；关闭后区域隐藏，暂不提供跳过。三类均不满足时普通问候。文案简短自然，具体句子仍可打磨。卡片用于当前建议动作，不新建任务对象，不启动后台通知。

**Decision source:** 2026-10-05用户明确“睡眠>>记录>复盘”、2小时、问候、无跳过、设置开关、默认开启及早八 / 晚十；委托细节继续打磨。

**Current status:** DECIDED

**Blocks implementation:** 本条明确值已确定；完整建议行为仍依赖Q-029，不由默认值或原型样例补全。

## Q-029

**Question:** 建议区域的实际时窗、更新时机与既有首次睡眠检查如何衔接？

**Why it matters:** 08:00与22:00只是默认时点，尚不能推导睡眠提示结束时刻、每天首次打开 / 每次打开政策、历史浏览行为或持续停留刷新。Q-010既有首次睡眠检查已实现，不能未经决定撤销或产生重复提示。

**Related domain objects:** SleepSession、DailyReview、派生Gap；首页UI状态与本机偏好。

**Possible options:** 延续首次检查并整合入建议区域；建议作为独立区域但明确避免重复；按实际今天判断或随浏览日显示；打开时更新或停留期间更新。还需明确默认时点是否可由用户修改、夜间或特殊作息的提示时窗。以上均为候选，不是决定。

**Decision:** 采用 2026-10-06 用户对四个边界的明确选择：

- **睡眠建议时窗：** 当地时刻处于 `[睡眠时点, 睡眠时点 + 4 小时)`，默认 08:00–12:00；且当天尚未记录主睡眠（按 Q-010：醒来日期为今天、endedAt 不晚于当前时刻且 type=mainSleep 的记录至少有一条即视为已记录）时，提示记录睡眠。睡眠时点为可编辑的本机偏好，默认 08:00。
- **记录建议：** 尾部连续 Gap 延伸至打开应用时的当前时刻且达到 2 小时（Q-028 阈值）；不把不连续缺口相加，也不使用非尾部缺口。
- **复盘建议：** 当地时刻 ≥ 复盘时点时提示；复盘时点为可编辑的本机偏好，默认 22:00。
- **优先级与兜底：** 睡眠 > 记录 > 复盘；三类均不满足时显示问候，问候按当地时刻分段，不引用可编辑时点。
- **历史 / 未来日期：** 浏览历史或未来日期时只显示问候，不判断睡眠 / 记录 / 复盘建议。
- **更新时机：** 进入或返回首页、应用从后台恢复时，按当时的当前时刻重算；不在停留期间连续或定时刷新。
- **与既有首次睡眠检查衔接：** 建议区域取代每日首次打开时的“确认主睡眠”弹窗；已记录主睡眠时不再提示。不新增跳过或稍后功能（Q-028）。

进入记录仍遵循 Q-023 时间建议与既有草稿 / 原子保存合同；建议区域只提供当前动作，不新建任务实体、不启动系统通知。

**Decision source:** 2026-10-06 用户逐项回答四个边界问题：睡眠提示窗口（08:00–12:00）、与首次弹窗的关系（用建议区域取代弹窗）、历史日期与刷新（历史日只显示问候、返回首页时刷新）、默认时点是否可改（允许修改）。

**Current status:** DECIDED

**Blocks implementation:** 否：边界已确定，可按本条实现建议区域；默认时点可改需新增本机偏好字段。

## Q-030

**Question:** 回顾式时间是否由用户选择准确 / 大概，活动子选项如何呈现？

**Why it matters:** 旧设计保留精度选择和回改摘要，增加输入负担，与用户本轮明确反馈冲突。

**Related domain objects:** TimeBlock、SleepSession、RhythmAnnotation；记录presentation。

**Decision:** 回顾式输入的时间统一为approximate，不提供精度选择，不因选择具体分钟声称exact。目标文字下方虚线提示可编辑，移除目标条上的更换 / 取消关联按钮；关联选择内仍可选择不关联。节奏存在适用子选项时增加一页：卡住原因、休息方式与感受仍可留空；推进当前无枚举子选项，直接进入事项。不显示01/03步骤计数，时间页删除节奏与事项回改摘要，通过上一步修改且保留输入。备注与接续点仍可选。

**Decision source:** 2026-10-05用户本轮明确反馈，特别强调“时间精度永远只可能是大概”，不交由用户选择。

**Current status:** DECIDED

**Blocks implementation:** 否：新输入与交互方向已确定；旧exact事实处理见Q-031，原型修改不等于正式实现验收。

## Q-031

**Question:** 已存exact事实和旧草稿如何处理，领域值域 / 存储结构是否随新精度政策调整？

**Why it matters:** 新输入一律approximate已确定，但旧模型包含exact且派生结果依赖边界精度；删除选择器不能作为改写历史事实或删除字段的授权。

**Related domain objects:** TimeBlock、SleepSession、记录草稿、TimePrecision及近似传播。

**Possible options:** 保留旧事实并只改变新输入；显式迁移旧事实与草稿；另行调整存储值域。需核查正式工程及实际数据后明确处理范围。

**Decision:** 尚未决定。本轮只修改原型与设计文档，不改写真实数据或实施schema迁移。

**Current status:** UNDECIDED

**Blocks implementation:** 阻塞依赖旧exact处理及schema变更的正式迁移 / 编辑兼容工作；不阻塞当前新记录原型。

## Q-032

**Question:** 新建睡眠草稿是否建议起止日期 / 区间，主睡眠与小睡如何按入口提供建议？

**Why it matters:** 睡眠首次检查与08:00提示时点不定义实际入睡 / 醒来时间；Q-023描述普通活动与Gap补记，不能直接复制为睡眠的区间建议。历史浏览、手动入口和建议卡入口可能有不同上下文。

**Related domain objects:** SleepSession、睡眠输入草稿；睡眠presentation。

**Possible options:** 两端空白，由用户点选；只建议日期，不建议时分；按已确定上下文提供用户可修改的候选区间。恢复草稿 / 编辑记录优先自身原始区间，不能重新猜测覆盖。

**Decision:** 2026-10-07用户要求睡眠沿用三种时间上下文，并授权实现。睡眠补记优先使用前后完整记录夹住的区间；只有已知起点时，结束为`max(当前时刻, 起点+30分钟)`；无可用起点则由用户手动调整。查询跨自然日邻居，主睡眠 / 小睡共用时间与日期规则，不按昼夜推断类型或固定整夜时长。每次新建 / 补记重算可确定的起止，不以旧缓存端点代替；同次编辑保持稳定。时间选择后直接接续日期选择，取消不应用未完成选择，无两端编辑中间层。详见Q-035。

后续Q-036明确完整预填与个人睡眠学习，以上初始化选取保留作TIME-01历史基线；未来算法不以最早闭合Gap或没有起点就留空为默认。具体时刻 / 学习模型待Q-037，已有日期交互 / 更正恢复 / 合法性继续保留。

**Decision source:** 2026-10-07用户对活动三种区间的明确解释、睡眠补充设计要求，以及“日期的选择应直接接续在时间的选择上……如果没有其他需要确认的问题就请你开始工作吧”。

**Current status:** DECIDED

**Blocks implementation:** 否；本轮授权时间初始化和直接编辑，不包含Q-031历史精度迁移。

## Q-033

**Question:** 目标详情的投入图、日期范围和历史记录怎样展示？

**Why it matters:** 目标详情不是单日goalSummaries；需要明确周月范围，避免把未来时间、无记录日期或同名其他目标计入投入。

**Related domain objects:** Goal、TimeBlock；派生目标投入及详情presentation。

**Decision:** 用户要求柱状图 / 热力图可切换，热力图周 / 月在设置中选择，历史记录位于底部，默认约5条。明确采用柱状图近7天（含今天）、热力图本自然周 / 本自然月，今天只计已发生时间。沿既有goalId归属、自然日窗口、近似传播和缺失表达；不改变Q-020单日摘要参与集。列表设置常用并高亮、柱状图默认、周从周一开始、首次热力图默认周、每次显示5条及“查看全部”的具体布局为待评审原型建议，不能据此扩展Goal事实字段。

**Decision supplement（2026-10-06布局反馈）：** 柱状图刻度按当前范围的实际日投入自适应，4小时不是固定展示或业务上限；时长行末承接范围 / 已记录投入标签，目标名称行末承接常用标签，避免辅助标签单独占行。列表常用操作入口仍待评审。

**Decision source:** 2026-10-06用户目标详情三点要求、回复日期范围问题“采用上述范围（建议）”，以及随后关于自适应刻度和标签同行的明确反馈。

**Current status:** DECIDED

**Blocks implementation:** 日期范围与方向已确定；仅授权原型设计。具体控件位置和列表常用入口尚待评审，不代表Flutter实施获准。

## Q-034

**Question:** 设置页的高级数据入口及清空 / 测试数据添加范围是什么？

**Why it matters:** 单对象删除、归档和草稿放弃合同不定义全量清空；测试数据也不能从已有原型样例推导为正式数据或覆盖授权。

**Related domain objects:** TimeBlock及依附RhythmAnnotation、SleepSession、Goal、DailyReview及其下一步、输入草稿、本机偏好。

**Decision:** 设置页先规划可扩充的分类入口；用户明确高级设置提供“添加测试数据”和“清空当前数据”。清空活动、睡眠、目标、复盘及未保存草稿，清除常用目标选择，保留界面、记录方式、提醒等设置。仅数据为空时允许添加测试数据；已有数据时不追加、不覆盖。候选分组为界面设置、记录与提醒、高级设置、关于，分组命名 / 布局、关于的具体条目与测试数据集内容尚未确认。本轮只是设计和文档，不执行数据操作或授权正式实施。

**Decision supplement（2026-10-07）：** 用户要求添加测试数据默认模拟一周的真实使用痕迹：以点击添加的当天为最后一天、日期向过去排列，条目覆盖日常活动、未知、目标归属、节奏解释、睡眠与复盘等真实记录形态，而不是少量占位示例。当天不出现晚于点按时刻的条目；具体文案、条数、时点与分布属实现细节，可在不改变该形态要求下调整。

**Decision source:** 2026-10-06用户设置分类与两个高级入口要求，并选择“清空上述数据，保留设置（建议）”“仅允许在数据为空时添加（建议）”；2026-10-07用户进一步明确实例数据应为一周的真实使用数据、条目类似真实使用痕迹，日期以点击添加的日期向过去排列。

**Current status:** DECIDED

**Blocks implementation:** 两个入口及核心操作范围已确定；测试数据集、实际写入与清空事务 / 并发 / 失败处理的实施合同须在正式任务中具体化，不以此授权真实操作。

## Q-035

**Question:** 活动 / 睡眠新建与补记怎样初始化完整日期时间，缓存和时间组件怎样承接？

**Why it matters:** 旧Q-023使用自然日Gap切片及草稿优先恢复，不能表达跨日完整边界与至少30分钟的开区间初值；两端编辑弹层增加一次应用步骤。

**Related domain objects:** TimeBlock、SleepSession；时间输入缓存、RecordingDraft、SleepDraft。

**Decision:** 按1闭区间、2已知起点 / 未定终点、3跳跃记录分类。补记使用1/2，普通新建使用2/3；睡眠补记优先1，其次2。1使用相邻真实记录的完整结束 / 开始；2结束=`max(打开时当前时刻, 起点+30分钟)`，30分钟只为建议，不是事实最短时长；3不自动推断。相邻查询跨日，活动与睡眠同样处理昼夜颠倒和跨日。每次进入时1/2重算，写入本次编辑缓存；其他未提交内容保留；全开区间不恢复旧端点，由用户在本次编辑中填写，同次编辑不重复初始化。已经正式提交但收尾失败的草稿先识别既有事实，不重算后重复提交。既有正式记录编辑沿Q-013，从自身事实 / 编辑输入读取，不套新建区间算法。

直接点击端点，先时分、再日期；日期自动建议考虑另一端完整日期与区间顺序，用户仍可改任意日期，两组件都完成才应用单端点，取消保持当前值。删除两端时间弹层和额外确认；时长可用于保持开始推算结束或保持结束反推开始。原子不重叠和正区间保存校验不变，不新增长期进行中状态或实际结束确认。Q-031旧事实精度迁移仍未决。

后续Q-036要求所有场景先给完整可改估计，约80%无需额外时间操作，并学习个人睡眠；因此3仅手动、相邻空白整段作为普遍初值的部分更新，以上时间选择 / 缓存 / 更正恢复及合法性保留。具体预测模型见Q-037候选，本段追溯的TIME-01代码交付状态不因此变更。

**Decision source:** 2026-10-07本轮用户明确纠正“当前时间+30分钟”，指定三种区间、取消时间缓存恢复为初始化依据，要求活动 / 睡眠保留自动日期并授权工作。其他草稿内容与已提交恢复沿Q-012 / Q-013；新建 / 补记起止不从旧缓存恢复。

**Current status:** DECIDED

**Blocks implementation:** 否。本轮限TIME-01，不自动推进其他功能。

## Q-036

**Question:** 时间初始化是否应等待单笔线索唯一 / 用户先采用候选，还是直接给完整估计，并怎样降低多日断记 / 漏睡眠的输入负担？

**Why it matters:** Q-035依据相邻事实预填完整空白，但空白可能跨数日或混有多件事。同一份账本可以对应不同单笔起止，单凭相邻端点不能唯一还原；上一笔结束只能证明空白边界，睡眠入口不能定位哪次睡眠。闭合 / 开放是几何上下文，单笔锚点与时长是另一维度；日期、现在及30分钟也须区分约束与默认候选。不重叠与覆盖完整均不能证明归属正确，误用初值会影响时间线、目标投入、睡眠摘要和复盘背景。

**Related domain objects:** TimeBlock、SleepSession、Unknown；派生Gap / DayLedgerView、DailyReview；新建草稿、首页建议及补记交互。

**Possible options:** 历史讨论包括自动采用相邻空白（Q-035基线）、有确定线索才填端点 / 其他先选候选，以及依据个人习惯与上下文直接预测完整区间。用户明确拒绝先选候选才给时间，选择直接完整预填；具体模型参数另见Q-037，不把历史未认可方案当现行要求。

**Decision:** 用户明确最首要要求为约80%常见记录无需额外时间选择 / 调整，必须覆盖连续多日未记及漏睡眠；剩余情况也先给完整端点供手改。进入新建 / 补记直接初始化完整日期时间，不因非唯一 / 低把握留空，不要求先采用范围或候选。引入过往睡眠学习，无历史默认常规作息。具体默认时刻、学习参数、活动预测、评分 / 冲突策略待Q-037，不声称80%已实测。每次进入重算、同次稳定、时分后接日期保留；更正 / 提交后恢复、不重叠、无时长上限、睡眠按醒来日摘要及Gap / Unknown合同不变。预测睡眠只用于编辑初值，不自动形成正式事实或参与统计。本轮仍是需求与模型设计，不授权代码修改。

**Decision source:** 2026-10-07用户先要求六场景深入复审，随后明确“最首要要求是不需要选择覆盖80%的内容”“剩余20%……用户在你提供的基础上手动进行调整”，并要求学习过去睡眠、默认常规作息。

**Current status:** DECIDED

**Blocks implementation:** 否：交互优先级与学习方向明确；睡眠首版参数及TIME-04授权见Q-037后续决定，其他算法 / 标定仍未决；不改写TIME-01历史交付状态。

## Q-037

**Question:** 直接完整预填采用哪种个人睡眠 / 活动模型、冷启动时刻、学习来源与权重，以及日期定位 / 评分 / 冲突策略？

**Why it matters:** Q-036确定必须给完整估计，但未指定常规作息几点、学习多少历史、如何适应多种作息与变化、避免原样接受初值自我强化，或哪些活动区间更适合多日断记。现有SleepSession没有预测来源、用户改过哪端或原时区，不能用createdAt / updatedAt假造这些信息。80%零时间操作率也不能等同真实边界准确率。

**Related domain objects:** SleepSession、TimeBlock；新建 / 补记编辑状态、学习元数据 / 派生模型、Gap / DayLedgerView；首页、摘要、统计及复盘。

**Possible options:** 候选推荐联合学习循环入睡相位与完整时长，保留昼睡 / 夜睡等多峰，以近期与来源加权；内部结合实际占用与日期焦点选择一组完整起止，活动比较接续 / 近期一笔及跨可能睡眠代价。主睡眠冷启动23:00–07:00、无历史活动 / 小睡30分钟、56天 / 最多60条、14天衰减、90分钟时刻带宽、0.25对数时长宽度、默认约2个有效样本、1 / 0.5 / 0.1来源权重及弱反馈上限在初稿中均为候选；后续睡眠首版已获用户批准，具体生效范围以下方Decision为准，其他活动 / 标定仍候选。星期条件差异、模式变化、评分与变形容差需标定，不用日历星期假造用户实际工作日。无论选何参数都须直接预填，不恢复被拒绝的先选择 / 留空方案。完整设计与反例见[算法设计稿](../planning/TIME_RECORDING_AUTOMATION_REVIEW.md)。

**Decision:** 部分参数已确定：用户明确普通活动新建在当前尾部连续Gap≥5小时（含边界）时，应用近期一笔方案，起止为`[打开时刻−60分钟,打开时刻)`；不再等到三天，也不以缺少活动历史为条件。按跨日真实连续空白计算，午夜不截断，正式活动 / Unknown / 睡眠中断，预测睡眠不中断；没有前序事实只取已知对账窗口。此分支优先于其他初值评分，旧空白保留，可改任意合法端点。仅此分支改为60分钟，不把其他开区间30分钟或小睡候选默认一起修改；历史Gap补记 / 睡眠预测不扩用这一条。

2026-10-07用户报告多日空白被预填为56小时睡眠，并选择“采用推荐模型与参数”。睡眠首版采用本条推荐的联合个人模板 / 多峰、23:00–07:00主睡眠冷启动、小睡30分钟、56天 / 最多60条、14天半衰期、90分钟时刻核、0.25对数时长核、先验量2、1 / 0.5 / 0.1来源权重及弱反馈20%上限。授权[TIME-04](../planning/SLEEP_TIME_PREDICTION.md)独立睡眠模型、完整日期定位、占用检查、缓存 / 类型切换保护和辅助学习反馈存储；这些参数不再是未批准候选。

其他活动估计、星期条件 / 模式变化标定、80%验证误差容差等仍未决定；用户已确认完整预填、约80%目标、学习个人睡眠及无历史常规作息，见Q-036。这些方向不再重新提问。辅助学习信息的存储 / 迁移在TIME-04按工程职责具体化，不新增主事实字段或进行中生命周期；不把未标定评分视为概率。预测不进入正式统计，不自动生成睡眠 / Unknown，不移动已有事实。

**Decision source:** 2026-10-07用户要求重设算法、学习过往睡眠，并明确默认常规作息；随后针对“三天未记，现在15:20新建活动”明确“连续5小时gap就应用这种方案”“30分钟应改为60分钟”。后续明确选择“采用推荐模型与参数”，批准睡眠首版；其他活动与效果标定仍未批准。

**Current status:** UNDECIDED

**Blocks implementation:** 仅阻塞其他活动估计与未决标定等范围；睡眠首版参数已批准，TIME-04可实施。已确认5小时 / 60分钟分支不需等个人睡眠模型定案。2026-10-07用户随后明确“请你着手开始实现”，已授权[TIME-03](../planning/LONG_GAP_ACTIVITY_INITIALIZATION.md)独立实施此分支及相关回归；不改写TIME-01历史结果，不将其余参数改为已决定。

## Q-038

**Question:** 全应用日期与时间修改是否分别直接打开选择器，并立即应用单字段？

**Why it matters:** TIME-01删除了生产中间层，但把时间和日期串联，活动日期不可单点、睡眠日期先开时钟；旧页面仍有双端总面板，未满足全应用独立字段要求。

**Related domain objects:** TimeBlock、SleepSession；表单编辑状态、账本日期、提醒偏好。

**Decision:** 日期字段直接对应日期选择器，时间字段直接对应现有时分选择器；开始 / 结束与日期 / 时间四个入口独立。各自确定即更新所选字段，不串联另一选择器，不需额外应用；取消与单纯打开不改变输入。初始位置为当前值，无值采用入口日期与合理时分；改日期保留时分 / 秒 / 毫秒，改时分保留日期及未选的秒 / 毫秒，另一端不变。不得为修正区间错误自动换日；正区间、跨事实原子校验及原精度合同继续执行。整个应用和保留的旧页面复用此路径，删除废弃双端面板及其状态 / 跳转；其他页面功能、布局、视觉不随意改变。覆盖Q-035 / Q-036的手动串联选择要求，不改变进入表单的自动初始化，不实施Q-037算法。

**Decision source:** 用户提供六项完整提示词，先要求核查汇报，随后明确“请你补足这份提示词要求但是你未实现的功能”。

**Current status:** DECIDED

**Blocks implementation:** 否。本轮仅TIME-02日期时间修改交互，不扩展预测算法或其他功能。
