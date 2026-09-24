# Agent Operating Rules

适用于 Time Pet Ledger 仓库中的 AI coding agents。本文规定工作方式，不定义产品功能。任务必须来自用户明确指定的范围；读取本文件或 TASKS.md 不代表获准开始开发。文档阶段只修改该阶段允许的文档，禁止因看到待办而开始实现。

## Source of Truth Priority

首先阅读 [time-ledger-domain-model-v4-proposal.md](time-ledger-domain-model-v4-proposal.md)。它是当前产品 / 领域 Source of Truth；本项目按 Greenfield 执行，源文件中的历史实现讨论不构成实施工作。

派生文档按以下优先级和职责使用，不能仅凭文件日期或代码现状覆盖来源：

| 优先级 | 文档 | 权威范围 |
| --- | --- | --- |
| 1 | Source of Truth | 产品与领域的确定结论 |
| 2 | [DOMAIN_RULES](docs/domain/DOMAIN_RULES.md) | invariant、validation、constraint、业务规则 |
| 3 | [DOMAIN_MODEL](docs/domain/DOMAIN_MODEL.md) | 对象、字段、关系与事实来源 |
| 4 | [DOMAIN_STATE_MACHINES](docs/domain/DOMAIN_STATE_MACHINES.md)、[DERIVED_MODELS](docs/domain/DERIVED_MODELS.md) | 分别负责生命周期与派生计算；受规则和对象定义约束 |
| 5 | [PRODUCT_PRINCIPLES](docs/product/PRODUCT_PRINCIPLES.md) | 产品取舍与交互原则 |
| 6 | [PRODUCT_DEFINITION](docs/product/PRODUCT_DEFINITION.md) | 产品问题、闭环与边界 |
| 7 | [APP_ARCHITECTURE](docs/architecture/APP_ARCHITECTURE.md)、[DATA_ARCHITECTURE](docs/architecture/DATA_ARCHITECTURE.md) | 分别负责代码组织与持久化；Engineering Recommendation 不是产品要求 |
| 8 | [MVP_SCOPE](docs/planning/MVP_SCOPE.md)、[IMPLEMENTATION_PLAN](docs/planning/IMPLEMENTATION_PLAN.md) | 分别负责发布范围与 Epic 顺序 |
| 9 | [TASKS](TASKS.md) | 当前任务粒度、范围、依赖与验收 |

[OPEN_QUESTIONS](docs/domain/OPEN_QUESTIONS.md) 是贯穿各层的未决事项登记表，不是低优先级的可忽略附件。UNDECIDED、候选选项、示例和 Engineering Recommendation 均不构成产品答案。本文只约束 agent 行为，不凌驾于产品 / 领域定义。

### 冲突与缺失

- **代码与文档冲突：** 以确定的产品 / 领域来源为准，定位受影响规则；在当前任务范围内修复代码，不为迁就代码改写领域文档。若修复超出任务，报告冲突和影响，不顺手扩大实现。
- **两份文档冲突：** 回到源提案核对，并按文档职责判断。例如计算公式看 DERIVED_MODELS，不能从一个 Task 的简写重定义公式。确定的事实性抄写错误可以在授权文档范围内纠正；若答案仍不唯一，暂停依赖该答案的部分，登记问题，不擅自择一。
- **源提案内部不一致：** 报告具体章节和证据。已登记的 §18 时长算术错误见 DOMAIN_RULES 的一致性检查，不把错误总量复制到测试；intendedDate 的存储缺口见 Q-001，不能用算术修正方式替产品选择日期政策。
- **Source of Truth 无法回答：** 先查 OPEN_QUESTIONS，已有问题引用原编号，新增问题使用既有格式追加稳定编号。不通过默认值、nullable、框架行为或测试夹具偷偷作答。说明影响并请求缺失产品决策；当前任务内独立、不受影响的部分可以继续。阶段禁止修改问题表时，在报告中提出问题，等待允许的文档更新。
- **用户明确给出新决定：** 记录可追溯的决定，更新职责对应的文档及原问题状态后实现；不要把旧文档当作拒绝用户明确指令的依据。没有明确决定时，agent 不能将 UNDECIDED 自行改为已解决。

## Agent Workflow

每个被明确指定的 Task 按顺序执行：

1. **Read task：** 读完整 Task，包括 Depends on、Out of scope、Acceptance criteria 和 Validation；检查前置完成证据与问题状态。
2. **Read referenced source documents：** 重读 Source of Truth、任务引用文档及相关 OPEN_QUESTIONS；按职责读取相邻文档，识别冲突。
3. **Inspect existing implementation：** 检查现有文件、测试及工作区改动，保留用户和其他 agent 的修改；定位时优先使用 rg / rg --files。
4. **Identify affected files：** 列出本任务确需修改的文件；目录只在有实际职责时创建。
5. **Produce short implementation plan：** 简述修改、依据、验证与未决边界；常规可逆实现无需重复索取已经取得的授权。
6. **Implement only requested scope：** 仅实现该任务，遵守依赖方向与领域合同；发现阻塞时不以临时产品行为绕过。
7. **Add/update tests：** 为新增或改变的领域行为、计算、持久化约束和失败路径增加相关测试；不机械测试枚举声明、getter 或纯转发方法。
8. **Self-review diff：** 检查范围、规则、未决项、意外格式化、依赖变化及文档一致性；新建未跟踪文件也必须检查。
9. **Run formatter：** 格式化本次改动的 Dart 文件，避免无关文件重排；随后验证格式。
10. **Run static analysis：** 在正确工程目录运行静态分析，记录新增问题与既存基线问题。
11. **Run tests：** 运行任务要求的相关测试及必要集成验证；失败后修正并重跑受影响部分，已通过且无新风险不无意义重复。
12. **Report result：** 报告 Task ID、修改文件、行为和规则依据、实际验证命令与结果、未决 / 未通过项及限制。未执行不能写通过，部分完成不能标完成。
13. **Stop：** 完成当前 Task 后停止；不得自动执行下一 Task 或下一阶段。

## Scope Discipline

不得修改无关功能、顺手重构整个项目、擅自扩展需求、改变 Domain Model、引入依赖、自动处理下一 Task，或遇到领域歧义时猜测。

依赖仅能在用户授权且任务明确包含的选型 / 接入范围内新增，说明必要性、选择依据及对平台的影响；其他任务不得顺带安装包或修改 pubspec。架构建议本身不是安装所有建议依赖的授权。常规内部命名和小型实现组织可在明确合同内自行选择，无需将每个工程细节升级为产品问题。

保持以下不可混淆的边界，完整定义引用领域文档：

- TimeBlock 描述事实，RhythmAnnotation 是可选解释；progress / stuck / recovery 不能成为 TimeBlock 类型。
- SleepSession 独立，跨日保留原事实；自然日是查询 / 投影边界。
- Unknown 是已交代的持久化事实，Gap 是未处理的派生区间；DayLedgerView、Gap 和聚合统计不成为持久化事实源。
- Goal 仅为时间归属；DailyReview 保存解释与下一步，continuationHint 不等于 TomorrowFirstStep。
- Approximate 合法，起止精度独立；统计描述事实，不评分、不自动评价用户，也不把睡眠关联说成因果。

完整功能排除清单以 MVP_SCOPE 的 Explicitly Out of Scope 为准。不得引入通用实体基类、通用 repository / use-case 框架、event sourcing、CQRS、microservices、插件架构、提前的同步架构或庞大设计系统来替代当前小规模需求。

纯 domain 不依赖 Flutter、数据库或全局当前时间；repository interface 位于 feature/domain，具体持久化在 feature/data，派生计算在 ledger/domain/projection，UI state 在 presentation。跨事实写入的一致性按 DATA_ARCHITECTURE 落实，不以 UI 预检替代原子约束。

## Cost-aware delegation

非简单开发任务中，若需要跨多个文件 / 目录定位未知代码、理解跨文件调用或状态变化、核查当前外部技术资料，或存在可独立并行调查的失败假设，主 agent 必须委派一个有界只读勘查任务。

仓库定位使用 `code_mapper`，外部官方资料研究使用 `docs_researcher`。若命名角色不可用，使用默认子 agent 并保持同样的只读范围。提供新鲜、最小上下文：明确问题、相关路径、限制和证据要求，不复制整段对话，不要求多个 agent 全仓扫描。报告应简洁，附路径与行号或直接来源链接、结论和剩余不确定性；主 agent 检查证据后才能采用。

实现决策、编辑、集成、安全敏感分析、最终验证与用户报告由主 agent 负责。已有答案、无实质定位需求的小改动，或委派开销高于工作时不委派。首轮至多两个勘查 agent，通常至多一轮跟进；没有明确独立范围不递归委派。

## Definition of Done

任务只有满足以下适用条件才可标记完成：

- Required behavior implemented：本任务要求全部交付，Acceptance criteria 均有证据。
- Domain rules satisfied：字段、规则、生命周期及派生口径一致，相关产品阻塞已解决。
- Relevant tests added：相关行为及失败路径有必要测试，不以测试固化未决答案。
- Formatting passes：改动 Dart 文件的格式检查通过。
- Static analysis passes：静态分析通过；既存失败如实报告，未验证不能视为通过。
- Tests pass：任务要求的测试通过，涉及持久化和平台的验证不能以纯 mock 代替。
- No unrelated modifications：无无关改动，没有覆盖他人工作、引入范围外能力或未授权依赖。
- Documentation updated if required：必要文档更新在授权范围内完成，Task 结果与问题状态不失真。

只读基线任务以完成检查并如实报告为交付，不要求在该任务内修复既存失败；任务交付与工程基线通过必须分别报告。基线失败仍影响后续依赖该能力的任务。只读基线任务或纯文档任务可将不适用的代码格式化 / 测试标记为 N/A，并说明理由；文档任务改查链接、编号、依赖、职责与范围。环境不可用时报告具体阻塞和未执行检查，不标记验证通过，不安装无关工具来凑出结果。最终报告后停止。
