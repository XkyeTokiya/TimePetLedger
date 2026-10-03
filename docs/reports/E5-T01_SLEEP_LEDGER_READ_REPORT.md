# E5-T01 — 接通睡眠日期上下文与完整摘要读取

**Task / Status：E5-T01 / COMPLETE。** 日期：2026-09-29。

## 依据与前置证据

已核对 AGENTS、完整 Task 和 Source documents 索引、SOT、OQ、MVP、PLAN，以及 DATA / 查询与读取一致性、DERIVED / 公共输入与 sleepSummary、APP / 调用流程及相关 MODEL / SleepSession、RULES / SL。Q-008、Q-009、Q-010、Q-014、Q-021 均为 DECIDED，未发现阻塞本任务的冲突。

前置证据及对应实现已核对：

- [E2-T05](E2-T05_LEDGER_READ_REPORT.md)：COMPLETE；完整行映射、同事务窗口读取、真实库及 Android / Web 验证记录。对应 readWindow、映射和真实库测试存在。
- [E3-T05](E3-T05_SLEEP_SUMMARY_REPORT.md)：COMPLETE；完整睡眠摘要、醒来日及 hasRecordedMainSleepToday，11 项新增测试。
- [E3-T06](E3-T06_DAY_LEDGER_VIEW_REPORT.md)：COMPLETE；DayLedgerView 区分窗口睡眠与摘要候选，8 项组合测试。
- [E3-T07](E3-T07_SUMMARY_FORMATTING_REPORT.md)：COMPLETE；hasRecords、缺失文案及近似展示映射，7 项新增测试。

遵循成本规则，委派 code_mapper 做有界只读定位；主 agent 检查证据、实现、集成及验证。上述历史平台结果仅为前置证据，本轮没有重新执行 Android / Web 集成。

## Changes

| 文件 | 本轮修改 |
| --- | --- |
| [ledger_repository.dart](../../lib/features/ledger/domain/ledger_repository.dart) | 增加 readSleepContext 及不可变 SleepLedgerSnapshot；窗口事实与完整摘要候选分别承载 |
| [drift_ledger_repository.dart](../../lib/features/ledger/data/drift_ledger_repository.dart) | 复用窗口查询，在同一事务内增加 ended_at 半开日期查询和完整映射 |
| [recording_ledger_loader.dart](../../lib/features/ledger/application/recording_ledger_loader.dart) | 已有日期上下文保留完整日开始及次日开始，供睡眠读取复用 |
| [sleep_ledger_loader.dart](../../lib/features/ledger/application/sleep_ledger_loader.dart) | 新增独立睡眠读取协调，输出切片、覆盖、完整睡眠摘要及今天的已记录判定 |
| [sleep_ledger.dart](../../lib/app/bootstrap/sleep_ledger.dart) | 注入 app 管理的数据库和现有设备日期适配 |
| [sleep_ledger_loader_test.dart](../../test/features/ledger/application/sleep_ledger_loader_test.dart) | 8 项真实 SQLite 与 application 验收测试 |
| [sleep_ledger_read_test.dart](../../test/features/ledger/data/sleep_ledger_read_test.dart) | 真实文件库、两个独立连接间的读取一致性测试 |
| [TASKS.md](../../TASKS.md) 与本报告 | 更新 E5-T01 状态、证据及当前状态说明 |

摘要查询为 `ended_at >= dayStartedAt AND ended_at < nextDayStartedAt`，不受 W 截止 now 的影响；午夜醒来和未来结束均保留。主睡眠与小睡分别交给既有 projectSleepSummary，全量列出并合计完整时长，不取最近 / 最长一条。窗口事实继续保持完整边界，切片、覆盖和精度传播复用已有算法，不混合两个集合重复计时。

每次 load 显式接收 now，并通过注入的日期 resolver 在 I/O 前按当前设备时区产生完整当地日边界及日期关系；历史 / 今天 / 未来 W 沿用既有合同。复用的是日期与读取合同，不依赖普通编辑器、表单、草稿或普通记录 loader 的执行。

recordedMainSleepToday 仅对今天调用既有判定；历史 / 未来结果为 null 表示不适用，不表示应该提醒。只有 nap 或未来结束主睡眠不满足判定。这是读取结果的工程表达，不增加提醒政策，后续首次打开调度仍由 E5-T06 实现。

无匹配数据正常返回 hasRecords=false；非法候选或存储失败抛出明确错误，不返回空摘要兜底。即使 W 为空也执行摘要读取并暴露失败。本入口提供睡眠所需上下文，不额外加载 Goal 元数据或构造完整统计页面。

## Validation

仓库根目录使用现有 Flutter / Dart 和已安装依赖；没有新增依赖、schema 或平台配置。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/domain/ledger_repository.dart lib/features/ledger/data/drift_ledger_repository.dart lib/features/ledger/application/recording_ledger_loader.dart lib/features/ledger/application/sleep_ledger_loader.dart lib/app/bootstrap/sleep_ledger.dart test/features/ledger/application/sleep_ledger_loader_test.dart test/features/ledger/data/sleep_ledger_read_test.dart` | 退出 0，7 文件，4 文件格式化 |
| 相同文件清单运行 `dart format --output=none --set-exit-if-changed` | 退出 0，7 文件，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=America/New_York flutter test --no-pub test/features/ledger/application/sleep_ledger_loader_test.dart test/features/ledger/data/sleep_ledger_read_test.dart test/app/time/device_recording_date_test.dart` | 退出 0，13 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time` | 退出 0，293 项通过，1 项纽约 DST 定向测试跳过（已在上一命令通过） |
| `git diff --check` | 退出 0 |

真实库验收覆盖：

- 午夜醒来不与 W 相交仍进入摘要；次日午夜醒来不进入当日摘要，但可贡献当日切片。
- 多段与白天主睡眠全部保留，小睡独立；不计段间清醒；未来结束保留原始结束时间，日内贡献仅截至 now。
- 跨日约 8h 完整时长与精确 7h 切片差异，分别传播精度；窗口和摘要共同记录的身份、边界、独立精度与 updatedAt 一致。
- 今日零点 / 未来 W 为空仍有完整摘要；历史使用完整当地日；空库的缺口长度按窗口变化；无记录使用“尚未记录主睡眠”。
- 只有 nap / 尚未结束主睡眠不满足免打扰；到达 endedAt 后重新读取满足条件，旧结果保持不变。
- 真实纽约日期适配 + SQLite 覆盖春季 23h / 秋季 25h 日，按实际边界取得完整时长与日内贡献。
- 四次 SELECT 使用同一真实 TransactionExecutor，一次提交；摘要独有非法行导致整体失败并回滚；关闭存储时含空 W 在内均失败；非法参数拒绝。
- 真实临时文件上两个独立 NativeDatabase 连接，在窗口第一次 SELECT 后暂停读取，另一连接尝试同时更改普通事实、睡眠及解释被 SQLite busy 拒绝；释放并提交后再次写入 / 读取成功，窗口和摘要都得到相同更新版本。拦截器只暂停或观察真实查询，不伪造结果。

双连接测试输出 Drift 多数据库实例的 debug 提示；测试有意使用两个独立 executor 验证锁与一致性，未共享 executor，测试通过。

## Self-review

检查本轮新增文件及增量修改、日期端点、事务范围、完整映射物化、失败传播、依赖方向与测试夹具；没有改写投影算法、普通编辑器或已有受控写入逻辑。格式化仅针对本轮 7 个 Dart 文件。没有睡眠表单、提醒调度、统计页面、依赖变更或后续任务实现。

工作开始时工作区已有 Epic 2–4 实现、测试及报告，以及 TASKS / PLAN 的未提交修改。本轮先记录文件 SHA-256；代码验证后对照，仅 3 个已有文件变化（repository 接口、Drift repository、日期上下文），其余已有 lib / test / docs / integration_test / TASKS / pubspec / lockfile 内容保持原样。之后仅更新 TASKS 中 E5-T01 状态和顶部状态说明，新增本报告。既有未跟踪文件和已有改动均保留；原写入 API 没有被回退。

## Blockers / Open Questions

无。适用检查全部通过；本轮真实库验证在 Native SQLite 上执行，未声称新增 Android / Web 端到端验收，睡眠平台闭环留 E5-T08。

## Next executable task

E5-T02 — 实现睡眠本机草稿存储。其前置 E2-T02 / E1-T04 已有完成证据；需另行指定执行。本次完成 E5-T01 后停止，不执行后续任务，不将 Epic 5 标为完成。
