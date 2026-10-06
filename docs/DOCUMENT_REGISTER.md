# 项目文档台账

整理日期：2026-10-07（Asia/Shanghai）。用途：统一说明开发文档的职责、有效性、保留方式与查阅入口。本文只做文档管理，不新增产品决定、执行任务或验收结论。

## 1. 定性规则与并行工作边界

| 定性 | 含义 | 处理方式 |
| --- | --- | --- |
| 现行依据 | 在指定职责内用于当前产品、领域或工程判断 | 保留并按决定追溯维护；工程建议不等于产品要求 |
| 持续维护 | 导航、任务索引、问题登记、当前设计交接 | 保持入口稳定，阶段变化由负责该工作的 agent 更新 |
| 历史归档 | 已完成任务定义、被替代或暂停的方案 | 本次采用原地逻辑归档；保留正文与链接，不作为新任务入口 |
| 验证证据 | 某任务、版本或时点的交付、检查与审查记录 | 按日期、提交和范围引用；不得推断当前工作区通过 |
| 原型参考 | HTML、截图、模拟流程、素材 | 保留来源与轮次；确认仅对其明确范围有效 |

**归档不等于完成、通过或撤销决定。** 未完成但已暂停的旧方案可归档为历史方案；不能将其任务改为 COMPLETE。旧方案中的已确认产品决定仍按源提案、对应职责文档及问题登记追溯。

本次盘点的提交基准为 `3f5dd75`，但工作区有另一个 agent 的未提交代码、测试、`OPEN_QUESTIONS.md` 修改及 UI 复核材料。因此这是一份文档盘点快照，不是该提交或工作区的工程验收。本次只新增本台账并整理根 README、docs README；不移动、删除、重命名旧文档，不改任务、领域文档、审查原件或其他 agent 的代码。

盘点范围：仓库内开发用途的 Markdown 文档，以及它们对应的 HTML 原型和证据目录；构建产物、工具缓存、第三方依赖及仓库外临时文件不纳入管理清单。本次盘点原有 Markdown 文档 106 份（含 74 份交付报告），新增本台账后共 107 份。报告逐文件列出，截图、日志、JSON、图标等按所属证据包管理。

## 2. 从哪里开始

| 目的 | 阅读顺序 |
| --- | --- |
| 理解产品与领域 | 源提案最新决定 → 对应领域 / 产品文档 → OPEN_QUESTIONS 对应条目 |
| 判断合法状态、计算或持久化 | DOMAIN_RULES → DOMAIN_MODEL → 状态机 / DERIVED_MODELS → 架构文档 |
| 接续当前前端设计 | UI_REBUILD_PLAN → 它引用的最新轮次素材 → OPEN_QUESTIONS；实现进度另核任务与新交付证据 |
| 查任务及历史完成依据 | TASKS → COMPLETED_TASKS 对应完整定义 → reports 对应报告 |
| 查二级界面问题 | 首轮审查 → 指定提交复核 → 后续修复的独立验证记录 |
| 判断文档能否归档 | 先查下方定性及替代关系；现行规则和未决事项持续保留 |

来源优先级沿用 [AGENTS](../AGENTS.md#source-of-truth-priority)：源提案 → 规则 → 对象 → 生命周期 / 派生计算 → 产品原则 → 产品定义 → 架构 → MVP / Epic 计划 → 任务。OPEN_QUESTIONS 贯穿各层；本台账不进入产品权威排序。

## 3. 基础与现行文档

| 文档 | 定性 | 职责与维护提醒 |
| --- | --- | --- |
| [根 README](../README.md) | 持续维护 | 项目介绍及统一文档入口；原 Flutter 模板说明已由本次整理替换 |
| [docs README](README.md) | 持续维护 | 文档目录入口；定性集中在本台账，避免重复维护阶段结论 |
| [本台账](DOCUMENT_REGISTER.md) | 持续维护 | 文档定性、查阅与归档关系；不代替任务状态表 |
| [AGENTS](../AGENTS.md) | 现行依据 | Agent 工作方式、范围、来源优先级及完成门槛；不定义产品功能 |
| [领域源提案](../time-ledger-domain-model-v4-proposal.md) | 现行依据 | 产品 / 领域 Source of Truth；先读顶部后续决定，原章节保留历史表达，不能单凭标题含“proposal”归档 |
| [DOMAIN_RULES](domain/DOMAIN_RULES.md) | 现行依据 | 不变量、合法性、校验与业务规则；稳定规则编号 |
| [DOMAIN_MODEL](domain/DOMAIN_MODEL.md) | 现行依据 | 对象、字段、关系与事实来源 |
| [DOMAIN_STATE_MACHINES](domain/DOMAIN_STATE_MACHINES.md) | 现行依据 | 生命周期、转换权限与更正行为 |
| [DERIVED_MODELS](domain/DERIVED_MODELS.md) | 现行依据 | 自然日切片、Gap、覆盖、睡眠及目标统计计算 |
| [OPEN_QUESTIONS](domain/OPEN_QUESTIONS.md) | 持续维护 | 未决事项与后续决定的稳定编号登记；逐项看 Decision / Current status，不靠顶部旧摘要推断全表状态；另一个 agent 正在修改 |
| [PRODUCT_PRINCIPLES](product/PRODUCT_PRINCIPLES.md) | 现行依据 | 产品取舍与交互原则 |
| [PRODUCT_DEFINITION](product/PRODUCT_DEFINITION.md) | 现行依据 | 产品问题、核心闭环与边界 |
| [APP_ARCHITECTURE](architecture/APP_ARCHITECTURE.md) | 现行依据（含历史现状） | 代码职责与依赖方向；开头“只有 Flutter 最小入口 / 只有 Flutter 依赖”已过时，不用于判断工程现状 |
| [DATA_ARCHITECTURE](architecture/DATA_ARCHITECTURE.md) | 现行依据（设计合同） | 五表、映射、约束及原子一致性；“本轮不创建数据库”属于编写阶段边界，非当前实现状态；区分工程建议 |
| [Web 持久化资产](../web/PERSISTENCE_ASSETS.md) | 现行依据（工程说明） | 配套 SQLite / Drift 资产、来源、哈希与部署条件；升级时与实际资产一起核验，不由本次盘点重认版本兼容性 |
| [MVP_SCOPE](planning/MVP_SCOPE.md) | 现行依据 | 首版范围与 Explicitly Out of Scope；未因旧 UI 暂停而失效 |
| [IMPLEMENTATION_PLAN](planning/IMPLEMENTATION_PLAN.md) | 现行依据（业务规划） | Epic 顺序、依赖与交付合同；其中日期和“本次不执行”属阶段记录，不作为当前进度表或前端施工路线 |
| [TASKS](../TASKS.md) | 持续维护（含历史索引） | 任务定义、完成入口及依赖；顶部设计阶段说明与正在变动的实现需由实施负责人对齐，本文不重判完成或授权 |
| [COMPLETED_TASKS](planning/COMPLETED_TASKS.md) | 历史归档 | 已移出的 77 项完整任务定义；已归档，不重复搬迁；完成证据以 TASKS 和具体报告核对 |
| [UI_REBUILD_PLAN](planning/UI_REBUILD_PLAN.md) | 持续维护（当前前端交接） | 当前设计入口，含轮次、确认、素材及待评审项；内部早期“未实施 Flutter”及 Q 状态不能直接代表正在变化的工作区 |
| [TIME_RECORDING_AUTOMATION](planning/TIME_RECORDING_AUTOMATION.md) | 现行依据（当前实施任务） | 2026-10-07用户授权TIME-01，来源Q-032 / Q-035；时间初始化与直接组件编辑，状态和验证查正文 |
| [DATE_TIME_EDITING](planning/DATE_TIME_EDITING.md) | 现行依据（本轮实施） | TIME-02用户授权补齐全应用日期 / 时间独立直达，Q-038覆盖手动串联；与时间初始化 / 学习算法分开 |
| [LONG_GAP_ACTIVITY_INITIALIZATION](planning/LONG_GAP_ACTIVITY_INITIALIZATION.md) | 现行依据（本轮实施） | TIME-03只实施Q-037已确认5小时 / 60分钟分支，后续睡眠首版另沿TIME-04，不改本任务历史结果 |
| [SLEEP_TIME_PREDICTION](planning/SLEEP_TIME_PREDICTION.md) | 现行依据（本轮实施） | TIME-04修复整段多日Gap睡眠初值，采用用户已批准的个人睡眠模型和参数 |

## 4. 旧设计与计划：原地逻辑归档

旧方案已在 [TASKS](../TASKS.md) 与原 [文档导航](README.md) 的整理前版本中暂停 / 分类为历史；部分文件顶部也明确标记“历史参考，暂停执行”。本次统一其管理定性，保留原验收记录和任务 ID。

| 文档 | 定性 | 被替代 / 承接关系与保留理由 |
| --- | --- | --- |
| [UI_DIRECTION_3_IMPLEMENTATION_PLAN](planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md) | 历史归档 | 早期方案三与 UI-T 规划；当前前端设计由 UI_REBUILD_PLAN 承接，UI-T01–04 交付仍查原报告 |
| [ui-direction-3-navigation-spec](planning/ui-direction-3-navigation-spec.md) | 历史归档 | 早期深蓝 / 青色主题标注和当时未确认项；不作为当前米色 / 砖红设计入口 |
| [PRODUCT_PAGE_SYSTEM_DESIGN](planning/PRODUCT_PAGE_SYSTEM_DESIGN.md) | 历史归档 | 旧页面体系、流程与设计确认记录；文件明确暂停，当前整体设计转至 UI_REBUILD_PLAN |
| [UI_IMPLEMENTATION_DESIGN](planning/UI_IMPLEMENTATION_DESIGN.md) | 历史归档 | 旧原型还原标准及展示修订；文件明确暂停，已登记的领域 / 展示决定仍需追溯保留 |
| [UI_IMPLEMENTATION_TASKS](planning/UI_IMPLEMENTATION_TASKS.md) | 历史归档（含未完成任务） | PAGE-T01–T09 旧路线暂停；不继续自动执行，未通过、部分交付及待执行状态保留 |
| [PAGE_T01_RESTORATION_CHECKLIST](planning/PAGE_T01_RESTORATION_CHECKLIST.md) | 历史归档 | 旧六屏还原清单和可操作视觉夹具；对应 PAGE-T01 报告，不作为新路线验收清单 |
| [GUIDED_RECORDING_DESIGN](planning/GUIDED_RECORDING_DESIGN.md) | 历史归档（含决定追溯） | 三幕 v0.2 及样板反馈；明确暂停，最新反馈转入 UI_REBUILD_PLAN；旧精度选择、外露更换按钮、时间绕行不能照搬 |
| [design-qa](../design-qa.md) | 验证证据（历史样板） | RB-01 内存预览交付与 blocked 记录；127.0.0.1 和 /tmp 为当时环境，不宣称当前可访问，不作为正式持久化交付 |
| [活动原型 README](../prototypes/activity-editor/README.md) | 原型参考（历史） | 本地 HTML 原型说明；localStorage 与模拟响应不读写 Flutter 正式库 |
| [活动原型 QA](../prototypes/activity-editor/QA.md) | 验证证据（历史原型） | 2026-10-05 原型检查；模拟键盘 / 保存通过不等于真实平台或数据库通过 |

## 5. 审查记录与材料包

| 入口 | 定性 | 证据边界与关系 |
| --- | --- | --- |
| [二级界面首轮审查](audits/2026-10-06-secondary-ui/README.md) | 验证证据 | 当次 Web 观察与问题建议；保留 UI 编号用于复核，不因修复自动抹掉原问题 |
| [首轮详细表格](audits/2026-10-06-secondary-ui/TABLES.md) | 验证证据 | 同一审查的表格呈现，与 README / 画廊 / audit-data.json 共属一个证据包，非另一套产品规范 |
| [3f5dd75 修改复核](audits/2026-10-06-secondary-ui-recheck-3f5dd75/README.md) | 验证证据（盘点时未跟踪） | 对照 38f8ffe 与 3f5dd75；17 项中 11 项达到该复核范围、6 项部分完成。只对该版本和接受的状态有效，不判定另一个 agent 的新修改 |
| [首轮画廊](audits/2026-10-06-secondary-ui/index.html)、[复核画廊](audits/2026-10-06-secondary-ui-recheck-3f5dd75/index.html) | 验证证据 | 各自截图、JSON、文本快照与 validation 文件原包保留，避免拆散截图编号及引用 |

## 6. 交付报告逐文件索引

以下报告统一定性为 **验证证据（历史交付）**，按原路径保留。不统一改写它们原有的 COMPLETE、PARTIAL、blocked 或验收结论。表中名称来自原报告标题；详尽命令、执行者、失败与补充证据仍以正文为准。

尤其保留这些区分：E0 基线任务交付与基线通过不同；E3 部分正式测试证据由用户补充；HOME-IMPL-01 的 R06 确认只覆盖对应睡眠详情；EDITOR-IMPL-01 记录视觉验收未通过；PAGE-T01 任务交付不等于页面视觉通过；UI-T04 有验证限制；GUIDED_RECORDING_DESIGN_REVIEW 是审查，不是认可。

| 报告 | 内容入口 |
| --- | --- |
| [TIME-01_TIME_AUTOMATION_REPORT](reports/TIME-01_TIME_AUTOMATION_REPORT.md) | 2026-10-07 活动 / 睡眠时间日期自动化；实现交付与平台验收限制 |
| [TIME-02_DATE_TIME_EDITING_REPORT](reports/TIME-02_DATE_TIME_EDITING_REPORT.md) | 日期 / 时间独立字段、全入口清理与实际验证限制 |
| [TIME-03_LONG_GAP_ACTIVITY_REPORT](reports/TIME-03_LONG_GAP_ACTIVITY_REPORT.md) | 长Gap后的普通活动初值、跨日 / 缓存 / 剩余Gap与实际验证 |
| [TIME-04_SLEEP_PREDICTION_REPORT](reports/TIME-04_SLEEP_PREDICTION_REPORT.md) | 用户已批准的个人睡眠初值、辅助反馈 / 迁移、跨日 / 类型与真实存储验证 |
| [E0-T01_BASELINE_REPORT](reports/E0-T01_BASELINE_REPORT.md) | E0-T01 工程与验证基线完成报告 |
| [E2-T01_DRIVER_REPORT](reports/E2-T01_DRIVER_REPORT.md) | E2-T01 — 核验持久化驱动选择 |
| [E2-T02_PERSISTENCE_CONNECTION_REPORT](reports/E2-T02_PERSISTENCE_CONNECTION_REPORT.md) | E2-T02 — 接入单库连接与测试环境 |
| [E2-T03_SCHEMA_REPORT](reports/E2-T03_SCHEMA_REPORT.md) | E2-T03 — 建立五表首版 schema 与约束 |
| [E2-T04_GOAL_REPOSITORY_REPORT](reports/E2-T04_GOAL_REPOSITORY_REPORT.md) | E2-T04 — 实现 Goal 存取边界 |
| [E2-T05_LEDGER_READ_REPORT](reports/E2-T05_LEDGER_READ_REPORT.md) | E2-T05 — 实现账本一致读取与行映射 |
| [E2-T06_ATOMIC_LEDGER_WRITE](reports/E2-T06_ATOMIC_LEDGER_WRITE.md) | E2-T06 — 实现受控账本原子写入 |
| [E2-T07_REVIEW_REPOSITORY_REPORT](reports/E2-T07_REVIEW_REPOSITORY_REPORT.md) | E2-T07 — 实现按日复盘存取 |
| [E2-T08_FULL_PERSISTENCE_REPORT](reports/E2-T08_FULL_PERSISTENCE_REPORT.md) | E2-T08 — 验证存储重开与完整持久化边界 |
| [E3-T01_PROJECTION_CONTRACT_REPORT](reports/E3-T01_PROJECTION_CONTRACT_REPORT.md) | E3-T01 — 对账窗口与派生时长基础合同 |
| [E3-T02_FACT_SLICING_REPORT](reports/E3-T02_FACT_SLICING_REPORT.md) | E3-T02 — 实现事实切片与边界精度传播 |
| [E3-T03_LEDGER_COVERAGE_REPORT](reports/E3-T03_LEDGER_COVERAGE_REPORT.md) | E3-T03 — 实现 Gap 与账本覆盖汇总 |
| [E3-T04_GOAL_RHYTHM_SUMMARY_REPORT](reports/E3-T04_GOAL_RHYTHM_SUMMARY_REPORT.md) | E3-T04 — 实现节奏与目标时间汇总 |
| [E3-T05_SLEEP_SUMMARY_REPORT](reports/E3-T05_SLEEP_SUMMARY_REPORT.md) | E3-T05 — 实现完整睡眠摘要与已记录判定 |
| [E3-T06_DAY_LEDGER_VIEW_REPORT](reports/E3-T06_DAY_LEDGER_VIEW_REPORT.md) | E3-T06 — 组装 DayLedgerView 并核验派生关系 |
| [E3-T07_SUMMARY_FORMATTING_REPORT](reports/E3-T07_SUMMARY_FORMATTING_REPORT.md) | E3-T07 — 实现摘要展示语义的纯映射 |
| [E4-T01_RECORDING_LEDGER_READ_REPORT](reports/E4-T01_RECORDING_LEDGER_READ_REPORT.md) | E4-T01 — 接通普通记录的日期上下文与投影读取 |
| [E4-T02_TIME_SUGGESTION_REPORT](reports/E4-T02_TIME_SUGGESTION_REPORT.md) | E4-T02 — 实现普通入口的时间建议分支 |
| [E4-T03_RECORDING_DRAFT_STORE_REPORT](reports/E4-T03_RECORDING_DRAFT_STORE_REPORT.md) | E4-T03 — 实现普通记录本机草稿存储 |
| [E4-T04_RECORDING_FORM_REPORT](reports/E4-T04_RECORDING_FORM_REPORT.md) | E4-T04 — 实现活动优先表单与草稿生命周期 |
| [E4-T05_RECORDING_SUBMISSION_REPORT](reports/E4-T05_RECORDING_SUBMISSION_REPORT.md) | E4-T05 — 接通正式新建保存、冲突反馈与刷新 |
| [E4-T06_TIME_BLOCK_CORRECTION_REPORT](reports/E4-T06_TIME_BLOCK_CORRECTION_REPORT.md) | E4-T06 — 接通已有 TimeBlock 更正与删除 |
| [E4-T07_BASIC_RECORDING_FLOW_REPORT](reports/E4-T07_BASIC_RECORDING_FLOW_REPORT.md) | E4-T07 — 验证普通记录完整应用闭环 |
| [E4-T08_ANDROID_WEB_RECORDING_RECOVERY_REPORT](reports/E4-T08_ANDROID_WEB_RECORDING_RECOVERY_REPORT.md) | E4-T08 — 验证 Android 与 Web 的保存和草稿恢复 |
| [E4-T09_OPTIONAL_TIME_BLOCK_NOTE_REPORT](reports/E4-T09_OPTIONAL_TIME_BLOCK_NOTE_REPORT.md) | E4-T09 — 提供普通记录可选备注入口 |
| [E5-T01_SLEEP_LEDGER_READ_REPORT](reports/E5-T01_SLEEP_LEDGER_READ_REPORT.md) | E5-T01 — 接通睡眠日期上下文与完整摘要读取 |
| [E5-T02_SLEEP_DRAFT_STORE_REPORT](reports/E5-T02_SLEEP_DRAFT_STORE_REPORT.md) | E5-T02 — 实现睡眠本机草稿存储 |
| [E5-T03_SLEEP_FORM_REPORT](reports/E5-T03_SLEEP_FORM_REPORT.md) | E5-T03 — 实现独立睡眠表单与草稿生命周期 |
| [E5-T04_SLEEP_SUBMISSION_REPORT](reports/E5-T04_SLEEP_SUBMISSION_REPORT.md) | E5-T04 — 接通睡眠新建、冲突反馈与刷新 |
| [E5-T05_SLEEP_CORRECTION_REPORT](reports/E5-T05_SLEEP_CORRECTION_REPORT.md) | E5-T05 — 接通睡眠更正与删除 |
| [E5-T06_FIRST_SLEEP_CONFIRMATION_REPORT](reports/E5-T06_FIRST_SLEEP_CONFIRMATION_REPORT.md) | E5-T06 — 实现每日首次打开的主睡眠确认 |
| [E5-T07_SLEEP_RECORDING_FLOW_REPORT](reports/E5-T07_SLEEP_RECORDING_FLOW_REPORT.md) | E5-T07 — 验证睡眠记录应用闭环 |
| [E5-T08_ANDROID_WEB_SLEEP_RECOVERY_REPORT](reports/E5-T08_ANDROID_WEB_SLEEP_RECOVERY_REPORT.md) | E5-T08 — 验证 Android 与 Web 睡眠保存和恢复 |
| [E5-T09_OPTIONAL_SLEEP_NOTE_REPORT](reports/E5-T09_OPTIONAL_SLEEP_NOTE_REPORT.md) | E5-T09 — 提供睡眠可选备注入口 |
| [E6-T01_DAY_LEDGER_ENTRY_REPORT](reports/E6-T01_DAY_LEDGER_ENTRY_REPORT.md) | E6-T01 — 接通日账本页面的日期选择与读取状态 |
| [E6-T02_DAY_LEDGER_TIMELINE_REPORT](reports/E6-T02_DAY_LEDGER_TIMELINE_REPORT.md) | E6-T02 — 呈现事实切片与派生 Gap 时间轴 |
| [E6-T03_GAP_RECORDING_REPORT](reports/E6-T03_GAP_RECORDING_REPORT.md) | E6-T03 — 接通 Gap 预填与明确确认 Unknown |
| [E6-T04_TIMELINE_EDITING_REPORT](reports/E6-T04_TIMELINE_EDITING_REPORT.md) | E6-T04 — 接通时间轴原事实更正与删除 |
| [E6-T05_DAY_LEDGER_RESOLUTION_REPORT](reports/E6-T05_DAY_LEDGER_RESOLUTION_REPORT.md) | E6-T05 — 验证时间轴与补账完整应用闭环 |
| [E6-T06_DAY_LEDGER_PLATFORM_REPORT](reports/E6-T06_DAY_LEDGER_PLATFORM_REPORT.md) | E6-T06 — 验证 Android 与 Web 时间轴补账集成 |
| [E7-T01_GOAL_CREATION_READ_REPORT](reports/E7-T01_GOAL_CREATION_READ_REPORT.md) | E7-T01 — 接通简单目标创建与读取 |
| [E7-T02_GOAL_LIFECYCLE_REPORT](reports/E7-T02_GOAL_LIFECYCLE_REPORT.md) | E7-T02 — 接通目标改名归档恢复与删除 |
| [E7-T03_OPTIONAL_GOAL_ASSOCIATION_REPORT](reports/E7-T03_OPTIONAL_GOAL_ASSOCIATION_REPORT.md) | E7-T03 — 接通普通记录的可选目标归属 |
| [E7-T04_OPTIONAL_RHYTHM_REPORT](reports/E7-T04_OPTIONAL_RHYTHM_REPORT.md) | E7-T04 — 接通可选节奏解释与接续点 |
| [E7-T05_TIMELINE_GOAL_RHYTHM_REPORT](reports/E7-T05_TIMELINE_GOAL_RHYTHM_REPORT.md) | E7-T05 — 在时间轴呈现目标节奏与接续点 |
| [E7-T06_GOAL_RHYTHM_CLOSURE_REPORT](reports/E7-T06_GOAL_RHYTHM_CLOSURE_REPORT.md) | E7-T06 — 验证目标与节奏完整应用闭环 |
| [E7-T07_GOAL_RHYTHM_PLATFORM_REPORT](reports/E7-T07_GOAL_RHYTHM_PLATFORM_REPORT.md) | E7-T07 — 验证 Android 与 Web 目标节奏集成 |
| [E7-T08_OPTIONAL_RHYTHM_DETAILS_REPORT](reports/E7-T08_OPTIONAL_RHYTHM_DETAILS_REPORT.md) | E7-T08 — 提供可选原因与恢复细节入口（Should Have） |
| [E8-T01_SUMMARY_CONTEXT_REPORT](reports/E8-T01_SUMMARY_CONTEXT_REPORT.md) | E8-T01 — 接通摘要日期上下文与一致读取 |
| [E8-T02_COVERAGE_SUMMARY_REPORT](reports/E8-T02_COVERAGE_SUMMARY_REPORT.md) | E8-T02 — 呈现账本覆盖与 Unknown 摘要 |
| [E8-T03_SLEEP_SUMMARY_REPORT](reports/E8-T03_SLEEP_SUMMARY_REPORT.md) | E8-T03 — 呈现完整睡眠背景摘要 |
| [E8-T04_GOAL_RHYTHM_SUMMARY_REPORT](reports/E8-T04_GOAL_RHYTHM_SUMMARY_REPORT.md) | E8-T04 — 呈现目标四项细分与全局节奏摘要 |
| [E8-T05_SUMMARY_RECALCULATION_REPORT](reports/E8-T05_SUMMARY_RECALCULATION_REPORT.md) | E8-T05 — 验证摘要随事实与解释变化重算 |
| [E8-T06_SUMMARY_PLATFORM_REPORT](reports/E8-T06_SUMMARY_PLATFORM_REPORT.md) | E8-T06 — 验证 Android 与 Web 基础摘要 |
| [E9-T01_REVIEW_CONTEXT_REPORT](reports/E9-T01_REVIEW_CONTEXT_REPORT.md) | E9-T01 — 接通按日复盘读取与上下文 |
| [E9-T02_REVIEW_DRAFT_STORE_REPORT](reports/E9-T02_REVIEW_DRAFT_STORE_REPORT.md) | E9-T02 — 实现独立复盘本机草稿存储 |
| [E9-T03_REVIEW_FORM_REPORT](reports/E9-T03_REVIEW_FORM_REPORT.md) | E9-T03 — 实现复盘表单与草稿生命周期 |
| [E9-T04_REVIEW_SUBMISSION_REPORT](reports/E9-T04_REVIEW_SUBMISSION_REPORT.md) | E9-T04 — 接通复盘新建保存与失败反馈 |
| [E9-T05_REVIEW_CORRECTION_REPORT](reports/E9-T05_REVIEW_CORRECTION_REPORT.md) | E9-T05 — 接通复盘原地更正与日期变更 |
| [E9-T06_REVIEW_DELETION_REPORT](reports/E9-T06_REVIEW_DELETION_REPORT.md) | E9-T06 — 接通复盘删除与返回读取 |
| [E9-T07_REVIEW_ROUTE_REPORT](reports/E9-T07_REVIEW_ROUTE_REPORT.md) | E9-T07 — 贯通日账本复盘与下一步回看 |
| [E9-T08_REVIEW_CLOSURE_REPORT](reports/E9-T08_REVIEW_CLOSURE_REPORT.md) | E9-T08 — 验证复盘完整应用闭环与失败恢复 |
| [E9-T09_REVIEW_PLATFORM_REPORT](reports/E9-T09_REVIEW_PLATFORM_REPORT.md) | E9-T09 — 验证 Android 与 Web 复盘保存和恢复 |
| [EDITOR_IMPL_01_REPORT](reports/EDITOR_IMPL_01_REPORT.md) | EDITOR-IMPL-01 · 三编辑页实施 |
| [EPIC_0_1_COMPLETION](reports/EPIC_0_1_COMPLETION.md) | Epic 0 / Epic 1 完成记录 |
| [GUIDED_RECORDING_DESIGN_REVIEW](reports/GUIDED_RECORDING_DESIGN_REVIEW.md) | 活动问答样板设计审查 |
| [HOME_DISPLAY_CLEANUP_REPORT](reports/HOME_DISPLAY_CLEANUP_REPORT.md) | 首页信息去重与全应用近似前缀 |
| [HOME_IMPL_01_REPORT](reports/HOME_IMPL_01_REPORT.md) | HOME-IMPL-01 · 主页样板实施进展 |
| [PAGE_T01_REPORT](reports/PAGE_T01_REPORT.md) | PAGE-T01 · 还原清单与可操作视觉夹具 |
| [PAGE_T02_REPORT](reports/PAGE_T02_REPORT.md) | PAGE-T02 · 活动编辑返工 |
| [UI_T01_TIMELINE_REPORT](reports/UI_T01_TIMELINE_REPORT.md) | UI-T01 — 日账本连续时间轴 |
| [UI_T02_THEME_REPORT](reports/UI_T02_THEME_REPORT.md) | UI-T02 深蓝主题与基础视觉样式 |
| [UI_T03_OVERVIEW_REPORT](reports/UI_T03_OVERVIEW_REPORT.md) | UI-T03 日账本头部与时间分布交付报告 |
| [UI_T04_NAVIGATION_REPORT](reports/UI_T04_NAVIGATION_REPORT.md) | UI-T04 根导航交付报告 |

## 7. 原型与非 Markdown 素材

| 入口 / 材料包 | 定性 | 处理方式 |
| --- | --- | --- |
| [旧首页校准](planning/home-visual-calibration-spec.html)、[旧编辑规格](planning/editor-visual-spec.html)、[输入校准](planning/editor-input-calibration.html) | 原型参考（历史） | 对应旧样板与还原路线；同名“spec”不赋予其当前产品权威 |
| [阅读与管理](planning/reading-management-visual-spec.html)、[核心流程线框](planning/product-core-flow-wireframes.html)、[低成本记录线框](planning/low-friction-recording-wireframe.html) | 原型参考（历史） | 设计演变和旧流程比对，不作为当前施工路线 |
| [activity-editor](../prototypes/activity-editor/index.html)、[activity-editor-v2](../prototypes/activity-editor-v2/index.html) | 原型参考（历史） | 原型文件、脚本、样式、图标及截图一起保留；版本号 v2 本身不表示最终认可 |
| [首页 / 摘要认可快照](planning/assets/home-summary-round-one/approved-preview-fragment.html) | 原型参考（有局部确认） | 用户参考图、认可范围及限制查 UI_REBUILD_PLAN；不等于整个应用验收 |
| [活动第一轮](planning/assets/activity-three-steps/prototype-fragment.html)、[活动第二轮](planning/assets/activity-three-steps/prototype-fragment-v2.html) | 原型参考（分轮追溯） | 第一轮对应布局被第二轮反馈调整；仍保留两轮，不把第二轮所有细节自动记为确认 |
| [睡眠第一轮](planning/assets/sleep-recording-round-one/prototype-fragment.html)、[详情第一轮](planning/assets/record-detail-round-one/prototype-fragment.html) | 原型参考 | 当前交接引用的独立片段；业务响应为模拟，确认边界查交接 |
| [目标第一轮](planning/assets/goal-management-round-one/prototype-fragment.html)、[目标第二轮](planning/assets/goal-management-round-two/prototype-fragment.html) | 原型参考（分轮追溯） | 同时保留演变证据；日期范围等规则回到 Q-033，常用归档政策回到 Q-025 |
| [设置第一轮](planning/assets/settings-round-one/prototype-fragment.html) | 原型参考 | 布局方向与高级操作模拟；真实清空 / 注入不由原型授权，合同查 Q-034 |
| [贯通原型第一轮](planning/assets/app-flow-round-one/prototype-fragment.html) | 原型参考 | 跨页模拟数据、返回路径与设计评审；复盘占位不表示领域复盘未实现 |
| [reports/assets](reports/assets/)、[根 assets](../assets/) 及各原型的附属文件 | 随所属文档管理 | 报告截图、对照、图标或运行资产；按引用关系区分用途，不因目录叫 assets 就整体归档或删除 |

## 8. 本次发现的维护缺口

以下只记录文档维护事项，不授权当前或另一个 agent 增加开发范围，不替代 OPEN_QUESTIONS 的产品问题登记。

| 位置 | 已观察到的问题 | 由相应负责人接续的方式 |
| --- | --- | --- |
| TASKS / UI_REBUILD_PLAN 的阶段摘要 | 仍有“未启动 / 未实施 Flutter”的设计阶段表述，而本次工作区已有实现改动及指定提交复核 | 实施负责人交付时按实际范围、授权及验证更新；本次不抢改其状态 |
| UI_REBUILD_PLAN 的 Q-029 描述 | 部分段落仍写未决；OPEN_QUESTIONS 当前补充已说本轮决定，且该文件正在被另一个 agent 修改 | 等本轮决定登记稳定后，按 Q-029 逐项对齐交接；不通过本台账替产品定案 |
| APP_ARCHITECTURE 的现状说明 | “最小入口 / 只有 Flutter 依赖”是旧阶段快照 | 后续维护只更新现状描述，保留职责与工程建议的边界 |
| 旧方案中的 /tmp、localhost、仓库外可视化路径 | 存在环境依赖，当前可用性不能由历史报告证明 | 正式交接优先引用已保存的仓库快照；本次不下载、复制或恢复临时材料 |
| 审查与交付索引 | 既有导航未纳入二级 UI 首轮审查及指定提交复核 | 已在本台账补齐，保留两个版本的原证据 |

## 9. 后续维护约定

- 新增文档时，将其放入对应职责目录，在本台账增加定性、来源与承接关系；报告更新第 6 节逐文件索引，证据素材归入所属包。
- 现行规范不随某个任务完成而整体归档；已完成任务全文沿既有 TASKS → COMPLETED_TASKS 流程处理。
- 新设计替代旧设计时，记录替代范围与新入口；旧确认仅在被明确替代的范围内失效，不撤销未受影响的领域决定。
- 交付报告保留当时结果；后续复核用独立日期 / 提交记录关联，不将旧失败改写成一直通过。
- 本次已完成逻辑归档。若以后需要物理迁移，须在并行工作结束后核对全部相对链接、任务锚点、素材引用及外部入口，再迁移成套文件；本次没有执行物理迁移。
