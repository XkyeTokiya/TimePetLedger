# E3-T03 — 实现 Gap 与账本覆盖汇总

**Status：COMPLETE。** 执行日期：2026-09-28。

实现、14 项新测试及 self-review 已完成，格式检查和静态分析通过。agent 沙箱内 Flutter 测试因无法监听本地套接字而在加载阶段失败；用户随后提供本机 projection 测试的 `00:00 +35: All tests passed!` 结果，补齐正式验收证据。

## 前置与依据

用户明确授权 E3-T03；前置 [E3-T02](E3-T02_FACT_SLICING_REPORT.md) 为 COMPLETE，已包含用户本机 57 项相关测试通过证据。本次没有修改该前置实现，也没有将其旧测试结果外推为新增测试通过。

已核对完整 Task、Source of Truth 的 Unknown / Gap、自然日投影及统计语义，OPEN_QUESTIONS / Q-009、Q-014，MVP_SCOPE、IMPLEMENTATION_PLAN / Epic 3，DERIVED_MODELS / UnresolvedSpan、三项时长及同一窗口关系，DOMAIN_RULES / LEDGER-001–005 和 APP_ARCHITECTURE / 纯派生逻辑。没有发现冲突或缺失产品决定。按 AGENTS 委派 code_mapper 有界只读勘查，主 agent 检查现有窗口、切片、时长实现及来源证据后实施。

## Changes

| 文件 | 职责 |
| --- | --- |
| [ledger_coverage.dart](../../lib/features/ledger/domain/projection/ledger_coverage.dart) | 新增 UnresolvedSpan、LedgerCoverage 和 projectLedgerCoverage |
| [ledger_coverage_test.dart](../../test/features/ledger/domain/projection/ledger_coverage_test.dart) | 新增 14 项行为测试及分区关系核对 |
| 本报告 | 范围、验收证据与限制 |

函数接收同一 ReconciliationWindow 和 projectLedgerSegments 产生的全部主要事实切片，复制后按时间排序。扫描窗口首部、相邻事实之间和尾部的正时长空白，形成无持久化身份的不可修改 Gap 列表；相接不产生零时长 Gap。

accountedDuration 包含所有普通事实和睡眠贡献；unknownDuration 仅取 knowledgeState=unknown 的普通事实切片，属于 accounted 的子集；annotation 不另占时间，Goal 或节奏不用于过滤覆盖。三项均复用 DerivedDuration，按实际毫秒汇总，各自保留近似标志。

Gap 的事实来源边界分别继承对应端精度，窗口来源边界为 exact。unresolvedDuration 从实际 Gap 时长和标志求和，不从 accountedDuration 复制近似；即使覆盖内部近似，零缺口仍为无近似。结果保留所用窗口，分区关系以该窗口实际长度核对。

## 测试与验收映射

- 空窗口无 Gap、三项零时长且无近似；空事实非空窗口整体为精确 Gap，使用显式 23/25 小时日边界及 today 的毫秒级 now。
- 首尾及内部空白完整输出；未排序切片不影响结果且输入保持原顺序，输出列表不可修改。
- 连续相接覆盖无 Gap；仅 Unknown 也属于已交代；mainSleep / nap 均参与覆盖但不计入 Unknown。
- 复现 DERIVED 手算示例的 210 分钟已交代、30 分钟 Unknown、30 分钟 Gap。夹具把示例整体平移到从零开始的窗口，所有相对边界和时长保持不变；分别添加 / 不添加解释，结果相同。包含有 Goal 和无 Goal 的记录。
- 首、中、尾 Gap 两端独立传播；睡眠结束与普通事实开始的四种精度组合正确；全覆盖但内部近似时零缺口不近似；非空精确 Gap 也不会继承覆盖的全局近似标志。
- 跨日近似边界被裁掉后不传播；今天尾部止于 now，未来 Unknown 不贡献覆盖或近似。
- 使用新增、同身份更正（含 Unknown 改 known）、删除、清空后的合法快照重新计算；旧结果和原事实保持不变，不涉及数据库或另行实现写入操作。
- 16 种合法覆盖组合检查连续空白、`accounted + unresolved = window`、`0 ≤ unknown ≤ accounted`。所有 Gap 正时长且落在窗口内，未按分钟提前舍入。

## Validation

沿用现有 SDK 和 E3-T01 建立的 `/tmp/time_pet_ledger_e3_sdk` 临时可写缓存入口，不安装、升级或解析依赖。以下变量仅为实际命令中的路径简写：

```sh
task_dart=/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart
task_flutter=/tmp/time_pet_ledger_e3_sdk/bin/cache/flutter_tools.snapshot
```

| 实际命令 / 检查 | 结果 |
| --- | --- |
| `$task_dart format lib/features/ledger/domain/projection/ledger_coverage.dart test/features/ledger/domain/projection/ledger_coverage_test.dart` | 退出 0；2 文件格式化 |
| `$task_dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection/ledger_coverage.dart test/features/ledger/domain/projection/ledger_coverage_test.dart` | 退出 0；2 文件、0 changed |
| `env -u HOME DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics analyze --no-pub` | 退出 0；No issues found |
| `DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics test --no-pub test/features/ledger/domain/projection` | 退出 1；4 文件在加载时失败，0 用例执行；127.0.0.1 server socket 被沙箱禁止 |
| `git diff --check` | 退出 0 |
| 既有跟踪 / 未跟踪文件 SHA-256 对照 | 全部既有文件内容保留，无改写或删除 |

agent 测试失败日志位于本次临时环境 `/tmp/e3_t03_flutter_tests.log`，保留上述失败记录，不将用户执行记作 agent 执行。

**用户本机执行证据：** 用户首次复制命令时误将后续说明文字一并作为测试路径，导致两项不存在路径的加载失败，实际 35 项测试通过。去除说明文字后，用户重新执行以下命令，并回传 `00:00 +35: All tests passed!`。35 项包含本任务新增 14 项及前置 projection 的 21 项回归。此后仅更新本报告，未修改代码或测试。

```sh
flutter test --no-pub test/features/ledger/domain/projection
```

## Self-review / Blockers / Next executable task

已检查新增生产文件及测试完整内容、报告链接、同窗口分区、近似来源、Unknown 子集、睡眠与解释处理、输入不变、毫秒计算及范围。生产实现只依赖纯 domain / core/time，无全局时钟、设备时区读取、数据库、UI、评分、Goal 筛选入口或新依赖。没有改动既有文件或执行 E3-T04。

输入合同沿用本 Task 的合法、不重叠、同一窗口全部切片前提，调用方不得传过滤后的局部事实或其他窗口切片；没有为非法重叠定义容错、合并或修复政策，也不以投影替代写入层原子约束。

无产品未决项或剩余验收 blocker。沙箱本地通信限制仍存在，但用户本机测试通过证据已补齐。下一可执行开发 Task 为 E3-T04（依赖 E3-T02、E1-T05、E1-T06，均有完成证据）；本次不执行后续任务。
