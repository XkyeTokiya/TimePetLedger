# Time Pet Ledger 领域模型重构提案

> 基于补充的真实目标，现有 V3 / V3.5 暂视为“历史实现”，重新从产品问题出发建模。
>
> 这次模型的核心变化只有一句话：
>
> **“时间账本事实”是底层；“推进 / 卡住 / 恢复”是对部分时间事实的节奏解释。睡眠则是一类独立的高优先级身体事实。**
>
> 这样既能保住“完整时间账本”，也不会逼所有时间都进入 `progress / stuck / recovery`。

---

## 后续交互决定（2026-10-05）

用户明确并基本认可新的活动记录方向：初版优先问答引导，依次询问节奏、事项、时间；长期目标在三幕持续可见，常用目标由用户明确指定，每笔可更换或取消关联。表单保留为设置中的另一种填写方式。时间调整提供完整无需键盘的路径，大部分基础元件优先采用Material 3成熟组件。

此决定更新§27–28中活动优先的历史入口顺序，不改变本提案的事实与解释分层。节奏仍可不选，Unknown仍为合法事实，目标仍仅为时间归属，睡眠独立；UI中的“休息”承接recovery语义，不把普通生活自动分类为恢复。常用目标和记录方式属于本机交互偏好，不新增领域实体。

决定追溯见[Q-025 / Q-026](docs/domain/OPEN_QUESTIONS.md#q-025)，当前交互规格见[三幕问答设计](docs/planning/GUIDED_RECORDING_DESIGN.md)。2026-10-05用户要求先更新文档；具体视觉、按钮细节、成熟组件的实际平台体验仍待原型与实现验证。以下原章节保留，涉及新的提问顺序时按此决定执行。

### 首页与摘要后续决定（同日）

用户提供首页参考，确认日期仅跨年带年份、仅点击日期选日，首页时间线 / 摘要 / 复盘同日横向切换，保留两个记录按钮。摘要首版以一天及目标时间构成的占比为主；建议区域采用睡眠 > 记录 > 复盘优先级，连续尾部Gap阈值2小时，默认08:00 / 22:00、整体默认开启并可在设置关闭，无命中时问候，暂不提供跳过。复盘AI仅为未来意向。用户随后认可摘要信息量及建议区域位置。

完整设计和素材见[当前前端交接](docs/planning/UI_REBUILD_PLAN.md)，决定追溯见[Q-027 / Q-028](docs/domain/OPEN_QUESTIONS.md#q-027)，执行边界待定见[Q-029](docs/domain/OPEN_QUESTIONS.md#q-029)。这次是设计基线，不改事实对象、统计口径、精度或缺失表达合同，不代表正式前端实施获准或已验收。旧首次睡眠检查与新建议的关系尚未确定。

### 记录原型反馈与精度新决定（同日）

用户明确：目标文字下方用虚线提示可编辑，移除外露的更换 / 取消关联按钮；存在适用子选项时，在节奏之后插入选择页；不显示步骤计数，时间页不再显示节奏 / 事项回改摘要。卡住原因、休息方式与感受仍可不填，推进没有子选项时直接进入事项。

用户再次强调回顾式时间只能是“大概”，精度不交给用户选择。当前回顾式输入统一采用approximate，活动与睡眠都不要求用户声明exact；具体日期 / 时分仍用于区间计算。此决定替代下文非对称精度、精确输入示例及旧精度选择要求；不改变Unknown / Gap区分、不重叠、近似传播和数值不加“约”的显示规则。现有exact事实的处理未被用户指定，本轮不改数据或存储结构，见[Q-030 / Q-031](docs/domain/OPEN_QUESTIONS.md#q-030)。当前交互以[前端交接](docs/planning/UI_REBUILD_PLAN.md)最新修订为准；正式实现另需任务授权。

### 常用目标归档后的处理（2026-10-06）

用户在目标管理讨论中明确选择：成功归档常用目标时清除常用选择，恢复目标后需要用户手动再设，不自动重新成为常用目标，也不自动替换为其他目标。有引用目标的界面删除按既有合同执行归档，适用同样处理；未引用目标被删除后也不保留不可用的常用选择。原记录与草稿仍保留自己的关联，不能因此自动改写。此决定补充[Q-025](docs/domain/OPEN_QUESTIONS.md#q-025)，常用目标仍是本机交互偏好，不新增Goal字段或状态。

### 目标详情投入图（2026-10-06）

用户要求目标详情展示投入图，可在柱状图 / 热力图之间切换，历史记录放在底部默认显示约5条。用户随后明确采用：柱状图为近7天（含今天），热力图的周 / 月分别为本自然周 / 本自然月，今天只统计已发生时间。热力图周 / 月范围通过设置选择。目标仅为时间归属，沿用TimeBlock按goalId归属、自然日裁剪、缺失表达和近似传播合同；不新增统计事实或绩效评分。常用目标改在列表选择并高亮是本轮待评审建议，不登记为已确认入口政策。追溯见[Q-033](docs/domain/OPEN_QUESTIONS.md#q-033)。

用户在本轮后续反馈中明确：柱状图的纵向刻度按实际数据自适应，不固定在4小时；“本月 · 已记录投入”等辅助标签并入时长行末，“常用目标”并入目标名称行末，不再单独占行。该补充只调整展示，不设置投入时长限制。

### 设置页与高级数据操作（2026-10-06）

用户要求设置页先形成可逐步完善的分类入口，高级设置必须包含“添加测试数据”和“清空当前数据”。分类名称与具体布局仍为待评审方案，基础组件沿已确定的Material 3方向。用户明确选择：清空活动、睡眠、目标、复盘及未保存草稿，同时清除常用目标选择，保留界面、记录方式、提醒等设置；测试数据仅允许在数据为空时添加。决定见[Q-034](docs/domain/OPEN_QUESTIONS.md#q-034)。这次授权设置设计与文档固定，不是执行清空、注入测试数据或开始正式实现；不把批量清空误套为单个有引用Goal的删除归档。

## 一、产品的重新定义

建议把产品定义正式改成：

> **Time Pet Ledger 是一个回顾式个人时间账本。它帮助用户以尽可能低的输入成本还原一天，不要求所有时间精确，但对睡眠和目标相关时间保持更高的记录精度。在此基础上，用户可以区分真正的推进、卡住与恢复，看清目标时间中的有效推进和无效消耗，并通过每日复盘留下下一次能够开始的一步。**

这里有五个关键词。

**回顾式。** 产品不是计时器。主要行为不是“开始时启动”，而是“做完一段以后回来补一笔”。

**账本。** 用户最终应该能够大致解释一天怎么过去。

**非对称精度。** 普通生活允许模糊；睡眠和目标推进值得更准确。

**节奏。** `推进 / 卡住 / 恢复` 不再承担完整分类职责，而是目标推进过程的解释层。

**下一步。** 统计不是终点，最终还是为了让下一次启动更容易。

---

## 二、“完整时间账本”到底意味着什么

这里必须先定清，否则以后一定重新走向“每分钟追踪”。

完整不等于：

> 24 小时每一分钟都有精确分类。

完整应该定义成：

> **一天中主要时间去向基本能够被解释；无法回忆的部分也可以被诚实地标记为未知。**

所以一天存在三个不同的数据质量维度，而不是一个“完成率”。

| 维度 | 含义 | 示例 |
| --- | --- | --- |
| 时间覆盖 | 这段时间有没有被账本交代 | 14:00–16:00 有一笔记录 |
| 语义清晰度 | 用户是否知道这段时间大概做了什么 | “外出办事” vs “想不起来” |
| 时间精度 | 起止边界是否可信 | 14:10–15:25 精确；“大约下午两点到四点”模糊 |

三者必须分离。

例如：

> 14:00–16:00「大概在外面办事」

时间覆盖完整，语义也基本知道，但时间精度较低。

而：

> 16:00–17:20「想不起来」

时间覆盖完整，但语义未知。

这两种记录都比假装精确更真实。

---

## 三、产品事实分成三个层级

建议以后所有产品和数据设计都按照这个结构思考。

```text
第一层：身体基础事实
        SleepSession
             ↓
第二层：时间账本事实
        TimeBlock
             ↓
第三层：目标节奏解释
        RhythmAnnotation
             ↓
第四层：每日解释与行动
        DailyReview
        TomorrowFirstStep
```

其中前三层尤其重要。

---

## 四、第一层：SleepSession —— 睡眠独立建模

睡眠不应该继续作为：

```text
RecoveryMethod.sleep
```

的一种。

因为普通夜间睡眠不是“恢复操作”，而是一天最重要的身体背景事实之一。

建议：

```text
SleepSession
- id
- startedAt
- endedAt
- startPrecision
- endPrecision
- type
- note?
- createdAt
- updatedAt
```

其中：

```text
SleepType
- mainSleep
- nap
```

最重要的数据其实只有：

> 几点睡，几点醒。

睡眠质量之类先不要急着做。

### 为什么允许跨日

例如：

```text
2026-09-21 01:20
→
2026-09-21 08:40
```

没有问题。

如果：

```text
2026-09-21 23:50
→
2026-09-22 07:40
```

也应该保存为一个完整 `SleepSession`。

用户不应该因为自然日边界而自己拆成两条。

但是在“9 月 21 日时间线”和“9 月 22 日时间线”展示时，系统自动按照自然日切片。

因此：

> **自然日是展示与统计边界，不应该强迫成为事实对象的存储边界。**

---

## 五、第二层：TimeBlock —— 真正的账本事实

这是新模型的核心对象。

它不再叫：

> progress entry / stuck entry / recovery entry

而只是：

> **这一段时间，大概发生了什么。**

建议模型：

```text
TimeBlock
- id

- startedAt
- endedAt
- startPrecision
- endPrecision

- knowledgeState
- title?

- goalId?
- categoryId?

- note?

- createdAt
- updatedAt
```

### `TimePrecision`

建议直接在数据层承认模糊。

```text
TimePrecision
- exact
- approximate
```

而且最好开始和结束分别保存：

```text
startPrecision
endPrecision
```

因为完全可能出现：

> 我确定自己 16:20 停下来了，但大概三点左右开始的。

于是：

```text
startedAt = 15:00
startPrecision = approximate

endedAt = 16:20
endPrecision = exact
```

这是一个非常重要的改变。

数据库里依然有具体时间用于排序和计算。

但产品不再谎称：

> 15:00 是绝对准确的。

---

## 六、目标相关时间也允许 approximate

这里不建议把：

> `progress` 必须 `exact`

写成强校验。

因为用户可能第二天才想起来：

> 昨天大概 14:30 到 16:00 在写毕业设计。

这仍然是非常有价值的数据。

区别只是统计必须诚实显示：

> **约 1 小时 30 分**

而不是：

> 1 小时 30 分

因此以后所有时间聚合都应该能够携带一个：

```text
hasApproximation
```

例如：

```text
毕业设计明确推进
约 3h40m
```

表示参与计算的某些记录边界是模糊的。

---

## 七、`knowledgeState`：正式允许“不知道”

这是完整账本非常重要的一环。

```text
BlockKnowledgeState
- known
- unknown
```

### known

```text
14:00–15:20
写毕业设计
```

### unknown

```text
15:20–16:10
想不起来
```

`unknown` 不是错误状态。

它是合法事实：

> 我知道这段时间过去了，但现在无法恢复它的内容。

因此不要让用户为了“完整度”随便编一个：

> 刷手机。

这比留下未知更糟。

---

## 八、Gap 和 Unknown 必须区别

这两个概念以后一定要严格区分。

### Gap

系统发现：

```text
14:00 上一条结束
16:00 下一条开始
```

14:00–16:00 没有任何记录。

这是：

> **尚未处理的时间。**

它不是数据库对象。

它只是系统根据时间轴派生出的：

```text
UnresolvedSpan
```

### Unknown

用户看到了 14:00–16:00，然后说：

> 想不起来了。

这时才真正保存：

```text
TimeBlock
14:00–16:00
knowledgeState = unknown
```

于是这段时间：

> 已经对账，只是内容未知。

这是非常重要的产品区别。

---

## 九、因此一天的账本实际上会出现三种区域

```text
┌─────────────────────┐
│ 已知：写毕业设计       │
├─────────────────────┤
│ 已知：午饭             │
├─────────────────────┤
│ 未知：想不起来          │
├─────────────────────┤
│ 尚未记录               │ ← Gap，不是数据
├─────────────────────┤
│ 已知：看电影           │
└─────────────────────┘
```

这已经足够构成真正的“账本”。

而不需要设计一个所谓：

> 83 分的今日时间完整度。

---

## 十、Category 不进入核心模型

赞同不应该现在设计复杂分类。

所以：

```text
categoryId?
```

可以留作扩展接口。

但产品内核不依赖它。

早期甚至完全可以不提供分类管理。

用户输入：

> 吃饭
> 去学校
> 买东西
> 刷视频
> 打游戏

已经足够还原时间。

以后如果发现真的需要分类，再加入非常粗的：

```text
生活
出行
娱乐
其他
```

都来得及。

**不要让分类体系成为记录时间的前置成本。**

---

## 十一、Goal 和 Category 完全不是一回事

这一点需要保留。

Category 回答：

> 这是什么性质的活动？

Goal 回答：

> 这段时间和哪个阶段性目标有关？

例如：

```text
活动：阅读论文
Goal：毕业设计
```

或者：

```text
活动：背单词
Goal：英语四级
```

所以 Goal 建议继续独立：

```text
Goal
- id
- name
- status
- createdAt
- updatedAt
- archivedAt?
```

状态继续只需要：

```text
active
archived
```

不加：

> 截止日期、百分比、里程碑、任务树、优先级。

因为 Goal 在这个产品里只是：

> **时间的归属维度。**

不是项目管理器。

---

## 十二、第三层：RhythmAnnotation

这是当前模型最大的改变。

现在：

```text
TimeEntry.kind
=
progress | stuck | recovery
```

新模型应该改成：

```text
TimeBlock
    +
optional RhythmAnnotation
```

例如：

```text
TimeBlock
14:10–15:25
修改毕业设计数据库章节
goalId = graduation
```

再附加：

```text
RhythmAnnotation
state = progress
```

于是：

> “做了什么”是事实。

> “这段时间属于真正推进”是解释。

两者不再混为一谈。

---

## 十三、RhythmState 的正式语义

建议：

```text
RhythmState
- progress
- stuck
- recovery
```

没有 `neutral`。

因为没有 annotation 本身就是：

> 不需要进行节奏解释。

这样更干净。

### progress

定义为：

> **这一时间段主要产生了用户能够确认的目标推进。**

关键不是：

> 看起来像工作。

而是：

> 用户认为目标确实向前移动了。

所以：

```text
查论文
```

可以是 progress。

也可以不是。

### stuck

定义为：

> **用户尝试推进某件目标相关事情，但主要时间消耗在阻力、停滞、反复尝试或无法进入有效推进上。**

例如：

```text
14:00–15:10
一直在想数据库怎么设计
goal = 毕业设计
rhythm = stuck
```

这正是所谓：

> 剔除“我好像做了一整天”的错觉。

### recovery

定义为：

> **这一段行为的主要作用是让用户从无法继续的状态重新获得继续行动的可能。**

例如：

```text
15:10–15:40
出去散步
rhythm = recovery
```

但普通午饭：

```text
12:00–12:30
吃午饭
```

默认没有 rhythm annotation。

因为：

> 正常生活 ≠ 自动恢复。

这是新模型相较当前模型的巨大进步。

---

## 十四、RhythmAnnotation 的完整结构

建议：

```text
RhythmAnnotation
- id
- timeBlockId

- state

- stuckReasonCode?
- stuckReasonText?

- recoveryMethod?
- recoveryQuality?

- continuationHint?

- createdAt
- updatedAt
```

数据库中应该满足：

> 一个 `TimeBlock` 最多一个有效 `RhythmAnnotation`。

---

## 十五、卡住原因不再强制填写

当前产品在这里过重。

新的规则应该是：

```text
标记为“卡住”
```

本身就已经是一条合法记录。

然后用户可以选择继续补：

```text
任务太大
不知道下一步
困
脑雾
焦虑
被打断
说不清
……
```

所以：

```text
stuckReasonCode?
stuckReasonText?
```

应该全部允许为空。

这样用户处于最困难的时候，最低操作成本只是：

> “这段我卡住了。”

已经足够。

---

## 十六、Recovery 也是同样原则

标记：

> 恢复

就可以成立。

然后可选：

```text
recoveryMethod
recoveryQuality
```

因此不应该继续要求：

> 必须选择恢复方式 + 必须评价质量

才能保存。

长期分析需要这些字段，可以鼓励补。

但不能拿它们挡住记录。

---

## 十七、睡眠不再是 RecoveryMethod

这一点建议彻底改变。

新的：

```text
RecoveryMethod
```

可以是：

```text
walk
meal
shower
empty
entertainment
switchTask
breakDownTask
askForHelp
other
```

但：

> nightly sleep

进入 `SleepSession`。

如果以后要处理：

> 午睡是一次恢复行为

可以通过睡眠记录的上下文进一步解决。

现在没必要把两个模型重新绑回去。

---

## 十八、Goal 和 RhythmState 结合以后，会产生真正有价值的数据

假设一天出现：

```text
Goal：毕业设计
```

账本中有：

| 时间 | 内容 | Rhythm |
| --- | --- | --- |
| 09:30–10:40 | 修改论文 | progress |
| 10:40–11:20 | 查数据库资料 | stuck |
| 13:20–14:30 | 改 Flutter 页面 | progress |
| 15:00–15:50 | 搜资料、来回切页面 | 无 |
| 19:00–20:10 | 修复数据层 | progress |

于是你可以非常诚实地说：

> 与毕业设计直接相关的时间：约 4h30m

同时：

> 明确推进时间：约 3h30m

> 明确卡住时间：约 40m

还有：

> 约 50m 与毕业设计相关，但没有被标记为推进或卡住。

这比“效率 77%”高级得多。

因为系统没有评价用户。

只是把事实拆开。

---

## 十九、“无用功”不要成为数据库枚举

这非常重要。

不要设计：

```text
RhythmState.useless
```

也不要：

```text
productive = true / false
```

“无用功”是复盘判断。

例如：

```text
15:00–15:50 搜资料
goal = 毕业设计
rhythm = null
```

晚上用户可能意识到：

> 这 50 分钟实际上没有明确问题，只是在搜东西。

于是她在复盘里得出：

> “查资料前应该先写出要解决的问题。”

这才是价值。

数据库记录事实。

**不要让数据库替用户进行道德判断。**

---

## 二十、ContinuationHint：取代旧的 TimeEntry.nextStep

现有 `NextStep` 把几个不同的东西混在一起。

建议把时间块里的“下一步”重新定义成：

> **Continuation Hint / 接续点**

例如：

```text
continuationHint =
"下次先把 User 表的字段画出来"
```

它回答：

> 我之后重新回到这件事时，应该从哪里接上？

它可以附在：

> progress

或者：

> stuck

记录上。

但它不是：

> 明天第一步。

这两个概念以后必须彻底分开。

---

## 二十一、DailyReview：一天的解释层

`DailyReview` 不应该再保存：

```text
progressMinutes
stuckMinutes
recoveryMinutes
```

这些都是可以从时间事实重新计算的派生数据。

建议：

```text
DailyReview
- id
- date

- summary?
- reflection?

- tomorrowFirstStep

- createdAt
- updatedAt
```

如果之后确实需要结构化，也可以是：

```text
- keyProgress?
- mainStuckPoint?
- recoveryObservation?
```

但它们不是第一版必须的。

---

## 二十二、TomorrowFirstStep 是独立语义

建议模型：

```text
TomorrowFirstStep
- text
- intendedDate
- goalId?
```

它只回答一个问题：

> **明天开始时，我首先要做什么？**

例如：

```text
打开数据库设计图，
先补 User 和 TimeBlock 两张表。
```

Goal 可选：

```text
goalId = graduation
```

但不用再次发展成：

> 每个 Goal 都必须有自己的明日 Next Step。

建议新模型取消当前的：

```text
goalNextSteps: Map<goalId, NextStep>
```

至少先退出核心模型。

否则 Daily Review 很容易重新变成：

> 多项目明日计划器。

---

## 二十三、一天不是数据库实体，而是“投影视图”

不建议创建一个充满字段的：

```text
Day
```

对象。

自然日更适合作为一个查询窗口：

```text
2026-09-22 00:00
→
2026-09-23 00:00
```

系统查询：

```text
TimeBlock 与该区间相交的部分
+
SleepSession 与该区间相交的部分
```

然后生成：

```text
DayLedgerView
```

这是派生对象，不持久化。

---

## 二十四、DayLedgerView

概念上可以是：

```text
DayLedgerView
- date

- segments
- unresolvedSpans

- sleepSummary

- goalSummaries

- accountedDuration
- unknownDuration
- unresolvedDuration
```

其中：

```text
segments
```

来自：

> TimeBlock + SleepSession 切片

而：

```text
unresolvedSpans
```

来自时间轴空隙计算。

---

## 二十五、完整度不要做成一个分数

这是一个非常容易重新走错的地方。

技术上你当然可以算：

```text
accountedMinutes / 1440
```

但不建议产品把它展示成：

> 今日完成度 83%

因为它会迅速产生打卡压力。

更适合的表达是：

```text
今天还有约 1h20m 没有记录
```

或者：

```text
有 45 分钟已经标记为“想不起来”
```

这是：

> 数据状态。

而不是：

> 用户成绩。

---

## 二十六、目标时间精度应该在 UX 上优先，而不是数据库上惩罚

你说：

> 对于目标推进的时间段要有准确的认识。

完全同意。

但建议通过交互做到。

例如用户保存：

```text
毕业设计
rhythm = progress
```

系统可以让时间区间显得更突出：

> 14:10–15:25
> 确认这段时间大致正确吗？

而普通：

> 晚上娱乐

只需要：

> 大约 20:00–22:00

即可。

所以：

> **高价值时间要求用户确认，低价值时间只要求用户解释。**

这可以成为非常强的一条产品原则。

---

## 二十七、真正核心的记录交互

以后用户不应该首先面对：

```text
日期
开始时间
结束时间
```

正常入口应该是：

```text
刚才这段时间在做什么？
```

系统已经根据账本猜：

```text
14:55–16:10
```

用户看到：

> 14:55–16:10 · 修改

然后输入：

```text
继续改毕业设计
```

如果相关：

```text
Goal
毕业设计

节奏
推进 / 卡住 / 恢复 / 不标记
```

结束。

只有用户认为系统猜错了，才打开时间编辑。

也就是说：

> **时间是系统提出的假设，活动才是用户主要输入。**

---

## 二十八、补账应该成为核心产品能力

例如时间线：

```text
13:20–14:30  毕业设计
              推进

14:30–16:05  尚未记录
              [补一笔]

16:05–16:40  吃饭
```

点击：

> 补一笔

系统直接创建草稿：

```text
startedAt = 14:30
endedAt   = 16:05
```

然后只问：

> 这段主要在做什么？

如果用户说：

> 真想不起来。

点击：

> 标记为未知

就结束。

这是我认为“完整时间账本”最重要的一个闭环。

---

## 二十九、睡眠应该拥有最高输入优先级

建议每天第一次打开应用时优先确认：

> 昨晚几点睡？
> 今天几点醒？

而不是要求先设置 Goal。

如果之前已经记过，就什么都不打扰。

这样用户一整天最重要的身体背景数据已经先确定下来。

然后再进入当天账本。

---

## 三十、统计模型也要重新定义

所有统计都应该从事实派生。

核心输出可以分三组。

### 身体背景

```text
昨晚睡眠
约 6h10m

入睡
约 01:40

醒来
07:50
```

以后才考虑趋势。

---

### 时间账本

```text
已交代时间
21h20m

尚未记录
2h40m

其中未知
50m
```

注意：

> 未知已经被交代。

所以它不能和 gap 混为一谈。

---

### 目标节奏

以毕业设计为例：

```text
目标相关时间
4h50m

明确推进
约 3h25m

明确卡住
55m
```

恢复单独作为当天背景：

```text
恢复行为
1h10m
```

不要急着输出：

> 推进效率 70.7%

用户自己已经能看到差异。

---

## 三十一、睡眠与推进只能做描述性关联

例如可以说：

> 最近 5 个睡眠少于约 6 小时 30 分的日子里，有 4 天记录了“困 / 精力不足”类型的卡住。

可以说：

> 这两个现象经常同时出现。

不能说：

> “睡眠不足导致你的效率下降 30%。”

这个产品没有实验设计支持这种因果判断。

这条以后 AI 复盘也必须遵守。

---

## 三十二、关于重叠，建议暂时保持简单

既然产品主要记录：

> 一段时间的主要事实

而多任务并不是核心问题，那么账本主时间轴暂时保持：

> 一段时间最多一条主要 TimeBlock / SleepSession

是合理的。

用户边吃饭边看视频，不需要拆成两个并行区间。

写：

```text
12:00–12:30
午饭
```

已经足够。

如果“边吃饭边刷视频”对复盘真的重要，可以写 note。

这个模型暂时不需要并行时间轴。

---

## 三十三、数据库建议

如果真正重构，核心表只需要这几张：

| 表 | 职责 |
| --- | --- |
| `goals` | 阶段目标 |
| `time_blocks` | 普通时间账本事实 |
| `rhythm_annotations` | 推进 / 卡住 / 恢复解释 |
| `sleep_sessions` | 睡眠事实 |
| `daily_reviews` | 每日解释与明日第一步 |

Category 系统可以以后再加。

### `time_blocks`

```text
id PK

started_at
ended_at

start_precision
end_precision

knowledge_state
title nullable

goal_id nullable
category_id nullable

note nullable

created_at
updated_at
```

约束：

```text
started_at < ended_at

knowledge_state = known
→ title must not be empty

knowledge_state = unknown
→ title may be null
```

### `rhythm_annotations`

```text
id PK
time_block_id UNIQUE FK

state

stuck_reason_code nullable
stuck_reason_text nullable

recovery_method nullable
recovery_quality nullable

continuation_hint nullable

created_at
updated_at
```

这里最重要的是：

> `time_block_id UNIQUE`

保证同一个时间块只有一套节奏解释。

### `sleep_sessions`

```text
id PK

started_at
ended_at

start_precision
end_precision

sleep_type

note nullable

created_at
updated_at
```

### `goals`

现有结构基本可以保留：

```text
id
name
status
created_at
updated_at
archived_at
```

### `daily_reviews`

建议：

```text
id PK
review_date UNIQUE

summary nullable
reflection nullable

tomorrow_first_step_text
tomorrow_first_step_goal_id nullable

created_at
updated_at
```

不存：

```text
progressMinutes
stuckMinutes
recoveryMinutes
```

这些以后全部实时派生。

---

## 三十四、旧模型到新模型的迁移

好消息是，现在的数据其实很好迁。

| 当前 | 新模型 |
| --- | --- |
| `TimeEntry` | `TimeBlock` |
| `kind = progress` | `RhythmAnnotation.progress` |
| `kind = stuck` | `RhythmAnnotation.stuck` |
| `kind = recovery` | `RhythmAnnotation.recovery` |
| `goalId` | `TimeBlock.goalId` |
| `stuckReason*` | `RhythmAnnotation.stuckReason*` |
| `recoveryMethod*` | `RhythmAnnotation.recovery*` |
| `TimeEntry.nextStep` | `RhythmAnnotation.continuationHint` |
| `DailyReview.tomorrowFirstStep` | `DailyReview.tomorrowFirstStep*` |
| `DailyReview.progressMinutes` 等 | 删除，重新派生 |
| `goalNextSteps` | 退出核心模型 |

现有数据不会被浪费。

只是：

> **从一个对象拆成了“事实 + 解释”。**

---

## 三十五、旧 recovery=sleep 不建议自动变成 SleepSession

这里要谨慎。

历史上：

```text
RecoveryMethod.sleep
```

表达的是：

> 用户把睡觉当作一次恢复行为。

它不一定意味着：

> 正式夜间睡眠记录。

所以数据迁移时最好仍然：

```text
TimeBlock
+
RhythmAnnotation.recovery
```

保留原语义。

新的 `SleepSession` 从新版本开始记录。

否则会偷偷重写历史事实。

---

## 三十六、最终领域关系可以浓缩成这张图

```text
                    ┌────────────┐
                    │    Goal    │
                    └─────┬──────┘
                          │ optional
                          │
                    ┌─────▼──────┐
                    │ TimeBlock  │
                    │ 时间事实    │
                    └─────┬──────┘
                          │ 0..1
                          │
                ┌─────────▼─────────┐
                │ RhythmAnnotation  │
                │ 推进 / 卡住 / 恢复 │
                └───────────────────┘


┌─────────────────┐
│  SleepSession   │
│    睡眠事实      │
└─────────────────┘


TimeBlock + SleepSession
          │
          ▼
┌───────────────────────┐
│     DayLedgerView     │
│ 自然日账本 / Gap /统计 │
└──────────┬────────────┘
           │
           ▼
┌───────────────────────┐
│      DailyReview      │
│ 理解今天 → 明天第一步  │
└───────────────────────┘
```

---

## 三十七、这套模型最终回答的是五个问题

| 用户问题 | 数据来源 |
| --- | --- |
| 我昨天大概是怎么过的？ | `TimeBlock + SleepSession` |
| 我昨晚睡了多久、什么时候睡的？ | `SleepSession` |
| 我实际上花了多少时间在这个目标附近？ | `TimeBlock.goalId` |
| 其中多少是真正推进、多少是在卡住？ | `RhythmAnnotation` |
| 我下一次从哪里开始？ | `ContinuationHint + DailyReview.tomorrowFirstStep` |

我认为这五个问题已经足以成为整个产品的骨架。

---

## 三十八、目前明确不应该进入核心模型的东西

暂时不建模复杂任务树、多任务并行分摊、详细活动分类体系、生产力评分、“有效率”、失败天数、习惯连续天数、所有 Goal 的每日计划、因果式睡眠分析，也不把“无用功”做成基础枚举。

它们以后不是绝对不能有，而是**目前都没有资格影响底层数据结构**。

---

## 最终定义

如果以后仓库只能留下一个新的 product / domain source of truth，我会把最上面写成：

> **Time Pet Ledger 的基础事实不是“推进、卡住、恢复”，而是时间。**
>
> 用户通过回顾式补记，以不同精度还原一天。睡眠与目标相关时间具有更高记录优先级，普通时间允许模糊，无法回忆的时间允许明确标记为未知。
>
> `TimeBlock` 描述“发生了什么”；`RhythmAnnotation` 描述其中部分时间对于目标推进意味着什么；`SleepSession` 独立描述睡眠；`DailyReview` 将这些事实转化为下一次行动。
>
> 系统追求的是**对时间的真实理解**，而不是对每一分钟的精确监控。

我认为这已经是一套可以直接取代当前 `TimeEntryKind` 体系的领域模型。下一步真正进入实现前，最值得继续细化的是 **`TimeBlock / SleepSession / RhythmAnnotation` 的状态机和校验规则**，因为那会直接决定数据库 migration、记录表单和时间线怎样重构。
