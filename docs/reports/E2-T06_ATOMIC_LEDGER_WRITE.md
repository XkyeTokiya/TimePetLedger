# E2-T06 — 实现受控账本原子写入

## Task / Status

完成 E2-T06，2026-09-27。仅执行本 Task；E2-T07 未开始。

前置依据：E0 / E1 完成确认见 [EPIC_0_1_COMPLETION](EPIC_0_1_COMPLETION.md)，E2-T04 / T05 已有实现及报告；Q-011、Q-013 均为 DECIDED。已按 AGENTS 重读任务、源提案、相关领域合同及架构事务章节，并检查既有实现。委派 code_mapper 只读定位更正、解释操作和冲突判定函数，主 agent 核对后复用。没有缺失产品决定或文档冲突。

## Changes / Rule Evidence

| 文件 | 职责 |
| --- | --- |
| `lib/features/ledger/domain/ledger_repository.dart` | 创建、更正、删除两类事实的受控合同；组合返回及明确错误 |
| `lib/features/ledger/domain/annotation_change.dart` | 解释的 Keep / Add / Edit / Remove 显式意图 |
| `lib/features/ledger/data/drift_ledger_repository.dart` | 同事务读取、复核、写入和回滚 |
| `lib/features/ledger/data/ledger_mapping.dart` | 固定存储代码及全字段写映射 |
| `integration_test/support/ledger_write_contract.dart` | 共用真实库行为、故障注入及事务观察检查 |
| `integration_test/ledger_write_test.dart` | Android / Web 正式驱动运行共用检查 |
| `test/features/ledger/data/ledger_write_test.dart` | 本机真实 SQLite 检查及独立连接竞争 |
| 本报告 | 结果与验证记录 |

依据 [RH-001、LEDGER-004](../domain/DOMAIN_RULES.md)、[Q-004 / Q-005 / Q-006 / Q-011 / Q-013 / Q-018](../domain/OPEN_QUESTIONS.md) 及 [DATA 事务合同](../architecture/DATA_ARCHITECTURE.md)：

- 全部写入口取得 Drift IMMEDIATE 事务后读取当前事实、解释和必要 Goal 引用；创建 / 更正读取两张事实表的相交候选，调用已有领域判定后写入。更正只排除同类型同 id，另一类型同 id 仍参与冲突检查。相接允许，approximate 不豁免冲突。
- TimeBlock 与可选解释整体提交；更正复用已有领域函数，保持身份、createdAt、独立精度及未被明确更改的字段。解释默认保留，添加、编辑、移除显式区分；没有独立解释写入旁路或 upsert。返回只发生在提交成功后，调用方可重读投影。
- 新 Goal 关联要求 active，已有关联允许归档 Goal。读取并复核发生在保存事务内。重复创建、缺失编辑及解释 add/edit 状态不符明确失败；重复删除幂等成功。删除 TimeBlock 通过已有 FK cascade 删除解释，复盘保持原样。
- 冲突返回完整冲突身份及区间，不截断、拆分、覆盖或移动事实；数据库失败作为 LedgerStorageException 返回，用户错误文本不直接展示 SQL。全部组合失败整体回滚。

## Validation

环境沿用 Flutter 3.47.5 / Dart 3.13.4；Android 13 API 33 x86_64 Medium_Phone；Chromium / ChromeDriver 153.0.8010.52。未安装依赖。

| 实际命令 | 结果 |
| --- | --- |
| `dart format`（上述 7 个 Dart 文件） | 已格式化 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/domain/annotation_change.dart lib/features/ledger/domain/ledger_repository.dart lib/features/ledger/data/ledger_mapping.dart lib/features/ledger/data/drift_ledger_repository.dart integration_test/ledger_write_test.dart integration_test/support/ledger_write_contract.dart test/features/ledger/data/ledger_write_test.dart` | 退出 0；7 文件，0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/features/ledger/data` | 退出 0；21 项通过 |
| `flutter test --no-pub` | 退出 0；217 项通过 |
| `flutter test --no-pub integration_test/ledger_write_test.dart -d emulator-5554` | 退出 0；11 组通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/ledger_write_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0；同一套 11 组通过 |
| `git diff --check` | 退出 0 |

平台共用检查覆盖字段往返、四种事实组合冲突与相接、同 id 不同类型、自排除、显式解释操作与 no-op、Goal 关联、重复与缺失操作、删除级联、唯一约束失败、组合中途失败及并发冲突。失败前后比较五张正式表，确保原数据不变。no-op 测试以拒绝 UPDATE 的测试触发器证明没有重写元数据。

故障注入在独立测试库使用临时创建的 SQLite 触发器，在解释 INSERT / UPDATE / DELETE 或睡眠 UPDATE 时抛错，验证前面的事实变更、解释变更或级联删除均回滚。触发器仅属于测试，不加入正式 schema。真实执行拦截器确认两表候选读取和组合插入共用一个 TransactionExecutor，并在读取之后写入；没有 mock 数据库结果。

本机另用两个独立 NativeDatabase 连接同一临时文件：暂停第一连接两表读取完成后的写事务，第二连接写入收到 busy；第一连接提交后，第二连接重试重新查到冲突并拒绝。平台共用并发测试使用同一连接同时提交冲突请求，只允许一个事实落库。

日志保存在本次环境 `/tmp/e2_t06_ledger_tests.log`、`/tmp/e2_t06_all_tests.log`、`/tmp/e2_t06_analyze.log`、`/tmp/e2_t06_android.log`、`/tmp/e2_t06_web.log`，非持久交付附件。Android 输出既有 JDK native-access / SDK XML 告警；独立连接测试输出 Drift 多实例调试提醒，实际使用不同 executor。均未造成验证失败。

## Self-review / Repository Change Check

核对执行前 SHA-256 快照，已有文件仅修改上表前三个对应文件（repository、mapping、Drift implementation），新增其余四个 Dart 文件及本报告；无删除。已检查 diff、新文件、任务范围及文档相对链接。未修改 pubspec / lockfile、schema、生成代码、平台配置、连接生命周期、Goal 实现或前序报告。

纯 domain 接口不依赖数据库 / Flutter / 全局当前时间。连接仍为 data 私有字段；无 UI、通用 repository 框架、自动重试、额外平台或派生事实持久化。保留执行前文件状态；测试启动的模拟器与 ChromeDriver 在收尾关闭。

## Limitations / Blockers / Open Questions

无 blocker。原子重叠保护依赖所有应用事实写入通过 LedgerRepository，任意绕过 repository 的原始 SQL 不受保护，符合当前架构合同。busy 明确失败，不自动重试；调用方重试须重新执行完整操作。

Android / Web 验证正式驱动的事务、回滚及同连接并发；独立连接竞争证据来自本机 SQLite，不声称已完成 Web 多标签页、跨进程竞争、浏览器兼容矩阵或崩溃恢复验证。测试使用独立命名数据库，清行并关闭后可能留下空测试库。

## Next executable task

**E2-T07 — 实现按日复盘存取**。本次完成 E2-T06 后停止，未执行后续任务。
