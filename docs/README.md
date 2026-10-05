# 文档导航

本文件只负责分类和查阅路由，不新增设计、产品规则或实施计划。

## 按用途查阅

| 想了解什么 | 从这里开始 |
| --- | --- |
| 产品的基础定义 | [Source of Truth](../time-ledger-domain-model-v4-proposal.md) → [产品定义](product/PRODUCT_DEFINITION.md) |
| 对象、规则、生命周期或计算 | 下方「产品与领域依据」；未决事项和后续决定查[OPEN_QUESTIONS](domain/OPEN_QUESTIONS.md) |
| 业务代码组织与持久化 | [应用架构](architecture/APP_ARCHITECTURE.md)、[数据架构](architecture/DATA_ARCHITECTURE.md) |
| 当前前端设计、素材和接续范围 | [设计与上下文交接](planning/UI_REBUILD_PLAN.md) |
| 任务范围、依赖和历史完成依据 | [TASKS](../TASKS.md) → [已完成任务归档](planning/COMPLETED_TASKS.md) → 对应报告 |
| 某次旧UI设计、实现或验收 | 下方「历史前端设计与计划」「交付与验证记录」「原型与素材」 |
| Agent如何工作 | [AGENTS](../AGENTS.md) |

当前前端阶段：用户已提供参考并认可首页 / 摘要第一轮结构；决定、原型快照和待细化项均保存在上述交接。活动三幕第一轮原型已交付待评审，未推进Flutter开发。旧UI计划不是当前执行路线。

## 产品与领域依据

| 文档 | 职责 |
| --- | --- |
| [Source of Truth](../time-ledger-domain-model-v4-proposal.md) | 产品与领域确定结论的首要来源 |
| [DOMAIN_RULES](domain/DOMAIN_RULES.md) | 业务规则、校验和不变量 |
| [DOMAIN_MODEL](domain/DOMAIN_MODEL.md) | 对象、字段、关系和事实来源 |
| [DOMAIN_STATE_MACHINES](domain/DOMAIN_STATE_MACHINES.md) | 生命周期与状态变化 |
| [DERIVED_MODELS](domain/DERIVED_MODELS.md) | 切片、Gap、覆盖和统计计算 |
| [OPEN_QUESTIONS](domain/OPEN_QUESTIONS.md) | 未决事项、已决定问题及决定追溯；不能跳过 |
| [PRODUCT_PRINCIPLES](product/PRODUCT_PRINCIPLES.md) | 产品取舍与交互原则 |
| [PRODUCT_DEFINITION](product/PRODUCT_DEFINITION.md) | 产品问题、闭环与边界 |
| [MVP_SCOPE](planning/MVP_SCOPE.md) | 首版范围和排除项 |

遇到冲突按[AGENTS的来源优先级](../AGENTS.md#source-of-truth-priority)核对；原型、工程建议和任务简写不覆盖确定的领域规则。历史UI暂停不代表其中已登记的产品决定自动撤销。

## 工程说明与任务索引

| 文档 | 用途 / 阅读提醒 |
| --- | --- |
| [APP_ARCHITECTURE](architecture/APP_ARCHITECTURE.md) | 分层、依赖方向和代码组织；“只有最小入口”的现状描述已过时 |
| [DATA_ARCHITECTURE](architecture/DATA_ARCHITECTURE.md) | 持久化设计与一致性；区分领域决定和工程建议，具体实现核对源码 |
| [Web持久化资产说明](../web/PERSISTENCE_ASSETS.md) | SQLite/Drift资产来源、校验和部署条件 |
| [IMPLEMENTATION_PLAN](planning/IMPLEMENTATION_PLAN.md) | 原业务Epic顺序与依赖，不是本轮前端施工计划 |
| [TASKS](../TASKS.md) | 任务入口和完成索引；列出任务不等于授权执行 |
| [COMPLETED_TASKS](planning/COMPLETED_TASKS.md) | 已完成任务的完整历史定义 |
| [UI_REBUILD_PLAN](planning/UI_REBUILD_PLAN.md) | 当前唯一前端重做交接：已确认设计、素材、待定边界、下一设计范围及工程验证限制 |

## 历史前端设计与计划

以下按演变阶段分类，保留追溯用途，不要求新前端照搬。

| 阶段 | 文档 |
| --- | --- |
| 早期方案三 | [改造计划](planning/UI_DIRECTION_3_IMPLEMENTATION_PLAN.md)、[UI-N补充规格](planning/ui-direction-3-navigation-spec.md) |
| 整体页面与流程 | [页面体系与核心流程](planning/PRODUCT_PAGE_SYSTEM_DESIGN.md) |
| 按原型还原与返工 | [实现设计](planning/UI_IMPLEMENTATION_DESIGN.md)、[PAGE任务清单](planning/UI_IMPLEMENTATION_TASKS.md)、[六屏还原清单](planning/PAGE_T01_RESTORATION_CHECKLIST.md) |
| 问答记录探索 | [三幕交互规格](planning/GUIDED_RECORDING_DESIGN.md) |

旧文档中的“当前”“已确认”“待执行”应结合所属阶段阅读；历史确认不等于新设计确认，也不自动授权开发。

## 交付与验证记录

报告集中在[reports](reports/)。优先从[TASKS](../TASKS.md)或[COMPLETED_TASKS](planning/COMPLETED_TASKS.md)定位具体任务，再读对应报告，避免逐份通读。

| 报告分组 / 文件名前缀 | 内容 |
| --- | --- |
| `E0-*`、[EPIC_0_1_COMPLETION](reports/EPIC_0_1_COMPLETION.md) | 工程基线、领域基础及完成确认 |
| `E2-*` | 数据库驱动、连接、schema、仓储和原子写入 |
| `E3-*` | 事实切片、投影、覆盖和汇总 |
| `E4-*` | 活动记录、建议、草稿、提交、更正和恢复 |
| `E5-*` | 睡眠记录、首次确认、草稿和恢复 |
| `E6-*` | 日账本、时间线、Gap补记、编辑和删除 |
| `E7-*` | 目标生命周期、归属和可选节奏 |
| `E8-*` | 当日覆盖、完整睡眠、目标节奏摘要及重算 |
| `E9-*` | 复盘读取、草稿、提交、更正、删除和平台闭环 |
| `UI_T01–04` | 早期时间线、主题、概览和导航交付 |
| [HOME_IMPL_01](reports/HOME_IMPL_01_REPORT.md)、[EDITOR_IMPL_01](reports/EDITOR_IMPL_01_REPORT.md) | 主页与编辑页样板实施 |
| [PAGE_T01](reports/PAGE_T01_REPORT.md)、[PAGE_T02](reports/PAGE_T02_REPORT.md) | 还原清单和活动页返工 |
| [HOME_DISPLAY_CLEANUP](reports/HOME_DISPLAY_CLEANUP_REPORT.md) | 主页展示整理 |
| [GUIDED_RECORDING_DESIGN_REVIEW](reports/GUIDED_RECORDING_DESIGN_REVIEW.md) | 问答样板设计审查 |
| [design-qa](../design-qa.md) | 根目录中的历史活动样板交付记录 |

报告只证明当时执行的检查及其范围，不代表当前工作区通过；工程测试、视觉确认和真实平台验收分别判断。

## 原型与素材

| 分组 | 入口 |
| --- | --- |
| 首页视觉 | [home-visual-calibration-spec.html](planning/home-visual-calibration-spec.html) |
| 编辑页视觉与输入校准 | [editor-visual-spec.html](planning/editor-visual-spec.html)、[editor-input-calibration.html](planning/editor-input-calibration.html) |
| 阅读与管理视觉 | [reading-management-visual-spec.html](planning/reading-management-visual-spec.html) |
| 核心流程线框 | [product-core-flow-wireframes.html](planning/product-core-flow-wireframes.html) |
| 问答记录线框 | [low-friction-recording-wireframe.html](planning/low-friction-recording-wireframe.html) |
| 活动编辑HTML原型 | [activity-editor](../prototypes/activity-editor/index.html)：[说明](../prototypes/activity-editor/README.md)、[QA记录](../prototypes/activity-editor/QA.md)；[activity-editor-v2](../prototypes/activity-editor-v2/index.html) |
| 历史截图、对照与审查素材 | [reports/assets](reports/assets/)，原型目录中的截图及[assets](../assets/) |

原型中的保存与错误可为模拟行为，截图也可能使用模拟尺寸或键盘；这些材料不替代正式数据库和Android/Web验收。根目录[README](../README.md)目前只有Flutter模板说明，不作为产品文档入口。
