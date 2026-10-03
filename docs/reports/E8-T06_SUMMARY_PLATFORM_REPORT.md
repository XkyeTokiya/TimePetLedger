# E8-T06 — 验证 Android 与 Web 基础摘要

**Task / Status：E8-T06 / COMPLETE（2026-10-02，Asia/Shanghai）。** 两首发平台均取得基础摘要集成及真实生命周期后的重算证据。仅执行 E8-T06；Epic 8 核心验收完成，不启动 Epic 9。

## 依据与前置

核对 AGENTS、Task 全文、共同必读 SOT / OQ / MVP / PLAN、MVP 的 M-05 / M-07、PLAN 的 Epic 8，并按领域职责核对 Q-008–Q-010、Q-012、Q-014、Q-017、Q-019–Q-022。上述问题均为 DECIDED，无来源冲突或新产品阻塞。E8-T05、E7-T07、E5-T08、E6-T06 的完整归档、完成报告及实际代码 / 测试已核对；Epic 3、5、6、7 的完整完成依据见 TASKS 索引。

按 AGENTS 委派 code_mapper 作有界只读勘查，定位既有五阶段协议、AppBootstrap 连接、真实关闭 / 刷新驱动和 UI 同步 helpers。主 agent 检查文件证据后负责实现、运行、自审和最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [summary_platform_test.dart](../../integration_test/summary_platform_test.dart) | 同一实际 AppBootstrap 的五阶段摘要测试；独立正式库 / 普通草稿 / 睡眠草稿 / 首次确认 / 控制库，复用生产平台连接、repository、loader、投影及格式映射 |
| [native reporter](../../integration_test/support/summary_platform_status_native.dart)、[web reporter](../../integration_test/support/summary_platform_status_web.dart) | Android 日志标记、Web 全部断言完成后的 document.title 标记 |
| [Android 驱动](../../tool/e8_t06_relaunch_android.py)、[Web 驱动](../../tool/e8_t06_refresh_web.py) | 完整复用 E7-T07 生命周期机制，仅替换 Task 标识和测试目标；保留前序文件 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成索引、原任务全文归档、Epic 8 验收依据及平台范围说明 |

未发现需修复的生产缺陷。本次不改 lib、前序测试、领域公式、正式 / 草稿 schema、生成代码、依赖、平台配置或产品导航；没有统计表、摘要事实缓存、复盘数值写回、周月报、评分或因果结论。

## Platform evidence

阶段 1–5 对应 Dart phase0–phase4。每阶段全部断言通过后才保存下一阶段标记；阶段之间不卸载、不清 app 数据。Android 驱动核对 force-stop 后进程为空，再启动 Activity；Web 使用同一 session / tab / origin 的真实刷新。不能把这些操作替换为测试内部关闭数据库。

### 混合正式事实与核对口径

测试夹具仅写入唯一 run ID 的隔离正式数据库，并通过生产 repository 执行约束校验；不作为交付 UI 或默认用户数据。显式 now 固定为本地 2026-10-02 12:00，不修改系统时钟。

- 跨日主睡眠约 10-01 23:00 → 准确 10-02 07:00：完整约480分钟，当前日覆盖420分钟；被日边界裁掉的近似起点不传播到当天睡眠覆盖。
- Goal A：progress 07:00–08:00（60）、stuck 约08:30–准确09:00（30）、recovery 09:30–10:00（30）、无解释10:00–10:30（30）；相关总量150分钟，四项按各自参与边界传播近似。
- Unknown 08:00–08:30（30），无 Goal recovery 10:30–11:00（30），nap 11:00–11:15（15），已归档同名 Goal B 的无解释记录11:15–11:30（15）。同名不同 id 保持独立。
- 当前日初始已交代约660分钟、其中未知准确30分钟、未记录准确60分钟；Unknown 已包含于覆盖。全局 recovery 准确60分钟，其中 Goal A recovery 为30分钟，不再把子集加到全局值。睡眠 / nap 不充当 recovery。

每个检查点核对窗口分区、Unknown 子集、主睡眠 / nap 的存在性与合计、Goal 身份 / 名称 / 归档状态及四项、全局节奏、实际格式文案。SleepSummaryView、GoalRhythmSummaryView 接收当前同一 DayLedgerView 中的同一对象；并再次调用该页面的既有 loader 核对覆盖和完整主睡眠身份。未在测试中实现第二套投影算法。

### 两平台均通过的五阶段

| 阶段 | 实际操作与通过断言 |
| --- | --- |
| 1 | 从首页打开实际摘要：今天660 / Unknown30 / Gap60，历史10-01覆盖60 / Gap1380且无醒来日主睡眠，未来10-03空窗口且无Gap；分别展示缺失主睡眠 / nap / 目标记录。通过真实平台 executor 注入一次读取失败，错误状态清空旧投影，重试取得正式事实且五表不变。日账本实际普通编辑器将 progress 结束改为07:45，返回摘要后覆盖645 / Gap75，Goal progress45，总量135。 |
| 2 | 真重启 / 刷新后仍为645 / Unknown30 / Gap75。打开 stuck 原事实，将结束输入改为09:15，保留草稿并返回摘要；正式五表不变，摘要仍按已提交的30分钟 stuck 展示。独立草稿已落盘。 |
| 3 | 再次真重启 / 刷新后恢复更正草稿，提交后清除对应草稿；stuck45、progress45，Goal总量150，覆盖660 / Gap60。通过实际 Goal 管理页改名为“平台摘要更正目标”并归档，重新进入摘要读取新名称 / 归档标记。 |
| 4 | 真重启 / 刷新后读取已提交更正与新 Goal 元数据。日账本实际睡眠表单将主睡眠改为09-30 23:00 → 10-01 07:00；返回今天摘要为覆盖240 / Unknown30 / Gap480，主睡眠缺失、小睡15。切历史10-01：完整主睡眠约480、覆盖准确420、Gap1020，原醒来日与新醒来日不混用。 |
| 5 | 再次真重启 / 刷新后重读240 / Unknown30 / Gap480，读取故障重试可恢复；10-01仍为完整约480 / 覆盖420，空历史09-29为覆盖0 / Gap1440，未来10-03为覆盖0 / Gap0。正式库仍有7个TimeBlock、2个SleepSession、4个annotation、2个Goal，DailyReview为空；最后清除本次隔离正式夹具。 |

摘要本身保持只读。测试捕获首页实际组装的 DayLedgerPage（带原有完整编辑回调），临时推到摘要路由上方，以验证真实更正页面和 RouteAware.didPopNext；这条测试操作不新增产品里的摘要编辑入口。Goal 更改走现有首页 / 管理页 / 摘要入口。

### Android

使用已有 Medium_Phone AVD，headless 启动；设备 emulator-5554 / sdk_gphone64_x86_64，Android 13、API 33、android-x64，设备时区 Asia/Shanghai。成功 run ID：`e8t06_android_20261002_trial2`。

首次安装启动通过阶段1，随后四次 `am force-stop`、核对 `pidof` 为空、`am start com.tokiya.time_pet_ledger/.MainActivity`，阶段2–5均取得对应 passed 标记和 `All tests passed!`；驱动退出0。成功完成后正式夹具清空，app 已强停，本任务启动的 emulator 已关闭。

初次试跑第4阶段误用了普通记录的时间对话框 helper，无法找到 time-dialog-input；只修正测试为睡眠 TextField 的 sleep-start / sleep-end 输入。修正后用新的独立 run ID 完整重跑五阶段通过。仅删除本次失败 trial1 的五个精确命名 SQLite 文件，保留前序平台数据库及其他工作区内容。

### Web

Chromium / ChromeDriver `153.0.8010.52`，headless 独立临时 profile，浏览器时区 Asia/Shanghai；origin `http://127.0.0.1:7386`，编译 run ID：`e8t06_web_20261002_trial1`。

五阶段通过，阶段间同一标签页真实刷新四次，驱动退出0。沿用生产 WasmDatabase 工厂；该工厂只接受 opfsShared / opfsLocks / sharedIndexedDb，拒绝 unsafeIndexedDb / inMemory。本轮未另行探测实际选择了哪一种可靠实现，不把候选驱动名称当成观察结果。数据跨刷新读回的证据来自上述真实五阶段。

首个浏览器会话在应用启动阶段超时，没有取得阶段1通过标记。待 Web 服务完成初始化后重新建立独立 profile，会话完整通过五阶段；未将超时尝试计为通过，也未放宽100秒阶段门槛。成功后驱动删除浏览器 session / profile并结束 ChromeDriver，Web server 已停止。

## Validation

以下命令在工程根目录实际执行：

| 命令 | 结果 |
| --- | --- |
| `dart format integration_test/summary_platform_test.dart integration_test/support/summary_platform_status_native.dart integration_test/support/summary_platform_status_web.dart` | 退出0，仅本次3个Dart文件；后续格式检查0 changed |
| `dart format --output=none --set-exit-if-changed integration_test/summary_platform_test.dart integration_test/support/summary_platform_status_native.dart integration_test/support/summary_platform_status_web.dart` | 退出0，3文件0 changed |
| `flutter analyze` | 最终退出0，No issues found；最初新增测试的未用import及两处if括号提示已修复 |
| `flutter test test/features/ledger test/features/goals test/app test/core/time` | 退出0，541通过、7个既有时区条件跳过；没有失败 |
| `TZ=America/New_York flutter test --no-pub test/features/ledger/application/day_ledger_loader_test.dart test/features/ledger/application/sleep_ledger_loader_test.dart test/app/time test/features/ledger/presentation/day_ledger_timeline_test.dart test/app/day_ledger_resolution_flow_test.dart` | 退出0，27通过、无跳过；覆盖真实本地日期适配、完整睡眠读取、23 / 25小时日及相应应用闭环 |
| `python -m py_compile tool/e8_t06_relaunch_android.py tool/e8_t06_refresh_web.py` | 退出0；本次生成的pyc已清理 |
| `python tool/e8_t06_relaunch_android.py --run-id e8t06_android_20261002_trial2` | 退出0，5阶段、4次真实强停重启通过 |
| `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7386 -t integration_test/summary_platform_test.dart --dart-define=E8_T06_RUN_ID=e8t06_web_20261002_trial1` | 服务启动；完成验证后主动结束 |
| `python tool/e8_t06_refresh_web.py --url http://127.0.0.1:7386 --run-id e8t06_web_20261002_trial1 --driver-port 9546` | 成功会话退出0，5阶段、4次同标签页刷新通过 |
| `git diff --check`、执行前SHA-256基线核对、文档链接 / 归档定义检查 | 通过；仅本次文档状态文件有既有文件增量 |

日志：`/tmp/e8_t06_android_trial2.log`、`/tmp/e8_t06_android_final_phase.log`、`/tmp/e8_t06_web_trial2.log`、`/tmp/e8_t06_web_server_trial1.log`、`/tmp/e8_t06_regression.log`、`/tmp/e8_t06_ny.log`、`/tmp/e8_t06_analyze_final.log`。失败尝试保留于对应 trial1 日志。Drift 的多个独立草稿 / 控制库实例提示为本测试构造的连接场景，未发生测试失败；Web软件WebGL回退提示未影响通过。

## Epic 8 完整验收

E8-T01–E8-T06 全部完成，依赖 Epic 3、5、6、7 完成；Q-010 / Q-014 / Q-020 / Q-021 均已决定。E8-T01–E8-T04 证明同一一致快照及原窗口、各摘要的独立近似与缺失表达；E8-T05 证明实际创建、更正、删除普通 / 睡眠事实和增改移除解释后重算、无草稿 / 复盘写回；E8-T06 补齐两平台实际生命周期证据。

对照 PLAN 验收：显示来自同一事实投影，提交后重读；无解释目标时间不推断progress，总量不冒充推进；Unknown不重复相加；缺失不推断零活动；睡眠 / 目标节奏仅作描述。没有持久化统计表、派生数值写回DailyReview、评分或因果结论。Epic 8 核心验收满足，不表示整个 MVP 已完成。

## Self-review

检查新增Dart及两份Python驱动完整内容、五阶段标记顺序、独立存储身份、路由返回、日期 / 原始睡眠边界、错误恢复、缺失 / 近似 / 归档文案和范围。两驱动与前序文件逐字归一比较，仅Task标识与目标不同。执行前基线核对确认代码验证完成时所有原有文件哈希一致；之后只更新TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN并新增本报告。原有工作区修改和未跟踪文件保留。

## Blockers / Open Questions / 未执行项

无阻塞，无新增Open Question。实际平台证据限上述Android emulator和Chromium：未执行物理Android硬件、OS reboot / 断电、系统运行中跨零点或切换时区、浏览器矩阵、生产部署 / release模式。纽约TZ进程中的非24小时日测试不替代真实设备运行中时区变更。没有执行Epic 9复盘输入、复盘平台生命周期或其他平台任务。

## Next executable task

E9-T01 — 接通按日复盘读取与上下文。E2-T07、E8-T05、E7-T02完成，Q-001、Q-006、Q-008均DECIDED；完整Epic 9所需Epic 2、7、8已完成。仅报告，不执行。
