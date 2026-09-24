# Domain Rules

## 依据、范围与阅读约定

本文件回答“什么状态与行为是合法的？”。规则来自 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)，并对照 [DOMAIN_MODEL](DOMAIN_MODEL.md)、[PRODUCT_PRINCIPLES](../product/PRODUCT_PRINCIPLES.md) 与 [OPEN_QUESTIONS](OPEN_QUESTIONS.md)。源文档中的当前产品 / 领域决定直接继承，历史实现讨论不进入 Greenfield 设计。

- `Rule` 是已有来源支持的 invariant、validation、constraint 或 business rule；`Source` 指源文档章节。
- `Examples` 仅说明本条规则，不声明示例中省略的全部字段已构成可保存对象。`Invalid examples` 对语义与交互规则指违反产品规则，不代表一定能用数据库校验发现。
- **Engineering Recommendation（不是产品要求）：** `Enforcement layer` 中的 Domain、Application、Database、Projection、Presentation 是未来执行职责建议，不确定目录、框架或实现方式。源文档明确的 UNIQUE / FK 会单独注明；其他数据库镜像约束是建议。
- 字段清单只引用 DOMAIN_MODEL，不在此复制；状态转换见 [DOMAIN_STATE_MACHINES](DOMAIN_STATE_MACHINES.md)，派生算法见 [DERIVED_MODELS](DERIVED_MODELS.md)，schema 见 [DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md)。未决问题不是默认允许，也不是默认禁止。
- 规则编号保持稳定，新增规则追加编号，不通过重排改变现有编号的含义。

## 规则索引

| 编号范围 | 内容 |
| --- | --- |
| MODEL-001–MODEL-002 | 正式对象字段存在性、可选性与文本规范 |
| TB-001–TB-009 | 时间区间、精度、已知性、标题与可选关联 |
| RH-001–RH-008 | 解释关系、三种节奏语义与可选细节 |
| SL-001–SL-005 | 独立睡眠、跨日、类型、输入优先级与区间范围 |
| GO-001–GO-002 | 时间归属与目标状态值域 |
| DR-001–DR-004 | 复盘唯一性、派生边界与明日第一步 |
| LEDGER-001–LEDGER-010 | Gap / Unknown、日投影、重叠、统计及回顾记录 |


## RULE MODEL-001

**Title:** 正式对象字段存在性与可选性

**Applies to:** 全部持久化领域对象、TomorrowFirstStep

**Rule:** 正式领域对象遵循 DOMAIN_MODEL 的 Required / optional 字段表；必需字段不能缺失，可选字段不应被统一升级为保存门槛。字段存在不等于已决定非空白、长度、默认值或时间戳生成策略。

**Reason:** 区分领域事实的结构与尚未定义的具体校验，避免复制全部字段清单。

**Examples:** TimeBlock.note 可空；SleepSession 保留起止时间；正式 DailyReview 包含 tomorrowFirstStep。

**Invalid examples:** 要求每条普通记录必填 note；把正式 DailyReview 的 tomorrowFirstStep 擅自改为可缺失。

**Enforcement layer:** Domain；Database 可镜像已确定的可空约束。文本规范见 MODEL-002；标识与元数据合同见 Q-018。

**Source:** §4–5、§11、§14、§21–22、§33


## RULE MODEL-002

**Title:** 已确定文本字段统一规范化

**Applies to:** Goal.name、TimeBlock.title / note、SleepSession.note、DailyReview.summary / reflection、TomorrowFirstStep.text、RhythmAnnotation.continuationHint

**Rule:** 保存前清理首尾空白，保留内部空格、换行和段落格式。必填文本清理后不得为空；可选文本清理后为空则保存为 null。短文本最多 200 个字符，长文本最多 2,000 个字符；长度由 Domain / Application 校验，数据库字段使用普通 TEXT。Q-007 尚未确定的原因与恢复值域不由本条定型。

**Reason:** 统一空白与空值语义，避免 UI、领域和数据库产生不同文本结果，同时限制异常大输入。

**Examples:** `"  目标一  "` 保存为 `"目标一"`；可选 note 只有空白时保存为 null；长文本内部换行保留。

**Invalid examples:** 必填文本清理后为空；以数据库 TEXT 类型替代长度校验；逐字段擅自采用不同的空串 / null 规则。

**Enforcement layer:** Domain / Application；Database 保持 TEXT，不镜像具体长度上限。

**Source:** Q-015


## RULE TB-001

**Title:** 时间区间必须为正

**Applies to:** TimeBlock

**Rule:** 必须满足 startedAt < endedAt；区间按半开区间 `[startedAt, endedAt)` 解释，近似边界也不豁免正区间约束。

**Reason:** 源文档对 time_blocks 明确给出严格不等式。

**Examples:** 14:00–15:00，无论起止精度是否相同。

**Invalid examples:** 14:00–14:00；同一日期 15:00–14:00。

**Enforcement layer:** Domain；Database 可用约束兜底。

**Source:** §5–6、§33


## RULE TB-002

**Title:** 起止精度独立且承认近似

**Applies to:** TimeBlock.startPrecision / endPrecision

**Rule:** 两个字段各自取 exact 或 approximate，分别表达对应边界的精度；仍保存具体起止时间用于排序和计算，不能把一个精度强制复制到另一个。

**Reason:** 用户对开始与结束可能有不同把握。

**Examples:** startedAt=15:00、startPrecision=approximate；endedAt=16:20、endPrecision=exact。

**Invalid examples:** 仅存一个精度并强制两个边界一致；将 approximate 替换成 unknown。

**Enforcement layer:** Domain；Database 可限制枚举值域；Presentation 表达近似。

**Source:** §5–6


## RULE TB-003

**Title:** 目标时间不要求 exact

**Applies to:** TimeBlock 与可选 RhythmAnnotation

**Rule:** 目标相关时间以及明确 progress 都允许 approximate；高价值时间通过交互优先确认，不以必须 exact 阻止保存。

**Reason:** 次日回忆的近似目标时间仍是合法、有价值的数据。

**Examples:** 约 14:30–16:00 写毕业设计，用户确认属于 progress。

**Invalid examples:** 以“推进记录必须精确”为由拒绝该记录。

**Enforcement layer:** Domain 不加 exact 门槛；Application / Presentation 支撑时间确认。

**Source:** §6、§26


## RULE TB-004

**Title:** 已知性与精度分别表达

**Applies to:** TimeBlock.knowledgeState

**Rule:** knowledgeState 仅为 known 或 unknown。known 表示知道大概发生了什么；unknown 表示知道时间过去了但无法恢复内容。状态切换的字段处理见 Q-003，组合限制见 Q-004。

**Reason:** 语义清晰度不等于边界精度。

**Examples:** 近似时间的“外出办事”是 known；明确 16:00–17:20 但想不起来是 unknown。

**Invalid examples:** 用 approximate 推导 unknown；把 gap 加入 knowledgeState 枚举。

**Enforcement layer:** Domain；Database 可限制枚举值域。

**Source:** §2、§7–8


## RULE TB-005

**Title:** known 必须有非空标题

**Applies to:** TimeBlock.title

**Rule:** knowledgeState=known 时 title 必须存在且在清理首尾空白后仍非空；适用的长度和规范化规则见 MODEL-002。

**Reason:** known 需要描述大概做了什么。

**Examples:** known，title="吃午饭"。

**Invalid examples:** known，title=null；known，title=""。

**Enforcement layer:** Domain；Database 可镜像确定的非空条件；Presentation 提示用户补活动。

**Source:** §33


## RULE TB-006

**Title:** unknown 允许无标题

**Applies to:** TimeBlock.title

**Rule:** knowledgeState=unknown 时 title 可为 null；不得要求编造活动，也不得把“可为空”改成“只能为空”或必须保存固定文案。可选文本的空白与长度规则见 MODEL-002；转换清理仍见 Q-003。

**Reason:** unknown 本身已经表达合法事实。

**Examples:** unknown，title=null；源文档以“想不起来”说明其含义。

**Invalid examples:** 因 title=null 拒绝 unknown；强迫选择一项活动来替代未知。

**Enforcement layer:** Domain；Database 允许条件可空；Presentation 的未知标签不成为必填存储值。

**Source:** §7–8、§33


## RULE TB-007

**Title:** 目标关联可选

**Applies to:** TimeBlock.goalId

**Rule:** TimeBlock 可以不关联 Goal；有 goalId 时表达一个目标归属，不是活动类别。解释与已知性对关联的具体组合要求未定，不由本条扩展，见 Q-004。

**Reason:** 普通生活事实也属于账本。

**Examples:** 午饭不选 Goal；阅读论文归属毕业设计。

**Invalid examples:** 所有时间块必须先选择 Goal；用一组并行 Goal 分摊同一块替代当前单个 goalId。

**Enforcement layer:** Domain；Application 处理关联；归档引用策略见 Q-006。

**Source:** §5、§11–12、§36


## RULE TB-008

**Title:** 节奏解释可选且独立于事实

**Applies to:** TimeBlock、RhythmAnnotation

**Rule:** TimeBlock 可以没有 RhythmAnnotation；progress / stuck / recovery 不是 TimeBlock 类型，缺少解释不使事实无效。

**Reason:** “做了什么”与“对目标意味着什么”是不同层次。

**Examples:** 目标相关的搜资料记录没有节奏标记。

**Invalid examples:** 为保存普通午饭强制选择一种节奏；将 TimeBlock 分成三个节奏子类型。

**Enforcement layer:** Domain；Application / Presentation 不强制标记。

**Source:** §12–13、§18


## RULE TB-009

**Title:** 分类不得成为前置条件

**Applies to:** TimeBlock、记录流程

**Rule:** 核心记录不依赖 Category，不能要求分类后才记录；首版保留可空 categoryId 作为扩展字段，但不建立 Category 实体、分类管理或分类入口。

**Reason:** 活动文字已足以还原普通时间。

**Examples:** 只写“去学校”即可描述活动。

**Invalid examples:** 先创建复杂分类体系才能保存记录。

**Enforcement layer:** Domain；Application / Presentation。

**Source:** §10–11


## RULE RH-001

**Title:** 解释必须附属于事实且最多一份

**Applies to:** RhythmAnnotation.timeBlockId

**Rule:** 每条 RhythmAnnotation 必须引用一个 TimeBlock；每个 TimeBlock 最多一个有效 annotation。源文档明确 time_block_id UNIQUE FK，不因此引入多版本或软删除模型；删除处理见 Q-013。

**Reason:** 同一时间事实只承载一套节奏解释。

**Examples:** 一条 TimeBlock 附一条 progress annotation。

**Invalid examples:** 孤立 annotation；同一 TimeBlock 同时附加有效 progress 和 stuck。

**Enforcement layer:** Database：源文档明确 UNIQUE FK；Domain / Application 维护关系。

**Source:** §14、§33、§36


## RULE RH-002

**Title:** 节奏枚举只含三种解释

**Applies to:** RhythmAnnotation.state

**Rule:** state 仅为 progress、stuck、recovery；不标记通过 annotation 不存在表达，不加入 neutral、useless 或 productive 布尔判断。

**Reason:** 不解释不等于第四种节奏，事实不替用户作价值判断。

**Examples:** 普通看电影不附 annotation。

**Invalid examples:** 保存 state=neutral 或 useless；自动给每条记录 productive=true/false。

**Enforcement layer:** Domain；Database 可限制值域。

**Source:** §13、§19


## RULE RH-003

**Title:** progress 由用户确认目标推进

**Applies to:** RhythmAnnotation.state=progress

**Rule:** 表示该时间段主要产生了用户能够确认的目标推进；不能只凭活动看起来像工作自动判定。显式 Goal 关联要求见 Q-004。

**Reason:** 同样是查论文，是否推进取决于用户确认。

**Examples:** 用户认为查到的论文解决了目标中的问题，标记 progress。

**Invalid examples:** 系统看到标题“查论文”便自动断定 progress。

**Enforcement layer:** Domain 语义；Application / Presentation 收集用户解释，不能算法验证其真实性。

**Source:** §13


## RULE RH-004

**Title:** stuck 表示尝试推进中的阻力

**Applies to:** RhythmAnnotation.state=stuck

**Rule:** 表示用户尝试推进目标相关事情，但主要时间消耗于阻力、停滞、反复尝试或无法进入有效推进；不等于失败评分。

**Reason:** 区分花在目标附近的时间与明确推进。

**Examples:** 一直尝试数据库设计但未能进入有效推进，由用户标记 stuck。

**Invalid examples:** 仅因没有 annotation 就推断 stuck；把 stuck 当“无用功”枚举。

**Enforcement layer:** Domain 语义；Application / Presentation。

**Source:** §13、§18–19


## RULE RH-005

**Title:** recovery 不是普通生活的默认分类

**Applies to:** RhythmAnnotation.state=recovery

**Rule:** 表示该行为主要让用户从无法继续的状态重新获得继续行动的可能；普通午饭等生活行为默认不附恢复解释。睡眠适用 SL-001。

**Reason:** 正常生活不自动等于恢复。

**Examples:** 从无法继续的状态出去散步，用户认为有恢复作用。

**Invalid examples:** 见到“午饭”或“娱乐”就自动标 recovery。

**Enforcement layer:** Domain 语义；Application / Presentation。

**Source:** §13、§17


## RULE RH-006

**Title:** 卡住原因可全部省略

**Applies to:** RhythmAnnotation.stuckReasonCode / stuckReasonText

**Rule:** 标记 stuck 本身可以成立；两个原因字段均可为空，不要求至少填一项。正式值域和字段组合细则见 Q-007、Q-005。

**Reason:** 卡住时应保持最低记录成本。

**Examples:** state=stuck，两个原因字段均为 null。

**Invalid examples:** 要求选择原因或写解释才允许保存 stuck。

**Enforcement layer:** Domain；Database 允许可空；Presentation 不设必填。

**Source:** §14–15、§33


## RULE RH-007

**Title:** 恢复细节可全部省略

**Applies to:** RhythmAnnotation.recoveryMethod / recoveryQuality

**Rule:** 标记 recovery 本身可以成立；方式与质量都可为空。候选恢复方式不是擅自固定枚举的依据，值域见 Q-007。

**Reason:** 可鼓励细化，但不能挡住记录。

**Examples:** state=recovery，方式和质量均为 null。

**Invalid examples:** 必须先选择恢复方式并评价质量才保存。

**Enforcement layer:** Domain；Database 允许可空；Presentation 不设必填。

**Source:** §14、§16–17、§33


## RULE RH-008

**Title:** 接续点可选且不等于明日第一步

**Applies to:** RhythmAnnotation.continuationHint

**Rule:** continuationHint 可为空；progress / stuck 可附接续点，回答回到这件事从哪里接上，不代表指定明天先做什么。recovery 能否填写与状态切换清理见 Q-005。

**Reason:** 避免把工作上下文与每日行动意向混合。

**Examples:** “下次先把 User 表的字段画出来”，或不填。

**Invalid examples:** 要求所有 annotation 必填接续点；自动把接续点等同为复盘明天第一步。

**Enforcement layer:** Domain 语义与可选性；Application / Presentation 区分两种输入。

**Source:** §14、§20、§22


## RULE SL-001

**Title:** 睡眠是独立事实

**Applies to:** SleepSession、RhythmAnnotation

**Rule:** 睡眠独立记录于 SleepSession，不塞入 RecoveryMethod；当前不把午睡与恢复解释重新绑定。核心睡眠数据是入睡与醒来边界，不要求睡眠质量。

**Reason:** 睡眠是身体背景，不是普通恢复操作。

**Examples:** 夜间睡眠保存为 SleepSession；小睡用 nap。

**Invalid examples:** 仅保存 recoveryMethod=sleep 来代表夜间睡眠事实；睡眠质量必填。

**Enforcement layer:** Domain；Application / Presentation。

**Source:** §4、§17


## RULE SL-002

**Title:** 跨日睡眠保存完整事实

**Applies to:** SleepSession

**Rule:** 允许跨自然日，不因午夜强制拆成多个事实；在各日时间线按查询窗口切片。

**Reason:** 自然日是展示与统计边界。

**Examples:** 9 月 21 日 23:50 至 22 日 07:40 保存为一个 SleepSession。

**Invalid examples:** 要求用户把上述睡眠在 00:00 拆成两条才可保存。

**Enforcement layer:** Domain；Application / Projection；Database 保存原始边界。

**Source:** §4、§23–24


## RULE SL-003

**Title:** 睡眠类型与精度独立表达

**Applies to:** SleepSession.type、startPrecision / endPrecision

**Rule:** type 仅为 mainSleep 或 nap；起止分别保留 exact / approximate，不用睡眠类型推导时间精度，不增加类型时长阈值。SleepSession 必须为正区间，允许未来区间，不设置固定历史回溯上限。

**Reason:** 睡眠类型、边界精度是不同维度。

**Examples:** mainSleep，开始 approximate、结束 exact。

**Invalid examples:** 把 sleepQuality 当 SleepType；强制所有睡眠边界 exact。

**Enforcement layer:** Domain；Database 可限制值域和正区间。

**Source:** §4–6、Q-016


## RULE SL-005

**Title:** 时间事实允许补录且不设固定时长边界

**Applies to:** TimeBlock、SleepSession

**Rule:** 两类时间事实均必须满足 startedAt < endedAt；不设置固定最短或最长持续时长，允许未来正区间，也不设置历史补录上限。

**Reason:** 保留回顾补记和用户表达的自由，不以未定义的时长或当前时间阈值阻止合法事实。

**Examples:** 补录很久以前的活动；保存尚未发生的计划时间段；跨日睡眠仍是正区间。

**Invalid examples:** 零时长或反向区间；仅因时长较长或发生在未来而拒绝保存。

**Enforcement layer:** Domain；Application / Presentation 可提供输入提示，不将提示升级为保存禁令。

**Source:** Q-016、TB-001、SL-002


## RULE SL-004

**Title:** 睡眠优先确认且已记录不重复打扰

**Applies to:** 每日首次打开的记录流程

**Rule:** 优先确认昨晚几点睡、今天几点醒，不以先设置 Goal 为前提；若已记录则不重复打扰。“昨晚”和“已记录”的识别口径见 Q-010。

**Reason:** 先保留重要身体背景。

**Examples:** 已录睡眠后直接进入账本。

**Invalid examples:** 每次打开都要求重新填睡眠；必须先建 Goal 才能记录睡眠。

**Enforcement layer:** Application / Presentation；不是数据库必填整日睡眠的约束。

**Source:** §29


## RULE GO-001

**Title:** Goal 仅承载时间归属

**Applies to:** Goal

**Rule:** Goal 表达阶段性目标的时间归属，与 Category 不同；不引入截止日期、百分比、里程碑、任务树、优先级等项目管理字段。

**Reason:** 目标时间理解无需项目管理系统。

**Examples:** 毕业设计作为阅读论文的 Goal。

**Invalid examples:** 把“娱乐”分类树当目标管理；为 Goal 建立任务层级与完成进度。

**Enforcement layer:** Domain 结构；Application / Presentation 范围约束。

**Source:** §11、§38


## RULE GO-002

**Title:** 状态值限定但生命周期未补全

**Applies to:** Goal.status / archivedAt

**Rule:** status 仅为 active、archived。Goal 只能以 active 创建；active 与 archived 可双向切换。归档写入当前 UTC archivedAt，恢复时清除；相同状态重复请求幂等且不更新 updatedAt。已有引用保留，archived Goal 不可用于新增关联；未被引用的 Goal 可物理删除，有引用的删除操作归档并隐藏，不新增 deleted 状态。改名实时作用于历史记录。

**Reason:** 值域确定不代表完整转换合同已确定。

**Examples:** 使用 active 或 archived 表达目标状态。

**Invalid examples:** 加入 completed、paused、deleted 状态；级联删除有引用的时间事实或复盘；让 archived Goal 进入新的时间归属。

**Enforcement layer:** Domain / Application；Database 可限制值域，跨表删除与隐藏行为按事务合同落实。

**Source:** §11


## RULE DR-001

**Title:** 每天最多一份正式复盘

**Applies to:** DailyReview.date

**Rule:** 复盘绑定自然日期，review_date 唯一；不需要持久化 Day 实体。不由唯一性推导必须每天填写、禁止补写或限制更新。保存时的日期按当前设备时区解释；已保存的 review_date 作为 CivilDate 保持不被设备时区变化自动改写。

**Reason:** 源文档明确 review_date UNIQUE。

**Examples:** 某自然日期有一条正式 DailyReview。

**Invalid examples:** 同一复盘日期保存两条正式 DailyReview。

**Enforcement layer:** Database：源文档明确 UNIQUE；Application 处理重复请求，具体交互不在本条决定。

**Source:** §21、§23、§33


## RULE DR-002

**Title:** 复盘不保存派生分钟数

**Applies to:** DailyReview

**Rule:** progressMinutes、stuckMinutes、recoveryMinutes 由时间事实及解释重新计算，不持久化为 DailyReview 字段或统计 Source of Truth。

**Reason:** 每日解释与时间计算拥有不同职责。

**Examples:** 复盘保存反思，展示的推进时长从事实重新计算。

**Invalid examples:** 编辑或读取 DailyReview.progressMinutes 作为权威统计。

**Enforcement layer:** Domain 结构；Data 不存上述统计字段；Projection 计算。

**Source:** §21、§30、§33


## RULE DR-003

**Title:** 解释文字可选，结构化复盘不是门槛

**Applies to:** DailyReview.summary / reflection

**Rule:** summary、reflection 均可为空；keyProgress、mainStuckPoint、recoveryObservation 不是第一版必需字段。tomorrowFirstStep 的存在性适用 MODEL-001。

**Reason:** 降低复盘成本，不把未来结构化选项当当前要求。

**Examples:** 留下明天第一步，summary 与 reflection 均为 null。

**Invalid examples:** 必须填写全部结构化复盘字段才保存。

**Enforcement layer:** Domain；Database 允许可空；Presentation 不设额外必填。

**Source:** §21、§33


## RULE DR-004

**Title:** 明天第一步是单一行动意向

**Applies to:** DailyReview.tomorrowFirstStep、TomorrowFirstStep

**Rule:** 它回答明天开始先做什么，包含 text 与 intendedDate，goalId 可选；不是每个 Goal 各一份计划，也不是任务生命周期。intendedDate 固定为 DailyReview.date 的下一自然日，不单独持久化；文本细则见 MODEL-002。

**Reason:** 使下一次启动更容易，而非多项目计划管理。

**Examples:** “打开数据库设计图，先补 User 和 TimeBlock 两张表”，可不关联 Goal。

**Invalid examples:** 要求为所有 Goal 填写明日计划；用 continuationHint 自动替代此对象。

**Enforcement layer:** Domain；Application / Presentation；由复盘日期派生，不建立单独存储列。

**Source:** §20–22、§33


## RULE LEDGER-001

**Title:** Gap 是未处理的派生空隙

**Applies to:** UnresolvedSpan、DayLedgerView

**Rule:** Gap 从时间轴未覆盖部分派生为 UnresolvedSpan，不作为数据库领域对象持久化；没记录不意味着用户已经确认未知。窗口边缘与当前日截止见 Q-009。

**Reason:** 系统发现空白与用户交代事实不同。

**Examples:** 前条 14:00 结束、后条 16:00 开始，中间未覆盖区间派生为 Gap。

**Invalid examples:** 创建 gaps 事实表；扫描时间轴后自动写入 unknown。

**Enforcement layer:** Projection 计算；Data 不持久化 Gap；Application 等待用户补账确认。

**Source:** §8、§23–24、§28


## RULE LEDGER-002

**Title:** Unknown 是已交代的持久化事实

**Applies to:** TimeBlock.knowledgeState=unknown、账本汇总

**Rule:** 用户确认想不起来后保存 unknown TimeBlock，计入已交代时间；unknownDuration 是已交代时间中的未知部分，不能与 unresolvedDuration 混同或作为额外覆盖重复相加。

**Reason:** 内容未知不等于尚未处理。

**Examples:** 已交代 2 小时，其中 30 分钟未知，已交代仍为 2 小时。

**Invalid examples:** 把未知 30 分钟再加为 2.5 小时；把未知仍显示成尚未记录。

**Enforcement layer:** Domain；Data 保存事实；Projection / Presentation 区分两种状态。

**Source:** §7–9、§30


## RULE LEDGER-003

**Title:** 自然日只作查询与投影边界

**Applies to:** TimeBlock、SleepSession、DayLedgerView

**Rule:** 按当前设备时区确定自然日窗口，查询相交的 TimeBlock 与 SleepSession 并切片生成 DayLedgerView；DayLedgerView 不持久化，也不创建数据库 Day 实体来强迫事实按日拆分。时间事实使用半开区间，端点细则见 Q-017。

**Reason:** 保留事实完整性，同时支持日账本。

**Examples:** 同一跨日事实参与两天各自窗口的展示。

**Invalid examples:** 为满足 Day 外键要求用户午夜拆事实；把 DayLedgerView 当权威数据库记录。

**Enforcement layer:** Projection；Data 保留原事实，不保存派生 Day。

**Source:** §4、§23–24


## RULE LEDGER-004

**Title:** 主时间轴只容纳一个主要事实

**Applies to:** 全部 TimeBlock 与 SleepSession

**Rule:** 同一段时间最多一条主要 TimeBlock / SleepSession；限制涵盖 TimeBlock 之间、SleepSession 之间及两类事实之间。近似不授权并行主事实，次要同时活动可写 note。冲突写入必须原子拒绝并提示冲突记录，由用户手动调整；不自动截断、拆分、覆盖或移动已有事实。端点判定见 Q-017。

**Reason:** 本产品记录一段时间的主要事实，不实现并行多任务时间轴。

**Examples:** 午饭为主要事实，边看视频写在 note。

**Invalid examples:** 14:00–15:00 的 TimeBlock 与 14:30–15:30 的 SleepSession 同时占主时间轴；两条 TimeBlock 在该区间并行分摊。

**Enforcement layer:** Domain 定义约束；Application 协调跨记录冲突检查；原子写入与存储兜底方案见 [DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md)。

**Source:** §32


## RULE LEDGER-005

**Title:** 覆盖、语义、精度不混成完成分数

**Applies to:** 账本质量表达

**Rule:** 分别表达有没有交代、是否知道内容、边界是否精确；完整不要求 24 小时每分钟精确分类。

**Reason:** 近似且已知、精确但未知都可能是诚实记录。

**Examples:** 14:00–16:00 大概外出办事，表达为已交代、known、approximate。

**Invalid examples:** 因 approximate 把该时段计作未记录；以三者合成今日成绩。

**Enforcement layer:** Domain 概念；Projection / Presentation。

**Source:** §2、§9、§25


## RULE LEDGER-006

**Title:** 统计从事实派生且保留不同口径

**Applies to:** 时间统计与目标汇总

**Rule:** 所有统计从时间事实及其解释派生；目标相关时间不等于明确推进或卡住时间，允许关联 Goal 而未解释的时间；恢复单独作为当天背景描述。计算细节见 [DERIVED_MODELS](DERIVED_MODELS.md)。

**Reason:** 没有解释的目标时间不能被擅自判为推进、卡住或无用。

**Examples:** 目标时间包含明确推进、明确卡住和未标记记录，分别展示。

**Invalid examples:** 以目标相关总时长代替 progressDuration；将未标记部分自动记 stuck。

**Enforcement layer:** Projection；Presentation 保持口径可辨；Data 不另设聚合事实源。

**Source:** §18、§21、§24、§30


## RULE LEDGER-007

**Title:** 聚合必须诚实携带近似信息

**Applies to:** hasApproximation、时间汇总

**Rule:** 时间聚合应能携带 hasApproximation，参与计算的近似边界不能被呈现为绝对精确；相应时长用“约”等方式表达。跨日切片传播细则见 Q-014；内部按毫秒计算，展示时最终统一舍入到分钟。

**Reason:** 具体时间值不等于绝对精确的认知。

**Examples:** 近似 14:30–16:00 形成“约 1 小时 30 分”。

**Invalid examples:** 移除精度信息，并将估计时长显示为准确测量结果。

**Enforcement layer:** Projection 传播标志；Presentation 表达近似。

**Source:** §5–6、§30


## RULE LEDGER-008

**Title:** 描述事实，不评价用户

**Applies to:** 统计、复盘辅助与领域枚举

**Rule:** 不输出生产力、效率或完整度评分，不建 useless / productive 判断；习惯连续天数、失败天数等不进入当前核心。用户可在复盘中形成自己的理解，系统或 AI 不替用户自动评价是否有效。

**Reason:** 数据状态不是用户成绩。

**Examples:** “还有约 1h20m 没有记录”；用户自己反思查资料前先写问题。

**Invalid examples:** “今日完成度 83%”“推进效率 70.7%”；自动判用户今天无效。

**Enforcement layer:** Domain 范围；Application / Presentation 输出约束。

**Source:** §9、§18–19、§25、§30、§38


## RULE LEDGER-009

**Title:** 描述性关联不得冒充因果

**Applies to:** 睡眠与节奏分析，包括未来 AI 复盘

**Rule:** 可描述睡眠与卡住等现象共同出现，不能断言睡眠导致效率变化；此规则不授权本阶段增加分析功能。

**Reason:** 产品没有支持因果判断的实验设计。

**Examples:** “最近这些睡眠较少的日子常同时记录困类型的卡住”。

**Invalid examples:** “睡眠不足导致你的效率下降 30%”。

**Enforcement layer:** Application / Presentation 的分析输出约束。

**Source:** §31、§38


## RULE LEDGER-010

**Title:** 回顾补账以活动为主要输入

**Applies to:** 记录与补账流程

**Rule:** 以事后补记为主，时间区间由系统提出可修改的假设，活动是主要输入；从 Gap 补账可预填其边界，想不起来则由用户确认未知。草稿持久化见 Q-012；非 Gap 入口的时间建议及初始精度见 Q-023。

**Reason:** 降低还原一天的输入成本。

**Examples:** 点击 14:30–16:05 的空白，预填时间后描述活动或确认未知。

**Invalid examples:** 必须先启动计时器才能留记录；系统猜测不可修改；草稿未经确认即当成事实。

**Enforcement layer:** Application / Presentation；领域保存仍需满足相应事实规则。

**Source:** §1、§27–28


## 未决规则边界

以下仅登记仍影响规则的未决依赖，不替 OPEN_QUESTIONS 重复定义候选答案。

| 问题 | 受影响规则或后续工作 |
| --- | --- |
| Q-003–Q-005 | TB-004–TB-008、RH-003–RH-008 的组合及转换字段处理 |
| Q-007 | RH-006–RH-007 的可选值域 |
| Q-009–Q-010 | SL-004、LEDGER-001 / 003 / 006 的当前日窗口与睡眠口径 |
| Q-012–Q-013 | 草稿保存、删除 / 更正及关联处理 |
| Q-014 | LEDGER-007 的切片精度传播 |
| Q-019 | Goal 名称是否唯一及重复判定 |
| Q-020–Q-021 | LEDGER-006 的摘要参与集与缺失数据表达 |
| Q-023 | LEDGER-010 的非 Gap 时间建议与初始精度 |

## 本阶段一致性检查

已核对事实 / 解释分层、睡眠独立性、Unknown 与 Gap、自然日投影、近似合法性和统计非评价性。没有添加新的 TimeBlock 类型、状态机、任务管理或并行时间轴。

源文档 §18 的示例总量存在算术不一致：五段分别为 70、40、70、50、70 分钟，共 300 分钟（5 小时），正文却写约 4h30m；明确推进 210 分钟与卡住 40 分钟的子项计算一致。本文件不复制错误总量、不修改 Source of Truth，也不将这个可算术核对的问题转成产品未决问题。

`TomorrowFirstStep.intendedDate` 已确定由 DailyReview.date 的下一自然日派生，不单独持久化。后续实现应保持这一合同。
