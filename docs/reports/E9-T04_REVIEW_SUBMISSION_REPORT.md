# E9-T04 — 接通复盘新建保存与失败反馈

**Status：COMPLETE**。执行日期：2026-10-02（Asia/Shanghai）。仅执行 E9-T04，完成后停止。

## 前置与依据

核对 AGENTS、Task 完整定义、SOT / §21–22、OQ、MVP、PLAN、MODEL / DailyReview 与 TomorrowFirstStep、RULES / DR-001–DR-004、DATA / daily_reviews、唯一约束与本机输入草稿，以及 APP / review 依赖、写入流程和装配边界。[E2-T07 报告](E2-T07_REVIEW_REPOSITORY_REPORT.md)、[E9-T03 报告](E9-T03_REVIEW_FORM_REPORT.md)、两项归档定义和相关实现均有前置完成证据。

Q-001、Q-006、Q-012、Q-013、Q-018 均 DECIDED，相关规范已同步：CivilDate 与下一自然日派生合同、当前有效 Goal 引用、独立草稿、显式新建 / 更正 / 删除边界、可选概述 / 反思与必填下一步。继承表单的 Q-015 文本合同，正式保存先清首尾空白，每个字段最多 2,000 Unicode 码点；草稿保留原始输入。没有补造产品决定或更改问题状态。

按 AGENTS 委派 code_mapper 有界只读定位提交、repository、草稿与 app 装配调用。主 agent 检查路径证据和既有普通 / 睡眠提交的两阶段收尾模式；实现决策、编辑、集成、自检与最终验证均由主 agent 执行。

## Changes

| 文件 | 本次职责 |
| --- | --- |
| `lib/features/review/application/review_entry_saver.dart` | 调用既有 create；区分正式失败与已提交后的清草稿 / 重读失败；只重试收尾，按全部规范化字段识别残留新建草稿 |
| `lib/app/bootstrap/review_submission.dart` | 用既有 DriftReviewRepository、草稿存储、读取 loader、ID 和时钟组装 saver |
| `lib/app/bootstrap/app_bootstrap.dart` | 将同一复盘 loader 与 saver 接入实际 app 生命周期 |
| `lib/app/main_app.dart` | 向实际复盘入口传递 saver |
| `lib/features/review/presentation/review_form_controller.dart` | 提交前排空并保存完整草稿，重复提交锁，分类失败反馈，记录正式提交身份并重试收尾 |
| `lib/features/review/presentation/review_form.dart` | 新建保存按钮、已提交反馈及清理 / 读取重试；提交后冻结输入；成功返回已存日期 |
| `lib/features/review/presentation/review_context_page.dart` | 收到保存结果后按实际已存 CivilDate 回看；普通草稿返回保持原入口行为 |
| `test/features/review/application/review_entry_saver_test.dart` | 10 项真实库、草稿文件、并发、文本、Goal、故障、提交锁与恢复测试 |
| `test/app/review_submission_flow_test.dart` | 5 项实际 bootstrap / 表单交互、失败反馈、重复点击、残留草稿恢复及回看测试 |
| `TASKS.md`、`docs/planning/COMPLETED_TASKS.md`、`docs/planning/IMPLEMENTATION_PLAN.md`、本报告 | T04 状态、完整定义归档及完成依据 |

- 提交前等待串行草稿写入，并保存最新完整快照；草稿写入失败先保留磁盘旧快照和内存新输入，阻止正式 create。正式写入继续使用 ReviewRepository.create 的事务、CivilDate 唯一约束和当前 Goal 检查；不以候选读取或 UI 预检替代原子约束。
- 正式保存失败区分日期占用、Goal 已无效、文本不合格及存储异常，保留原始输入和草稿供用户修正 / 重试。同日竞争不会覆盖获胜复盘；Goal 在选择后归档或删除会按提交时当前状态拒绝。
- 第一次点击同步进入提交中状态；再次点击、输入、放弃和离页不能并发创建或改变提交快照。只有新建草稿接通正式保存；已有复盘仍进入编辑草稿，未接通正式更正。
- create 成功即保留已提交 DailyReview 的身份、日期和时间戳。随后只清原始草稿 context 对应键，并按已存日期重读；改草稿日期不改清理键，也不清其他日期 / 编辑身份的草稿。成功回到实际已存日期，重读要求同一复盘 ID 和正确日期。
- 已提交后的清理和重读分别反馈，失败后只调用 finishCommitted，不重新 create。输入和放弃功能保持冻结，重试不改变正式 ID、createdAt 或 updatedAt；空值、错日期或其他身份的读回不标成功。
- 重新读取残留新建草稿时，只有合法日期和全部规范化文字 / Goal ID 都与已存复盘相同，才恢复已提交收尾状态。不同内容、无效文本或不完整下一步保留草稿，不自动覆盖或重复创建。应用交互覆盖改日期后返回原入口的残留草稿恢复。
- 可只填写下一步，不要求先看统计、补齐 Gap、填写概述或反思；不自动生成行动 / 反思，不写统计快照。复用 CivilDate 与 TomorrowFirstStep，下一自然日仍由已存复盘日期派生，intendedDate 无独立列。

## Validation

在仓库根目录使用已有 Flutter / Dart 与缓存依赖。以下最终命令均退出 0：

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format`（上述 7 个生产 Dart 文件与 2 个测试文件） | 通过 |
| `dart format --output=none --set-exit-if-changed`（同上 9 个文件） | 9 files，0 changed |
| `flutter analyze --no-pub` | No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review/application/review_entry_saver_test.dart test/app/review_submission_flow_test.dart` | 15 项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/review test/features/ledger test/features/goals test/app test/core/time` | 637 项通过，3 项既有条件跳过 |
| `git diff --check`、执行前文件 SHA-256 对照、原定义归档及文档链接检查 | 通过 |

验收证据：

1. 真实 SQLite 同日并发新建只有一个获胜；另一草稿完整保留。表单打开后另一写入占用日期，正式提交明确拒绝，未覆盖原记录。修正日期 / Goal 后可创建新的复盘。
2. 真实 active Goal 成功保存并读回当前元数据；选择后归档 / 物理删除均拒绝。空白下一步及三个字段 2,001 码点被拒绝；2,000 emoji 码点可以保存。可选空文字规范化为空，内部段落保留。
3. SQLite AFTER INSERT 的 RAISE(FAIL) 验证正式事务回滚，草稿和输入保留，修正 / 重试后只有一行。SQLite 草稿 AFTER UPDATE 故障验证最终草稿保存失败不调用 create，成功重试后保存最新输入。
4. SQLite 草稿 AFTER DELETE 故障与读取异常同时出现时，反馈明确为已提交但两项收尾失败；先恢复清理，再恢复读取，全程 create 计数为 1，身份 / 时间戳不变。读回空值或错日期同样不能误报完成。
5. 延迟真实 create 期间 controller 和重复点击 widget 场景证明不会重复提交；已提交后不能编辑或放弃。实际 AppBootstrap → 复盘 → 新建表单只填写下一步，Gap 为 1,440 分钟仍成功保存，并回看改后的历史日期。
6. 真实草稿文件关闭 / 重开后逐项匹配概述、反思、下一步和 Goal ID；各项差异 / 超长文本均不误清草稿或 create。界面返回原入口后可恢复改日期的已提交残留草稿，仅重试收尾并回看已存日期。
7. 改日期跨闰年月边界后，已存 CivilDate 与下一自然日遵守既有领域算法；检查 daily_reviews 仍为既有 8 列，没有 intendedDate 或派生统计列。已有复盘的编辑草稿不提供正式新建按钮，改草稿反思不改正式复盘。

首轮静态分析的花括号提示和新增测试缺失的 Goal.delete 接口已修正。故障注入曾与尚未排空的自动保存竞争 SQLite 锁，修正为先等待既有写入完成再安装触发器。真实 NativeDatabase widget 关闭跨越 fake-async 队列时曾等待未完成，已中止该次运行，修正测试 harness：在真实异步区开始关闭、推进 widget / 真实队列，最后在真实异步区等待关闭。没有为测试改变生产存储或领域合同；最终定向测试与相关回归均通过。

3 项 skip 是上海时区下既有 sleep_ledger_loader_test 的纽约 DST 条件测试，以及 day_ledger_resolution_flow_test 的 23 / 25 小时场景，未计为通过。本次未改变自然日投影。日志：`/tmp/e9-t04-target-final.log`、`/tmp/e9-t04-analyze-final.log`、`/tmp/e9-t04-regression.log`。

## Self-review / Scope

检查全部新建未跟踪文件，以及相对执行前备份的生产代码完整差异。执行前 367 个既有文件的 SHA-256 对照，只有本任务所列 5 个既有生产文件和 3 个任务状态文档发生变化，其余既有修改 / 未跟踪内容保留。新增 2 个生产文件、2 个测试文件和本报告；没有改 pubspec、正式 schema、领域模型、已决问题或其他任务报告，没有引入依赖或无关重构。

新建协调层只依赖既有 review/domain 与读取接口，具体持久化在 app 装配。create 仍由既有 repository 事务保证当前库约束；正式更正、日期变更更正、删除和后续回看 / 平台验收没有提前实现。Task 原完整定义保持不变归档，仅增加完成状态和报告链接；Epic 9 尚未整体验收。

## Blockers / Open Questions

无 blocker，无新增产品问题。当前任务的共享代码、真实库及 widget 验证完成。未执行 Android 实际关闭重开或 Web 同源刷新验收，不把文件重开、widget 返回恢复或模拟生命周期作为平台证据；实际生命周期按 E9-T09 交付。

## Next executable task

E9-T05 — 接通复盘原地更正与日期变更。前置 E9-T04、E1-T12 有完成依据，涉及问题已决。仅报告，未执行；E9-T04 完成后停止。
