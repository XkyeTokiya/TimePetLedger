# Product Principles

本文件回答“遵循什么产品原则？”。依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)，不扩展新产品要求。对象结构见 [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)，未决项见 [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md)。

## P-01 回顾式记录（§1、§27–28）

- **Principle:** 以事后回顾、补记为主要行为。
- **Why:** 用户需要低成本还原已经过去的时间。
- **Implication:** 记录入口围绕刚才发生的活动，补账是核心能力。
- **Anti-pattern:** 要求活动开始前启动计时器才能留下有效记录。

## P-02 完整不等于每分钟精确（§2、§25）

- **Principle:** 时间覆盖、语义清晰度、时间精度分别表达。
- **Why:** 已交代的时间可以内容未知，也可以边界近似。
- **Implication:** 完整账本允许真实的不确定性，显示数据状态。
- **Anti-pattern:** 将三个维度混成完成率或每日成绩。

## P-03 普通时间允许模糊（§5–6、§26）

- **Principle:** Approximate time 是合法数据；开始和结束可具有不同精度。
- **Why:** 用户可能只记得大概开始时间，却确定结束时间。
- **Implication:** 保留用于计算的具体时间与精度信息，汇总诚实表达“约”；目标时间同样允许 approximate。
- **Anti-pattern:** 强迫精确回忆，或把估计边界显示为绝对准确。

## P-04 高价值时间优先确认（§1、§26）

- **Principle:** 睡眠和目标相关时间值得优先记录与确认。
- **Why:** 这些时间直接支撑身体背景与目标节奏理解。
- **Implication:** 通过交互突出时间确认，普通生活以解释主要去向为主。
- **Anti-pattern:** 将 progress 必须 exact 变成保存门槛。

## P-05 Unknown 是合法事实（§7、§30）

- **Principle:** 想不起来也是对过去时间的诚实交代。
- **Why:** 编造活动比承认未知更损害账本真实性。
- **Implication:** Unknown 作为 TimeBlock 保存，计入已交代时间。
- **Anti-pattern:** 把 Unknown 当错误，逼用户随便填“刷手机”。

## P-06 Gap 与 Unknown 分开（§8–9、§28）

- **Principle:** Gap 是未处理的派生空白；Unknown 是用户已确认的事实。
- **Why:** 没有记录不等于用户已确认无法回忆。
- **Implication:** 由时间轴计算 Gap，用户确认未知后才保存 Unknown。
- **Anti-pattern:** 自动把空白保存成未知记录。

## P-07 事实与用户解释分开（§12–19）

- **Principle:** TimeBlock 记录发生了什么，RhythmAnnotation 解释部分时间的目标节奏。
- **Why:** 看起来像工作，不代表用户确认目标推进；普通生活也不自动属于恢复。
- **Implication:** 节奏解释可选，推进由用户确认，卡住原因与恢复细节可选。
- **Anti-pattern:** 把 progress / stuck / recovery 当作 TimeBlock 类型，或加入 useless、productive 布尔标签。

## P-08 Goal 只是时间归属（§11、§22）

- **Principle:** Goal 回答时间与哪个阶段性目标有关。
- **Why:** 理解目标时间无需建立项目管理系统。
- **Implication:** 目标关联可选；明天第一步也可关联一个 Goal。
- **Anti-pattern:** 引入任务树、里程碑，或要求每个 Goal 每日填写计划。

## P-09 分类不能成为前置成本（§10–11）

- **Principle:** 活动描述足以支持早期账本，核心不依赖 Category。
- **Why:** 复杂分类增加记录负担，且不能取代 Goal 的归属语义。
- **Implication:** 不要求先建分类或选择分类再记录。
- **Anti-pattern:** 为普通活动建立详细分类体系作为必填步骤。

## P-10 时间是系统假设，活动是主要输入（§27–28）

- **Principle:** 系统提出可修改的时间区间，用户主要补充活动。
- **Why:** 降低重复选择日期与起止时间的成本。
- **Implication:** 补账可用 Gap 边界预填草稿，用户可以修正区间。
- **Anti-pattern:** 将系统猜测视为不可修改的事实，或总是先展示复杂时间表单。

## P-11 睡眠独立且优先（§4、§17、§29）

- **Principle:** 睡眠是独立身体事实，拥有最高输入优先级。
- **Why:** 几点睡、几点醒是重要身体背景，不是普通恢复操作。
- **Implication:** 已记录不重复打扰；跨日睡眠保存完整事实，在自然日窗口切片展示。
- **Anti-pattern:** 把 SleepSession 塞入 Recovery，或要求用户午夜拆记录。

## P-12 Statistics 描述，不评分（§18–19、§25、§30）

- **Principle:** 统计从事实派生，展示差异而不评价用户。
- **Why:** 目标相关时间、明确推进和明确卡住有不同含义。
- **Implication:** 展示时长、未知与尚未记录等数据状态；不把派生分钟数变成复盘事实源。
- **Anti-pattern:** 输出效率百分比、生产力评分，或由 AI 自动判定用户“有效”。

## P-13 Correlation 与 causation 分离（§31）

- **Principle:** 睡眠与目标节奏只能做描述性关联。
- **Why:** 产品没有支持因果结论的实验设计。
- **Implication:** 可以陈述共同出现的现象，未来 AI 复盘也须遵守。
- **Anti-pattern:** 声称“睡眠不足导致效率下降 30%”。

## P-14 解释最终服务于下一次行动（§20–22）

- **Principle:** 接续点与明天第一步有不同语义。
- **Why:** 回到某件事从哪里接上，不等于明天先做什么。
- **Implication:** continuationHint 附于节奏解释；TomorrowFirstStep 属于每日复盘。
- **Anti-pattern:** 将二者合成通用任务或多项目明日计划器。

## P-15 自然日是投影边界（§23–24、§32）

- **Principle:** 自然日用于查询、展示与统计；主时间轴记录一段时间的主要事实。
- **Why:** 时间事实可以跨日，用户也无需为同时发生的活动做并行分摊。
- **Implication:** DayLedgerView 派生而不保存为 Day 实体；次要并行活动可以记在 note 中。
- **Anti-pattern:** 用数据库 Day 强迫事实拆分，或设计并行多任务时间轴。
