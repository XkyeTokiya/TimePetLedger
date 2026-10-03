# E9-T06 — 接通复盘删除与返回读取

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T06，完成后停止。

## 前置与依据

核对 AGENTS、Task 完整定义、SOT / §21–22、OQ、MVP、PLAN、STATES / 通用更正与删除及 DailyReview、RULES / DR-002、DATA / daily_reviews、外键删除策略与独立草稿，及 MODEL / DailyReview 与 APP / 写入、UI 状态和依赖方向。[E9-T05 完成报告](E9-T05_REVIEW_CORRECTION_REPORT.md)、原归档定义与实际更正实现 / 测试均有前置证据。既有 ReviewRepository.delete 及 E2-T07 的真实库删除合同已核对。

Q-012、Q-013 均 DECIDED，规范已同步：独立编辑草稿不提前改变事实，正式失败保留输入；按源 ID 删除，缺失对象重复删除幂等，更正缺失对象不得重建；删除复盘不删除当天时间事实或 Goal。TomorrowFirstStep 随 DailyReview 保存，不存在独立下一步实体或级联 Day 表。没有新增产品决定或修改已决问题。

按 AGENTS 委派 code_mapper 有界只读定位既有普通 / 睡眠删除收尾、review 调用路径及测试。主 agent 检查路径证据，复用“正式删除 → 独立清草稿 / 重读 → 只重试收尾”模式；实现、编辑、集成、自检与最终验证由主 agent 执行。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/application/review_entry_saver.dart` | 明确的删除结果；调用既有 delete；按源 ID 清编辑草稿，按已存源日期重读；收尾重试不再次写入 |
| `lib/features/review/presentation/review_form_controller.dart` | 删除前保留完整输入并排空写入；提交锁、失败保留、已删除状态冻结与单独收尾重试 |
| `lib/features/review/presentation/review_form.dart` | 编辑入口的删除确认、已存源日期提示、快速重复操作防护、删除 / 收尾反馈及返回读取 |
| `test/features/review/application/review_deletion_test.dart` | 7 项真实文件库、正式表隔离、幂等、故障、冻结、读回、重开及草稿失败测试 |
| `test/app/review_deletion_flow_test.dart` | 4 项实际 bootstrap / widget 删除确认、失败 / 重试、快速重复操作、返回 / 重开及残留草稿隔离测试 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | T06 状态、完整定义归档及完成依据 |

- 只有已有复盘的编辑入口提供“删除复盘”。确认框显示原已存 CivilDate，并说明删除范围。取消不执行正式写入；快速重复打开或重复确认不会创建多个确认框、重复返回或并发删除。
- 删除使用编辑 context.reviewId 与原复盘 ID，先核对两者一致，再调用既有 ReviewRepository.delete。草稿中改过的日期、无效日期或空下一步不改变删除对象，也不成为删除校验门槛。
- 删除前冻结输入并保存完整原始草稿，等待已接受的写入。草稿保存失败先保留磁盘旧值和内存新输入，阻止正式删除；正式删除失败明确反馈，原始输入和草稿保留，可修正或重试，不显示已删除。
- 正式删除成功立即按已删除结果管理后续操作。只清该源 ID 的编辑草稿，保留同日独立新建草稿、其他日期新建草稿和其他身份编辑草稿。重读 / 返回使用原已存日期，不采用草稿改后日期或系统今天。
- 清理和读回失败分别反馈。已删除后输入、保存更正、再次删除与放弃均冻结；收尾只清草稿 / 重读，不再次 delete、update 或 create。旧源 ID 的编辑输入即使残留、恢复，也不能绕过 update 的缺失源合同重建事实。
- 重读要求 ledger 日期正确且读到的复盘 ID 不再是已删源；旧成功快照或错日期不会误报完成。同日后来出现另一 ID 时正常显示当前读取结果，重复删除旧源不影响替代复盘。
- 返回后读取页按当前事实显示无复盘或当前另一份复盘。重新进入新建表单使用独立日期键，不带入旧 ID 的编辑输入；没有自动创建复盘。复用既有 app 注入和 CivilDate 返回路由，无需改 app 装配、领域或 schema。

## Validation

在仓库根目录使用已有 Flutter / Dart 与缓存依赖。以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format`（上述 3 个生产文件与 2 个测试文件） | 通过 |
| `dart format --output=none --set-exit-if-changed`（同上 5 个文件） | 5 files，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/application/review_deletion_test.dart test/app/review_deletion_flow_test.dart` | 11 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 660 项通过，3 项既有条件跳过 |
| `git diff --check`、新增文件空白检查、执行前 SHA-256 对照、原定义归档和文档链接检查 | 通过 |

验收证据：

1. 真实正式文件库含 Goal、TimeBlock、RhythmAnnotation、跨日 SleepSession、待删复盘及另一日期复盘。不同正式表特意使用相同 ID，删除仍只影响源 daily_reviews 行；四张非复盘表的全部字段、其他复盘及账本 accounted / unresolved 时长保持原值。下一步随该复盘行消失。
2. 同一源重复删除幂等；删除后原日期出现另一 ID，再次删除旧 ID 不影响另一份复盘，读回展示当前身份。只清对应编辑键，三类无关草稿逐项保持内容。
3. SQLite AFTER DELETE 的 RAISE(FAIL) 验证正式删除事务回滚，五张正式表完整快照不变，最新原始输入留在编辑草稿；widget 不显示已删除。恢复存储后明确重试成功，没有先保存草稿更正。
4. 日期未完成 / 无效、下一步空白仍可以明确删除原记录。草稿 AFTER UPDATE 故障阻止正式删除，磁盘旧值与内存新输入保留；恢复草稿存储后可删除，不将正式保存的文本门槛套到删除。
5. 延迟 delete 时重复删除、保存、离页、放弃和输入均被锁；widget 同一帧两次打开及两次确认只有一次正式删除。提交后 SQLite 编辑草稿 AFTER DELETE 故障和读取异常分别重试，delete 计数保持 1，update / create 为 0，旧编辑输入不能重新提交。
6. 源复盘旧快照或错日期读回不标完成；后来正确读回只重试收尾。实际 AppBootstrap 路由验证确认框显示已存源日期，改草稿日期到另一已有复盘日期后删除仍只删源，返回源日期；另一日期读取完整保留。
7. 正式文件和草稿文件实际关闭 / 重开，残留编辑草稿按旧 ID 恢复，但更正提示源已不存在，不创建事实。界面在草稿清理失败后返回并重开表单，只恢复同日独立新建草稿，未带入残留编辑文字；旧源保持消失，其他草稿保留。

初轮应用层 7 项测试通过；widget 首轮 3 项通过、1 项因新增测试末尾多余的未绑定参数 SQL 断言失败，已移除该断言，保留 repository 读取与正式表快照证据后重跑。静态分析首轮发现新增测试的一个未使用导入，已移除。修正仅涉及测试，未改变生产存储或领域规则；最终定向、相关回归和静态分析均通过。

3 项 skip 是上海时区下既有 sleep_ledger_loader_test 的纽约 DST 条件测试，以及 day_ledger_resolution_flow_test 的 23 / 25 小时条件场景，未计为通过。本次未改变时间投影。日志：`/tmp/e9-t06-unit-initial.log`、`/tmp/e9-t06-widget-initial.log`、`/tmp/e9-t06-widget-final.log`、`/tmp/e9-t06-target-final.log`、`/tmp/e9-t06-analyze-final.log`、`/tmp/e9-t06-regression.log`。

## Self-review / Scope

检查相对执行前备份的三个生产文件完整差异及所有新增未跟踪测试文件。执行前 375 个既有文件的 SHA-256 对照，仅本任务所列 3 个生产文件及 3 个状态文档改变；其他既有修改 / 未跟踪内容均保留。新增 2 个测试文件与本报告；未改其他任务报告、pubspec、schema、领域对象、repository 或已决问题，未新增依赖。

正式 delete 仍由既有 repository 事务执行；application 只依赖接口和既有读取回调，UI 删除状态没有写为领域 status。范围仅为当前复盘删除、其编辑草稿收尾及返回读取，未删除其他事实 / 草稿，未扩展到 E9-T07 的跨入口回看。原完整定义保持不变归档，仅增加完成状态与报告链接；Epic 9 尚未整体验收。

## Blockers / Open Questions

无 blocker，无新增产品问题。当前 Task 的共用代码、真实文件库及 widget 验证完成。未执行 Android 实际关闭重开或 Web 同源刷新验收，不把文件重开或 widget 路由重开视作平台生命周期证据；实际两平台恢复按 E9-T09 交付。

## Next executable task

E9-T07 — 贯通日账本复盘与下一步回看。仅报告，未执行；E9-T06 完成后停止。
