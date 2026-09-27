# E2-T03 — 建立五表首版 schema 与约束

**Status：COMPLETE**。执行日期：2026-09-27（Asia/Shanghai）。

## 前置、依据与范围

E0 / E1 按[负责人完成确认](EPIC_0_1_COMPLETION.md)承接，不重新索取历史证据。[E2-T02](E2-T02_PERSISTENCE_CONNECTION_REPORT.md) 已完成；用户明确要求继续 E2-T03。已核对 TASKS 完整定义与 Source Documents 索引、源提案、DOMAIN_MODEL、DOMAIN_RULES、OPEN_QUESTIONS、MVP_SCOPE、APP_ARCHITECTURE、DATA_ARCHITECTURE 和 IMPLEMENTATION_PLAN / Epic 2；Q-005、Q-007、Q-013、Q-019 等相关决定均已明确。

按 AGENTS 委派 code_mapper 进行有界只读勘查，主 agent 核对其引用的字段、时间类型、枚举、连接及测试证据后实施、验证和自检。采用已批准 Drift 方案；本任务未新增依赖、未修改 pubspec / lockfile。

## 交付与修改文件

| 文件 | 交付 |
| --- | --- |
| `lib/features/goals/data/goals_table.dart` | goals 六列；状态值域和 archived_at 联动，无名称唯一约束 |
| `lib/features/ledger/data/time_blocks_table.dart` | time_blocks 十二列；正区间、独立精度、已知性、显式 NULL 安全的 known 标题 CHECK；可空 Goal FK 和无 FK 的 category_id |
| `lib/features/ledger/data/rhythm_annotations_table.dart` | rhythm_annotations 十列；time_block_id 非空 UNIQUE FK，完整 Q-007 可选 TEXT 代码值域；保留跨状态细节 |
| `lib/features/ledger/data/sleep_sessions_table.dart` | sleep_sessions 九列；正区间、独立精度、mainSleep / nap，不按日期拆行或加日期唯一键 |
| `lib/features/review/data/daily_reviews_table.dart` | daily_reviews 八列；review_date 非空唯一、可空 Goal FK；不存 intendedDate 或统计 |
| `lib/core/persistence/app_database.dart`、`.g.dart` | 单库注册五表；schemaVersion 2；全新库及 E2-T02 空库的事务建表路径；拒绝未支持的版本变化 |
| `build.yaml` | 将 feature/data 建表文件加入 Drift 生成输入，维持 manager 禁用 |
| `test/core/persistence/app_database_test.dart` | 更新空库断言；外键不可开启的测试使用已建库，确保测试实际到达 beforeOpen |
| `test/features/persistence/schema_test.dart` | 7 组共享 schema 检查及 3 组版本 / 失败路径检查 |
| `integration_test/schema_test.dart`、`support/schema_contract.dart` | Android / Web 共用的七组真实 SQL 检查 |
| `docs/architecture/DATA_ARCHITECTURE.md`、本报告 | 记录外键更新动作、空库升级和验收结果 |

额外索引仅为规范中的四个：`idx_time_blocks_started_at`、`idx_time_blocks_goal_started_at`、`idx_sleep_sessions_started_at`、`idx_daily_reviews_first_step_goal`。PK 和两处 UNIQUE 自带索引，不重复建立。

## 约束与工程选择

- 外键逐连接开启并读回验证。两处 Goal 引用 `ON DELETE RESTRICT`；annotation 引用 `ON DELETE CASCADE`，只随其 TimeBlock 删除。三处显式 `ON UPDATE RESTRICT`，避免父身份改名自动传播；这是对保留实体身份合同的工程落实。
- 五表 id 都是显式非空文本主键；已定枚举以区分大小写的 TEXT CHECK 保存。恢复质量为 notRecovered / partlyRecovered / readyToContinue，非数值评分。
- known 标题使用 `title IS NOT NULL AND title <> ''`，避免 SQLite NULL CHECK 漏洞；unknown 可以保留标题、Goal 和解释。可选原因、方式、质量均允许 NULL；不加按当前节奏清空细节的约束或触发器。
- 时间列直接使用 INTEGER 毫秒，日期列使用 CivilDate 文本；没有使用 Drift 默认 DateTime 秒编码。Goal 状态与 archived_at 联动在数据库镜像，名称仍可重复。
- 版本 1 是 E2-T02 的空基础库。新库与 1 → 2 升级在事务内建立完整 schema；实际验证最后一个索引建失败时前面的建表被回滚，版本仍为 1，清除故障后可重试。拒绝未支持的版本变更，不迁移历史 V3 / V3.5 模型。

## Validation

环境沿用现有 Flutter 3.47.5 / Dart 3.13.4、Android 13 API 33 x86_64 Medium_Phone AVD、Chromium / ChromeDriver 153.0.8010.52。未新增平台。

| 实际命令 | 最终结果 |
| --- | --- |
| `dart run build_runner build` | 退出 0，五表代码生成成功，无最终生成告警 |
| `dart format --output=none --set-exit-if-changed lib/features/goals/data lib/features/ledger/data lib/features/review/data lib/core/persistence/app_database.dart lib/core/persistence/app_database.g.dart test/core/persistence/app_database_test.dart test/features/persistence integration_test/schema_test.dart integration_test/support/schema_contract.dart` | 退出 0，11 个文件，0 changed；此前已格式化本次编辑文件 |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/persistence test/core/persistence test/app/bootstrap` | 退出 0，18 项通过 |
| `flutter test --no-pub` | 退出 0，186 项通过 |
| `flutter test --no-pub integration_test/schema_test.dart -d emulator-5554` | 退出 0，Android 七组真实 schema 检查通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/schema_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0，Web 同一套七组检查通过 |
| `git diff --check` | 退出 0 |

Web 测试前启动 `chromedriver --port=4444 --allowed-ips=127.0.0.1`；Android 使用已有 AVD。本次启动的测试后台进程在收尾关闭。

七组共享检查直接执行参数化 SQL，绕过 Dart 写入验证；拒绝结果核验 SQLite constraint failure，而不是把任意异常都当约束通过。覆盖：五表完整列、类型、nullable、无隐含默认值、主键、四个索引键；合法五类插入与毫秒读回；每个必需列的省略和 NULL；非法 / 大写代码及全部合法代码；known 的 NULL / 空串；两类非正区间；孤立、重复 annotation；重复复盘日期及冲突更新；Goal 删除与更新限制；annotation 级联和反向删除隔离；同名 Goal、可空细节、unknown 保留字段及节奏切换保留细节。

首轮问题与处理：原 build.yaml 仅包含数据库入口，生成器不能识别新增表，补充 feature/data 输入后消除告警；原外键失败夹具在未建表库内预开事务，被新增建表事务提前拒绝，改用真实已建库后恢复对外键开启失败的针对性验证。修复后的结果才记为通过。

非失败输出：首次分析时 Flutter 的版本检查 `git fetch --tags` 遇到 TLS 错误，静态分析本身通过，最终重跑也通过；Android 构建有已有 JDK native-access / SDK XML 版本告警；隔离连接测试仍有 Drift 多实例调试告警，使用不同 executor，不共享连接。未全局抑制告警。

## Self-review / Repository Change Check

执行前保存 116 个仓库文件的 SHA-256。最终按文件内容对比：既有文件仅变更 build.yaml、app_database.dart / .g.dart、连接测试和 DATA_ARCHITECTURE；其余为上表列出的新文件。原有 DOMAIN_RULES、OPEN_QUESTIONS、domain 实现 / 测试、E0 / E1 确认、E2-T01 / T02 报告、pubspec / lockfile、Web 驱动资产与其他平台文件均保持原样。审阅包含未跟踪的新文件及生成代码，不以 git diff 忽略未跟踪文件。

无 Day / Gap / 聚合表、Category 实体、默认级联、额外业务状态、触发器或通用 repository 框架。

## Limitations / Blockers / Next executable task

本任务无未解决 blocker。schema 不能代替 Domain / Application：Unicode 空白清理、长度、UUID / 日历解析、禁止新增归档目标关联、实体内容更新语义以及跨两类事实的不重叠与原子保存，仍由既定领域合同及后续 repository 任务落实。本任务不将直接 SQL 插入能力视为可上线的业务保存接口。

新库约束已在 Android / Web 验证；1 → 2 升级、DDL 失败回滚及文件重开在本机真实 SQLite 验证，未声称两个平台均已完成升级安装、杀进程重启或完整浏览器兼容矩阵。平台夹具仅使用唯一命名的专用测试库，不打开正式库；清除测试行并关闭连接后可能留下空测试库。五类事实的完整重启读回验收仍属于 E2-T08。

完成 E2-T03 后停止。下一可执行任务为 **E2-T04 — 实现 Goal 存取边界**，本次未执行。
