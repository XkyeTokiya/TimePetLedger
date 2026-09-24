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
| TimeBlock | 存在 known / unknown 认知状态维度，不是工作生命周期 | 分析认知更正及目标状态约束；完整转换合同仍待定 |
| RhythmAnnotation | 没有阶段式生命周期 | 分析 add / edit / remove 与 0..1 关系；三个节奏值不构成阶段顺序 |
| SleepSession | 没有已定义生命周期状态 | 记录、更正与删除不是入睡 / 醒来的实时状态机 |
| DailyReview | 没有已定义生命周期状态 | 保存解释与行动，不引入提交、完成、锁定或重开状态 |

## Goal

来源：§11；规则 GO-001、GO-002；Q-006、Q-018；名称唯一性仍见 Q-019。

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

### Invalid transitions

不得转换到 completed、paused、deleted 等未定义状态；不得以“归档”为名引入百分比、里程碑或任务树。archived Goal 不得用于新增关联，但既有引用继续有效。

### Deletion / correction semantics

删除不是第三个 status。未被 TimeBlock 或 TomorrowFirstStep 引用的 Goal 可以物理删除；有引用的 Goal 的界面删除操作执行归档并隐藏，保留引用且支持恢复和改名。archived Goal 可仅在已有时间记录中显示，不能进入新的归属选择。改名实时作用于历史记录，不保存名称快照。重名校验见 Q-019；文本、id 与更新时间合同见 Q-015、Q-018。

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
| known | 更正为 unknown | 目标值合法；是否提供转换及完整字段处理未定（Q-003、Q-004） |
| unknown | 更正为 known | 目标值合法；结果必须有非空 title；转换合同仍未定（Q-003、Q-004） |
| known / unknown | 保持 knowledgeState 并更正内容 | 不构成新的状态边；可编辑范围及关联影响见 Q-013 |

### 字段处理：known → unknown 与 unknown → known

下表是**目标状态约束与缺口**，不是自动清理算法。

| 字段 / 关联 | known → unknown | unknown → known |
| --- | --- | --- |
| knowledgeState | 若转换执行，目标值为 unknown | 若转换执行，目标值为 known |
| title | 可为 null；不代表必须清空，旧描述的保留、替换或确认方式未定（Q-003） | 结果必须有非空活动描述；不能默认为沿用“想不起来”，如何取得新内容未定（Q-003、Q-015） |
| goalId | 是否保留、解除及允许的组合未定（Q-003、Q-004） | 是否沿用或要求重选未定；不能新增“一定关联 Goal”的要求（Q-003、Q-004） |
| RhythmAnnotation | 是否保留、移除、要求用户确认未定；不能自动改为 recovery（Q-003、Q-004） | 不能因恢复记忆自动添加 progress；原关联如何处理未定（Q-003、Q-004） |
| note | 不因状态名推导清空或保留政策（Q-003） | 同左（Q-003） |
| categoryId | 首版保留可空扩展字段；转换时不因 knowledgeState 自动清理，具体更正操作仍见 Q-003 | 同左 |
| startedAt / endedAt | 状态名不授权改变区间；结果仍满足 TB-001。是否同次编辑区间见 Q-003、Q-013 | 同左 |
| startPrecision / endPrecision | unknown 不意味着 approximate；更正精度须独立表达，不能从已知性推断 | known 不意味着 exact；两个边界仍独立 |
| id / createdAt / updatedAt | id 和时间戳合同已由 Q-018 确定；原地更正或其他操作合同仍见 Q-013 | 同左 |

若在同一个窗口中仅改变 knowledgeState、区间不变，则 accountedDuration 不变；unknownDuration 按该区间是否被标为 unknown 改变。这是投影上的条件性结果，不代表源文档已经选定字段保留策略。

### Invalid transitions

- 将 unknown 保存为错误状态或 Gap；将 Gap 加入 BlockKnowledgeState。
- 转为 known 后仍缺少活动描述或 title 为空（TB-005）。
- 以转换为由生成非正 TimeBlock 区间、并行主要事实或强制把精度改成 exact。
- 把 progress / stuck / recovery 当作 TimeBlock 的目标状态。

### Deletion / correction semantics

Unknown 改为 known 仍是在交代同一类时间事实，不是把“不合格记录”变为“完成记录”。删除 TimeBlock 若最终获准且完成，投影必须根据剩余事实重算；只有该区间在查询窗口内不再被事实覆盖时才出现 Gap。是否允许删除、如何处理依附 annotation、是否保留历史等由 Q-013 决定，不建立 deleted 状态。事实更正不得顺带选择重写 DailyReview 文字的政策。

## RhythmAnnotation

**No meaningful state machine required.**

来源：§12–20、§33；规则 TB-008、RH-001–RH-008。`progress / stuck / recovery` 是用户解释的类别，不是必须经历的三个阶段；不存在自动 `stuck → recovery → progress` 链条。

### States

实体的 `state` 仍只取三个 RhythmState 值。下表中的“无 annotation / 有 annotation”只是 TimeBlock 上关系的存在情况，不添加 absent、neutral、removed 等枚举值。

### Events 与操作语义

| 操作 | 输入关系 | 语义及成功后的关系 | 已确定约束 / 未决边界 |
| --- | --- | --- | --- |
| add | TimeBlock 没有 annotation | 为已有事实附加一份用户解释，变为有 annotation | 只能一个有效解释，必须关联 TimeBlock；状态与字段满足 RH 规则；组合条件见 Q-004 |
| edit | TimeBlock 已有 annotation | 修改这份解释的状态或可选细节，仍最多一份 | 不另外生成并存解释；同状态细节编辑与跨状态更正的范围、条件见 Q-005、Q-013 |
| remove | TimeBlock 已有 annotation | 若此操作提供并成功，结果为该事实不再附有效解释 | 不等于删除 TimeBlock，不变为 neutral；是否允许、删除方式、历史与重复请求行为见 Q-013 |

这定义三种操作的领域含义，不据此补全编辑 / 删除权限、确认弹窗、幂等策略或历史记录机制。annotation 操作本身不改变 TimeBlock 的活动、区间、已知性或 Goal；是否支持同时编辑事实属于另一项操作合同（Q-013）。

### Allowed transitions

add 得到三种合法解释之一，源文档明确允许可选附加。edit 从任一种解释改到另一种时，目标值属于合法值域并不足以证明整个操作合法：六个有向组合的开放条件与附属字段处理均未定义，见 Q-005。remove 的结果可解释为“未标记”，但源文档没有完整删除合同，见 Q-013。

对 edit 尤其不能擅自规定：离开 stuck 必须清空两个原因字段、离开 recovery 必须清空方式和质量、进入 recovery 必须删除 continuationHint，或所有字段必须无条件保留。它们均为 Q-005 的待决内容。

### Invalid transitions

add 后同一 TimeBlock 存在两份有效解释；用 neutral 表示 remove 的结果；自动把未标记活动判为 stuck；编辑时以原因或恢复质量未填写拒绝合法的基础标记。具体组合的可接受性仍须区分 Q-004、Q-005 的未决状态。

### Deletion / correction semantics

解释移除后，若事实区间仍存在，accountedDuration 不因移除解释而减少，亦不形成 Gap；其节奏贡献按新解释关系重新计算。更换 state 后旧分类不再与新分类同时计入同一事实。物理删除还是其他处理、重复 remove、缺少解释时 edit、已有解释时再次 add 的响应策略见 Q-013；不以“最多一个有效”自行设计版本链。

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

- **States:** 没有 draft / submitted / completed / locked 等正式领域状态。输入未完成不代表已批准的持久化 draft（Q-012）。
- **Events:** 保存解释与明天第一步；更正或删除的具体支持方式见 Q-013。
- **Allowed transitions:** 无阶段式生命周期可定义。正式保存结果遵循一天最多一条及字段存在性规则；不推导每天必须提交、过日自动锁定或只能当天填写。
- **Invalid transitions:** 以统计值达到阈值自动“完成复盘”；为明天第一步新增任务完成状态；把派生分钟数保存为复盘事实源。
  - **Deletion / correction semantics:** 复盘内容与时间事实分层。修正时间事实会改变派生统计，不自动授权重写用户反思；删除复盘不等于删除当天事实。`intendedDate` 固定为 review.date 的下一自然日并由其派生，不单独持久化。复盘删除 / 更正合同仍见 Q-013；不存在可随之级联删除的数据库 Day 实体。

## Engineering Recommendation（不是产品要求）

当前只有局部状态维度与普通事实操作，不需要通用状态机框架。后续开发可用明确的操作及前后置校验表达已确定行为，待 Q-003、Q-005、Q-013 等获得答案后再补全转换合同。本建议不授权越过未决产品行为实现任意转换。
