# E9-T09 — 验证 Android 与 Web 复盘保存和恢复

**Task / Status：E9-T09 / COMPLETE（2026-10-03，Asia/Shanghai）。** Android 与 Web 均取得复盘正式持久化和独立草稿的实际生命周期证据。Epic 9 核心验收完成；没有执行或细化 Epic 10。

## 依据与前置

核对 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 MVP / M-06、M-07、DATA / 本机输入草稿、PLAN / Epic 9。按领域职责核对 MODEL / DailyReview、TomorrowFirstStep、RULES / DR-001–DR-004 和 APP / review 依赖与本机草稿装配。

直接依赖 [E9-T08](E9-T08_REVIEW_CLOSURE_REPORT.md)、[E7-T07](E7-T07_GOAL_RHYTHM_PLATFORM_REPORT.md)、[E8-T06](E8-T06_SUMMARY_PLATFORM_REPORT.md) 的归档定义、完成报告及相关实现均有完成证据。Epic 2、7、8 已完成；Q-012、Q-022 为 DECIDED，日期、原身份更正及原归档引用继续遵守 Q-001、Q-006、Q-013，没有新增产品决定或来源冲突。

按 AGENTS 委派 code_mapper 作有界只读勘查，定位既有五阶段协议、真实强停 / 刷新驱动和连接隔离方式。主 agent 检查证据后完成测试设计、实现、自审和最终验证。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| [review_platform_test.dart](../../integration_test/review_platform_test.dart) | 真实 AppBootstrap / repository / 平台存储的五阶段复盘恢复、失败、正式保存、更正、删除和放弃测试 |
| [native reporter](../../integration_test/support/review_platform_status_native.dart)、[web reporter](../../integration_test/support/review_platform_status_web.dart) | Android 日志、Web 全部阶段断言通过后的 document.title 标记 |
| [Android 驱动](../../tool/e9_t09_relaunch_android.py)、[Web 驱动](../../tool/e9_t09_refresh_web.py) | 完整复用 E8-T06 生命周期协议，仅替换 Task 标识、命名和测试目标；保留前序驱动 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原任务全文归档、完成索引及 Epic 9 验收状态 |

未发现需修复的生产缺陷；未修改 lib、schema、生成代码、依赖、平台配置或前序测试。没有复盘统计列、自动反思、自动下一步或新导航。

## 实际平台证据

Dart phase0–phase4 对应下表阶段 1–5。每阶段全部断言通过后，才在独立 control 库保存下一阶段编号。两个平台阶段间均不卸载、不清应用数据；不会以测试内部关闭数据库代替真实生命周期。

| 阶段 | 实际操作与断言 |
| --- | --- |
| 1：初次启动 / 打开 | 真实 repository 建立跨夜 approximate 主睡眠、known / progress / continuationHint、Unknown、历史复盘及其原 Goal，再归档 Goal。核对历史上下文为已交代 540、Unknown 60、Gap 900 分钟，完整主睡眠 480、目标 progress 60 分钟。分别通过 UI 填写独立另一日期草稿、新建空下一步草稿（入口 2024-12-31，输入日期改为 2025-01-01）、已有复盘改日期 / 全文字草稿（2024-02-28 → 闰日 02-29）；离页重进保留原始空白、多行和 emoji，正式五表全行不变。保持改日期编辑页打开。 |
| 2：第一次强停重开 / 同页刷新 | 原 ID 编辑草稿、闰日、全部原始文字与新建空下一步草稿均恢复，正式内容仍为原复盘。为新建草稿填写下一步，表单打开后真实 repository 抢占其输入日期 2025-01-01；正式提交显示日期冲突，不覆盖竞争者，正式五表全行不变，原始草稿与其他两个上下文仍保留。保持失败表单打开。 |
| 3：第二次强停重开 / 刷新 | 失败新建草稿仍恢复，不误认内容不同的竞争者为已提交；再次提交仍拒绝。用户明确改回空日期 2024-12-31 后成功保存，概述 / 下一步 trim、空白反思存 null，原入口草稿清除，下一自然日为 2025-01-01。恢复原 ID 的编辑草稿并成功改到 2024-02-29，id / createdAt 保持，updatedAt 正确，全部文字规范化，归档原 Goal 引用保留，原日期空、编辑草稿清除、下一自然日为 2024-03-01；账本事实全行不变，另一日期草稿仍在。 |
| 4：第三次强停重开 / 刷新 | 读回新建及更正后的日期 / 文字 / 原归档 Goal / 下一自然日。分别主动放弃新建的未完成日期输入及已有复盘的未提交编辑，只有对应草稿清除，正式五表全行不变。随后通过编辑页、明确删除确认删除闰日原复盘，其编辑草稿清除，源日期和目标日期均空，时间事实保留。为竞争复盘建立独立编辑草稿并保持页面打开；另一日期新建草稿不串用。 |
| 5：第四次强停重开 / 刷新 | 原复盘删除仍保持；新建复盘及竞争者读回，已成功 / 放弃 / 删除的上下文无草稿。竞争者的独立编辑草稿及另一日期新建草稿分别按自身身份恢复，逐一主动放弃，正式五表保持。最后核对只剩两份预期复盘，再清空本 run 隔离正式夹具并释放 app。 |

UI 操作经过生产 ReviewContextPage / ReviewForm / ReviewFormController、ReviewEntrySaver 及真实 repositories。日期冲突是表单打开后的真实正式写入，没有 mock 唯一性或成功结果。`flush()` 只等待既有自动写队列完成，不替代页面自动保留。阶段之间 app 由外部驱动真正关闭或刷新，阶段编号与数据均通过原平台连接持久化。

正式、复盘草稿、普通草稿、睡眠草稿工厂、首次睡眠确认、control 分别采用 `e9_t09_*_<runId>` 命名；未使用开发者默认库。实际打开五个独立存储：formal、reviews、recording、openings、control；sleep 工厂已隔离但未进入睡眠输入页，不声称打开其存储。复盘新建草稿按入口日期、编辑草稿按原 ID 隔离；修改输入日期不会改变入口键或串用其他日期。

**Android：** 使用已有 Medium_Phone AVD，无窗口启动；设备 `emulator-5554`、`sdk_gphone64_x86_64`、Android 13 / API 33、设备时区 Asia/Shanghai。run ID：`e9t09_android_20261003_trial1`。初次 `flutter run` 安装并启动测试入口；后续四次执行 `am force-stop com.tokiya.time_pet_ledger`，每次核对 `pidof` 为空后执行 `am start -n com.tokiya.time_pet_ledger/.MainActivity`。每阶段必须同时出现对应 passed 标记和 `All tests passed!`，驱动退出 0。`run-as` 核对本 run 五个独立 SQLite 文件。成功 run 的正式行已清空，空库及阶段标记保留；没有删除其他 run 或开发者数据。最终 app 强停，本次启动的模拟器已关闭。

**Web：** Chromium / ChromeDriver 153.0.8010.52，headless、独立临时 profile，浏览器时区 Asia/Shanghai，同源 `http://127.0.0.1:7399`。run ID：`e9t09_web_20261003_trial1`。同一 WebDriver session / tab 执行四次 `/refresh`，五阶段全通过，驱动退出 0。正式及草稿使用生产 Wasm 连接，允许 OPFS / shared IndexedDB，拒绝内存与 unsafe IndexedDB；未观测具体选中哪一种允许后端，不作进一步断言。浏览器、ChromeDriver、临时 profile 由驱动清理，本次 Web 服务已关闭。

两平台注入 now 为 2026-10-03 12:00，不修改系统时钟。历史 CivilDate 与其下一自然日经实际保存 / 更正 / 重启读回，包含闰日跨月与年边界；不取系统今天或固定 24 小时。首次睡眠确认通过隔离 opening store 预先 claim 今日作为入口夹具，不改变产品行为。

## Validation

使用现有 Flutter / Dart、Android SDK / AVD、Chromium 和 ChromeDriver；没有安装工具或新增依赖。

| 实际命令 | 结果 |
| --- | --- |
| `dart format integration_test/review_platform_test.dart integration_test/support/review_platform_status_native.dart integration_test/support/review_platform_status_web.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同上 3 文件） | 退出 0，3 files / 0 changed |
| `PYTHONPYCACHEPREFIX=/tmp/e9_t09_pycache python3 -m py_compile tool/e9_t09_relaunch_android.py tool/e9_t09_refresh_web.py` | 退出 0，缓存位于工作区之外 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/review_closure_flow_test.dart test/app/review_route_flow_test.dart test/app/review_form_entry_test.dart test/features/review` | 退出 0，103 项通过，无跳过 |
| `TZ=Asia/Shanghai python3 tool/e9_t09_relaunch_android.py --run-id e9t09_android_20261003_trial1 --device emulator-5554` | 退出 0，五阶段 / 四次实际强停重开通过 |
| `TZ=Asia/Shanghai flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7399 -t integration_test/review_platform_test.dart --dart-define=E9_T09_RUN_ID=e9t09_web_20261003_trial1` + `TZ=Asia/Shanghai python3 tool/e9_t09_refresh_web.py --url http://127.0.0.1:7399 --run-id e9t09_web_20261003_trial1 --driver-port 9549` | 服务启动成功，驱动退出 0，五阶段 / 四次同源同页刷新通过 |
| `git diff --check`、新文件全文 / 空白、驱动复用、开始前 SHA-256、归档全文 / 本地链接 / 后续工作包核对 | 通过 |

初轮静态分析发现测试的未使用导入和 if 括号 lint，已修正；自审同时将 CivilDate 输入统一为既有 `formatReviewDate`，之后才开始平台验证。两平台均为首个 run 全阶段通过，没有放宽断言或修改生产行为。共用测试和平台 control / recording 的同类数据库独立实例有既有 Drift 调试提示，每个实例持有独立命名 executor，没有共享连接或禁用提示。

本次日志：`/tmp/e9-t09-analyze-initial.log`、`/tmp/e9-t09-analyze-final.log`、`/tmp/e9-t09-regression.log`、`/tmp/e9-t09-android-trial1.log`、`/tmp/e9-t09-android-final-logcat.log`、`/tmp/e9-t09-android-files.log`、`/tmp/e9-t09-web-server-trial1.log`、`/tmp/e9-t09-web-trial1.log`。仅计算本次实际运行结果，不把前序报告的测试数量计入本次。

## Self-review / Epic gate

检查新增五阶段测试、原始输入 / 空下一步、历史及改日期上下文、原 ID 与元数据、当前唯一约束、失败恢复、成功 / 放弃 / 删除的清理键、原归档引用、逐行事实快照、投影、阶段推进时机及真实生命周期驱动。执行前 382 个既有已跟踪 / 未跟踪文件 SHA-256 对照，仅完成状态的 TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN 三份文档改变，其余既有工作保持。新增 3 个 Dart、2 个 Python 和本报告。

Epic 2、7、8 的前置完成依据齐备。E9-T01–E9-T08 的逐项报告和 E9-T08 核心验收对照涵盖 CivilDate / 下一自然日、每日唯一、可选解释 / Goal、接续点与每日行动区分、无统计写回 / 自动评价、当前事实变化不改写反思、按原身份更正 / 删除与提交后安全收尾；本次 103 项定向回归通过，并补齐 E9-T09 Android / Web 草稿和正式数据的实际生命周期证据。因此 **Epic 9 核心验收完成**，不表示 Epic 10 全 MVP 可靠性或发布验收完成。

原 E9-T09 定义全文归档，仅增加 COMPLETE 和报告链接；Epic 10 工作包内容不变。没有自动执行后续任务。

## Blockers / Open Questions / Limitations

无剩余 blocker，无新增 Open Question。Task 要求的验收均有证据。未执行实体 Android 设备、整机重启 / 断电 / 崩溃、运行时系统时区切换、浏览器关闭重开、隐私模式 / 其他浏览器矩阵、发布 / 部署；本次证据限于上述模拟器强停重开与 Chromium 同源刷新。没有以本地文件重开冒充平台生命周期。

## Next executable task

当前 **没有已细化、可直接执行的下一 Task ID**。Epic 10 仍为待细化工作包；须另行授权细化。仅报告，不细化或执行。E9-T09 完成后停止。
