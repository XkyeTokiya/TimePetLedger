# E4-T04 — 实现活动优先表单与草稿生命周期

**Status：COMPLETE。** 执行日期：2026-09-28。

## 前置与依据

前置 [E4-T02](E4-T02_TIME_SUGGESTION_REPORT.md)、[E4-T03](E4-T03_RECORDING_DRAFT_STORE_REPORT.md) 已完成，实际建议结果、时间输入、草稿合同与独立连接均已核对。遵循 AGENTS 和 TASKS / E4-T04，依据 Source of Truth §7、§26–28，DOMAIN_RULES / TB、MODEL-002、LEDGER-010、Q-023 决策表，DOMAIN_MODEL / UI Models，以及已决定的 Q-012、Q-015、Q-017、Q-023；沿用当前已核对的 MVP / PLAN 边界。没有产品阻塞或扩大实施范围。

按 AGENTS 委派 code_mapper 只读定位启动链路、前置接口和测试；主 agent 核查实际代码、实现和验证。

## Changes

| 文件 | 修改 |
| --- | --- |
| [recording_form.dart](../../lib/features/ledger/presentation/recording_form.dart) | 新增活动优先表单、分钟级跨日期时间编辑、独立精度、候选确认、草稿状态与反馈 |
| [recording_form_controller.dart](../../lib/features/ledger/presentation/recording_form_controller.dart) | 新增页面输入状态、恢复优先、串行自动保存、离开等待与主动放弃 |
| [main_app.dart](../../lib/app/main_app.dart) | 将占位首页替换为查看日期与“补一笔”入口，注入正式读取、草稿存储和 now |
| [app_bootstrap.dart](../../lib/app/bootstrap/app_bootstrap.dart) | 管理正式库及独立草稿库的打开 / 关闭、失败和迟到连接释放 |
| [recording_form_test.dart](../../test/features/ledger/presentation/recording_form_test.dart) | 表单 widget 和日期解析测试 |
| [recording_form_controller_test.dart](../../test/features/ledger/presentation/recording_form_controller_test.dart) | 恢复、顺序写入、失败重试和校验测试 |
| [recording_form_storage_test.dart](../../test/features/ledger/presentation/recording_form_storage_test.dart) | Controller→真实文件草稿库，关闭重开与正式五表不变验证 |
| [app_bootstrap_test.dart](../../test/app/bootstrap/app_bootstrap_test.dart) | 调整首页断言，验证真实入口、两库释放及草稿打开失败 / 延迟完成 |
| [TASKS.md](../../TASKS.md#e4-t04--实现活动优先表单与草稿生命周期)、本报告 | 仅追加本任务完成状态和验收证据 |

## 行为与规则

- 首页默认设备当前日期，也可输入其他自然日期；“补一笔”进入表单。浏览日期直接验证 CivilDate，不通过当地零点是否存在判断日历日期合法性。
- 活动输入在表单首位；用户明确选择“记得做了什么”或“想不起来”，不自动 Unknown。known 标题去首尾空白后非空，最多 200 个 Unicode 码点；Unknown 不要求标题，非空标题同样按长度提示。草稿保留原始文本，不在输入时删掉空白或截断。
- 复用 E4-T02 的直接建议、候选和手填。单候选仍由用户点击确认，全部建议均可编辑。新输入默认两端 approximate，明确切换精度后修改时间仍保留该端精度。
- 开始和结束可分别选择跨日期的当地分钟值，支持清空单端；无今天、历史年数或未来日期的业务上限。时间选择对话框确认后才应用到表单，取消不改变原值；无效日期 / 分钟不自动进位。端点不完整或非正区间有提示，但仍可保留草稿。
- 先读草稿，存在则恢复原输入并跳过新建议，避免被新的 now 或 Gap 覆盖。读取失败时禁用输入并提供重试，不用空输入覆盖已有草稿。首次直接建议作为草稿保留，候选不自动选择。
- 每次输入变化写入完整草稿快照；写入串行，避免旧值后完成覆盖新值。离开按钮和系统返回等待已排队写入，成功离开不清除。保存失败留在页内保留输入，显示重试；不展示 SQL 原文。
- 主动放弃先停止编辑、等写入结束，再清除对应草稿，避免清除后旧写入重建草稿。清除失败不离开、不丢输入，允许再次操作。
- 本 Task 提供“保留草稿并返回”，明确说明输入尚未计入账本。没有正式提交按钮或保存成功提示；E4-T05 才接正式新建、冲突、提交后清草稿和刷新。无 Goal / 分类 / annotation / 备注入口。

## Validation

以下命令由本 agent 在仓库根目录执行，没有安装依赖或修改 lockfile。

| 实际命令 | 结果 |
| --- | --- |
| `dart format lib/app/main_app.dart lib/app/bootstrap/app_bootstrap.dart lib/features/ledger/presentation/recording_form.dart lib/features/ledger/presentation/recording_form_controller.dart test/app/bootstrap/app_bootstrap_test.dart` | 退出 0；生产与启动测试格式化 |
| `dart format test/features/ledger/presentation/recording_form_test.dart test/features/ledger/presentation/recording_form_controller_test.dart test/features/ledger/presentation/recording_form_storage_test.dart` | 对应新增测试分批执行并在修改后格式化，均退出 0 |
| `dart format --output=none --set-exit-if-changed lib/app/main_app.dart lib/app/bootstrap/app_bootstrap.dart lib/features/ledger/presentation/recording_form.dart lib/features/ledger/presentation/recording_form_controller.dart test/app/bootstrap/app_bootstrap_test.dart test/features/ledger/presentation/recording_form_test.dart test/features/ledger/presentation/recording_form_controller_test.dart test/features/ledger/presentation/recording_form_storage_test.dart` | 退出 0；8 文件、0 changed |
| `flutter analyze --no-pub` | 最终退出 0；No issues found |
| `flutter test --no-pub test/features/ledger/presentation test/app/bootstrap test/features/ledger/application test/features/ledger/data/recording_draft_store_test.dart` | 退出 0；47 项全部通过 |
| `flutter test --no-pub test/features/ledger/presentation/recording_form_test.dart test/app/bootstrap` | 最终日期处理修正 / 新增日期测试后退出 0；12 项全部通过 |
| `git diff --check` | 退出 0 |
| 执行前既有跟踪 / 未跟踪文件 SHA-256 对照 | 除上述 3 个既有代码 / 测试文件及收尾 TASKS 状态外，全部原有内容保留 |

本轮新增 15 项测试：controller 5 项、表单 widget 5 项及日期解析 2 项、真实存储 1 项、启动错误 / 迟到连接 2 项；已有启动测试增强真实入口和两库关闭检查。最终相关集合共 48 项，由 47 项回归与最后受影响集合重跑覆盖，未声称运行过单条“48 项全量”命令。

首轮记录：两项 widget 测试未等滚动布局完成便点击屏幕外按钮；修正测试中的滚动等待和文本可见性后通过。静态分析先后发现两处 if 括号和一处多余插值括号，均修正并重跑。失败不记为通过。日志保留在本机 `/tmp/e4_t04_final_tests.log`、`/tmp/e4_t04_last_tests.log`。

### 验收证据

1. Widget 验证活动位置先于时间；无 Goal 即可输入，空白 known 标题提示错误，明确 Unknown 可无标题。
2. 跨日期分钟输入覆盖 2000 年开始、2040 年结束；修改开始时间保留准确开始 / 大约结束的混合精度；无固定回溯或未来限制。
3. 单候选初始不预填，点击后可编辑；普通手填入口两端为空。前置建议分支随 application 测试回归。
4. 输入半成品离开后重新打开恢复，新的直接建议不能覆盖；主动放弃后删除。保存失败、放弃失败、读取失败均有可见反馈且不暴露内部错误。
5. Controller 使用受控异步门验证多个自动保存串行以及放弃等待顺序；错误重试保留当前输入；标题按 trim 与 Unicode 码点边界验证。
6. Controller 接真实 SQLite 文件草稿库：输入变化→自动写入→关闭→新连接打开→恢复→放弃→关闭重开为空。全过程正式五表逐列快照保持不变，没有用 mock 代替该持久化证据。
7. Bootstrap 用真实隔离库进入首页后点击“补一笔”，实际草稿读取和账本读取完成后活动表单可见；重建不重复打开，卸载关闭两库，草稿打开失败关闭正式连接，迟到的草稿连接也被释放。

## Self-review / Blockers / Open Questions

完整检查新增表单 / 状态 / 测试和既有 app diff，重点核对返回拦截、异步完成后 mounted / disposed 检查、写入顺序、恢复优先、明确 Unknown、分钟编辑不改精度，以及页面输入不形成正式事实。没有改动前置存储、投影算法、领域合同、正式表、平台文件或依赖；已有用户改动和其他未跟踪文件均保留。

无 blocker 或新增 Open Question。时间选择对话框应用的是已确认分钟值；未填写的端点和未完成活动正文均可保留。Android 关闭应用与 Web 实际刷新恢复仍待 E4-T08，本机测试不冒充平台端到端证据。正式写入失败反馈不属于本任务，本次覆盖的是草稿存储失败；正式保存接入留 E4-T05。

## Next executable task

**E4-T05 — 接通正式新建保存、冲突反馈与刷新**。E4-T04 已完成，E2-T06 有既有完成报告。本次不执行下一任务。
