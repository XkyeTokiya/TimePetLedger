# E7-T07 — 验证 Android 与 Web 目标节奏集成

## Task / Status

**E7-T07 / COMPLETE（2026-10-02，Asia/Shanghai）。** 两首发平台均取得真实目标 / 解释保存、草稿恢复、失败反馈及生命周期操作后的读回证据。仅执行本任务，未执行 E7-T08 或 Epic 8 / 9。

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 MVP 的 M-04 / M-07、DATA 的本机输入草稿、PLAN 的 Epic 7。核对 E7-T06、E6-T06 的完整归档定义、报告和实际实现；Epic 2、4、6 已有完成依据。Q-012、Q-022 均为 DECIDED；Goal 状态与解释更正继续遵守 Q-005、Q-006、Q-013，未发现来源冲突或新的产品 blocker。

按 AGENTS 委派 code_mapper 有界只读核查 E6-T06 平台入口、控制标记、连接工厂、强停 / 刷新驱动与报告协议，主 agent 检查证据后完成设计、实现、自审及最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [goal_rhythm_platform_test.dart](../../integration_test/goal_rhythm_platform_test.dart) | 同一真实 AppBootstrap 的五阶段目标 / 归属 / 解释平台测试；独立命名正式库、普通草稿、首次确认与阶段控制存储；真实旧 v3 草稿升级 |
| [native reporter](../../integration_test/support/goal_rhythm_platform_status_native.dart)、[web reporter](../../integration_test/support/goal_rhythm_platform_status_web.dart) | Android 测试日志标记；Web 在全部断言通过后写 document.title 标记 |
| [Android 驱动](../../tool/e7_t07_relaunch_android.py)、[Web 驱动](../../tool/e7_t07_refresh_web.py) | 复用 E6-T06 驱动的全部生命周期机制，仅替换 Task、数据库 / 日志命名和测试目标；未修改前序驱动 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原任务全文归档、稳定锚点索引与核心 Epic 状态同步 |

没有发现需修复的生产缺陷。领域、repository、生产 UI、正式 schema 2 / 五表、草稿 v4、生成代码、依赖及平台配置均未改动。LegacyInputs 仅构造隔离测试库的旧 v3 输入表，由生产迁移升级；没有重建正式 schema。

## Platform evidence

Dart 内部 phase 为 0–4，下表及驱动报告阶段为 1–5。每个阶段只在全部断言通过后持久化下一阶段标记。阶段之间不卸载、不清 app 数据；驱动实施真正的进程退出 / Activity 启动或同页刷新，不以重新打开数据库代替。

| 阶段 | Android / Web 进入方式 | 操作与通过断言 |
| --- | --- | --- |
| 1 | 首次启动 / 页面打开 | 在同一个实际平台草稿库建立旧 v3 ordinary 输入：原始含空白 / emoji 的标题、旧备注、10:00–11:00、开始 exact / 结束 approximate。生产存储升级后遗漏的 Goal / annotation 意图保持默认 keep，无提前事实。目标 UI 创建两个同名不同 id 的 active Goal；真实表单恢复旧标题 / 备注，按 id 选择目标、添加 progress 和多行原始接续点。离页再进恢复全部输入，正式五表不变，保持输入页打开。 |
| 2 | 第一次强停重开 / 同页刷新 | 原草稿、稳定 annotation id、正式目标均读回。通过管理页归档所选 Goal 后，恢复表单显示当前归档标识与重新选择提示；尝试新增关联被真实 repository 拒绝。五表逐行快照保持，失败输入和原接续点仍留草稿，保持失败输入页打开。 |
| 3 | 第二次强停重开 / 刷新 | 失败输入仍恢复。通过归档管理恢复 Goal，实际表单成功保存原 Goal + progress + 规范化接续点，成功清新建草稿；原始独立精度、annotation id 保持。当前目标时间与 progress 均为 60 分钟。repository 设置原分类 / 原原因 / 恢复方式作为未展示字段夹具。真实时间轴更正草稿改 Unknown、09:00–10:00、stuck / 新接续点；离页重进恢复，正式五表与 60 分钟 progress 投影不变，保持更正页打开。 |
| 4 | 第三次强停重开 / 刷新 | 更正草稿仍读回，成功的新建草稿为空。通过目标 UI 再归档已引用 Goal，历史投影仍显示原 60 分钟 progress 与归档标识；恢复编辑器可保留原归属。表单打开后真实 repository 建立 09:30–10:00 竞争 nap，拟更正区间冲突被拒绝，正式五表快照不变、接续点和草稿保留。用户手动将结束时间改为相接的 09:30 后原子成功，原 id / createdAt 和隐藏字段保持，updatedAt 按注入 now 更新。当前目标 stuck / Unknown 各 30 分钟。明确移除解释后仅无解释细分变为 30 分钟，TimeBlock 全行不变；再添加 recovery / 新接续点后只有一份解释，事实全行仍不变，成功清更正草稿。 |
| 5 | 第四次强停重开 / 刷新 | 正式读回两个 Goal、一条 Unknown TimeBlock、一份 recovery 和一条 nap；新建 / 更正草稿均空，原接续点及归档 Goal 正确显示，相关 / recovery 为 30 分钟。通过管理 UI 恢复并改名 Goal，重新访问时间轴反映当前名字 / active 状态，TimeBlock 和 annotation SQL 全行不变。重新填写 Goal / stuck / 接续点后主动放弃，草稿清除、五表不变。最后只清空当前隔离 run 的正式五表并释放 app。 |

每个投影检查点核对目标四项细分及 `accounted + unresolved = window`；睡眠仍是独立事实，不被标为 recovery。目标、记录、解释、更正 / 移除和放弃全部经过实际页面；竞争事实与旧字段夹具通过真实 repository 设置。正式读取、当前状态校验、跨事实事务、草稿迁移和投影均复用生产实现，未 mock 保存或重写算法。

**Android：** 启动已有 Medium_Phone AVD 的无窗口模式，设备 `emulator-5554`、型号 `sdk_gphone64_x86_64`，Android 13 / API 33，设备时区 Asia/Shanghai。最终 run ID 为 `e7t07_android_20261002_trial5`。驱动首次 flutter run 安装测试入口；随后四次 `am force-stop com.tokiya.time_pet_ledger`，每次核对 pidof 无进程，再执行 `am start -n com.tokiya.time_pet_ledger/.MainActivity`。五阶段 passed / All tests passed 门槛全部通过，驱动退出 0。run-as 文件列表核对正式、普通草稿、首次确认、control 四个独立 SQLite 文件；睡眠草稿工厂为隔离命名连接，但未进入睡眠输入页，不声称已打开该文件。成功 run 正式行最后清空，空存储及阶段标记保留；只删除本次失败 trial2–4 的独立测试命名文件，未清开发者 app 数据。最终 app 强停，本轮启动的模拟器关闭。

**Web：** Chromium / ChromeDriver 均为 153.0.8010.52，headless、独立临时 profile、同源 `http://127.0.0.1:7379`，浏览器报告时区 Asia/Shanghai。最终 run ID 为 `e7t07_web_20261002_trial4`。同一 WebDriver session / tab 四次 refresh，五阶段全部通过，驱动退出 0。正式与草稿连接使用既有 Wasm 工厂，仅允许 OPFS / shared IndexedDB，拒绝内存及 unsafe IndexedDB；未观测具体选中哪一种允许后端，不作进一步断言。浏览器 / ChromeDriver / profile 由驱动清理，本轮 Web 服务已关闭。

测试 now 明确注入 2026-10-02 12:00；组合更正推进至 12:01，未修改设备系统时钟。首次睡眠确认以隔离 opening store 预先 claim 当日作为入口夹具，场景从当日已确认开始。

## Validation

使用现有 Flutter / Dart、Android SDK、AVD、Chromium 和 ChromeDriver；未安装工具或新增依赖。

| 实际命令 | 最终结果 |
| --- | --- |
| `TZ=Asia/Shanghai dart format integration_test/goal_rhythm_platform_test.dart integration_test/support/goal_rhythm_platform_status_native.dart integration_test/support/goal_rhythm_platform_status_web.dart` | 退出 0 |
| `TZ=Asia/Shanghai dart format --output=none --set-exit-if-changed`（同上 3 文件） | 退出 0，3 files / 0 changed |
| `PYTHONPYCACHEPREFIX=/tmp/e7_t07_pycache python3 -m py_compile tool/e7_t07_relaunch_android.py tool/e7_t07_refresh_web.py` | 退出 0，缓存在工作区之外 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub` | 退出 0，568 项通过、3 项既有时区条件测试跳过；后续仅修正独立平台测试辅助方法，最终版本另由以下两平台验证 |
| `python3 tool/e7_t07_relaunch_android.py --run-id e7t07_android_20261002_trial5 --device emulator-5554` | 退出 0，五阶段及四次实际强停重开通过 |
| `flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7379 -t integration_test/goal_rhythm_platform_test.dart --dart-define=E7_T07_RUN_ID=e7t07_web_20261002_trial4` + `python3 tool/e7_t07_refresh_web.py --url http://127.0.0.1:7379 --run-id e7t07_web_20261002_trial4 --driver-port 9539` | 服务启动成功；驱动退出 0，五阶段及四次同页刷新通过 |
| `git diff --check`、新建文件全文自审、驱动复用对照、开始前 SHA-256、归档全文 / 后续任务定义 / 本地链接 / whitespace 检查 | 通过 |

初轮静态分析与 Android 编译发现测试内 Drift / Flutter 的 Table 导入歧义及一个括号 lint，已修正。连续同名目标输入的初轮 Android / Web 测试失败：辅助方法取消焦点后，测试绑定仍缓存同一 EditableText，第二次 enterText 未接通输入；检查本机 Flutter 源码确认该机制。改为先实际点击字段再输入，并保留字段原文断言与有界异步完成等待。仅等待帧稳定不代表平台 SQL 已完成，因此补充保存 / 加载状态及逐次创建的读回检查；没有改产品行为、减少目标数量或放宽断言。修正后 Android trial5 与 Web trial4 从独立新 run 开始，全部阶段通过。Web trial2 / trial3 仅启动服务，未运行浏览器验证。

共用测试及平台控制 / 普通草稿的同类数据库独立实例有既有 Drift 调试提示；每个实例持有独立 executor，未共用或静默禁用提示。Android 有现有 Gradle / SDK 工具链提示，最终构建成功；未为消除提示扩展平台配置。3 项纽约 DST 条件场景按上海时区跳过，未记作通过。

日志：`/tmp/e7_t07_android_trial5.log`、`/tmp/e7_t07_web_trial4.log`、`/tmp/e7_t07_web_server_trial4.log`、`/tmp/e7_t07_analyze_final.log`、`/tmp/e7_t07_all.log`；初轮失败日志按各自 trial 编号保留。

## Self-review / Epic gate

检查全部新增 Dart / Python 文件、阶段推进时机、run ID 校验、真实连接隔离、迁移前版本、字段焦点与异步状态、失败输入、按 id 区分同名目标、归档原引用、新增关联校验、解释唯一 / 移除 / 重加、当前事实冲突及操作后投影。对照执行前 312 个既有文件的 SHA-256 和内容副本，仅三份完成文档改变，其余既有已跟踪和未跟踪内容原样保留。新增 3 个 Dart、2 个 Python 与本报告；前序平台驱动保持原样。

Epic 2、4、6 的前置已完成，E7-T01–E7-T07 逐项完成证据覆盖 PLAN 的核心目标 / 解释交付与两首发平台门槛，因此 **Epic 7 核心范围完成**。E7-T08 原因 / 恢复细节入口仍为独立 Should Have，未将其标完成或作为核心门槛。统计 / 复盘及全 MVP 仍待后续任务，不以本结果表示完成。

原 E7-T07 全文归档，仅补 COMPLETE 与报告链接，后续任务定义不变。

## Blockers / Open Questions / Limitations

无剩余 blocker，无新增 Open Question。未执行物理 Android 设备、整机重启 / 断电 / 崩溃、运行时系统时区切换、其他浏览器矩阵、发布 / 部署；未用本地文件重开冒充平台生命周期。

## Next executable task

**E7-T08 — 提供可选原因与恢复细节入口（Should Have）** 可按编号接续，其前置 E7-T04 / E7-T05 已完成，涉及 Q 均 DECIDED；如执行，须按其定义补做受影响的两平台草稿恢复。核心路径 **E8-T01 — 接通摘要日期上下文与一致读取** 也已有前置，可独立执行，不等待 E7-T08。仅报告，不执行。E7-T07 完成后停止。
