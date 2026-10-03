# E4-T03 — 实现普通记录本机草稿存储

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

已核对 AGENTS、TASKS / E4-T03、Source of Truth §27–28、MODEL / UI Models、DATA / 本机输入草稿、PLAN / 输入草稿共同交付合同，以及 Q-012、Q-022（均 DECIDED）。复用已批准的 Drift 2.35.0 / drift_flutter 0.3.1，未引入依赖或扩大平台范围。

前置 [E2-T02](E2-T02_PERSISTENCE_CONNECTION_REPORT.md) 和 [E4-T02](E4-T02_TIME_SUGGESTION_REPORT.md) 均有 COMPLETE 报告；检查了实际数据库连接、正式五表、平台适配和时间输入实现。按 AGENTS 委派 code_mapper 有界只读定位；主 agent 核对来源、作实现决定、编辑和最终验证。无合同冲突或缺失产品决定。

## Changes

| 文件 | 交付 |
| --- | --- |
| [recording_draft_store.dart](../../lib/features/ledger/domain/recording_draft_store.dart) | 最小 read / save / clear 存取合同、专用存取 DTO、入口上下文及显式异常 |
| [drift_recording_draft_store.dart](../../lib/features/ledger/data/drift_recording_draft_store.dart) | 独立草稿 SQLite 库、逐列映射、原子保存 / 清除与错误传播 |
| [recording_drafts.dart](../../lib/app/bootstrap/recording_drafts.dart) | 复用平台连接函数打开固定独立草稿库，调用方负责关闭 |
| [recording_draft_store_test.dart](../../test/features/ledger/data/recording_draft_store_test.dart) | 6 项真实文件 SQLite 测试，含关闭重开、正式事实隔离和失败路径 |
| [TASKS.md](../../TASKS.md#e4-t03--实现普通记录本机草稿存储)、本报告 | 本任务状态与验收证据 |

### 存储选择与输入边界

现有本机能力仅有已批准 SQLite/Drift，无其他键值存储。采用单独名称 `time_pet_ledger_recording_drafts`，复用 connectDatabase 的 Android 文件库及 Web 持久化实现选择；Web 继续拒绝 inMemory / unsafeIndexedDb 降级。独立库仅有 recording_drafts 表，schemaVersion=1；正式 AppDatabase 的五表、schemaVersion=2 和查询均未修改。

草稿表使用专用列，不是通用 payload / 草稿框架。不需要代码生成或安装包。该新库与正式库不共享 executor；openRecordingDraftStore 返回真实打开后的存储，后续 app 生命周期接入方负责 close。当前未自动打开草稿库或加入表单，触发自动保存、恢复优先级和清除时机的交互协调属于后续任务。

存取 DTO 不新增正式领域实体或生命周期状态，也不承载 Widget/controller 状态。保存当前普通输入所需的原始 title、可空起止、两端独立精度、可空 known/unknown 选择，以及入口日期、种类、原 Gap 边界或编辑 TimeBlock id。原样保留空白、多行、空标题、只填一端、暂时反向 / 等长区间；不在草稿写入时提前应用正式记录校验或修剪输入。

入口键为工程上的隔离方式：普通新建按浏览日期；明确 Gap 按日期和原入口区间；编辑按完整 TimeBlock id。输入区间修改不改变入口键，同一编辑记录从不同日期进入仍可读回其草稿和保存的入口日期。多个不同日期、Gap 或编辑对象不会串用；同一上下文保存替换该上下文的草稿，定向 clear 不清除其他草稿。

精度由调用方显式提供，存储层不改为 exact；新建输入初始 approximate 继续复用 E4-T02。编辑草稿仅保存待改输入和关联身份，未展示的 Goal、annotation、备注等正式字段不能由草稿缺省值覆盖；实际更正时保留当前正式字段、处理已删除对象和重校验由 E4-T06 实现。note 便利入口及对应草稿字段仍按 E4-T09 交付。

### 失败语义

- read 返回 null 只表示不存在；非法存储数据抛 RecordingDraftDataException，不自动删行、重置或伪装无草稿。
- 打开、读取、保存、清除和关闭的存储错误抛带 operation 的 RecordingDraftStorageException；toString 不展示原始 SQL / 文件路径。
- 保存采用单条 UPSERT，清除采用单条 DELETE；语句失败不会留下部分更新或清除。clear 缺失上下文为幂等成功。
- 不支持的数据库版本拒绝打开，不静默清空或降级。

## Validation

以下命令由本 agent 在仓库根目录执行，无新依赖解析。

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/domain/recording_draft_store.dart lib/features/ledger/data/drift_recording_draft_store.dart lib/app/bootstrap/recording_drafts.dart` | 退出 0；3 个生产文件格式化 |
| `dart format test/features/ledger/data/recording_draft_store_test.dart` | 退出 0；测试格式化；lint 修正后再运行退出 0 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/domain/recording_draft_store.dart lib/features/ledger/data/drift_recording_draft_store.dart lib/app/bootstrap/recording_drafts.dart test/features/ledger/data/recording_draft_store_test.dart` | 退出 0；4 文件、0 changed |
| `flutter analyze --no-pub` | 最终退出 0；No issues found |
| `flutter test --no-pub test/features/ledger/data/recording_draft_store_test.dart` | 首轮及最终均退出 0；6 项通过 |
| `flutter test --no-pub test/features/ledger/application test/features/ledger/data test/core/persistence test/app/bootstrap` | 退出 0；53 项全部通过 |
| `git diff --check` | 退出 0 |
| 执行前既有跟踪 / 未跟踪文件 SHA-256 对照 | 实现与验证后 0 既有文件改动；文档收尾仅 TASKS 追加 E4-T03 状态 |

测试添加后的一次分析发现测试辅助函数公开签名引用私有类型，改为私有函数；最终分析与六项测试重跑通过。53 项回归在该纯命名修正前通过，未改任何生产行为。本机临时日志为 `/tmp/e4_t03_tests_final.log` 与 `/tmp/e4_t03_regression.log`。

验收证据：

1. 真正 SQLite 文件写入后关闭全部草稿连接，再以新 executor 打开同一文件，逐字段核对六种上下文和不完整输入、混合精度、原入口与编辑关联；不是内存库。
2. 重开后定向清除并重复清除、替换另一上下文，再关闭重开，确认被清除项缺失、更新保留、其余项不变。
3. 另一个真实正式数据库通过批准 repository 填满五类对象；草稿读写清除前后逐列快照相同。草稿不进入 readWindow；与草稿重叠但不与正式事实重叠的新正式记录能成功写入，而与正式事实重叠仍按既有原子接口拒绝。
4. SQLite AFTER UPDATE / AFTER DELETE 测试触发器主动 RAISE(ABORT)，验证保存和清除明确失败，当前和重新打开后均保留上次已提交草稿。触发器仅存在隔离测试库，移除后可正常清除并持久生效。
5. 关闭后的连接 read / save / clear 均明确报对应失败；损坏数据读取失败且未被修改；不可打开路径及不支持的 schema 版本拒绝打开。
6. 检查草稿库只有专用草稿表、正式库没有该表；回归既有一致读取、原子写入、文件持久化、E4-T01 / T02 和 app 连接生命周期。

## Self-review

完整检查四个新增 Dart 文件、错误分支、SQL 参数绑定、键隔离、原始输入映射、连接所有权和测试。保留开始时所有既有改动；没有修改前置代码、正式 schema、产品合同、pubspec / lockfile、生成文件或平台配置。只在 TASKS 追加本任务状态，无睡眠 / 复盘草稿、云同步、通用框架、正式保存协调或额外 UI。

## Blockers / Open Questions

无。当前证据为本机真实 SQLite 文件关闭 / 重开；未在本次任务运行 Android 关闭应用或 Web 实际刷新。平台应用级恢复证据明确留 E4-T08，不以本机文件测试冒充。自动保存触发、页面恢复和反馈留 E4-T04，成功提交后的清草稿协调留 E4-T05。

## Next executable task

**E4-T04 — 实现活动优先表单与草稿生命周期**。E4-T02、E4-T03 已完成。本次仅执行 E4-T03，未开始下一任务。
