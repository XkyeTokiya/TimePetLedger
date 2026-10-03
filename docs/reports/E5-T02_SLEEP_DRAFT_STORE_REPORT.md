# E5-T02 — 实现睡眠本机草稿存储

**Task / Status：E5-T02 / COMPLETE。** 日期：2026-09-29。

## 依据与前置

已核对共同必读 SOT / AGENTS / OQ / MVP / PLAN、Task 全文，MODEL / UI Models、DATA / 本机输入草稿、PLAN / 输入草稿共同交付合同。Q-012、Q-022 为 DECIDED，无冲突。E2-T02 依据[持久化接入报告](E2-T02_PERSISTENCE_CONNECTION_REPORT.md)及现有 connectDatabase；E1-T04 依据[负责人完成记录](EPIC_0_1_COMPLETION.md)及 SleepSession / 校验实现。委派 code_mapper 有界只读定位，主 agent 核对并实现。

## Changes

- [sleep_draft_store.dart](../../lib/features/ledger/domain/sleep_draft_store.dart)：睡眠专用 DTO、上下文、read/save/clear 与显式存储 / 损坏异常。新建按入口日期隔离，编辑按 SleepSession 身份隔离，跨入口日期仍读取同一编辑草稿。
- [drift_sleep_draft_store.dart](../../lib/features/ledger/data/drift_sleep_draft_store.dart)：独立 SQLite 草稿库、原子 UPSERT、严格解码；错误不返回空值或删除损坏行。
- [sleep_drafts.dart](../../lib/app/bootstrap/sleep_drafts.dart)：复用批准的 connectDatabase，以 `time_pet_ledger_sleep_drafts` 独立持久名称打开，调用方拥有连接。
- [sleep_draft_store_test.dart](../../test/features/ledger/data/sleep_draft_store_test.dart)：5 组真实库测试。
- TASKS 与本报告：状态及验证记录。

草稿保留 nullable 起止时间、类型、两端精度，以及原始未完成日期时间文本。null 类型 / 精度表示用户尚未选择，不给正式领域字段设置默认值；可保留零 / 反向区间，不把草稿校验当正式提交校验。文本原样保留，解析的绝对时间由输入层提供，存储层不重新按设备时区解释。没有备注入口或正式表变更。

## Validation

实际命令（仓库根目录，现有依赖）：

- `dart format lib/features/ledger/domain/sleep_draft_store.dart lib/features/ledger/data/drift_sleep_draft_store.dart lib/app/bootstrap/sleep_drafts.dart test/features/ledger/data/sleep_draft_store_test.dart`：退出 0；修正测试 helper 可见性后再次格式化测试文件，退出 0。
- 对上述 4 文件运行 `dart format --output=none --set-exit-if-changed`：退出 0，0 changed。
- `flutter analyze --no-pub`：最终退出 0，No issues found。首次发现测试 helper 暴露私有类型，已改为私有 helper 并复验。
- `flutter test --no-pub test/features/ledger/data/sleep_draft_store_test.dart test/features/ledger/data/recording_draft_store_test.dart`：退出 0，12 项通过（睡眠新增 5 组）。
- `git diff --check`：退出 0。

真实文件库验证写入→关闭→重开→清除→重开；日期和编辑身份隔离、全部原始字段及未选择状态保留。真实 SQLite trigger 使更新 / 删除失败，重开仍保留旧草稿；关闭连接、无效路径、未知版本和损坏日期 / 身份 / 枚举 / 物理类型均显式失败。独立草稿操作前后正式五表（均填有记录）及普通草稿不变；睡眠摘要只读正式睡眠；与草稿重叠的正式写入成功，正式事实冲突仍拒绝。

## Self-review

核查全部新增文件、SQL 字段与绑定顺序、严格解码、上下文 key、独立连接所有权和失败原子性。以本轮开始 SHA-256 对照，代码验证完成时既有文件均未改变；随后仅更新 TASKS 和新增报告。保留全部既有工作区修改；未改普通草稿、正式 schema、依赖或投影。未执行平台关闭应用 / Web 刷新验证，按 Task 留 E5-T08。

## Blockers / Open Questions

无。所有适用验证通过。

## Next executable task

E5-T03 — 实现独立睡眠表单与草稿生命周期。E5-T01 已完成，本任务已验证通过；按用户本轮明确授权继续执行 E5-T03，不扩展到 E5-T04。
