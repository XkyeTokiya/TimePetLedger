# E2-T08 — 验证存储重开与完整持久化边界

**Status：COMPLETE**。执行日期：2026-09-27（Asia/Shanghai）。本任务验收范围内无剩余失败或 blocker。

## 前置、依据与执行范围

用户明确授权执行 E2-T08。Epic 0 / 1 依据[负责人完成确认](EPIC_0_1_COMPLETION.md)；前置存取实现及验证见 [E2-T04](E2-T04_GOAL_REPOSITORY_REPORT.md)、[E2-T05](E2-T05_LEDGER_READ_REPORT.md)、[E2-T06](E2-T06_ATOMIC_LEDGER_WRITE.md)、[E2-T07](E2-T07_REVIEW_REPOSITORY_REPORT.md)。不重新索取已确认的历史完成证据。

已核对 AGENTS、Task 完整定义、源提案 §33 的五类事实边界、DATA / Timestamps 与明确不持久化、PLAN / Epic 2、MVP / M-07，以及 Q-018 / Q-022 等已确定合同。沿用已批准的 SQLite / Drift 工程选型，不新增依赖或平台。按 AGENTS 委派 code_mapper 有界只读定位已有连接重开测试与平台入口，主 agent 核对后补齐正式五类数据场景。

既有 persistence_test 使用人工父子表验证连接重开；本次新增通过正式 repository 构造五类数据的完整场景，不替代前序约束、映射、事务和并发测试。

## 新增文件

| 文件 | 职责 |
| --- | --- |
| `integration_test/support/full_persistence_contract.dart` | 五类正式数据的共用重开场景、逐字段比较、失败持久化边界及 schema 核查 |
| `integration_test/full_persistence_test.dart` | Android / Web 正式连接工厂，唯一命名测试库，三次打开 / 两次重开 |
| `test/core/persistence/full_persistence_test.dart` | 独立临时 SQLite 文件执行同一合同，确认文件存在且非空 |
| 本报告 | 验收及限制记录 |

没有发现需要修复的生产实现缺陷；未改动生产代码。

## 验证场景与验收证据

1. 使用 GoalRepository、LedgerRepository、ReviewRepository 创建 Goal、TimeBlock、RhythmAnnotation、SleepSession、DailyReview。包含跨 UTC 日期的完整睡眠、独立起止精度、毫秒边界、已知活动及无可选字段的 Unknown、同 id 不同事实类型、Goal 关联、多行 Unicode 文本和完整可选解释细节。
2. 通过获准操作归档 Goal、切换解释状态、修改睡眠备注及复盘概述。保留原有归档引用、暂不适用的解释细节及 createdAt，区分事实起止时间和补记元数据。复盘采用历史闰日前日期，intendedDate 派生为下一自然日。
3. 尝试跨事实冲突更正、同日复盘重复创建，以及在新 TimeBlock 已插入后因重复 annotation PK 失败的组合写入。全部失败，并与失败前五表原始行比较；重开后再次证明没有残留或部分提交。
4. 关闭连接，确认旧连接拒绝查询，再调用工厂创建新 executor，打开同一测试存储。逐字段比较全部领域对象及五表原始值，包括身份、引用、日期、枚举、独立精度、可选字段、createdAt / updatedAt / archivedAt 和派生 intendedDate。预期比较不使用生产写入编码器生成。
5. 新连接上核验外键仍启用、禁止物理删除被引用 Goal；随后通过 repository 移除解释、删除 Unknown、恢复 Goal、移动复盘日期并清空可选字段。第二次关闭重开后，核对更正结果、删除不复活、原睡眠保留、复盘旧日期无记录、新日期 intendedDate 正确派生。
6. 每次打开均复用已有只读 schema 合同，核对精确五表、所有规定列、类型、NULL 约束和索引，没有 view / trigger。库中没有 Day、Gap、aggregate、切片、intendedDate 或统计持久化列。执行 PRAGMA foreign_keys、foreign_key_check、integrity_check，分别得到 1、空结果、ok。

正式夹具全部通过批准操作构造。唯一直接写 SQL 是预期失败的 Goal DELETE，用于重开后的 FK RESTRICT 核验；测试清理通过既有 clearSchemaRows 完成，不是应用写入口。未实现完整日投影或计算 Gap。

## Platform Evidence

| 平台 | 实际存储及重开证据 | 结果 |
| --- | --- | --- |
| 本机验证工具 | NativeDatabase 指向临时目录中的 `ledger.sqlite`；每次打开新 executor；重开前确认物理文件非空 | 一套完整场景通过，3 次打开 / 2 次重开 |
| Android | Android 13 API 33 x86_64 Medium_Phone；正式 connectDatabase / drift_flutter；PRAGMA database_list 三次报告同一非空物理路径 | 一套完整场景通过，3 次打开 / 2 次重开 |
| Web | Chromium / ChromeDriver 153.0.8010.52；正式 connectDatabase / WasmDatabase；同源同名存储，以新连接重开 | 同一套完整场景通过，3 次打开 / 2 次重开 |

Android 本次实际文件为 `/data/data/com.tokiya.time_pet_ledger/app_flutter/time_pet_ledger_full_test_1790519518146835.sqlite`，三次打开日志一致。该文件是唯一命名测试库，不是正式用户库。

Web 工厂只接受 opfsShared / opfsLocks / sharedIndexedDb，拒绝并关闭 inMemory / unsafeIndexedDb；测试调用该工厂，因此没有用内存回退冒充持久化。当前接口不返回 chosenImplementation，本次不声称确定使用了哪一种允许的浏览器后端。Web 测试通过的是实际允许的浏览器存储连接重开，不是本机 NativeDatabase 替代运行。

## Validation

沿用 Flutter 3.47.5 / Dart 3.13.4。以下均实际执行：

| 命令 | 结果 |
| --- | --- |
| `dart format integration_test/support/full_persistence_contract.dart integration_test/full_persistence_test.dart test/core/persistence/full_persistence_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed integration_test/support/full_persistence_contract.dart integration_test/full_persistence_test.dart test/core/persistence/full_persistence_test.dart` | 退出 0；3 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/core/persistence/full_persistence_test.dart` | 退出 0；1 套完整文件场景通过 |
| `flutter test --no-pub` | 退出 0；227 项通过 |
| `flutter test --no-pub integration_test/full_persistence_test.dart -d emulator-5554` | 退出 0；1 套完整 Android 场景通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/full_persistence_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0；同一套 Web 场景通过 |
| `git diff --check` | 退出 0 |

日志位于本次环境 `/tmp/e2_t08_analyze.log`、`/tmp/e2_t08_tests.log`、`/tmp/e2_t08_all_tests.log`、`/tmp/e2_t08_android.log`、`/tmp/e2_t08_web.log`；它们不是持久交付附件。Android 出现既有 JDK native-access 告警，未造成失败。没有跳过或未通过的本任务检查。

## Self-review / Repository Change Check

与执行前全部跟踪 / 未跟踪文件 SHA-256 快照比较，既有文件内容没有变化或删除；仅新增三个测试文件和本报告。E2-T06 / T07 的未提交改动保持原样。已检查所有新文件、格式、空白、报告链接、断言及任务边界。

未修改依赖、schema、生成代码、平台配置、生产实现、领域文档或前序报告。没有 UI、完整投影、草稿实现、持久化汇总或范围外平台支持。临时本机文件在测试后删除；平台测试清行并关闭，可能留下空测试库。本次启动的模拟器和 ChromeDriver 在收尾关闭。

## Limitations / Blockers / Next executable task

无本任务 blocker。实际验证边界是正常关闭数据库连接后重新打开，使用新 executor 和同一真实持久化存储；没有执行 Android 进程终止、整机重启、Web 刷新、浏览器关闭重启、崩溃 / 断电恢复、隐私模式或浏览器发布矩阵测试，不把本结果扩大为这些保证。Web 仍受浏览器存储配额、用户清理及部署条件约束，既有资产说明见 [PERSISTENCE_ASSETS](../../web/PERSISTENCE_ASSETS.md)。上述额外场景不属于本 Task 明确要求的连接重开验证。

E2-T01–E2-T08 的任务报告已齐备，本次补齐 Epic 2 五类正式数据的重开验收；这不表示 MVP 或发布验收完成。

当前 TASKS 后续仅有 Epic 3–10 待细化工作包，没有可直接执行的下一 Task ID。需在用户授权下先细化下一阶段任务。本次完成 E2-T08 后停止，不自动进入 Epic 3。
