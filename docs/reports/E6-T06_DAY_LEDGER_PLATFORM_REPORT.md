# E6-T06 — 验证 Android 与 Web 时间轴补账集成

**Task / Status：E6-T06 / COMPLETE（2026-10-01）。** 两首发平台的新增时间轴路由、Gap 输入恢复和操作后刷新均取得实际运行证据。

## 依据与前置

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 MVP 的 M-02 / M-07、PLAN 的 Epic 6 与输入草稿共同交付合同、DATA 的本机输入草稿。核对 [E6-T05](E6-T05_DAY_LEDGER_RESOLUTION_REPORT.md)、[E4-T08](E4-T08_ANDROID_WEB_RECORDING_RECOVERY_REPORT.md)、[E5-T08](E5-T08_ANDROID_WEB_SLEEP_RECOVERY_REPORT.md) 的归档定义、完成报告及实际 app / 平台测试实现；Epic 3、4、5 的完成证据见 TASKS 索引。Q-012、Q-022 当前均为 DECIDED，无来源冲突或新的产品 blocker。

按 AGENTS 复用 code_mapper 作有界只读勘查，定位真实连接注入、平台阶段控制、关闭 / 刷新驱动和时间轴操作入口。主 agent 检查证据后负责测试设计、实现、自审及最终验证。

## Changes

| 文件 | 本轮职责 |
| --- | --- |
| [day_ledger_platform_test.dart](../../integration_test/day_ledger_platform_test.dart) | 同一 AppBootstrap 的五阶段真实平台测试，覆盖时间轴 → Gap 表单 → 返回 / 保存 → 原事实更正 / 删除 → 重启读回。 |
| [native reporter](../../integration_test/support/day_ledger_platform_status_native.dart)、[web reporter](../../integration_test/support/day_ledger_platform_status_web.dart) | Android 用测试日志，Web 用 document.title 报告已完成阶段。 |
| [Android 驱动](../../tool/e6_t06_relaunch_android.py) | 首次安装启动后，四次真实强停、核对进程退出并重开 Activity。 |
| [Web 驱动](../../tool/e6_t06_refresh_web.py) | 临时独立 profile、同一 session / tab 四次真实刷新，并记录浏览器版本与时区。 |
| [TASKS](../../TASKS.md)、[COMPLETED_TASKS](../planning/COMPLETED_TASKS.md)、本报告 | 完成状态、54 项完整归档、稳定锚点和验收证据。 |

没有发现需修复的生产实现缺陷。未改生产代码、领域合同、正式 / 草稿 schema、生成代码、依赖或平台配置；复用现有平台连接、repository、草稿存储和 E3 投影算法。

## Platform evidence

以下为驱动显示的完成阶段编号；Dart 内部 phase 从 0 开始。独立控制库只在该阶段全部断言通过后推进。阶段之间不卸载、不清除数据，也不以数据库重开代替平台生命周期操作。

| 阶段 | Android / Web 进入方式 | 实际操作与通过断言 |
| --- | --- | --- |
| 1 | 首次 app 启动 / 页面打开 | 正式 repository 建立前日 23:50–当日 07:40 的完整主睡眠，入睡近似、醒来准确。当前日窗口为 00:00–显式 now 12:00，已交代 460 分钟、Gap 07:40–12:00。从真实 Gap 填 known 到 09:00、改开始精度为准确；保留草稿返回后正式块仍为空、Gap 不变。重新进入恢复标题、时间及独立精度，保持表单打开等待关闭 / 刷新。 |
| 2 | 第一次强停重开 / 同页刷新 | 相同 Gap 恢复 known 输入，确认保存后已交代 540 分钟、剩余 Gap 09:00–12:00，对应草稿清除。从新 Gap 明确选择 Unknown 到 10:00；离开和重新进入均恢复输入，未提交时仍只有一条 known，覆盖不变。再次保持表单打开。 |
| 3 | 第二次强停重开 / 刷新 | 成功保存的旧 known 草稿不恢复；Unknown 输入和认知选择恢复。确认保存无标题 Unknown 后已交代 600 分钟、其中 Unknown 60 分钟，剩余 Gap 10:00–12:00，草稿清除。为另一 Gap 填 known 到 11:00，离开后正式覆盖仍不变，再进入恢复。 |
| 4 | 第三次强停重开 / 刷新 | 第三个 Gap 草稿恢复。正式 repository 在表单打开后新增 10:30–11:00 竞争小睡，提交时按当前事实拒绝冲突；正式五表逐行快照不变，草稿结束时间仍为 11:00。用户手动改为相接的 10:30 后成功保存，草稿清除、已交代 660 分钟。时间轴更正 known 标题，原 id / createdAt 保留；更正完整跨日主睡眠醒来为 07:30，新增 07:30–07:40 Gap；从时间轴进入睡眠表单删除竞争小睡，Gap 重算；删除 Unknown 块后 Unknown 为 0、已交代 560 分钟，三个剩余 Gap 正确。 |
| 5 | 第四次强停重开 / 刷新 | 正式读回两条 known 和一条完整主睡眠；睡眠仍从前日 23:50 到当日 07:30，完整摘要 460 分钟、createdAt / note 保留。已删除 Unknown 与小睡不复活，成功草稿全部为空，剩余 Gap 为 07:30–07:40、09:00–10:00、10:30–12:00。填新的 Gap 后主动放弃，草稿清除、事实和覆盖不变。切换前一历史日，跨日睡眠只投影 10 分钟；最后清空隔离正式五表并释放 app。 |

每个当前日检查点核对窗口边界、已交代时长、Unknown 时长、`accounted + unresolved = window`、Gap 的完整区间列表及实际 UI 数量。Unknown 已包含在 accounted 中；保留未解决 Gap 合法。正式事实始终经现有一致读取和 `projectDayLedgerView` 产生视图，没有保存 Day、Gap 或聚合。睡眠、冲突夹具由真实原子 repository 建立，known / Unknown 及更正 / 删除均通过实际页面完成；没有 mock 正式写入、草稿持久化或投影。

**Android：** 本轮启动已有 Medium_Phone AVD 的无窗口模式，设备 `emulator-5554`，型号 `sdk_gphone64_x86_64`，Android 13 / API 33，设备时区 Asia/Shanghai。run ID 为 `e6t06_android_20261001_trial1`。驱动首次执行 flutter run 安装测试入口；随后四次 `am force-stop com.tokiya.time_pet_ledger`，均确认 pidof 无进程后执行 `am start -n com.tokiya.time_pet_ledger/.MainActivity`。五阶段均报告 passed 和 All tests passed，驱动退出 0。通过 run-as 文件列表核对 formal / drafts / sleep_drafts / openings / control 五个独立 SQLite 文件位于 app_flutter；正式行最后已清空，隔离控制 / 标记文件保留。

**Web：** Chromium / ChromeDriver 均为 153.0.8010.52，headless、临时独立 profile，同源 `http://127.0.0.1:7378`，浏览器报告时区 Asia/Shanghai。run ID 为 `e6t06_web_20261001_trial1`。同一 WebDriver session / tab 四次调用 refresh，五阶段全部通过，驱动退出 0。使用现有 Wasm 正式连接工厂，其只接受 OPFS / shared IndexedDB，拒绝内存及 unsafe IndexedDB；本轮未观测具体选中的允许后端，不声称使用了其中某一种。结束时浏览器、ChromeDriver 和临时 profile 均由驱动清理。

测试 now 明确注入 2026-09-29 12:00，未改变设备系统时钟。本轮重点补充 Gap 上下文及新增路由的真实关闭 / 刷新证据，未机械重跑前序普通 / 睡眠平台全部故障矩阵。

## Validation

环境为现有 Flutter 3.47.5 / Dart 3.13.4；未安装额外工具。

| 实际命令 | 结果 |
| --- | --- |
| `dart format integration_test/day_ledger_platform_test.dart integration_test/support/day_ledger_platform_status_native.dart integration_test/support/day_ledger_platform_status_web.dart` | 退出 0。 |
| `dart format --output=none --set-exit-if-changed`（同 3 文件） | 退出 0，0 changed。 |
| `PYTHONPYCACHEPREFIX=/tmp/e6_t06_pycache python3 -m py_compile tool/e6_t06_relaunch_android.py tool/e6_t06_refresh_web.py` | 退出 0；缓存位于工作区之外。 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found。 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，491 项通过、3 项时区专用场景跳过。 |
| `python3 tool/e6_t06_relaunch_android.py --run-id e6t06_android_20261001_trial1 --device emulator-5554` | 退出 0，五阶段及四次实际强停重开通过。 |
| `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7378 -t integration_test/day_ledger_platform_test.dart --dart-define=E6_T06_RUN_ID=e6t06_web_20261001_trial1` + `python3 tool/e6_t06_refresh_web.py --url http://127.0.0.1:7378 --run-id e6t06_web_20261001_trial1 --driver-port 9538` | 服务启动成功；刷新驱动退出 0，五阶段及四次同页刷新通过。 |
| `git diff --check`、新增文件全文自审、Task 数量 / 状态 / 链接与开始前 SHA-256 对照 | 通过。 |

初轮静态分析发现新增测试的一条未使用 import，移除后通过。两平台在最终 Dart 版本上首次完整运行即通过，没有为测试改变生产行为。全量测试有 6 条前序 AppDatabase 多连接调试提示；平台控制库与普通草稿使用同一 Drift 数据库类的独立连接，也出现对应调试提示，未共用 executor 或禁用警告，没有测试失败。

日志：`/tmp/e6_t06_android_trial1.log`、`/tmp/e6_t06_web_trial1.log`、`/tmp/e6_t06_web_server_trial1.log`、`/tmp/e6_t06_analyze.log`、`/tmp/e6_t06_all.log`（本机临时日志）。

## Self-review 与 Epic 门槛

已检查全部新增 Dart / Python 文件：独立 run ID、实际平台连接、阶段标记推进时机、输入页关闭 / 刷新、Gap 上下文恢复、正式保存前覆盖不变、当前冲突校验、失败五表快照、成功 / 放弃清除、两种源事实的编辑路由、完整跨日事实及删除后的重启读回。测试只表达预期边界和时长，不重写投影算法。

对照任务开始时 239 个文件的 SHA-256，既有文件仅修改 TASKS、COMPLETED_TASKS；生产源码、已有测试、PLAN、领域文档、前序报告、pubspec / lockfile 和生成文件均原样保留。新增 3 个 Dart 文件、2 个 Python 驱动和本报告；原工作区修改及未跟踪文件保留。本轮启动的 Web 服务和无窗口模拟器已关闭。

Epic 3、4、5 的依赖已完成；E6-T01–E6-T06 逐项证据覆盖 PLAN 的窗口、切片、Gap 补记、Unknown 子集关系、批准更正 / 删除后重算与两首发平台恢复。本轮通过补足 Epic 6 平台门槛，Epic 6 核心范围完成；Goal / annotation UI、统计、复盘和完整 MVP 仍待后续范围。

## Blockers / Open Questions

无剩余 blocker 或新增 Open Question。3 项纽约 DST 定向场景本轮按时区跳过，当前通过证据仍见 E6-T05 的纽约运行，本轮不写为重新通过。未执行物理 Android 设备、整机重启、断电 / 崩溃、运行中系统时区切换、其他浏览器矩阵、发布或部署；这些不属于本 Task 的实际平台证据。

## Next executable task

当前没有已细化、可直接执行的后续 Task。下一步需单独授权细化 Epic 7 — Goal + Rhythm Annotation；本轮未执行该工作包，完成 E6-T06 后停止。
