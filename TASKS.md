# Tasks

**2026-10-10入口直跳（用户明确要求）：** 用户指出“先关闭侧边栏、回到首页再打开设置”不可接受，要求直接跳转。修复：`_activatePanelEntry` 点击后不再等待收拢，立即提交目标页导航；快捷区在路由过渡后同步收拢；关闭收拢的焦点交还提前到推送前，避免与目标页输入焦点互抢。新增回归：点击后两帧内设置页已出现且快捷区仍在收拢（过渡重叠而非串行），返回后正常。同轮修复设置页读取失败时的无限加载指示（改为“重试读取”）。相关批次 66 项通过、零新增失败；Android / Web 构建通过；真机帧率与手感未实测。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| HOME-NAV-DIRECT-01 — 快捷区入口直跳 | 用户明确要求 | 入口点击立即导航、面板过渡后收拢、焦点交还顺序、直跳回归、失败态重试 | COMPLETE |

**2026-10-10导航卡顿修复（用户报告）：** 用户报告从侧边栏打开设置时“先关闭侧边栏、回到首页再打开设置”整体明显卡顿。定位：`home_shell` 把 `busy` 并入时间轴 `active`，导航时 `busy` 翻转触发重新接纳与整条账本重建；且每次打开路由的 `setState` 都会重建整条时间轴。修复：`active` 与 `busy` 解耦（入口回调自身已有 busy 防护，`main_app` 改为稳定回调）；`HomeShell` 增加时间轴子树缓存（键含帧版本 / 浏览日 / 活跃态 / 无障碍系数 / 宽度与字号），纯 `busy` 变化不再重建账本。调试探针同机对比：首帧 39.7 → 13.9ms、过渡 20 帧 752 → 220ms（相对证据，非真机帧率）。回归：首页 / 导航 / 设置 / bootstrap / rebuild 批次零新增失败；全量 `+768 ~11 -141` 与基线逐条一致；Android 调试 APK 与 Web 构建通过；真机帧率未实测。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| HOME-PERF-01 — 侧边栏进设置的导航卡顿修复 | 用户报告 | `busy` 与 `active` 解耦、时间轴子树缓存、稳定入口回调；探针与相关回归 | COMPLETE |

**2026-10-10设置页重设计（用户参考稿）：[重设计交接](docs/planning/UI_REBUILD_PLAN.md#设置页重设计2026-10-10用户参考稿)已完成。** 用户提供其他应用设置截图并要求“参考其他应用的设置重新设计设置页面的全部页面”。设置首页与四个子页改为分组圆角卡片、圆形图标、行尾当前值 / 开关；主题模式 / 自选主题色（矮色卡）/ 字体 / 记录方式改为 MD3 底部面板；动态色彩仅可用时显示，关闭后回到上次自选方案；四类分组与偏好键不变。设置相关测试、320–412 × 1–2× 文字滚动与 rebuild 回归通过；暖纸与默认 M3 截图存[素材](docs/planning/assets/settings-redesign-round/)（M3 截图在测试环境无系统字体，显示为方框，仅验证布局）。人工真机视觉 / 读屏未验收；不推进其他功能。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| SETTINGS-UI-01 — 设置页全部页面重设计 | 用户参考稿，Q-034 / Q-041 | 卡片 / 图标 / 行尾值与开关、底部面板（主题模式 / 色卡 / 字体 / 记录方式）、动态色彩条件显示；相关回归 | COMPLETE |

**2026-10-09当前首页阶段：[HOME-INTERACTION-01](docs/planning/HOME_INTERACTION_DESIGN.md)已按用户后续「开始实现」授权落地；2026-10-10纠正纸带方向、头部样式及收放触发。** 左右可设置滑盖快捷区、按钮镜像、当日入口、下沿阅读锚点、日期横线上沿切日 / 连续回展、下拖连续收起、首版展开 / 紧凑头部布局、今天专属提醒、未来日上限与设置持久化均已实现。左右截图已检查；真机系统边缘、人工读屏 / 误触及帧性能未验收，平台任务保持PARTIAL。详见[实施报告](docs/reports/HOME_INTERACTION_IMPLEMENTATION_REPORT.md)。

**2026-10-10反馈修复（HOME-INTERACTION-IMPL-03）：** 用户报告滚动时时间轴文字闪烁、星期信息独占一行浪费空间。已修复：可见波段按滚动内容坐标逐帧同步，标签形态只由块高决定；星期始终并入日期行，并按用户二次确认取消页头第二行——放不下时省略“· 今天 / 昨天”后缀、再隐藏星期，“返回今天”按文字 → 图标 → 快捷区入口降级。相关套件与新增回归通过；既有失败`home_feed_nav_capture`经HEAD复现为基线问题；全量比对与限制见[报告](docs/reports/HOME_SCROLL_HEADER_POLISH_REPORT.md)。不推进其他功能。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| HOME-INTERACTION-IMPL-01 — 滑盖、导航与设置 | Q-042–Q-044，用户实施授权 | 左右滑盖、镜像顶部、日期上限、方向回展、偏好持久化及行为回归 | COMPLETE |
| HOME-INTERACTION-IMPL-02 — 平台与人工验收 | IMPL-01 | Web / Android构建与左右截图通过；真机边缘手势、读屏、误触与帧性能 | PARTIAL |
| HOME-INTERACTION-IMPL-03 — 滚动标签稳定性与页头单行化 | 用户反馈 | 可见波段逐帧同步、标签形态按块高稳定；星期始终并入日期行，页头取消第二行并自适应降级 | COMPLETE |

**2026-10-09主题系统实施（用户已授权）：[实施前合同与spike](docs/planning/THEME_SYSTEM_CONTRACT.md)与四步实施已完成。** 生产代码已零 `HomePalette` / `homeSerifFamily` / `Theme(data: homeTheme)` 直引；主题系统含预设配色 + Android 动态取色 + 暖纸浅深 + 字体选项、根部管道与设置页入口，依赖接入 `dynamic_color 1.9.0`。新增矩阵 / 回退 / 持久化 / 对比度测试通过；全量测试 `+756 ~11 -141` 与基线（`+748 ~11 -141`）失败集合逐条一致、无新增；Android 调试 APK 与 Web 构建通过。暖纸深色视觉确认、Android 真机动态取色 / 系统栏与人工读屏未执行，03 记 PARTIAL；不推进其他功能。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| THEME-01 — 取色与字体解耦 | Q-041合同 | 7处Theme硬绑定、~270 HomePalette直引、105处fontFamily、painter重绘与取色面清单；暖纸视觉等价验证 | COMPLETE |
| THEME-02 — 主题系统与设置切换 | THEME-01 | 预设配色+动态取色+暖纸深色+字体选项；根部管道；设置UI与偏好键；dynamic_color 1.9.0接入 | COMPLETE |
| THEME-03 — 测试与平台验证 | THEME-02 | 矩阵/回退/持久化测试、对比度测试、Android构建与Web、构建与既有失败基线对比 | PARTIAL |

**2026-10-09上轮视觉交付：按用户九点反馈细化首页字阶、信息组、标尺间距、短条及顶部 / 底部布局。** HOME-TIME-VISUAL-01完成；采用[局部视觉规格](design.md#首页视觉细化2026-10-09用户九点反馈)，保留72dp / 小时、32dp短段规则、滞回与时刻锚点。64项相关测试、格式 / 分析、Android / Web真实引擎集成和两平台构建通过；22张截图及实际命令见[视觉细化报告](docs/reports/HOME_TIMELINE_VISUAL_REFINEMENT_REPORT.md)。人工读屏 / 实机误触仍待补，不推进其他功能。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| HOME-TIME-VISUAL-01 — 首页视觉细化 | HOME-TIME-01–03，用户九点反馈 | 字阶、4/8间距、图标 / 节点 / 短条对齐、双态页头、指标与底部；矩阵及相关回归 | COMPLETE |

**2026-10-09首页比例时间轴与双态布局已实施：[方案](docs/planning/HOME_PROPORTIONAL_TIMELINE_DESIGN.md) / [实施报告](docs/reports/HOME_PROPORTIONAL_TIMELINE_REPORT.md)。** 用户定案Q-039并明确开始执行；Q-040选择今天靠近当前时刻、历史第一条正式事实。首页72dp / 小时、双态滞回、时间锚点与短段选择已落地，63项相关测试、格式 / 静态分析、Android模拟器与Web真实引擎 + 独立SQLite集成、两平台构建通过。人工读屏 / 误触验收未执行，04保持PARTIAL。不改领域对象、schema、依赖、提醒 / 初始化算法或其他任务状态。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| HOME-TIME-01 — 固定设计合同 | Q-039 / Q-040，用户实施授权 | 参考构图、72比例、双态、短段及默认定位合同同步 | COMPLETE |
| HOME-TIME-02 — 比例日轴与四类状态 | HOME-TIME-01 | 真实几何、刻度 / 节点、事实 / Gap、短段簇及无障碍访问路径 | COMPLETE |
| HOME-TIME-03 — 双态壳与阅读定位 | HOME-TIME-02 | 滞回状态机、时间锚点、切日 / 返回 / 刷新 / 补偿及窄屏大字 | COMPLETE |
| HOME-TIME-04 — 应用回归与平台验收 | HOME-TIME-03 | 工程与Android / Web集成通过；人工读屏 / 实机误触未验收 | PARTIAL |

**2026-10-08当前授权：[取消“草稿”、改为会话内输入恢复](docs/planning/SESSION_INPUT_RECOVERY.md)。** 用户要求完整实施Q-012新决定；跨关闭 / 跨刷新恢复合同已被取代，历史COMPLETE报告只保留为当时证据。本轮只执行下列四个顺序任务，不改正式领域模型、五表schema、时间算法或冲突规则。

| Task | Depends on | Scope | Status |
| --- | --- | --- | --- |
| INPUT-RECOVERY-01 — 固定文档合同 | Q-012新决定 | Source of Truth、领域 / 架构、MVP、实施计划、当前UI交接与任务追踪 | IN PROGRESS |
| INPUT-RECOVERY-02 — 会话存储与旧数据迁移 | INPUT-RECOVERY-01 | app运行期内存store、旧三类输入清除、睡眠学习分层与保留 | IN PROGRESS |
| INPUT-RECOVERY-03 — 全入口交互去草稿化 | INPUT-RECOVERY-02 | 活动 / 睡眠 / 复盘的新建、Gap、更正、恢复选择与失败体验 | IN PROGRESS |
| INPUT-RECOVERY-04 — Android / Web验证 | INPUT-RECOVERY-03 | controller / widget / 迁移回归、平台会话边界、分析 / 测试 / 构建 | IN PROGRESS |

**2026-10-07首页动效修复：[HOME-NAV-03](docs/planning/HOME_NAV_MOTION.md)。** 用户继续反馈切换缺少动效、数字和文字闪烁；本轮取消重复定位引起的焦点闪回，时间轴加入左右平移，日期 / 时长 / 建议内容加入裁剪过渡，并保留刷新阅读位置与系统关闭动画。72项相关测试、格式、静态分析及Web / Android构建通过；全量800通过、7跳过、103项失败与HOME-NAV-02逐条一致，无新增失败。实际结果、慢放预览及平台未实测限制见[动效报告](docs/reports/HOME_NAV_MOTION_REPORT.md)，不推进其他功能。

**2026-10-07首页验收修复：[HOME-NAV-02](docs/planning/HOME_NAV_FEED_FIXES.md)。** 用户在独立验证后要求制定方案并修复；本轮切日失败保留旧窗口、斜滑判定、跨午夜跟随、恢复前台刷新及窄屏大字排版已修复。64项相关测试、格式与静态分析、Web / Android构建通过；全量792通过、7跳过、103项既存失败与修复前及HEAD基线逐条一致，无新增失败；不推进其他功能。实际结果与平台未实测限制见[修复报告](docs/reports/HOME_NAV_FEED_FIX_REPORT.md)。

**2026-10-07最新授权：[TIME-04个人睡眠初值与多日空白修复](docs/planning/SLEEP_TIME_PREDICTION.md)。** 用户报告56小时自动睡眠并确认采用推荐模型与参数；本轮独立睡眠模型、历史学习与缓存 / 反馈保护已实现，101项相关测试、Web存储与静态分析通过；不执行其他活动候选模型。见[交付报告](docs/reports/TIME-04_SLEEP_PREDICTION_REPORT.md)。

**2026-10-07最新授权：[TIME-03长Gap后的活动新建初值](docs/planning/LONG_GAP_ACTIVITY_INITIALIZATION.md)。** 用户确认当前尾部连续Gap≥5小时则预填最近60分钟，随后要求开始实现；此分支实现与验证已完成（78项相关测试、静态分析通过）；只实施Q-037这一已确认分支，睡眠学习其余参数保持未决，结果见[交付报告](docs/reports/TIME-03_LONG_GAP_ACTIVITY_REPORT.md)。

**2026-10-07后续授权：[TIME-02日期时间独立修改](docs/planning/DATE_TIME_EDITING.md)。** 用户在审查后明确要求补足提示词遗漏；覆盖全应用四字段直达、取消 / 初值 / 单字段更新及旧中间层清理。实现与验证见[交付报告](docs/reports/TIME-02_DATE_TIME_EDITING_REPORT.md)，不扩展预测模型或执行其他Task。

**2026-10-07本轮授权：[TIME-01活动与睡眠时间自动化](docs/planning/TIME_RECORDING_AUTOMATION.md)，实现已交付，平台验收未完成。** 相关测试与Web真实存储验证通过；全仓库既有失败及Android未实测见[交付报告](docs/reports/TIME-01_TIME_AUTOMATION_REPORT.md)，不标COMPLETE。按Q-032 / Q-035执行当前生产输入范围；下述旧阶段说明保留追溯，不阻止本轮明确授权。

**当前：全应用前端重做的设计探索与上下文交接（2026-10-06）。** 贯通原型第一轮已交付：首页、活动 / 睡眠输入、详情 / 删除、目标与设置共享模拟数据；先评审连续使用和返回路径。2026-10-07按用户明确授权完成首页导航与三页改版：取消首页“时间线 / 摘要 / 复盘”标签页，首页改为跨日期连续时间账本，摘要与每日复盘改为侧边栏独立页面（复盘接入正式保存与草稿处理）；决定、实施与验证见[重做交接](docs/planning/UI_REBUILD_PLAN.md#首页导航与三页改版2026-10-07后续授权)及[实施报告](docs/reports/HOME_NAV_FEED_REPORT.md)。首页 / 摘要已认可，活动第二轮保持反馈基线，睡眠获基本认可，设置当前方向暂采纳，独立原型保留。目标投入沿Q-033日期范围 / 自适应刻度 / 约5条历史，常用归档后清除与恢复手动再设沿Q-025，高级数据操作沿Q-034。表单排法与模式生效时点、列表常用入口、周起点 / 首次图表默认仍待评审。素材、范围及53项原型流程断言与浏览器证据见[重做交接](docs/planning/UI_REBUILD_PLAN.md)。新输入统一approximate（Q-030），Q-029 / Q-031 / Q-032未决边界保持；未添加 / 清空真实数据。下方旧UI计划暂停执行，领域任务及历史交付记录保留。

## 使用方式与当前状态

**历史路线起点（2026-10-04）：** 当时执行入口为[界面层重建计划](docs/planning/UI_REBUILD_PLAN.md)。当时仅授权RB-00前期文档；RB-01起待明确授权。下面PAGE旧计划保留历史索引，不再自动按逐页补丁路线推进。

**记录设计更新（2026-10-05）：** 用户已基本认可[三幕问答规格](docs/planning/GUIDED_RECORDING_DESIGN.md)，初版重点为节奏 → 事项 → 时间、持续目标、用户指定常用目标、无键盘时间调整与MD3基础组件；表单作为设置中的另一种方式保留。此次只同步文档。RB活动任务的布局与模式清理应按新基线细化，不以旧单页表单或“仅一套UI”约束覆盖新决定；任务完成和授权状态不变。

历史页面改造专项见 [页面实现设计](docs/planning/UI_IMPLEMENTATION_DESIGN.md) 与 [整体任务清单 PAGE-T01–T09](docs/planning/UI_IMPLEMENTATION_TASKS.md)。三编辑页上一版视觉验收未通过，进入返工规划；专项任务状态不覆盖下述领域/工程任务及旧UI-T交付状态。

本文件与 [已完成任务归档](docs/planning/COMPLETED_TASKS.md) 将 [IMPLEMENTATION_PLAN](docs/planning/IMPLEMENTATION_PLAN.md) 的前 10 个 Epic（Epic 0–9）细化为可单独交付的任务。Epic 10 只列工作包，不是可直接交给 coding agent 执行的大任务。范围以 [MVP_SCOPE](docs/planning/MVP_SCOPE.md) 为准，执行方式遵守 [AGENTS](AGENTS.md)。

**任务定义不等于执行状态。** 已完成的 77 个任务（Epic 0–4、E5-T01–E5-T09、E6-T01–E6-T06、E7-T01–E7-T08、E8-T01–E8-T06、E9-T01–E9-T09）保留下方简短索引，完整定义见 [COMPLETED_TASKS](docs/planning/COMPLETED_TASKS.md)，完成依据见各行报告或负责人确认记录。E6-T01–E6-T06 已完成；Epic 6 的前置与核心验收已有逐项证据，不等于全 MVP 完成。E7-T01–E7-T08 已完成，Epic 7 核心及独立 Should Have 均有两平台验收；E8-T01–E8-T06 已完成，Epic 8 核心验收及两平台生命周期证据齐备；E9-T01–E9-T09 已完成；Epic 9 核心验收及两平台生命周期证据齐备；Epic 10 仍待细化。执行任务时核对对应报告与实际实现；任务可执行条件仍为用户明确指定、Depends on 中前置任务已完成、涉及的未决问题已有可追溯答案且相应规范已更新。问题答案不由 coding agent 自行产生；缺少答案时报告 BLOCKED，不用默认值或临时模型绕过。

历史起点为 E0-T01；当前可执行任务须依据前置完成证据判断，不重新执行已交付任务。ID 和已有跳转锚点保持稳定。未完成任务保留完整验收及验证，不把测试统一推迟到最后一个 Epic。后续任务完成并记录证据后，将其全文移入 COMPLETED_TASKS，本文件保留带原锚点、归档链接和完成依据的索引行；不要归档部分完成或阻塞的任务。

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

已完成任务见下表；完整定义已归档，实际验证范围与限制见完成依据。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e0-t01--核查现有工程与验证基线"></a>[E0-T01 — 核查现有工程与验证基线](docs/planning/COMPLETED_TASKS.md#e0-t01--核查现有工程与验证基线) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e0-t02--建立最小-app-入口边界"></a>[E0-T02 — 建立最小 app 入口边界](docs/planning/COMPLETED_TASKS.md#e0-t02--建立最小-app-入口边界) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e0-t03--验证已确认首发平台的启动基线"></a>[E0-T03 — 验证已确认首发平台的启动基线](docs/planning/COMPLETED_TASKS.md#e0-t03--验证已确认首发平台的启动基线) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |

## Epic 1 — Domain Foundation

已完成任务见下表；完整定义已归档，实际验证范围与限制见完成依据。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e1-t01--定义已确定的领域枚举"></a>[E1-T01 — 定义已确定的领域枚举](docs/planning/COMPLETED_TASKS.md#e1-t01--定义已确定的领域枚举) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t02--落实时间日期与元数据基础合同"></a>[E1-T02 — 落实时间、日期与元数据基础合同](docs/planning/COMPLETED_TASKS.md#e1-t02--落实时间日期与元数据基础合同) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t03--实现-timeblock-与单对象校验"></a>[E1-T03 — 实现 TimeBlock 与单对象校验](docs/planning/COMPLETED_TASKS.md#e1-t03--实现-timeblock-与单对象校验) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t04--实现独立-sleepsession-与校验"></a>[E1-T04 — 实现独立 SleepSession 与校验](docs/planning/COMPLETED_TASKS.md#e1-t04--实现独立-sleepsession-与校验) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t05--实现-goal-的字段与校验"></a>[E1-T05 — 实现 Goal 的字段与校验](docs/planning/COMPLETED_TASKS.md#e1-t05--实现-goal-的字段与校验) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t06--实现-rhythmannotation-与关联校验"></a>[E1-T06 — 实现 RhythmAnnotation 与关联校验](docs/planning/COMPLETED_TASKS.md#e1-t06--实现-rhythmannotation-与关联校验) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t07--实现-dailyreview-与-tomorrowfirststep"></a>[E1-T07 — 实现 DailyReview 与 TomorrowFirstStep](docs/planning/COMPLETED_TASKS.md#e1-t07--实现-dailyreview-与-tomorrowfirststep) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t08--实现主要时间事实的纯冲突判定"></a>[E1-T08 — 实现主要时间事实的纯冲突判定](docs/planning/COMPLETED_TASKS.md#e1-t08--实现主要时间事实的纯冲突判定) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t09--实现获准-goal-生命周期合同"></a>[E1-T09 — 实现获准 Goal 生命周期合同](docs/planning/COMPLETED_TASKS.md#e1-t09--实现获准-goal-生命周期合同) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t10--实现获准-timeblock-更正合同"></a>[E1-T10 — 实现获准 TimeBlock 更正合同](docs/planning/COMPLETED_TASKS.md#e1-t10--实现获准-timeblock-更正合同) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t11--实现获准-annotation-编辑与移除合同"></a>[E1-T11 — 实现获准 annotation 编辑与移除合同](docs/planning/COMPLETED_TASKS.md#e1-t11--实现获准-annotation-编辑与移除合同) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |
| <a id="e1-t12--实现获准睡眠与复盘更正合同"></a>[E1-T12 — 实现获准睡眠与复盘更正合同](docs/planning/COMPLETED_TASKS.md#e1-t12--实现获准睡眠与复盘更正合同) | [负责人完成确认](docs/reports/EPIC_0_1_COMPLETION.md) |

## Epic 2 — Persistence Foundation

已完成任务见下表；完整定义已归档，实际验证范围与限制见完成依据。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e2-t01--核验持久化驱动选择"></a>[E2-T01 — 核验持久化驱动选择](docs/planning/COMPLETED_TASKS.md#e2-t01--核验持久化驱动选择) | [任务报告](docs/reports/E2-T01_DRIVER_REPORT.md) |
| <a id="e2-t02--接入单库连接与测试环境"></a>[E2-T02 — 接入单库连接与测试环境](docs/planning/COMPLETED_TASKS.md#e2-t02--接入单库连接与测试环境) | [任务报告](docs/reports/E2-T02_PERSISTENCE_CONNECTION_REPORT.md) |
| <a id="e2-t03--建立五表首版-schema-与约束"></a>[E2-T03 — 建立五表首版 schema 与约束](docs/planning/COMPLETED_TASKS.md#e2-t03--建立五表首版-schema-与约束) | [任务报告](docs/reports/E2-T03_SCHEMA_REPORT.md) |
| <a id="e2-t04--实现-goal-存取边界"></a>[E2-T04 — 实现 Goal 存取边界](docs/planning/COMPLETED_TASKS.md#e2-t04--实现-goal-存取边界) | [任务报告](docs/reports/E2-T04_GOAL_REPOSITORY_REPORT.md) |
| <a id="e2-t05--实现账本一致读取与行映射"></a>[E2-T05 — 实现账本一致读取与行映射](docs/planning/COMPLETED_TASKS.md#e2-t05--实现账本一致读取与行映射) | [任务报告](docs/reports/E2-T05_LEDGER_READ_REPORT.md) |
| <a id="e2-t06--实现受控账本原子写入"></a>[E2-T06 — 实现受控账本原子写入](docs/planning/COMPLETED_TASKS.md#e2-t06--实现受控账本原子写入) | [任务报告](docs/reports/E2-T06_ATOMIC_LEDGER_WRITE.md) |
| <a id="e2-t07--实现按日复盘存取"></a>[E2-T07 — 实现按日复盘存取](docs/planning/COMPLETED_TASKS.md#e2-t07--实现按日复盘存取) | [任务报告](docs/reports/E2-T07_REVIEW_REPOSITORY_REPORT.md) |
| <a id="e2-t08--验证存储重开与完整持久化边界"></a>[E2-T08 — 验证存储重开与完整持久化边界](docs/planning/COMPLETED_TASKS.md#e2-t08--验证存储重开与完整持久化边界) | [任务报告](docs/reports/E2-T08_FULL_PERSISTENCE_REPORT.md) |

## Epic 3 — Ledger Projection Engine

已完成任务见下表；完整定义已归档，实际验证范围与限制见完成依据。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e3-t01--实现对账窗口与派生时长基础合同"></a>[E3-T01 — 实现对账窗口与派生时长基础合同](docs/planning/COMPLETED_TASKS.md#e3-t01--实现对账窗口与派生时长基础合同) | [任务报告](docs/reports/E3-T01_PROJECTION_CONTRACT_REPORT.md) |
| <a id="e3-t02--实现事实切片与边界精度传播"></a>[E3-T02 — 实现事实切片与边界精度传播](docs/planning/COMPLETED_TASKS.md#e3-t02--实现事实切片与边界精度传播) | [任务报告](docs/reports/E3-T02_FACT_SLICING_REPORT.md) |
| <a id="e3-t03--实现-gap-与账本覆盖汇总"></a>[E3-T03 — 实现 Gap 与账本覆盖汇总](docs/planning/COMPLETED_TASKS.md#e3-t03--实现-gap-与账本覆盖汇总) | [任务报告](docs/reports/E3-T03_LEDGER_COVERAGE_REPORT.md) |
| <a id="e3-t04--实现节奏与目标时间汇总"></a>[E3-T04 — 实现节奏与目标时间汇总](docs/planning/COMPLETED_TASKS.md#e3-t04--实现节奏与目标时间汇总) | [任务报告](docs/reports/E3-T04_GOAL_RHYTHM_SUMMARY_REPORT.md) |
| <a id="e3-t05--实现完整睡眠摘要与已记录判定"></a>[E3-T05 — 实现完整睡眠摘要与已记录判定](docs/planning/COMPLETED_TASKS.md#e3-t05--实现完整睡眠摘要与已记录判定) | [任务报告](docs/reports/E3-T05_SLEEP_SUMMARY_REPORT.md) |
| <a id="e3-t06--组装-dayledgerview-并核验派生关系"></a>[E3-T06 — 组装 DayLedgerView 并核验派生关系](docs/planning/COMPLETED_TASKS.md#e3-t06--组装-dayledgerview-并核验派生关系) | [任务报告](docs/reports/E3-T06_DAY_LEDGER_VIEW_REPORT.md) |
| <a id="e3-t07--实现摘要展示语义的纯映射"></a>[E3-T07 — 实现摘要展示语义的纯映射](docs/planning/COMPLETED_TASKS.md#e3-t07--实现摘要展示语义的纯映射) | [任务报告](docs/reports/E3-T07_SUMMARY_FORMATTING_REPORT.md) |

## Epic 4 — Basic Recording

已完成任务见下表；完整定义已归档，实际验证范围与限制见完成依据。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e4-t01--接通普通记录的日期上下文与投影读取"></a>[E4-T01 — 接通普通记录的日期上下文与投影读取](docs/planning/COMPLETED_TASKS.md#e4-t01--接通普通记录的日期上下文与投影读取) | [任务报告](docs/reports/E4-T01_RECORDING_LEDGER_READ_REPORT.md) |
| <a id="e4-t02--实现普通入口的时间建议分支"></a>[E4-T02 — 实现普通入口的时间建议分支](docs/planning/COMPLETED_TASKS.md#e4-t02--实现普通入口的时间建议分支) | [任务报告](docs/reports/E4-T02_TIME_SUGGESTION_REPORT.md) |
| <a id="e4-t03--实现普通记录本机草稿存储"></a>[E4-T03 — 实现普通记录本机草稿存储](docs/planning/COMPLETED_TASKS.md#e4-t03--实现普通记录本机草稿存储) | [任务报告](docs/reports/E4-T03_RECORDING_DRAFT_STORE_REPORT.md) |
| <a id="e4-t04--实现活动优先表单与草稿生命周期"></a>[E4-T04 — 实现活动优先表单与草稿生命周期](docs/planning/COMPLETED_TASKS.md#e4-t04--实现活动优先表单与草稿生命周期) | [任务报告](docs/reports/E4-T04_RECORDING_FORM_REPORT.md) |
| <a id="e4-t05--接通正式新建保存冲突反馈与刷新"></a>[E4-T05 — 接通正式新建保存、冲突反馈与刷新](docs/planning/COMPLETED_TASKS.md#e4-t05--接通正式新建保存冲突反馈与刷新) | [任务报告](docs/reports/E4-T05_RECORDING_SUBMISSION_REPORT.md) |
| <a id="e4-t06--接通已有-timeblock-更正与删除"></a>[E4-T06 — 接通已有 TimeBlock 更正与删除](docs/planning/COMPLETED_TASKS.md#e4-t06--接通已有-timeblock-更正与删除) | [任务报告](docs/reports/E4-T06_TIME_BLOCK_CORRECTION_REPORT.md) |
| <a id="e4-t07--验证普通记录完整应用闭环"></a>[E4-T07 — 验证普通记录完整应用闭环](docs/planning/COMPLETED_TASKS.md#e4-t07--验证普通记录完整应用闭环) | [任务报告](docs/reports/E4-T07_BASIC_RECORDING_FLOW_REPORT.md) |
| <a id="e4-t08--验证-android-与-web-的保存和草稿恢复"></a>[E4-T08 — 验证 Android 与 Web 的保存和草稿恢复](docs/planning/COMPLETED_TASKS.md#e4-t08--验证-android-与-web-的保存和草稿恢复) | [任务报告](docs/reports/E4-T08_ANDROID_WEB_RECORDING_RECOVERY_REPORT.md) |
| <a id="e4-t09--提供普通记录可选备注入口should-have"></a>[E4-T09 — 提供普通记录可选备注入口（Should Have）](docs/planning/COMPLETED_TASKS.md#e4-t09--提供普通记录可选备注入口should-have) | [任务报告](docs/reports/E4-T09_OPTIONAL_TIME_BLOCK_NOTE_REPORT.md) |

## Epic 5 — Sleep Recording

本 Epic 核心任务为 E5-T01–E5-T08；E5-T09 为独立 Should Have。完整依赖 Epic 2、3，不以 Epic 4 普通活动编辑器完成为前提；可以复用已存在的 app 时间适配和本机存储能力，但不为复用建立通用框架。睡眠仍归属 ledger，已有领域、投影和原子写入不重复实现。首次打开标记仅为本机交互状态，不是睡眠事实或已记录判定来源。不新增依赖；如确需新包，先报告必要性与授权范围。

已完成 E5-T01–E5-T09；完整定义及独立 Should Have 交付证据见归档和报告。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e5-t01--接通睡眠日期上下文与完整摘要读取"></a>[E5-T01 — 接通睡眠日期上下文与完整摘要读取](docs/planning/COMPLETED_TASKS.md#e5-t01--接通睡眠日期上下文与完整摘要读取) | [任务报告](docs/reports/E5-T01_SLEEP_LEDGER_READ_REPORT.md) |
| <a id="e5-t02--实现睡眠本机草稿存储"></a>[E5-T02 — 实现睡眠本机草稿存储](docs/planning/COMPLETED_TASKS.md#e5-t02--实现睡眠本机草稿存储) | [任务报告](docs/reports/E5-T02_SLEEP_DRAFT_STORE_REPORT.md) |
| <a id="e5-t03--实现独立睡眠表单与草稿生命周期"></a>[E5-T03 — 实现独立睡眠表单与草稿生命周期](docs/planning/COMPLETED_TASKS.md#e5-t03--实现独立睡眠表单与草稿生命周期) | [任务报告](docs/reports/E5-T03_SLEEP_FORM_REPORT.md) |
| <a id="e5-t04--接通睡眠新建冲突反馈与刷新"></a>[E5-T04 — 接通睡眠新建、冲突反馈与刷新](docs/planning/COMPLETED_TASKS.md#e5-t04--接通睡眠新建冲突反馈与刷新) | [任务报告](docs/reports/E5-T04_SLEEP_SUBMISSION_REPORT.md) |
| <a id="e5-t05--接通睡眠更正与删除"></a>[E5-T05 — 接通睡眠更正与删除](docs/planning/COMPLETED_TASKS.md#e5-t05--接通睡眠更正与删除) | [任务报告](docs/reports/E5-T05_SLEEP_CORRECTION_REPORT.md) |
| <a id="e5-t06--实现每日首次打开的主睡眠确认"></a>[E5-T06 — 实现每日首次打开的主睡眠确认](docs/planning/COMPLETED_TASKS.md#e5-t06--实现每日首次打开的主睡眠确认) | [任务报告](docs/reports/E5-T06_FIRST_SLEEP_CONFIRMATION_REPORT.md) |
| <a id="e5-t07--验证睡眠记录应用闭环"></a>[E5-T07 — 验证睡眠记录应用闭环](docs/planning/COMPLETED_TASKS.md#e5-t07--验证睡眠记录应用闭环) | [任务报告](docs/reports/E5-T07_SLEEP_RECORDING_FLOW_REPORT.md) |
| <a id="e5-t08--验证-android-与-web-睡眠保存和恢复"></a>[E5-T08 — 验证 Android 与 Web 睡眠保存和恢复](docs/planning/COMPLETED_TASKS.md#e5-t08--验证-android-与-web-睡眠保存和恢复) | [任务报告](docs/reports/E5-T08_ANDROID_WEB_SLEEP_RECOVERY_REPORT.md) |
| <a id="e5-t09--提供睡眠可选备注入口should-have"></a>[E5-T09 — 提供睡眠可选备注入口（Should Have）](docs/planning/COMPLETED_TASKS.md#e5-t09--提供睡眠可选备注入口should-have) | [任务报告](docs/reports/E5-T09_OPTIONAL_SLEEP_NOTE_REPORT.md) |

## Epic 6 — Daily Timeline / Gap Resolution

本 Epic 核心任务为 E6-T01–E6-T06，完整依赖 Epic 3、4、5。复用既有日期适配、投影、普通 / 睡眠编辑与草稿，只接完整日时间轴、明确 Gap 入口及操作后的刷新。E6-T01 / E6-T02 可在各自前置完成后先行，不等同于完整 Epic 验收；基础统计页面留 Epic 8。不新增依赖，不把可保存未来事实误解为应在未来区域提示补账。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e6-t01--接通日账本页面的日期选择与读取状态"></a>[E6-T01 — 接通日账本页面的日期选择与读取状态](docs/planning/COMPLETED_TASKS.md#e6-t01--接通日账本页面的日期选择与读取状态) | [任务报告](docs/reports/E6-T01_DAY_LEDGER_ENTRY_REPORT.md) |
| <a id="e6-t02--呈现事实切片与派生-gap-时间轴"></a>[E6-T02 — 呈现事实切片与派生 Gap 时间轴](docs/planning/COMPLETED_TASKS.md#e6-t02--呈现事实切片与派生-gap-时间轴) | [任务报告](docs/reports/E6-T02_DAY_LEDGER_TIMELINE_REPORT.md) |
| <a id="e6-t03--接通-gap-预填与明确确认-unknown"></a>[E6-T03 — 接通 Gap 预填与明确确认 Unknown](docs/planning/COMPLETED_TASKS.md#e6-t03--接通-gap-预填与明确确认-unknown) | [任务报告](docs/reports/E6-T03_GAP_RECORDING_REPORT.md) |
| <a id="e6-t04--接通时间轴原事实更正与删除"></a>[E6-T04 — 接通时间轴原事实更正与删除](docs/planning/COMPLETED_TASKS.md#e6-t04--接通时间轴原事实更正与删除) | [任务报告](docs/reports/E6-T04_TIMELINE_EDITING_REPORT.md) |
| <a id="e6-t05--验证时间轴与补账完整应用闭环"></a>[E6-T05 — 验证时间轴与补账完整应用闭环](docs/planning/COMPLETED_TASKS.md#e6-t05--验证时间轴与补账完整应用闭环) | [任务报告](docs/reports/E6-T05_DAY_LEDGER_RESOLUTION_REPORT.md) |
| <a id="e6-t06--验证-android-与-web-时间轴补账集成"></a>[E6-T06 — 验证 Android 与 Web 时间轴补账集成](docs/planning/COMPLETED_TASKS.md#e6-t06--验证-android-与-web-时间轴补账集成) | [任务报告](docs/reports/E6-T06_DAY_LEDGER_PLATFORM_REPORT.md) |

## Epic 7 — Goal + Rhythm Annotation

核心任务 E7-T01–E7-T07；E7-T08 独立为 Should Have。复用 Epic 1 / 2 已交付的 Goal、annotation 领域与受控 repository，以及 Epic 4 的输入、草稿和原子保存；完整验收依赖 Epic 2、4、6。E7-T01–E7-T08 已完成，Epic 7 核心及独立 Should Have 已交付；任务编号不代表执行授权。不新增依赖或重建正式 schema；有实际缺口才增量扩展接口。Goal 生命周期管理应提供归档目标的恢复入口，但归档目标不进入新增归属候选。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e7-t01--接通简单目标创建与读取"></a>[E7-T01 — 接通简单目标创建与读取](docs/planning/COMPLETED_TASKS.md#e7-t01--接通简单目标创建与读取) | [任务报告](docs/reports/E7-T01_GOAL_CREATION_READ_REPORT.md) |
| <a id="e7-t02--接通目标改名归档恢复与删除"></a>[E7-T02 — 接通目标改名归档恢复与删除](docs/planning/COMPLETED_TASKS.md#e7-t02--接通目标改名归档恢复与删除) | [任务报告](docs/reports/E7-T02_GOAL_LIFECYCLE_REPORT.md) |
| <a id="e7-t03--接通普通记录的可选目标归属"></a>[E7-T03 — 接通普通记录的可选目标归属](docs/planning/COMPLETED_TASKS.md#e7-t03--接通普通记录的可选目标归属) | [任务报告](docs/reports/E7-T03_OPTIONAL_GOAL_ASSOCIATION_REPORT.md) |
| <a id="e7-t04--接通可选节奏解释与接续点"></a>[E7-T04 — 接通可选节奏解释与接续点](docs/planning/COMPLETED_TASKS.md#e7-t04--接通可选节奏解释与接续点) | [任务报告](docs/reports/E7-T04_OPTIONAL_RHYTHM_REPORT.md) |
| <a id="e7-t05--在时间轴呈现目标节奏与接续点"></a>[E7-T05 — 在时间轴呈现目标节奏与接续点](docs/planning/COMPLETED_TASKS.md#e7-t05--在时间轴呈现目标节奏与接续点) | [任务报告](docs/reports/E7-T05_TIMELINE_GOAL_RHYTHM_REPORT.md) |
| <a id="e7-t06--验证目标与节奏完整应用闭环"></a>[E7-T06 — 验证目标与节奏完整应用闭环](docs/planning/COMPLETED_TASKS.md#e7-t06--验证目标与节奏完整应用闭环) | [任务报告](docs/reports/E7-T06_GOAL_RHYTHM_CLOSURE_REPORT.md) |
| <a id="e7-t07--验证-android-与-web-目标节奏集成"></a>[E7-T07 — 验证 Android 与 Web 目标节奏集成](docs/planning/COMPLETED_TASKS.md#e7-t07--验证-android-与-web-目标节奏集成) | [任务报告](docs/reports/E7-T07_GOAL_RHYTHM_PLATFORM_REPORT.md) |
| <a id="e7-t08--提供可选原因与恢复细节入口should-have"></a>[E7-T08 — 提供可选原因与恢复细节入口（Should Have）](docs/planning/COMPLETED_TASKS.md#e7-t08--提供可选原因与恢复细节入口should-have) | [任务报告](docs/reports/E7-T08_OPTIONAL_RHYTHM_DETAILS_REPORT.md) |

## Epic 8 — Statistics / Summaries

核心任务 E8-T01–E8-T06；完整验收依赖 Epic 3、5、6、7。已有 DayLedgerView、目标 / 节奏 / 睡眠投影与 summary_formatting 是复用基础，本 Epic 接展示和一致性验证，不另起计算或统计存储。E8-T01–E8-T03 可按各自前置先行，E7-T08 不作为核心依赖。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e8-t01--接通摘要日期上下文与一致读取"></a>[E8-T01 — 接通摘要日期上下文与一致读取](docs/planning/COMPLETED_TASKS.md#e8-t01--接通摘要日期上下文与一致读取) | [E8-T01 报告](docs/reports/E8-T01_SUMMARY_CONTEXT_REPORT.md) |
| <a id="e8-t02--呈现账本覆盖与-unknown-摘要"></a>[E8-T02 — 呈现账本覆盖与 Unknown 摘要](docs/planning/COMPLETED_TASKS.md#e8-t02--呈现账本覆盖与-unknown-摘要) | [E8-T02 报告](docs/reports/E8-T02_COVERAGE_SUMMARY_REPORT.md) |
| <a id="e8-t03--呈现完整睡眠背景摘要"></a>[E8-T03 — 呈现完整睡眠背景摘要](docs/planning/COMPLETED_TASKS.md#e8-t03--呈现完整睡眠背景摘要) | [E8-T03 报告](docs/reports/E8-T03_SLEEP_SUMMARY_REPORT.md) |
| <a id="e8-t04--呈现目标四项细分与全局节奏摘要"></a>[E8-T04 — 呈现目标四项细分与全局节奏摘要](docs/planning/COMPLETED_TASKS.md#e8-t04--呈现目标四项细分与全局节奏摘要) | [E8-T04 报告](docs/reports/E8-T04_GOAL_RHYTHM_SUMMARY_REPORT.md) |
| <a id="e8-t05--验证摘要随事实与解释变化重算"></a>[E8-T05 — 验证摘要随事实与解释变化重算](docs/planning/COMPLETED_TASKS.md#e8-t05--验证摘要随事实与解释变化重算) | [E8-T05 报告](docs/reports/E8-T05_SUMMARY_RECALCULATION_REPORT.md) |
| <a id="e8-t06--验证-android-与-web-基础摘要"></a>[E8-T06 — 验证 Android 与 Web 基础摘要](docs/planning/COMPLETED_TASKS.md#e8-t06--验证-android-与-web-基础摘要) | [任务报告](docs/reports/E8-T06_SUMMARY_PLATFORM_REPORT.md) |

## Epic 9 — Daily Review

核心任务 E9-T01–E9-T09；完整验收依赖 Epic 2、7、8。复用已有 DailyReview / TomorrowFirstStep 与 ReviewRepository；独立本机复盘草稿不复用普通活动编辑器。摘要是可读上下文，不要求先阅读统计、补齐 Gap 或填写 summary / reflection 才能复盘。实现以 Q-001 的下一自然日为准，不用当前日或固定 24 小时替代。

| 已完成任务 / 完整定义 | 完成依据 |
| --- | --- |
| <a id="e9-t01--接通按日复盘读取与上下文"></a>[E9-T01 — 接通按日复盘读取与上下文](docs/planning/COMPLETED_TASKS.md#e9-t01--接通按日复盘读取与上下文) | [E9-T01 报告](docs/reports/E9-T01_REVIEW_CONTEXT_REPORT.md) |
| <a id="e9-t02--实现独立复盘本机草稿存储"></a>[E9-T02 — 实现独立复盘本机草稿存储](docs/planning/COMPLETED_TASKS.md#e9-t02--实现独立复盘本机草稿存储) | [E9-T02 报告](docs/reports/E9-T02_REVIEW_DRAFT_STORE_REPORT.md) |
| <a id="e9-t03--实现复盘表单与草稿生命周期"></a>[E9-T03 — 实现复盘表单与草稿生命周期](docs/planning/COMPLETED_TASKS.md#e9-t03--实现复盘表单与草稿生命周期) | [E9-T03 报告](docs/reports/E9-T03_REVIEW_FORM_REPORT.md) |
| <a id="e9-t04--接通复盘新建保存与失败反馈"></a>[E9-T04 — 接通复盘新建保存与失败反馈](docs/planning/COMPLETED_TASKS.md#e9-t04--接通复盘新建保存与失败反馈) | [E9-T04 报告](docs/reports/E9-T04_REVIEW_SUBMISSION_REPORT.md) |
| <a id="e9-t05--接通复盘原地更正与日期变更"></a>[E9-T05 — 接通复盘原地更正与日期变更](docs/planning/COMPLETED_TASKS.md#e9-t05--接通复盘原地更正与日期变更) | [E9-T05 报告](docs/reports/E9-T05_REVIEW_CORRECTION_REPORT.md) |
| <a id="e9-t06--接通复盘删除与返回读取"></a>[E9-T06 — 接通复盘删除与返回读取](docs/planning/COMPLETED_TASKS.md#e9-t06--接通复盘删除与返回读取) | [E9-T06 报告](docs/reports/E9-T06_REVIEW_DELETION_REPORT.md) |
| <a id="e9-t07--贯通日账本复盘与下一步回看"></a>[E9-T07 — 贯通日账本复盘与下一步回看](docs/planning/COMPLETED_TASKS.md#e9-t07--贯通日账本复盘与下一步回看) | [E9-T07 报告](docs/reports/E9-T07_REVIEW_ROUTE_REPORT.md) |
| <a id="e9-t08--验证复盘完整应用闭环与失败恢复"></a>[E9-T08 — 验证复盘完整应用闭环与失败恢复](docs/planning/COMPLETED_TASKS.md#e9-t08--验证复盘完整应用闭环与失败恢复) | [E9-T08 报告](docs/reports/E9-T08_REVIEW_CLOSURE_REPORT.md) |
| <a id="e9-t09--验证-android-与-web-复盘保存和恢复"></a>[E9-T09 — 验证 Android 与 Web 复盘保存和恢复](docs/planning/COMPLETED_TASKS.md#e9-t09--验证-android-与-web-复盘保存和恢复) | [E9-T09 报告](docs/reports/E9-T09_REVIEW_PLATFORM_REPORT.md) |

## Epic 10 — 待细化工作包

尚无 Task ID，不能直接作为编码任务执行。进入前按已批准产品答案和届时实现继续细化；本次不拆分或执行 Epic 10。

| Epic | 前置 Epic | 后续拆分方向与验收重点 | 关键决策门槛 |
| --- | --- | --- | --- |
| 10 Polish / Reliability | 4、5、6、7、8、9 | 完整 MVP 场景、Android / Web 平台可靠性及关键失败路径；不扩充产品 | Q-022 已决定；Must Have 所涉其他合同全部明确 |

E4-T03–E4-T08、E5-T02–E5-T08、E9-T02–E9-T09与E7-T03–E7-T07记录的本机草稿行为是当时Q-012合同下的历史交付证据；2026-10-08起由INPUT-RECOVERY-01–04的会话内输入恢复合同取代，不回写历史COMPLETE报告。MVP 的 Later / Explicitly Out of Scope 均不生成任务；各 Task 的 Q 清单不取代 OQ 与职责文档。

## Epic 完成核对与停止点

Epic 0 在 E0-T01–E0-T03 完成后核对 PLAN 验收。Epic 1 在 E1-T01–E1-T12 及 Epic 0 完成后核对验收。Epic 2 在 E2-T01–E2-T08 及 Epic 0、1 完成后核对验收。Epic 3 在 E3-T01–E3-T07 及 Epic 1 完成后核对验收；不要求 Epic 2。Epic 4 在 E4-T01–E4-T08 及 Epic 2、3 完成后核对验收，E4-T09 单独记录 Should Have 交付情况。Epic 5 在 E5-T01–E5-T08 及 Epic 2、3 完成后核对验收，E5-T09 单独记录 Should Have 交付情况。Epic 6 在 E6-T01–E6-T06 及 Epic 3、4、5 完成后核对验收。Epic 7 在 E7-T01–E7-T07 及 Epic 2、4、6 完成后核对验收，E7-T08 单独记录 Should Have。Epic 8 在 E8-T01–E8-T06 及 Epic 3、5、6、7 完成后核对验收。Epic 9 在 E9-T01–E9-T09 及 Epic 2、7、8 完成后核对验收。局部工作先行不改变完整 Epic 的依赖。

执行一个 Task 后按 AGENTS 报告并停止。不得因为已细化其他 Task 自动继续；本次规划细化不授权执行任何实现任务。
