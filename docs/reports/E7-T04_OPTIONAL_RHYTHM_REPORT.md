# E7-T04 — 接通可选节奏解释与接续点

## Task / Status

**E7-T04 / COMPLETE（2026-10-01，Asia/Shanghai）。** 本次仅执行 E7-T04，未执行 E7-T05 或后续任务，Epic 7 未标记完成。

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，核对 MODEL / RhythmAnnotation、STATES / RhythmAnnotation、RULES / RH-001–RH-008，以及草稿、分层和原子写入合同。E7-T03、E2-T06 的完整定义、完成报告与实际实现已核对；E1-T11 的归档定义、领域实现和 Epic 0 / 1 负责人完成确认已核对，不补造历史验证记录。Q-004、Q-005、Q-012、Q-013、Q-015 均为 DECIDED；已有细节值域继续遵守 Q-007，身份遵守 Q-018。无来源冲突或产品阻塞。

按 AGENTS 委派 code_mapper 做有界只读写入 / 恢复路径勘查，主 agent 检查实际源文件后实现。复用已有 LedgerRepository、AnnotationChange、RhythmAnnotation 的领域校验和 Drift 原子事务，没有新增正式 repository 操作或重写领域规则。

## Changes

| 文件 | 本任务交付 |
| --- | --- |
| [recording_form.dart](../../lib/features/ledger/presentation/recording_form.dart)、[recording_rhythm_input.dart](../../lib/features/ledger/presentation/recording_rhythm_input.dart) | 共用表单增加“不标记 / 推进 / 卡住 / 恢复”、三状态可选接续点与长度反馈；已有细节只读，按当前选择状态展示，无新原因 / 恢复细节输入 |
| [recording_form_controller.dart](../../lib/features/ledger/presentation/recording_form_controller.dart) | 原解释读取、显式 keep / add / edit / remove 意图、接续点省略与清空区分、串行自动保留、关系操作失败反馈；已提交状态禁用重复提交 |
| [recording_draft_store.dart](../../lib/features/ledger/domain/recording_draft_store.dart)、[drift_recording_draft_store.dart](../../lib/features/ledger/data/drift_recording_draft_store.dart) | 独立草稿保存意图、稳定 annotation id、状态、原始接续点及 hintProvided；草稿 schema v4，v1 / v2 / v3 事务升级，旧行默认 keep |
| [recording_annotation_change.dart](../../lib/features/ledger/application/recording_annotation_change.dart)、[recording_entry_saver.dart](../../lib/features/ledger/application/recording_entry_saver.dart)、[recording_entry_editor.dart](../../lib/features/ledger/application/recording_entry_editor.dart) | 转换显式意图并传入现有原子写入；重复 add / 缺失 edit 的 typed failure；恢复匹配包含解释，add 必须匹配草稿稳定 id，避免将竞争者的添加误认作本次提交 |
| [recording_rhythm_test.dart](../../test/features/ledger/presentation/recording_rhythm_test.dart) | 24 项真实库 controller / widget 测试，覆盖六向切换、仅改解释、文本、事务回滚、存储失败、缺失对象及提交后恢复 |
| [recording_rhythm_migration_test.dart](../../test/features/ledger/data/recording_rhythm_migration_test.dart) | 5 项真实 SQLite 文件测试：旧草稿升级、原解释保留、意图 / 原始文本 / 稳定 id 文件重开、DDL 失败回滚与重试 |
| [recording_rhythm_flow_test.dart](../../test/app/recording_rhythm_flow_test.dart) | 2 项真实 AppBootstrap 组合测试，覆盖普通 / 主页编辑、Gap / 时间轴编辑的草稿、添加、切换、接续点读回与明确移除 |
| [recording_draft_store_test.dart](../../test/features/ledger/data/recording_draft_store_test.dart)、[recording_goal_migration_test.dart](../../test/features/ledger/data/recording_goal_migration_test.dart)、[recording_goal_test.dart](../../test/features/ledger/presentation/recording_goal_test.dart) | 草稿版本探针 / 不支持版本夹具随 v4 更新；复用旧版 schema 夹具扩展 v3；懒构建滚动定位修复，保留原行为断言 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 原完整任务归档、稳定锚点索引、完成依据与进度同步 |

四处应用入口已共用 RecordingForm，本次通过真实组装测试验证接通，无需修改 app 生产代码。

## Acceptance evidence

- known / unknown × 有 / 无 Goal × 无解释 / 三状态的 16 种组合均可创建。无解释为缺少 annotation，不加入 neutral，不从“午饭”等活动名称自动打标；无需原因或恢复细节，approximate 继续合法。普通 / 睡眠原有低成本路径在回归中保留。
- 六向状态切换全部通过 widget + 真实 repository 验证。annotation 的 id / timeBlockId / createdAt 与原附属字段保留；卡住原因仅在 stuck 展示，恢复方式 / 效果仅在 recovery 展示，progress 不显示这些细节。仅更正解释时 TimeBlock 全行、元数据与区间不变。
- 三状态均可输入、清空和恢复接续点。Unicode 码点边界 2000（含补充平面字符和内部换行）可保存，2001 拒绝且原始草稿不截断；正式文本由现有领域规范化处理，首尾清理、内部换行保留，空白明确清空为 null。切换状态或暂选不标记不会丢掉未提交的原始输入。
- 未请求解释变更使用 KeepAnnotation。旧版草稿默认 keep，编辑时读取现有解释，而非把未展示字段清空。明确 remove 仅删除解释，TimeBlock 全行 / metadata / 账本覆盖保持；移除后无第四种解释状态。
- 组合时间冲突，以及 SQLite annotation AFTER INSERT / UPDATE / DELETE + RAISE(FAIL) 分别覆盖 add / edit / remove 的中途失败：正式五表快照不变，输入和意图仍在草稿，解除故障或手动修正后可成功重试。同块唯一、缺失对象及关联约束继续由现有真实写入测试验证。
- 其他写入者先添加解释或移除原解释时，重复 add / 缺失 edit 明确反馈，事实修改同样回滚；重新打开仍保留失败操作的显式意图，不静默 upsert。用户基于新读到的关联重新选择后可提交。原 TimeBlock 已删除时，恢复编辑草稿不能创建替代事实，输入仍留在草稿。
- 草稿保存故障保留当前原始接续点、意图及旧持久化草稿；未成功保留草稿前不写正式事实，重试可继续。v1 / v2 / v3 文件升级后活动 / note / Goal / 时间精度保持，原解释与隐藏细节保留。v3→v4 第二条 ALTER 失败时回滚第一条，user_version 仍为 3，解除故障后可重试。
- 新建 annotation 的稳定 id 和原始接续点在真实文件关闭 / 重开后保持，暂选不标记后再次选择也使用同一 id。create / add / edit / remove 提交成功而清理和刷新同时失败时，重开 controller 识别已提交结果并禁用再次提交；仅重试清理 / 读取，SQL 计数确认无重复正式写入。竞争者的相同状态 add 因 id 不同不会被误清为已提交。

## Validation

仓库根目录使用已有 Dart / Flutter 和缓存依赖，未安装或更新包。本次改动 14 个 Dart 文件（上表 8 个生产文件、6 个测试文件）。

| 实际命令 | 结果 |
| --- | --- |
| `TZ=Asia/Shanghai dart format` 上述改动 Dart 文件（分批） | 退出 0 |
| `TZ=Asia/Shanghai dart format --output=none --set-exit-if-changed` 上述 14 文件 | 退出 0，14 files / 0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/recording_rhythm_test.dart test/features/ledger/data/recording_rhythm_migration_test.dart test/app/recording_rhythm_flow_test.dart test/features/ledger/data/recording_draft_store_test.dart test/features/ledger/data/recording_goal_migration_test.dart` | 退出 0，40 项通过；随后增加的文件重开用例另在修复与最终回归中通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/data/recording_rhythm_migration_test.dart test/features/ledger/presentation/recording_goal_test.dart` | 退出 0，18 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/features/goals test/app test/core/time` | 最终退出 0，505 项通过、3 项既有时区条件测试跳过；新增 31 项均通过 |
| `git diff --check`、任务增量 whitespace 检查、执行前 SHA-256 对照、归档全文 / 后续定义 / 文档链接检查 | 通过 |

初次迁移 / app 测试中的对象身份断言不适用于重新读取的领域对象，改为正式 SQL 行数据比较；三项 if 大括号 lint 已修复。首轮广回归两项旧目标测试因新增区块后向下滚动无法找到屏幕上方的懒构建控件而失败，修正定位辅助函数后定向及最终广回归通过；未降低原断言。迁移测试移除闲置的第二个草稿连接，未共享 executor。未把初次失败写成通过。

上海时区的 3 项 skip 是既有 DST 条件测试，未视为通过。最终日志：`/tmp/e7-t04-focused.log`、`/tmp/e7-t04-repair.log`、`/tmp/e7-t04-analyze-final.log`、`/tmp/e7-t04-regression-final.log`。

## Self-review / Scope

以执行前全部 302 个既有文件的 SHA-256 与内容副本作任务增量检查，覆盖已跟踪及未跟踪文件；仅上述必要代码、测试与完成文档发生本任务变更，其他既有工作区修改保留。检查显式意图、省略 / 清空、隐藏字段、原子提交、关系错误、草稿迁移、提交恢复、控件禁用和新测试断言。

正式 AppDatabase 仍为 schema 2 / 五表；未修改正式 schema、生成文件、pubspec / lockfile、领域校验、时间建议或睡眠行为。没有新增原因 / 恢复细节输入、时间轴节奏展示（E7-T05）、统计、自动评价、通用 use-case 框架或后续任务。原 E7-T04 全文归档，仅补充状态 / 报告链接；后续完整定义保持原样。

## Blockers / Open Questions / Limitations

无 blocker，无新增 Open Question。真实文件重开属于 Native SQLite 证据；未执行 Android 应用关闭或 Web 刷新恢复，不外推为两平台完成。新增解释输入的两平台生命周期验证仍属 E7-T07。

## Next executable task

**E7-T05 — 在时间轴呈现目标节奏与接续点。** E7-T04、E6-T04 已有完成依据，相关 Q-003、Q-005、Q-006、Q-013 均为 DECIDED；仅报告，不执行。E7-T04 完成后停止。
