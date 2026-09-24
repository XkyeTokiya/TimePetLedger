# MVP Scope

## 依据与范围判断

依据 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md) §1–3、§4–33、§38，以及 [PRODUCT_DEFINITION](../product/PRODUCT_DEFINITION.md)、[PRODUCT_PRINCIPLES](../product/PRODUCT_PRINCIPLES.md)。对象、合法状态、生命周期与计算分别引用 [DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)、[DOMAIN_RULES](../domain/DOMAIN_RULES.md)、[DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md)、[DERIVED_MODELS](../domain/DERIVED_MODELS.md)，不在本文重写规则。

**核心判断：用户是否能够低成本还原一天、理解目标相关时间，并留下下一次行动。** MVP 不是功能数量最少，也不是要求用户每天补齐所有 Gap、精确到每分钟或为全部时间添加解释。

**Domain Decision：** 产品语义与边界继承上述来源。**Planning Recommendation（不是源文档强制的发布优先级）：** 以下 Must / Should / Later 是为验证核心闭环提出的首版范围；不表示未决行为已经获准。技术选型继续使用架构文档中的 Engineering Recommendation。产品答案仅维护在 [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md)。

## Must Have

| 范围编号 | 用户能力与完成边界 | 依据 / 待决入口 |
| --- | --- | --- |
| M-01 低成本回顾记录 | 用户主要填写活动，系统提出可修改的时间区间；支持 known / unknown 和独立起止精度。目标、分类、节奏解释都不能成为普通记录的必填门槛 | TB-001–TB-009、LEDGER-010；非 Gap 入口的建议时间见 Q-023 |
| M-02 一天账本与缺口处理 | 在明确的自然日查询窗口呈现事实切片与派生 Gap；点击 Gap 后带入区间，补活动或确认 Unknown。Unknown 保存为事实且属于 accounted；可以留下未解决 Gap | LEDGER-001–LEDGER-005；Q-009、Q-014 |
| M-03 独立睡眠记录 | 支持 mainSleep / nap、近似边界、完整跨日事实；首次打开时优先确认睡眠，已经记录时不重复打扰。睡眠参与账本覆盖，但不变成 recovery | SL-001–SL-005；Q-010 |
| M-04 目标归属与可选节奏 | 可建立并选择简单 Goal，查看其时间归属；TimeBlock 可保持无解释，或由用户确认 progress / stuck / recovery。支持可选 continuationHint 的接续语义；不要求填写卡住原因或恢复细节 | GO-001、GO-002、RH-001–RH-008；Q-004、Q-005、Q-007、Q-019 |
| M-05 描述性基础摘要 | 呈现睡眠背景、已交代 / 未交代 / 其中 Unknown，以及目标相关时间与其中 progress / stuck；recovery 保持独立口径，显示适用的近似提示。摘要全部来自当前事实，不产生评分 | LEDGER-006–LEDGER-009、DERIVED_MODELS；Q-010、Q-014、Q-020、Q-021 |
| M-06 复盘与下一步 | 同一天至多一份 DailyReview，允许可选 summary / reflection，保留一个 TomorrowFirstStep 及可选 Goal 关联；和单段时间的 continuationHint 区分 | DR-001–DR-004；Q-013 |
| M-07 可靠保存与一致反馈 | 首发平台上事实和复盘能够保存、重新读取；失败不显示成功；重叠不被静默保存，重算结果反映成功提交的事实。具体纠错交互与更正 / 删除能力按产品答案落实 | LEDGER-004；APP_ARCHITECTURE、DATA_ARCHITECTURE；Q-003、Q-005、Q-013、Q-022 |

M-04 的 active / archived 值域已由 Q-006 细化为创建、归档、恢复、引用、删除和改名合同；这不扩展为任务管理。M-07 同样不授权任意 CRUD、自动覆盖冲突、拆分事实或级联删除。Q-003、Q-005、Q-013 尚未确认的操作仍不能在验收时悄悄补齐，也不能凭规划自行选择。

### 闭环验收场景

用户能记录跨日睡眠，在当天看到其切片；补记普通活动和目标相关时间，选择需要的节奏解释，允许其他记录不标记；将一段缺口确认成 Unknown，并允许另一段继续保持 Gap；查看不带评价的时间摘要；最后留下复盘和下一步。关闭并重新进入应用后，已提交事实仍存在，账本与摘要从事实重新计算。

此场景允许 approximate、可选文字留空、无目标的普通活动与未解决缺口。它不以全日零 Gap、每日复盘打卡或填写全部字段为通过条件。跨日、缺口和时长计算用 DERIVED_MODELS 的示例及边界合同验证，不复制另一套公式。

## Should Have

以下改善同一闭环，未完成时不应阻止已确定核心能力的验证：

- 为普通记录和睡眠提供可选 note 的便利编辑入口，避免增加主记录路径的必填步骤。
- 提供可选 stuckReasonCode / stuckReasonText、recoveryMethod / recoveryQuality 的补充入口；仅在 Q-007 的值域与类型、Q-005 的适用状态明确后交付。

这里延后的是补充输入体验，不是擅自删除领域字段或绕过正式 schema 的未决类型。首版完整 schema 仍按 DATA_ARCHITECTURE 的定稿条件完成。

## Later

当前没有另行批准的新产品能力。先验证上述闭环，再依据真实使用情况安排同一记录流程的进一步简化与摘要呈现改进；具体方案届时另行定义，不进入本轮 Epic 验收。

Should Have 中未交付的入口可以后续排期，但不是自动启动下一轮开发的授权。下列 Explicitly Out of Scope 能力也不会因为处于 Later 阶段而自动进入范围。

## Explicitly Out of Scope

Source of Truth 明确排除或暂未纳入核心的能力：

- timer-first、minute-perfect tracking、并行主要活动时间线或多任务分摊。
- task manager、habit tracker、streak、失败天数、任务树、里程碑、deadline / completion percentage / priority 等项目管理能力，以及每天为全部 Goal 安排行动。
- productivity / efficiency / completeness 评分，自动评价用户是否有效、无用活动枚举，以及因果式睡眠分析。
- 复杂分类和首版分类管理；首版保留可空 categoryId 扩展字段，但不提供分类功能。
- 睡眠质量输入、长期睡眠趋势、nap 与 recovery 的关联，以及自动判定进展或恢复效果。
- 将 keyProgress / mainStuckPoint / recoveryObservation 等候选复盘字段扩展为首版强制结构。

**Planning / Engineering boundary（不是新增产品结论）：** 本轮也不安排账号、云同步、AI 分析服务、外部数据导入、通用插件平台或庞大设计系统；现有来源没有授权这些交付物。退出后恢复草稿见 Q-012，尚不作为首版承诺，不因此新增领域 draft 状态。

## 发布边界与范围控制

首发平台确定为 Android 和 Web（Q-022）。iOS、Linux、macOS、Windows 不纳入首发支持与验收范围；仓库已有平台目录或本机可运行设备不会扩大该范围。Must Have 是待实现的目标，不是所有相关问题已解决的声明：涉及的其他产品合同须先确定，未决问题只阻塞相应能力；已确定的领域与纯计算可以先做。

新增范围必须能追溯到 Source of Truth 或明确的产品决定。不能用“顺手完善”增加新实体、统计评分、额外状态或基础设施。实施顺序与各 Epic 的决策门槛集中在 [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md)，本文件不拆具体开发 Task。
