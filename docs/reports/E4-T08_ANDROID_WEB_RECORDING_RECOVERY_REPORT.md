# E4-T08 — 验证 Android 与 Web 的保存和草稿恢复

## Task / Status

**COMPLETE（2026-09-29）。** 仅执行 E4-T08，未执行 E4-T09。E4-T07 的状态、报告及交互测试已核对；E2-T08 有 COMPLETE 报告、真实 Android / Web 存储重开证据及实现，但 `TASKS.md` 该条原本没有状态行，本次不代改前序记录。Q-012、Q-022 均为 DECIDED，没有阻塞性 Open Question。

依据 Source of Truth 的回顾式账本、正式事实与 Gap / Unknown 边界，IMPLEMENTATION_PLAN 的输入草稿共同交付合同及 Epic 4，DATA_ARCHITECTURE 的独立本机草稿，MVP_SCOPE 的闭环验收。按 `AGENTS.md` 委派有界只读代码勘查，主 agent 核对入口和持久化连接后完成测试设计、执行及复核。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `integration_test/recording_platform_test.dart` | 新增同一应用入口的五阶段真实平台测试，以唯一 run ID 分离正式库、草稿库与阶段控制库；每阶段断言通过后才推进控制标记 |
| `integration_test/support/recording_platform_status_native.dart`、`recording_platform_status_web.dart` | Web 阶段完成时写入页面标题，供同一浏览器标签页的外部刷新驱动核对；Android 保持空实现 |
| `tool/e4_t08_relaunch_android.py` | 首次安装并运行测试后，逐次执行 Android `am force-stop`、确认进程退出、启动 Activity，读取设备测试日志确认后续四阶段 |
| `tool/e4_t08_refresh_web.py` | 启动隔离 Chromium profile，在同一标签页执行四次 WebDriver `refresh` 并等待每个阶段的页面标题 |
| `TASKS.md`、本报告 | 记录本任务状态、平台环境、步骤、结果和验证边界 |

未修改正式 app、domain、数据库 schema 或依赖。测试通过现有 `AppBootstrap` 和真实平台数据库连接读写正式事实及独立草稿；不是内存 mock 或仅重开数据库连接。

## Platform evidence

| 阶段 | 进入前的实际生命周期操作 | 通过的行为断言 |
| --- | --- | --- |
| 1 | 首次启动 Android 测试应用 / 首次打开 Web 页面 | 新建表单输入标题、准确开始时间，保留默认近似结束精度，结束时间未填；离开页面后草稿存在，正式账本仍空 |
| 2 | Android 强制停止并重新打开 Activity / Web 同一标签页刷新 | 恢复新建草稿及未完成时间；补齐结束时间正式保存后账本读回，混合精度保留且新建草稿清除；编辑输入离开页面后，原正式事实仍保持原值 |
| 3 | 再次停止并打开 / 刷新 | 正式记录仍可读，编辑草稿恢复；外部插入一条重叠事实后提交恢复的更正，当前冲突校验拒绝写入并展示相关记录，草稿与原事实保留 |
| 4 | 再次停止并打开 / 刷新 | 失败的编辑草稿再次恢复；手动调整时间后更正成功，编辑草稿清除；新建另一份输入并主动放弃，草稿清除 |
| 5 | 再次停止并打开 / 刷新 | 更正后的正式记录仍可读；新建、编辑入口均不恢复已清除草稿；隔离正式测试记录随后清理 |

Android 设备为 `Medium_Phone` 模拟器，Android 13 / API 33，型号 `sdk_gphone64_x86_64`，设备 ID `emulator-5554`。从独立 run ID `e4t08_android_20260929_final2` 启动 `python tool/e4_t08_relaunch_android.py --run-id e4t08_android_20260929_final2 --device emulator-5554`；脚本首先执行 `flutter run --no-pub -d emulator-5554 -t integration_test/recording_platform_test.dart --dart-define=E4_T08_RUN_ID=e4t08_android_20260929_final2`，之后四次 `adb shell am force-stop com.tokiya.time_pet_ledger`，检查 `pidof` 不再返回进程，再以 `adb shell am start -n com.tokiya.time_pet_ledger/.MainActivity` 重新打开。五阶段均通过，脚本退出 0。阶段间没有卸载应用或清除应用数据。

Web 使用 Chromium `153.0.8010.52` 与同版本 ChromeDriver，headless 模式、临时独立浏览器 profile、本机 `http://127.0.0.1:7358/`。以 `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7358 -t integration_test/recording_platform_test.dart --dart-define=E4_T08_RUN_ID=e4t08_web_20260929_final2` 提供同一测试页面；执行 `python tool/e4_t08_refresh_web.py --url http://127.0.0.1:7358/ --run-id e4t08_web_20260929_final2`。ChromeDriver 在同一 session / tab 中四次调用 `/refresh`，每次检查新页面报告的阶段；五阶段均通过，脚本退出 0。该运行使用当前 Web 正式连接路径，数据限于临时 profile，结束时 profile 已删除。

## Validation

| 命令 | 结果 |
| --- | --- |
| `dart format`（本任务 3 个 Dart 文件） | 退出 0，0 changed |
| `dart format --output=none --set-exit-if-changed`（同 3 文件） | 退出 0，0 changed |
| `python -m py_compile tool/e4_t08_relaunch_android.py tool/e4_t08_refresh_web.py` | 退出 0 |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub` | 退出 0，362 项通过、2 项 skip |
| Android 上述全新 run ID 五阶段生命周期测试 | 退出 0，五阶段通过 |
| Web 上述全新 run ID 同页四次刷新测试 | 退出 0，五阶段通过 |
| `git diff --check` | 退出 0 |

## Self-review / Blockers / Open Questions

已复核新增未跟踪文件、`TASKS.md` 的单条状态修改及原有工作区改动。测试先检查正式事实不被未保存编辑修改，并在草稿恢复后插入冲突事实，因而覆盖失败保留与按当前事实重新校验；通过真实重启和刷新检查成功、主动放弃后的草稿清除。使用隔离命名的测试数据库和浏览器 profile；正式应用行为与用户数据不受测试清理影响。

无 blocker 或新增 Open Question。E2-T08 在 `TASKS.md` 中缺状态行是既存记录差异，其报告和实际平台证据已核对，不阻塞本任务。本次不声称其他平台、睡眠或复盘草稿已经完成，也不作发布验收。

## Next executable task

**E4-T09 — 提供普通记录可选备注入口（Should Have）。** 其前置 E4-T06 已完成；本次到 E4-T08 为止，不执行 E4-T09。
