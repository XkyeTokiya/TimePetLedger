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
| sleep_sessions | 独立睡眠事实，保留完整跨日区间 | SL-001–SL-005 |
| daily_reviews | 每日解释与 TomorrowFirstStep 的内容 | DR-001–DR-004 |

不建立通用 timeline_entries 表来合并 SleepSession 和 TimeBlock；两者共同参与查询不意味着共用一个领域实体。annotation 也不另存起止或时长。

## Engineering Recommendation：持久化与通用类型

初始工程建议为一个本地 SQLite 关系库，五张表共用同一个事务边界。它适合已明确的关系、唯一约束和少量跨表写入协调；Q-022 确定首发平台为 Android 和 Web。初始建议没有固定驱动 / 包，E2-T01 核验后的批准见下节。此方案不增加账号、网络服务或同步表。

### 已批准的工程选型（2026-09-27）

E2-T01 已完成官方资料核验。项目负责人在后续对话中明确表示“我明确采用你的方案，继续 E2-T02”，批准单库 SQLite + Drift 2.35.0 / drift_flutter 0.3.1 的工程方案及 E2-T02 最小依赖接入。Android 使用 NativeDatabase，Web 使用 WasmDatabase 及配套 WASM / worker 资产；不接受 inMemory 或 unsafeIndexedDb 作为正式持久化路径。该批准落实上述工程建议，不改变领域模型，也不扩大 Q-022 的平台范围。

Drift 2.34.0 起使用 BEGIN IMMEDIATE；本次以 2.35.0 为接入版本，逐连接在业务事务前启用并核验外键。选型依据与限制见 [E2-T01 报告](../reports/E2-T01_DRIVER_REPORT.md)。运行证据由 E2-T02 及后续任务分别提供；批准选型不等于平台验证通过。

所有下述物理类型都是建议；领域字段的存在性与 nullable 仍按源文档。

| 语义类型 | 建议的物理类型 | 合同与未决边界 |
| --- | --- | --- |
| 实体标识 | TEXT | 本地生成 UUID v4 的不透明标识；所有实体 id 显式 NOT NULL PRIMARY KEY，外键类型与之相同 |
| 时间点 Instant | INTEGER | 统一 UTC epoch 毫秒用于比较 / 排序；不把 approximate 变 exact。用户界面采用分钟级输入，内部按毫秒计算，展示时最终舍入到分钟 |
| 自然日期 CivilDate | TEXT | 统一 YYYY-MM-DD 日期值；不是 UTC 零点时间戳。时间事实的自然日按当前设备时区投影；已保存的 CivilDate 不因设备时区变化自动改写 |
| 已确定枚举 | TEXT | 固定、区分大小写的代码，见枚举表；不用 Dart enum 序号，也不存本地化文案 |
| 普通文字 | TEXT | 保存前清理首尾空白；必填文本非空，可选空文本为 null；短文本最多 200 个字符，长文本最多 2,000 个字符，由 Domain / Application 校验 |

data 映射按上述合同绑定和读回整数 / 文本，不通过隐式字符串转换掩盖类型错误；类型声明不能替代领域值解析。

UTC 数值保存事实时间点；自然日查询使用当前设备时区。设备时区变化会重新投影历史事实，但不修改 UTC 时间、精度或其他事实字段。账本时区覆盖能力属于后续开发，不要求首版为每条记录保存时区上下文。

### 枚举表示

| 列 | 已确定值域（Domain Decision） | 数据库表达建议 |
| --- | --- | --- |
| 两类事实的 start_precision / end_precision | exact、approximate，两个字段独立 | 各自 NOT NULL + CHECK IN |
| time_blocks.knowledge_state | known、unknown | NOT NULL + CHECK IN |
| rhythm_annotations.state | progress、stuck、recovery | NOT NULL + CHECK IN |
| sleep_sessions.sleep_type | mainSleep、nap | NOT NULL + CHECK IN |
| goals.status | active、archived | NOT NULL + CHECK IN；不设隐含 active 默认值 |

stuck_reason_code、recovery_method、recovery_quality 按 Q-007 已批准的选项保存为可空 TEXT 代码，完整代码表见 DOMAIN_MODEL；非空值必须属于对应值域。映射遇到未知代码应报告数据错误，不降级成 unknown、neutral 或任意默认状态。

## goals

Domain Decision：对象及字段见 DOMAIN_MODEL / Goal。表内物理类型属于 Engineering Recommendation。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK；目标身份 |
| name | TEXT | NO | 名称；非空白和长度见 Q-015；允许同名，不设 UNIQUE（Q-019） |
| status | TEXT | NO | CHECK 值域 active / archived；初始状态见 Q-006 |
| created_at | INTEGER（Instant） | NO | 创建时间，写入策略见时间戳章节 |
| updated_at | INTEGER（Instant） | NO | 更新时间，触发条件见 Q-018 |
| archived_at | INTEGER（Instant） | YES | 源结构可选；与 status 联动规则见 Q-006 |

**Foreign keys:** 本表无外键；被 time_blocks.goal_id 与 daily_reviews.tomorrow_first_step_goal_id 引用。

**Unique constraints:** 仅 id 主键唯一；按 Q-019 不设置 name UNIQUE，active / archived 都允许同名，创建和改名不进行重名拒绝。

**Indexes:** 初始只需要主键；小规模目标列表不预先增加 status / name 索引。查询确有需要时再验证。

**Constraint:** 应用层按 Q-006 维护 `archivedAt` 联动；数据库可镜像 `archived ⇒ archived_at IS NOT NULL` 与 `active ⇒ archived_at IS NULL`，但不依赖触发器定义归档 / 恢复操作。

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
| goal_id | TEXT | YES | 引用 goals.id；可与 known / unknown 及任一 RhythmState 组合；新增关联仍受 Q-006 约束 |
| category_id | TEXT | YES | 首版保留可空扩展字段；不建立 Category 表、分类入口或外键 |
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

上述是文档中的约束片段，不是独立可执行 DDL。必须与表中的 NOT NULL 配合：SQLite 的 CHECK 表达式结果为 NULL 时不会失败，因此不能仅写 `CHECK (knowledge_state <> 'known' OR length(title) > 0)` 来确保 known 的 title 存在。文本先由 Domain / Application 清理首尾空白并执行长度校验，数据库保持 TEXT；[SQLite CHECK 语义](https://www.sqlite.org/lang_createtable.html#check_constraints)

## rhythm_annotations

Domain Decision：保存当前附于 TimeBlock 的解释，一个 TimeBlock 最多一个有效 annotation；absence 表示不标记，没有 neutral 行。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| time_block_id | TEXT | NO | UNIQUE FK → time_blocks.id，源文档明确要求 |
| state | TEXT | NO | CHECK IN progress / stuck / recovery |
| stuck_reason_code | TEXT | YES | 可选单选代码；值域见 DOMAIN_MODEL（Q-007） |
| stuck_reason_text | TEXT | YES | 可独立填写或补充任一 code；other 不强制文字（Q-007） |
| recovery_method | TEXT | YES | 可选单选代码；值域见 DOMAIN_MODEL（Q-007） |
| recovery_quality | TEXT | YES | notRecovered / partlyRecovered / readyToContinue；主观描述代码，不保存数字评分（Q-007） |
| continuation_hint | TEXT | YES | 接续点；三种节奏均可填写，切换保留（Q-005） |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** time_block_id → time_blocks.id；不能指向 sleep_sessions。解释自身不另存 goal_id，以免与事实的时间归属形成两份来源。

**Unique constraints:** id；time_block_id 唯一且非空。使用普通 UNIQUE 表达一份当前解释，不为未定义的历史版本引入 is_active / deleted_at 或条件唯一索引。

**Indexes:** time_block_id 的唯一索引已满足连接与外键子列查找，不再重复创建普通索引。首版不为 state 单独建立索引；按已选窗口的 TimeBlock 找 annotation 即可。

**Decision（Q-005）：** 状态可任意互换，切换保留所有已填细节和接续点；不添加按状态自动清空的触发器或要求不适用字段必须为 NULL 的 CHECK。读取 / 展示只使用当前状态适用的细节，接续点适用于全部状态。

**Decision（Q-013）：** 允许编辑及移除解释，不保存历史版本；删除 TimeBlock 时一并删除解释，单独移除解释保留 TimeBlock。不得添加“stuck 必须有原因”或“recovery 必须有方式 / 质量”的 CHECK。

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

**Unique constraints:** 仅 id；Q-010 明确同一醒来日期允许多段主睡眠和小睡，不设置日期唯一约束。

**Indexes:** 建议 started_at 非唯一索引用于窗口查询及重叠候选检索。

**Constraint:** SleepSession 必须满足 `started_at < ended_at`；不设置固定最短 / 最长时长，允许未来正区间，不设置历史补录上限。该约束在 domain / database 双层落实。睡眠摘要按 Q-010 从 endedAt 与当前设备时区派生醒来日期，不新增 sleep_date 列。

## daily_reviews

Domain Decision：按日期唯一保存复盘解释，TomorrowFirstStep 作为其组成内容，不独立建任务表。

| Column | 建议类型 | Nullable | 约束 / 语义 |
| --- | --- | --- | --- |
| id | TEXT | NO | PK |
| review_date | TEXT（CivilDate） | NO | UNIQUE；对应领域 date，不是 Day 外键 |
| summary | TEXT | YES | 可选概述 |
| reflection | TEXT | YES | 可选反思 |
| tomorrow_first_step_text | TEXT | NO | 对应 TomorrowFirstStep.text；进一步文本校验见 Q-015 |
| tomorrow_first_step_goal_id | TEXT | YES | 引用 goals.id；不要求所有 Goal 各有第一步 |
| created_at | INTEGER（Instant） | NO | 创建时间 |
| updated_at | INTEGER（Instant） | NO | 更新时间 |

**Foreign keys:** 建议 tomorrow_first_step_goal_id → goals.id；没有指向数据库 Day 或某条 TimeBlock 的必需关联。

**Unique constraints:** id；review_date 非空唯一（DR-001）。Q-013 允许原地更正 review_date，但目标日期已被其他复盘占用时违反唯一性，拒绝保存，不自动覆盖另一份复盘。

**Indexes:** review_date 的唯一索引支撑按日读取，不重复创建日期索引；建议 tomorrow_first_step_goal_id 非唯一索引用于引用查找。

`TomorrowFirstStep.intendedDate` 固定为 `review_date` 的下一自然日，由领域构造时派生，不建立单独数据库列。

**明确不存：** progress_minutes、stuck_minutes、recovery_minutes、睡眠总量、Gap 总量、目标汇总或整份 DayLedgerView JSON。

## Foreign keys 与引用行为

| 子列 | 父键 | 可空性 | 关系依据 / 工程落实 | 删除 / 更新动作 |
| --- | --- | --- | --- | --- |
| time_blocks.goal_id | goals.id | 可空 | 目标归属已确定；用数据库 FK 兜底是工程建议 | 物理删除使用 RESTRICT；已有引用的界面删除转为归档，archived Goal 不得新增关联 |
| rhythm_annotations.time_block_id | time_blocks.id | 非空 | RH-001 / 源文档 §33 明确 UNIQUE FK | ON DELETE CASCADE（Q-013）；删除 TimeBlock 同时删除解释 |
| daily_reviews.tomorrow_first_step_goal_id | goals.id | 可空 | 可选目标关联已确定；数据库 FK 为工程建议 | 物理删除使用 RESTRICT；已有引用的界面删除转为归档 |

Goal 引用使用 RESTRICT 保护已有事实和复盘；应用层在有引用时将界面删除解释为归档并隐藏，在无引用时才执行物理删除。TimeBlock、SleepSession、DailyReview 按 Q-013 原地更正或删除；单独移除 annotation 保留其事实，不建立历史版本。`category_id` 不生成指向虚构表的 FK。

**E2-T03 工程落实：** 三处外键显式声明 `ON UPDATE RESTRICT`，防止父键更名时自动改写引用；实体更正保留身份，不提供重编号操作。删除动作按上表执行，仅 annotation 随 TimeBlock 删除而级联。数据库同时镜像 Goal.status 与 archived_at 的行内联动；是否允许新增归档目标关联仍由后续受控写入路径核验。

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

日窗口查询按区间相交检索，不能只找 started_at 落在当天的记录，否则会漏掉前一晚开始的睡眠。睡眠摘要另按 Q-010 查询 endedAt 落在醒来日期当地零点至次日零点的完整记录（含起点、不含终点），不能仅复用对账窗口相交结果。data 返回完整起止与精度，由 domain/projection 裁剪；多个表及 annotation 的读取使用下文的一致视图。

区间相交检索同时涉及 started_at 与 ended_at；单个 started_at 索引不保证所有区间查询都高效。先用少量索引与实际查询计划验证，再依据数据量考虑 ended_at 等额外索引，不建立每字段索引或独立统计表。

## Timestamps 与日期

**Domain Decision：** 五类实体都有 createdAt / updatedAt；Goal 另有可空 archivedAt；TimeBlock 与 SleepSession 的事实边界和这类元数据是两种不同时间。补记昨天的记录，不意味着 created_at 必须等于 started_at。

**Engineering Recommendation：** 由一个操作获取可注入的当前时间并交给 data 写入；创建时可采用同一次取时填 created_at / updated_at。UUID v4 和 UTC epoch milliseconds 采用前述合同。`created_at` 创建后不变；`updated_at` 仅在实体内容实际发生变化并成功保存后更新，查询、失败写入和无变化重复请求不更新。`archived_at` 按 Q-006 的生命周期决定。

自然日期字符串在 domain / 映射边界检查实际日历合法性，不能只靠长度十位。数据库的日期唯一约束不负责决定用户时区；review_date 在当前设备时区下选择并作为已保存 CivilDate 保持稳定。

## 三类约束的职责

| 类别 | 负责的约束 | 边界 |
| --- | --- | --- |
| **Database-enforced constraint** | 各列 NOT NULL、PK、已确定枚举 CHECK、TimeBlock 正区间及条件标题 CHECK、annotation 的 UNIQUE FK、review_date UNIQUE；建议增加两个 Goal FK | 防止违反已确定结构；不能判断用户是否真的推进，不能以简单行 CHECK 处理跨表重叠 |
| **Domain-enforced constraint** | TB / RH / SL / GO / DR 的已确定单对象语义；纯时间冲突判定、日期值解析、派生计算及精度传播 | 不执行 I/O；组合、更正与近似传播按 Q-004、Q-013、Q-014 已批准合同执行；不能通过标题自动评判节奏 |
| **Application-enforced constraint** | 协调关联查找、跨表重叠检查与原子写入；按批准合同处理转换 / 删除；保存失败不报告成功 | 在 application 发起，在 data 的同一事务内完成读取 / 复核 / 写入；不靠 UI 预检单独保证一致性 |

一个规则可有领域校验与数据库兜底，并不意味着复制两套互相冲突的产品定义。完整规则仍以 DOMAIN_RULES 为准；架构新增的是执行位置。

## Engineering Recommendation：事务、重叠与读取一致性

SQLite 的普通 CHECK 不能包含子查询，无法直接检查另一行或另一张表是否存在冲突。重叠原则由下列受控写入路径落实，不谎称两个时间表各自的 CHECK 已保证全局不重叠。[SQLite CHECK 限制](https://www.sqlite.org/lang_createtable.html#check_constraints)

建议 LedgerRepository 的具体实现统一承接 TimeBlock 与 SleepSession 写入：

1. 在读取冲突候选前取得写事务；选定驱动后使用等效于 `BEGIN IMMEDIATE` 的事务能力，不能先在事务外查一次再插入。
2. 查两张事实表中与候选区间相交的完整记录；若是已经批准的原地更正，只排除正在修改的同表同 id 记录，不能误排除另一表碰巧相同 id 的对象。
3. 调用领域重叠判定并核验必要引用。按已确定的 Q-017 端点约定处理相接；不能因 approximate 而忽略冲突。
4. 无冲突才写入该操作全部事实 / 解释；失败整体回滚。冲突结果原子拒绝并交回应用提示，用户手动调整；不自动截断、拆分、覆盖或移动其他事实。
5. 成功提交后通知上层重读投影。读取一份日账本所需的多表数据时，使用同一读取事务取得一致视图，避免把不同提交时刻的事实与解释拼在一起。

采用半开区间时，正时长重叠候选条件为 `existing.started_at < new.ended_at AND existing.ended_at > new.started_at`。切片和重叠判断复用同一约定。

SQLite 允许同时存在多个读事务，但只有一个写事务；立即写事务仍可能遇到忙错误，data 层必须暴露失败或在确认回滚后重试整个操作，不能静默忽略失败或只重试最后一条写语句。[SQLite 事务语义](https://www.sqlite.org/lang_transaction.html)

所有应用内主要事实写入应经过上述路径。直接绕开 repository 的任意 SQL 写入不受此跨表保护，因此不向 feature/presentation 暴露原始连接。第一版不增加触发器体系或通用事务框架；按 Q-013，TimeBlock 与 annotation 组合更正置于同一事务，删除 TimeBlock 及其解释同样原子完成；不自动重写或删除复盘。缺失对象编辑失败，缺失对象删除幂等完成；已有 annotation 时 add 拒绝，无 annotation 时 edit 拒绝，不以 upsert 静默覆盖或创建。

## 明确不持久化

**Domain Decision：** 以下不是数据库 Source of Truth，也不建立对应实体表、聚合列或持久化快照：

- DayLedgerView、数据库 Day entity、segments 日切片。
- UnresolvedSpan / Gap。
- aggregate statistics：sleepSummary、goalSummaries、accountedDuration、unknownDuration、unresolvedDuration、progressDuration、stuckDuration、recoveryDuration。
- hasApproximation 聚合标志：从事实的独立边界精度派生。

Unknown TimeBlock 不在此列表中，它是正式事实。UI 草稿按 Q-012 独立保存到本机，但不属于正式事实源；不在正式表新增 draft、通用 payload 或占位状态。未来读取时重新计算投影，具体算法只维护在 DERIVED_MODELS。

## 本机输入草稿（Q-012）

普通记录、睡眠记录和每日复盘的未保存输入自动写入独立本机草稿存储，支持页面离开、应用关闭和网页刷新后恢复。草稿允许未完成输入，不占据正式事实表，也不参与账本、摘要或跨事实重叠检查；编辑已有记录的草稿不得提前更改原事实。

活动 / 睡眠新建与补记的起止初始化沿Q-035：闭区间和已知起点的开区间每次进入重新计算并覆盖缓存端点，其他未提交内容保留；全开区间不恢复旧端点，由用户本次填写；既有事实更正沿自身编辑输入合同。先识别已经正式提交但收尾失败的草稿，避免重新初始化后重复提交。相邻事实读取在同一事务内取得所选日期相交的完整记录及日期前后最近记录，跨日端点不取自然日切片；不新增事实表、草稿字段或派生持久化数据。

以上为TIME-01已实施基线。后续Q-036明确所有入口直接提供完整估计、约80%无需时间操作及个人睡眠学习，替代3仅手动的初始化政策；既有缓存 / 原子事实写入 / 提交后恢复保留。具体历史读取、学习来源元数据和可重建个人模型的持久化位置均待Q-037，原TIME-01“不新增字段”不构成拒绝新学习需求的依据，也不是本轮新增表 / 迁移的授权。模型预测不得成为SleepSession、Unknown或Gap事实源，不将其当正式占用。此轮只更新设计追溯，不修改存储。

### TIME-04睡眠学习辅助存储（2026-10-07）

用户已确认推荐睡眠模型与参数，具体实施见[TIME-04](../planning/SLEEP_TIME_PREDICTION.md)。工程实现复用睡眠草稿独立连接，schema从2升到3：`sleep_drafts.prediction_origin`保存本次模型初值 / 类型 / 版本，独立`睡眠ID → 学习反馈`表保存实际提交端点及当地UTC offset。不是SleepSession字段、正式统计或缓存模型事实；正式五表schema保持2。旧v1 / v2草稿升级保留原输入，历史来源未知不伪造手改信息。

正式SleepSession先按原原子合同提交，再在辅助库同一事务写学习反馈并清草稿。辅助失败不能撤销正式事实；保留草稿，先识别既有提交再重试辅助事务，不再次创建睡眠。更正后的当前事实与已保存端点逐端比较重新赋学习权重，删除的事实不再训练；旧反馈行不成为已删除睡眠的占用。高级数据清空同时清除这些辅助信息，普通放弃草稿不删除已提交反馈。

模型每次从现存完整已发生睡眠重建训练样本；以最近独立信息为学习窗口锚点，优先保留独立样本，并按各端预算压低原样沿用预测。具体模型不持久化为统计快照，不依赖updatedAt猜测时间修改。普通活动及睡眠正式写入仍执行跨表原子不重叠。

正式保存仍须满足全部领域和原子写入约束；正式提交成功后清除对应草稿，失败保留，用户主动放弃时清除。具体存储机制由对应实现任务落实，不在本次文档决定中引入依赖。Android 关闭后恢复与 Web 刷新后恢复均需在对应任务取得实际验证证据。

## Schema 产品决定状态

原列入 schema 定稿清单的 Q-005、Q-007、Q-013、Q-019 均已明确，按本文及对应领域合同落实。产品问题已解决不代表 schema 已实现或平台验证已通过。

Q-021 已确定摘要缺失表达；记录存在性、实际时长和近似标志均从事实派生，不新增持久化汇总字段。Q-009 已确定当前日截至当前时刻、未来日期无缺口及首尾空白纳入的对账窗口政策，不新增持久化汇总字段。Q-003 已确定双向更正时保留已有字段和解释，不通过建表默认值自动清空；通用操作合同仍见 Q-013。

Q-022 已确定首发平台为 Android 和 Web，因此不再属于 schema 的产品待决项。驱动、包及 Web 本地存储实现已完成 E2-T01 核验并获批准，见上文工程选型；两个首发平台的运行证据仍按 E2-T02 及后续任务分别验收，平台决定本身不等于技术验证完成。

## 本阶段自检基准

E2-T03 建立首版五表及上述四个额外索引，Drift `schemaVersion = 2`。版本 1 是 E2-T02 已可创建的空连接库，升级到版本 2 时在事务内建立五表与索引；全新库使用相同定义。未支持的版本变化拒绝打开，不静默降级。此版本处理不涉及历史 V3 / V3.5 数据迁移，也不表示后续 repository、跨表重叠和重启验收已完成。验证记录见 [E2-T03 报告](../reports/E2-T03_SCHEMA_REPORT.md)。

五个对象均有逐列映射，optional 字段没有升级成记录门槛。没有强制 unknown.title 为空，没有把 SleepSession 塞入 recovery，没有持久化 Gap / Day / 统计，也没有把 intendedDate 重复存储。检查式明确处理 known.title 的 NULL 情况；不重叠通过单一事务写入边界协调而非仅靠逐表校验。
