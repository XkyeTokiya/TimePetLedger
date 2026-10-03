# E4-T01 — 接通普通记录的日期上下文与投影读取

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

已阅读 AGENTS、TASKS / E4-T01、Source of Truth、APP / 纯派生逻辑与调用流程、DATA / 读取一致性、DERIVED / 公共输入，以及相关 OPEN_QUESTIONS、MVP_SCOPE、IMPLEMENTATION_PLAN。Q-008、Q-009、Q-017 均为 DECIDED；实现采用当前设备时区、历史完整日 / 今天截至显式 now / 未来空窗口、UTC 毫秒和半开区间合同。没有发现需要新增产品决定的冲突。

前置完成证据已核实，不能仅从 TASKS 是否有状态行判断：

- [E2-T05](E2-T05_LEDGER_READ_REPORT.md)：COMPLETE，真实读取、事务与 Android / Web 验证证据齐全；检查实际 readWindow 查询和事务内映射。
- [E3-T03](E3-T03_LEDGER_COVERAGE_REPORT.md)：COMPLETE，包含用户本机 35 项 projection 测试通过证据；检查实际全部事实覆盖与 Gap 实现。
- [E3-T06](E3-T06_DAY_LEDGER_VIEW_REPORT.md)：COMPLETE，206 项相关测试通过；检查组合入口所要求的独立完整睡眠候选边界。

按 AGENTS 委派 code_mapper 有界只读定位，主 agent 核查源文件、完成实现及最终验证。本次未修改上述前置状态或实现。

## Changes

| 文件 | 交付 |
| --- | --- |
| [recording_ledger_loader.dart](../../lib/features/ledger/application/recording_ledger_loader.dart) | 日期上下文、普通记录读取结果与加载协调器 |
| [device_recording_date.dart](../../lib/app/time/device_recording_date.dart) | 当前设备时区的日期关系、当地零点与次日零点适配 |
| [recording_ledger.dart](../../lib/app/bootstrap/recording_ledger.dart) | 用 app 所有的数据库连接组装真实 repository 与日期适配，不新增连接 |
| [device_recording_date_test.dart](../../test/app/time/device_recording_date_test.dart) | 4 项日期适配测试 |
| [recording_ledger_loader_test.dart](../../test/features/ledger/application/recording_ledger_loader_test.dart) | 5 项真实 SQLite 读取到投影集成测试 |
| [TASKS.md](../../TASKS.md#e4-t01--接通普通记录的日期上下文与投影读取)、本报告 | 本任务状态与实际验收证据 |

加载入口要求调用方显式传入 date 与 now，在异步查询前解析一次日期上下文，调用已有 ReconciliationWindow.select，再调用一次 LedgerRepository.readWindow。完整快照直接交给 E3 的 projectLedgerSegments 和 projectLedgerCoverage，不复制切片、Gap、覆盖或近似算法。结果保留正式完整事实、切片与覆盖，供时间建议和保存后重新加载使用。

设备适配每次使用本地 DateTime 构造器分别解析当天与日历次日；没有缓存固定时区偏移、取 UTC 日期当今天或给起点加 24 小时。纯 domain 仍不读取全局时钟或设备时区。

只组装普通记录所需的覆盖结果，不调用要求完整睡眠候选和 Goal 元数据的 DayLedgerView 总入口，不传空候选伪造“无睡眠”摘要。app 工厂可供后续普通表单入口注入；本任务没有创建表单或修改 Hello World 页面。

## readWindow 可复用边界

- 正时长半开窗口使用相交查询，包含窗口外开始、跨日及跨 now 的完整事实；TimeBlock（包括 Unknown、无 Goal、有归档 Goal）、SleepSession（mainSleep / nap）和相关 annotation 在同一事务中完成读取及映射。
- annotation 不另占覆盖；无 Goal、无 annotation 的事实不能被过滤。投影不读草稿，不改原始事实或写入 Gap。
- LedgerDataException / LedgerStorageException 原样向调用方传播，加载失败不会转换为空账本。成功的非空窗口无事实时才产生整窗 Gap。
- 空窗口沿用原接口无需查库的合同：未来或今天零点返回空覆盖，不表示已经验证数据库健康。
- 相交读取不足以提供完整睡眠摘要。例如恰在当天零点醒来的睡眠与窗口不相交，但完整摘要仍应考虑它；额外候选查询和一致性扩展留 Epic 5/8。本任务未扩展 repository 或拼接其他时刻的查询结果。

## Validation

以下命令均在仓库根目录由本 agent 实际运行，未安装或更新依赖。

| 命令 | 结果 |
| --- | --- |
| `dart format lib/features/ledger/application lib/app/time lib/app/bootstrap/recording_ledger.dart test/app/time test/features/ledger/application` | 退出 0；新增 5 文件格式化；修正后对 application 两目录再运行，退出 0 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/application/recording_ledger_loader.dart lib/app/time/device_recording_date.dart lib/app/bootstrap/recording_ledger.dart test/app/time/device_recording_date_test.dart test/features/ledger/application/recording_ledger_loader_test.dart` | 退出 0；5 文件、0 changed |
| `flutter analyze --no-pub` | 最终退出 0；No issues found |
| `TZ=America/New_York flutter test --no-pub test/app/time test/features/ledger/application test/features/ledger/data/ledger_read_test.dart test/features/ledger/domain/projection` | 最终退出 0；84 项全部通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/time test/features/ledger/application` | 退出 0；9 项全部通过 |
| `git diff --check` | 退出 0 |
| 执行前全部跟踪 / 未跟踪文件 SHA-256 对照 | 实现与验证后既有文件 0 改动；文档收尾仅在 TASKS 的 E4-T01 追加状态 |

首轮测试因缺少 Drift interceptWith 扩展导入而编译失败；首轮分析同时报告两处 prefer_initializing_formals。修正导入与构造器后，以上相关测试与分析均重跑通过，没有将首轮失败算作通过。最终测试日志在本机临时文件 `/tmp/e4_t01_tests_ny.log`、`/tmp/e4_t01_tests_shanghai.log`。

验收映射：

1. 显式 now 的历史 / 今天 / 未来、今天零点、毫秒边界；闰日、跨年日历进位。
2. 两个真实进程设备时区使用同一个 UTC now：纽约所选日期为未来，上海为今天，绝对日界分别正确。纽约 2026-03-08 / 2026-11-01 分别为 23 / 25 小时，上海同日期为 24 小时。对应时区测试在上述两次命令中均实际执行；普通未指定 TZ 的运行可能跳过两项特定时区断言。
3. 真实 Drift / SQLite 同一事务三次 SELECT 后投影：跨日主睡眠、小睡、Unknown、有归档 Goal 和解释的普通记录、无 Goal / 无解释的普通记录，以及窗口外事实和跨 now 事实。accounted=11h、unknown=1h、Gap=3h，同窗合计 14h；验证实际三个 Gap、边界精度及源记录完整起止。
4. 提交事实删除并推进 now 后用同一 loader 重读：Unknown 归零、Gap 更新、旧结果保持不变；不以 UI 内存修改冒充正式事实变化。
5. 空账本各日期窗口成功；仅睡眠也能完全覆盖；零点醒来记录不被误计入当天覆盖。
6. 非规范存储数据及关闭数据库分别抛出数据 / 存储错误，不静默丢行或返回整窗 Gap。
7. 回归原有真实 repository 读取一致性、独立连接竞争和 E3 全部投影测试。

## Self-review

已完整检查全部新增生产和测试文件、导入方向、不可变输出、查询范围、近似传播复用与错误语义。工作开始时既有修改和未跟踪文件全部保留，未覆盖他人工作；TASKS 仅追加本任务完成行。未改 schema、repository、领域算法、pubspec / lockfile、平台配置、其他任务状态或产品文档。

无 UI 时间线、完整睡眠摘要查询、统计页面、草稿输入、写入协调、额外依赖或持久化派生结果。

## Blockers / Open Questions

无阻塞和新增未决问题。真实库集成使用本机 NativeDatabase.memory，执行真实 SQL / 事务 / 映射；不是 mock。时区证据来自本机 Dart 运行时的两个 TZ 进程，不声称已完成 Android / Web 运行中切换系统时区、关闭应用或浏览器刷新验收。完整平台记录闭环仍按 E4-T08 验证。

## Next executable task

**E4-T02 — 实现普通入口的时间建议分支**。其前置 E4-T01 已完成；本次仅执行 E4-T01，未开始 E4-T02。
