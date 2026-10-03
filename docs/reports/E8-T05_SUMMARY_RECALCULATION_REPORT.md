# E8-T05 — 验证摘要随事实与解释变化重算

**Task / Status：E8-T05 / COMPLETE。** 日期：2026-10-02。

## 依据与依赖

核对 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，以及 PLAN / Epic 8、DERIVED / 同一窗口可核对关系、APP / 写入后重读与失败处理。E8-T02–E8-T04、E7-T06、E6-T05 的完整定义、COMPLETE 报告与现有代码 / 闭环测试已核查。相关日期、精度、睡眠、解释、保存、草稿和摘要合同均已决定，无来源冲突或新产品阻塞。

按 AGENTS 委派 code_mapper 有界只读定位既有实际 UI helpers、文件库闭环和提交后故障拦截器；主 agent 检查证据后复用并负责测试实现、自审和最终验证。

## Changes

- `test/app/day_summary_recalculation_flow_test.dart`：新增2项真实文件 SQLite + AppBootstrap UI 集成场景，串联事实 / 解释操作、摘要检查点、路由返回、时钟推进、读取失败与重试，以及连接 / 应用重开。
- TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告：完成索引、完整定义归档、Epic 局部状态与证据。

没有发现必须修复的生产缺陷。未修改生产代码、前序测试、领域计算、持久化 / 草稿 schema、依赖或平台配置；没有统计缓存事实源、复盘数值写回或后续 Task 实现。

## Acceptance evidence

### 历史日手算混合场景与 UI 操作

正式库、普通草稿与睡眠草稿均使用隔离真实 SQLite 文件。通过实际首页 / 表单创建 Goal、跨日主睡眠、known / Unknown 普通事实、Goal stuck 记录与无 Goal recovery。固定区间以10月1日凌晨表达：睡眠覆盖00:00–01:00，Goal无解释01:00–02:00，Unknown02:00–02:30，Gap02:30–03:00，Goal stuck03:00–03:30，全局无Goal recovery03:30–04:00。历史窗口继续取完整自然日，不把领域示例的局部4小时窗口当成应用日期政策。

初始已交代210分钟、其中未知30分钟、未记录1230分钟（内Gap30 + 04:00后的1200）；完整跨日主睡眠约120分钟，日覆盖睡眠60分钟；Goal相关90分钟、无解释60分钟、stuck30分钟、全局recovery30分钟。

- 通过普通表单保留带Goal / progress的未提交输入，再通过睡眠表单保留未提交nap；正式五表逐行不变，摘要值不变。随后从实际表单主动放弃草稿。
- 从实际日账本打开同一完整普通记录，依次添加progress、更正为stuck、移除解释、再添加recovery。已交代 / Unknown / Gap及Goal总量不变；progress、stuck、recovery、无解释参与集每次按新解释重算，目标内恢复已包含在全局恢复。
- 将第一条普通记录结束时间缩短30分钟，产生新Gap；删除Unknown后unknown变为零，Gap增加。相关Goal总量随源区间更正，不累加旧解释。
- 将主睡眠通过实际完整表单更正到下一醒来日期，两日重新进入摘要：原日主睡眠缺失但仍有入睡日切片，新日完整约120分钟而覆盖精确60分钟。删除主睡眠后覆盖与缺失表达更新。
- 实际创建并删除nap，验证小睡合计、覆盖及Gap随事实变更。Goal通过实际管理页改名 / 归档后，摘要读取当前名称 / archived状态，旧投影不变。
- 最终历史日已交代90分钟、Unknown0、Gap1350、Goal相关60、stuck30、全局recovery60。卸载完整bootstrap、关闭连接并从文件重开后同一摘要保持一致。
- 预置一份正式DailyReview作为保护夹具，所有事实和解释变化后其SQL全行保持原样，没有统计写回或反思改写。

每个检查点核对毫秒分区、Unknown子集、Goal四项之和，并逐项比较覆盖 / Goal / 全局节奏格式映射文案。SleepSummaryView、GoalRhythmSummaryView的输入与当前同一DayLedgerView里的结果为同一对象；完整结果签名（窗口、时长 / 存在性 / 近似、Gap、完整睡眠记录、Goal元数据与四项、全局节奏）与当前createDayLedgerLoader重读一致。

### 当前日、返回链路与读取重试

- 通过实际普通表单保存10:00–11:00的一小时known事实；只在SQLite创建事务成功提交后触发读取失败。页面明确“已保存”、移除再次提交按钮。故障期间收尾重试及解除后的重试不写入正式事实，SQL审计仅一次TimeBlock INSERT。
- 首页实际进入摘要；为验证已有didPopNext链路，测试将从首页真实组装的DayLedgerPage推到摘要上方（没有新增产品编辑入口），通过实际时间轴打开普通编辑器并添加progress。编辑器返回日账本、再返回原摘要，摘要自动重读并显示全局progress60分钟；旧投影依然无progress。
- 将注入now从12:00推进到13:00并令真实库窗口查询失败：摘要显示可重试错误、controller.view为null、睡眠和Goal组件均消失，旧快照不冒充成功。
- 故障期间重试仍失败，解除后只读重试得到新窗口：已交代60、Unknown0、Gap720、progress60。正式五表及全部INSERT / UPDATE / DELETE计数在摘要重试前后不变，没有重复创建或更正。

故障拦截器只控制实际查询时机，不mock事实 / 写入结果或投影；所有SQL写入、约束和事务真实执行。新测试和广回归检查无评分 / 效率 / 因果文案；已有loader双连接一致性测试在广回归中通过，支持同一读取事务下正式事实 / 解释 / Goal元数据不混用不同提交快照。跨日普通源更正与删除亦由既有应用回归覆盖，本轮新增跨日操作重点为完整睡眠迁移。

## Validation

仓库根目录使用现有SDK / 缓存依赖，无安装或更新。

| 实际命令 | 最终结果 |
| --- | --- |
| `dart format test/app/day_summary_recalculation_flow_test.dart` | 退出0 |
| `dart format --output=none --set-exit-if-changed test/app/day_summary_recalculation_flow_test.dart` | 退出0，1文件，0 changed |
| `flutter analyze --no-pub` | 最终退出0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/app/day_summary_recalculation_flow_test.dart` | 最终退出0，2项通过，无跳过 |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger test/features/goals test/app test/core/time` | 退出0，545项通过，3项按既有时区条件跳过 |
| `git diff --check`、开始前SHA-256对照、文档链接 / 归档检查 | 通过 |

首轮集成2项通过；静态分析发现新测试未使用导入和条件语句缺少大括号，修正后分析通过。补充睡眠草稿、既有复盘保护及逐项UI文案断言后重跑定向及相关回归，全部通过。3项skip是上海时区不满足的既有DST条件场景，本轮未执行，不记为通过。

日志 `/tmp/e8_t05_analyze_final.log`、`/tmp/e8_t05_target_final.log`、`/tmp/e8_t05_regression.log`。广回归中的既有独立数据库连接测试可能输出Drift多实例debug提示，测试通过，不关闭全局提示掩盖问题。

## Self-review

检查新增测试全文、真实应用操作路径、隔离文件库 / 草稿、原事实身份、同快照组件输入、手算与实际投影、提交后故障时点、只读重试写次数、原复盘、生命周期释放及重开结果。开始前记录已有文件SHA-256，代码验证结束对照没有任何已有文件变化；随后只更新三份规划文档并新增报告。保留所有原有工作区改动与未跟踪文件，无无关格式化或依赖变动。

## Blockers / Open Questions

无阻塞，无新增未决问题。没有执行Android实际关闭重开 / Web浏览器刷新或真实系统时区切换；文件重开及本机Flutter UI证据不外推为两平台验收。E8-T06仍保留平台验证门槛，Epic 8未标完成。

## Next executable task

E8-T06 — 验证 Android 与 Web 基础摘要。前置E8-T05、E7-T07、E5-T08、E6-T06有完成依据；执行时仍须核对实际平台环境及完整Epic依赖。仅报告，不执行；本次完成E8-T05后停止。
