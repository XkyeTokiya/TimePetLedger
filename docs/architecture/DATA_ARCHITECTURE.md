# Data Architecture

## 职责、依据与设计状态

本文是 Greenfield 第一版正式 schema 设计文档，回答“数据未来怎么存？”。依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) §4–24、§33，以及 [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)、[DOMAIN_RULES](../domain/DOMAIN_RULES.md)、[DERIVED_MODELS](../domain/DERIVED_MODELS.md) 与 [DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md)。代码归属见 [APP_ARCHITECTURE](APP_ARCHITECTURE.md)，未决项唯一入口为 [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md)。

下文逐列定义五张核心表，并区分：

- **Domain Decision：** 已确定的事实字段、可空性、关系及领域约束。
- **Engineering Recommendation：** 数据库、物理类型、索引、事务与具体约束表达方式。它们是技术建议，不是 Source of Truth 强制的产品要求。
- **UNDECIDED：** 产品答案会影响物理设计的部分，明确保留条件分支。不能用 nullable、默认值、JSON 杂项列或数据库默认动作掩盖缺失答案。

这是首版 schema 的规范及待决边界，不是已可执行的完整建表脚本。具体 DDL 必须在对应阻塞问题明确后落实；本轮不创建数据库、SQL 文件或安装 package。

## Domain Decision：保存哪些事实

| 表 | 持久化内容 | 对应规则 |
| --- | --- | --- |
| goals | 时间归属目标 | GO-001、GO-002 |
| time_blocks | 普通时间事实，含 known / unknown | TB-001–TB-009 |
| rhythm_annotations | 附于时间块的可选节奏解释 | RH-001–RH-008 |
| sleep_sessions | 独立睡眠事实，保留完整跨日区间 | SL-001–SL-003 |
| daily_reviews | 每日解释与 TomorrowFirstStep 的内容 | DR-001–DR-004 |

不建立通用 timeline_entries 表来合并 SleepSession 和 TimeBlock；两者共同参与查询不意味着共用一个领域实体。annotation 也不另存起止或时长。

## Engineering Recommendation：持久化与通用类型

建议使用一个本地 SQLite 关系库，五张表共用同一个事务边界。它适合本轮明确的关系、唯一约束和少量跨表写入协调；具体 Flutter 驱动 / 包在首发平台 Q-022 明确后选择，本轮不固定包或版本。此建议不增加账号、网络服务或同步表。

所有下述物理类型都是建议；领域字段的存在性与 nullable 仍按源文档。

| 语义类型 | 建议的物理类型 | 合同与未决边界 |
| --- | --- | --- |
| 实体标识 | TEXT | 不透明标识；所有实体 id 显式 NOT NULL PRIMARY KEY，外键类型与之相同。生成方式见 Q-018，不在此指定生成包 |
| 时间点 Instant | INTEGER | 建议统一 UTC epoch 毫秒用于比较 / 排序；这是编码建议，不把 approximate 变 exact，不限制用户输入到分钟。精度 / 舍入见 Q-017，原始时区上下文是否额外保存见 Q-008 |
| 自然日期 CivilDate | TEXT | 建议统一 YYYY-MM-DD 日期值；不是 UTC 零点时间戳。日期合法性由领域 / 映射验证；日期所属时区仍待 Q-008 |
| 已确定枚举 | TEXT | 固定、区分大小写的代码，见枚举表；不用 Dart enum 序号，也不存本地化文案 |
| 普通文字 | TEXT | 保留文字；不擅自 trim、设长度上限或将空串改为 null（Q-015） |

data 映射按上述合同绑定和读回整数 / 文本，不通过隐式字符串转换掩盖类型错误；类型声明不能替代领域值解析。

UTC 数值只保存一个时间点，不能重建用户输入时的时区名称。若 Q-008 选择按记录时区解释日期，需明确补充的时区 / 偏移字段，不能宣称上述时间列已解决该问题。schema 定稿前也不能自动采用当前设备时区填补语义。

### 枚举表示

| 列 | 已确定值域（Domain Decision） | 数据库表达建议 |
| --- | --- | --- |
| 两类事实的 start_precision / end_precision | exact、approximate，两个字段独立 | 各自 NOT NULL + CHECK IN |
| time_blocks.knowledge_state | known、unknown | NOT NULL + CHECK IN |
| rhythm_annotations.state | progress、stuck、recovery | NOT NULL + CHECK IN |
| sleep_sessions.sleep_type | mainSleep、nap | NOT NULL + CHECK IN |
| goals.status | active、archived | NOT NULL + CHECK IN；不设隐含 active 默认值 |

不为 stuck_reason_code、recovery_method 或 recovery_quality 从示例擅自生成封闭枚举（Q-007）。映射遇到未知代码应报告数据错误，不降级成 unknown、neutral 或任意默认状态。

## goals

Domain Decision：对象及字段见 DOMAIN_MODEL / Goal。表内物理类型属于 Engineering Recommendation。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK；目标身份 |
| name | TEXT | NO | 名称；非空白和长度见 Q-015，名称唯一性见 Q-019 |
| status | TEXT | NO | CHECK 值域 active / archived；初始状态见 Q-006 |
| created_at | INTEGER（Instant） | NO | 创建时间，写入策略见时间戳章节 |
| updated_at | INTEGER（Instant） | NO | 更新时间，触发条件见 Q-018 |
| archived_at | INTEGER（Instant） | YES | 源结构可选；与 status 联动规则见 Q-006 |

**Foreign keys:** 本表无外键；被 time_blocks.goal_id 与 daily_reviews.tomorrow_first_step_goal_id 引用。

**Unique constraints:** id 主键唯一。`name UNIQUE` 未确定，不作为已确定约束；不把“尚未加 UNIQUE”当成已批准的重名产品行为。

**Indexes:** 初始只需要主键；小规模目标列表不预先增加 status / name 索引。查询确有需要时再验证。

**Pending:** 不添加 `archived ⇒ archived_at IS NOT NULL` 或 `active ⇒ archived_at IS NULL` 的 CHECK，不用数据库触发器自行定义归档 / 恢复语义（Q-006）。

## time_blocks

Domain Decision：所有普通时间事实使用此表，unknown 也正常保存。起止、精度与标题约束见 TB-001–TB-008。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| started_at | INTEGER（Instant） | NO | 与 ended_at 构成严格正区间 |
| ended_at | INTEGER（Instant） | NO | CHECK started_at < ended_at |
| start_precision | TEXT | NO | exact / approximate |
| end_precision | TEXT | NO | exact / approximate；独立于 start_precision |
| knowledge_state | TEXT | NO | known / unknown |
| title | TEXT | YES，条件必需 | known 时必须存在且非空；unknown 可为空，不强制清空 |
| goal_id | TEXT | YES | 引用 goals.id；是否受状态组合限制见 Q-004 |
| category_id | 首版存在性待定；若保留建议 TEXT | 若保留则 YES | 条件列，Q-002；不能默认新建 categories 表或空悬外键 |
| note | TEXT | YES | 补充说明 |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** 建议 goal_id → goals.id；NULL 表示没有目标关联。删除 / 更新动作见下方外键章节。

**Unique constraints:** 仅 id；不为 title、起止组合或 goal_id 添加唯一约束。与其他时间事实的重叠是另一个跨记录约束，不由唯一键替代。

**Indexes:** 建议 started_at 索引支撑日窗口候选查找；(goal_id, started_at) 支撑目标窗口查询并覆盖外键子列查找。完整索引清单见索引章节。

**Database-enforced constraint 建议表达：**

```sql
CHECK (started_at < ended_at)
CHECK (knowledge_state IN ('known', 'unknown'))
CHECK (start_precision IN ('exact', 'approximate'))
CHECK (end_precision IN ('exact', 'approximate'))
CHECK (
  knowledge_state <> 'known'
  OR (title IS NOT NULL AND title <> '')
)
```

上述是文档中的约束片段，不是独立可执行 DDL。必须与表中的 NOT NULL 配合：SQLite 的 CHECK 表达式结果为 NULL 时不会失败，因此不能仅写 `CHECK (knowledge_state <> 'known' OR length(title) > 0)` 来确保 known 的 title 存在。此处未用 trim，不替 Q-015 决定空白政策。[SQLite CHECK 语义](https://www.sqlite.org/lang_createtable.html#check_constraints)

## rhythm_annotations

Domain Decision：保存当前附于 TimeBlock 的解释，一个 TimeBlock 最多一个有效 annotation；absence 表示不标记，没有 neutral 行。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| time_block_id | TEXT | NO | UNIQUE FK → time_blocks.id，源文档明确要求 |
| state | TEXT | NO | CHECK IN progress / stuck / recovery |
| stuck_reason_code | 建议 TEXT | YES | 代码值域未定（Q-007） |
| stuck_reason_text | TEXT | YES | 与 code 均可为空；关系细则见 Q-007 |
| recovery_method | 建议 TEXT 代码 | YES | 正式代码表未定（Q-007），不从候选方式建硬编码 CHECK |
| recovery_quality | 物理类型待 Q-007 | YES | 不擅自选整数等级、评分或文字枚举；不是用 null 占位就算完成 schema |
| continuation_hint | TEXT | YES | 接续点；状态组合见 Q-005 |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** time_block_id → time_blocks.id；不能指向 sleep_sessions。解释自身不另存 goal_id，以免与事实的时间归属形成两份来源。

**Unique constraints:** id；time_block_id 唯一且非空。使用普通 UNIQUE 表达一份当前解释，不为未定义的历史版本引入 is_active / deleted_at 或条件唯一索引。

**Indexes:** time_block_id 的唯一索引已满足连接与外键子列查找，不再重复创建普通索引。首版不为 state 单独建立索引；按已选窗口的 TimeBlock 找 annotation 即可。

**Pending:** 类型和值域 Q-007；不同 state 的附属字段保留 / 清理 Q-005；移除解释和历史处理 Q-013。不得添加“stuck 必须有原因”或“recovery 必须有方式 / 质量”的 CHECK。

## sleep_sessions

Domain Decision：独立保存完整睡眠事实；跨日不拆行，不与普通 recovery 共表。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| started_at | INTEGER（Instant） | NO | 原始入睡时间 |
| ended_at | INTEGER（Instant） | NO | 原始醒来时间 |
| start_precision | TEXT | NO | CHECK IN exact / approximate |
| end_precision | TEXT | NO | CHECK IN exact / approximate |
| sleep_type | TEXT | NO | CHECK IN mainSleep / nap；对应领域 type |
| note | TEXT | YES | 可选补充 |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** 无。没有 time_block_id、goal_id、day_id 或 recovery annotation 关联。

**Unique constraints:** 仅 id；不能从“昨晚睡眠”推导“一天只能一条睡眠”或入睡日期唯一。

**Indexes:** 建议 started_at 非唯一索引用于窗口查询及重叠候选检索。

**Pending:** Q-016 尚未明确 SleepSession 正区间及其他范围校验。**Engineering Recommendation：** 建议确认后同样采用 `started_at < ended_at` 并在 domain / database 双层落实；本条不把建议写成已批准规则，也不表示零 / 负时长已获允许。实际建表与保存实现必须先确定该合同。睡眠摘要日期归属 Q-010 不应被提前固化成 sleep_date 列。

## daily_reviews

Domain Decision：按日期唯一保存复盘解释，TomorrowFirstStep 作为其组成内容，不独立建任务表。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| review_date | TEXT（CivilDate） | NO | UNIQUE；对应领域 date，不是 Day 外键 |
| summary | TEXT | YES | 可选概述 |
| reflection | TEXT | YES | 可选反思 |
| tomorrow_first_step_text | TEXT | NO | 对应 TomorrowFirstStep.text；进一步文本校验见 Q-015 |
| tomorrow_first_step_intended_date | 条件列；若保存建议 TEXT（CivilDate） | 若保存则 NO | 领域 intendedDate 必需，但物理保存 / 派生方式待 Q-001 |
| tomorrow_first_step_goal_id | TEXT | YES | 引用 goals.id；不要求所有 Goal 各有第一步 |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** 建议 tomorrow_first_step_goal_id → goals.id；没有指向数据库 Day 或某条 TimeBlock 的必需关联。

**Unique constraints:** id；review_date 非空唯一（DR-001）。如何处理已存在日期的保存请求见 Q-013，不由 UNIQUE 自动决定覆盖或提示。

**Indexes:** review_date 的唯一索引支撑按日读取，不重复创建日期索引；建议 tomorrow_first_step_goal_id 非唯一索引用于引用查找。

**intendedDate 的两个待决分支（Q-001）：**

- 若产品确认显式保存意向日期，保留上述非空日期列；其与 review_date 的关系仍须确定。
- 若产品确认完全由复盘日期和明确规则派生，不保存该列，由领域构造时按确定规则提供 intendedDate。

不能因为源文档存储示例漏列就删除领域字段，不能擅自默认 `review_date + 1`，也不能用 nullable 日期列表示未决定。这里未选择任一分支。

**明确不存：** progress_minutes、stuck_minutes、recovery_minutes、睡眠总量、Gap 总量、目标汇总或整份 DayLedgerView JSON。

## Foreign keys 与引用行为

| 子列 | 父键 | 可空性 | 关系依据 / 工程落实 | 删除 / 更新动作 |
| --- | --- | --- | --- | --- |
| time_blocks.goal_id | goals.id | 可空 | 目标归属已确定；用数据库 FK 兜底是工程建议 | Q-006、Q-018 待决 |
| rhythm_annotations.time_block_id | time_blocks.id | 非空 | RH-001 / 源文档 §33 明确 UNIQUE FK | Q-013、Q-018 待决 |
| daily_reviews.tomorrow_first_step_goal_id | goals.id | 可空 | 可选目标关联已确定；数据库 FK 为工程建议 | Q-006、Q-018 待决 |

不在文档中默认选 CASCADE、SET NULL 或 RESTRICT 来代表删除产品行为，也不借 ORM 默认动作绕过 Q-006 / Q-013。执行完整 DDL 前应显式选择和验证对应动作；当前表结构说明不授权任何删除操作。Q-002 未解决前，category_id 不生成指向虚构表的 FK。

**Engineering Recommendation：** 若采用 SQLite，每个连接在事务开始前显式开启并核验外键约束；父 id 使用声明的主键，子列类型保持一致。仅在文本中写出 FK 不等于运行时已执行外键校验。[SQLite 外键启用与索引要求](https://www.sqlite.org/foreignkeys.html)

## Indexes：最小查询驱动清单

以下额外索引均为 Engineering Recommendation，不能承担业务唯一性或重叠约束：

| 索引 / 约束 | 键 | 用途 |
| --- | --- | --- |
| 各表 PK | id | 实体查找、引用目标 |
| rhythm_annotations 的 UNIQUE | time_block_id | 每块最多一份解释；连接读取 |
| daily_reviews 的 UNIQUE | review_date | 每日期最多一份复盘；按日读取 |
| idx_time_blocks_started_at | started_at | 主轴窗口和重叠候选查找 |
| idx_sleep_sessions_started_at | started_at | 睡眠窗口和跨表重叠候选查找 |
| idx_time_blocks_goal_started_at | goal_id, started_at | 单目标窗口查询；目标引用查找 |
| idx_daily_reviews_first_step_goal | tomorrow_first_step_goal_id | 明日第一步目标引用查找 |

日窗口查询按区间相交检索，不能只找 started_at 落在当天的记录，否则会漏掉前一晚开始的睡眠。data 返回完整起止与精度，由 domain/projection 裁剪；多个表及 annotation 的读取使用下文的一致视图。

区间相交检索同时涉及 started_at 与 ended_at；单个 started_at 索引不保证所有区间查询都高效。先用少量索引与实际查询计划验证，再依据数据量考虑 ended_at 等额外索引，不建立每字段索引或独立统计表。

## Timestamps 与日期

**Domain Decision：** 五类实体都有 createdAt / updatedAt；Goal 另有可空 archivedAt；TimeBlock 与 SleepSession 的事实边界和这类元数据是两种不同时间。补记昨天的记录，不意味着 created_at 必须等于 started_at。

**Engineering Recommendation：** 由一个操作获取可注入的当前时间并交给 data 写入；创建时可采用同一次取时填 created_at / updated_at。UTC 数值编码采用前述通用表示建议。具体“哪些编辑更新 updated_at”、同状态重复请求是否更新、时钟回拨如何处理仍属 Q-018；不自动添加 `created_at <= updated_at` CHECK 或自动更新时间触发器。archived_at 按 Q-006 的生命周期决定。

自然日期字符串在 domain / 映射边界检查实际日历合法性，不能只靠长度十位。数据库的日期唯一约束不负责决定用户时区；Q-008 未确定前，不添加按数据库本地时区生成 review_date 的默认表达式。

## 三类约束的职责

| 类别 | 负责的约束 | 边界 |
| --- | --- | --- |
| **Database-enforced constraint** | 各列 NOT NULL、PK、已确定枚举 CHECK、TimeBlock 正区间及条件标题 CHECK、annotation 的 UNIQUE FK、review_date UNIQUE；建议增加两个 Goal FK | 防止违反已确定结构；不能判断用户是否真的推进，不能以简单行 CHECK 处理跨表重叠 |
| **Domain-enforced constraint** | TB / RH / SL / GO / DR 的已确定单对象语义；纯时间冲突判定、日期值解析、派生计算及精度传播 | 不执行 I/O；未决组合、转换、睡眠校验和传播政策须先明确；不能通过标题自动评判节奏 |
| **Application-enforced constraint** | 协调关联查找、跨表重叠检查与原子写入；按批准合同处理转换 / 删除；保存失败不报告成功 | 在 application 发起，在 data 的同一事务内完成读取 / 复核 / 写入；不靠 UI 预检单独保证一致性 |

一个规则可有领域校验与数据库兜底，并不意味着复制两套互相冲突的产品定义。完整规则仍以 DOMAIN_RULES 为准；架构新增的是执行位置。

## Engineering Recommendation：事务、重叠与读取一致性

SQLite 的普通 CHECK 不能包含子查询，无法直接检查另一行或另一张表是否存在冲突。重叠原则由下列受控写入路径落实，不谎称两个时间表各自的 CHECK 已保证全局不重叠。[SQLite CHECK 限制](https://www.sqlite.org/lang_createtable.html#check_constraints)

建议 LedgerRepository 的具体实现统一承接 TimeBlock 与 SleepSession 写入：

1. 在读取冲突候选前取得写事务；选定驱动后使用等效于 `BEGIN IMMEDIATE` 的事务能力，不能先在事务外查一次再插入。
2. 查两张事实表中与候选区间相交的完整记录；若是已经批准的原地更正，只排除正在修改的同表同 id 记录，不能误排除另一表碰巧相同 id 的对象。
3. 调用领域重叠判定并核验必要引用。按已确定的 Q-017 端点约定处理相接；不能因 approximate 而忽略冲突。
4. 无冲突才写入该操作全部事实 / 解释；失败整体回滚。冲突结果交回应用处理，用户是否调整、拆分等仍见 Q-011，不自动改其他事实。
5. 成功提交后通知上层重读投影。读取一份日账本所需的多表数据时，使用同一读取事务取得一致视图，避免把不同提交时刻的事实与解释拼在一起。

例如，若最终采用半开区间的工程建议，正时长重叠候选条件可为 `existing.started_at < new.ended_at AND existing.ended_at > new.started_at`；这里不替 Q-017 定案。切片和重叠判断应复用同一约定。

SQLite 允许同时存在多个读事务，但只有一个写事务；立即写事务仍可能遇到忙错误，data 层必须暴露失败或在确认回滚后重试整个操作，不能静默忽略失败或只重试最后一条写语句。[SQLite 事务语义](https://www.sqlite.org/lang_transaction.html)

所有应用内主要事实写入应经过上述路径。直接绕开 repository 的任意 SQL 写入不受此跨表保护，因此不向 feature/presentation 暴露原始连接。第一版不增加触发器体系或通用事务框架；目标删除等跨 feature 操作待 Q-006 / Q-013 确定后再给出具体事务合同。

## 明确不持久化

**Domain Decision：** 以下不是数据库 Source of Truth，也不建立对应实体表、聚合列或持久化快照：

- DayLedgerView、数据库 Day entity、segments 日切片。
- UnresolvedSpan / Gap。
- aggregate statistics：sleepSummary、goalSummaries、accountedDuration、unknownDuration、unresolvedDuration、progressDuration、stuckDuration、recoveryDuration。
- hasApproximation 聚合标志：从事实的独立边界精度派生。

Unknown TimeBlock 不在此列表中，它是正式事实。UI 草稿不是已批准的持久化对象（Q-012），不因 schema 未决就给正式表新增 draft、通用 payload 或占位状态。未来读取时重新计算投影，具体算法只维护在 DERIVED_MODELS。

## Schema 定稿的待决清单

| 问题 | 对物理设计 / 实施的影响 |
| --- | --- |
| Q-001 | intendedDate 保存列还是确定规则派生；不能丢失领域语义 |
| Q-002 | category_id 是否进入首版；不创建分类系统 |
| Q-004、Q-005 | 跨字段 / 跨表组合和转换；不提前添加清理触发器或条件 CHECK |
| Q-006、Q-013 | 删除 / 更正合同、外键动作；不预先级联或解除引用 |
| Q-007 | 原因与恢复方式值域、recovery_quality 物理类型 |
| Q-008 | 时间点编码之外是否需保存记录时区 / 偏移上下文 |
| Q-015、Q-016 | 文本额外校验、SleepSession 区间校验 |
| Q-017、Q-018 | 时间分辨率、端点、标识生成及元数据写入合同 |
| Q-019 | 是否增加 Goal 名称唯一约束与比较规则 |
| Q-022 | 首发平台、驱动及本地存储运行支持 |

Q-009、Q-010、Q-014、Q-020、Q-021 影响派生与展示，不通过新增持久化汇总字段绕开。Q-003 的转换字段处理与 Q-012 草稿行为也不能被建表默认值替代。以上问题保持 UNDECIDED；本文的技术建议不把它们标成已解决。

## 本阶段自检基准

五个对象均有逐列映射，optional 字段没有升级成记录门槛。没有强制 unknown.title 为空，没有把 SleepSession 塞入 recovery，没有持久化 Gap / Day / 统计，也没有把 intendedDate 的源文档缺口悄悄定案。检查式明确处理 known.title 的 NULL 情况；不重叠通过单一事务写入边界协调而非仅靠逐表校验。
