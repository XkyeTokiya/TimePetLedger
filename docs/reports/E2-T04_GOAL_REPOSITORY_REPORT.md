# E2-T04 — 实现 Goal 存取边界

**Status：COMPLETE**。日期：2026-09-27（Asia/Shanghai）。

## 依据与前置

用户明确授权继续 E2-T04。E1-T05、E1-T09 按[负责人 E0 / E1 完成记录](EPIC_0_1_COMPLETION.md)承接；[E2-T03](E2-T03_SCHEMA_REPORT.md) 已完成。核对 TASKS 完整定义与 Source Documents 索引、Source of Truth / Goal、OPEN_QUESTIONS（重点 Q-006、Q-015、Q-018、Q-019）、MVP_SCOPE、IMPLEMENTATION_PLAN / Epic 2、APP / GoalRepository、DATA / goals 与引用行为、RULES / GO、STATES / Goal；无新增产品未决项。

按 AGENTS 委派 code_mapper 有界只读核查现有 Goal、生命周期测试及存储入口；主 agent 核对证据、决定小型接口、实施并验证。E0 / E1 不因缺少历史日志重新阻塞。

## 文件与行为

| 文件 | 改动 |
| --- | --- |
| `lib/features/goals/domain/goal.dart` | 增加获准 rename 操作，复用名称规范化；名称规范化后未变则返回原对象，不更新时间；保留身份、创建时间、状态与归档时间 |
| `lib/features/goals/domain/goal_repository.dart` | 小型 GoalRepository 接口；读取、创建、改名、归档、恢复、按引用删除；明确缺失、重复身份、数据错误及存储失败，不暴露驱动类型 |
| `lib/features/goals/data/goal_mapping.dart` | 六字段显式读写；状态代码严格解析；核验整数 / 文本类型、UUID、名称及状态联动，不静默修复脏数据 |
| `lib/features/goals/data/drift_goal_repository.dart` | 借用 app 已持有的连接；修改前在写事务内读取当前 Goal；引用查询与归档 / 删除同事务；成功提交才返回成功 |
| `test/features/goals/data/goal_repository_test.dart` | 七组共享真实 SQLite 检查，以及文件重开、未知状态映射、关闭连接失败检查 |
| `integration_test/goal_repository_test.dart`、`support/goal_repository_contract.dart` | Android / Web 共用的七组存取、约束、引用保护与故障回滚检查 |
| 本报告 | 验收、限制和仓库检查记录 |

## 合同落实

- `listActive` 只提供 active 目标，供普通目标选择；`findById` 支持历史引用与恢复所需的 archived 读回。列表使用 id 排序以稳定输出，不将此工程顺序定义为产品排序要求。
- 创建只能为 active；身份由调用方传入并校验 UUID v4，不提供任意 save / upsert。重复身份明确拒绝，不覆盖已有对象；同名不同身份合法。
- 改名使用领域 trim、非空及最多 200 Unicode 码点规则，保留内部格式。归档写入调用方提供的毫秒时间，恢复清除 archivedAt；真实变更更新 updatedAt，创建时间保持不变。重复状态与规范化后相同名称完全不发出 UPDATE。时钟回拨不擅自修正。
- delete 在 Drift 写事务内读取当前对象及 TimeBlock / DailyReview 两类引用。有任一种引用即归档，保留全部引用及事实；无引用才物理删除。结果区分 deleted、archived、notFound；missing 更正抛明确异常，不重建对象。结果类型属于接口工程表达，没有新增领域状态。
- 失败经事务回滚后抛 GoalStorageException，诊断原因保留，面向调用方的异常文案不直接输出 SQL。已存字段非法抛 GoalDataException，不把未知状态降级为 active 或修改原数据。
- 普通列表隐藏 archived，历史关联仍按同一身份读到现名；不保存名称快照，不改写 TimeBlock 或复盘。

## Validation

沿用既有 Flutter 3.47.5 / Dart 3.13.4；Android 13 API 33 x86_64 Medium_Phone AVD；Chromium / ChromeDriver 153.0.8010.52。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/features/goals/domain/goal.dart lib/features/goals/domain/goal_repository.dart lib/features/goals/data/goal_mapping.dart lib/features/goals/data/drift_goal_repository.dart` | 退出 0 |
| `dart format integration_test/goal_repository_test.dart integration_test/support/goal_repository_contract.dart test/features/goals/data/goal_repository_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed lib/features/goals/domain/goal.dart lib/features/goals/domain/goal_repository.dart lib/features/goals/data/goal_mapping.dart lib/features/goals/data/drift_goal_repository.dart integration_test/goal_repository_test.dart integration_test/support/goal_repository_contract.dart test/features/goals/data/goal_repository_test.dart` | 退出 0，7 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/goals` | 退出 0，28 项通过（含 10 项新增存取测试） |
| `flutter test --no-pub` | 退出 0，全量 196 项通过 |
| `flutter test --no-pub integration_test/goal_repository_test.dart -d emulator-5554` | 退出 0，Android 七组真实驱动测试通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/goal_repository_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0，Web 同一套七组测试通过 |
| `git diff --check` | 退出 0 |

七组测试覆盖读写往返、重复身份拒绝、同名允许、名称空白 / 200 码点边界、归档改名与恢复、重复请求不执行 UPDATE、两类引用分别及同时存在时的删除保护、缺失对象、真实写入失败后的回滚、并发改名与归档、非法持久化类型的显式拒绝。文件重开额外验证六字段无损保留；未知状态解析直接在映射边界验证，不关闭数据库 CHECK 或外键。

故障测试仅在专用测试库创建 TEMP TRIGGER，以 AFTER INSERT / UPDATE / DELETE + RAISE(FAIL) 在语句已修改数据后制造错误，验证 repository 的外层事务撤销实际变化。测试没有关闭外键、绕过引用保护或添加生产触发器。失败后逐字段核验 Goal 与历史事实保持原样，并验证后续重试成功。

所有检查首轮通过。Android 构建出现已有 JDK native-access / SDK XML 版本告警，未影响构建和测试；全量隔离连接测试仍可能输出 Drift 多实例调试提示，不共享 executor。本次启动的 AVD / ChromeDriver 在收尾关闭。

## Self-review / Repository Change Check

执行前保存仓库文件 SHA-256；最终核对本次既有文件仅 `lib/features/goals/domain/goal.dart` 变化，其余新增文件限于上表。未改动其他领域实现、五表 schema / 生成代码、数据库连接、app、平台文件、pubspec / lockfile、既有文档和任务报告。检查涵盖未跟踪文件，不仅依赖 git diff。

无目标 UI、任务管理、通用 repository / use-case 框架、外部依赖、自动重试或后续账本 / 复盘存取实现。

## Limitations / Blockers / Next executable task

无未解决 blocker。GoalRepository 不负责新增 TimeBlock / DailyReview 关联；归档目标不得新增关联的已有领域规则，将由对应后续写入任务在事务内复核。本任务没有把 active 列表筛选当作完整关联保护，也未提前执行 E2-T06 / E2-T07。

并发测试覆盖同一真实数据库连接上的并发请求；未声称验证多进程 / 多浏览器标签页竞争。Android / Web 运行七组 repository 检查；文件关闭重开在本机真实 SQLite 验证，不等同于全部平台杀进程重启验收。平台测试使用唯一命名的专用测试库，清理业务行并关闭后可能保留空测试库，不接触正式库。

完成 E2-T04 后停止。下一可执行任务为 **E2-T05 — 实现账本一致读取与行映射**，本次未执行。
