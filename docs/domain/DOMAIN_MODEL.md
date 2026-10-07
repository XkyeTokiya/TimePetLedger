# Domain Model

## 职责与依据

本文件回答“系统里有什么？”，依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) 的对象结构与语义。产品原则见 [PRODUCT_PRINCIPLES](../product/PRODUCT_PRINCIPLES.md)。本文仅保留理解对象所必需的约束，详细校验引用 [DOMAIN_RULES](DOMAIN_RULES.md)，也不决定数据库类型、索引或实现方式。

字段表中“必需”继承源文档中未带 `?` 的声明；“可选”继承 `?` / nullable。必需不额外代表文本裁剪、长度、默认值等规则已确定。疑义见 [OPEN_QUESTIONS](OPEN_QUESTIONS.md)。

## 模型分类

| 分类 | 成员 | Persistence status |
| --- | --- | --- |
| Persisted Domain Entities | Goal、TimeBlock、RhythmAnnotation、SleepSession、DailyReview | YES：领域事实或用户解释 |
| 领域值对象 | TomorrowFirstStep | 随 DailyReview 保存其内容；不是已确定的独立实体 / 表，intendedDate 按复盘日期派生 |
| 领域枚举 | TimePrecision、BlockKnowledgeState、RhythmState、SleepType；Goal.status 的两个值 | 作为所属实体字段保存，无独立生命周期 |
| Derived Models | DayLedgerView、UnresolvedSpan、时间切片与各项时长 / 汇总 | NO：由事实重新计算 |
| UI Models | 会话内未完成输入快照、时间区间建议、时间编辑状态等交互数据 | 只存活于当前app / 网页会话，不属于正式领域事实（Q-012） |

Time is the foundational fact。TimeBlock = what happened；RhythmAnnotation = 部分时间的目标节奏解释；SleepSession = independent sleep fact；DailyReview = interpretation and next action。

## Persisted Domain Entities

### Goal（§11）

**Purpose:** 时间归属维度，回答某段时间与哪个阶段性目标有关。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| id | 目标标识 | 必需 |
| name | 目标名称 | 必需 |
| status | active / archived | 必需 |
| createdAt | 创建时间 | 必需 |
| updatedAt | 更新时间 | 必需 |
| archivedAt | 归档时间 | 可选 |

**Relationships:** TimeBlock.goalId 与 TomorrowFirstStep.goalId 可引用 Goal；目标没有必须拥有记录或明日计划的要求。Goal 只能以 active 创建；archived Goal 保留历史引用但不用于新增关联。未被引用的 Goal 可物理删除；有引用的删除操作归档并隐藏，保留引用且可恢复、改名。

**Persistence status:** YES。状态、归档时间、引用、删除与改名行为已按 Q-006 确定。

**What this object must NOT represent:** Category、任务管理器或项目管理器；不包含截止日期、完成百分比、里程碑、任务树、优先级。

**名称与身份（Q-019）：** active / archived 均允许同名，创建与改名不做名称唯一校验；不同 id 的记录与统计独立，不自动合并，名称仍遵守 Q-015。

### TimeBlock（§5–12、§33）

**Purpose:** 一段时间主要发生了什么，包括无法回忆内容的合法事实。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| id | 时间事实标识 | 必需 |
| startedAt / endedAt | 起止边界的具体时间，用于排序与计算；可为近似值 | 各自必需 |
| startPrecision / endPrecision | 两个边界各自的 TimePrecision | 各自必需 |
| knowledgeState | BlockKnowledgeState，说明是否知道活动内容 | 必需 |
| title | 活动描述；known 不能空，unknown 可为空，不等于必须为空 | 条件必需 |
| goalId | 可选的目标归属 | 可选 |
| categoryId | 源文档保留的可选扩展点；核心不依赖，首版不定义 Category 实体 | 可选；首版保留但不提供分类能力，暂不建立外键 |
| note | 补充说明，也可描述次要并行活动 | 可选 |
| createdAt / updatedAt | 创建 / 更新时间 | 各自必需 |

**Relationships:** 可关联一个 Goal；可附加零或一个有效 RhythmAnnotation；与 SleepSession 一起提供自然日投影的输入。

**Persistence status:** YES，包括 knowledgeState = unknown 的记录。Gap 不保存为 TimeBlock；只有用户确认未知后才产生 Unknown 事实。

**What this object must NOT represent:** progress / stuck / recovery 类型、计时器运行状态、未处理 Gap、精确时间的保证或并行多任务分摊。起止必须构成正区间；详细规则见 [DOMAIN_RULES](DOMAIN_RULES.md)。known / unknown 字段转换见 Q-003；已知性、Goal 与解释之间不设额外组合限制。

### RhythmAnnotation（§12–20）

**Purpose:** 对一段时间在目标推进过程中意味着什么做可选解释。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| id | 解释标识 | 必需 |
| timeBlockId | 所解释的 TimeBlock | 必需 |
| state | RhythmState | 必需 |
| stuckReasonCode | 卡住原因单选代码；正式值域见下表（Q-007） | 可选 |
| stuckReasonText | 可选文字补充；可独立填写，“其他”不强制补充 | 可选 |
| recoveryMethod | 恢复方式单选代码；正式值域见下表（Q-007） | 可选 |
| recoveryQuality | 用户主观恢复效果单选代码；不换算分数（Q-007） | 可选 |
| continuationHint | 下次回到这件事从哪里接上；可附于 progress / stuck / recovery（Q-005） | 可选 |
| createdAt / updatedAt | 创建 / 更新时间 | 各自必需 |

**Relationships:** 每条解释属于一个 TimeBlock，一个 TimeBlock 最多一个有效解释。Goal 归属位于 TimeBlock；解释自身没有独立 goalId。任何 RhythmState 都不强制要求 TimeBlock 关联 Goal；已有解释与目标归属可按已知性自由组合，但新增关联仍须遵守 Q-006。

**可选细节正式值域（Q-007）：** 以下代码是已确认选项的稳定内部命名；均可为空，不增加必填门槛。

| 字段 | 代码 → 展示含义 |
| --- | --- |
| stuckReasonCode | taskTooLarge → 任务太大；unclearNextStep → 不知道下一步；sleepy → 困；brainFog → 脑雾；anxious → 焦虑；interrupted → 被打断；unsure → 说不清；other → 其他 |
| recoveryMethod | walk → 散步；meal → 吃饭；shower → 洗澡；empty → 放空；entertainment → 娱乐；switchTask → 切换任务；breakDownTask → 拆小任务；askForHelp → 寻求帮助；other → 其他 |
| recoveryQuality | notRecovered → 没缓过来；partlyRecovered → 缓过来一些；readyToContinue → 可以继续了 |

stuckReasonText 可以独立于代码填写，也可补充任一选项；选择 other 不强制填写文字。recoveryQuality 是主观描述，不映射为分数；睡眠不进入 recoveryMethod。

**Persistence status:** YES，作为用户解释独立于时间事实保存。无 annotation 就是不需要解释，无 neutral 状态。三种节奏可任意互换；切换保留附属字段，仅当前状态适用的细节参与展示和使用，接续点适用于全部状态（Q-005）；附属字段值域见 Q-007。

**What this object must NOT represent:** TimeBlock 类型、独立时间区间、自动效率评价、SleepSession 或明天第一步。标记 stuck / recovery 本身即可成立，不要求原因或质量。

### SleepSession（§4、§17、§29）

**Purpose:** 独立睡眠事实，核心是几点睡、几点醒。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| id | 睡眠事实标识 | 必需 |
| startedAt / endedAt | 睡眠起止边界，可跨自然日 | 各自必需 |
| startPrecision / endPrecision | 起止各自的 TimePrecision | 各自必需 |
| type | SleepType；存储示例名为 sleep_type，表达同一属性 | 必需 |
| note | 睡眠补充说明 | 可选 |
| createdAt / updatedAt | 创建 / 更新时间 | 各自必需 |

**Relationships:** 与 TimeBlock 共同构成账本投影输入；不从属于 TimeBlock、Goal 或 RhythmAnnotation。当前不建立午睡与恢复的额外关联。

**Persistence status:** YES。跨日保存一个完整事实，自然日只切片查询和展示。

**What this object must NOT represent:** RecoveryMethod、恢复质量评价或由日界线强制拆分的事实。睡眠质量不属于当前对象字段。

### DailyReview（§21–22、§33）

**Purpose:** 对一天的解释与下一次行动。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| id | 复盘标识 | 必需 |
| date | 所复盘的自然日期；源存储示例 review_date 唯一 | 必需 |
| summary | 当天概述 | 可选 |
| reflection | 用户反思 | 可选 |
| tomorrowFirstStep | TomorrowFirstStep，明天开始先做什么 | 源结构声明为必需；未提出可空的已保存复盘 |
| createdAt / updatedAt | 创建 / 更新时间 | 各自必需 |

**Relationships:** 按 date 解读当天事实及其派生信息，不持有持久化 Day 实体；包含一个 TomorrowFirstStep，其中可引用 Goal。

**Persistence status:** YES，保存解释和行动内容。progressMinutes / stuckMinutes / recoveryMinutes 不保存为复盘事实源。会话内未完成复盘输入不等于已定义的持久化 DailyReview（Q-012）。

**What this object must NOT represent:** 统计快照的事实源、所有 Goal 的明日计划器、任务列表。keyProgress / mainStuckPoint / recoveryObservation 只是后续可考虑的结构，不属于第一版必需字段。

## 领域值对象

### TomorrowFirstStep（§22、§33）

**Purpose:** 回答“明天开始时，我首先要做什么？”。

| Fields | Field semantics | Required / optional |
| --- | --- | --- |
| text | 第一步的行动文字 | 必需 |
| intendedDate | 该行动意向对应的日期 | 必需；固定为 DailyReview.date 的下一自然日，由复盘日期派生 |
| goalId | 这一步可关联的目标 | 可选 |

**Relationships:** 属于 DailyReview，可引用一个 Goal；与 RhythmAnnotation.continuationHint 语义独立。

**Persistence status:** 内容随 DailyReview 保存；源文档未给它独立 id 或独立表。`intendedDate` 不单独建列，由 `DailyReview.date + 1` 派生。

**What this object must NOT represent:** 每个 Goal 都必须填写的计划、任务生命周期、接续点的别名。

## 领域枚举

这些类型没有独立 id、关系或持久化表；其值通过所属对象必需字段保存。下表中的 Values 即它们的 Fields，不另外添加默认值。

| 类型 / Purpose | Values / Field semantics | Relationships 与 Required / optional | Persistence status | What this object must NOT represent |
| --- | --- | --- | --- | --- |
| TimePrecision：边界可信精度 | 当前回顾式输入统一approximate：近似（Q-030）；旧模型含exact，兼容及值域调整待Q-031 | TimeBlock、SleepSession 的起止分别必需 | 随所属实体字段保存 | 内容是否已知、对用户的质量评分 |
| BlockKnowledgeState：活动内容的已知性 | known：知道大概做了什么；unknown：无法恢复内容但已交代时间 | TimeBlock.knowledgeState 必需 | 随 TimeBlock 保存 | Gap、时间精度或记录失败 |
| RhythmState：用户节奏解释 | progress：主要产生用户确认的目标推进；stuck：尝试推进目标相关事情但主要消耗于阻力、停滞或反复尝试；recovery：主要作用是重新获得继续行动的可能 | RhythmAnnotation.state 必需；annotation 本身可不存在 | 随 RhythmAnnotation 保存 | neutral、useless、活动类别、自动生产力判断 |
| SleepType：睡眠类型 | mainSleep：主睡眠；nap：午睡 / 小睡 | SleepSession.type 必需 | 随 SleepSession 保存 | 恢复方式或睡眠质量；不自行添加时长分类阈值 |

Goal.status 明确只有 active、archived；不额外引入新的生命周期值或强制命名一个源文档未命名的类型。首版只能创建 active；归档、恢复、引用、删除和改名行为见 [DOMAIN_STATE_MACHINES](DOMAIN_STATE_MACHINES.md)。

## Derived Models（§23–25、§30）

本节仅界定对象及事实源边界；计算细节集中见 [DERIVED_MODELS](DERIVED_MODELS.md)。

| 模型 / 字段 | Purpose / Field semantics 与 Relationships | Required / optional | Persistence status / 禁止承载的语义 |
| --- | --- | --- | --- |
| DayLedgerView | 自然日窗口上的 projection；概念字段 date、segments、unresolvedSpans、sleepSummary、goalSummaries、accountedDuration、unknownDuration、unresolvedDuration | 源文档为概念结构，输出空值约定未定义 | NO；不是数据库 Day entity |
| segments | TimeBlock 与 SleepSession 在窗口内的切片 | 集合的具体结构未定义 | NO；不是拆分后另存的时间事实 |
| UnresolvedSpan | 时间轴尚未处理的空隙；来自事实之间未覆盖区间 | 具体字段结构未定义 | NO；不是 Unknown |
| sleepSummary / goalSummaries | 睡眠背景与目标时间描述；由相应事实及解释生成 | 汇总结构未完整定义 | NO；不是独立统计事实源 |
| accountedDuration | 已交代时间，包含 Unknown | 派生数值；公式不在本轮决定 | NO；不是成绩 |
| unknownDuration / unresolvedDuration | 已确认未知 / 尚未处理的时长，分别表达 | 同上 | NO；不能合并为一种缺失 |
| progressDuration / stuckDuration / recoveryDuration | 由时间事实与 RhythmAnnotation 派生的节奏时长；恢复在当天背景中单列 | 同上 | NO；不写回 DailyReview |
| hasApproximation | 汇总可携带的标志，表达参与计算的某些记录边界近似 | 具体切片传播细节未完整定义 | NO；不是独立事实或置信度评分 |

自然日按当前设备时区投影；设备时区变化后历史事实按新时区重新投影，原始事实不变。今天对账截至当前时刻（Q-009）；睡眠摘要按醒来日期归属，主睡眠与小睡分别列出并合计整次时长（Q-010）；重叠保存按 Q-011 原子拒绝。图示或示例时长不替代正式计算定义。

## UI Models（§26–29）

**Purpose:** 支撑时间建议、活动输入、补账以及会话内输入恢复。

**Fields / Field semantics:** 会话快照可保留用户已修改的活动 / 睡眠 / 复盘文本、选择以及活动引导步骤。Q-036后续要求每次新建 / 补记进入直接重算完整可改估计，以约80%无需额外时间操作为目标，包含多日断记 / 漏睡眠；结合相邻完整事实与个人睡眠学习，无历史用常规作息。不用旧会话端点绕过时间初始化；既有事实更正则以当前正式记录为基线。确切模型 / 参数与学习元数据位置见Q-037候选，不将预测模型作为持久化账本事实。新建统一approximate，无精度选择（Q-030）；旧精度迁移待Q-031。

**Relationships:** 会话输入可由 UnresolvedSpan 预填，确认后形成领域事实；系统猜测和会话快照都不等于用户确认的记录。

**Required / optional:** 未定义，不从示意交互推导新的领域必填项。

**Persistence status:** NO。按Q-012仅保留在当前应用 / 网页会话的内存快照中；冷启动或刷新后为空。快照与正式事实分开，不参与覆盖、统计或重叠判断，编辑期间不修改原正式记录。睡眠学习反馈另行持久化，不属于未完成输入。

**What these objects must NOT represent:** 新增持久化 Gap、运行中的计时器领域实体、额外 Day 实体或强制记录流程状态。
