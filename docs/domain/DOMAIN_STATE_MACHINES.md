# Domain State Machines

## 依据与边界

本文件回答“状态如何变化？”，依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)，结合 [DOMAIN_MODEL](DOMAIN_MODEL.md)、[DOMAIN_RULES](DOMAIN_RULES.md) 与 [OPEN_QUESTIONS](OPEN_QUESTIONS.md)。字段和校验以已有文档为准，不在此重复完整清单。

状态值存在、对象可保存、某项操作有合理含义，不等于完整转换权限已经确定。下文区分：

- **已确定：** 源文档明确支持的状态、记录结果或操作含义。
- **待定：** 转换是否开放、前置条件或字段处理尚未唯一确定；不视作默认允许，也不视作禁止。
- **无效：** 违反已确定规则的结果。

本轮不新增 draft / completed / deleted 等领域状态，不用 CRUD 操作构造通用状态机，也不建立自动推进流程。派生数据的变化见 [DERIVED_MODELS](DERIVED_MODELS.md)。

## 对象判断

| 对象 | 是否需要生命周期状态机 | 本轮结论 |
| --- | --- | --- |
| Goal | 存在 active / archived 生命周期维度 | 创建、归档、恢复、引用、删除、改名和重复请求合同已按 Q-006 确定 |
| TimeBlock | 存在 known / unknown 认知状态维度，不是工作生命周期 | 双向认知更正及字段策略已按 Q-003 确定；通用操作合同见 Q-013 |
| RhythmAnnotation | 没有阶段式生命周期 | 分析 add / edit / remove 与 0..1 关系；三个节奏值不构成阶段顺序 |
| SleepSession | 没有已定义生命周期状态 | 记录、更正与删除不是入睡 / 醒来的实时状态机 |
| DailyReview | 没有已定义生命周期状态 | 保存解释与行动，不引入提交、完成、锁定或重开状态 |

## Goal

来源：§11；规则 GO-001、GO-002；Q-006、Q-018；Q-019 明确允许同名，按 id 区分。

### States

`active`、`archived`。这是生命周期维度，不是目标完成度。`archivedAt` 是可选字段，不是第三个状态。Goal 只能以 active 创建。

### Events

“归档”“恢复为 active”“重命名”“删除”是已批准的 Goal 操作。删除是否物理执行取决于是否存在引用；不引入 deleted 状态。

### Allowed transitions

| 起点 | 事件 / 终点 | 已确定的含义 | 许可与前置条件 |
| --- | --- | --- | --- |
| 尚无对象 | 创建为 active | 对象只能使用这两个状态值 | 不支持直接创建 archived |
| active | 归档 → archived | 结果属于 archived 状态 | 写入当前 UTC archivedAt；保留既有引用，禁止新增关联 |
| archived | 恢复 → active | 结果属于 active 状态 | 清除 archivedAt；恢复新增关联资格 |
| active / archived | 重复请求相同状态 | 不是新增状态 | 幂等成功，不更新 updatedAt |

此表定义 `active ↔ archived` 双向转换及重复请求结果。

Q-025的2026-10-06补充：成功归档所选常用目标后清除本机常用选择；恢复Goal只恢复新增关联资格，不自动恢复常用，需手动再设。不自动选择另一个Goal。该交互偏好不增加Goal状态；已有事实和草稿仍按原关联处理。删除按下述引用合同执行后，同样清除对应常用选择。

### Invalid transitions

不得转换到 completed、paused、deleted 等未定义状态；不得以“归档”为名引入百分比、里程碑或任务树。archived Goal 不得用于新增关联，但既有引用继续有效。

### Deletion / correction semantics

删除不是第三个 status。未被 TimeBlock 或 TomorrowFirstStep 引用的 Goal 可以物理删除；有引用的 Goal 的界面删除操作执行归档并隐藏，保留引用且支持恢复和改名。archived Goal 可仅在已有时间记录中显示，不能进入新的归属选择。改名实时作用于历史记录，不保存名称快照。按 Q-019 创建与改名允许重名，各 id 的记录和统计独立；文本、id 与更新时间合同见 Q-015、Q-018。

## 通用更正与删除合同（Q-013）

TimeBlock、SleepSession 和 DailyReview 均允许原地更正及删除，更正保留 id / createdAt，不保存历史版本；updatedAt 遵循 Q-018，仅在实际变化成功保存后更新。业务字段可修改，结果须满足字段、时间、引用与唯一性规则；SleepSession 可更正类型与边界，DailyReview 可更正日期但同日仍至多一份，intendedDate 按新日期派生。

- 删除 TimeBlock 同时删除附属解释；单独移除解释保留 TimeBlock。
- 时间事实更正或删除只影响派生结果，不自动改写复盘文字；删除复盘不删除当天事实。
- 允许同次更正 TimeBlock 和解释，原子成功或原子失败。未请求更改解释时保留它；移除解释必须是明确操作，不以空参数暗示删除。
- 删除已不存在的对象幂等完成；修改不存在的对象提示“记录已不存在”，不自动重建。
- annotation 已存在时 add 拒绝并提示改用编辑；不存在时 edit 拒绝并提示先添加，remove 则视为已完成。

此合同不新增 deleted 状态、历史版本或通用 upsert，也不改变 Goal 的 Q-006 生命周期。

## TimeBlock

来源：§5–9、§28、§33；规则 TB-001–TB-008、LEDGER-001–LEDGER-004。

### States

`known` 与 `unknown` 只描述活动内容的已知性。两者都是持久化、已交代的时间事实；边界精度由两个独立的 TimePrecision 字段表达。

Gap 是派生的未处理区间，不是 TimeBlock 的起始状态或第三个状态。精度更正也不是 known / unknown 的自动转换。

### Events

- **记录已知活动：** 用户说明发生了什么，生成 known TimeBlock。
- **确认想不起来：** 用户确认未知，生成 unknown TimeBlock；从 Gap 补账时是新增事实、重新派生空隙，不是更新一个持久化 Gap。
- **更正认知状态：** 将已存 known 改为 unknown，或将 unknown 改为 known；具体转换行为见 Q-003。
- **更正其他字段 / 删除：** 不自动创建新的知识状态，操作合同见 Q-013。

### Allowed transitions

| 起点 | 事件 / 结果 | 确定程度 |
| --- | --- | --- |
| 尚无 TimeBlock | 记录活动 → known | 源文档明确支持；结果必须满足 known 标题及时间规则 |
| 尚无 TimeBlock | 确认未知 → unknown | 源文档明确支持；结果仍是已交代事实 |
| known | 更正为 unknown | 允许；保留已有字段和解释，不自动清空（Q-003） |
| unknown | 更正为 known | 允许；必须填写满足文本规则的活动名称（Q-003） |
| known / unknown | 保持 knowledgeState 并更正内容 | 不构成新的状态边；可编辑范围及关联影响见 Q-013 |

### 字段处理：known → unknown 与 unknown → known

下表按 Q-003 的产品决定规定转换行为；双向更正没有额外门槛，保存结果仍须满足既有领域规则。

| 字段 / 关联 | 转换时的处理 |
| --- | --- |
| knowledgeState | 由用户明确选择 known 或 unknown |
| title | 转为 unknown 时保留，用户可修改或清空；转为 known 时必须填写满足文本规则的活动名称 |
| goalId / note / categoryId | 不因状态切换自动清空或重置；可选内容可由用户修改或清空，新增目标关联仍受 Q-006 约束 |
| RhythmAnnotation | 保留已有解释，不自动添加、移除或改变节奏；用户编辑 / 移除解释的通用合同见 Q-005、Q-013 |
| startedAt / endedAt | 允许同次编辑；结果仍须严格正区间且不重叠 |
| startPrecision / endPrecision | 当前回顾式输入按Q-030统一approximate，无精度选择；旧exact记录的更正处理待Q-031。不从known / unknown推断精度 |
| id / createdAt / updatedAt | 元数据遵循 Q-018；通用更正操作合同仍见 Q-013 |

若在同一个窗口中仅改变 knowledgeState、区间不变，则 accountedDuration 不变；unknownDuration 按该区间是否被标为 unknown 改变。

### Invalid transitions

- 将 unknown 保存为错误状态或 Gap；将 Gap 加入 BlockKnowledgeState。
- 转为 known 后仍缺少活动描述或 title 为空（TB-005）。
- 以转换为由生成非正 TimeBlock 区间、并行主要事实或强制把精度改成 exact。
- 把 progress / stuck / recovery 当作 TimeBlock 的目标状态。

### Deletion / correction semantics

Unknown 改为 known 仍是在交代同一类时间事实，不是把“不合格记录”变为“完成记录”。按 Q-013 允许更正和删除；删除 TimeBlock 时原子移除附属 annotation，投影按剩余事实重算。只有查询窗口内不再被事实覆盖的区间才成为 Gap。事实更正和删除不自动改写 DailyReview 文字，不保存历史版本或建立 deleted 状态。

## RhythmAnnotation

**No meaningful state machine required.**

来源：§12–20、§33；规则 TB-008、RH-001–RH-008。`progress / stuck / recovery` 是用户解释的类别，不是必须经历的三个阶段；不存在自动 `stuck → recovery → progress` 链条。

### States

实体的 `state` 仍只取三个 RhythmState 值。下表中的“无 annotation / 有 annotation”只是 TimeBlock 上关系的存在情况，不添加 absent、neutral、removed 等枚举值。

### Events 与操作语义

| 操作 | 输入关系 | 语义及成功后的关系 | 已确定约束 / 未决边界 |
| --- | --- | --- | --- |
| add | TimeBlock 没有 annotation | 为已有事实附加一份用户解释，变为有 annotation | 只能一个有效解释，必须关联 TimeBlock；状态与字段满足 RH 规则；不因 known / unknown 或 goalId 缺失增加组合门槛 |
| edit | TimeBlock 已有 annotation | 修改这份解释的状态或可选细节，仍最多一份 | 不另外生成并存解释；同状态细节编辑与跨状态更正的范围、条件见 Q-005、Q-013 |
| remove | TimeBlock 已有 annotation | 允许移除；结果为该事实不再附解释 | 保留 TimeBlock，不变为 neutral；无解释时幂等完成，不保存历史版本（Q-013） |

操作按 Q-013 执行：已有解释时 add 提示改用编辑，无解释时 edit 提示先添加；remove 在无解释时幂等完成。单独 annotation 操作不改变 TimeBlock 字段；允许用户明确组合更正事实和解释，并以单个原子写入提交。

### Allowed transitions

add 得到三种合法解释之一，源文档明确允许可选附加。解释与 known / unknown、goalId 有无之间不设额外组合门槛。按 Q-005，progress、stuck、recovery 可任意双向更正，无先后顺序或额外转换门槛。remove 的完整操作合同仍见 Q-013。

切换状态保留已填附属字段，只展示和使用当前状态适用的细节：stuckReasonCode / stuckReasonText 仅在 stuck 使用，recoveryMethod / recoveryQuality 仅在 recovery 使用；切回对应状态可重新显示原值。continuationHint 在三种状态下均可填写，切换时不清空。所有细节仍可选，值域见 Q-007；通用编辑、移除及缺失对象处理遵循本文件 Q-013 合同。

### Invalid transitions

add 后同一 TimeBlock 存在两份有效解释；用 neutral 表示 remove 的结果；自动把未标记活动判为 stuck；编辑时以原因或恢复质量未填写拒绝合法的基础标记。状态切换的附属字段处理仍见 Q-005。

### Deletion / correction semantics

解释移除后，若事实区间仍存在，accountedDuration 不因移除解释而减少，亦不形成 Gap；其节奏贡献按新解释关系重新计算。更换 state 后旧分类不再与新分类同时计入同一事实。按 Q-013 移除解释，不保存历史版本；重复 remove 幂等完成，缺少解释时 edit 提示先添加，已有解释时 add 提示改用编辑。

## SleepSession

**No meaningful state machine required.**

来源：§4、§17；规则 SL-001–SL-005、LEDGER-003–LEDGER-004。

- **States:** 没有生命周期 status；mainSleep / nap 是类型，exact / approximate 是边界精度，均不组成睡眠过程状态机。
- **Events:** 记录睡眠、更正输入、删除是事实操作，不是“开始睡眠 / 正在睡眠 / 已醒”的实时追踪。
- **Allowed transitions:** 没有可定义的生命周期转换表。源文档支持保存完整跨日事实；类型或边界更正的具体操作合同见 Q-013、Q-016。
- **Invalid transitions:** 在午夜自动将一个事实转换成两条；转成 TimeBlock.recovery 或 RecoveryMethod.sleep；自行增加 running / finished 等状态。
- **Deletion / correction semantics:** 事实更正后相关窗口切片与睡眠摘要需要重新派生；删除合同见 Q-013，睡眠摘要选择见 Q-010。跨日不会更改原事实身份或触发状态转换；与其他事实冲突的处理见 Q-011。

## DailyReview

**No meaningful state machine required.**

来源：§21–22、§33；规则 DR-001–DR-004。

- **States:** 没有 draft / submitted / completed / locked 等正式领域状态。未完成输入按 Q-012 独立保存为本机 UI 草稿，不属于正式 DailyReview，不放宽正式字段规则。
- **Events:** 保存解释与明天第一步；更正或删除的具体支持方式见 Q-013。
- **Allowed transitions:** 无阶段式生命周期可定义。正式保存结果遵循一天最多一条及字段存在性规则；不推导每天必须提交、过日自动锁定或只能当天填写。
- **Invalid transitions:** 以统计值达到阈值自动“完成复盘”；为明天第一步新增任务完成状态；把派生分钟数保存为复盘事实源。
  - **Deletion / correction semantics:** 复盘内容与时间事实分层。修正时间事实会改变派生统计，不自动改写用户反思；删除复盘不等于删除当天事实。`intendedDate` 固定为 review.date 的下一自然日并由其派生，不单独持久化。复盘允许原地更正和删除，日期可修改但仍须唯一（Q-013）；不存在可随之级联删除的数据库 Day 实体。

## Engineering Recommendation（不是产品要求）

当前只有局部状态维度与普通事实操作，不需要通用状态机框架。后续开发可用明确的操作及前后置校验表达已确定行为，按 Q-003、Q-005、Q-013 已批准合同落实更正与删除。本建议不授权越过未决产品行为实现任意转换。
