# Tasks

## 使用方式与当前状态

本文件将 [IMPLEMENTATION_PLAN](docs/planning/IMPLEMENTATION_PLAN.md) 的前 3 个 Epic（Epic 0、1、2）细化为可单独交付的任务。后续 Epic 只列工作包，不是可直接交给 coding agent 执行的大任务。范围以 [MVP_SCOPE](docs/planning/MVP_SCOPE.md) 为准，执行方式遵守 [AGENTS](AGENTS.md)。

**所有任务初始均为 NOT STARTED。** 本轮只编写文档，未执行基线命令、实现或安装依赖。任务可执行条件：用户明确指定该任务、Depends on 中前置任务已完成、涉及的未决问题已有可追溯答案且相应规范已更新。问题答案不由 coding agent 自行产生；缺少答案时报告 BLOCKED，不用默认值或临时模型绕过。

首个可交付任务为 **E0-T01：核查现有工程与验证基线**；执行后停止。下文 ID 是稳定标识，不因后来插入任务重排。每个 Task 自带验收及验证，不把测试统一推迟到最后一个 Epic。

### Source documents 索引

每个任务列出的简称指向下表完整文件及其指定章节；执行单个任务时应展开读取，不能只依赖本文件的摘要。所有任务共同必读 SOT、OQ、MVP、PLAN 与 AGENTS，局部来源列在任务内。

| 简称 | 文件 |
| --- | --- |
| SOT | [time-ledger-domain-model-v4-proposal.md](time-ledger-domain-model-v4-proposal.md) |
| MODEL | [DOMAIN_MODEL](docs/domain/DOMAIN_MODEL.md) |
| RULES | [DOMAIN_RULES](docs/domain/DOMAIN_RULES.md) |
| STATES | [DOMAIN_STATE_MACHINES](docs/domain/DOMAIN_STATE_MACHINES.md) |
| DERIVED | [DERIVED_MODELS](docs/domain/DERIVED_MODELS.md) |
| OQ | [OPEN_QUESTIONS](docs/domain/OPEN_QUESTIONS.md) |
| APP | [APP_ARCHITECTURE](docs/architecture/APP_ARCHITECTURE.md) |
| DATA | [DATA_ARCHITECTURE](docs/architecture/DATA_ARCHITECTURE.md) |
| MVP | [MVP_SCOPE](docs/planning/MVP_SCOPE.md) |
| PLAN | [IMPLEMENTATION_PLAN](docs/planning/IMPLEMENTATION_PLAN.md) |

### 验证约定与工程边界

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

**Depends on:** E1-T01、E1-T02；Q-002、Q-015、Q-016 的字段及校验合同已确定，Q-004 的关联组合仍须明确。

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

**Depends on:** E1-T02；Q-006、Q-015、Q-018 已确定，Q-019 的名称规则仍须明确。

**Source documents:** MODEL / Goal；RULES / GO-001、GO-002；STATES / Goal。

**Scope:** goals/domain 的对象、单对象校验、名称比较规则（若确认需要）及测试。

**Out of scope:** 归档 / 恢复执行、跨记录名称查询、关联记录删除、任务树和进度字段。

**Acceptance criteria:** 字段与可空性一致，状态仅 active / archived；初始状态和 archivedAt 条件有确定依据。名称唯一性若需集合查询，保留至存储操作，不伪装为单对象校验。

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

**Depends on:** E1-T03、E1-T06、E1-T08；Q-003、Q-004、Q-013 已明确后执行。

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

**Depends on:** E2-T02；DATA / Schema 定稿清单全部相关问题已有答案并更新规范，含仍影响 schema 的 Q-004、Q-005、Q-007、Q-013、Q-019；Q-022 的平台核验另按 E2-T01 执行。

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

## Epic 3–10 — 待细化工作包

以下没有 Task ID，不能直接作为编码任务执行。进入对应 Epic 前，根据已批准产品答案和实际实现细化为同样九字段的小任务；不能借工作包一次实现整个 Epic。完整交付及验收仍引用 PLAN 的对应 Epic，依赖保持不变。

| Epic | 前置 Epic | 后续拆分方向与验收重点 | 关键决策门槛 |
| --- | --- | --- | --- |
| 3 Ledger Projection Engine | 1 | 按切片与覆盖、Gap、节奏 / 目标时长、摘要选择和近似传播分批；以 DERIVED 手算及边界样例验证 | Q-009、Q-010、Q-014、Q-020、Q-021；不依赖 Epic 2 |
| 4 Basic Recording | 2、3 | 活动优先输入、可改建议时间、known / unknown 保存与失败反馈 | Q-023、Q-003、Q-013 及输入合同 |
| 5 Sleep Recording | 2、3 | 完整睡眠记录、跨日接入、首次确认与已记录识别 | Q-010；不依赖 Epic 4 普通活动编辑器 |
| 6 Daily Timeline / Gap Resolution | 3、4、5 | 时间轴、Gap 预填、用户确认 Unknown、成功后重算 | Q-009、Q-014 |
| 7 Goal + Rhythm Annotation | 2、4、6 | 归属选择、用户解释、获准更正与接续点；可选细节入口另列 Should Have | Q-004、Q-005、Q-007、Q-013、Q-019 |
| 8 Statistics / Summaries | 3、5、6、7 | 描述性基础摘要与近似 / 缺失数据展示，不重复计算或存储统计 | Q-010、Q-014、Q-020、Q-021 |
| 9 Daily Review | 2、7、8 | 单份复盘、一个下一步、可选 Goal、历史日期与失败处理 | Q-013 |
| 10 Polish / Reliability | 4、5、6、7、8、9 | 完整 MVP 场景、Android / Web 平台可靠性及关键失败路径；不扩充产品 | Q-022 已决定；Must Have 所涉其他合同全部明确 |

Q-012 的跨启动草稿恢复未进入任务清单；MVP 的 Later / Explicitly Out of Scope 均不生成任务。未决问题的完整影响以 OQ、PLAN 和各职责文档为准，表格不构成穷尽规则。

## Epic 完成核对与停止点

Epic 0 在 E0-T01–E0-T03 完成后核对 PLAN 验收。Epic 1 在 E1-T01–E1-T12 及 Epic 0 完成后核对验收。Epic 2 在 E2-T01–E2-T08 及 Epic 0、1 完成后核对验收。局部工作先行不改变完整 Epic 的依赖。

执行一个 Task 后按 AGENTS 报告并停止。不得因为已细化其他 Task 自动继续；不得在本轮执行 E0-T01。
