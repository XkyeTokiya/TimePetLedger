# App Architecture

## 职责、依据与当前状态

本文回答“Flutter 代码未来怎么组织？”。产品 / 领域依据为 [Source of Truth](../../time-ledger-domain-model-v4-proposal.md)、[DOMAIN_MODEL](../domain/DOMAIN_MODEL.md)、[DOMAIN_RULES](../domain/DOMAIN_RULES.md)、[DOMAIN_STATE_MACHINES](../domain/DOMAIN_STATE_MACHINES.md) 和 [DERIVED_MODELS](../domain/DERIVED_MODELS.md)。未决行为见 [OPEN_QUESTIONS](../domain/OPEN_QUESTIONS.md)，持久化细节集中在 [DATA_ARCHITECTURE](DATA_ARCHITECTURE.md)。

当前仓库只有 Flutter 最小入口；pubspec 只有 Flutter 与测试 / lint 依赖。下文是 Greenfield 第一版的组织方案，本阶段不创建目录骨架、Dart 文件或安装依赖。

- **Domain Decision：** 来源已经确定的领域边界，不由架构选择改写。
- **Engineering Recommendation：** 本文提出的文件组织、依赖、接口与测试方式，不是产品要求。除标记为 Domain Decision 的段落外，本文设计均属这一类。
- **UNDECIDED：** 仍未明确的产品语义保留对应 Q 编号，不在实现默认值中作答；首发平台范围已由 Q-022 确定。

## Domain Decision：架构必须保留的边界

| 领域决定 | 架构影响 | 依据 |
| --- | --- | --- |
| 时间事实与节奏解释分离，annotation 可选 | 模型独立；不能把节奏类别做成 TimeBlock 类型 | TB-008、RH-001–RH-008 |
| SleepSession 是独立身体事实 | 独立类型与存储映射；不从属 Recovery | SL-001–SL-005 |
| 主轴不允许主要事实重叠 | TimeBlock 与 SleepSession 的写入检查必须覆盖彼此 | LEDGER-004 |
| Gap 与自然日视图派生，Unknown 保存 | 对账计算不写入 Gap / Day；unknown 走正常事实保存 | LEDGER-001–LEDGER-003 |
| Goal 仅是时间归属 | 功能边界围绕归属，不引入任务管理 | GO-001 |
| DailyReview 保存解释与下一步 | 不把统计数值写回复盘，不合并两种下一步语义 | DR-002、DR-004 |

具体字段、规则与公式仍由以上领域文档维护，本文件不复制其实现。

## Engineering Recommendation：按功能组织，按复杂度分层

建议三个 feature：`ledger`、`goals`、`review`。账本承担普通时间、节奏解释、睡眠、日投影及其描述性汇总。睡眠拥有独立领域模型和记录入口，但不必因此新建一个跨仓库协调的 feature。把两类主要事实放在同一功能的写入边界内，有利于一致地检查重叠。

建议结构如下；只有实际开发到该职责时才创建文件或目录，标为按需的 application 不预先建空壳：

```text
lib/
  main.dart                     # 启动并交给 app 组装
  app/
    bootstrap/                  # 连接、具体实现及依赖的组装与释放
    navigation/                 # 应用导航
  core/
    time/                       # 确有跨 feature 复用的纯时间 / 日期值与转换约定
    persistence/                # 单库连接、事务基础能力；不包含业务表模型
  features/
    goals/
      domain/                   # Goal、其规则、GoalRepository 接口
      application/              # 按需：目标操作的协调，不生成每个 CRUD 的包装类
      data/                     # goals 映射与具体 repository
      presentation/             # 目标相关 UI、controller / view model 与 UI state
    ledger/
      domain/
        projection/             # 纯计算、DayLedgerView、UnresolvedSpan 与汇总
                                # 同层其他文件：TimeBlock、RhythmAnnotation、SleepSession
                                # 枚举、校验与 LedgerRepository 接口
      application/              # 加载窗口、记录保存、重叠冲突与刷新协调
      data/                     # 两类事实及 annotation 的查询、映射、事务写入
      presentation/             # 时间线、记录 / 睡眠输入、汇总及各自 UI state
    review/
      domain/                   # DailyReview、TomorrowFirstStep、ReviewRepository 接口
      application/              # 按需：加载复盘上下文、协调已有事实和用户输入
      data/                     # daily_reviews 映射与具体 repository
      presentation/             # 复盘编辑状态与展示
```

`domain / data / presentation` 各自有明确职责；`application` 只在加载多个来源、协调保存或处理实际流程时增加。简单的 Goal 查询可以由 presentation controller 调用领域内的 repository 接口，不强制经过只转发参数的 use-case 类。`ledger` 的跨事实约束及投影值得保留明确 domain / application；其他功能不机械复制它的深度。

Flutter 官方同样将额外 domain / use-case 层视作按复杂度采用的建议；本项目因已明确的时间投影与领域规则而保留纯领域计算，并不套用整套示例或强制引入其推荐包。[Flutter 架构建议](https://docs.flutter.dev/app-architecture/recommendations)

### core 的边界

`core/time` 只容纳已出现的跨功能共用内容，例如自然日期值的表示；TimePrecision 若只被 ledger 使用，就留在 ledger。`core/persistence` 只管理连接和事务基础设施，表映射仍归 feature/data。共享 UI 组件等到确有复用再提取；core 不成为杂项、全部模型或通用业务服务的堆放处。

## Engineering Recommendation：dependency direction

下面表示源代码依赖，不是数据流或业务执行顺序：

```text
app ──> feature presentation / application / data（组装具体实例）
feature presentation ──> 同 feature application、domain
feature application ──> domain 与所需 repository 接口
feature data ──> 本 feature domain、core/persistence
feature domain ──> Dart 标准纯计算能力、core/time 中的纯值 / 函数
```

| 层 | 允许依赖 | 不应依赖 |
| --- | --- | --- |
| domain | Dart 基础类型、集合、纯计算；确需的纯时间值 | Flutter、BuildContext、状态管理、SQL 驱动、数据库行、文件 / 网络 I/O、全局当前时间 |
| application | domain、repository 接口；通过参数注入的时间 / 日期政策 | Widget、SQL、其他 feature 的具体 data 实现 |
| data | domain 模型与校验、持久化驱动、core/persistence | presentation、页面 controller、application 流程实现 |
| presentation | domain 值、application 操作或简单 repository 接口；Flutter | 数据库连接、SQL 行模型、另一 feature 的内部 controller |
| app | 具体实现、导航、依赖生命周期 | 在 bootstrap 中补写领域规则 |

repository 接口放在各 feature 的 `domain`，数据实现依赖接口而不是反向引用。domain 可声明异步存取合同，但纯投影函数不执行 I/O。

跨 feature 关系保持单向：ledger/application 可以读取 goals/domain 的接口用于目标选择或名称；review/application 可以读取 ledger/domain 与 goals/domain 的接口以取得复盘上下文。goals 不依赖 ledger/review 的 presentation 或具体实现。领域关联使用 `goalId`，不把完整 Goal 图嵌进每条事实。读取目标元数据遵守 Q-006 的归档隐藏规则和 Q-020 的摘要筛选政策。

## Engineering Recommendation：repository 与持久化实现

建议先采用三个小型、用途明确的接口，不创建泛型基类：

| 接口位置 | 职责 | 实现位置 |
| --- | --- | --- |
| goals/domain 的 GoalRepository | 目标读取及已明确允许的目标操作 | goals/data |
| ledger/domain 的 LedgerRepository | 按窗口读取完整时间事实及 annotation；在一个写入边界内保存时间事实并检查跨表冲突 | ledger/data |
| review/domain 的 ReviewRepository | 按复盘日期读取 / 保存解释与 TomorrowFirstStep | review/data |

LedgerRepository 是两类时间事实的共同存取边界，不是合并实体。无需为 annotation 单独暴露可绕开所属 TimeBlock 的任意写入接口，也无需增加通用 UnitOfWork / RepositoryFactory。具体操作按被批准的 Task 增量加入；更正与删除遵循已确定的 Q-003、Q-005、Q-013，不生成范围外覆盖或转换方法。

具体 data 实现负责 SQL 与行映射，把读取结果还原成领域值；不把数据库行或驱动类型泄露到 UI。字段名称相近时直接写小型映射函数即可，不强制每层再复制一套 entity / model / DTO。

Q-013 已允许组合更正 TimeBlock 与 annotation，必须形成单个原子写入，全部成功或全部失败。接口明确表达保留、添加、编辑或移除解释的意图；未请求修改解释时保留，不以空参数或通用 upsert 静默删除、覆盖或重建。

## Engineering Recommendation：纯派生逻辑与调用流程

`features/ledger/domain/projection` 承载 [DERIVED_MODELS](../domain/DERIVED_MODELS.md) 的切片、覆盖、Gap、时长及近似传播。输入是明确的窗口、事实、annotation 和必要政策参数；输出是非持久化领域投影。

加载一次日账本时：

1. application 使用当前设备时区并显式提供当前时刻，按 Q-009 构造对账窗口：历史日完整、今天截至当前时刻、未来日为空；首尾空白纳入 Gap。
2. LedgerRepository 从一致的读取视图取得 TimeBlock、SleepSession 与相关 annotation；以原始事实返回，不预先按日改写事实。
3. application 把结果交给纯投影函数；如需目标名称，再结合 Goal 元数据。sleepSummary 按 Q-010 加载醒来日期对应的完整记录，主睡眠与小睡分别汇总，不能只靠对账窗口裁剪结果。
4. presentation 接收投影并负责格式化、编辑状态和空数据表达，不重复实现时长或 Gap 算法。

写入时，domain 校验单对象及纯重叠判定；application 发起已定义操作；data 实现在同一事务内读取相关事实、再次检查冲突并写入，不能仅依赖事务外的 UI 预检。成功提交后重新加载受影响窗口 / 汇总；失败保留编辑输入并暴露操作结果，不伪装保存成功。原子性方案集中见 DATA_ARCHITECTURE。

## Engineering Recommendation：UI state 与依赖注入

UI state 放在所属 feature/presentation：当前选择日期、输入草稿、正在保存、错误提示、展示投影等。它们不新增领域实体状态；“正在保存”不写入 DailyReview.status，按 Q-012 自动保存本机草稿并跨启动 / 网页刷新恢复，草稿存储由所属 feature 的 application / data 协调，正式 domain 实体不因此增加状态。编辑期间正式事实保持原样，成功提交或主动放弃后清除对应草稿，失败保留。

第一版可采用 Flutter 自带的局部状态与小型 controller / view model；需要通知多个 Widget 的 controller 可使用 ChangeNotifier / Listenable。它们只属于 presentation，不进入 domain。状态管理包与路由包不在本轮选定或安装。[Flutter UI 与状态建议](https://docs.flutter.dev/app-architecture/recommendations)

依赖从 app 的组装处通过构造参数传入。数据库具体实例只在那里创建和释放，不使用全局可变 repository 单例。当前时间可作为函数或值注入需要它的操作，无需为每种基础依赖建立通用框架。Q-022 已确定第一版正式支持 Android 和 Web；其他平台目录不构成首发支持承诺。

## Engineering Recommendation：错误与一致性边界

领域校验返回能定位字段或规则的结果，例如 TB-005；data 层将外键、唯一约束、存储忙或读写失败映射成操作可理解的失败。presentation 不显示 SQL 异常原文，也不把技术失败写成 Unknown 时间。

跨表不重叠必须针对写入前最终数据检查。原子拒绝并提示冲突是 Q-011 已确定的产品行为；自动截断、合并或覆盖冲突事实均不允许。非法数据不能默默丢弃一条后展示成正常完整账本。

## Engineering Recommendation：可测试、可增量、便于 Agent 修改

| 职责 | 后续验证重点 |
| --- | --- |
| domain / projection | 纯输入输出：边界精度独立、Unknown / Gap、跨日切片、不重复计时；沿用 DERIVED_MODELS 手算例子 |
| application | 用小型 fake repository 验证操作协调与错误传播；未决转换不写“默认行为”测试 |
| data | 单库约束、枚举与日期映射、事务回滚、跨两表的并发冲突防护；需要真实存储集成验证 |
| presentation | 输入不会强制原因 / 恢复质量、近似表达、保存失败保留输入等用户可见行为 |

测试目录可镜像 features 结构，按当前 Task 风险增加必要测试，不为纯转发方法机械造测试。文件名按实体、投影或操作命名；规则测试引用稳定规则编号。一个 Task 只触及该行为需要的 domain、data 或 presentation 文件，不因结构图存在就补齐所有文件。

首版不建立通用实体基类、通用 use-case 系统、额外服务端或同步基础设施。持久化驱动须面向 Q-022 已确定的 Android 与 Web 做小范围技术核查，不把具体数据库包泄露到 domain。Epic 顺序见 [IMPLEMENTATION_PLAN](../planning/IMPLEMENTATION_PLAN.md)，具体任务见 [TASKS](../../TASKS.md)；本文不重复安排。

## 产品决定与实施边界

Q-001–Q-023 均已决定；普通记录时间建议按 Q-023 的分支实现，具体入口与初始精度见 DOMAIN_RULES。完成产品澄清不等于相关接口或功能已经实现，仍按用户指定 Task 执行。

Q-022 已确定首发平台为 Android 和 Web。该决定限定后续驱动核验与平台验收范围，但不直接选定持久化包、浏览器兼容矩阵或部署方案。
