# 方案三 UI 改造准备与任务计划

初稿：2026-10-03；补全：2026-10-04（Asia/Shanghai）。状态：**PLAN DECISIONS COMPLETE / IMPLEMENTATION PARTIAL**。方案三已经选定；本计划不重新进行三方案选择。UI-T01 / UI-T02 / UI-T03 / UI-T04 已交付，UI-T05–UI-T12 未实施。

负责人于 2026-10-04 委托补全本计划的未决定部分。本次只修改本文件，保留已有 Dart、测试、主题、UI-N 视觉规格及报告改动；没有执行 UI 代码任务或 Epic 10。下文 UI-D01–UI-D09 是本次受托作出的 UI 规划结论，可作为逐项执行任务的设计来源；不是把负责人此前选择方案三解释为已逐项批准全部交互。实现仍需负责人明确指定 Task，未交付的状态图、设备截图和平台验证不因计划补全而视为完成。

## 1. 输入、基线与完成证据

### HOME-IMPL-01 — 已确认主页样板实施（进行中）

2026-10-04，用户确认全部核心视觉稿后回复“请继续”，授权先实施主页样板。最新设计决定见 [PRODUCT_PAGE_SYSTEM_DESIGN](PRODUCT_PAGE_SYSTEM_DESIGN.md) 确认记录及 [主页规格](home-visual-calibration-spec.html)。主页范围内旧 UI-D 的常驻图例、操作行、活动图标和尺寸建议由该已确认规格替代；不改旧 UI-T 交付状态。

- 依赖：已有 UI-T01–04 工作区增量及报告，主页设计确认；保留全部既有修改。
- 范围：主页日期/覆盖/时间条/连续时间轴/详情、完整睡眠折叠、主页更多接线与外壳尺寸；共用组件的其他调用保持原行为。
- 排除：其他页面视觉推广、领域/持久化/controller合同改变、新依赖、后续 UI-T 自动实施。
- 验收：同一混合样例的真实360×800截图；首层紧凑与次层能力完整，详情沿用源ID与原删除收尾；日期、Gap、Unknown、跨日睡眠精度保持；窄屏/大字无溢出。
- 验证：主页规格§7的格式/分析/相关行为测试及截图，工程和用户视觉验收分别记录。未取得证据的项目不标通过。

初稿与此前体验回顾使用以下设计输入，并已实际查看两张图；本次沿用该选定方向：

- [选定方向与细化约束](</home/tokiya/.codex/visualizations/2026/10/03/01a10149-6dc4-74b3-a366-ba5993adc555/timeledger-review/direction-3-design.md>)。
- [原方案三](</home/tokiya/.codex/visualizations/2026/10/03/01a10149-6dc4-74b3-a366-ba5993adc555/timeledger-review/concept-3-dark-workbench.png>)。
- [主页细化效果图 v2](</home/tokiya/.codex/visualizations/2026/10/03/01a10149-6dc4-74b3-a366-ba5993adc555/timeledger-review/concept-3-refined-v2.png>)。

仓库入口 /home/tokiya/Projects/21-TimePetLedger 实际解析为 /kiyodata/Projects/21-TimePetLedger。初稿基线为 main、HEAD dcb4946、干净工作区。2026-10-04 补全时，工作区已有 UI-T01 / UI-T02 的代码、测试、规格及报告增量，本计划也尚未跟踪；这些内容原样保留。主 agent 重读 AGENTS、SOT、任务和相关来源，委派一次有界只读 code_mapper，并检查其引用的控制器、路由与报告；代码结论以当前工作区为准。

Epic 9 完成证据：

- [TASKS](../../TASKS.md) 与 [COMPLETED_TASKS](COMPLETED_TASKS.md) 一致列出 E9-T01–E9-T09 COMPLETE；[IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) 的 Epic 9 核心门槛已完成，Epic 10 仍是未细化工作包。
- [E9-T08 闭环报告](../reports/E9-T08_REVIEW_CLOSURE_REPORT.md) 对照三组真实 SQLite / widget 闭环；主 agent 检查 [review_closure_flow_test.dart](../../test/app/review_closure_flow_test.dart) L481、L567 的提交后双故障、竞争日期及过期源身份场景。
- [E9-T09 平台报告](../reports/E9-T09_REVIEW_PLATFORM_REPORT.md) 记录 Android 模拟器五阶段、四次实际强停重开，以及 Chromium 同源同页四次刷新。当前 [review_platform_test.dart](../../integration_test/review_platform_test.dart) L236–518、[Android 驱动](../../tool/e9_t09_relaunch_android.py) L69–103、[Web 驱动](../../tool/e9_t09_refresh_web.py) L95–109 对应这些流程。
- 初稿记录的留存日志：/tmp/e9-t09-analyze-final.log 为 No issues found；/tmp/e9-t09-regression.log 末尾为103项通过；Android / Web日志有五阶段和生命周期完成标记。本次以对应报告为完成索引，不重新断言这些临时文件当前仍可用。

这些是 Epic 9 已完成任务的留存证据，本次没有重跑分析、测试或平台流程。它们支持 UI 规划，不证明新 UI 已验收，也不代表实体手机、其他浏览器、发布部署或 Epic 10 已完成。

当前 UI 增量已核对：[UI-T01 时间轴报告](../reports/UI_T01_TIMELINE_REPORT.md) 和 [UI-T02 主题报告](../reports/UI_T02_THEME_REPORT.md) 分别记录组件、主题已交付；现有时间轴和共享主题接入与报告相符。[UI-N 规格](ui-direction-3-navigation-spec.md) 已采纳视觉标注，但原文其余部分的 UNCONFIRMED 是本次补全前的状态。视觉继续以该规格为准，日期头、导航及各页面的新规划以本文件 UI-D 条目为补充；不改写其原始采纳记录，不把报告的测试结果算作本次重跑。

共同来源：[SOT](../../time-ledger-domain-model-v4-proposal.md)、[RULES](../domain/DOMAIN_RULES.md)、[MODEL](../domain/DOMAIN_MODEL.md)、[STATES](../domain/DOMAIN_STATE_MACHINES.md)、[DERIVED](../domain/DERIVED_MODELS.md)、[OQ](../domain/OPEN_QUESTIONS.md)、[产品原则](../product/PRODUCT_PRINCIPLES.md)、[APP](../architecture/APP_ARCHITECTURE.md)、[DATA](../architecture/DATA_ARCHITECTURE.md)、[MVP](MVP_SCOPE.md)。OQ 当前 Q-001–Q-023 均为 DECIDED。下列 UI-D 编号只记录界面规划，不追加领域问题或修改已决答案；本次未发现必须新增产品 / 领域规则才能补全的阻塞。

所有后续 UI 任务共同保留现有 domain / application / data、数据库 schema 与连接、本机草稿存储键 / 队列 / 恢复 / 清理策略、saver / editor 的原子写入和提交收尾语义。日期仍按 CivilDate 与设备时区，now 显式注入；不新增依赖或统计持久化。布局变化不能用 UI 预检代替正式事务约束，也不能借切页绕过既有离页等待。发现必须超出 UI 职责的缺陷时，报告具体影响，单独定义修复范围。

## 2. 已确认方向与本次补全的 UI 决策

| 类别 | 本计划采用的内容 | 证据和边界 |
| --- | --- | --- |
| 已选方向 | 深蓝底、青色主动作；连续时间轴、全天时间条；底部“回看 / ＋记录一笔 / 复盘” | 负责人明确选择方案三，强调时间轴和底部栏；不换成四个等权目的地 |
| 已采纳视觉参数 | UI-N 的色值、系统字体、文字层级、焦点与错误样式、48×48触控目标；沿用 UI-T01 的测量时间列 | UI-T01 / UI-T02 已交付；不重新改配色、不加字体包或主题切换 |
| 本次补全 | UI-D01–UI-D09 的日期、导航、表单、摘要、复盘、宽屏及范围选择 | 负责人委托补全计划；这些是 UI 规划结论，保留现有领域合同 |
| 尚未交付 | 新页面 / 状态图、完整主页、真实 Android 键盘和返回、Web 宽屏交互与平台回归 | 决策已明确不等于代码或验收已完成；在对应 UI-T 内取得证据 |

图例仍是 2026-10-02 历史日：睡眠440、早餐40、设计120、Unknown30、Gap30、散步30、末段Gap750分钟；已交代660（含Unknown30），Gap780。图中的“昨天”基于生成日期2026-10-03；实际界面按注入的 now 和设备自然日期生成今天 / 昨天 / 星期，不把相对日期文案写死。

### UI-D01 — 日期所有权与日期头

- 根导航持有一份轻量 presentation 选择：跟随今天，或明确 CivilDate。默认回看、跟随今天；账本、摘要和复盘读取承接同一选择，不持久化浏览日期、不新增日期领域对象。沿用 DayLedgerController 的 null / 明确日期语义和请求隔离。
- 左右箭头以 CivilDate 前后自然日切换，选择后固定该日；点日期打开日历，日历选择包括今天在内都成为明确选择。独立“今天”动作恢复跟随今天；取消日历不改变选择。保留手动 YYYY-MM-DD 入口，不因日历控件可显示范围限制合法领域日期。
- 头部顺序为日期、范围说明、已交代 / 尚未记录、其中想不起来，再是时间条；不用完成率。今天标“截至 HH:mm”，历史日标当地实际日窗口；未来日标“未来日期，暂无对账窗口”，不提示补账。
- 根层在 resumed、回到读取目的地及既有刷新触发时重新解析跟随今天；明确日期不随午夜跳转。编辑表单捕获打开时上下文，不能因午夜或切页重新定向草稿；同页停留不新增分钟定时轮询，保留刷新入口。
- 读取页快速改日沿用原控制器旧响应隔离；加载 / 失败不显示上一日期的数值或第一步。日期行在320宽或大字时换行，左右按钮仍至少48×48；不压缩字体来塞满首行。

### UI-D02 — 全天时间条与列表

- 时间条仅是只读分布概览，不承担小区间点击或拖动编辑；准确操作由下方时间轴提供。线性坐标以设备时区当天零点到次日零点的实际毫秒为分母，非固定1440分钟；事实和Gap均取现有投影，不再次做覆盖计算。
- 历史日显示完整窗口。今天只绘制投影中的截至 now 部分，之后用低强调表面并标“尚未发生”；未来日整条中性、不可补记。中性区域不进入Gap或统计。现有完整睡眠摘要仍按原口径展示，不因W为空被当成无睡眠。
- 睡眠蓝、普通活动青色、Unknown灰实色、Gap空心虚线；近似精度由相应文字和语义标签说明，不伪造宽度误差带。不给微小片段增宽，不加时间评分或动画奖励。
- 手机条高16、与刻度间距8，周边触控动作仍48×48。普通日刻度00:00 / 06:00 / 12:00 / 18:00 / 次日00:00；DST日按实际 instant 放置、跳过不存在的时刻，重复当地时刻附偏移说明，避免等分刻度冒充精确坐标。拥挤时保留首尾并减少中间标签，完整日期区间可通过语义访问。
- 保留 UI-T01 的通用活动、月亮、问号、Gap 图标；“复盘”采用笔记 / 文档图标，不按活动标题推断早餐、电脑或散步分类。时间列、换行和完整睡眠精度沿用当前组件，不重复制造局部主题。

### UI-D03 — 根导航、返回与滚动

| 场景 | 采用行为 |
| --- | --- |
| 默认入口 / 回看 | 进入选定日日账本。再次点已选“回看”不重置日期或强制滚到顶部 |
| 中间创建动作 | 打开模态底部选择，只有“记录活动”“记录睡眠”及取消；不是第三个目的地。创建活动沿用Q-023，明确Gap仍直接预填；睡眠使用既有独立入口 |
| 复盘 | 根目的地，承接所选日；未保存 / 已保存 / 读取失败分开，日期仍可切换。不会要求先补满Gap或读摘要 |
| 更多 | 明确提供“当日摘要”“目标管理”；摘要沿用选定日，目标是全局管理页。刷新和手动日期输入仍可达，不保留旧七按钮作为重复根入口 |
| 系统返回 | 先交由平台处理键盘，随后关闭最上层选择器 / 对话框，再返回子页；编辑离页仍走原flush。根复盘返回根回看且保留日期；根回看无子页时交回系统退出，不新增退出确认 |
| 记录保存 / 更正 / 删除返回 | 保持浏览日期，重读受影响账本 / 摘要 / 正式复盘上下文；不按事实的新时间擅自跳日，不自动改复盘文字 |
| 复盘改日期后正式保存返回 | 沿用编辑页返回实际 savedDate 的合同；读取页和根选择一起固定到该日。取消或仅保留草稿不改变根日期，日期冲突 / 写入失败留在编辑页 |
| 首次睡眠 | 复用原协调器、设备今天、检查去重和首帧 / resumed / 返回根层钩子；只在根读取可见且无模态 / 编辑时提示，普通目的地切换不另建协调器或重复提示 |

底部栏采用水平三段：左回看、中央较宽青色记录动作、右复盘；基础内容高度76加底部SafeArea，水平内边距16、间隔12，低强调表面与顶部1px分隔。中央不是选中态Tab，左右有文字、图标和选中标识。放大字体时按内容增加栏高，正文底部预留实际高度；不使用生成图的固定像素高度覆盖正文。

账本 / 复盘根页各自保留滚动位置，按目的地＋明确解析日期分开；切日首次进入顶部，切回来恢复该日。只保留会话内最近7个日期，不新增磁盘或草稿键。读刷新、子页返回保持锚点（类型＋源ID；Gap用现有边界），对象已删除时回到最近保留项或可用范围；不能因像素偏移变化展示错日。重启 / Web刷新不要求恢复浏览位置，但原持久化输入草稿仍须恢复。

### UI-D04 — 活动表单与可选内容

- 手机使用完整编辑页，编辑时不显示根底栏。顺序为：草稿 / 失败状态、活动内容和Known / Unknown、建议时间及修改、独立精度、目标、节奏、可选细节、保存区。默认不自动弹键盘，方便检查恢复草稿；点文本后正常输入。
- 有完整建议区间时默认显示可读区间与“修改时间”，两端精度仍可单独选择；无完整区间或存在时间错误时展开起止编辑。选定Goal后的原时间确认信息保持突出。日期＋时间选择与原手动输入并存；取消选择不应用值，修改时间不自动变exact。
- 目标与节奏的摘要 / 选择入口常显，避免隐藏核心能力；“备注”与适用的节奏细节可折叠。新草稿没有内容时折叠，有原值或恢复值时展开；有相关错误立即展开并滚动 / 聚焦字段。用户主动折叠后保留简短已有内容摘要，字段值继续由原controller管理。
- 选stuck或recovery立即展开各自可选细节；状态切换只隐藏不适用字段，切回恢复值；接续点三种节奏都可填写。Unknown保留并可编辑已有title、Goal、note、annotation；Unknown选择不是一键正式保存，仍由保存动作提交。
- 主按钮“保存到账本”或“保存更正”；次按钮“保留草稿并返回”；放弃草稿为低强调文字动作。删除正式记录是独立危险动作并确认，确认显示对象与完整区间，不用放弃草稿替代删除。
- 不通过视觉调整放宽controller校验或强行启用按钮。未触碰字段用中性必填说明；保存意图或字段离焦后显示输入校验，草稿读取 / 写入和正式提交失败立即显示。已有错误在字段隐藏时也要可见；这只是展示时机，正式校验始终完整。

### UI-D05 — 睡眠、首次确认与目标

- 睡眠页顺序为类型（主睡眠 / 小睡）、入睡完整日期时间与精度、醒来完整日期时间与精度、可选备注、保存区。起止日期始终可见，不根据时分自动补一天；已有值 / 错误的备注展开，保存层级和键盘行为同UI-D04。
- 首次睡眠使用现有提示与协调逻辑，清楚提供“记录睡眠”和继续账本动作；不先要求Goal。已有已结束主睡眠免打扰、多段主睡眠、只有小睡和未来醒来条件均按Q-010，不新增提醒频率或跳过持久化政策。
- 目标管理默认显示活跃列表，归档为明确可切换分区；创建为主动作，单项更多提供改名 / 归档 / 恢复 / 删除。删除确认说明“有关联记录时会归档并保留引用，可恢复”；执行仍由原操作判断，不为确认文案新增引用预查询或先假定无引用。
- 记录 / 复盘目标选择用单选模态列表，含“不关联”；仅活跃目标可新增关联，原归档引用单独显示且可保留。名称可换行，同名项显示既有身份辅助信息，完整ID可访问，不去重或自动合并。
- 列表读取失败显示重试，不当作空列表；保留名称与现有选择。Goal不新增跨启动草稿承诺；沿用现有页面内输入保留与提交后重读 / 收尾。

### UI-D06 — 键盘、焦点与失败反馈

- 编辑页单列滚动，文本与保存区不得被viewInsets遮住；键盘打开后将保存区放入可滚动内容末尾，不强行固定浮在键盘上挤压长文本。小屏 / 横屏可滚到所有字段和动作，大字不截断正式内容。
- 手机创建 / 目标选择使用底部模态，目标列表可滚动；宽度达到840时改为居中、最大480宽的同一选择器。日历 / 手动时间对话框限制在当前可用宽高内，大字可滚动；取消均不应用值，不创建第二套编辑controller。
- 单行输入的键盘下一项移动焦点；多行Enter保留换行。Web Tab按视觉顺序，聚焦按钮Enter激活；不以文本框Enter全局提交。Escape先取消日历 / 模态，再对编辑页走与返回相同的flush，不直接放弃草稿。关闭模态恢复触发控件焦点。
- 字段错误显示在对应字段；存储、草稿、冲突、源缺失和收尾错误保留在可见状态区域，不只用短暂snackbar。失败颜色配文字和动作；保存中沿用原禁用与冻结规则。
- 冲突主提示采用现有payload的类型＋完整起止日期时间，不把内部UUID作为标题；身份放辅助详细信息。提供修改当前时间与重试，不自动改冲突记录。无须新增活动名读取接口。
- 正式未提交可重试保存；已经提交但清理 / 重读失败只能重试收尾。放弃或删除失败留页并保留输入，未执行成功不得显示成功。具体动作沿用各controller，不用一种通用错误组件抹平失败阶段。

### UI-D07 — 摘要单位与复盘层级

- 采用中文小时分钟展示：先复用现有roundedMinutes，60分以下为“40分钟”，整小时为“2小时”，其余为“7小时20分钟”。不重新舍入、不先舍入参与记录再相加；零值、hasRecords缺失文案、“少于1分钟”及逐项“约”保持Q-017 / Q-021 / Q-014。超过一天继续显示总小时，不新增按天舍入。空格为排版细节，不影响数字语义。
- 单位转换由UI-T03在既有presentation格式化处统一引入，回归所有受影响时间轴 / 睡眠 / 摘要 / 复盘展示；UI-T08复用该格式，不维护第二套算法。输入时间仍是分钟级，原始事实 / 毫秒计算不变。
- 摘要阅读顺序：账本范围与覆盖 → 完整主睡眠 / 小睡背景 → 各目标总时长及四项细分 → 独立全局恢复。Goal有贡献才显示，归档 / 同名身份保持。主信息默认可见，公式与口径说明默认折叠；不隐藏某项合法数据来缩短页面，不将全局恢复再加到目标合计。
- 复盘读取顺序：日期、正式存在性、概述 / 反思、一个下一自然日第一步及可选Goal、编辑 / 删除操作、可展开事实上下文。第一步完整多行可读，不硬截断；无正式复盘提供填写入口，失败提供重试，二者不同。
- 复盘编辑顺序：日期与次日说明、概述、反思、第一步、可选Goal、保存区、可展开事实上下文。概述 / 反思不因重排成为必填；第一步不从接续点或旧日内容自动生成。字段错误与草稿恢复按UI-D04 / D06，刷新上下文不替换文字。
- 账本正式结果卡：读取中低强调等待；不存在显示“还没有保存此日复盘”及填写入口；失败显示读取失败 / 重试，不显示旧第一步；已保存显示次日日期、第一步摘录及查看入口。摘录最多两行，全文在正式读页可访问；不显示或查询其他入口的草稿存在性。
- 复盘事实默认折叠，标题保留日期、范围与是否读取成功。上下文读取失败时折叠区也显示重试，但不抹掉已有复盘输入；依当前loader / controller的成功、失败分界实施，不能伪造部分成功快照。

### UI-D08 — Web 响应式布局

以下宽度均为逻辑像素，按可用内容宽度判断。320 / 360 / 412手机优先；旋转或resize只改布局，不新建编辑controller或重置原输入。

| 可用宽度 | 布局与导航 | 右侧内容 |
| --- | --- | --- |
| <840 | 单列，边距16，根页保留底栏；编辑页正文限宽560、无根栏 | 不显示独立右栏，信息在原页可展开 |
| 840–1199 | 88宽导航轨，24间隔，主内容限宽760并居中；回看 / 复盘 / 青色记录及更多可达，取消底栏 | 无右栏，摘要和详情仍为原页内容 |
| ≥1200 | 200宽左导航、中央账本480–760、320宽右栏；外边距24、列间隔24，超宽留白 | 回看时为选定日只读覆盖 / 完整睡眠摘要、默认折叠目标摘要，以及正式复盘卡；复盘读 / 编辑时为同日事实上下文 |

三栏容不下各列最小宽度（含文字放大）时降到双栏，再不足则单栏，不能水平裁切。840前后、1200前后分别验证；800单列、1024双栏、1440三栏。独立摘要 / 目标页面不强加重复右栏；三栏下复盘卡移到右栏，主时间轴不重复同卡。

右栏只消费同一日期的已加载投影 / 正式ReviewContext，或复用既有只读loader，不成为事实源；不提供第二套编辑会话或“选中记录编辑器”。读失败分别显示失败，不悄悄用另一日期缓存补位。根选择和当前编辑实例在断点变化前后相同；滚动仍按UI-D03保留。

### UI-D09 — 视觉尺寸与范围取舍

- 不改已采纳色值。继续系统字体和Material文字层级：页面标题24、日期20、覆盖值32、正文16、辅助13；时间轴13 / 17 / 14 / 13沿用现有规格，文字随系统缩放。大字需要换行 / 增高，不将字号缩小到固定框内。
- 间距采用8为基础：手机边距16，组内8，组间16 / 24；记录主动作与状态表面圆角16，选择模态顶部20，输入和普通控件沿用Material / UI-T02，不批量重排已验收时间轴。页面背景纯色，主动作采用纯青色，不增加纹理、强渐变或装饰发光。
- 主 / 次 / 危险动作层级一致；触控至少48×48，焦点2px青色或相应错误轮廓。所有状态带文字 / 语义标签；真实对比度、大字、触控、键盘和系统返回在任务内验证。
- 冲突活动名补充、自动活动分类图标、主页草稿存在性聚合均明确排除在UI-T01–UI-T12之外，不再作为本轮未决前置。当前已有字段、编辑 / 删除 / 放弃 / 归档等能力不裁剪；若以后增加上述能力，另定义范围与授权。

## 3. 当前实现与复用边界

| 实际职责 | 当前代码证据 | 改造策略 |
| --- | --- | --- |
| 启动、注入与根入口 | [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) L175–240；[main_app.dart](../../lib/app/main_app.dart) L81–103、L588–641 | ready / loading / 本地存储打不开分别有入口；当前主页仍是日期输入与多个按钮；UI-T02 已接入共享深蓝主题，底部导航和响应式 shell 未实施。复用原注入与存储生命周期 |
| 导航及首次睡眠 | main_app.dart L176–232、L251–342、L423–468 | MaterialPageRoute 打开已有页面；首次睡眠协调器在根页启动 / resumed / 返回时检查。替换根页必须迁移这些钩子，不能丢失或随切换目的地重复触发 |
| 日账本与时间轴 | [day_ledger_page.dart](../../lib/features/ledger/presentation/day_ledger_page.dart) L17–100、L276–355；[day_ledger_timeline.dart](../../lib/features/ledger/presentation/day_ledger_timeline.dart) L21–216、L237–473 | 已合排全部事实切片和 Gap，使用源类型＋ID 回调。UI-T01 已有连续轨道、四状态、完整睡眠及切片展示；UI-T02 已使用全局主题。比例时间条仍未实施 |
| 日期与刷新 | [day_ledger_controller.dart](../../lib/features/ledger/presentation/day_ledger_controller.dart) L7–64 | 已有 loading / empty / ready / failed、旧响应隔离；null 选择跟随今天，明确历史日跨午夜保持。复用，不另造日账本状态模型 |
| 活动输入 | [recording_form.dart](../../lib/features/ledger/presentation/recording_form.dart) L123–173、L336–535；[recording_form_controller.dart](../../lib/features/ledger/presentation/recording_form_controller.dart) L456–550 | 活动、备注、Known / Unknown、目标、候选 Gap、起止与独立精度、可选节奏细节均可输入。复用 controller 的草稿队列、flush、提交及收尾 |
| 睡眠输入 | [sleep_form.dart](../../lib/features/ledger/presentation/sleep_form.dart) L102–240；[sleep_form_controller.dart](../../lib/features/ledger/presentation/sleep_form_controller.dart) L349–383 | 日期时间文本输入、跨日、主睡眠 / 小睡、独立精度、备注和草稿恢复已接通。不要借用活动 controller 或改变睡眠事实 |
| 目标 | [goals_page.dart](../../lib/features/goals/presentation/goals_page.dart) L12–107、L263–319；[goal_rename_dialog.dart](../../lib/features/goals/presentation/goal_rename_dialog.dart) L25–101 | 创建、归档、恢复、删除、改名及失败保留已存在。Goal 不拥有普通记录那样的持久化草稿合同，不能在改样式时顺带增加 |
| 摘要与共享展示 | [day_summary_page.dart](../../lib/features/ledger/presentation/day_summary_page.dart) L120–208；[sleep_summary_view.dart](../../lib/features/ledger/presentation/sleep_summary_view.dart) L10–47；[goal_rhythm_summary_view.dart](../../lib/features/ledger/presentation/goal_rhythm_summary_view.dart) | 摘要复用 DayLedgerController；睡眠 / 目标摘要也被复盘使用。改这些组件会影响两处，要同时验收 |
| 复盘读取 / 编辑 | [review_context_page.dart](../../lib/features/review/presentation/review_context_page.dart) L101–212；[review_form.dart](../../lib/features/review/presentation/review_form.dart) L204–350；[review_form_controller.dart](../../lib/features/review/presentation/review_form_controller.dart) L93–124、L382–423 | 无复盘、已有复盘、失败已有区别；表单与正式读取分开。入口新建草稿按日期、编辑草稿按原 ID 隔离；改日期后返回实际保存日期 |
| 格式与冲突信息 | [summary_formatting.dart](../../lib/features/ledger/presentation/summary_formatting.dart) L14–47；[ledger_conflicts.dart](../../lib/features/ledger/domain/ledger_conflicts.dart) L13–30；sleep_form.dart L217–219 | 当前通用时长显示分钟；UI-D07 采用最终分钟结果转小时分钟。冲突payload只有类型、ID、完整起止，无活动标题；UI-D06 按现有信息呈现 |

已有可复用的是领域投影、格式化、feature controllers、睡眠 / 目标摘要、表单时间与节奏输入，以及 UI-T01 时间轴和 UI-T02 的 lib/app/theme/time_ledger_theme.dart。导航shell、布局断点和显式滚动恢复尚未实施；状态表达按第5节逐项改造。仅在出现实际复用时提取小组件；不建立通用表单、repository、状态机或庞大设计系统。

## 4. 页面与设计交付清单

UI-N / A / S / G / M / R / W 的行为选择已经由第2节补全；它们不再是等待逐项产品问答的门槛。当前只有 UI-N 视觉规格存在，其余独立规格文件不要求在代码任务前全部创建：执行时直接引用本计划的对应UI-D，必要时在明确授权范围内提取成规格，不重新作相反决定。

| 设计范围 | 本计划设计来源 | 对应任务必须交付的状态与证据 |
| --- | --- | --- |
| UI-N 导航与主页 | 现有UI-N视觉规格＋UI-D01–D03、D07–D09 | 历史 / 今天 / 未来 / 空窗口 / 失败头部、实际比例条、底栏安全区、创建 / 更多、复盘卡、日期 / 滚动 / 返回 / 首次睡眠；手机状态图或实际截图 |
| UI-A 活动 | UI-D04、D06、D09 | Q-023全部入口分支、Known / Unknown新建 / 更正、目标与全部节奏字段、折叠保留 / 错误展开、键盘、草稿恢复、提交 / 删除 / 收尾失败 |
| UI-S 睡眠 | UI-D05、D06、D09 | 跨日起止和独立精度、主睡眠 / 小睡、多段、首次确认 / 已记录免打扰、更正 / 删除 / 草稿 / 各阶段失败 |
| UI-G 目标 | UI-D05、D06、D09 | 活跃 / 归档、创建 / 改名 / 归档 / 恢复 / 删除确认、选择器、空 / 读失败 / 同名 / 旧归档引用 / 状态竞争 |
| UI-M 摘要 | UI-D07、D09 | 覆盖关系、完整睡眠与切片、目标四项 / 全局恢复、无记录 / 正时长不足一分钟 / 近似 / 长列表 / 失败；核验共享组件两处使用 |
| UI-R 复盘 | UI-D01、D03、D06、D07、D09 | 正式读取 / 独立草稿、全文、多行、改日期返回、删除、上下文刷新、Goal变更、源缺失、日期冲突、提交后收尾失败 |
| UI-W 宽屏 | UI-D08＋对应页面条目 | 两个断点前后、resize / 横屏 / 大字、左右栏来源与失败、Tab / Enter / Escape、可见焦点、单实例编辑与刷新恢复 |

这些图、截图及交互证据仍未交付，不将本计划或生成图作为实际验收。任务在其范围内实现并验证全部必要状态即可满足设计交付，不再以“还没有独立spec文件”为由反复索取常规实现决定。发现领域冲突仍按AGENTS停下受影响部分。

## 5. 关键状态合同与视觉补充

这些状态已由代码提供结果或控制逻辑；改造的是表达和可达性，不能把它们合并成一条通用“失败”。每个表单任务都验收自己的失败状态，不把失败验证全部推迟到最后。

| 状态 | 必须设计的表达与动作 | 必须保留的结果 |
| --- | --- | --- |
| 启动中 / 本地库打不开 | 独立加载与错误页；沿用现有重启指引 | 未打开库不能显示为正常空账本；不新增清库 / 重置动作 |
| 页面读失败 / 目标读失败 | 可见重试和范围说明 | 不伪装无记录，不展示陈旧成功快照，不清输入或现有 Goal 关联 |
| 历史空账本 / 当前空窗口 / 未来日期 | 展示窗口与开始记录入口；未来区域中性 | 无事实可有整窗 Gap；空窗口不制造 Gap。普通入口仍按 Q-023 手动输入，不擅自预填整窗 |
| Gap / Unknown | 空心轨道与补记；实心灰节点与“想不起来 · 已交代”及更正 | Gap 可保留；Unknown 已计入 accounted，不继续催促补记；Unknown 已有 title / Goal / rhythm 不隐藏为不存在 |
| 草稿恢复 / 正在保留草稿 | 中性恢复提示，与正式保存分别命名 | 恢复原始未完成输入；不把草稿计入账本、摘要、复盘卡或正式第一步 |
| 草稿写入 / 读取失败，返回等待失败 | 内联保留提示与专门重试；不要只放短暂 snackbar | 内存仍有输入不等于已经写到磁盘；flush 未成功时沿用现有离页阻止，不强行 pop |
| 正式保存中 | 等待提示，禁用重复提交与冲突动作 | 不能同时放弃、再次保存或更换正在提交的输入 |
| 时间重叠 / 复盘日期已占用 | 类型与完整区间 / 日期、手动调整入口 | 原子拒绝，不自动覆盖、截断、拆分或移动已有事实；保留输入 |
| Goal 当前不可新关联 | 当前引用、重新读取与重新选择 | 原归档引用可保留；新增关联仍检查当前状态，不静默清空 |
| 编辑源不存在 / 解释操作已过期 | 说明源身份失效、返回或处理草稿 | 不重建源、不替换成同日另一 ID，不拿刷新后的对象代替旧编辑源 |
| 正式写入失败 | 留在页内，可重试正式保存 | 不能显示成功、提前清草稿或修改原事实 |
| 正式已提交，草稿清理 / 重读失败 | 明确“已保存，收尾未完成”，专用收尾动作 | 输入按已有逻辑冻结；只重试清理 / 读取，不出现再次提交入口 |
| 删除写入失败 / 已删除但收尾失败 | 前者保留对象，后者专用收尾；确认动作分层 | 不以返回时重复删除替代收尾；删除复盘不删除时间事实 |
| 放弃草稿失败 | 留页保留并允许重试 | 不能显示已放弃；只清当前入口键，不影响其他日期 / 原 ID 草稿 |

冲突提示按UI-D06使用已有类型与完整区间，ID置于辅助详情。活动名查询已明确排除本轮；不修改LedgerFactInterval、持久化或事务判定来塞入文案。

## 6. 任务依赖与执行约定

第2节已补全UI设计选择，表中UI-N / A / S / G / M / R / W均映射第4节来源；实现任务的设计来源现在可读，不再额外等待未创建的spec。任务交付与平台验收仍按各自Acceptance criteria / Validation取得证据。每次只执行负责人指定的任务并停止。

| 任务 | 依赖 | 交付 |
| --- | --- | --- |
| UI-T01 | 已完成 E6-T02 / E6-T04 / E7-T05，选定图 | 已交付连续时间轴，见UI-T01报告 |
| UI-T02 | UI-T01；已采纳UI-N视觉部分 | 已交付共享主题与启动样式，见UI-T02报告 |
| UI-T03 | UI-T02；UI-D01 / D02 / D07 / D09 | 已交付：日期头、覆盖、比例条、统一展示单位；见[UI-T03报告](../reports/UI_T03_OVERVIEW_REPORT.md) |
| UI-T04 | UI-T03；UI-D01–D03、D09 | 已交付：Android根导航、创建动作、共享日期与会话滚动；见[UI-T04报告](../reports/UI_T04_NAVIGATION_REPORT.md)。正式复盘卡由T09交付 |
| UI-T05 | UI-T02；UI-D04–D06、D09 | 活动新建 / 更正表单 |
| UI-T06 | UI-T02；UI-D05、D06、D09 | 睡眠表单与首次确认样式 |
| UI-T07 | UI-T02；UI-D05、D06、D09 | 目标管理及选择展示 |
| UI-T08 | UI-T03；UI-D07、D09 | 摘要展示，复用T03统一格式 |
| UI-T09 | UI-T08；UI-D01、D03、D06、D07、D09 | 复盘读取与账本正式结果卡 |
| UI-T10 | UI-T02；UI-D01、D03、D05–D07、D09 | 复盘编辑表单 |
| UI-T11 | UI-T04–UI-T10；UI-D08及各页条目 | Web宽屏适配 |
| UI-T12 | UI-T01–UI-T11 | 本次 UI 改造的跨页与两平台回归证据 |

T05 / T06 / T07 / T10 可从现有入口独立验收，不必等待根导航；T08在T03统一格式后独立验收。T01 / T02是已交付前置，不自动重做。所有任务仍需明确授权，规划补全不等于开始T03。

共同代码验证：仅格式化本任务改动 Dart，随后 dart format --output=none --set-exit-if-changed <改动文件>；flutter analyze --no-pub；TZ=Asia/Shanghai flutter test --no-pub <相关测试路径>；git diff --check。新增布局验证建议覆盖 320 / 360 / 412 逻辑像素手机宽度、文字缩放 1 / 1.5 / 2、长中文与多行 emoji；这是拟定测试矩阵，不是本轮通过结果。使用当前 SDK 的 Android 触控目标、标签与文字对比度 guideline 检查，并人工核验状态不只依赖颜色。

以下新增代码 / 测试文件名都是职责候选，执行时再核对当前实现；不预先创建目录。controller 文件主要作为受保护合同和回归对象，不因改布局自动获准重写。若 UI state 必须小幅调整，需在指定任务范围中说明理由，继续使用原 saver / editor 和草稿合同。

### UI-T01 — 改造现有日账本连续时间轴（已交付）

- ID / Title：UI-T01 / 日账本连续时间轴。
- Goal：在已有日账本中交付方案三最明确的视觉部分，独立证明可读性和事实身份不变。
- Depends on：依赖表所列已完成任务与选定图，无待确认导航 / 折叠建议。
- Source documents：设计说明的已确认方向、时间轴规则；RULES / TB-002、TB-004、SL-002、LEDGER-001–007；DERIVED / segments、hasApproximation。
- Scope / 涉及文件：lib/features/ledger/presentation/day_ledger_timeline.dart；原交付为局部样式，随后由UI-T02统一主题；test/features/ledger/presentation/day_ledger_timeline_test.dart、test/app/day_ledger_timeline_test.dart、test/app/day_ledger_goal_rhythm_test.dart；必要的布局 / 视觉测试。
- Out of scope：根主页、全局主题、日期控件、全天条、底部导航、折叠交互、保存流程、分类图标推断、controller / domain / data 改写。
- Acceptance criteria：稳定左时间列、连续轨道、标题优先与右侧时长；Known / Sleep / Unknown / Gap 有文字和形状区分；Unknown 已交代并保留已有可选内容；所有原编辑 / 删除 / Gap 回调仍带相同源身份与区间。睡眠同时标明当日切片与完整事实起止 / 时长，近似各自按来源显示；长文本可换行，手机放大字体无遮挡。
- Validation：共同代码验证；以上三份测试；补充混合四状态、长文本和跨日独立精度的布局 / 截图证据。现有跨日测试应继续证明切片没有继承被裁掉的近似，再单独证明完整睡眠保留近似，不能只删除旧断言。人工对照两张选定图验收轨道、层级和节点；组件通过不写成主页已完成。

### UI-T02 — 最小主题与启动状态（已交付）

- ID / Title：UI-T02 / 深蓝主题与基础视觉样式。
- Goal：给实际多页复用提供统一色彩、文本和控件样式。
- Depends on：UI-T01、已采纳的UI-N视觉标注；导航不在本任务实施。
- Source documents：选定图、UI-N 标注、APP / 按需共享 UI。
- Scope / 涉及文件：lib/app/main_app.dart、lib/app/bootstrap/app_bootstrap.dart；已新增 lib/app/theme/time_ledger_theme.dart；test/app/bootstrap/app_bootstrap_test.dart 与主题样式测试。T01原局部主题已统一为全局消费，见UI-T02报告。
- Out of scope：新导航、页面重排、主题切换功能、字体包 / 依赖、改变启动错误恢复方式。
- Acceptance criteria：正常应用和启动中 / 启动失败颜色一致；主次文字、禁用 / 焦点 / 错误均可辨；原状态消息和操作保持；已有时间轴可消费全局主题，无第二套大设计系统。
- Validation：共同代码验证；启动状态及代表性表单 / 对话框截图；文字缩放、guideline 检查。颜色常量不写镜像 getter 测试。

### UI-T03 — 账本日期、覆盖与全天时间条（已交付）

- ID / Title：UI-T03 / 日账本头部与时间分布。
- Goal：把现有投影呈现为方案三头部，先从现有日账本入口验收。
- Depends on：UI-T02；UI-D01、UI-D02、UI-D07、UI-D09。
- Source documents：UI-N视觉部分及对应UI-D；Q-009、Q-014、Q-017、Q-021；DERIVED / W、覆盖及Gap；现有DayLedgerController。
- Scope / 涉及文件：day_ledger_page.dart、summary_formatting.dart 的纯展示；拟新增同presentation下day_ledger_overview.dart、day_ledger_time_bar.dart；day_ledger_page_test.dart、新布局 / 比例 / 格式测试及共享格式影响的时间轴 / 睡眠 / 摘要 / 复盘测试。
- Out of scope：导航 shell、额外统计、重新实现 Gap / coverage 投影、把未来时间记成 Gap。
- Acceptance criteria：落实UI-D01 / D02日期与时间条、UI-D07最终分钟转小时分钟；“今天”跟随与明确日期不同，Unknown包含在已交代中。条宽按毫秒与当地真实日边界，未来中性且不可补记；空窗口不除零，短段在列表有大入口。读取失败不显示旧结果，刷新隔离旧请求；单位变化不改hasRecords、近似、微小时长和舍入，共享呈现保持一致。
- Validation：共同代码验证；day_ledger_page_test.dart、day_ledger_controller_test.dart、test/app/day_ledger_entry_test.dart、summary_formatting_test.dart及受影响共享展示测试；用图例、非24小时日、DST刻度和微小区间核对坐标。验证59 / 60 / 61分钟、正时长舍入零、约与缺失；截图验证头部换行及状态。

### UI-T04 — Android 根导航与创建动作（已交付）

- ID / Title：UI-T04 / 回看、记录、复盘根入口。
- Goal：用选定底部构图承接现有全部能力。
- Depends on：UI-T03；UI-D01–UI-D03、UI-D09。
- Source documents：UI-N；APP / 注入与导航；Q-010、Q-012、Q-023；原 app 路由测试。
- Scope / 涉及文件：lib/app/main_app.dart；按需新增 lib/app/navigation/ledger_shell.dart；day_ledger_page.dart、day_summary_page.dart、review_context_page.dart 的必要入口适配；test/app/day_ledger_entry_test.dart、gap_recording_flow_test.dart、sleep_first_open_flow_test.dart、review_route_flow_test.dart、goal_entry_test.dart。
- Out of scope：领域 / 存储改写、删除能力、新路由包、把创建动作变成独立页面目的地、UI-T09正式复盘卡的读取展示。
- Acceptance criteria：落实UI-D03底栏、创建模态、更多入口、返回顺序和会话滚动范围；正文不被SafeArea栏遮住，大字允许增高。账本 / 复盘 / 摘要共用日期，复盘正式改日才更新根选择。首次睡眠沿用原协调器，编辑或模态不被重复提示打断；切页不重复实例化表单或绕过flush。
- Validation：共同代码验证及所列路由回归；增加日期、滚动、创建取消、系统返回、无重复提示与底栏遮挡测试；Android 实际触控、返回和旋转检查。旧测试入口可调整，事实 / 草稿断言不能删除。

### UI-T05 — 活动记录与更正表单

- ID / Title：UI-T05 / 活动表单视觉改造。
- Goal：在既有保存合同内呈现活动优先的输入层级。
- Depends on：UI-T02；UI-D04–UI-D06、UI-D09（UI-A / 目标选择）。
- Source documents：UI-A；RULES / TB、RH、MODEL-002、LEDGER-010；Q-003–007、Q-012、Q-013、Q-023。
- Scope / 涉及文件：recording_form.dart、recording_rhythm_input.dart；保留 recording_form_controller.dart 合同；test/features/ledger/presentation/recording_form_test.dart、recording_form_storage_test.dart、recording_goal_test.dart、recording_rhythm_details_test.dart；相关 app flow tests。
- Out of scope：改建议算法、减少 optional 字段、增必填、单键 Unknown 自动正式保存、改变草稿存储键。
- Acceptance criteria：所有既有字段和手动输入仍可达；折叠保留字段、显示已有内容并暴露错误；Known / Unknown 转换和节奏转换不清空值。主保存 / 次级草稿返回 / 放弃清楚；键盘打开可操作。读 / 草稿写 / 正式写 / 时间冲突 / 源缺失 / 提交后收尾失败按第 5 节逐项成立。
- Validation：共同代码验证；以上 widget、recording_submission_controller_test.dart、test/app/basic_recording_flow_test.dart、gap_recording_flow_test.dart、day_ledger_editing_flow_test.dart；Android 键盘与返回；若布局导致 controller 生命周期变化，当任务内补真实重启 / Web 刷新草稿验证，不等待 T12。

### UI-T06 — 睡眠表单与首次确认

- ID / Title：UI-T06 / 独立睡眠输入。
- Goal：清楚呈现完整跨日起止和各自精度。
- Depends on：UI-T02；UI-D05、UI-D06、UI-D09（UI-S）。
- Source documents：UI-S；RULES / SL、TB-002；Q-010、Q-012、Q-013。
- Scope / 涉及文件：sleep_form.dart、sleep_time_input.dart；main_app.dart 中首次确认对话框样式；保留 sleep_form_controller.dart 和 app/bootstrap/sleep_entry.dart 合同；睡眠 presentation / app tests。
- Out of scope：睡眠质量、把 nap 关联 recovery、拆日保存、改变已记录免打扰、替换 controller。
- Acceptance criteria：主睡眠 / 小睡、起止日期时间、独立精度和 note 可用；更正 / 删除及完整事实保持；恢复提示、保存层级与键盘空间明确。首次确认可以继续账本，已有主睡眠不重复打扰；第 5 节相关失败和收尾状态不丢。
- Validation：共同代码验证；sleep_form_test.dart、sleep_submission_test.dart、sleep_editing_test.dart、test/app/sleep_first_open_flow_test.dart、sleep_draft_entry_test.dart、sleep_recording_flow_test.dart；实际 Android 输入跨日 / 独立精度 / 返回；涉及 lifecycle 的调整同 T05 当任务内验证。

### UI-T07 — 目标管理和选择展示

- ID / Title：UI-T07 / 目标页与选择器。
- Goal：减少视觉噪声，保留全部简单目标生命周期。
- Depends on：UI-T02；UI-D05、UI-D06、UI-D09（UI-G）。
- Source documents：UI-G；GO-001 / GO-002；Q-006、Q-015、Q-019。
- Scope / 涉及文件：goals_page.dart、goal_rename_dialog.dart；recording_form.dart、review_form.dart 中目标选择展示；test/features/goals/presentation、recording_goal_test.dart、test/app/recording_goal_flow_test.dart。
- Out of scope：Goal 草稿持久化、名称去重、任务管理或改引用政策。
- Acceptance criteria：active / archived 明确；重名保持独立；创建 / 改名 / 归档 / 恢复 / 删除确认可达；失败保留名称。被引用目标的删除仍按原逻辑归档，原归档关联仍可读；读取失败不当空列表；提交成功后读取失败仅重读。
- Validation：共同代码验证；goals_page_test.dart、goal_management_test.dart 与记录 / 复盘目标回归；小屏、长名称、归档标识和对话框键盘截图。

### UI-T08 — 摘要展示

- ID / Title：UI-T08 / 描述性摘要。
- Goal：让覆盖、完整睡眠与目标细分可读而不混算。
- Depends on：UI-T03、UI-M（UI-D07、UI-D09）。
- Source documents：UI-M；DERIVED；Q-010、Q-014、Q-017、Q-020、Q-021。
- Scope / 涉及文件：day_summary_page.dart、sleep_summary_view.dart、goal_rhythm_summary_view.dart；复用UI-T03统一格式，仅在必要时补纯展示适配；摘要tests及受共享组件影响的复盘tests。
- Out of scope：统计表、评分、睡眠因果、趋势功能、改变舍入 / 参与集。
- Acceptance criteria：覆盖三量关系、主睡眠 / 小睡、多段、目标四项及全局恢复清楚；归档目标 / 同名 ID 独立。缺失、近似、少于一分钟各自正确；共享视图在复盘仍可读。日期与失败语义保持。
- Validation：共同代码验证；test/features/ledger/presentation/day_summary_*.dart、summary_formatting_test.dart、test/app/day_summary_recalculation_flow_test.dart 及受影响复盘 tests；长列表和文字放大截图。

### UI-T09 — 复盘读取与账本正式结果卡

- ID / Title：UI-T09 / 已保存复盘的读取展示。
- Goal：从账本按所选日读回正式解释和第一步。
- Depends on：UI-T08；UI-D01、UI-D03、UI-D06、UI-D07、UI-D09（UI-R读取 / UI-N结果卡）。
- Source documents：UI-R；DR-001–004；Q-001、Q-006、Q-013；现有 ReviewContextLoader。
- Scope / 涉及文件：review_context_page.dart、review_facts_view.dart、review_context_controller.dart 的必要展示适配；账本主页组装中的只读复盘卡；test/app/review_route_flow_test.dart、review_context_entry_test.dart。
- Out of scope：用草稿第一步作为正式结果、新增首页统计源、自动复盘、擅自设计草稿存在性查询。
- Acceptance criteria：正式不存在 / 读取失败 / 已保存分开；已保存卡只用正式 ReviewContext，无法读取不显示旧第一步；第一步全文可访问，次日日期与归档 Goal 正确。编辑改日 / 删除返回后重读，事实变更不覆盖复盘文字；事实折叠按UI-D07。
- Validation：共同代码验证；review_context_controller_test.dart、所列路由 tests、test/app/day_summary_recalculation_flow_test.dart；长第一步、历史日、改日期 / 删除及卡片读失败截图与组合回归。

### UI-T10 — 复盘编辑表单

- ID / Title：UI-T10 / 概述、反思和明天第一步。
- Goal：按方案三层级改造编辑体验，保留独立草稿和安全提交。
- Depends on：UI-T02；UI-D01、UI-D03、UI-D05–UI-D07、UI-D09（UI-R编辑 / UI-G目标选择）。
- Source documents：UI-R；DR、MODEL-002；Q-001、Q-012、Q-013、Q-015。
- Scope / 涉及文件：review_form.dart、review_facts_view.dart；保护 review_form_controller.dart；test/features/review/presentation、test/app/review_form_entry_test.dart、review_submission_flow_test.dart、review_correction_flow_test.dart、review_deletion_flow_test.dart。
- Out of scope：合并 continuationHint / TomorrowFirstStep、改变必填第一步、自动填反思 / 下一步、持久化统计。
- Acceptance criteria：summary / reflection 可空，只有一个正式第一步；日期编辑和下一自然日提示明确。全文、多行与原始草稿格式保持；刷新事实上下文不覆盖输入；草稿恢复、日期竞争、源不存在、Goal 状态变化和提交 / 删除后收尾失败均可辨且可处理。
- Validation：共同代码验证及所列 tests、test/app/review_closure_flow_test.dart；实际 Android 键盘、长文本、返回；影响 controller 生命周期时当任务内跑同页 Web 刷新与 Android 草稿恢复证据。

### UI-T11 — Web 宽屏适配

- ID / Title：UI-T11 / 宽屏布局与键盘操作。
- Goal：用相同状态、源数据和路由承接宽屏呈现。
- Depends on：UI-T04–UI-T10；UI-D08及各页条目（UI-W）。
- Source documents：UI-W；APP / presentation state 与依赖边界；Q-012、Q-022。
- Scope / 涉及文件：app/navigation/ledger_shell.dart（如已创建）、各受影响页面的布局包装；拟新增少量共用自适应布局；相应 widget / app 路由 tests。
- Out of scope：第二个编辑会话、布局专用持久化、桌面平台支持、新路由 / 状态包。
- Acceptance criteria：按UI-D08的840 / 1200断点及列最小宽度回退；右栏只读内容与来源明确，独立目标 / 摘要不重复右栏。resize不丢日期、滚动或编辑实例，不重复提交；键盘按UI-D06，可见焦点和语义标签清楚，全部失败状态可达。
- Validation：共同代码验证；839 / 840 / 841、1199 / 1200 / 1201、800 / 1024 / 1440及窄窗、大字、横屏截图 / 交互；同源同页刷新恢复，用生产Web存储，不以widget resize或内存库替代。

### UI-T12 — UI 改造回归与证据收束

- ID / Title：UI-T12 / 页面、导航与平台回归。
- Goal：汇总本次视觉与交互改动的真实证据，检查既有闭环未因 UI 迁移受损。
- Depends on：UI-T01–UI-T11 完成；各页失败测试在其任务内已经通过。
- Source documents：本计划UI-D及现有UI-N视觉规格、已完成E4–E9的相关合同与平台报告。
- Scope / 涉及文件：受影响 test/app 和 integration_test；复用既有平台驱动，仅在入口变化确需时更新定位；新增 UI 改造验收报告及截图索引。
- Out of scope：Epic 10 工作包细化 / 执行、全 MVP 发布验收、部署、浏览器矩阵扩张、无风险依据反复跑所有旧测试。
- Acceptance criteria：Android 主要路径从账本到活动 / 睡眠 / 目标 / 摘要 / 复盘均可完成；导航、键盘、安全区、大字和宽屏有实际截图 / 操作记录。草稿不混入正式结果；真实提交失败不成功；已提交后收尾不重复写；改日 / 删除后重读准确。
- Validation：最终 format / analyze 与受影响测试集合；按 UI 改动选择并复用 recording / sleep / review 等平台流程，Android 实际强停重开和 Web 同源同页刷新分别留证。用隔离 run ID 和测试库；记录设备、浏览器、命令、失败注入、截图及未执行项，不把 synthetic 结果外推成人工视觉验收。

## 7. 本次补全验证、下一任务与停止点

本次补全范围为UI-D01–UI-D09、设计交付映射、过时基线及依赖修正。UI-T01 / UI-T02的交付来自已有报告和当前代码，未重跑其测试。首个尚未实施任务为**UI-T03**：日期头、比例条及统一小时分钟格式；其设计来源已补齐，可在负责人明确指定后执行。随后UI-T04承接根导航；其他可独立的页面任务按第6节依赖执行。

本次检查本地引用、UI-D01–UI-D09及12个UI-T编号、任务完整字段、依赖无环、计划中的设计来源覆盖与空白。修改前对全部已跟踪及非忽略未跟踪文件记录SHA-256，修改后确认只有本计划有本次增量，已有代码 / 测试 / UI-N视觉规格 / 报告均保持原样。原388文件及初稿“只新增本文件”是2026-10-03历史证据，不作为当前工作区状态。

Dart formatter、flutter analyze、Flutter测试及平台运行均为N/A：本次只有计划文档变化。尚未验证新导航、时间条、小时分钟、表单折叠、宽屏或键盘；实际截图、状态图与平台验证在对应UI-T内交付，不以生成图或本计划代替。

报告后停止。没有开始UI-T03或其他代码任务，没有细化或执行Epic 10，没有提交或推送。


## 8. UI-T03执行记录（2026-10-04）

负责人明确指定并在补齐计划后继续执行UI-T03，已完成日期头、覆盖、只读比例条与统一小时分钟；修改文件、真实命令结果、实际widget截图及未执行平台项见[交付报告](../reports/UI_T03_OVERVIEW_REPORT.md)。UI-D01–UI-D09决策原样保留；第1、3、7节的实现基线与“本次补全验证”是计划文档补全阶段的留存记录，不代表这次UI代码任务的验证结果。

仅UI-T03交付；整个主页、根导航及根层跨页日期状态尚未完成。完成后停止，没有执行UI-T04或Epic 10，没有提交或推送。

## 9. UI-T04执行记录（2026-10-04）

负责人明确指定UI-T04，已完成回看 / 创建 / 复盘根入口、创建与更多模态、共享浏览日期、返回顺序及最近7日期的会话源锚点恢复。沿用现有投影、格式化、编辑 / 删除 / Gap回调、首次睡眠协调器及表单flush；没有修改领域、持久化、主题或表单。完整增量文件、282项相关回归、实际Android触控 / 键盘返回 / 旋转结果、手机大字截图及检测限制见[UI-T04交付报告](../reports/UI_T04_NAVIGATION_REPORT.md)。

第7节及第8节是各自阶段的留存记录。此次仅UI-T04交付，整个主页与后续表单、正式复盘卡、Web宽屏仍未完成；没有以模拟器或widget截图外推实体手机、真实Web刷新或全MVP验收。完成后停止，没有执行UI-T05–UI-T12或Epic 10，没有提交或推送。
