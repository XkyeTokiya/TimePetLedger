# Implementation Plan

## 依据与执行边界

本文回答“按照什么顺序做？”，范围以 [MVP_SCOPE](MVP_SCOPE.md) 为准，产品依据为 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)、[PRODUCT_DEFINITION](../product/PRODUCT_DEFINITION.md)、[PRODUCT_PRINCIPLES](../product/PRODUCT_PRINCIPLES.md)。实施必须同时满足 [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)、[DOMAIN_RULES](../domain/DOMAIN_RULES.md)、[DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md)、[DERIVED_MODELS](../domain/DERIVED_MODELS.md)。代码和数据边界引用 [APP_ARCHITECTURE](../architecture/APP_ARCHITECTURE.md)、[DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md)。

**Engineering / Planning Recommendation：** Epic 划分、顺序、测试安排与采用架构建议的路径属于工程规划，不是新的产品要求。本文只规划未来开发，不创建代码、安装依赖或执行任何 Epic。实际工程与前置交付状态以仓库及 docs/reports 的对应任务报告为准；从现状继续首版，不重新生成项目覆盖现有文件。

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

## 产品决定与完成门槛

截至 2026-09-25，OPEN_QUESTIONS 的 Q-001–Q-023 均为 DECIDED，对应领域、派生和架构规范已同步。进入实现仍须满足 Task 前置条件并取得实际验收证据，不能把产品澄清标作开发完成。

Q-012于2026-10-08更新为仅当前会话的未完成输入恢复，明确取代跨关闭 / 跨刷新的本机草稿合同，按INPUT-RECOVERY-01–04统一实施。Q-023 已确定普通记录时间建议分支和初始精度；Epic 4 及复用该算法的其他入口按 DOMAIN_RULES 实现。

## Epic 0 — Project Foundation

**Goal:** 建立可验证的最小开发基线。

**Why now:** 先确认现有工程状态和验证方式，后续变更才能定位影响。

**Dependencies:** 无；Q-022 已确定首发平台为 Android 和 Web。

**Deliverables:** 现有 Flutter 工程基线检查、最小 app / core / features 组织约定、格式化 / 静态分析 / 测试执行方式，以及 Android、Web 的运行基线。目录按实际文件需要建立，不生成空层级。

**Acceptance criteria:** 现有启动行为能够验证；Android 与 Web 分别有验证命令和实际结果；未因初始化覆盖已有文件。未经选型任务不安装数据库或状态管理包；其他平台不纳入首发支持声明。

**Explicit non-goals:** 功能页面、庞大设计系统、通用框架、网络服务、提前引入全部依赖。

## Epic 1 — Domain Foundation

**Goal:** 用纯领域对象、值与校验表达已确认合同。

**Why now:** 存储、投影和用户输入需要共享语义，不能各自创造规则。

**Dependencies:** Epic 0；按已确认的字段、类型、合法状态及时间合同执行，不以占位枚举代替完整实现。

**Deliverables:** 五类实体、TomorrowFirstStep、已确认的枚举与时间值；对应合法性校验及纯重叠判定；领域测试。真实生命周期只按已批准合同实现。

**Acceptance criteria:** DOMAIN_MODEL 字段与 DOMAIN_RULES 可追溯；TimeBlock / RhythmAnnotation / SleepSession 保持独立；known / unknown 与两端精度独立；可选关联和细节没有被升级为必填。合法及非法样例有针对性测试，domain 不依赖 Flutter、数据库或全局当前时间。

**Explicit non-goals:** 数据库、页面、通用状态机引擎、虚构 draft / completed 状态或尚未批准的转换。

## Epic 2 — Persistence Foundation

**Goal:** 可靠保存并读回五类正式事实与解释。

**Why now:** 记录入口必须有真实持久化和原子约束，不能以界面内存模拟完成闭环。

**Dependencies:** Epic 0、1；DATA_ARCHITECTURE 的 schema 定稿问题，以及面向 Android 与 Web 的持久化驱动核验。

**Deliverables:** 对应 feature 的 repository interface / 实现、首版五表 schema、显式映射、必要索引、约束和事务；一致读取与受控写入。采用本地 SQLite 属于现有工程建议，选包前核验首发平台支持。

**Acceptance criteria:** 完整字段映射与重启读回验证通过；数据库验证已确定 NOT NULL / CHECK / FK / UNIQUE；跨 TimeBlock / SleepSession 重叠检测与保存处于同一原子操作；冲突、约束错误或写入失败不留下部分提交。时间窗口查询包含跨日事实，读取多表获得一致视图。更正 / 删除动作仅按批准合同验证，未知问题不借默认级联解决。

**Explicit non-goals:** 保存 Day / Gap / 聚合统计、同步架构、通用 repository 框架、在数据库中重写领域解释。

## Epic 3 — Ledger Projection Engine

**Goal:** 将事实投影为明确日窗口下的账本及摘要。

**Why now:** 时间轴、缺口处理和统计必须复用同一计算来源。

**Dependencies:** Epic 1；独立于 Epic 2。窗口、端点、睡眠选择与近似传播按已确认合同执行；目标选择与细分按 Q-020 执行；缺失表达和微小时长显示按 Q-021 执行。

**Deliverables:** 纯投影逻辑与结果模型，覆盖 DERIVED_MODELS 中 DayLedgerView、segments、UnresolvedSpan、各时长、sleepSummary、goalSummaries、hasApproximation；显式输入窗口、事实和已确定政策。

**Acceptance criteria:** 手算样例和跨日 / 窗口外记录 / 相接边界 / Unknown / 未标记目标时间等测试通过；accounted 与 unresolved 对同一完整窗口成立分区关系，Unknown 不重复相加；annotation 不新增覆盖；跨日切片不改原记录。缺失摘要和近似传播按批准合同输出，不将未知政策藏进默认参数。

**Explicit non-goals:** 数据库 Day entity、Gap 持久化、UI、存储访问、评分或睡眠因果推断。

具体任务见 [TASKS / Epic 3](../../TASKS.md#epic-3--ledger-projection-engine)：E3-T01–E3-T07，依次覆盖窗口与时长合同、切片、覆盖与 Gap、节奏 / 目标汇总、完整睡眠摘要、DayLedgerView 组装及纯展示映射。每项自带验证；不等待数据库实现。

## 会话内输入恢复的共同交付合同（Q-012）

Epic 4 普通记录、Epic 5 睡眠和 Epic 9 复盘的新建、Gap补记与更正入口均使用由app运行期持有的内存session store。只有用户实际修改后才保留快照，回到初始基线时清除；同一context再次进入先显示继续 / 重新选择。新建 / 补记继续重算时间初值，更正从当前正式事实开始。快照不参与正式账本覆盖、统计和重叠判断，不新增领域 draft 状态。正式提交失败保留页面内容；已提交残留先识别事实并收尾，不重复提交。睡眠学习store与输入store分离并继续持久化。

实施顺序为：INPUT-RECOVERY-01固定文档合同；INPUT-RECOVERY-02实现会话store、清除旧输入并保留睡眠学习反馈；INPUT-RECOVERY-03贯通全部入口与失败体验；INPUT-RECOVERY-04验证Android / Web会话边界。历史COMPLETE报告仅保留为当时证据，不回写其结论。

## Epic 4 — Basic Recording

**Goal:** 贯通活动为主要输入的回顾记录路径。

**Why now:** 有了存储和投影后，可验证核心输入成本及保存反馈。

**Dependencies:** Epic 2、3；Q-023 时间建议及相关输入合同。保存后更正行为依 Q-003 / Q-013。

**Deliverables:** 普通 TimeBlock 的 known / unknown 记录入口、可改时间建议、独立精度输入、保存反馈与成功后的账本刷新；适用时提供 Should Have 的 note 入口。

**Acceptance criteria:** 无 Goal、分类和 annotation 也能提交合法记录；known 标题规则生效，unknown 不强制虚构活动名称；用户可以修正系统时间假设。失败不报告成功或丢失当前输入，冲突不覆盖其他事实；提交后读回和投影一致。建议时间不是不可修改的事实判定。

**Explicit non-goals:** timer-first、分类管理、自动推断节奏、擅自开放所有保存后编辑 / 删除操作。

具体任务见 [TASKS / Epic 4](../../TASKS.md#epic-4--basic-recording)：E4-T01–E4-T08 覆盖日期与读取、时间建议、独立草稿、表单、正式新建、更正删除、闭环及 Android / Web 恢复验证；E4-T09 为可选 note 入口，不阻塞核心完成。仅接普通记录所需入口与结果刷新，完整时间轴、睡眠输入、Goal / annotation 编辑和统计页面仍属后续 Epic。更正 / 删除权限已由 Q-003 / Q-013 批准，本 Epic 按合同开放 TimeBlock 操作，不外推到其他对象 UI。

## Epic 5 — Sleep Recording

**Goal:** 低成本保存独立睡眠事实并体现其高记录优先级。

**Why now:** 睡眠直接影响一天覆盖，完整 Gap 体验需要先接入真实睡眠。

**Dependencies:** Epic 2、3；Q-010 已确认的主睡眠识别与醒来日期归属，以及适用的时间、冲突合同。

**Deliverables:** mainSleep / nap 记录、起止及精度输入、完整跨日保存与日切片接入；按批准合同实现首次打开时的睡眠确认。可选 note 输入入口按 MVP_SCOPE 的 Should Have 单独排期，不成为 Must Have 验收门槛。

**Acceptance criteria:** 跨日睡眠保存为一条事实；睡眠与普通块重叠时按已确定规则反馈；日窗口展示对应贡献。已记录睡眠时不重复打扰，未记录不能显示为“未睡觉”；sleep 不写入 recovery 或附带普通 RhythmAnnotation。

**Explicit non-goals:** 睡眠质量评分、睡眠因果分析、长期趋势、nap 与 recovery 联动。

具体任务见 [TASKS / Epic 5](../../TASKS.md#epic-5--sleep-recording)：E5-T01–E5-T08 覆盖完整睡眠读取、独立草稿、表单、原子新建、更正删除、首次打开确认、应用闭环及 Android / Web 恢复验证；E5-T09 为可选 note 入口，不阻塞核心完成。复用 Epic 2 / 3 合同，不依赖 Epic 4 普通编辑器；首次打开的本机交互标记不替代正式主睡眠已记录判定。

## Epic 6 — Daily Timeline / Gap Resolution

**Goal:** 让用户在同一天账本上辨认事实、Unknown 与待解决缺口。

**Why now:** 普通记录和睡眠均已贯通，可完整验证一天的覆盖与补记。

**Dependencies:** Epic 3、4、5；Q-009 当前日窗口、Q-014 精度传播及已确认的时间合同。

**Deliverables:** 日窗口查询与时间轴呈现、跨日切片、派生 Gap 入口；从 Gap 预填时间后补 known 或确认 unknown，成功后重读投影。

**Acceptance criteria:** 空白不是自动 Unknown；确认 Unknown 后形成 TimeBlock 并计入 accounted；Gap 不保存为行。补记或批准的更正后缺口随事实重算；保留未解决 Gap 合法。接近日界与当前日截止的结果符合确定政策，不默认每一天固定 1440 分钟或自动补到未来。

**Explicit non-goals:** 完整度分数、强制补齐全日、平行时间线、自动拆分 / 合并已存事实。

具体任务见 [TASKS / Epic 6](../../TASKS.md#epic-6--daily-timeline--gap-resolution)：E6-T01–E6-T06 覆盖日期读取、切片与 Gap 时间轴、明确 Gap 补记、原事实更正路由、应用闭环及两平台集成验证。Gap 新草稿两端精度遵守 Q-023，不直接复制 Gap 的显示精度；已有草稿恢复遵守 Q-012。部分读取 / 展示可先行，完整验收仍要求 Epic 3、4、5 完成；统计页面留 Epic 8。

## Epic 7 — Goal + Rhythm Annotation

**Goal:** 在时间事实之上增加可选的归属和节奏解释。

**Why now:** 先证明记录闭环，再验证解释不会增加普通时间的记录门槛。

**Dependencies:** Epic 2、4、6；Q-005–Q-007、Q-013、Q-019 的解释切换、生命周期与细节合同。

**Deliverables:** 简单 Goal 创建 / 选择与经确认的状态操作；TimeBlock 的可选归属和最多一份 annotation；经确认的 add / edit / remove 行为；continuationHint 入口。Should Have 的原因与恢复细节入口可单独排期。

**Acceptance criteria:** 无解释仍是合法时间事实；用户明确选择 progress / stuck / recovery，不从标题自动打标；不强制状态链。可不填原因或恢复细节；接续点不成为每日任务。目标相关时间在交互中优先突出区间确认，但 approximate 仍可保存（TB-003）。归档引用、解释切换和删除仅按已批准规则执行，字段不被无依据清空；一块最多一份有效解释的集成测试通过。

**Explicit non-goals:** 任务树、目标进度百分比、deadline、里程碑、优先级、自动效果评价或睡眠 recovery 化。

具体任务见 [TASKS / Epic 7](../../TASKS.md#epic-7--goal--rhythm-annotation)：E7-T01–E7-T07 覆盖目标创建与生命周期、可选归属、节奏和接续点、时间轴回看、应用及两平台验证；E7-T08 单列可选原因 / 恢复细节 Should Have。扩展普通草稿时保留旧输入与未展示字段，不重复建设领域或原子写入。局部任务可按各自前置先行，完整 Epic 依赖保持不变。E7-T01 已完成并归档，目标 active 列表 / 创建及读取失败恢复的证据见 [E7-T01 报告](../reports/E7-T01_GOAL_CREATION_READ_REPORT.md)；E7-T02 已完成并归档，目标生命周期 UI 与引用保留的证据见 [E7-T02 报告](../reports/E7-T02_GOAL_LIFECYCLE_REPORT.md)；E7-T03 已完成并归档，可选目标归属、草稿升级与真实库保存 / 恢复的证据见 [E7-T03 报告](../reports/E7-T03_OPTIONAL_GOAL_ASSOCIATION_REPORT.md)；E7-T04 已完成并归档，可选节奏解释、接续点、草稿升级与原子保存 / 恢复的证据见 [E7-T04 报告](../reports/E7-T04_OPTIONAL_RHYTHM_REPORT.md)；E7-T05 已完成并归档，时间轴目标 / 节奏 / 接续点回看、同源更正及只读刷新重试的证据见 [E7-T05 报告](../reports/E7-T05_TIMELINE_GOAL_RHYTHM_REPORT.md)；E7-T06 已完成并归档，真实文件库完整应用闭环、原子失败与提交后重开恢复的证据见 [E7-T06 报告](../reports/E7-T06_GOAL_RHYTHM_CLOSURE_REPORT.md)；E7-T07 已完成并归档，真实 Android 强停重开 / Web 同页刷新、旧草稿升级和归属 / 解释恢复的证据见 [E7-T07 报告](../reports/E7-T07_GOAL_RHYTHM_PLATFORM_REPORT.md)；E7-T08 已完成并归档，可选原因 / 恢复细节、草稿 v5 升级、真实库写入 / 恢复与受影响两平台草稿恢复的证据见 [E7-T08 报告](../reports/E7-T08_OPTIONAL_RHYTHM_DETAILS_REPORT.md)；Epic 7 核心及独立 Should Have 已交付，E7-T08 不改变原核心依赖。

## Epic 8 — Statistics / Summaries

**Goal:** 呈现帮助理解一天和目标时间的基础描述性摘要。

**Why now:** 已接入睡眠、普通事实和节奏，能验证不同口径不会混算，并为复盘提供上下文。

**Dependencies:** Epic 3、5、6、7；Q-010、Q-014、Q-020、Q-021。

**Deliverables:** 睡眠背景、账本覆盖、Unknown 子集、目标相关 / progress / stuck 与 recovery 的基础展示；适用的近似和缺失数据表示。

**Acceptance criteria:** 展示与同一事实快照的投影一致，成功写入后刷新；无 annotation 的目标时间不自动当作 progress，相关总时长不冒充推进时长；Unknown 不被加两遍。缺失记录不推断零活动，睡眠与日内目标节奏只作描述；不把派生数字写回 DailyReview 或统计表。

**Explicit non-goals:** 评分、排行、效率百分比、因果睡眠结论、长期分析系统或新统计存储层。

具体任务见 [TASKS / Epic 8](../../TASKS.md#epic-8--statistics--summaries)：E8-T01–E8-T06 覆盖一致读取、覆盖 / Unknown、完整睡眠、目标四项与全局节奏、重算集成及两平台验证。复用 Epic 3 的投影与格式映射，不建立第二套统计算法或事实源。局部任务可按各自前置先行，完整 Epic 依赖保持不变。E8-T01–E8-T06 已完成，实际交付及验证见 [E8-T01 报告](../reports/E8-T01_SUMMARY_CONTEXT_REPORT.md)、[E8-T02 报告](../reports/E8-T02_COVERAGE_SUMMARY_REPORT.md)、[E8-T03 报告](../reports/E8-T03_SLEEP_SUMMARY_REPORT.md)、[E8-T04 报告](../reports/E8-T04_GOAL_RHYTHM_SUMMARY_REPORT.md)、[E8-T05 报告](../reports/E8-T05_SUMMARY_RECALCULATION_REPORT.md)、[E8-T06 报告](../reports/E8-T06_SUMMARY_PLATFORM_REPORT.md)。Epic 3、5、6、7 已完成，Epic 8 的一致快照、独立近似 / 缺失表达、提交后重算、无草稿 / 复盘数值写回及 Android / Web 实际生命周期验收已逐项满足；Epic 8 核心验收完成，不启动 Epic 9。

## Epic 9 — Daily Review

**Goal:** 将对一天的解释收束为一次可接续的下一步。

**Why now:** 事实、归属和基础摘要已可用，复盘无需自行维护另一套统计。

**Dependencies:** Epic 2、7、8；Q-013 保存 / 更正合同；日期和文本合同已确定。

**Deliverables:** 可选 summary / reflection、一个 TomorrowFirstStep、可选 Goal 关联；按日保存和读取；按批准合同处理已有日期及历史复盘。

**Acceptance criteria:** 同日唯一约束验证通过；下一步意向日期按 Q-001 固定为 review.date 的下一自然日并派生，不单独存储；不能取系统今天或用固定 24 小时代替自然日运算；不要求给每个 Goal 写计划。continuationHint 与 TomorrowFirstStep 分工清楚；复盘不存派生时长，事实更正不会未经授权重写用户反思。

**Explicit non-goals:** 独立任务管理、强制每日打卡、结构化复盘字段扩张、自动评价反思。

具体任务见 [TASKS / Epic 9](../../TASKS.md#epic-9--daily-review)：E9-T01–E9-T09 覆盖按日读取、独立草稿、表单、新建、更正日期、删除、回看路由、应用及两平台恢复验证。正式提交失败与已提交后的草稿清理 / 刷新失败分别处理，避免重复提交。局部任务可按各自前置先行，完整 Epic 依赖保持不变。E9-T01 已完成，按日复盘读取、历史日期、旧响应隔离、CivilDate / 下一自然日展示和复用事实上下文的依据见 [E9-T01 报告](../reports/E9-T01_REVIEW_CONTEXT_REPORT.md)。E9-T02 已完成，独立复盘草稿存储、日期 / 编辑身份隔离、原始输入保留、失败回滚及 app 生命周期装配的依据见 [E9-T02 报告](../reports/E9-T02_REVIEW_DRAFT_STORE_REPORT.md)。E9-T03 已完成，复盘表单、原始输入恢复、串行自动保留 / 离页等待、失败重试、当前草稿放弃和可选 Goal 读取的依据见 [E9-T03 报告](../reports/E9-T03_REVIEW_FORM_REPORT.md)。E9-T04 已完成，新建提交、当前日期 / Goal 约束、正式失败保留输入、提交后清草稿 / 重读失败区分与只重试收尾的依据见 [E9-T04 报告](../reports/E9-T04_REVIEW_SUBMISSION_REPORT.md)。E9-T05 已完成，按源 ID 更正、日期迁移与唯一性、归档 Goal 保留 / 新关联校验、缺失源拒绝重建及提交后只重试收尾的依据见 [E9-T05 报告](../reports/E9-T05_REVIEW_CORRECTION_REPORT.md)。E9-T06 已完成，明确按源 ID 删除、正式表 / 草稿隔离、幂等及失败保留、删除后仅重试清理 / 重读和返回日期一致性的依据见 [E9-T06 报告](../reports/E9-T06_REVIEW_DELETION_REPORT.md)。E9-T07 已完成，日账本 / 摘要的所选日期复盘入口、已有行动读回、改日期 / 删除后的入口一致性、返回重读及事实变化与复盘文字独立的依据见 [E9-T07 报告](../reports/E9-T07_REVIEW_ROUTE_REPORT.md)。E9-T08 已完成，真实文件库完整字段闭环、竞争唯一 / 过期编辑、提交后双故障与完整重开恢复、无重复写入及核心验收对照的依据见 [E9-T08 报告](../reports/E9-T08_REVIEW_CLOSURE_REPORT.md)。E9-T09 已完成，Android 实际强停重开 / Web 同源刷新后的新建、编辑 / 改日期草稿恢复、正式冲突失败保留、成功 / 放弃清理及保存 / 更正 / 删除读回依据见 [E9-T09 报告](../reports/E9-T09_REVIEW_PLATFORM_REPORT.md)。Epic 2、7、8 前置齐备，E9-T01–E9-T09 已逐项交付，Epic 9 核心验收及两平台生命周期门槛完成；不表示 Epic 10 或全 MVP 发布验收完成，不自动细化或执行后续工作包。

## Epic 10 — Polish / Reliability

**Goal:** 验证首发平台上的完整 MVP 闭环与关键失败路径。

**Why now:** 各入口已接入，才能发现跨流程的一致性和记录成本问题。

**Dependencies:** Epic 4、5、6、7、8、9；Q-022 已确定的 Android、Web 平台验证范围，以及 Must Have 涉及的其他产品合同均已明确。

**Deliverables:** MVP_SCOPE 闭环场景验证、重启读回 / 失败反馈 / 冲突写入 / 跨日 / 近似 / 空数据检查，以及阻碍核心输入和理解的问题修复。

**Acceptance criteria:** Must Have 均有可复现验证，相关格式化、静态分析和测试通过；Android 与 Web 的数据保存与重启读回检查分别通过。批准的更正操作不会留下部分写入或陈旧摘要；没有域外功能、派生数据来源或隐藏产品默认值。未交付 Should Have 如实记录，不将其包装成 Must Have 失败，也不把未决 Must Have 当完成。

**Explicit non-goals:** 扩张 MVP、支持未批准的平台、补齐未来功能、建立巨大测试 / 设计框架。

## 验证与完成纪律

可靠性从 Epic 1 开始逐层验证：纯领域规则与计算用确定输入测试；持久化用真实约束、事务及失败路径验证；记录入口验证输入成本、可选性和保存反馈；最终再覆盖整条闭环。Epic 10 不承担前面各 Epic 应有的所有测试。

每个 Epic 的交付必须能追溯到 MVP 范围、领域规则和已解决的问题。接口可以按实际使用增量形成，不一次生成通用抽象。Should Have 独立标注，Later 与 Explicitly Out of Scope 不转成隐含任务。近期任务见 [TASKS](../../TASKS.md)，后续 Epic 在进入相应工作前再细化；读取计划不构成执行授权。
