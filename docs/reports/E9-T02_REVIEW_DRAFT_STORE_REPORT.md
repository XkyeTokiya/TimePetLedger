# E9-T02 — 实现独立复盘本机草稿存储

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T02，完成后停止。

## 前置与依据

阅读 AGENTS、Task 完整定义、SOT、OQ、MVP、PLAN、DATA / 本机输入草稿、MODEL / UI Models、APP / review 分层，并核对 Q-012、Q-015 及 E1-T07 文本补充决定。E2-T02 的归档定义与[连接报告](E2-T02_PERSISTENCE_CONNECTION_REPORT.md)、E2-T07 的定义与[复盘存取报告](E2-T07_REVIEW_REPOSITORY_REPORT.md)、E1-T07 定义及[负责人完成确认](EPIC_0_1_COMPLETION.md)均有依赖完成证据，相关实现仍可用。

按 AGENTS 委派 code_mapper 做有界只读定位，主 agent 检查现有普通 / 睡眠草稿、连接装配和测试证据后实现。复用已有 Drift 和平台连接工厂，没有安装新依赖。没有将领域未完成输入当作正式复盘或放宽正式下一步必填合同。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/domain/review_draft_store.dart` | 专用草稿 DTO、稳定入口身份、read / save / clear 边界与数据 / 存储错误 |
| `lib/features/review/data/drift_review_draft_store.dart` | 独立复盘草稿数据库 v1、明确字段映射、事务写入 / 清除、严格读取与关闭等待 |
| `lib/app/bootstrap/review_drafts.dart` | `time_pet_ledger_review_drafts` 命名连接和 app 拥有的 lazy ReviewDraftSession |
| `lib/app/bootstrap/app_bootstrap.dart`、`lib/app/main_app.dart` | 注入存储接口，bootstrap 释放 session 并报告关闭失败 |
| `test/features/review/data/review_draft_store_test.dart` | 6 组真实 SQLite 原文、身份 / 日期、数据隔离、失败回滚、关闭顺序和坏数据检查 |
| `test/app/review_draft_storage_test.dart` | 5 组 lazy 打开、失败重试、延迟打开期间关闭、bootstrap 注入 / 释放及文件重开 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | 当前状态、原定义归档及完成依据 |

- 新建草稿按入口 CivilDate 定位；编辑草稿按原 DailyReview ID 定位。ReviewDraft.date 独立保存正在编辑的日期，改日期不会迁移键或覆盖另一日期 / 另一身份的草稿。
- 原样保存 summary、reflection、下一步文字及原 Goal ID；null、空串、首尾空白、多行、段落和超长 Unicode 文本均保留。当前解析日期可以为 null，同时保存未完成 / 无效的 dateInput 原文，不由存储层重新解释日期输入。
- DTO 是完整输入快照，保存 null Goal 表示当前未选或清空；不是部分正式更新指令。原 Goal 可以保留，不查询其 active / archived 状态，也不在草稿库建立正式外键；UUID 结构仍校验。
- 独立库只有 `review_drafts` 表，不接触正式五表 / 普通 / 睡眠草稿；不存 intendedDate、统计、Day、Gap 或正式 draft 状态。草稿可与正式复盘同日并存，不占 review_date 的唯一位置。
- read 返回 null 仅表示没有该键；非法持久值抛 ReviewDraftDataException，技术失败抛带 open / read / save / clear / close 操作标识的 ReviewDraftStorageException，不静默默认或吞掉故障。
- 保存与清除用事务包住语句及其触发器。操作按调用顺序执行，失败不污染后续操作；close 等待已接受的操作完成，关闭后拒绝新操作。打开失败清理连接，未知 schema 版本拒绝，不进行静默降级。
- bootstrap 提供 app 生命周期内按需打开的独立存储接口，重建不重复打开，dispose 关闭并通过 FlutterError 报告释放失败；关闭期间未完成的打开及已接受保存也会等待完成。未使用草稿接口时不会额外打开持久库。

## Validation

仓库根目录使用既有 Flutter / Dart 与缓存依赖；以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format lib/features/review/domain/review_draft_store.dart lib/features/review/data/drift_review_draft_store.dart lib/app/bootstrap/review_drafts.dart lib/app/bootstrap/app_bootstrap.dart lib/app/main_app.dart test/features/review/data/review_draft_store_test.dart test/app/review_draft_storage_test.dart` | 格式化通过（新增测试在修正后单独重排） |
| `dart format --output=none --set-exit-if-changed`（同上七个文件） | 7 文件、0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/data/review_draft_store_test.dart test/app/review_draft_storage_test.dart` | 11 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 604 项通过，3 项既有 DST 条件测试跳过 |
| `git diff --check`、执行前 SHA-256 对照、归档原定义与文档链接核对 | 通过 |

实际证据包括：

- 真实独立文件库关闭 / 重开，逐项比较原始字段；两新建日期与两编辑源身份并存，新建和编辑改日期后互不覆盖；缺失草稿与幂等 clear。
- 未完成日期、空白 / 空 / null 下一步、多行及三个字段各超过 2,000 Unicode 码点的输入保持原样；正式 TomorrowFirstStep 仍拒绝全空白文字。Goal 选择、替换与清空分别重开读回。
- 已填充正式五表的逐行快照及 schema / indexes 不变，已有复盘文字不改。草稿与正式同日共存，新建草稿不阻止同日正式创建；普通 / 睡眠草稿保持原值，正式读取不包含复盘草稿。
- 测试库 AFTER INSERT / UPDATE / DELETE 触发器执行 RAISE(FAIL)，确认新建失败无残留、更新 / 清除失败保留全部旧字段；移除故障后可重试。真实查询故障和坏值分别暴露存储 / 数据错误，坏行保持以便诊断，不假报无草稿。
- 连续 save / save / clear / save 后立即 close，重开取得最后已接受的输入；关闭后操作、不可打开路径、未知版本和注入关闭失败分别有正确错误操作类型。
- app session 打开失败后重试，多个排队操作仅成功打开一次；延迟打开期间 close 仍完成已接受输入并释放真实文件连接。bootstrap 重建保留同一接口且保持 lazy，dispose 后真实连接拒绝读取、文件重开可恢复；关闭错误进入 FlutterError。

首轮分析发现新增测试一处缺少花括号，已修正。首轮 widget 生命周期测试把 fake-async 区域创建的延迟操作在 runAsync 中等待，未完成并中止该次测试；修正为真实异步 session 测试验证延迟打开 / close drain，widget 测试在 runAsync 内调用文件操作并单独验证 bootstrap 注入 / 释放。最终定向及回归均通过，没有为测试修改生产合同。

三项 skip 为上海时区下既有 sleep_ledger_loader_test 的纽约 DST 测试，以及 day_ledger_resolution_flow_test 的两个 23 / 25 小时条件场景，未计为通过。本任务不修改自然日投影。独立库错误 / 故障测试可能输出 Drift 多实例 debug 提示，未关闭全局提示掩盖输出；使用的 executor 均各自独立。

最终日志：`/tmp/e9-t02-target-final.log`、`/tmp/e9-t02-analyze-final.log`、`/tmp/e9-t02-regression.log`。

## Self-review / Scope

执行前保存全部 354 个既有 tracked / untracked 文件 SHA-256。代码验证后，只有两份 app 文件有本次增量变化；其余既有文件（含 E9-T01 全部交付）保持原样。对照 bootstrap 原始副本及剥离 MainApp 新增接口后的哈希核对，保留原有内容与行为。新增生产文件仅专用 DTO / store / app 装配，新增测试仅对应本 Task。

收尾增量更新三份规划文档并完整归档 E9-T02 原定义，添加 COMPLETE 与报告链接。检查全部新文件与增量，无无关格式化、依赖 / lockfile、正式 schema / 生成代码或产品规则变更。草稿库是新建 v1，未改已有草稿库版本；不存在需要迁移的前序复盘草稿库。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。本 Task 交付存储及 app 生命周期边界，尚未接入复盘表单 / 输入自动保存、恢复 / 放弃按钮或正式提交；这些属于 E9-T03 及后续任务。本机真实库重开、session 与 widget 释放证据不等于 Android 关闭重开或 Web 浏览器刷新验证，实际平台生命周期仍留 E9-T09。未执行平台验证，不标记平台通过。

## Next executable task

**E9-T03 — 实现复盘表单与草稿生命周期。** E9-T01、E9-T02 已完成，Q-001、Q-006、Q-012、Q-015 已决定；仅报告，不执行。Epic 9 尚未整体验收，本次完成 E9-T02 后停止。
