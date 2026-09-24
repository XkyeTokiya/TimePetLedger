# Implementation Plan

## 依据与执行边界

本文回答“按照什么顺序做？”，范围以 [MVP_SCOPE](MVP_SCOPE.md) 为准，产品依据为 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)、[PRODUCT_DEFINITION](../product/PRODUCT_DEFINITION.md)、[PRODUCT_PRINCIPLES](../product/PRODUCT_PRINCIPLES.md)。实施必须同时满足 [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)、[DOMAIN_RULES](../domain/DOMAIN_RULES.md)、[DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md)、[DERIVED_MODELS](../domain/DERIVED_MODELS.md)。代码和数据边界引用 [APP_ARCHITECTURE](../architecture/APP_ARCHITECTURE.md)、[DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md)。

**Engineering / Planning Recommendation：** Epic 划分、顺序、测试安排与采用架构建议的路径属于工程规划，不是新的产品要求。本文只规划未来开发，不创建代码、安装依赖或执行任何 Epic。当前仓库只有基础 Flutter 启动工程；从现状建立首版，不重新生成项目覆盖现有文件。

## 顺序与依赖

| 顺序 | Epic | 完成所需的前置 Epic | MVP 覆盖 |
| --- | --- | --- | --- |
| 0 | Project Foundation | 无 | M-07 |
| 1 | Domain Foundation | 0 | M-01–M-07 的领域合同 |
| 2 | Persistence Foundation | 0、1 | M-07；五类持久化对象 |
| 3 | Ledger Projection Engine | 1 | M-02、M-03、M-05 |
| 4 | Basic Recording | 2、3 | M-01、M-07 |
| 5 | Sleep Recording | 2、3 | M-03、M-07 |
| 6 | Daily Timeline / Gap Resolution | 3、4、5 | M-02 |
| 7 | Goal + Rhythm Annotation | 2、4、6 | M-04 |
| 8 | Statistics / Summaries | 3、5、6、7 | M-05 |
| 9 | Daily Review | 2、7、8 | M-06 |
| 10 | Polish / Reliability | 4、5、6、7、8、9 | 核心闭环整体 |

编号是推荐主线，不表示所有工作只能串行。Epic 3 的纯计算可在 Epic 1 对应合同明确后与 Epic 2 并行；Epic 5 的睡眠入口不依赖 Epic 4 的普通活动编辑器。表中依赖指完整 Epic 验收所需条件，允许先完成不受未决项影响的局部内容，但不得将未完成的 Epic 标记为完成。

相对参考顺序作两处调整：睡眠提前到完整时间轴 / Gap 体验之前，避免验收时把已睡时间当成未交代；基础摘要提前到复盘之前，为复盘提供一致的事实上下文。Epic 7 使用已贯通的时间轴附加解释，Epic 8 验证组合后的摘要。这些是集成顺序建议，不表示 Goal 实体依赖 UI，也不把复盘强制绑定统计阅读步骤。

## 未决问题与完成门槛

问题的原文、选项和状态仅维护于 [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md)。下表不选答案；进入相应开发工作前须确认合同并更新对应规范，不能以代码默认值代替产品决定。

| 问题 | 阻塞的交付 / 验收 | 可以先进行的工作 |
| --- | --- | --- |
| Q-001 | Epic 2 意向日期存储，Epic 9 历史复盘与下一步日期 | 保留 TomorrowFirstStep 概念字段 |
| Q-002 | Epic 1 / 2 最终 categoryId 字段映射 | 普通事实的核心语义；不实现分类管理 |
| Q-003、Q-005、Q-013 | Epic 1 转换合同，Epic 2 引用与写入动作，Epic 4 / 7 / 9 更正与移除；Epic 10 生命周期验收 | 已确定值域及独立事实建模，不默认任意转换 |
| Q-004 | Epic 1 关联合法性、Epic 2 约束、Epic 7 实际关联输入 | 可选归属 / 解释的分离；不默认全部组合合法 |
| Q-006、Q-019 | Epic 1 / 2 Goal 状态、名称与引用规则，Epic 7 创建及生命周期入口 | Goal 时间归属语义、已有两状态值域 |
| Q-007 | Epic 1 细节类型、Epic 2 完整 annotation schema、Epic 7 可选细节入口 | 三种节奏的语义，不把细节变成必填 |
| Q-008、Q-017 | Epic 1 时间合同、Epic 2 编码 / 查询、Epic 3 日期窗口与端点、Epic 4–9 时间体验 | 显式窗口与事实输入下的算法分析，不固化设备时区或 1440 分钟 |
| Q-009、Q-014 | Epic 3 / 6 当前日投影、精度传播；Epic 8 近似展示 | 原始起止精度和明确窗口下的集合运算 |
| Q-010、Q-020、Q-021 | Epic 3 摘要输出，Epic 5 首次睡眠确认，Epic 8 目标参与集与缺失表示 | 完整睡眠事实与明确参与集求和 |
| Q-011、Q-016 | Epic 1 睡眠校验、Epic 2 时间写入，Epic 4 / 5 / 6 冲突反馈 | 不重叠原则，不静默改写原事实 |
| Q-012 | 若另行批准退出后恢复草稿，则阻塞该能力 | 正式记录闭环；不新增 draft 领域状态 |
| Q-015、Q-018 | Epic 1 / 2 文本、身份与元数据合同；各写入口的相应验收 | 已确定必填 / 可选性及 known 标题存在且非空 |
| Q-022 | Epic 0 平台验证范围、Epic 2 驱动选择、Epic 10 发布检查 | 纯领域与计算工作 |
| Q-023 | Epic 4 非 Gap 入口的建议时间；Epic 5 若复用普通建议算法同受影响 | Gap 入口的已知区间预填，不凭算法猜测事实 |

完整 schema 的具体待决边界以 DATA_ARCHITECTURE 的清单为准。可选输入暂不显示不能解决 recoveryQuality 类型、外键动作等存储问题。摘要问题也不能通过保存派生统计绕开。未决问题不要求整个项目停工，但涉及该问题的验收必须等待答案。

## Epic 0 — Project Foundation

**Goal:** 建立可验证的最小开发基线。

**Why now:** 先确认现有工程状态和验证方式，后续变更才能定位影响。

**Dependencies:** 无；首发平台与平台验证范围依赖 Q-022。

**Deliverables:** 现有 Flutter 工程基线检查、最小 app / core / features 组织约定、格式化 / 静态分析 / 测试执行方式，以及确认平台后的运行基线。目录按实际文件需要建立，不生成空层级。

**Acceptance criteria:** 现有启动行为能够验证；明确所支持平台与验证命令；未因初始化覆盖已有文件。未经选择不安装数据库或状态管理包；平台未定时只报告已验证环境，不声称完成发布支持。

**Explicit non-goals:** 功能页面、庞大设计系统、通用框架、网络服务、提前引入全部依赖。

## Epic 1 — Domain Foundation

**Goal:** 用纯领域对象、值与校验表达已确认合同。

**Why now:** 存储、投影和用户输入需要共享语义，不能各自创造规则。

**Dependencies:** Epic 0；按上表解决涉及字段、类型、合法状态及时间规则的问题。未决部分不以占位枚举伪装完成。

**Deliverables:** 五类实体、TomorrowFirstStep、已确认的枚举与时间值；对应合法性校验及纯重叠判定；领域测试。真实生命周期只按已批准合同实现。

**Acceptance criteria:** DOMAIN_MODEL 字段与 DOMAIN_RULES 可追溯；TimeBlock / RhythmAnnotation / SleepSession 保持独立；known / unknown 与两端精度独立；可选关联和细节没有被升级为必填。合法及非法样例有针对性测试，domain 不依赖 Flutter、数据库或全局当前时间。

**Explicit non-goals:** 数据库、页面、通用状态机引擎、虚构 draft / completed 状态或尚未批准的转换。

## Epic 2 — Persistence Foundation

**Goal:** 可靠保存并读回五类正式事实与解释。

**Why now:** 记录入口必须有真实持久化和原子约束，不能以界面内存模拟完成闭环。

**Dependencies:** Epic 0、1；DATA_ARCHITECTURE 的 schema 定稿问题及 Q-022 的驱动选择。

**Deliverables:** 对应 feature 的 repository interface / 实现、首版五表 schema、显式映射、必要索引、约束和事务；一致读取与受控写入。采用本地 SQLite 属于现有工程建议，选包前核验首发平台支持。

**Acceptance criteria:** 完整字段映射与重启读回验证通过；数据库验证已确定 NOT NULL / CHECK / FK / UNIQUE；跨 TimeBlock / SleepSession 重叠检测与保存处于同一原子操作；冲突、约束错误或写入失败不留下部分提交。时间窗口查询包含跨日事实，读取多表获得一致视图。更正 / 删除动作仅按批准合同验证，未知问题不借默认级联解决。

**Explicit non-goals:** 保存 Day / Gap / 聚合统计、同步架构、通用 repository 框架、在数据库中重写领域解释。

## Epic 3 — Ledger Projection Engine

**Goal:** 将事实投影为明确日窗口下的账本及摘要。

**Why now:** 时间轴、缺口处理和统计必须复用同一计算来源。

**Dependencies:** Epic 1；独立于 Epic 2。完整输出需确认窗口、端点、摘要选择与近似传播等问题。

**Deliverables:** 纯投影逻辑与结果模型，覆盖 DERIVED_MODELS 中 DayLedgerView、segments、UnresolvedSpan、各时长、sleepSummary、goalSummaries、hasApproximation；显式输入窗口、事实和已确定政策。

**Acceptance criteria:** 手算样例和跨日 / 窗口外记录 / 相接边界 / Unknown / 未标记目标时间等测试通过；accounted 与 unresolved 对同一完整窗口成立分区关系，Unknown 不重复相加；annotation 不新增覆盖；跨日切片不改原记录。缺失摘要和近似传播按批准合同输出，不将未知政策藏进默认参数。

**Explicit non-goals:** 数据库 Day entity、Gap 持久化、UI、存储访问、评分或睡眠因果推断。

## Epic 4 — Basic Recording

**Goal:** 贯通活动为主要输入的回顾记录路径。

**Why now:** 有了存储和投影后，可验证核心输入成本及保存反馈。

**Dependencies:** Epic 2、3；Q-023 时间建议、Q-011 冲突反馈及相关输入合同。保存后更正行为依 Q-003 / Q-013。

**Deliverables:** 普通 TimeBlock 的 known / unknown 记录入口、可改时间建议、独立精度输入、保存反馈与成功后的账本刷新；适用时提供 Should Have 的 note 入口。

**Acceptance criteria:** 无 Goal、分类和 annotation 也能提交合法记录；known 标题规则生效，unknown 不强制虚构活动名称；用户可以修正系统时间假设。失败不报告成功或丢失当前输入，冲突不覆盖其他事实；提交后读回和投影一致。建议时间不是不可修改的事实判定。

**Explicit non-goals:** timer-first、分类管理、自动推断节奏、擅自开放所有保存后编辑 / 删除操作、退出后恢复草稿承诺。

## Epic 5 — Sleep Recording

**Goal:** 低成本保存独立睡眠事实并体现其高记录优先级。

**Why now:** 睡眠直接影响一天覆盖，完整 Gap 体验需要先接入真实睡眠。

**Dependencies:** Epic 2、3；Q-010 已记录判断 / 昨晚选择与 Q-016 睡眠校验，以及适用的时间、冲突合同。

**Deliverables:** mainSleep / nap 记录、起止及精度输入、完整跨日保存与日切片接入；按批准合同实现首次打开时的睡眠确认。可选 note 输入入口按 MVP_SCOPE 的 Should Have 单独排期，不成为 Must Have 验收门槛。

**Acceptance criteria:** 跨日睡眠保存为一条事实；睡眠与普通块重叠时按已确定规则反馈；日窗口展示对应贡献。已记录睡眠时不重复打扰，未记录不能显示为“未睡觉”；sleep 不写入 recovery 或附带普通 RhythmAnnotation。

**Explicit non-goals:** 睡眠质量评分、睡眠因果分析、长期趋势、nap 与 recovery 联动。

## Epic 6 — Daily Timeline / Gap Resolution

**Goal:** 让用户在同一天账本上辨认事实、Unknown 与待解决缺口。

**Why now:** 普通记录和睡眠均已贯通，可完整验证一天的覆盖与补记。

**Dependencies:** Epic 3、4、5；Q-008 / Q-009 日窗口、Q-014 精度传播及相关端点合同。

**Deliverables:** 日窗口查询与时间轴呈现、跨日切片、派生 Gap 入口；从 Gap 预填时间后补 known 或确认 unknown，成功后重读投影。

**Acceptance criteria:** 空白不是自动 Unknown；确认 Unknown 后形成 TimeBlock 并计入 accounted；Gap 不保存为行。补记或批准的更正后缺口随事实重算；保留未解决 Gap 合法。接近日界与当前日截止的结果符合确定政策，不默认每一天固定 1440 分钟或自动补到未来。

**Explicit non-goals:** 完整度分数、强制补齐全日、平行时间线、自动拆分 / 合并已存事实。

## Epic 7 — Goal + Rhythm Annotation

**Goal:** 在时间事实之上增加可选的归属和节奏解释。

**Why now:** 先证明记录闭环，再验证解释不会增加普通时间的记录门槛。

**Dependencies:** Epic 2、4、6；Q-004–Q-007、Q-013、Q-019 的关联、生命周期与细节合同。

**Deliverables:** 简单 Goal 创建 / 选择与经确认的状态操作；TimeBlock 的可选归属和最多一份 annotation；经确认的 add / edit / remove 行为；continuationHint 入口。Should Have 的原因与恢复细节入口可单独排期。

**Acceptance criteria:** 无解释仍是合法时间事实；用户明确选择 progress / stuck / recovery，不从标题自动打标；不强制状态链。可不填原因或恢复细节；接续点不成为每日任务。目标相关时间在交互中优先突出区间确认，但 approximate 仍可保存（TB-003）。归档引用、解释切换和删除仅按已批准规则执行，字段不被无依据清空；一块最多一份有效解释的集成测试通过。

**Explicit non-goals:** 任务树、目标进度百分比、deadline、里程碑、优先级、自动效果评价或睡眠 recovery 化。

## Epic 8 — Statistics / Summaries

**Goal:** 呈现帮助理解一天和目标时间的基础描述性摘要。

**Why now:** 已接入睡眠、普通事实和节奏，能验证不同口径不会混算，并为复盘提供上下文。

**Dependencies:** Epic 3、5、6、7；Q-010、Q-014、Q-020、Q-021。

**Deliverables:** 睡眠背景、账本覆盖、Unknown 子集、目标相关 / progress / stuck 与 recovery 的基础展示；适用的近似和缺失数据表示。

**Acceptance criteria:** 展示与同一事实快照的投影一致，成功写入后刷新；无 annotation 的目标时间不自动当作 progress，相关总时长不冒充推进时长；Unknown 不被加两遍。缺失记录不推断零活动，睡眠与日内目标节奏只作描述；不把派生数字写回 DailyReview 或统计表。

**Explicit non-goals:** 评分、排行、效率百分比、因果睡眠结论、长期分析系统或新统计存储层。

## Epic 9 — Daily Review

**Goal:** 将对一天的解释收束为一次可接续的下一步。

**Why now:** 事实、归属和基础摘要已可用，复盘无需自行维护另一套统计。

**Dependencies:** Epic 2、7、8；Q-001 intendedDate、Q-008 日期、Q-013 保存 / 更正及 Q-015 文本合同。

**Deliverables:** 可选 summary / reflection、一个 TomorrowFirstStep、可选 Goal 关联；按日保存和读取；按批准合同处理已有日期及历史复盘。

**Acceptance criteria:** 同日唯一约束验证通过；下一步意向日期采用确定规则，不能擅自取今天或 review.date + 1；不要求给每个 Goal 写计划。continuationHint 与 TomorrowFirstStep 分工清楚；复盘不存派生时长，事实更正不会未经授权重写用户反思。

**Explicit non-goals:** 独立任务管理、强制每日打卡、结构化复盘字段扩张、自动评价反思。

## Epic 10 — Polish / Reliability

**Goal:** 验证首发平台上的完整 MVP 闭环与关键失败路径。

**Why now:** 各入口已接入，才能发现跨流程的一致性和记录成本问题。

**Dependencies:** Epic 4、5、6、7、8、9；首发平台 Q-022 与 Must Have 涉及的产品合同均已明确。

**Deliverables:** MVP_SCOPE 闭环场景验证、重启读回 / 失败反馈 / 冲突写入 / 跨日 / 近似 / 空数据检查，以及阻碍核心输入和理解的问题修复。

**Acceptance criteria:** Must Have 均有可复现验证，相关格式化、静态分析和测试通过；首发平台的数据保存与重启读回检查通过。批准的更正操作不会留下部分写入或陈旧摘要；没有域外功能、派生数据来源或隐藏产品默认值。未交付 Should Have 如实记录，不将其包装成 Must Have 失败，也不把未决 Must Have 当完成。

**Explicit non-goals:** 扩张 MVP、支持未批准的平台、补齐未来功能、建立巨大测试 / 设计框架。

## 验证与完成纪律

可靠性从 Epic 1 开始逐层验证：纯领域规则与计算用确定输入测试；持久化用真实约束、事务及失败路径验证；记录入口验证输入成本、可选性和保存反馈；最终再覆盖整条闭环。Epic 10 不承担前面各 Epic 应有的所有测试。

每个 Epic 的交付必须能追溯到 MVP 范围、领域规则和已解决的问题。接口可以按实际使用增量形成，不一次生成通用抽象。Should Have 独立标注，Later 与 Explicitly Out of Scope 不转成隐含任务。近期任务见 [TASKS](../../TASKS.md)，后续 Epic 在进入相应工作前再细化；读取计划不构成执行授权。
