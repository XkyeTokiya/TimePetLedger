# E2-T05 — 实现账本一致读取与行映射

**Status：COMPLETE**。日期：2026-09-27（Asia/Shanghai）。

## 前置与依据

用户明确指定 E2-T05，并在执行中要求继续。E1-T03、E1-T04、E1-T06 按[负责人确认记录](EPIC_0_1_COMPLETION.md)完成；[E2-T03](E2-T03_SCHEMA_REPORT.md) 五表已通过验收。核对 TASKS 完整定义与 Source Documents 索引、AGENTS、源提案的两类事实 / 可选解释 / 日窗口定义、相关 OPEN_QUESTIONS、MVP_SCOPE、PLAN / Epic 2、APP / LedgerRepository、DATA / 类型与查询一致性、DERIVED / Inputs。未发现阻塞本任务的未决产品合同。

按 AGENTS 委派 code_mapper 进行有界只读核查，主 agent 核对字段、枚举、现有 schema 与来源后完成实现、自检和验证。

## 修改文件与交付

本次全部为新增文件，既有文件保持原样。

| 文件 | 交付 |
| --- | --- |
| `lib/features/ledger/domain/ledger_repository.dart` | 小型只读 LedgerRepository 合同、不可变 LedgerSnapshot 输入集合、数据 / 存储错误类型 |
| `lib/features/ledger/data/drift_ledger_repository.dart` | 两类事实的半开相交查询、对应 annotation 查询；一个事务内查询并完成全部行映射 |
| `lib/features/ledger/data/ledger_mapping.dart` | 三类对象完整字段解析，固定代码到枚举映射，严格整数 / 文本校验，复用领域构造校验 |
| `test/features/ledger/data/ledger_read_test.dart` | 九项真实 SQLite 检查，含独立连接竞争和关闭连接失败 |
| `integration_test/ledger_read_test.dart`、`support/ledger_read_contract.dart` | Android / Web 共用的七组实际读取和事务检查 |
| 本报告 | 证据、限制及范围核对 |

## 行为与约束

- `readWindow(startedAt, endedAt)` 接收调用方明确提供的 UTC 毫秒窗口，不获取当前时刻或决定时区 / 自然日。反向窗口拒绝；空窗口无需查库，返回空集合。
- 非空窗口使用 `started_at < windowEnd AND ended_at > windowStart`，包含窗口外开始、跨午夜、包含整个窗口及部分相交的事实，排除仅端点相接的事实。
- 返回完整原始起止、独立起止精度、元数据及所有可选字段。未知内容是合法 TimeBlock；不因无目标、归档目标或没有解释而过滤事实。TimeBlock 与 SleepSession 分开返回，允许不同类型具有相同 id。
- annotation 仅关联本次选中的 TimeBlock；通过同窗口 JOIN 查询，不返回窗口外解释，也不生成 neutral。Q-005 中暂不适用的原因 / 恢复细节继续保留，不因当前 state 擦除。
- 非空读取的三条查询和全部映射处于同一事务。返回集合立即物化且不可修改；不会在事务结束后延迟查库或解析。
- 未知代码、错误物理类型、非法领域字段或未规范化文字使整次读取抛 LedgerDataException，不静默降级为 Unknown、不丢弃坏行、不自动修复。存储错误抛 LedgerStorageException，用户错误信息不展示原始 SQL。
- LedgerSnapshot 仅为一次读取的输入集合，不是持久化快照或 DayLedgerView。查询结果按起点 / id 稳定排列，不新增产品排序策略。

## Validation

沿用 Flutter 3.47.5 / Dart 3.13.4；Android 13 API 33 x86_64 Medium_Phone AVD；Chromium / ChromeDriver 153.0.8010.52。

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format lib/features/ledger/domain/ledger_repository.dart lib/features/ledger/data/ledger_mapping.dart lib/features/ledger/data/drift_ledger_repository.dart` | 退出 0 |
| `dart format integration_test/ledger_read_test.dart integration_test/support/ledger_read_contract.dart test/features/ledger/data/ledger_read_test.dart` | 退出 0 |
| `dart format --output=none --set-exit-if-changed lib/features/ledger/domain/ledger_repository.dart lib/features/ledger/data/ledger_mapping.dart lib/features/ledger/data/drift_ledger_repository.dart integration_test/ledger_read_test.dart integration_test/support/ledger_read_contract.dart test/features/ledger/data/ledger_read_test.dart` | 退出 0，6 文件、0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/features/ledger/data` | 退出 0，9 项通过 |
| `flutter test --no-pub` | 退出 0，全量 205 项通过 |
| `flutter test --no-pub integration_test/ledger_read_test.dart -d emulator-5554` | 退出 0，Android 七组通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/ledger_read_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0，Web 同一套七组通过 |
| `git diff --check` | 退出 0 |

七组平台检查覆盖完整跨日事实和所有可选字段、独立精度、两类同 id、半开相交的包含 / 被包含 / 部分相交 / 相接情况、空窗口与无匹配、窗口外解释排除、可选细节代码和 NULL、非法代码与物理类型，以及三次 SELECT 使用同一个真实 TransactionExecutor、成功提交和映射失败回滚。测试拦截器只观察 / 暂停真实执行，不伪造数据库结果。

独立连接一致性证据：在本机临时文件上打开两个独立 NativeDatabase；暂停读取连接的第一条事实 SELECT 后，第二连接尝试同事务修改 TimeBlock、SleepSession 和 annotation。SQLite 返回 busy，读取结果保持完整旧版本；释放读取事务后第二连接提交，再次读取全部为新版本。无需靠 sleep 猜测竞争时序。

合法夹具全部通过现有正式 schema 插入，不新增生产写入口。非法代码测试先创建合法记录，仅在独立测试库短暂启用 `ignore_check_constraints` 人工制造损坏，随后恢复 CHECK 再执行正式读取；始终保留 FK，未改动生产 schema / 约束。该步骤仅用于验证损坏数据不能静默降级，不代表应用允许非法写入。错误物理类型测试使用 SQLite 允许的异常值，验证映射层不会截断或隐式转为字符串。

首轮问题如实记录：测试导入 Drift 与 matcher 的 isNull 重名，限制导入后修复；静态分析发现一处测试 if 缺少大括号，补齐后分析及九项相关测试重跑通过。全量与平台测试在补大括号前已通过，该最后改动仅修复 lint，不改变测试逻辑。Android 构建有已有 JDK native-access / SDK XML 告警；双连接测试输出 Drift 多实例调试提醒，实际使用独立 executor，没有共享连接。

## Self-review / Repository Change Check

按执行前 SHA-256 快照比较全部跟踪及未跟踪文件，既有文件没有本任务造成的改动；新增文件仅限上表。检查覆盖新文件空白、报告链接及职责边界。

未修改 schema、连接生命周期、生成代码、pubspec / lockfile、平台配置、Goal 实现、旧文档或前序报告。没有写入 API、领域切片、Gap / 汇总计算、睡眠选择策略、UI 或持久化 DayLedgerView。

## Limitations / Blockers / Next executable task

无未解决 blocker。读取复用已采用 Drift 2.35 的 IMMEDIATE 事务：动作只执行 SELECT，但事务会短暂占用写事务资格；因此其他写入可能等待或返回 busy。本次没有切换驱动事务模式、添加自动重试或修改性能政策，失败向调用方明确报告。

本机双连接竞争已验证；Android / Web 验证真实事务归属、映射和错误传播，未声称完成跨进程 / 多标签页竞争或浏览器兼容矩阵。平台夹具使用唯一命名测试库，清理行并关闭后可能留下空测试库，不打开正式库；本次启动的 AVD / ChromeDriver 在收尾关闭。

Goal 元数据属于独立输入。睡眠摘要按醒来日期选择时可能需要窗口外睡眠，不能以本次相交结果代替；该选择不在 E2-T05 内实现。跨事实写入及不重叠保护仍属于 E2-T06，本任务不提供旁路。

完成 E2-T05 后停止。下一可执行任务为 **E2-T06 — 实现受控账本原子写入**，本次未执行。
