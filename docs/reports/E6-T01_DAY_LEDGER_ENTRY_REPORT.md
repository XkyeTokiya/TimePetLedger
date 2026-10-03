# E6-T01 — 接通日账本页面的日期选择与读取状态

**Task / Status：E6-T01 / COMPLETE。** 日期：2026-09-30。

## 依据与依赖

已阅读 AGENTS、完整 Task、SOT、OQ、MVP、PLAN，并核对 APP / 调用流程与 UI state、DATA / 读取一致性、DERIVED / DayLedgerView。Q-008、Q-009 为 DECIDED，当前设备时区、显式 now、历史整日 / 今天截至 now / 未来空窗口的合同一致，没有新产品阻塞。

核对归档完整定义、COMPLETE 报告及现有实现：E4-T01 的 RecordingDateContext / 设备日期适配 / readWindow；E5-T01 的 readSleepContext / 完整醒来日候选与一致读取；E3-T06 的 projectDayLedgerView / 组合测试。记录入口的局部投影不冒充完整日账本。按 AGENTS 委派 code_mapper 做有界只读定位，主 agent 检查证据并负责实现、集成及验证。

## Changes

| 文件 | 修改 |
| --- | --- |
| [day_ledger_loader.dart](../../lib/features/ledger/application/day_ledger_loader.dart) | 正式读取输入及 application loader，每次重新解析日期上下文，直接调用已有 projectDayLedgerView |
| [day_ledger.dart](../../lib/app/bootstrap/day_ledger.dart) | 在 app 管理的数据库外层读取事务中复用 readSleepContext 和 Goal findById，包含归档目标 |
| [day_ledger_controller.dart](../../lib/features/ledger/presentation/day_ledger_controller.dart) | 选择日期、loading / empty / ready / failed；请求序号淘汰旧成功与旧失败；销毁和非法输入使请求失效 |
| [day_ledger_page.dart](../../lib/features/ledger/presentation/day_ledger_page.dart) | 日期输入、今天、刷新、失败重试；返回路由与恢复前台重取时间上下文 |
| [main_app.dart](../../lib/app/main_app.dart)、[app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 注入完整 loader，新增“打开日账本”入口；app 持有自己的 RouteObserver |
| [day_ledger_loader_test.dart](../../test/features/ledger/application/day_ledger_loader_test.dart) | 真实 SQLite、外层读取事务、双连接竞争、日期窗口、23 / 25 小时与设备时区 |
| [day_ledger_controller_test.dart](../../test/features/ledger/presentation/day_ledger_controller_test.dart) | 失败重试、快速切日、旧成功 / 失败、失效 / 销毁、跨零点及改变时区适配上下文 |
| [day_ledger_page_test.dart](../../test/features/ledger/presentation/day_ledger_page_test.dart) | 加载 / 空 / 失败文案、重试、快速切日、非法日期、返回路由、恢复前台、刷新与今天 |
| [day_ledger_entry_test.dart](../../test/app/day_ledger_entry_test.dart) | app 真实库入口、跨零点、草稿隔离与保留、午夜醒来摘要独有数据的 ready 状态、原始睡眠事实不变 |
| TASKS、COMPLETED_TASKS、本报告 | 完成状态、归档及验收证据 |

同一次加载在 I/O 前取得完整日界、日期关系和显式 now，正式事实、解释、完整睡眠候选和被引用目标来自同一个外层事务；已有 readSleepContext 内部事务为嵌套事务，Goal 查询仍受外层事务保护。缺失 / 非法数据或读取失败不降级为空集合。未来和零点 W 为空也读取完整睡眠候选，从而暴露存储失败。

“今天”跟随当前设备日期；明确日期保留用户选择，刷新时重新计算该日期在当前设备时区下的日界和关系。快速切换、刷新、非法输入及销毁都会使旧请求失效。失败提示不显示数据库诊断原文。empty 按窗口切片和独立完整睡眠摘要均无记录判断，不根据 Gap、舍入零或只有零窗口判空；空文案明确指当前账本窗口。

没有复制投影算法、修改正式事实、schema、依赖、时区设置或统计页面；E6-T02 的事实 / Gap 时间轴及后续补记、编辑路由未实施。

## Validation

使用仓库已有 SDK / 缓存依赖；未安装或更新工具与依赖。

| 实际命令 | 结果 |
| --- | --- |
| `dart format` 本轮 10 个 Dart 文件 | 退出 0 |
| `dart format --output=none --set-exit-if-changed` 相同清单 | 退出 0，0 changed |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=America/New_York flutter test --no-pub test/features/ledger/application/day_ledger_loader_test.dart test/features/ledger/presentation/day_ledger_controller_test.dart test/features/ledger/presentation/day_ledger_page_test.dart` | 退出 0，8 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/app test/core/time` | 退出 0，388 项通过，1 项纽约定向测试跳过；该时区覆盖已在纽约命令执行 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/day_ledger_page_test.dart test/app/day_ledger_entry_test.dart test/app/bootstrap/app_bootstrap_test.dart` | 收尾日期入口 / 空文案调整后退出 0，10 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_ledger_entry_test.dart` | 新增午夜摘要独有 ready 断言后退出 0，1 项通过 |
| `git diff --check`、基线 SHA-256 对照与归档链接核验 | 通过，见 Self-review |

首轮存在构造器接线 / 测试编译问题、测试生命周期跳转不合法，以及错误地要求嵌套事务 executor 与外层 executor 是同一对象、错误地将 StateError 当作 Exception。已修正并重跑；不将初次失败计为通过。双连接真实文件测试验证外层事务在 Goal 读取时仍保护整份快照，未用 executor 身份代替一致性证明。两连接测试会输出 Drift 有意打开多个数据库实例的 debug 提示。

验收证据：

- 真实库加载归档 Goal、跨日睡眠、普通事实和解释，调用已有组合入口得到同窗口结果；检查原始起止、精度和持久化行不变。
- 两个独立文件连接：暂停 Goal SELECT 后尝试一起修改 Goal / TimeBlock / SleepSession / annotation，SQLite busy 拒绝；释放读取后提交，重读取得所有新值，旧结果不变。
- 历史整日、今天截至 now、未来无 Gap、今天零点；关闭库后即使空 W 也失败。
- controller / widget 覆盖快速切日时旧成功及旧失败、读取失败重试、无数据与失败区别、非法日期及销毁期间响应。
- 路由返回、恢复前台、刷新重新读取；今天跨零点跟随新日期，明确历史日期保持选择；注入时区变化重新取得日界，真实纽约 / 上海进程验证设备时区、23 / 25 小时日。
- app 组装真实库测试：已保存本机输入草稿保留且不计为正式记录；午夜醒来不与 W 相交仍进入完整摘要，不能显示为空数据。

日志：`/tmp/e6_t01_analyze.log`、`/tmp/e6_t01_tests_ny.log`、`/tmp/e6_t01_tests_shanghai.log`、`/tmp/e6_t01_final_tests.log`、`/tmp/e6_t01_entry_test.log`。

## Self-review

检查全部新增生产 / 测试文件、app 增量、日期上下文、请求淘汰、路由生命周期、事务边界、完整摘要、源事实、错误文案与依赖方向。开始前记录既有文件 SHA-256；实现结束时仅 main_app 和 app_bootstrap 两个既有代码文件改变，其余已有生产 / 测试 / 集成文件及领域、架构、PLAN、pubspec / lockfile 均保持原样。文档收尾仅更新 TASKS / COMPLETED_TASKS 并新增本报告，保留原有工作区改动与未跟踪文件。格式化仅针对本轮文件。

## Blockers / Open Questions

无阻塞，无新增未决问题。没有重新执行 Android / Web 设备端到端或运行中真实系统时区切换；本轮证据为本机 Flutter controller / widget、真实 Native SQLite、两个 TZ 进程及注入时区变化，不外推为平台集成通过。平台闭环仍属 E6-T06。

## Next executable task

E6-T02 — 呈现事实切片与派生 Gap 时间轴，依赖 E6-T01、E3-T07 及已决定的 Q-014 / Q-017 / Q-021。本次完成 E6-T01 后停止，未执行 E6-T02，未将 Epic 6 标记为完成。
