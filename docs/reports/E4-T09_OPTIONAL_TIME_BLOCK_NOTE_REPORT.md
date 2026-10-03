# E4-T09 — 提供普通记录可选备注入口

## Task / Status

**COMPLETE（2026-09-29）。** 仅执行 E4-T09。E4-T06 已在 `TASKS.md` 标记 COMPLETE，报告、原子更正实现及测试已核对；E4-T08 已完成首发平台恢复验证。Q-012、Q-015 均为 DECIDED，无阻塞性 Open Question。

依据 Source of Truth 的可选 TimeBlock.note 与次要并行活动说明，DOMAIN_MODEL 的可选字段，DOMAIN_RULES / MODEL-001、MODEL-002 和 TB 规则，以及 MVP_SCOPE / Should Have。保留普通记录活动优先、备注非必填的输入路径；未改变核心 Epic 4 的验收门槛。按 `AGENTS.md` 委派有界只读代码勘查，主 agent 核对字段、草稿与正式提交链路后实施。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `lib/features/ledger/presentation/recording_form.dart`、`recording_form_controller.dart` | 增加普通表单可选多行备注；新建、编辑从草稿或原事实恢复原始输入，输入后自动保留；清理首尾空白后的 2,000 Unicode 码点上限在提交前给出字段提示 |
| `lib/features/ledger/domain/recording_draft_store.dart`、`data/drift_recording_draft_store.dart` | 草稿原样保存备注，不提前规范化或限长；独立草稿库从 v1 原地迁至 v2，增加可空备注及“是否曾提供备注输入”标记，旧新建和编辑草稿保持可读，旧编辑草稿不会意外清空原事实备注 |
| `lib/features/ledger/application/recording_entry_saver.dart`、`recording_entry_editor.dart` | 正式新建传入备注，正式更正支持修改或显式清空；提交后恢复识别比较备注，避免把同时间和标题、不同备注的事实误认作本次提交 |
| 相关 `test/features/ledger`、`test/app/basic_recording_flow_test.dart` | 覆盖留空、多行、空白归一、修改清空、2,000 码点边界、失败保留、正式读回、旧草稿升级及新增输入框后的滚动断言 |
| `integration_test/recording_platform_test.dart` | 扩充 E4-T08 的五阶段真实平台测试，在新建和编辑的跨启动 / 刷新恢复、冲突失败、正式提交和重读中核对备注 |
| `TASKS.md`、本报告 | 记录任务状态及验证证据 |

正式 TimeBlock、正式数据库表和 repository 原有 note 合同直接复用；没有新增正式字段、依赖、睡眠备注入口或其他 Epic 功能。旧草稿的备注缺席与用户明确清空是两个不同状态，新增草稿列记录这一区别。

## Validation

在仓库根目录执行：

| 命令或场景 | 结果 |
| --- | --- |
| `dart format`（本任务 14 个 Dart 文件） | 退出 0，最终 0 changed |
| `dart format --output=none --set-exit-if-changed`（同 14 文件） | 退出 0，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub` | 最终退出 0，366 项通过、2 项 skip |
| `git diff --check` | 退出 0 |

平台补充验证沿用 E4-T08 的真实应用入口、隔离数据库及五阶段测试驱动；新增断言检查原始多行备注从草稿恢复、保存后首尾空白归一、编辑时原备注不提前改写、冲突失败保留编辑备注，以及更正后重启读回。

| 平台 | 环境与实际操作 | 结果 |
| --- | --- | --- |
| Android | `Medium_Phone` 模拟器，Android 13 / API 33；run ID `e4t09_android_20260929_01`；`python tool/e4_t08_relaunch_android.py --run-id e4t09_android_20260929_01 --device emulator-5554`，四次 `am force-stop` 并重新启动 Activity，不卸载或清数据 | 五阶段通过，脚本退出 0 |
| Web | Chromium `153.0.8010.52`、同版本 ChromeDriver、临时独立 profile；同一 `http://127.0.0.1:7358/` 标签页，run ID `e4t09_web_20260929_01`；`python tool/e4_t08_refresh_web.py --url http://127.0.0.1:7358/ --run-id e4t09_web_20260929_01` 四次实际刷新 | 五阶段通过，脚本退出 0 |

初次全套测试有一项既有交互断言因新增输入框改变页面滚动位置而未找到顶部字段提示；调整测试滚动回顶部后，该测试单独重跑通过，最终全套测试通过。没有因此改动领域规则或扩大 UI 功能。

## Self-review / Blockers / Open Questions

已检查本次 Dart 修改、新增平台断言、旧草稿升级路径、`TASKS.md` 状态及原有工作区改动。草稿允许超长原始输入留存，正式提交由表单和既有 TimeBlock 领域校验限制；换行不被压缩，可选空白最终成为 `null`。正式更正只更新本次展示的字段，未展示的 Goal、category、annotation 仍由现有 repository 保留。

无 blocker 或新增 Open Question。首发平台的本任务受影响恢复路径已复验；未做其他平台、睡眠备注或发布验收。工作区原有未提交和未跟踪改动均保留。

## Next executable task

当前 `TASKS.md` 在 E4-T09 后只有 Epic 5–10 待细化工作包，没有可直接执行的下一 Task ID。后续需要用户明确指定细化或执行范围；本次到 E4-T09 为止。
