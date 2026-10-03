# 已完成任务归档

本文件保存从 [TASKS](../../TASKS.md) 移出的完整任务定义。归档整理日期：2026-10-03；范围为 Epic 0–4、E5-T01–E5-T09 、E6-T01–E6-T06 、E7-T01–E7-T08 、E8-T01–E8-T06 与 E9-T01–E9-T09，共 77 个任务。当前待办及完成索引仍以 TASKS 为入口。

原有任务正文、依赖、范围、验收、验证和已记录状态均保留，仅调整相对链接。早期正文未逐项标记 Status：Epic 0 / 1 的完成依据为 [负责人确认记录](../reports/EPIC_0_1_COMPLETION.md)，Epic 2 / 3 的完成依据为 TASKS 索引所列任务报告；不补造历史验证结果。归档不改变领域合同，也不构成重新执行任务的授权。

## Source documents 索引

每个任务列出的简称指向下表完整文件及其指定章节；执行单个任务时应展开读取，不能只依赖本文件的摘要。所有任务共同必读 SOT、OQ、MVP、PLAN 与 AGENTS，局部来源列在任务内。

| 简称 | 文件 |
| --- | --- |
| SOT | [time-ledger-domain-model-v4-proposal.md](../../time-ledger-domain-model-v4-proposal.md) |
| MODEL | [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md) |
| RULES | [DOMAIN_RULES](../domain/DOMAIN_RULES.md) |
| STATES | [DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md) |
| DERIVED | [DERIVED_MODELS](../domain/DERIVED_MODELS.md) |
| OQ | [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md) |
| APP | [APP_ARCHITECTURE](../architecture/APP_ARCHITECTURE.md) |
| DATA | [DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md) |
| MVP | [MVP_SCOPE](MVP_SCOPE.md) |
| PLAN | [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) |

## 验证约定与工程边界

以下划分与文件归属是 **Engineering Recommendation**，不是新的产品决定。Scope 的目录是允许影响的职责边界，执行时先定位实际文件；不要求建立所有目录。任务若确需超出范围，先说明具体影响，不能顺手扩大。

代码任务共用验证：对改动 Dart 文件运行 formatter 及格式检查，运行 `flutter analyze` 与本任务涉及的测试（通常 `flutter test <相关测试路径>`）。实际命令以 E0-T01 核实的工程环境为准。保存命令、退出结果及失败原因；环境不足不是通过。仅枚举声明等不需要镜像实现的机械测试，纯基线任务不为产生测试数量而修改代码。

Epic 完成门槛继承 PLAN。允许先交付不受问题影响的局部任务：例如 E1-T01 只依赖 E0-T01，不等待首发平台；这不表示 Epic 0 或 1 已整体验收。完整 Epic 2 仍要求 Epic 0 与 1 完成。各任务的 Q 清单是本任务门槛，不复制问题答案；如来源新增相关门槛，应重新检查，不能以列表未列出为由忽略。

## Epic 0 — Project Foundation

### E0-T01 — 核查现有工程与验证基线

**ID:** E0-T01

**Title:** 核查现有工程与验证基线

**Goal:** 确认现有最小工程的真实状态和可复用验证命令。

**Depends on:** 无；Q-022 不阻塞本机基线，但不授权平台支持承诺。

**Source documents:** PLAN / Epic 0；APP / 当前状态；README.md、pubspec.yaml、lib/main.dart。

**Scope:** 只读检查入口、已有测试、SDK 与运行环境；执行可用的格式检查、分析与测试，记录缺失项和基线结果于任务报告。

**Out of scope:** 修改代码、安装包、重建工程、添加功能、代选首发平台。

**Acceptance criteria:** 列出实际入口和已有测试；区分命令通过、失败与未执行；明确可用验证命令，不把没有测试说成测试通过。

**Validation:** 用检查模式验证格式；仅使用不安装 / 解析新依赖的现有分析与测试路径，若缓存、测试或工具缺失则明确报告。源文件、配置和 lockfile 不得改写；工具产生的临时缓存或构建产物须与既有改动区分。核查报告完整可交付本任务，报告中的失败不等于基线通过，也不授权修复。

### E0-T02 — 建立最小 app 入口边界

**ID:** E0-T02

**Title:** 建立最小 app 入口边界

**Goal:** 让现有启动入口按 APP 的职责组织，保持现有可观察行为。

**Depends on:** E0-T01。

**Source documents:** APP / 按功能组织、dependency direction；PLAN / Epic 0。

**Scope:** 仅 lib/main.dart、实际需要的 lib/app 文件及相关启动测试；按需提取启动组装，不预建空 feature 或 core。

**Out of scope:** 导航系统、功能页面、状态管理包、全套目录骨架。

**Acceptance criteria:** 入口与 app 职责可辨，原有启动行为保持；没有虚构业务对象或空层级。

**Validation:** 共用代码验证；核查入口 diff 与启动行为，已有启动测试若受影响则调整，不为文件搬动新增机械测试。

### E0-T03 — 验证已确认首发平台的启动基线

**ID:** E0-T03

**Title:** 验证已确认首发平台的启动基线

**Goal:** 将平台承诺和可运行证据对应起来。

**Depends on:** E0-T01、E0-T02；Q-022 已确认首发平台为 Android 和 Web。

**Source documents:** PLAN / Epic 0；APP / 平台边界；OQ / Q-022。

**Scope:** 在 Android 与 Web 验证现有启动工程；仅修复启动所需的最小平台配置并记录实际运行证据。

**Out of scope:** 新增业务页面、支持清单外平台、数据库或状态管理依赖。

**Acceptance criteria:** Android 与 Web 分别有启动验证结果；不能运行的平台明确阻塞；不把存在目录视为支持，也不扩展到其他平台。

**Validation:** 按平台执行构建 / 启动检查；有代码变更时执行共用代码验证；核对无新增产品功能。

## Epic 1 — Domain Foundation

### E1-T01 — 定义已确定的领域枚举

**ID:** E1-T01

**Title:** 定义已确定的领域枚举

**Goal:** 以纯 Dart 表达独立的精度、已知性、节奏和睡眠类型。

**Depends on:** E0-T01；可独立于 E0-T03 单独交付。

**Source documents:** MODEL / 领域枚举；RULES / TB-002、TB-004、RH-002、SL-003；APP / domain。

**Scope:** ledger/domain 中 TimePrecision、BlockKnowledgeState、RhythmState、SleepType 的声明与语义注释。

**Out of scope:** 枚举持久化编码、默认值、状态转换、原因 / 恢复细节候选枚举、自动分类。

**Acceptance criteria:** 值域与 MODEL 一致；无 gap、neutral、useless、running 等值；不依赖 Flutter 或驱动。

**Validation:** 共用代码验证；直接核对枚举值和 import；无行为逻辑时不额外写镜像枚举清单的测试。

### E1-T02 — 落实时间、日期与元数据基础合同

**ID:** E1-T02

**Title:** 落实时间、日期与元数据基础合同

**Goal:** 为事实和复盘提供一致的时间值及身份 / 时间戳输入边界。

**Depends on:** E0-T02、E1-T01；时间、日期与元数据合同已由 Q-008、Q-017、Q-018 确定。

**Source documents:** MODEL / 字段语义；DATA / 通用类型、Timestamps；APP / core 边界；OQ 对应条目。

**Scope:** 确需共享的 core/time 纯值与函数、身份和元数据的明确输入合同及测试；简单类型足够时不另建包装层。

**Out of scope:** 数据库编码、全局当前时间、账本时区覆盖设置、固定 1440 分钟、日账本窗口政策、通用 base entity。

**Acceptance criteria:** 时间点与自然日期不会混同；采用明确的分辨率和端点合同；当前时间从调用方传入；身份与元数据策略不靠构造器猜测。

**Validation:** 共用代码验证；日期合法性、选定端点 / 精度合同及元数据行为的确定输入测试；不依赖机器时钟。

### E1-T03 — 实现 TimeBlock 与单对象校验

**ID:** E1-T03

**Title:** 实现 TimeBlock 与单对象校验

**Goal:** 表达普通时间事实及其已确定合法性。

**Depends on:** E1-T01、E1-T02；Q-002、Q-004、Q-015、Q-016 的字段及校验合同已确定。

**Source documents:** MODEL / TimeBlock；RULES / MODEL-001、TB-001–TB-009；STATES / TimeBlock。

**Scope:** ledger/domain 的 TimeBlock、构造 / 校验及对应测试；包含获准的首版字段。

**Out of scope:** known ↔ unknown 操作、数据库、Gap、自动 annotation、UI。

**Acceptance criteria:** 正区间、known 非空标题、unknown 可空标题得到验证；两端精度独立，可不关联 Goal / annotation；不强制 unknown.title 只能 null。

**Validation:** 共用代码验证；零 / 反向区间、known null / 空串、unknown 无标题、混合精度和可选字段测试；其他文字与时间边界按已确认答案验证。

### E1-T04 — 实现独立 SleepSession 与校验

**ID:** E1-T04

**Title:** 实现独立 SleepSession 与校验

**Goal:** 保留完整睡眠事实及其起止精度。

**Depends on:** E1-T01、E1-T02；Q-015、Q-016 对睡眠的合同已确定。

**Source documents:** MODEL / SleepSession；RULES / SL-001–SL-005；STATES / SleepSession。

**Scope:** ledger/domain 的 SleepSession、校验与测试。

**Out of scope:** 昨晚睡眠选择、每日首次提醒、睡眠质量、recovery 关联、日切片算法。

**Acceptance criteria:** 跨日事实不拆分；mainSleep / nap 与精度分离；区间校验按 Q-016 的答案实现，不从例子擅推上下限。

**Validation:** 共用代码验证；跨日、独立精度、可选 note 和批准的无效区间样例测试。

### E1-T05 — 实现 Goal 的字段与校验

**ID:** E1-T05

**Title:** 实现 Goal 的字段与校验

**Goal:** 提供简单时间归属对象，不把目标扩展为项目。

**Depends on:** E1-T02；Q-006、Q-015、Q-018、Q-019 已确定。

**Source documents:** MODEL / Goal；RULES / GO-001、GO-002；STATES / Goal。

**Scope:** goals/domain 的对象、单对象校验、名称比较规则（若确认需要）及测试。

**Out of scope:** 归档 / 恢复执行、跨记录名称查询、关联记录删除、任务树和进度字段。

**Acceptance criteria:** 字段与可空性一致，状态仅 active / archived；初始状态和 archivedAt 条件有确定依据。按 Q-019 允许同名，创建和改名不拒绝重名，不增加名称唯一约束。

**Validation:** 共用代码验证；字段及确定的状态 / 文本边界测试，确认无数据库或 UI 依赖。

### E1-T06 — 实现 RhythmAnnotation 与关联校验

**ID:** E1-T06

**Title:** 实现 RhythmAnnotation 与关联校验

**Goal:** 将可选解释独立于 TimeBlock，并落实确认后的组合约束。

**Depends on:** E1-T03、E1-T05；Q-004、Q-005、Q-007、Q-015 已确定。

**Source documents:** MODEL / RhythmAnnotation；RULES / RH-001–RH-008；STATES / RhythmAnnotation。

**Scope:** ledger/domain 的 annotation、可选细节的正式类型、关联组合校验及测试；以明确输入验证关联，不执行存取。

**Out of scope:** 状态切换操作、数据库唯一约束实现、自动判定推进、睡眠 annotation。

**Acceptance criteria:** 原因与恢复细节均可省略；没有 neutral；解释不另有时间范围或 goalId；组合校验按答案而不是示例猜测。

**Validation:** 共用代码验证；可选细节全空、合法 / 非法组合、接续点适用范围测试；最多一份的持久化保障留 E2。

### E1-T07 — 实现 DailyReview 与 TomorrowFirstStep

**ID:** E1-T07

**Title:** 实现 DailyReview 与 TomorrowFirstStep

**Goal:** 表达每日解释和单一下一步意向。

**Depends on:** E1-T02、E1-T05；Q-001、Q-006、Q-015 的合同已确定。

**Source documents:** MODEL / DailyReview、TomorrowFirstStep；RULES / DR-001–DR-004；STATES / DailyReview。

**Scope:** review/domain 的复盘和值对象、日期 / 文字校验及测试。

**Out of scope:** 按日唯一查询、存储、任务状态、派生分钟数、所有 Goal 的明日计划。

**Acceptance criteria:** summary / reflection 可空；下一步存在且目标可选；intendedDate 有明确语义，不自行默认次日。

**Validation:** 共用代码验证；可选文字与目标、必需下一步、获准日期边界样例测试；检查无聚合字段。

### E1-T08 — 实现主要时间事实的纯冲突判定

**ID:** E1-T08

**Title:** 实现主要时间事实的纯冲突判定

**Goal:** 为两类事实共用不重叠判定。

**Depends on:** E1-T03、E1-T04；Q-017 端点、分辨率与舍入合同已确定。

**Source documents:** RULES / LEDGER-004；DERIVED / 公共输入；DATA / 事务与重叠。

**Scope:** ledger/domain 的纯冲突函数及测试，接收候选与已有区间；更新排除对象须以明确的类型 / 身份表示。

**Out of scope:** 查库、自动截断 / 合并 / 覆盖、用户冲突修正流程、Gap 算法。

**Acceptance criteria:** 覆盖 TB/TB、Sleep/Sleep、TB/Sleep；approximate 不豁免冲突；相接按确定合同处理；不误排除另一类型的同 id 事实。

**Validation:** 共用代码验证；包含、部分相交、相接、分离、跨日和两类同 id 的样例。

### E1-T09 — 实现获准 Goal 生命周期合同

**ID:** E1-T09

**Title:** 实现获准 Goal 生命周期合同

**Goal:** 落实目标归档、恢复与重复请求的纯领域语义。

**Depends on:** E1-T05；Q-006、Q-018 已明确。

**Source documents:** STATES / Goal；RULES / GO；OQ / Q-006、Q-018。

**Scope:** goals/domain 的已批准状态操作与测试；明确引用效果合同供 data 使用，不执行查询。

**Out of scope:** 跨表写入、UI、未批准删除、通用状态机。

**Acceptance criteria:** 批准转换的前置条件、archivedAt 和重复请求行为可验证；未开放行为没有可调用实现。

**Validation:** 共用代码验证；逐项测试已批准转换及拒绝样例，检查不引入 completed 等状态。

### E1-T10 — 实现获准 TimeBlock 更正合同

**ID:** E1-T10

**Title:** 实现获准 TimeBlock 更正合同

**Goal:** 明确认知更正与字段处理，保持事实合法。

**Depends on:** E1-T03、E1-T06、E1-T08；Q-003、Q-013 已明确后执行。

**Source documents:** STATES / TimeBlock 字段矩阵；RULES / TB；OQ 对应条目。

**Scope:** ledger/domain 的已批准更正纯操作与测试；字段清理和 annotation 关系结果显式表达。

**Out of scope:** 数据库、自动恢复记忆、擅自增删关联、任意 CRUD。

**Acceptance criteria:** known / unknown 转换仅按批准合同提供；标题、目标、解释、区间、精度及元数据处理有明确依据。

**Validation:** 共用代码验证；各批准方向和受限方向、保留 / 清理字段、结果校验与重复请求测试。

### E1-T11 — 实现获准 annotation 编辑与移除合同

**ID:** E1-T11

**Title:** 实现获准 annotation 编辑与移除合同

**Goal:** 保证解释变化不改写时间事实。

**Depends on:** E1-T06；Q-005、Q-013 已明确后执行。

**Source documents:** STATES / RhythmAnnotation；RULES / RH-001–RH-008。

**Scope:** ledger/domain 的 add / edit / remove 纯关系合同与针对性测试，限已批准操作。

**Out of scope:** 独立写库、neutral、自动节奏链、历史版本机制。

**Acceptance criteria:** 字段处理和重复 / 缺失对象行为明确；移除只改变解释关系，事实保持；编辑后最多一份解释。

**Validation:** 共用代码验证；批准状态变化、可选字段处理、重复 add 与缺失 edit / remove 等已确认结果测试。

### E1-T12 — 实现获准睡眠与复盘更正合同

**ID:** E1-T12

**Title:** 实现获准睡眠与复盘更正合同

**Goal:** 落实无生命周期状态的事实更正边界。

**Depends on:** E1-T04、E1-T07、E1-T08；Q-013 已明确，日期合同沿用已确认的 Q-001，Q-016、Q-018 已明确。

**Source documents:** STATES / SleepSession、DailyReview；RULES / SL、DR。

**Scope:** 对应 domain 的已批准更正纯操作及测试；两者保持独立，拒绝范围外字段更改。

**Out of scope:** 跨表删除、UI、draft / completed 状态、自动重写复盘。

**Acceptance criteria:** 睡眠更正保留完整事实，复盘只更改批准字段；事实变化不自动改写反思；身份和元数据遵循合同。

**Validation:** 共用代码验证；批准字段、日期 / 时间边界及元数据结果测试，无新的阶段式状态。

## Epic 2 — Persistence Foundation

### E2-T01 — 核验持久化驱动选择

**ID:** E2-T01

**Title:** 核验持久化驱动选择

**Goal:** 为 Android 与 Web 选出满足单库事务与测试需求的最小驱动。

**Depends on:** Epic 0 完成；Q-022 已确定首发平台为 Android 和 Web。可作 Epic 2 的只读准备，不提前实现存储。

**Source documents:** APP / repository 与持久化；DATA / 持久化、事务；PLAN / Epic 2。

**Scope:** 查阅候选驱动官方资料，分别核验 Android、Web 的事务、外键、本地持久化和测试支持；给出工程选型依据及最小依赖清单，记录于任务报告。

**Out of scope:** 安装包、改 pubspec、实现 schema、自动选择未批准平台。

**Acceptance criteria:** 明确选择建议及证据、限制；区分已批准采用的方案与仅推荐项，不把推荐当产品要求。

**Validation:** 核对官方来源及 Android、Web 支持；检查两个平台满足原子写入 / 一致读取的需求；仓库无实现改动。

### E2-T02 — 接入单库连接与测试环境

**ID:** E2-T02

**Title:** 接入单库连接与测试环境

**Goal:** 提供可打开、关闭与隔离测试的本地存储基础。

**Depends on:** E2-T01；Epic 0、1 完成；选型已明确采用且当前任务授权最小依赖接入。

**Source documents:** APP / app 组装、core/persistence；DATA / 外键启用、事务。

**Scope:** 允许仅接入选定持久化依赖、必要 pubspec / lockfile 变化、core/persistence 连接、app 生命周期组装及存储测试夹具。

**Out of scope:** 业务 schema、通用 UnitOfWork、选定最小依赖之外的新包、远程服务、功能 UI。

**Acceptance criteria:** 连接按生命周期释放；若采用 SQLite，逐连接启用并验证外键；测试库隔离且不会接触用户正式数据。

**Validation:** 共用代码验证；真实驱动打开 / 关闭、外键启用、隔离和失败反馈测试；分别在 Android 与 Web 验证驱动可运行。

### E2-T03 — 建立五表首版 schema 与约束

**ID:** E2-T03

**Title:** 建立五表首版 schema 与约束

**Goal:** 将已定稿的数据规范转为正式首版建表定义。

**Depends on:** E2-T02；DATA / Schema 定稿清单全部相关问题已有答案并更新规范，遵循已确定的 Q-005、Q-007、Q-013、Q-019；Q-022 的平台核验另按 E2-T01 执行。

**Source documents:** DATA / 五表、Foreign keys、Indexes、三类约束；RULES 对应约束。

**Scope:** feature/data 的建表定义及 core/persistence 必要组装；五表约束和最小索引的真实数据库测试。

**Out of scope:** Day / Gap / 统计表、默认级联、用占位类型掩盖 recoveryQuality、分类系统。

**Acceptance criteria:** 五表列、nullable、外键动作及索引与定稿规范一致；known 标题 CHECK 正确处理 NULL；annotation FK / UNIQUE 和 review_date UNIQUE 生效。

**Validation:** 共用代码验证；真实库验证合法插入、缺字段、非法枚举、known 空标题、孤立 / 重复 annotation、重复日期及批准的 FK 动作。

### E2-T04 — 实现 Goal 存取边界

**ID:** E2-T04

**Title:** 实现 Goal 存取边界

**Goal:** 贯通目标读取和已批准目标操作。

**Depends on:** E2-T03、E1-T05、E1-T09。

**Source documents:** APP / GoalRepository；DATA / goals 与引用行为；RULES / GO；STATES / Goal。

**Scope:** goals/domain 的小型接口、goals/data 映射和实现、对应真实存储测试；仅实现已批准操作。

**Out of scope:** 目标 UI、通用 repository、任务管理；不为方便测试绕过引用保护。

**Acceptance criteria:** 字段读回不丢失；名称与状态规则执行一致；已批准归档 / 删除行为保护既有引用并原子完成，不能误删时间事实。

**Validation:** 共用代码验证；读写往返、名称 / 状态规则、引用存在时的操作及回滚测试。

### E2-T05 — 实现账本一致读取与行映射

**ID:** E2-T05

**Title:** 实现账本一致读取与行映射

**Goal:** 取得投影需要的完整事实及其解释。

**Depends on:** E2-T03；E1-T03、E1-T04、E1-T06。

**Source documents:** APP / LedgerRepository；DATA / 查询、枚举、读取一致性；DERIVED / Inputs。

**Scope:** ledger/domain 的必要读取合同，ledger/data 中两类事实及 annotation 映射、相交窗口查询和测试。

**Out of scope:** 领域切片、昨晚选择策略、写入旁路、持久化 DayLedgerView。

**Acceptance criteria:** 跨日开始于窗口外的相交事实被读到且保持完整起止；多表读取同一视图；精度和可选字段保留；未知存储代码报告错误而非降级为 unknown。

**Validation:** 共用代码验证；真实库跨日 / 窗口外 / 空集合、独立精度、非法编码样例及一致读取测试；合法夹具通过已定 schema 建立。

### E2-T06 — 实现受控账本原子写入

**ID:** E2-T06

**Title:** 实现受控账本原子写入

**Goal:** 在同一事务中保障事实与解释保存及跨表不重叠。

**Depends on:** E2-T04、E2-T05；E1-T08、E1-T10、E1-T11、E1-T12；Q-011 的保存结果合同已明确。

**Source documents:** APP / 写入流程；DATA / 事务、重叠与读取一致性；RULES / RH-001、LEDGER-004。

**Scope:** LedgerRepository 的已批准写合同、ledger/data 事务实现及测试；创建和获准更正 / 移除均经过同一受控边界。

**Out of scope:** UI 冲突修正方案、自动覆盖、独立 annotation 旁路、通用 upsert 决定保留或删除。

**Acceptance criteria:** 事务内读取两表并复核后写入；事实 / 解释组合操作按批准合同整体提交；失败全部回滚；跨表同 id 不误排除；不泄露连接给 UI。

**Validation:** 共用代码验证；真实库冲突、组合操作中途失败、并发冲突尝试、更新自排除、约束失败和重复操作测试；失败后检查原事实不变。

### E2-T07 — 实现按日复盘存取

**ID:** E2-T07

**Title:** 实现按日复盘存取

**Goal:** 可靠保存解释与下一步而不保存派生统计。

**Depends on:** E2-T03、E2-T04；E1-T07、E1-T12。

**Source documents:** APP / ReviewRepository；DATA / daily_reviews；RULES / DR；STATES / DailyReview。

**Scope:** review/domain 必要接口、review/data 映射与按日操作、真实数据库测试。

**Out of scope:** 复盘 UI、任务表、聚合数值快照、自动改写反思。

**Acceptance criteria:** 完整往返包括 intendedDate 的确认存储 / 派生合同；同日已有复盘的行为明确；可选目标及外键动作正确，保存失败不部分更新。

**Validation:** 共用代码验证；按日读取、可选文字 / 目标、历史日期、同日重复请求、约束失败与回滚测试。

### E2-T08 — 验证存储重开与完整持久化边界

**ID:** E2-T08

**Title:** 验证存储重开与完整持久化边界

**Goal:** 确认五类数据在实际关闭重开后仍可一致读回。

**Depends on:** E2-T04、E2-T05、E2-T06、E2-T07；Epic 0、1 完成。

**Source documents:** DATA / 明确不持久化、Timestamps；PLAN / Epic 2 验收；MVP / M-07。

**Scope:** 存储集成测试及本 Epic 范围内发现的缺陷修复；使用已批准操作构造五类数据并关闭重开。

**Out of scope:** UI、完整日投影、扩大依赖、把此任务当作前面任务免测理由。

**Acceptance criteria:** 读回事实、关联、复盘与元数据一致；没有 Gap / Day / aggregate 的持久化来源；Android 与 Web 的存储证据完整，剩余问题不得标成完成。

**Validation:** 在隔离的实际持久化文件或所选平台等效存储上重开验证，不能仅用内存 mock；共用代码验证并报告平台限制。

## Epic 3 — Ledger Projection Engine

本 Epic 只交付纯计算、结果合同及不依赖 Widget 的展示映射，不查库、不建设 UI 页面；不依赖 Epic 2。各项结果随算法一起实现近似传播和存在性，不留到最终集成补齐。自然日到绝对边界的设备适配在应用接入时落实（普通记录见 E4-T01），纯算法接收明确边界及当前时刻；Epic 5 可独立接入或复用已有适配，不以完成 Epic 4 为前提。

### E3-T01 — 实现对账窗口与派生时长基础合同

**ID:** E3-T01

**Title:** 实现对账窗口与派生时长基础合同

**Goal:** 明确历史日、今天和未来日的窗口及逐项时长表达。

**Depends on:** E1-T02；Q-008、Q-009、Q-014、Q-017、Q-021 已确定。

**Source documents:** DERIVED / 公共输入、对账窗口边界示例、摘要存在性；RULES / LEDGER；APP / 纯派生逻辑。

**Scope:** ledger/domain/projection 的窗口选择、时长结果及测试；复用 core/time 已有日期、毫秒与最终舍入函数。调用方显式提供日期关系、当地日边界和 now，具体参数类型按实际需要选择。

**Out of scope:** 读取设备时区或全局时钟、数据库、UI 文案组件、新时间依赖、固定 24 小时日长。

**Acceptance criteria:** 历史日取完整当地日，今天截止 now，未来日与今天零点可为空；按实际边界计算日长。结果分别表达实际毫秒、hasApproximation，摘要另保留 hasRecords；空参与集不引入近似。

**Validation:** 共用代码验证；历史 / 今天 / 未来、零点、23 / 25 小时显式日边界、空参与集与正时长舍入为零测试；纯函数不依赖运行机器时钟。

### E3-T02 — 实现事实切片与边界精度传播

**ID:** E3-T02

**Title:** 实现事实切片与边界精度传播

**Goal:** 将完整事实映射为窗口内贡献，保留可回到源事实的身份。

**Depends on:** E3-T01、E1-T03、E1-T04、E1-T06。

**Source documents:** DERIVED / segments、hasApproximation；RULES / SL、TB、LEDGER；Q-014、Q-017。

**Scope:** ledger/domain/projection 的两类事实切片、按时间组织结果和针对性测试；annotation 只附着对应 TimeBlock。

**Out of scope:** 存储切片、改写原事实、自动拆分事实、annotation 独立区间、重叠数据自动修复。

**Acceptance criteria:** 仅正时长交集产生切片，保留源类型 / id 与展示所需事实信息；被裁掉的近似边界不传播，恰等于窗口边界的事实精度仍保留；两端精度独立，原对象不变。

**Validation:** 共用代码验证；跨日睡眠 23:50–07:40 的两日贡献、窗口外 / 相接 / 跨 now、两类型同 id、裁掉与恰相等的近似边界、未排序输入的时间顺序测试。

### E3-T03 — 实现 Gap 与账本覆盖汇总

**ID:** E3-T03

**Title:** 实现 Gap 与账本覆盖汇总

**Goal:** 从全部主要事实计算未处理区间和覆盖时长。

**Depends on:** E3-T02。

**Source documents:** DERIVED / UnresolvedSpan、accountedDuration、unknownDuration、unresolvedDuration、同一窗口关系；RULES / LEDGER-001–LEDGER-005。

**Scope:** ledger/domain/projection 的覆盖、首尾及内部 Gap、三项时长与各自近似标志；输入沿用合法不重叠事实前提。

**Out of scope:** Gap 持久化、筛选目标后重算全局 Gap、自动 Unknown、完成率、非法重叠的容错政策。

**Acceptance criteria:** Unknown 和睡眠均已覆盖，annotation 不重复贡献；accounted + unresolved 等于同一窗口时长，unknown 是 accounted 子集。Gap 继承实际相邻边界精度；unresolved 的近似来自 Gap，不复制 accounted 标志。

**Validation:** 共用代码验证；空窗口 / 空事实、首尾缺口、连续相接、仅 Unknown / 睡眠、混合事实、全部覆盖但内部边界近似，以及增删 / 更正事实后重算的分区关系。

### E3-T04 — 实现节奏与目标时间汇总

**ID:** E3-T04

**Title:** 实现节奏与目标时间汇总

**Goal:** 提供全局节奏及按 Goal id 的四项时间细分。

**Depends on:** E3-T02、E1-T05、E1-T06。

**Source documents:** DERIVED / goalSummaries、progressDuration、stuckDuration、recoveryDuration；Q-019、Q-020、Q-021。

**Scope:** ledger/domain/projection 的全局节奏和目标摘要；显式接收所需 Goal 元数据，输出总时长、四项细分及逐项存在性 / 近似。

**Out of scope:** Goal UI、查库、推断节奏、把睡眠计作恢复、按名称合并、效率计算。

**Acceptance criteria:** 仅列窗口内有正贡献的 Goal，归档目标保留归档标记，同名不同 id 分开；progress / stuck / recovery / 无 annotation 合计等于目标总时长。无 Goal 记录参与全局；全局 recovery 不与目标 recovery 再相加，缺少可选细节不排除记录。

**Validation:** 共用代码验证；全未标记、全 recovery、无 Goal 的三种节奏、同名 / 归档目标、无记录目标、各细分近似与存在性独立、目标筛选不改变覆盖的样例。SOT §18 使用 DERIVED 校正后的 5h / 3h30m / 40m / 50m，不复制原算术错误。

### E3-T05 — 实现完整睡眠摘要与已记录判定

**ID:** E3-T05

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E3-T05 报告](../reports/E3-T05_SLEEP_SUMMARY_REPORT.md)。

**Title:** 实现完整睡眠摘要与已记录判定

**Goal:** 区分日窗口睡眠贡献和按醒来日期归属的整次睡眠。

**Depends on:** E3-T01、E3-T02、E1-T04。

**Source documents:** DERIVED / sleepSummary；RULES / SL；Q-008、Q-010、Q-014、Q-021。

**Scope:** ledger/domain/projection 的主睡眠 / 小睡选择与完整时长汇总，以及基于显式 now 的主睡眠已记录纯判定；输入允许包含 W 外完整记录。

**Out of scope:** 睡眠表单、提醒调度、数据查询、只取最长 / 最近一次、质量评分或恢复关联。

**Acceptance criteria:** 按当前设备时区的醒来日期选择全部记录，mainSleep / nap 分别列出原始起止并汇总，不计段间清醒。午夜醒来即使与 W 不相交仍入摘要；当天 endedAt ≤ now 的主睡眠才满足已记录判定。

**Validation:** 共用代码验证；多段主睡眠、小睡单列、白天主睡眠、午夜醒来、只有 nap / 未来结束主睡眠、无匹配记录、完整睡眠与日切片的时长及近似差异、显式时区日期变化。

### E3-T06 — 组装 DayLedgerView 并核验派生关系

**ID:** E3-T06

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E3-T06 报告](../reports/E3-T06_DAY_LEDGER_VIEW_REPORT.md)。

**Title:** 组装 DayLedgerView 并核验派生关系

**Goal:** 以单一纯入口组合全部派生结果，供后续功能复用。

**Depends on:** E3-T03、E3-T04、E3-T05；完整 Epic 3 验收要求 Epic 1 完成。

**Source documents:** DERIVED / DayLedgerView、可核对的关系与例子；MODEL / Derived Models；APP / projection。

**Scope:** ledger/domain/projection 的组合入口及组合样例测试；明确窗口事实、睡眠摘要候选和 Goal 元数据输入边界。

**Out of scope:** I/O、UI、持久化 Day / Gap / aggregate、不合法输入的隐式丢弃或合并。

**Acceptance criteria:** 所有概念输出可取得且复用已有算法；睡眠摘要不从切片反推，空未来窗口不妨碍独立睡眠摘要合同；同窗分区与目标四项关系成立，解释变更不改变覆盖，计算不修改输入事实。

**Validation:** 共用代码验证；DERIVED 手算与混合场景，覆盖跨日、Unknown、Gap、睡眠、同名归档 Goal、未标记与混合精度；改变 now / 窗口重投影，检查输入不变及 domain 无 Flutter / 驱动 / 全局时钟依赖。

### E3-T07 — 实现摘要展示语义的纯映射

**ID:** E3-T07

**Status:** COMPLETE（2026-09-28）；实际交付、验证及 Epic 3 验收核对见 [E3-T07 报告](../reports/E3-T07_SUMMARY_FORMATTING_REPORT.md)。

**Title:** 实现摘要展示语义的纯映射

**Goal:** 让缺失记录、微小时长和近似信息在后续 UI 中一致表达。

**Depends on:** E3-T06。

**Source documents:** DERIVED / 摘要存在性与分钟展示；RULES / 摘要缺失表达；Q-017、Q-021；APP / presentation。

**Scope:** ledger/presentation 中不依赖 Widget 的格式化函数及测试；复用最终汇总舍入，接受投影结果，不查询或重新计算事实。

**Out of scope:** 统计页面、设计系统、国际化框架接入、domain 内硬编码 UI 文案、重复时长算法。

**Acceptance criteria:** 主睡眠 / 小睡缺失、空目标列表、缺少节奏项分别采用已定文案；正时长舍入为零显示“少于 1 分钟”，近似时显示“约少于 1 分钟”；Gap 的零表示无缺口，不套活动缺失文案。

**Validation:** 共用代码验证；缺失与有记录的微小时长、四舍五入边界、多个小值先汇总后舍入、各项独立近似提示；核对不会表达实际睡眠或推进为零。

## Epic 4 — Basic Recording

本 Epic 核心任务为 E4-T01–E4-T08；E4-T09 是独立 Should Have，不作为核心完成门槛。复用 Epic 2 的原子写入与 Epic 3 的纯计算，仅做普通记录所需最小入口、候选区间和保存结果展示；完整时间轴与具体 Gap 点击入口留 Epic 6，Goal / annotation 输入留 Epic 7。不新增依赖；若草稿存储确需新增包，先报告具体必要性及授权范围，不能借本任务改 pubspec。

### E4-T01 — 接通普通记录的日期上下文与投影读取

**ID:** E4-T01

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E4-T01 报告](../reports/E4-T01_RECORDING_LEDGER_READ_REPORT.md)。

**Title:** 接通普通记录的日期上下文与投影读取

**Goal:** 为时间建议及保存后刷新提供真实设备日期和正式事实。

**Depends on:** E2-T05、E3-T03、E3-T06；Q-008、Q-009、Q-017。

**Source documents:** APP / 纯派生逻辑与调用流程；DATA / 读取一致性；DERIVED / 公共输入。

**Scope:** ledger/application、必要 app 组装与设备时间适配；从当前设备时区解析当地零点 / 次日零点，显式注入 now；一致读取完整事实后调用 E3。

**Out of scope:** 完整时间轴、睡眠摘要查询接入、统计页面、把 UI 草稿纳入事实、重复投影算法。

**Acceptance criteria:** 历史 / 今天 / 未来窗口正确，不能用起点加固定 24 小时推算次日；加载失败与空账本区分。普通记录所用覆盖 / Gap 来自全部正式事实；完整睡眠摘要额外查询留 Epic 5/8，不把 readWindow 当作足够的摘要来源。

**Validation:** 共用代码验证；显式时间适配测试覆盖零点、时区变化及非 24 小时日；真实 repository 的读取→覆盖 / Gap 集成测试；确认当前已有 LedgerRepository.readWindow 的可复用边界。

### E4-T02 — 实现普通入口的时间建议分支

**ID:** E4-T02

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E4-T02 报告](../reports/E4-T02_TIME_SUGGESTION_REPORT.md)。

**Title:** 实现普通入口的时间建议分支

**Goal:** 把 Q-023 转为可测试的输入建议，不代替用户确认事实。

**Depends on:** E4-T01。

**Source documents:** RULES / 时间建议合同；MODEL / UI Models；Q-023；SOT §27–28。

**Scope:** ledger/application 或 presentation 的建议模型 / 纯选择函数及测试，明确返回直接建议、候选待选或手动输入；接受明确 Gap 的预填参数供 Epic 6 复用。

**Out of scope:** 完整 Gap 时间线、持久化建议、自动填满整天空白、自动 exact、自动保存。

**Acceptance criteria:** 明确 Gap 优先直接预填；普通入口未来日、无 Gap 或窗口完全无事实时手动填起止；今天有事实且有尾部 Gap 时直接建议；其他情况候选供确认，即使仅一个。新草稿两端 approximate，修改时间不自动改精度。

**Validation:** 共用代码验证；逐行覆盖 RULES 决策表，尤其今天全空与明确点击同一全日 Gap 的区别、历史单候选 / 多候选、未来、无 Gap、混合 Sleep / TimeBlock 及尾部截止 now。

### E4-T03 — 实现普通记录本机草稿存储

**ID:** E4-T03

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E4-T03 报告](../reports/E4-T03_RECORDING_DRAFT_STORE_REPORT.md)。

**Title:** 实现普通记录本机草稿存储

**Goal:** 保留未完成输入而不创建正式事实。

**Depends on:** E2-T02、E4-T02；Q-012、Q-022。

**Source documents:** MODEL / UI Models；DATA / 本机输入草稿；PLAN / 输入草稿共同交付合同。

**Scope:** ledger 中专用草稿输入模型、最小存取接口 / 实现及必要连接组装；先核验并复用已批准本机持久化能力，草稿与正式五表隔离。支持区分新建上下文与编辑对象身份。

**Out of scope:** 正式表新增 draft / payload、通用草稿框架、睡眠 / 复盘草稿实现、新依赖、云同步。

**Acceptance criteria:** 不完整标题 / 区间可恢复；保留输入、独立精度、入口上下文及编辑关联所需数据；存草稿不改变原记录，不参与查询覆盖或冲突。读取、写入和清除失败显式返回，不伪装成功。

**Validation:** 共用代码验证；真实草稿存储写入→关闭→重开读回及清除，正式五表前后不变；新建与编辑草稿不会串用；平台关闭 / 刷新端到端证据在 E4-T08 补齐，不能用内存存储冒充本机恢复。

### E4-T04 — 实现活动优先表单与草稿生命周期

**ID:** E4-T04

**Status:** COMPLETE（2026-09-28）；实际交付与验证见 [E4-T04 报告](../reports/E4-T04_RECORDING_FORM_REPORT.md)。

**Title:** 实现活动优先表单与草稿生命周期

**Goal:** 交付可恢复的普通活动 / Unknown 输入体验。

**Depends on:** E4-T02、E4-T03。

**Source documents:** SOT §7、§26–28；RULES / TB、LEDGER-010；MODEL / UI Models；Q-012、Q-015、Q-017、Q-023。

**Scope:** ledger/presentation 的记录表单、输入状态及最小 app 可达入口；活动输入优先、时间候选确认 / 手动分钟级编辑、独立精度、known / unknown 明确选择；接通自动草稿保存、恢复和主动放弃。

**Out of scope:** Goal / 分类 / annotation 选择、计时器、完整导航改造、备注便利入口、自动 Unknown。

**Acceptance criteria:** known 标题按领域文本合同校验，Unknown 不强制编造名称；所有建议可改，跨日期起止可表达，不限制批准的未来 / 历史正区间。离开不等于放弃，恢复不被新建议覆盖；无全局 draft 领域状态。

**Validation:** 共用代码验证与 widget 测试；无 Goal 可输入、无标题 Unknown、空白标题、混合精度、手动时间不改精度、草稿恢复 / 放弃 / 保存失败可见反馈；未完整输入也能保留，输入期间正式事实不变。

### E4-T05 — 接通正式新建保存、冲突反馈与刷新

**ID:** E4-T05

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E4-T05 报告](../reports/E4-T05_RECORDING_SUBMISSION_REPORT.md)。

**Title:** 接通正式新建保存、冲突反馈与刷新

**Goal:** 让用户确认的输入经过原子写入成为账本事实。

**Depends on:** E4-T04、E2-T06；Q-011、Q-012、Q-018。

**Source documents:** DATA / 事务与重叠；RULES / TB、LEDGER-004；APP / 失败处理；PLAN / Epic 4。

**Scope:** ledger/application 与 presentation 提交协调：生成 / 注入正式身份和 now，调用既有 createTimeBlock，成功后清草稿、重新读取并投影；必要 app 组装及测试。

**Out of scope:** SQL 放进 UI、用预检取代原子约束、自动覆盖 / 截断 / 拆分、目标与解释新建、完整统计页面。

**Acceptance criteria:** 失败保留输入和草稿，不显示保存成功；冲突显示相关记录供手动调整。成功提交后才反映正式记录，Unknown 计入 accounted。防止重复提交；区分正式提交失败、已提交但草稿清理 / 刷新失败，不能误导重试导致重复事实。

**Validation:** 共用代码验证；真实 repository 集成新建 known / unknown、TB / Sleep 冲突、保存时事实变化、失败保留草稿、成功读回与重算；controller / widget 验证反馈、重复点击及提交后清理 / 刷新失败分支。

### E4-T06 — 接通已有 TimeBlock 更正与删除

**ID:** E4-T06

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E4-T06 报告](../reports/E4-T06_TIME_BLOCK_CORRECTION_REPORT.md)。

**Title:** 接通已有 TimeBlock 更正与删除

**Goal:** 落实普通事实更正能力，保留关联语义。

**Depends on:** E4-T05、E1-T10、E2-T06；Q-003、Q-013、Q-018。

**Source documents:** STATES / TimeBlock 字段矩阵、通用更正删除；DATA / 原子写入；RULES / 更正与删除合同。

**Scope:** 普通编辑 / 删除入口、完整对象加载及最小所需 repository 读取扩展（若现有接口不足）、编辑草稿恢复；调用既有 update / delete，成功后重新读取投影。

**Out of scope:** Sleep / Review 编辑、Goal / annotation 编辑 UI、历史版本、自动删其他事实、完整时间轴。

**Acceptance criteria:** 按源事实身份编辑完整区间而非切片；更正不换 id，未变内容不更新元数据。known↔unknown 不自动清空 title / goal / note / category / annotation；未展示字段保留。删除 TimeBlock 原子删除解释且不改复盘；缺失编辑报不存在，重复删除幂等。

**Validation:** 共用代码验证；真实存储配合 widget / controller 验证双向更正、已有归档 Goal / annotation 字段保留、冲突回滚、未保存编辑原事实不变、删除后 Gap 重算；恢复编辑草稿面对已删除事实时不得重建。

### E4-T07 — 验证普通记录完整应用闭环

**ID:** E4-T07

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E4-T07 报告](../reports/E4-T07_BASIC_RECORDING_FLOW_REPORT.md)。

**Title:** 验证普通记录完整应用闭环

**Goal:** 核验入口、保存、更正和刷新在同一应用中协作。

**Depends on:** E4-T06、E3-T07。

**Source documents:** MVP / M-01、M-07；PLAN / Epic 4；RULES / 时间建议合同、LEDGER-010。

**Scope:** 普通记录范围的应用集成测试及必要修复；使用最小结果展示或读取验证投影，不建设完整时间轴。

**Out of scope:** Epic 5–9 UI、替代前序单元测试、扩大功能或依赖、宣布全 MVP 完成。

**Acceptance criteria:** 从真实入口建议 / 手填→活动或 Unknown→保存→读回投影→更正 / 删除可完成；存在睡眠的账本不被误作空白；非法与冲突输入可修正后重试；事实、草稿及近似信息在各层一致。

**Validation:** 共用代码验证；真实数据库场景结合交互测试，覆盖尾部建议、候选确认、全空手填、精度、Unknown、冲突重试、缺失编辑、删除及无 Goal / annotation 成功路径；已通过且无新风险的前序测试不机械重复。

### E4-T08 — 验证 Android 与 Web 的保存和草稿恢复

**ID:** E4-T08

**Status:** COMPLETE（2026-09-29）；实际平台步骤、结果与边界见 [E4-T08 报告](../reports/E4-T08_ANDROID_WEB_RECORDING_RECOVERY_REPORT.md)。

**Title:** 验证 Android 与 Web 的保存和草稿恢复

**Goal:** 为普通记录跨页面、跨启动及刷新恢复取得平台证据。

**Depends on:** E4-T07、E2-T08；完整 Epic 4 验收要求 Epic 2、3 完成；Q-012、Q-022。

**Source documents:** PLAN / 输入草稿共同交付合同、Epic 4；DATA / 本机输入草稿；MVP / 闭环验收。

**Scope:** 普通记录 Android / Web 隔离测试数据、平台集成验证及任务报告；必要的本 Epic 范围修复。

**Out of scope:** 只重开数据库代替关闭应用 / 网页刷新、仅 mock 平台证据、其他平台、睡眠 / 复盘草稿实现、发布部署。

**Acceptance criteria:** 两平台分别证明正式记录重启后可读；新建及编辑未保存输入离开后可恢复，Android 关闭再打开及 Web 实际刷新后仍可恢复。失败保留，成功 / 主动放弃后重启不恢复旧草稿；编辑时正式事实保持原样，恢复后提交重新校验当前冲突。

**Validation:** 共用代码验证；记录具体设备 / 浏览器、实际关闭 / 刷新步骤及结果。覆盖不完整输入、混合精度、编辑隔离、成功清除、主动放弃、失败后恢复和过期草稿冲突；平台缺失或失败逐项报告，未验证不标完成。

### E4-T09 — 提供普通记录可选备注入口（Should Have）

**ID:** E4-T09

**Status:** COMPLETE（2026-09-29）；实现、草稿升级及 Android / Web 补充验证见 [E4-T09 报告](../reports/E4-T09_OPTIONAL_TIME_BLOCK_NOTE_REPORT.md)。

**Title:** 提供普通记录可选备注入口（Should Have）

**Goal:** 以非必填的补充入口支持 TimeBlock.note。

**Depends on:** E4-T06；本项不阻塞 E4-T07 / E4-T08 或核心 Epic 4 验收。

**Source documents:** MVP / Should Have；MODEL / TimeBlock；RULES / TB；Q-012、Q-015。

**Scope:** 普通表单的可选 note 输入、草稿与正式保存衔接及相关测试；复用已存在字段和文本规则。

**Out of scope:** 新增字段、必填备注、睡眠备注入口、改动核心验收门槛。

**Acceptance criteria:** 备注可省略、修改、清空；内部换行保留，空白归一及长度按既有合同；草稿恢复包含备注，失败不丢失。

**Validation:** 共用代码验证；备注留空 / 多行 / 清空 / 长度边界、草稿恢复和正式读回；若在 E4-T08 后交付，补充受影响的平台恢复验证。

## Epic 5 — Sleep Recording

本 Epic 核心任务为 E5-T01–E5-T08；E5-T09 为独立 Should Have。完整依赖 Epic 2、3，不以 Epic 4 普通活动编辑器完成为前提；可以复用已存在的 app 时间适配和本机存储能力，但不为复用建立通用框架。睡眠仍归属 ledger，已有领域、投影和原子写入不重复实现。首次打开标记仅为本机交互状态，不是睡眠事实或已记录判定来源。不新增依赖；如确需新包，先报告必要性与授权范围。

### E5-T01 — 接通睡眠日期上下文与完整摘要读取

**ID:** E5-T01

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E5-T01 报告](../reports/E5-T01_SLEEP_LEDGER_READ_REPORT.md)。

**Title:** 接通睡眠日期上下文与完整摘要读取

**Goal:** 为睡眠入口同时取得日内贡献、完整睡眠和免打扰依据。

**Depends on:** E2-T05、E3-T05、E3-T06、E3-T07；Q-008、Q-009、Q-010、Q-014、Q-021。

**Source documents:** DATA / 查询与读取一致性；DERIVED / sleepSummary、公共输入；APP / 调用流程。

**Scope:** ledger/domain 的必要查询接口、ledger/data 查询、ledger/application 读取协调与 app 时间适配；按醒来日期查询完整睡眠，并与窗口事实在一致读取视图中组装。已有设备日期适配可复用，不依赖普通编辑器。

**Out of scope:** 睡眠表单、提醒调度、重写投影算法、统计页面、新依赖。

**Acceptance criteria:** 摘要查询包含当地零点醒来且与 W 不相交的记录；全部 mainSleep 与 nap 分开，不能只取最近或最长一条。设备时区、now 显式传入；历史 / 今天 / 未来窗口按合同，读取失败不同于无记录。

**Validation:** 共用代码验证；真实库覆盖午夜醒来、多段 / 白天主睡眠、小睡、未来结束、跨日及非 24 小时日；检查窗口查询与摘要候选一致性、完整时长和切片差异。

### E5-T02 — 实现睡眠本机草稿存储

**ID:** E5-T02

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E5-T02 报告](../reports/E5-T02_SLEEP_DRAFT_STORE_REPORT.md)。

**Title:** 实现睡眠本机草稿存储

**Goal:** 独立保留未完成睡眠输入及编辑上下文。

**Depends on:** E2-T02、E1-T04；Q-012、Q-022。

**Source documents:** MODEL / UI Models；DATA / 本机输入草稿；PLAN / 输入草稿共同交付合同。

**Scope:** ledger 中睡眠专用草稿输入模型、最小存取边界与本机实现，必要 app 组装；复用已批准持久化能力，区分新建上下文和编辑对象身份。

**Out of scope:** 正式表 draft 状态、通用草稿框架、普通记录 / 复盘草稿改造、新依赖。

**Acceptance criteria:** 不完整起止、类型、独立精度及恢复所需上下文可保留；睡眠草稿不与普通记录混用，不参与正式覆盖、摘要、冲突，不提前改写编辑对象；存取和清除失败可识别。

**Validation:** 共用代码验证；真实草稿写入→关闭存储→重开→清除；核对正式五表不变、新建 / 编辑隔离、损坏与读写失败反馈；平台实际关闭 / 刷新证据留 E5-T08。

### E5-T03 — 实现独立睡眠表单与草稿生命周期

**ID:** E5-T03

**Status:** COMPLETE（2026-09-29）；实际交付与验证见 [E5-T03 报告](../reports/E5-T03_SLEEP_FORM_REPORT.md)。

**Title:** 实现独立睡眠表单与草稿生命周期

**Goal:** 以入睡和醒来时间为核心提供可恢复的睡眠输入。

**Depends on:** E5-T01、E5-T02。

**Source documents:** SOT §4、§29；RULES / SL-001–SL-005；MODEL / SleepSession、UI Models；Q-012、Q-016、Q-017。

**Scope:** ledger/presentation 的睡眠表单及最小可达入口；mainSleep / nap、分钟级日期时间输入、起止各自精度，自动存草稿、恢复和主动放弃。

**Out of scope:** Goal / annotation 输入、睡眠质量、实时睡眠计时、备注便利入口、将普通记录 Q-023 算法当睡眠推断规则。

**Acceptance criteria:** 跨日输入不要求拆条；类型由用户确认，不以时长推断；两端精度独立可选，改时间不暗改精度。正区间允许历史和未来，不设时长阈值；离开不等于放弃，恢复不覆盖已填内容，无 Goal 也可进入。

**Validation:** 共用代码验证及 widget 测试；跨日、混合精度、零 / 反向区间、缺少端点、类型切换、恢复 / 放弃及草稿失败；输入期间原事实不变。

### E5-T04 — 接通睡眠新建、冲突反馈与刷新

**ID:** E5-T04

**Status:** COMPLETE（2026-09-30）；实际交付与验证见 [E5-T04 报告](../reports/E5-T04_SLEEP_SUBMISSION_REPORT.md)。

**Title:** 接通睡眠新建、冲突反馈与刷新

**Goal:** 让确认后的完整睡眠通过受控写入成为正式事实。

**Depends on:** E5-T03、E2-T06；Q-011、Q-012、Q-018。

**Source documents:** DATA / 原子写入；RULES / SL、LEDGER-004；APP / 失败处理。

**Scope:** ledger/application 提交协调、presentation 反馈与 app 组装；复用 createSleepSession，成功后清草稿并重读睡眠摘要和日投影；提供主睡眠 / 小睡原始起止、完整时长及缺失 / 近似信息的最小展示，复用 E3 格式映射。

**Out of scope:** UI 预检替代事务、自动截断 / 拆分 / 覆盖、生成 TimeBlock 或 recovery、完整时间轴。

**Acceptance criteria:** 跨日保存一条 SleepSession；与 TimeBlock / SleepSession 冲突均原子拒绝，列出冲突供手动修正。失败保留草稿，防重复提交；区分正式写入失败与已提交但清理 / 刷新失败，不诱导重复创建。

**Validation:** 共用代码验证；真实库新建两种类型、两类冲突、相接合法、保存前事实变化、失败回滚；controller / widget 核对重复点击、清理或刷新失败及成功后摘要 / 覆盖更新。

### E5-T05 — 接通睡眠更正与删除

**ID:** E5-T05

**Status:** COMPLETE（2026-09-30）；实际交付与验证见 [E5-T05 报告](../reports/E5-T05_SLEEP_CORRECTION_REPORT.md)。

**Title:** 接通睡眠更正与删除

**Goal:** 允许按原事实身份修正整次睡眠并重算受影响结果。

**Depends on:** E5-T04、E1-T12、E2-T06；Q-013、Q-018。

**Source documents:** STATES / SleepSession、通用更正删除；DATA / 事务；DERIVED / sleepSummary。

**Scope:** 睡眠编辑 / 删除入口、按 id 加载完整睡眠的必要 repository 扩展、编辑草稿；调用既有 update / delete，刷新受影响日期与醒来日摘要。

**Out of scope:** 历史版本、编辑切片作为新事实、改写复盘、自动修改其他事实、备注便利入口。

**Acceptance criteria:** 修改保留 id / createdAt，无变化不更新 updatedAt；时间、类型、独立精度可更正，未展示 note 保留。未保存编辑不改正式事实；缺失编辑报不存在而不重建，重复删除幂等；失败不清草稿。

**Validation:** 共用代码验证；真实库配合交互测试，覆盖跨日编辑、醒来日变化、mainSleep↔nap、冲突回滚、保留 note、删除后 Gap / 摘要更新、恢复草稿时源事实已删除及重复删除。

### E5-T06 — 实现每日首次打开的主睡眠确认

**ID:** E5-T06

**Status:** COMPLETE（2026-09-30）；实际交付与验证见 [E5-T06 报告](../reports/E5-T06_FIRST_SLEEP_CONFIRMATION_REPORT.md)。

**Title:** 实现每日首次打开的主睡眠确认

**Goal:** 优先收集主睡眠，同时避免反复打扰。

**Depends on:** E5-T01、E5-T04、E5-T05；Q-008、Q-010、Q-012。

**Source documents:** RULES / SL-004；DERIVED / 已记录识别；SOT §29；APP / UI state。

**Scope:** app 入口与 ledger/application / presentation 的首次打开协调；复用 E3 已记录判定和睡眠入口，最小本机交互标记支撑每日首次语义，恢复已有草稿。

**Out of scope:** 通知 / 后台提醒系统、强制睡眠后才能记账、以草稿充当已记录、把首次打开标记写成领域状态。

**Acceptance criteria:** 按当前设备日期判断；当天已结束 mainSleep 免打扰，仅 nap 或未来结束 mainSleep 不满足条件。未记录时首次打开优先确认，可继续账本；同日重开 / Web 刷新不重复主动询问，下一自然日重新判定。读失败不伪装未记录，草稿不被新入口覆盖；更正删除后的识别来自当前事实，不追加反复提醒。

**Validation:** 共用代码验证；显式 now / 日期下验证首次、同日再次、跨日、时区变化、已记录、仅 nap、未来结束、查询失败与已有草稿；实际跨启动 / 刷新免打扰在 E5-T08 验证。

### E5-T07 — 验证睡眠记录应用闭环

**ID:** E5-T07

**Status:** COMPLETE — 见 [任务报告](../reports/E5-T07_SLEEP_RECORDING_FLOW_REPORT.md)。

**Title:** 验证睡眠记录应用闭环

**Goal:** 核验睡眠输入、正式事实、摘要与覆盖协同。

**Depends on:** E5-T05、E5-T06。

**Source documents:** MVP / M-03、M-07；PLAN / Epic 5；DERIVED / sleepSummary、hasApproximation。

**Scope:** 睡眠应用集成测试与本 Epic 必要修复，使用最小结果展示核验日切片，不提前建设完整时间轴。

**Out of scope:** Epic 6–9 页面、长期趋势、用此任务替代前序测试、宣布全 MVP 完成。

**Acceptance criteria:** 真实入口→草稿→正式保存→读回→更正 / 删除贯通；23:50–次日 07:40 在醒来日完整摘要 7h50m、覆盖 7h40m（无偏移变化且 W 足够）；缺失显示尚未记录，不声称未睡觉；近似按各项来源传播。

**Validation:** 共用代码验证；真实数据库结合应用交互，覆盖跨日、多段主睡眠与 nap 分列、午夜醒来、无 Goal、冲突后修正、删除与失败恢复；核对未生成 recovery / 普通块。

### E5-T08 — 验证 Android 与 Web 睡眠保存和恢复

**ID:** E5-T08

**Status:** COMPLETE — 见 [任务报告](../reports/E5-T08_ANDROID_WEB_SLEEP_RECOVERY_REPORT.md)。

**Title:** 验证 Android 与 Web 睡眠保存和恢复

**Goal:** 为睡眠草稿恢复、正式持久化及首次打开取得平台证据。

**Depends on:** E5-T07、E2-T08；完整 Epic 5 验收要求 Epic 2、3 完成；Q-012、Q-022。

**Source documents:** PLAN / Epic 5、输入草稿共同交付合同；DATA / 本机输入草稿；MVP / 闭环验收。

**Scope:** Android / Web 隔离测试数据、平台验证和任务报告；仅修复本 Epic 范围问题。

**Out of scope:** 仅重开数据库代替应用关闭 / 网页刷新、mock 平台证据、其他平台、发布部署。

**Acceptance criteria:** 两平台证明正式睡眠重启可读，新建 / 编辑不完整输入离开和关闭 / 刷新后可恢复；编辑原事实不变，恢复提交重新校验。失败保留、成功或主动放弃后不恢复旧草稿；每日首次标记与已记录免打扰跨启动有效。

**Validation:** 共用代码验证；记录设备 / 浏览器、实际 Android 关闭重开与 Web 刷新步骤和结果；覆盖混合精度、跨日、失败后恢复、过期冲突、清理与免打扰。缺失平台或失败如实报告，不标完成。

### E5-T09 — 提供睡眠可选备注入口（Should Have）

**ID:** E5-T09

**Status:** COMPLETE（2026-09-30）；实现、草稿升级及平台补充验证见 [E5-T09 报告](../reports/E5-T09_OPTIONAL_SLEEP_NOTE_REPORT.md)。

**Title:** 提供睡眠可选备注入口（Should Have）

**Goal:** 允许补充睡眠说明而不增加主路径必填项。

**Depends on:** E5-T05；不阻塞 E5-T07 / E5-T08 或核心 Epic 5 验收。

**Source documents:** MVP / Should Have；MODEL / SleepSession；RULES / MODEL-002；Q-012、Q-015。

**Scope:** 睡眠 note 可选输入，接入睡眠草稿和正式保存 / 更正，复用现有字段及文本校验。

**Out of scope:** 新增领域字段、必填备注、睡眠质量、改动核心完成门槛。

**Acceptance criteria:** note 可省略、修改、清空；按既有文本合同规范化，保留内部换行；恢复包含 note，失败不丢失。

**Validation:** 共用代码验证；空白、多行、长度边界、清空、草稿恢复与正式读回；若在 E5-T08 后交付，补充受影响的平台恢复验证。

## Epic 6 — Daily Timeline / Gap Resolution

### E6-T01 — 接通日账本页面的日期选择与读取状态

**ID:** E6-T01

**Status:** COMPLETE（2026-09-30）；实际交付与验证见 [E6-T01 报告](../reports/E6-T01_DAY_LEDGER_ENTRY_REPORT.md)。

**Title:** 接通日账本页面的日期选择与读取状态

**Goal:** 为完整时间轴提供同一日期上下文下的一致正式投影。

**Depends on:** E4-T01、E5-T01、E3-T06；Q-008、Q-009。

**Source documents:** APP / 调用流程、UI state；DATA / 读取一致性；DERIVED / DayLedgerView。

**Scope:** ledger/application / presentation 的日账本页面入口、日期选择、加载 / 空数据 / 失败状态与 app 组装；复用已有读取和时间适配。

**Out of scope:** 重复投影算法、数据库 Day、统计页面、日历规划器、时区覆盖设置。

**Acceptance criteria:** 历史日完整窗口、今天截至显式 now、未来无 Gap；无数据与读取失败区分。切换日期、返回页面及刷新重新取得日期 / 时间上下文；快速切换时旧响应不覆盖新日期，不把草稿当事实。

**Validation:** 共用代码验证；controller / widget 覆盖空日、读取失败重试、快速切日、跨零点、时区与非 24 小时日，核对调用现有投影且原始事实不变。


### E6-T02 — 呈现事实切片与派生 Gap 时间轴

**ID:** E6-T02

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E6-T02 报告](../reports/E6-T02_DAY_LEDGER_TIMELINE_REPORT.md)。

**Title:** 呈现事实切片与派生 Gap 时间轴

**Goal:** 让已知、未知、睡眠与尚未记录在同一时间轴清楚可辨。

**Depends on:** E6-T01、E3-T07；Q-014、Q-017、Q-021。

**Source documents:** DERIVED / segments、UnresolvedSpan、hasApproximation；RULES / LEDGER-001–LEDGER-005；SOT §9、§24–25。

**Scope:** ledger/presentation 按时间排列切片和 Gap，展示类型、区间及各项近似；携带源事实类型 / id 供后续编辑。

**Out of scope:** Goal / annotation 编辑、统计仪表盘、完整度分数、仅以颜色区分状态、持久化 Gap。

**Acceptance criteria:** Unknown 按 knowledgeState 识别，不能按标题猜测；已知块、Unknown、mainSleep / nap 与 Gap 可辨。跨日仅显示窗口贡献，原始区间不变；近似来自切片 / Gap 自身，裁掉的边界不污染结果。首尾及全空窗口的 Gap 可见，未来无补账提示。

**Validation:** 共用代码验证与 widget 测试；混合事实、带标题 Unknown、跨日、相接无 Gap、全空历史 / 今天、空未来、零点及近似裁剪 / 相等边界、微小时长；核对排序和无重复片段。

### E6-T03 — 接通 Gap 预填与明确确认 Unknown

**ID:** E6-T03

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E6-T03 报告](../reports/E6-T03_GAP_RECORDING_REPORT.md)。

**Title:** 接通 Gap 预填与明确确认 Unknown

**Goal:** 把用户选择的缺口交给现有普通记录流程补账。

**Depends on:** E6-T02、E4-T02、E4-T04、E4-T05；Q-011、Q-012、Q-023。

**Source documents:** RULES / 时间建议合同、TB-004–TB-006；SOT §8、§28；DATA / 原子写入。

**Scope:** Gap 点击入口、明确 Gap 参数传递、普通记录草稿上下文和保存返回衔接；复用 known / unknown 表单及原子提交。

**Out of scope:** 第二套普通编辑器、点击即自动持久化 Unknown、Gap id / 状态表、自动填全日、以 Gap 展示精度覆盖新草稿精度。

**Acceptance criteria:** 明确点击 Gap 直接预填可改起止，包括全空日；新草稿两端 approximate。用户可填活动或明确确认 Unknown，无标题 Unknown 合法；取消 / 离开只保留草稿，不占覆盖，不覆盖已有未保存输入。保存时按当前正式事实校验，过期 Gap 冲突不覆盖其他记录。

**Validation:** 共用代码验证；widget 与真实库集成覆盖 known / Unknown、修改为部分区间后仍有剩余 Gap、全空明确 Gap 与普通入口分支差异、取消恢复、已有草稿、冲突失败保留和成功重读。

### E6-T04 — 接通时间轴原事实更正与删除

**ID:** E6-T04

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E6-T04 报告](../reports/E6-T04_TIMELINE_EDITING_REPORT.md)。

**Title:** 接通时间轴原事实更正与删除

**Goal:** 让日切片跳回完整事实，并让操作后的时间轴反映当前账本。

**Depends on:** E6-T02、E6-T03、E4-T06、E5-T05；Q-003、Q-013、Q-018。

**Source documents:** STATES / 通用更正删除、TimeBlock、SleepSession；APP / 写入后重读；DERIVED / segments。

**Scope:** 按源类型 / id 路由至普通 / 睡眠既有编辑器；更正删除成功后重新读取当前日，受影响其他日期再次打开时读取新事实。

**Out of scope:** 编辑切片生成新记录、重写更正领域逻辑、Goal / annotation 编辑、历史版本或自动改写复盘。

**Acceptance criteria:** 跨日任一切片编辑同一完整源事实；删除后 Gap 重算，改时间跨日或改睡眠醒来日后相关视图不陈旧。缺失编辑不重建，重复删除幂等；失败不显示成功，已提交但刷新失败可单独重试读取。

**Validation:** 共用代码验证；真实库与交互验证跨日 TimeBlock / SleepSession 从两日访问、known↔unknown、区间移出当前日、删除后缺口、冲突回滚、缺失源事实、保留未展示字段及刷新失败。

### E6-T05 — 验证时间轴与补账完整应用闭环

**ID:** E6-T05

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E6-T05 报告](../reports/E6-T05_DAY_LEDGER_RESOLUTION_REPORT.md)。

**Title:** 验证时间轴与补账完整应用闭环

**Goal:** 为 M-02 的事实、Unknown 和 Gap 区分提供端到端证据。

**Depends on:** E6-T03、E6-T04、E4-T07、E5-T07。

**Source documents:** MVP / M-02、闭环验收；PLAN / Epic 6；DERIVED / 可核对关系与例子。

**Scope:** 同一应用真实数据库闭环测试及本 Epic 必要修复；核验补账前后日投影与 UI。

**Out of scope:** Epic 7–9 功能、重新实现统计、替代前序单元测试、强制零 Gap。

**Acceptance criteria:** 跨日睡眠→普通补记→部分 Gap 确认为 Unknown→另一 Gap 保留→更正 / 删除后重算可完成。Unknown 已计 accounted，不能重复相加；同窗 accounted + unresolved 等于窗口时长。没有保存 Gap、Day 或聚合，不把失败算作 Unknown。

**Validation:** 共用代码验证；真实库与应用交互组合，覆盖首尾 / 中间 Gap、部分补记、近似、相接、当前截止、未来、手动冲突修正与刷新失败重试；完整日不使用固定 1440 分钟。

### E6-T06 — 验证 Android 与 Web 时间轴补账集成

**ID:** E6-T06

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E6-T06 报告](../reports/E6-T06_DAY_LEDGER_PLATFORM_REPORT.md)。

**Title:** 验证 Android 与 Web 时间轴补账集成

**Goal:** 证明两首发平台上的真实 Gap 入口与返回刷新可用。

**Depends on:** E6-T05、E4-T08、E5-T08；完整 Epic 6 验收要求 Epic 3、4、5 完成；Q-012、Q-022。

**Source documents:** MVP / M-02、M-07；PLAN / Epic 6；DATA / 本机输入草稿。

**Scope:** 两平台时间轴→Gap 表单→保存 / 返回→更正 / 删除的集成验证与报告；仅补充新增路由与上下文的恢复证据，不机械重跑所有前序用例。

**Out of scope:** 其他平台、部署、用纯 mock 替代平台验证、把 Epic 6 完成当全 MVP 完成。

**Acceptance criteria:** Android / Web 均可完成 Gap 补 known 或 Unknown 并刷新；从 Gap 离开后以及 Android 关闭 / Web 刷新后可恢复对应输入，正式提交前不消除 Gap；跨日睡眠与剩余缺口重启后仍由事实正确投影。

**Validation:** 共用代码验证；记录实际设备 / 浏览器与操作结果，覆盖 Gap 上下文恢复、成功清除、取消不提交、冲突保留、两类事实编辑返回及重启读回；未执行或失败逐项列明。

## Epic 7 — Goal + Rhythm Annotation

### E7-T01 — 接通简单目标创建与读取

**ID:** E7-T01

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E7-T01 报告](../reports/E7-T01_GOAL_CREATION_READ_REPORT.md)。

**Title:** 接通简单目标创建与读取

**Goal:** 让用户建立时间归属目标并读取当前目标。

**Depends on:** E2-T04、E4-T07、E6-T01；Q-006、Q-015、Q-018、Q-019。

**Source documents:** MODEL / Goal；RULES / GO-001–GO-002；APP / goals 边界。

**Scope:** goals/presentation 与 app 组装：active 列表、创建、加载 / 空 / 失败状态；复用 GoalRepository。

**Out of scope:** 归属表单、目标统计、项目管理字段、通用 use-case 框架。

**Acceptance criteria:** 创建仅 active，名称按已有规则校验；同名允许且按 id 区分；失败保留输入、成功后重读，不把加载失败当空列表；普通记录和睡眠不要求先建目标。

**Validation:** 共用代码验证；widget 与真实 repository 组合覆盖空列表、同名创建、文本边界、保存失败和重试；不重复实现领域校验。

### E7-T02 — 接通目标改名归档恢复与删除

**ID:** E7-T02

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E7-T02 报告](../reports/E7-T02_GOAL_LIFECYCLE_REPORT.md)。

**Title:** 接通目标改名归档恢复与删除

**Goal:** 提供已批准的目标生命周期操作并保留历史引用。

**Depends on:** E7-T01、E2-T07；Q-006、Q-018、Q-019。

**Source documents:** STATES / Goal；DATA / 引用策略；RULES / GO-002。

**Scope:** goals/presentation、必要的 goals/domain / data 查询扩展及 app 装配；提供归档管理 / 恢复入口。

**Out of scope:** 级联删除事实、目标历史版本、清空既有引用、给目标增加状态。

**Acceptance criteria:** 改名对历史读取生效；归档 / 恢复和重复请求遵守元数据合同。有 TimeBlock 或 TomorrowFirstStep 引用时删除转归档，无引用才物理删除；反馈区分结果，恢复后可重新选择；失败不伪报成功。

**Validation:** 共用代码验证；真实库覆盖两类引用、无引用删除、重名改名、归档恢复与重复操作；widget 验证管理入口和失败反馈。

### E7-T03 — 接通普通记录的可选目标归属

**ID:** E7-T03

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E7-T03 报告](../reports/E7-T03_OPTIONAL_GOAL_ASSOCIATION_REPORT.md)。

**Title:** 接通普通记录的可选目标归属

**Goal:** 在新建与编辑 TimeBlock 时明确选择或移除目标。

**Depends on:** E7-T02、E4-T06、E6-T04；Q-003、Q-004、Q-006、Q-012。

**Source documents:** SOT §11、§26–27；RULES / TB-003、GO-002；DATA / 本机输入草稿。

**Scope:** ledger 表单、controller、草稿 DTO / 独立存储升级、保存 / 更正协调及 goals/domain 读取；覆盖普通、Gap、编辑入口。

**Out of scope:** 强制 Goal、改变时间建议、自动精度升级、annotation 输入。

**Acceptance criteria:** known / unknown 均可有无 Goal；新关联仅 active，原有 archived 引用可保留或明确移除。归属按 id 保存，同名不合并；草稿记录选择及明确清空意图，旧草稿不覆盖未展示字段。目标相关区间突出供确认，approximate 仍合法。保存时重新校验目标状态，失败保留输入。

**Validation:** 共用代码验证；新建 / 编辑 / Gap、已归档原引用、新选后被归档或删除、清空、旧草稿迁移和重开读回；正式引用在提交前不变。


### E7-T04 — 接通可选节奏解释与接续点

**ID:** E7-T04

**Status:** COMPLETE（2026-10-01）；实际交付与验证见 [E7-T04 报告](../reports/E7-T04_OPTIONAL_RHYTHM_REPORT.md)。

**Title:** 接通可选节奏解释与接续点

**Goal:** 把用户解释接入记录流程且保留不标记的低成本路径。

**Depends on:** E7-T03、E2-T06、E1-T11；Q-004、Q-005、Q-012、Q-013、Q-015。

**Source documents:** MODEL / RhythmAnnotation；STATES / RhythmAnnotation；RULES / RH-001–RH-008。

**Scope:** ledger/presentation、草稿及 application 提交：显式 add / edit / remove、三个状态、可选 continuationHint；复用原子组合写入。

**Out of scope:** 原因 / 恢复细节的新输入入口（E7-T08）、自动打标、neutral、独立任务管理。

**Acceptance criteria:** known / unknown、有无 Goal 均可选三种解释或无解释；不要求原因或恢复细节。三状态自由切换，已有附属字段保留，仅当前适用字段参与展示 / 使用；接续点三状态均可填、清空和恢复。未请求变更时保留解释，remove 明确且只移除解释；同次事实与解释全成或全败。重复 add / 缺失 edit 给出正确反馈，不静默 upsert。

**Validation:** 共用代码验证；真实库与表单覆盖六向切换、仅改解释、组合冲突回滚、移除不改覆盖、缺失对象、同块唯一、文本边界、草稿升级与失败保留；已提交后的清理 / 刷新失败不开放重复提交。


### E7-T05 — 在时间轴呈现目标节奏与接续点

**ID:** E7-T05

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E7-T05 报告](../reports/E7-T05_TIMELINE_GOAL_RHYTHM_REPORT.md)。

**Title:** 在时间轴呈现目标节奏与接续点

**Goal:** 让保存的归属和用户解释可从原事实入口查看与更正。

**Depends on:** E7-T04、E6-T04；Q-003、Q-005、Q-006、Q-013。

**Source documents:** SOT §12–20；APP / 跨 feature 读取；STATES / 通用更正。

**Scope:** 日时间轴及原事实详情 / 编辑路由，按 Goal id 读取名称与状态；写入后刷新。

**Out of scope:** 统计页面、自动评价、切片副本编辑、自动生成明日第一步。

**Acceptance criteria:** 显示当前目标名和归档标识、所选节奏及可选接续点；无解释不暗示失败。跨日切片仍定位同一完整事实；改名、归档、解释更正 / 移除、事实删除后重新读取，不自动改写复盘。

**Validation:** 共用代码验证；widget 与真实库覆盖同名目标、跨日编辑、归档标识、接续点读回、移除及删除、刷新失败单独重试；仅颜色区分不可作为唯一语义。

### E7-T06 — 验证目标与节奏完整应用闭环

**ID:** E7-T06

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E7-T06 报告](../reports/E7-T06_GOAL_RHYTHM_CLOSURE_REPORT.md)。

**Title:** 验证目标与节奏完整应用闭环

**Goal:** 验证 M-04 的可选性、归属和解释写入一致性。

**Depends on:** E7-T01–E7-T05、E6-T05。

**Source documents:** MVP / M-01、M-04、M-07；PLAN / Epic 7。

**Scope:** 真实库应用集成测试及本 Epic 必要修复。

**Out of scope:** Epic 8 / 9 页面、全量重构、把 Should Have 作为核心门槛。

**Acceptance criteria:** 建立目标→补记目标时间→明确解释→更正 / 移除→归档 / 恢复闭环可完成；无目标、无解释、近似和 Unknown 均可保存。一块最多一份解释，写入失败无部分事实；提交成功但清理 / 刷新失败可恢复且不重复建记录。

**Validation:** 共用代码验证；通过实际 UI 和真实库组合核验原子性、元数据、草稿隔离、旧字段保留与错误分支；断言当前投影反映解释变化。

### E7-T07 — 验证 Android 与 Web 目标节奏集成

**ID:** E7-T07

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E7-T07 报告](../reports/E7-T07_GOAL_RHYTHM_PLATFORM_REPORT.md)。

**Title:** 验证 Android 与 Web 目标节奏集成

**Goal:** 取得新增归属和解释输入的两平台持久化与恢复证据。

**Depends on:** E7-T06、E6-T06；完整 Epic 7 要求 Epic 2、4、6 完成；Q-012、Q-022。

**Source documents:** MVP / M-04、M-07；DATA / 本机输入草稿；PLAN / Epic 7。

**Scope:** Android / Web 实际应用场景、平台测试和报告；复用既有驱动。

**Out of scope:** 其他平台、部署、以本地文件重开替代关闭 / 刷新。

**Acceptance criteria:** 两平台正式目标 / 解释读回；未保存目标选择、节奏和接续点离页及 Android 关闭重开 / Web 刷新可恢复，正式事实不提前改变；成功 / 放弃清草稿，失败保留；旧普通记录草稿兼容。

**Validation:** 共用代码验证；记录设备 / 浏览器、命令及结果，覆盖恢复后目标状态变化、归档与更正、冲突、保存后重启和时间轴刷新；缺失证据不得标通过。

### E7-T08 — 提供可选原因与恢复细节入口（Should Have）

**ID:** E7-T08

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E7-T08 报告](../reports/E7-T08_OPTIONAL_RHYTHM_DETAILS_REPORT.md)。

**Title:** 提供可选原因与恢复细节入口（Should Have）

**Goal:** 降低补充节奏细节的成本而不增加保存门槛。

**Depends on:** E7-T04、E7-T05；Q-005、Q-007、Q-012、Q-015。

**Source documents:** MODEL / 原因与恢复值域；MVP / Should Have；STATES / 字段保留。

**Scope:** 既有解释编辑器的 stuckReasonCode / stuckReasonText、recoveryMethod / recoveryQuality；草稿和正式提交映射。

**Out of scope:** 新增代码值域、强制原因或质量、睡眠恢复方式、效果评分。

**Acceptance criteria:** 按已定单选值域，可全部不填；原因可仅文字，“其他”不强制补充；状态切换保留字段，只显示适用细节，切回恢复。清空意图明确，主观恢复质量不换算分数。

**Validation:** 共用代码验证；空值、每种代码映射、仅文字、切换恢复、长度边界、清空与失败保留；真实库读回；若晚于 E7-T07 交付，补做受影响的两平台草稿恢复。

## Epic 8 — Statistics / Summaries

### E8-T01 — 接通摘要日期上下文与一致读取

**ID:** E8-T01

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T01 报告](../reports/E8-T01_SUMMARY_CONTEXT_REPORT.md)。

**Title:** 接通摘要日期上下文与一致读取

**Goal:** 为基础摘要提供同一日期和事实快照。

**Depends on:** E3-T06、E3-T07、E5-T01、E6-T01。

**Source documents:** APP / 读取流程；DATA / 一致读取；DERIVED / DayLedgerView；OQ Q-008–Q-010。

**Scope:** ledger/application / presentation 摘要入口和 app 组装；复用日账本 loader、显式 now / 本地日期边界与格式映射。

**Out of scope:** 重复计算、统计表、周月报、时区设置。

**Acceptance criteria:** 历史 / 今天 / 未来遵守原窗口；完整睡眠按醒来日期读取而非仅日切片。加载、空数据、失败可辨；日期切换旧响应不覆盖新日期，刷新取得新上下文；无草稿参与。

**Validation:** 共用代码验证；controller / widget 覆盖快速切日、跨零点、非 24 小时日、读取错误重试、完整跨日睡眠与窗口贡献不同；核对使用现有投影。


### E8-T02 — 呈现账本覆盖与 Unknown 摘要

**ID:** E8-T02

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T02 报告](../reports/E8-T02_COVERAGE_SUMMARY_REPORT.md)。

**Title:** 呈现账本覆盖与 Unknown 摘要

**Goal:** 描述已交代、其中未知及尚未记录的数据状态。

**Depends on:** E8-T01；Q-009、Q-014、Q-017、Q-021。

**Source documents:** DERIVED / accountedDuration、unknownDuration、unresolvedDuration；RULES / LEDGER-005–LEDGER-009。

**Scope:** 摘要覆盖区块及既有格式映射接线。

**Out of scope:** 完整度比例、1440 分钟固定分母、补账新入口或算法。

**Acceptance criteria:** Unknown 明确是已交代子集，不相加两遍；每项独立近似，Gap 为零是数据状态。今天只截至 now，未来无补账压力；正微小时长依 Q-021 展示，最终汇总后舍入。

**Validation:** 共用代码验证；widget + 手算夹具核对全空、全覆盖、Unknown、剩余 Gap、边界裁剪和独立近似；关系在毫秒计算层验证，不要求舍入后显示数机械相等。


### E8-T03 — 呈现完整睡眠背景摘要

**ID:** E8-T03

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T03 报告](../reports/E8-T03_SLEEP_SUMMARY_REPORT.md)。

**Title:** 呈现完整睡眠背景摘要

**Goal:** 区分完整主睡眠 / 小睡背景和日窗口睡眠覆盖。

**Depends on:** E8-T01、E5-T07；Q-010、Q-014、Q-017、Q-021。

**Source documents:** DERIVED / sleepSummary；RULES / SL-001–SL-005；MVP / M-05。

**Scope:** 复用或组合 sleep_summary_view，接入摘要日期与完整睡眠结果。

**Out of scope:** 睡眠质量输入、长期趋势、因果结论、将 nap 算作 recovery。

**Acceptance criteria:** 按醒来日期分别展示主睡眠与小睡及各自完整记录 / 合计；无匹配记录各自提示尚未记录，不称睡了零小时；跨日完整近似可不同于当天覆盖近似，多条记录不擅自挑一条。

**Validation:** 共用代码验证；跨日、多条主睡眠、小睡、缺失、微小时长、当前日醒来已记录和未来窗口场景；更正醒来日后原日 / 新日重读正确。


### E8-T04 — 呈现目标四项细分与全局节奏摘要

**ID:** E8-T04

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T04 报告](../reports/E8-T04_GOAL_RHYTHM_SUMMARY_REPORT.md)。

**Title:** 呈现目标四项细分与全局节奏摘要

**Goal:** 让目标相关总时间与明确推进等贡献保持可辨。

**Depends on:** E8-T01、E7-T05、E3-T04；Q-019–Q-021、Q-014、Q-017。

**Source documents:** DERIVED / goalSummaries、节奏汇总；RULES / LEDGER-006；MVP / M-05。

**Scope:** ledger 摘要目标列表、名称 / 归档状态读取、总量及 progress / stuck / recovery / 无 annotation 四项，全局节奏与恢复背景。

**Out of scope:** 效率比例、同名合并、合成无目标 Goal、自动推断未标记活动。

**Acceptance criteria:** 仅显示窗口内正贡献 Goal，含归档并标注，同名按 id 独立；无目标记录参与全局统计。每项近似 / hasRecords 独立，缺失不当零活动；全局 recovery 不再与目标 recovery 相加；四项之和在原始时长层等于相关总量。

**Validation:** 共用代码验证；混合目标、归档、同名、无目标三种节奏、未标记、缺失与微小时长；逐项核对格式映射和投影，覆盖改名 / 归档后的显示更新。


### E8-T05 — 验证摘要随事实与解释变化重算

**ID:** E8-T05

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T05 报告](../reports/E8-T05_SUMMARY_RECALCULATION_REPORT.md)。

**Title:** 验证摘要随事实与解释变化重算

**Goal:** 证明摘要展示始终由当前事实派生。

**Depends on:** E8-T02–E8-T04、E7-T06、E6-T05。

**Source documents:** PLAN / Epic 8；DERIVED / 可核对关系；APP / 写入后重读。

**Scope:** 真实库应用集成、返回 / 刷新链路及必要修复。

**Out of scope:** 将统计写回复盘、缓存事实源、重做前序算法。

**Acceptance criteria:** 创建、更正、删除普通 / 睡眠事实和增改移除解释后重算；Goal 改名归档更新显示，草稿不影响数值。一次展示不混用新旧账本快照，刷新失败可重试且不重复写入；无评分或因果文案。

**Validation:** 共用代码验证；固定手算混合场景与当前日场景，通过 UI 操作比较同快照 DayLedgerView；验证跨日修改、删除后的 Gap / Unknown、目标四项与恢复口径。


### E8-T06 — 验证 Android 与 Web 基础摘要

**ID:** E8-T06

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E8-T06 报告](../reports/E8-T06_SUMMARY_PLATFORM_REPORT.md)。

**Title:** 验证 Android 与 Web 基础摘要

**Goal:** 取得两首发平台摘要集成与重启重算证据。

**Depends on:** E8-T05、E7-T07、E5-T08、E6-T06；完整 Epic 8 要求 Epic 3、5、6、7 完成；Q-022。

**Source documents:** MVP / M-05、M-07；PLAN / Epic 8。

**Scope:** 两平台实际日期切换、修改返回、关闭 / 刷新后摘要重算及报告。

**Out of scope:** 新统计功能、其他平台、把测试夹具数据当交付 UI。

**Acceptance criteria:** 两平台睡眠、覆盖、Unknown、目标四项和全局恢复与事实一致；空数据、近似及归档文案正确，重启后重新派生，失败可识别且可恢复。

**Validation:** 共用代码验证；实际设备 / 浏览器操作证据；混合正式事实、编辑返回、历史 / 当前日期、重启与刷新读回；复用前序驱动并列明未执行项。

## Epic 9 — Daily Review

### E9-T01 — 接通按日复盘读取与上下文

**ID:** E9-T01

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T01 报告](../reports/E9-T01_REVIEW_CONTEXT_REPORT.md)。

**Title:** 接通按日复盘读取与上下文

**Goal:** 区分无复盘、已有复盘和读取失败并提供当天事实上下文。

**Depends on:** E2-T07、E8-T05、E7-T02；Q-001、Q-006、Q-008。

**Source documents:** MODEL / DailyReview；APP / review 依赖；RULES / DR-001–DR-004。

**Scope:** review/application / presentation 与 app 入口；按 CivilDate 读复盘、复用 ledger 摘要并读 Goal 元数据。

**Out of scope:** 复盘写入、强制先看统计、派生数值持久化。

**Acceptance criteria:** 可选历史日期；无复盘与失败分开，已有内容按身份读入；切日旧响应不覆盖新日期。展示已存 CivilDate 与其下一自然日，设备时区变化不改写复盘日期；上下文不自动生成反思或下一步。

**Validation:** 共用代码验证；读取空值、历史复盘、快速切日、失败重试、日期年 / 月边界、已归档原 Goal 引用、当前事实变化但复盘文字不变。

### E9-T02 — 实现独立复盘本机草稿存储

**ID:** E9-T02

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T02 报告](../reports/E9-T02_REVIEW_DRAFT_STORE_REPORT.md)。

**Title:** 实现独立复盘本机草稿存储

**Goal:** 可靠保存未完成复盘输入并隔离正式数据。

**Depends on:** E2-T02、E2-T07、E1-T07；Q-012、Q-015。

**Source documents:** DATA / 本机输入草稿；MODEL / UI Models；APP / review 分层。

**Scope:** review 专用草稿 DTO / 存取边界、data 实现及 app 生命周期装配；按新建日期 / 编辑源身份区分上下文，覆盖改日期输入。

**Out of scope:** 正式 draft 状态、放宽下一步必填、正式表 payload、通用草稿框架、新依赖。

**Acceptance criteria:** 保存原始未完成 summary、reflection、下一步、可选 Goal 和正在编辑的日期；草稿不占 review_date 唯一位置。编辑身份与改后日期分开，不覆盖其他日期草稿；读写清除失败明确，离开重开可读回。

**Validation:** 共用代码验证；真实独立存储重开、日期 / 身份隔离、未完成及超长文字保留、选择 / 清空 Goal、故障反馈；核对正式五表不变；平台生命周期验证留 E9-T09。

### E9-T03 — 实现复盘表单与草稿生命周期

**ID:** E9-T03

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T03 报告](../reports/E9-T03_REVIEW_FORM_REPORT.md)。

**Title:** 实现复盘表单与草稿生命周期

**Goal:** 用一个下一步收束复盘并自动保留未保存输入。

**Depends on:** E9-T01、E9-T02；Q-001、Q-006、Q-012、Q-015。

**Source documents:** RULES / DR-001、DR-003–DR-004；MODEL / TomorrowFirstStep；DATA / 本机草稿。

**Scope:** review 表单 / controller：summary、reflection、单个下一步、可选 active Goal、日期、恢复 / 放弃；接已有目标读取。

**Out of scope:** 正式提交、任务列表、每目标一份计划、复制 continuationHint 为正式下一步。

**Acceptance criteria:** summary / reflection 可空；下一步正式保存需非空白，三个文本按长文本合同处理。日期改变同步展示下一自然日；输入 / 离页自动保留，恢复不被摘要刷新覆盖；编辑原事实不变，旧归档引用保留可见，新选仅 active。放弃仅清本草稿，失败保留并反馈。

**Validation:** 共用代码验证；widget / controller 覆盖多行与 Unicode 边界、空下一步草稿、切日与恢复、编辑改日期、保存草稿失败、快速输入 / 离页顺序、主动放弃、可选 Goal。

### E9-T04 — 接通复盘新建保存与失败反馈

**ID:** E9-T04

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T04 报告](../reports/E9-T04_REVIEW_SUBMISSION_REPORT.md)。

**Title:** 接通复盘新建保存与失败反馈

**Goal:** 将完整复盘一次提交并安全完成草稿收尾。

**Depends on:** E9-T03、E2-T07；Q-001、Q-006、Q-012、Q-013、Q-018。

**Source documents:** DATA / daily_reviews、唯一约束；APP / 写入流程；RULES / DR-001–DR-004。

**Scope:** review/application 新建协调、表单提交和 app 装配，复用 ReviewRepository.create。

**Out of scope:** upsert 覆盖已有复盘、统计快照字段、自动生成必填下一步。

**Acceptance criteria:** 提交时按当前库核查日期唯一和 Goal 引用；重复点击不重复创建。成功后清对应草稿并重读；正式失败保留输入。已提交但清理 / 刷新失败明确区分，只重试收尾 / 读取，不再 create；不要求零 Gap 或非空反思。

**Validation:** 共用代码验证；真实库与交互覆盖同日竞争、选后归档 / 删除 Goal、文本失败、存储异常、成功读回、重复点击及清理 / 刷新失败重试；intendedDate 不单独存储。

### E9-T05 — 接通复盘原地更正与日期变更

**ID:** E9-T05

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T05 报告](../reports/E9-T05_REVIEW_CORRECTION_REPORT.md)。

**Title:** 接通复盘原地更正与日期变更

**Goal:** 安全修改既有解释与下一步且保留身份。

**Depends on:** E9-T04、E1-T12；Q-001、Q-006、Q-012、Q-013、Q-018。

**Source documents:** STATES / DailyReview、通用更正；DATA / daily_reviews；RULES / DR-001。

**Scope:** 按源 id 编辑协调，复用 ReviewRepository.update；日期、文字及 Goal 的明确保留 / 清空。

**Out of scope:** 历史版本、占用日期自动覆盖、将缺失对象改为新建。

**Acceptance criteria:** 保留 id / createdAt，实际变化才更新 updatedAt；改日期后 intendedDate 随新日派生，旧日查询为空，新日读到同一条。目标日占用拒绝且原文 / 日期不变；保留既有 archived Goal 合法，新关联重新校验。源已删除时提示，不自动重建；失败保留草稿。

**Validation:** 共用代码验证；真实库覆盖日期冲突回滚、跨月 / 闰年、无变化保存、清空可选文字和 Goal、缺失源对象、编辑草稿恢复、提交后收尾失败。

### E9-T06 — 接通复盘删除与返回读取

**ID:** E9-T06

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T06 报告](../reports/E9-T06_REVIEW_DELETION_REPORT.md)。

**Title:** 接通复盘删除与返回读取

**Goal:** 允许删除一份复盘而不影响时间事实。

**Depends on:** E9-T05；Q-012、Q-013。

**Source documents:** STATES / DailyReview；RULES / DR-002；DATA / 删除策略。

**Scope:** review 删除操作、关联编辑草稿收尾、按日返回 / 重读。

**Out of scope:** 删除当天时间事实、Goal、独立下一步实体或其他日期草稿。

**Acceptance criteria:** 明确删除后本复盘消失，账本和其他复盘不变；重复删除幂等；失败不显示成功且保留输入。已删除后的旧编辑输入不自动重建事实，收尾失败可单独重试；页面状态与当前日期读取一致。

**Validation:** 共用代码验证；真实库和 widget 覆盖删除前后正式表对比、重复删除、存储失败、关联草稿清理失败、返回及重开不会复活；保留其他草稿。

### E9-T07 — 贯通日账本复盘与下一步回看

**ID:** E9-T07

**Status:** COMPLETE（2026-10-02）；实际交付与验证见 [E9-T07 报告](../reports/E9-T07_REVIEW_ROUTE_REPORT.md)。

**Title:** 贯通日账本复盘与下一步回看

**Goal:** 让用户从某日事实进入复盘并读回已保存行动。

**Depends on:** E9-T04–E9-T06、E8-T05、E7-T05。

**Source documents:** SOT §20–22；MVP / M-06；APP / feature 调用流程。

**Scope:** app 路由、review 阅读 / 编辑入口与摘要上下文刷新，显示一份下一步及 intendedDate。

**Out of scope:** 提醒、打卡、任务完成状态、每 Goal 计划、自动接续点搬运。

**Acceptance criteria:** 当天 / 历史日期入口保持正确 CivilDate；已有复盘打开读回 / 更正，不再默认新建。接续点与明日第一步标签和来源分明；事实更正刷新上下文但不重写反思；留 Gap、无目标、仅下一步均可完成。

**Validation:** 共用代码验证；widget + 真实库完整路由验证：摘要进入、保存返回、历史回看、改日期后旧新日入口、删除后状态、事实更正与复盘文字独立。

### E9-T08 — 验证复盘完整应用闭环与失败恢复

**ID:** E9-T08

**Status:** COMPLETE（2026-10-03）；实际交付与验证见 [E9-T08 报告](../reports/E9-T08_REVIEW_CLOSURE_REPORT.md)。

**Title:** 验证复盘完整应用闭环与失败恢复

**Goal:** 验证 M-06 和独立草稿、唯一性及安全重试。

**Depends on:** E9-T07、E7-T06、E8-T05。

**Source documents:** MVP / M-06、M-07、闭环验收；PLAN / Epic 9；DATA / 草稿隔离。

**Scope:** 应用真实库集成测试与本 Epic 必要修复。

**Out of scope:** Epic 10 全 MVP 验收、以 mock 替代正式约束、重复全套前序测试。

**Acceptance criteria:** 事实 / 摘要→复盘草稿→提交→更正日期 / 内容→回看 / 删除可完成；不自动评价或持久化摘要；同日唯一、已有归档引用和失败保留满足合同；正式提交后恢复不产生重复记录。

**Validation:** 共用代码验证；组合覆盖历史日期、竞争唯一冲突、过期编辑、Goal 状态变化、读写 / 草稿清理 / 刷新故障、文本边界及跨自然日；逐项对照核心验收。

### E9-T09 — 验证 Android 与 Web 复盘保存和恢复

**ID:** E9-T09

**Status:** COMPLETE（2026-10-03）；实际交付与验证见 [E9-T09 报告](../reports/E9-T09_REVIEW_PLATFORM_REPORT.md)。

**Title:** 验证 Android 与 Web 复盘保存和恢复

**Goal:** 取得复盘正式持久化和草稿跨生命周期证据。

**Depends on:** E9-T08、E7-T07、E8-T06；完整 Epic 9 要求 Epic 2、7、8 完成；Q-012、Q-022。

**Source documents:** MVP / M-06、M-07；DATA / 本机输入草稿；PLAN / Epic 9。

**Scope:** 两平台新建 / 编辑 / 改日期草稿恢复、正式保存 / 删除重启读回与报告；复用平台驱动。

**Out of scope:** 发布部署、其他平台、将本地数据库重开称为 Android 关闭或 Web 刷新。

**Acceptance criteria:** 离页、Android 关闭重开、Web 同源刷新后输入可恢复；未提交不改变已有复盘或账本。失败保留，成功或放弃清除对应草稿；更正与删除重启后保持，其他日期草稿不串用。

**Validation:** 共用代码验证；记录实际设备 / 浏览器、关闭 / 刷新操作和命令结果；覆盖空下一步草稿、历史日期、改日期、正式冲突后恢复、成功读回及主动放弃；未执行项单列。
