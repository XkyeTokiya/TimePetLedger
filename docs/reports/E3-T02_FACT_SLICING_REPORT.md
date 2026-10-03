# E3-T02 — 实现事实切片与边界精度传播

**Status：COMPLETE。** 执行日期：2026-09-28。

实现、9 项正式测试和 self-review 已完成；格式检查、静态分析及补充纯 Dart 72 组切片检查通过。agent 沙箱内 Flutter 测试在加载阶段被本地套接字权限阻止；用户同日提供本机同一相关测试命令的输出，57 项全部通过，补齐正式验收证据。

## 前置与依据

用户明确授权继续 E3-T02。E1-T03、E1-T04、E1-T06 的完成依据为 [Epic 0 / 1 记录](EPIC_0_1_COMPLETION.md)。E3-T01 由用户补充本机命令 `flutter test --no-pub test/core/time test/core/identity test/features/ledger/domain/projection` 的 `00:01 +31: All tests passed!` 输出，已同步至 [E3-T01 报告](E3-T01_PROJECTION_CONTRACT_REPORT.md)，状态为 COMPLETE；该结果不包含此后新增的切片测试。

已核对 Task 全部定义、源提案 §4–6、§12–14、§23–24、§32，OPEN_QUESTIONS 的 Q-014 / Q-017，MVP_SCOPE、IMPLEMENTATION_PLAN / Epic 3，DERIVED_MODELS / segments 与 hasApproximation，DOMAIN_RULES / TB、SL、LEDGER，以及 APP_ARCHITECTURE / 纯派生逻辑。没有发现本任务产品冲突或缺失决定。按 AGENTS 委派 code_mapper 只读核查原对象字段、身份引用及前置证据，主 agent 检查了相关实现。

## Changes

| 文件 | 修改 |
| --- | --- |
| [ledger_segment.dart](../../lib/features/ledger/domain/projection/ledger_segment.dart) | 新增纯切片函数、封闭的两类切片结果、正交集计算和独立边界精度传播 |
| [ledger_segment_test.dart](../../test/features/ledger/domain/projection/ledger_segment_test.dart) | 新增 9 项行为测试，包含两类事实 72 组边界与精度组合 |
| [E3-T01 报告](E3-T01_PROJECTION_CONTRACT_REPORT.md) | 记录用户补充的前置测试证据，保留此前沙箱失败历史 |
| 本报告 | 实施范围、验证与环境限制 |

`projectLedgerSegments` 显式接收 ReconciliationWindow、TimeBlock、SleepSession 和 annotation 集合。仅正时长交集产生切片；结果按起点排序并返回不可修改列表，输入顺序与对象均不改变。函数依赖合法、不重叠、同类型身份唯一的事实快照，不合并、去重或修复非法重叠。

`TimeBlockSegment` 与 `SleepSessionSegment` 保留完整源对象引用及复用的 `LedgerFactReference`（类型与 id）。标题、已知性、Goal、备注、睡眠类型和原始精度仍来自源事实。annotation 只按 timeBlockId 附着普通事实，不单独贡献片段；相同 id 的睡眠不接收该解释。重复 annotation 引用按 RH-001 拒绝，避免 map 静默覆盖。

切片两端分别决定精度：严格裁掉的原边界以窗口边界替代并记为 exact；原边界与窗口相等时仍保留原精度。切片时长复用 intervalMilliseconds 和 DerivedDuration，不舍入、不读取时钟或设备时区。没有修改原事实、数据库、依赖、UI 或实现 Gap / 汇总。

## 测试覆盖

1. 23:50–次日 07:40 的同一 SleepSession 在两日分别贡献 600,000 和 27,600,000 毫秒，保留源对象。
2. 两类事实在窗口外或仅与窗口相接时没有切片。
3. 今天零点、未来日的空窗口不产生切片。
4. 两类事实跨 now 时只贡献窗口内部分，裁掉的近似结束不传播。
5. 每类事实的起点在窗口前 / 相等 / 之后、终点在窗口前 / 相等 / 之后，加四种独立精度组合，共 72 组，验证裁剪、近似及原精度保留。
6. 同 id 的普通事实和睡眠仍有不同源引用，解释只附着普通事实，展示信息保留。
7. 未排序输入合并后按时间排序；Unknown 无标题合法、没有解释时不自动补解释；输入不变、输出不可修改。
8. 一毫秒正交集保留实际时长，不因最终舍入为零而消失。
9. 重复解释引用失败，不静默选择其中之一。

## Validation

沿用 E3-T01 的现有 SDK 与 `/tmp/time_pet_ledger_e3_sdk` 临时可写缓存入口，不安装或解析依赖。下列变量仅为实际命令的路径简写：

```sh
task_dart=/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart
task_flutter=/tmp/time_pet_ledger_e3_sdk/bin/cache/flutter_tools.snapshot
```

| 实际命令 / 检查 | 结果 |
| --- | --- |
| `$task_dart format lib/features/ledger/domain/projection/ledger_segment.dart test/features/ledger/domain/projection/ledger_segment_test.dart` | 退出 0；2 文件格式化 |
| `$task_dart format --output=none --set-exit-if-changed lib/features/ledger/domain/projection/ledger_segment.dart test/features/ledger/domain/projection/ledger_segment_test.dart` | 退出 0；2 文件、0 changed |
| `env -u HOME DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics analyze --no-pub` | 退出 0；No issues found |
| `DASH__SUPPRESS_ANALYTICS=true FLUTTER_ROOT=/tmp/time_pet_ledger_e3_sdk $task_dart $task_flutter --no-version-check --suppress-analytics test --no-pub test/features/ledger/domain/projection test/features/ledger/domain/time_block_test.dart test/features/ledger/domain/sleep_session_test.dart test/features/ledger/domain/rhythm_annotation_test.dart` | 退出 1；6 文件加载失败，0 用例执行；127.0.0.1 server socket 被沙箱禁止 |
| `$task_dart --packages=.dart_tool/package_config.json /tmp/e3_t02_contract_check.dart` | 退出 0；直接导入生产代码，72 组纯 Dart 切片检查通过，不替代正式测试套件 |
| `git diff --check` | 退出 0 |
| 既有文件 SHA-256 对照 | 仅 E3-T01 报告按用户证据更新，其余既有跟踪 / 未跟踪文件保留 |

**用户本机执行证据（非 agent 沙箱执行）：** 2026-09-28 用户在本次对话回传以下完整命令输出，包含新增 9 项切片测试，末行为 `00:01 +57: All tests passed!`。57 项由 projection 21 项（E3-T01 的 12 项和 E3-T02 的 9 项）以及三类原对象相关 36 项测试组成。用户执行之后未再修改生产代码或测试。

```sh
flutter test --no-pub test/features/ledger/domain/projection test/features/ledger/domain/time_block_test.dart test/features/ledger/domain/sleep_session_test.dart test/features/ledger/domain/rhythm_annotation_test.dart
```

测试失败日志在 `/tmp/e3_t02_flutter_tests.log`，补充检查在 `/tmp/e3_t02_contract_check.dart`；两者为本次临时验证产物。没有把 E3-T01 的 31 项通过外推为新增测试已通过。

## Self-review / Blockers / Next executable task

已检查新文件全量内容、范围、端点严格比较、身份命名空间、annotation 关联、毫秒计算、原对象及输入集合不变、不可修改输出、领域依赖和报告链接。没有改动 TASKS、规划、存储、实体、E3-T01 生产代码或其他既有工作区修改。无新产品未决问题。

本任务无剩余 blocker 或产品未决项。沙箱本地套接字限制仍存在，但已取得用户本机正式测试通过证据，不影响本次验收结论。下一可执行开发 Task 为 E3-T03；本次未执行该 Task 或其他实现。
