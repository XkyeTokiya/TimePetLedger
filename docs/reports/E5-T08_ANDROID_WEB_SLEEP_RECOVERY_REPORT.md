# E5-T08 — 验证 Android 与 Web 睡眠保存和恢复

## Task / Status

**E5-T08 / COMPLETE，2026-09-30。** 仅执行本 Task，未执行 E5-T09。

读取 AGENTS、Task 全文、共同必读 SOT / OQ / MVP / PLAN、PLAN 的输入草稿共同交付合同与 Epic 5、DATA 的本机输入草稿，并核对 APP 的失败边界及 SL-004。前置 [E5-T07](E5-T07_SLEEP_RECORDING_FLOW_REPORT.md)、[E2-T08](E2-T08_FULL_PERSISTENCE_REPORT.md) 的完成证据和实际实现一致；Epic 2 / 3 完成证据见 TASKS 的逐项报告索引。Q-012 / Q-022 均为 DECIDED，相关睡眠、更正、冲突和精度合同没有来源冲突或新增 blocker。

按 AGENTS 委派 code_mapper 有界只读定位既有 E4 平台阶段协议、驱动脚本及睡眠连接注入入口；主 agent 检查证据后完成测试设计、执行、自审及验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [sleep_platform_test.dart](../../integration_test/sleep_platform_test.dart) | 同一实际 AppBootstrap 的八阶段睡眠保存 / 恢复测试；正式库、睡眠草稿、首次标记、普通草稿和控制库按唯一 run ID 分离 |
| [sleep_platform_status_native.dart](../../integration_test/support/sleep_platform_status_native.dart)、[sleep_platform_status_web.dart](../../integration_test/support/sleep_platform_status_web.dart) | Web 通过 document.title 报告已完成阶段；Android 使用测试日志 |
| [e5_t08_relaunch_android.py](../../tool/e5_t08_relaunch_android.py) | 安装运行第一阶段，随后七次真实强停 / 重开，核对进程退出和每阶段测试通过 |
| [e5_t08_refresh_web.py](../../tool/e5_t08_refresh_web.py) | 隔离浏览器 profile、同一 session / tab 七次真实刷新，逐阶段核对通过标记 |
| TASKS、COMPLETED_TASKS、本报告 | 完成状态、完整定义归档、原锚点和证据 |

没有发现需要修复的生产代码问题。测试复用正式平台连接工厂、repository、草稿存储、首次检查及 E3 投影；未新增依赖，未改领域合同、schema、生成代码、app 行为或平台配置。

## Platform evidence

下表阶段编号为脚本显示的完成编号；Dart 内部 phase 从 0 开始。阶段控制标记只有在本阶段所有断言通过后才推进。阶段之间没有卸载、清除数据或仅重开数据库来代替实际平台生命周期操作。

| 阶段 | Android / Web 的进入方式 | 通过的断言 |
| --- | --- | --- |
| 1 | 首次启动 / 首次打开页面 | 首次主睡眠确认进入表单；跨日开始、未完成醒来原文、独立混合精度自动保留。离开页面后正式事实为空、覆盖为 0，重新进入恢复草稿，保留输入页等待实际关闭 / 刷新 |
| 2 | 第 1 次强停重开 / 同页刷新 | 无正式主睡眠也不重复首次询问，已检查标记跨启动有效；恢复未完成新建输入，补齐后保存一条完整 mainSleep，摘要约 470 分钟、覆盖准确 460 分钟。清除新建草稿；形成未完成编辑草稿，离开再进入恢复，原正式事实仍为原值 |
| 3 | 第 2 次强停重开 / 刷新 | 正式睡眠和不完整编辑原文均可读；恢复后插入 TimeBlock 与 SleepSession，再补齐并提交更正，事务按当前事实拒绝两类冲突、列出类型 / id，保留草稿及原睡眠 |
| 4 | 第 3 次强停重开 / 刷新 | 冲突失败后的编辑再次恢复；手动修正，真实 AFTER UPDATE / ABORT 触发器令正式写入回滚，原睡眠和草稿仍在。移除故障后更正成功且身份 / createdAt 保留。新建混合精度 nap，真实草稿 DELETE / ABORT 故障令已提交保存的清理失败；页面明确“已保存”，重试不增加正式记录，解除故障后清理完成。另建不完整输入并主动放弃 |
| 5 | 第 4 次强停重开 / 刷新 | 更正后的主睡眠、nap、两端精度均可读；成功新建、更正及主动放弃后均没有旧草稿恢复。删除主睡眠，仅 nap 留存 |
| 6 | 第 5 次强停重开 / 刷新 | 已删除主睡眠不复活；当日检查标记仍免打扰，明确显示尚未记录主睡眠。保存下一设备日期醒来的完整主睡眠 |
| 7 | 第 6 次强停重开 / 刷新；注入 next-day now | 新设备日期尚未登记首次标记，但已有结束的正式 mainSleep，直接免打扰；重启读回完整跨日事实和混合精度，摘要 / 覆盖再次为约 470 / 准确 460 分钟。删除该睡眠 |
| 8 | 第 7 次强停重开 / 刷新 | 删除后新的设备日期标记仍跨启动免打扰。随后在同一阶段重建 app 并注入再下一自然日，重新出现首次确认，可继续账本；最后清空隔离正式五表 |

每个无冲突夹具的阶段核对 Goal、TimeBlock、RhythmAnnotation、DailyReview 为空；冲突夹具由正式 repository 明确创建，并在手动修正成功后移除。未生成普通块、recovery 或睡眠解释。只有真实库的测试连接使用故障触发器，正式写入结果和投影没有 mock。阶段 4 的提交后清理恢复在本次运行内完成，下一次实际重启 / 刷新核对清理结果；不把它扩大为“带未清理提交凭据关闭后”的恢复保证。

**Android：** Medium_Phone 模拟器，Android 13 / API 33，型号 sdk_gphone64_x86_64，设备 emulator-5554，设备时区 Asia/Shanghai。最终 run ID 为 `e5t08_android_20260930_final3`。脚本先执行 `flutter run --no-pub -d emulator-5554 -t integration_test/sleep_platform_test.dart --dart-define=E5_T08_RUN_ID=e5t08_android_20260930_final3`，随后七次执行 `adb shell am force-stop com.tokiya.time_pet_ledger`，确认 pidof 无进程，再 `am start -n com.tokiya.time_pet_ledger/.MainActivity`。八阶段均通过，脚本退出 0。通过 run-as 列表实际核对独立 formal / sleep_drafts / openings / ordinary / control 的五个 final3 SQLite 文件位于 app_flutter；最后正式行已清空，隔离控制 / 标记文件仍可留存。

**Web：** Chromium 153.0.8010.52 / ChromeDriver 153.0.8010.52，headless、临时独立 profile、同源 `http://127.0.0.1:7368/`，最终 run ID 为 `e5t08_web_20260930_final3`。使用现有 Web 正式连接工厂（仅允许 OPFS / shared IndexedDB 实现，拒绝内存和 unsafe IndexedDB）；不声称选中了哪一种允许的后端。脚本在同一 WebDriver session / tab 七次调用 refresh，八阶段均通过，退出 0。结束时关闭浏览器 / ChromeDriver 并删除临时 profile。

两平台的 now 明确注入测试日期 2026-09-29、09-30 和下一自然日 10-01；日期递进用于判定验证，没有改变设备系统时间。实际强停 / 刷新操作由平台驱动完成。

## Validation

| 实际命令 | 结果 |
| --- | --- |
| `dart format integration_test/sleep_platform_test.dart integration_test/support/sleep_platform_status_native.dart integration_test/support/sleep_platform_status_web.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同 3 文件） | 退出 0，0 changed |
| `python3 -m py_compile tool/e5_t08_relaunch_android.py tool/e5_t08_refresh_web.py` | 退出 0 |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，455 项通过、1 项纽约 DST 定向用例按时区条件跳过 |
| `python3 tool/e5_t08_relaunch_android.py --run-id e5t08_android_20260930_final3 --device emulator-5554` | 退出 0，八阶段及七次实际强停重开通过 |
| `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7368 -t integration_test/sleep_platform_test.dart --dart-define=E5_T08_RUN_ID=e5t08_web_20260930_final3` + `python3 tool/e5_t08_refresh_web.py --url http://127.0.0.1:7368/ --run-id e5t08_web_20260930_final3 --driver-port 9528` | 服务启动成功；刷新脚本退出 0，八阶段及七次同页刷新通过 |
| `git diff --check` | 退出 0 |
| Task 定义、稳定锚点、47 项归档数量及文档链接核对 | 通过 |

首次静态分析发现测试使用了不存在的 snapshot getter，改为既有 readWindow 获取跨日期的完整测试事实。首次图形 emulator 启动退出 -6，使用已有 emulator 的无窗口模式成功启动，未安装工具。Android 初次测试在异步首检查完成前断言首次提示，修正为等待正式覆盖结果后再断言；Web 初版在更正返回后的短视口向下寻找位于上方的首页按钮，修正测试滚动方向。最终同一版本在全新 run ID 上分别重跑两平台，均完整通过。没有为这些测试问题改变产品行为。

最终日志为 `/tmp/e5_t08_android_final3.log`、`/tmp/e5_t08_web_final3.log`、`/tmp/e5_t08_web_server_final3.log`、`/tmp/e5_t08_analyze_final.log`、`/tmp/e5_t08_all_tests.log`，均为本机临时日志。全量有 5 条既存 Drift 独立 AppDatabase 多实例调试警告，与 E5-T07 数量一致；平台的控制库与普通草稿使用同一数据库类的独立连接，可能报告对应调试警告，没有共用 executor 或关闭全局警告。

## Self-review

检查全部新增未跟踪 Dart / Python 文件、真实平台连接与路径、独立 run ID、阶段控制写入时机、输入页关闭 / 刷新、原始未完成文本和精度、正式事实隔离、恢复后当前冲突校验、真实回滚、已提交清理失败的防重复反馈、成功 / 放弃后的不恢复，以及跨启动的首次标记和已记录识别。前序领域、事务、app 和投影测试继续保留，不以平台测试替代。

对照开始时文件内容和 SHA-256 快照：既有源码 / 文档仅更新 TASKS、COMPLETED_TASKS；新增 3 个 Dart 测试 / reporter、2 个 Python 驱动与本报告。Android 运行仅额外写入被 Git 忽略的 Gradle 构建缓存；原有源码、pubspec / lockfile、领域文档、前序报告、生成代码、平台配置及 E2–E5 工作区修改均保留。移除本次 py_compile 产生的新 pyc，既有 pyc 不动。任务归档保留旧正文，E5-T09 与后续任务未开始。本轮启动的 Web 服务和无窗口 emulator 已关闭。

## Blockers / Open Questions

无剩余 blocker 或新增 Open Question。纽约 DST 定向用例本轮跳过，不写为通过。平台证据限于上述 Android 模拟器和 Chromium 的正常流程 / 强停 / 同页刷新；不声称崩溃断电、整机重启、其他浏览器矩阵、同步或发布部署通过，也不声明全 MVP 完成。

## Next executable task

**E5-T09 — 提供睡眠可选备注入口（Should Have）。** 前置 E5-T05 已完成，Q-012 / Q-015 当前为 DECIDED；该任务不阻塞核心 Epic 5 能力。本轮完成后停止，未执行 E5-T09 或 Epic 6。
