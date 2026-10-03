# E9-T03 — 实现复盘表单与草稿生命周期

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T03，完成后停止。

## 前置与依据

核对 AGENTS、Task 完整定义及 SOT / §21–22、OQ、MVP、PLAN、MODEL / DailyReview 与 TomorrowFirstStep、RULES / DR-001、DR-003–DR-004、MODEL-002、DATA / 本机输入草稿及 APP / review 依赖方向。E9-T01、E9-T02 的原定义、[读取报告](E9-T01_REVIEW_CONTEXT_REPORT.md)、[独立草稿报告](E9-T02_REVIEW_DRAFT_STORE_REPORT.md)与相关实现均有完成证据。

Q-001、Q-006、Q-012、Q-015 均 DECIDED，规范已同步：下一自然日由复盘日期派生；已有归档 Goal 引用保留，新关联只选 active；草稿独立、自动保留、失败不清除；三个字段均为清理首尾空白后最多 2,000 Unicode 码点的长文本，概述 / 反思可空，正式下一步非空白。没有补造产品决定或重开已决问题。

按 AGENTS 委派 code_mapper 有界只读定位表单、草稿、Goal 读取与 app 入口。主 agent 检查其路径证据，并复用普通 / 睡眠表单的串行写入、离页等待、显式放弃模式；实现与最终验证由主 agent 执行。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/presentation/review_form_controller.dart` | 原始输入、恢复、稳定草稿身份、日期 / 文本反馈、串行自动保存、离页等待、失败重试、显式放弃及 Goal 元数据 |
| `lib/features/review/presentation/review_form.dart` | 概述、反思、单个下一步、日期与可选目标输入；保留 / 放弃反馈；独立事实刷新与 resume |
| `lib/features/review/presentation/review_facts_view.dart` | 复用原覆盖、睡眠、目标 / 节奏摘要组件，为读取页和表单提供同一事实展示 |
| `lib/features/review/presentation/review_context_page.dart` | 明确读到无复盘 / 已有复盘后进入新建 / 编辑草稿；调用方负责 controller 释放 |
| `lib/app/main_app.dart` | 将既有 ReviewDraftStore 与 GoalRepository 注入实际复盘路由 |
| `lib/features/review/domain/tomorrow_first_step.dart` | 仅暴露既有纯日历运算供空下一步草稿展示日期，不新增或改变领域字段 / 日期规则 |
| `test/features/review/presentation/review_form_controller_test.dart` | 10 项恢复、原文边界、日期、串行操作、失败与目标关联测试 |
| `test/features/review/presentation/review_form_test.dart` | 5 项 widget 输入、快速切日、上下文独立刷新、返回恢复、失败重试与目标选择测试 |
| `test/app/review_form_entry_test.dart` | 3 项真实文件重开、SQLite 故障、正式表隔离及实际 bootstrap 路由测试 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | T03 状态、完整定义归档及完成依据 |

- 初始化先读取草稿；仅确认无草稿后使用原复盘或新建入口日期。完整快照中明确清空的文字 / Goal 不从原事实回填。读取失败禁用输入并提供重试，重复初始化不覆盖当前输入。
- 新建草稿仍按入口 CivilDate 定位，编辑草稿按原 DailyReview ID 定位；改日期只改变输入与派生展示，不迁移键、不覆盖其他日期或身份的草稿。原复盘保持不可变，未提交不写正式五表。
- 输入保留首尾空白、内部换行、段落、空下一步、无效日期及超长文字。复用既有领域文本规则提供反馈，不截断输入，也不因为正式下一步暂不合格而拒绝保留草稿。
- 日期有效时同步展示其下一自然日；无效 / 未完成日期不展示旧的下一自然日。复用 TomorrowFirstStep 原有 Gregorian 日历算法，不取系统今天、设备时区或固定 24 小时。
- 每次输入捕获完整快照并串行写入；返回先冻结输入并等待已接受的写入，保存失败保留页面和输入，支持重试。放弃等待排队写入后只清当前键，清除失败不返回成功、不丢失输入。
- 当前 Goal 按 ID 读取，可显示原归档引用；新选择仅 active，可不关联或主动清空。同名 active 候选显示标识用于区分，其他候选只显示名称。Goal 读取失败保留关联和文字，晚到的读取不能恢复已明确清空的关联。
- 事实读取与原始表单输入各自管理：切日丢弃旧响应，刷新 / resume 仅重读当前日期事实及 Goal 元数据，不恢复默认文字、不自动生成反思或下一步。
- 表单明确提示自动保留为草稿；没有正式提交、任务列表、每 Goal 计划、continuationHint 复制或派生数值持久化。

## Validation

仓库根目录使用既有 Flutter / Dart 与缓存依赖。最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format`（上述 6 个生产 Dart 文件与 3 个测试文件） | 通过 |
| `dart format --output=none --set-exit-if-changed`（同上 9 个文件） | 9 files，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/presentation/review_form_controller_test.dart test/features/review/presentation/review_form_test.dart test/app/review_form_entry_test.dart` | 18 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 622 项通过，3 项既有条件跳过 |
| `git diff --check`、执行前文件 SHA-256 对照、原定义归档与文档链接检查 | 通过 |

验收证据：

1. 可选概述 / 反思留空仍可得到合格的表单输入；只有空白的下一步原样保存草稿并恢复，同时保持正式非空白提示。三个字段均检查 2,000 / 2,001 码点边界，覆盖 emoji（两个 UTF-16 单元）、组合字符、多行与段落，不使用 TextField 截断原文。
2. 年边界、月边界、闰年、1900 / 2000 年与负年到零年的下一自然日同步正确。无效 / 未完成日期原文保存并恢复，不显示旧日期上下文或旧下一自然日；快速切日的旧成功 / 失败响应不覆盖新日期。
3. 延迟写入期间快速输入与离页严格按快照顺序执行，冻结后不接受新输入；普通系统返回保留草稿，重新打开原入口恢复改后日期与文字。重入初始化、事实上下文失败 / 重试及 resume 不覆盖已恢复或当前输入。
4. 保存失败保留内存新输入和磁盘旧草稿，阻止离页；重试成功后可以返回。放弃先等待写入，失败仍保留，重试只清当前键。真实文件 SQLite AFTER UPDATE / DELETE 的 RAISE(FAIL) 验证回滚和恢复，未用纯 mock 代替存储故障。
5. 真实正式库中的已归档原 Goal 按 ID 显示，候选只含 active；同名候选可区分，可替换 / 清空。目标读取失败及晚到响应不会改写输入或恢复已清空的关联。
6. 真实正式文件与草稿文件关闭 / 重开，原复盘身份、日期、概述、反思、下一步、Goal 引用及五表快照保持原值；编辑草稿恢复改后日期、空文字与原归档引用。另一新建入口草稿独立，放弃编辑草稿后仍可读。
7. 实际 AppBootstrap → 按日复盘 → 新建 / 编辑草稿路由传递存储和 Goal 接口；普通返回与重开恢复输入，正式复盘原文不变。在打开表单期间另行写入时间事实，刷新看到 60 分钟，而草稿反思与正式 daily_reviews 行均保持原样；放弃编辑草稿不清除当天新建草稿。

首轮新增测试出现辅助函数参数 / API 使用错误及缺少花括号，已修正后重跑。真实 NativeDatabase widget 测试曾在纯 fake-async pump 中超时、在关闭阶段等待尚未推进的异步链而未完成，已中止该次运行并修正测试 harness：预先打开连接，在 frame 之间允许真实异步延续执行，dispose 后先排空再等待关闭。没有为测试改变生产存储或领域合同；最终定向与相关回归均通过。

3 项 skip 是上海时区下既有 sleep_ledger_loader_test 的纽约 DST 条件测试，以及 day_ledger_resolution_flow_test 的 23 / 25 小时场景，未计为通过。本次未改变自然日投影。日志：`/tmp/e9-t03-target-final.log`、`/tmp/e9-t03-analyze-final.log`、`/tmp/e9-t03-regression.log`。

## Self-review / Scope

检查了本次新建未跟踪文件及相对执行前备份的完整差异。执行前 360 个既有文件的 SHA-256 对照，仅本任务所列的 3 个既有生产文件和 3 个任务状态文档发生变化，其余既有修改 / 未跟踪内容保留。未改 pubspec、正式 schema、领域模型文档或已决问题；未新增依赖、正式写入接口或无关重构。

新增事实展示组件是读取页与表单的必要共用展示，继续复用 ledger 摘要口径。TomorrowFirstStep 的改动只有对原日历函数的静态入口，避免为未完成下一步构造虚假的行动文字或复制一套日期规则。相关领域、读取、草稿、账本、目标和 app 测试通过。

## Blockers / Open Questions

无 blocker，无新增产品问题。此任务的共享代码、真实库与 widget 验证完成；没有执行 Android 关闭重开或 Web 同源刷新验收，不将文件重开或模拟 resume 写成两平台证据，实际生命周期按 E9-T09 交付。

## Next executable task

E9-T04 — 接通复盘新建保存与失败反馈。仅报告，未执行；E9-T03 完成后停止，Epic 9 尚未整体验收。
