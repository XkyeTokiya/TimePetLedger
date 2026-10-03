# E2-T07 — 实现按日复盘存取

**Status：COMPLETE**。执行日期：2026-09-27（Asia/Shanghai）。本次仅执行 E2-T07。

## 前置与依据

用户明确授权执行 E2-T07。E1-T07 / E1-T12 按[负责人完成确认](EPIC_0_1_COMPLETION.md)承接；[E2-T03](E2-T03_SCHEMA_REPORT.md)、[E2-T04](E2-T04_GOAL_REPOSITORY_REPORT.md) 已完成。阅读 AGENTS、完整 Task 及 Source Documents 索引、源提案 §21–22 / §33、APP / ReviewRepository、DATA / daily_reviews、RULES / DR-001–004、STATES / DailyReview、MVP_SCOPE、PLAN / Epic 2 和相关 OPEN_QUESTIONS。Q-001、Q-006、Q-013、Q-015、Q-018 等合同已确定，无新增产品 blocker。

按 AGENTS 委派 code_mapper 只读定位现有复盘领域函数、schema 和 Goal 存取模式；主 agent 核对代码证据后实施。复用 `correctDailyReview`、`validateReviewGoalAssociation` 和 `TomorrowFirstStep`，没有另定领域行为。

## 修改文件与行为

| 新增文件 | 职责 |
| --- | --- |
| `lib/features/review/domain/review_repository.dart` | 按日读取、显式创建、按身份更正 / 删除；错误合同 |
| `lib/features/review/data/review_mapping.dart` | 八字段严格读写，CivilDate 文本编码与解析 |
| `lib/features/review/data/drift_review_repository.dart` | 事务内复核当前复盘、目标日期和 Goal 引用后保存 |
| `integration_test/support/review_repository_contract.dart` | 八组跨平台真实库合同检查 |
| `integration_test/review_repository_test.dart` | Android / Web 正式驱动运行共用检查 |
| `test/features/review/data/review_repository_test.dart` | 本机真实 SQLite 共用检查及关闭连接失败检查 |
| 本报告 | 验证与范围记录 |

- 按 CivilDate 精确读取，不存在返回 null。支持历史日期；日期不转 UTC 零点、不随设备时区改写。编码普通年份为 YYYY-MM-DD，同时保留现有 CivilDate 支持的其他年份，不增加产品日期范围限制。
- `intendedDate` 始终由复盘日期的下一自然日派生。改日期后重新派生；数据库仍只有既有八列，不存 intendedDate、派生统计或 Day 实体。
- 创建与编辑分开。同日已有其他复盘抛 `DailyReviewDateConflict` 并携带已有记录；重复身份创建拒绝，缺失对象编辑拒绝，不 upsert、不覆盖另一份复盘。
- 编辑保留 id / createdAt。省略可选字段表示保留，`(value: null)` 明确清空；规范化后无变化不执行 UPDATE，也不改变 updatedAt。下一步文本仍必填。时间由调用方注入，保留已有领域允许的时钟回拨语义。
- 写事务内读取并核验 Goal；新关联只能指向 active Goal，原有 archived 引用可保留。既有 FK RESTRICT 继续保护引用；通过 GoalRepository 删除有引用 Goal 会归档。
- 删除复盘幂等，不删除时间事实。存储失败整体回滚、抛 `ReviewStorageException`，成功结果只在提交后返回。坏类型、非法日期 / UUID、空必填或未规范化已存文本报 `ReviewDataException`，不静默修复。

## Validation

环境沿用 Flutter 3.47.5 / Dart 3.13.4、Android 13 API 33 x86_64 Medium_Phone、Chromium / ChromeDriver 153.0.8010.52。未安装依赖或工具。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/review/domain/review_repository.dart lib/features/review/data/review_mapping.dart lib/features/review/data/drift_review_repository.dart integration_test/support/review_repository_contract.dart integration_test/review_repository_test.dart test/features/review/data/review_repository_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同上六个文件） | 退出 0；6 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/features/review` | 退出 0；37 项通过 |
| `flutter test --no-pub` | 退出 0；226 项通过 |
| `flutter test --no-pub integration_test/review_repository_test.dart -d emulator-5554` | 退出 0；八组通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/review_repository_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0；同一套八组通过 |
| `git diff --check` | 退出 0 |

共用检查覆盖完整字段往返、可选内容、历史日期、闰日 / 跨年派生、日期迁移、同日重复与身份重复、缺失编辑、无变化请求、目标归档 / 恢复 / RESTRICT、幂等删除、同连接并发创建、真实存储故障及坏数据拒绝。真实库读回原始八列，确认不额外持久化 intendedDate 或统计。损坏日期及非法 Goal UUID 使用原始映射输入测试；错误物理类型及未规范化文本在独立真实测试库中注入，保持 FK 开启。

失败验证使用测试专用 AFTER INSERT / UPDATE / DELETE 触发器，在语句已开始修改后执行 RAISE(FAIL)，比较失败前后全部复盘列；插入失败后无残留行，编辑 / 删除失败保持原行。另用测试触发器在 UPDATE 后设置不存在的 Goal，触发真实 FK 约束失败并检查整体回滚。no-op 测试以拒绝 UPDATE 的触发器确认未发出更新。这些触发器不进入正式 schema。

首轮静态分析发现一处 `use_null_aware_elements` 提示，改用 null-aware collection element 后分析及测试全部通过。Android 构建有已有 JDK native-access / SDK XML 告警，不影响结果。日志位于本次环境 `/tmp/e2_t07_analyze.log`、`/tmp/e2_t07_tests.log`、`/tmp/e2_t07_all_tests.log`、`/tmp/e2_t07_android.log`、`/tmp/e2_t07_web.log`，不是持久交付附件。

## Self-review / Repository Change Check

按执行前 SHA-256 快照核对全部跟踪及未跟踪文件：没有改动或删除任何既有文件，仅新增上述六个 Dart 文件及本报告。E2-T06 的既有工作区改动保持原样。检查覆盖新文件内容、空白、报告链接、职责和任务范围。

未修改 schema / 版本、生成代码、pubspec / lockfile、平台配置、旧领域实现、连接生命周期、前序报告或产品文档。接口仍为纯 domain，数据层借用 app 管理的私有连接；未加入 UI、草稿、任务表、聚合快照、自动反思、通用框架或后续任务实现。

## Limitations / Blockers / Next executable task

无 blocker。使用现有 Drift 事务及错误传播；busy 不自动重试，调用方需要重试完整操作。并发测试验证同连接并行请求，不声称本任务验证了多标签页或跨进程竞争。读取只取单条完整复盘，不同时查询 Goal 元数据或派生统计。

平台测试使用独立命名测试库，清空行并关闭后可能留下空测试库；本次启动的模拟器及 ChromeDriver 在收尾关闭。跨关闭 / 重开与完整持久化边界验收由下一 Task 负责，本报告不代替该验收。

下一可执行任务：**E2-T08 — 验证存储重开与完整持久化边界**。完成 E2-T07 后停止，未执行 E2-T08。
