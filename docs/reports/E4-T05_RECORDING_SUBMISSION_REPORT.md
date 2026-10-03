# E4-T05 — 接通正式新建保存、冲突反馈与刷新

## Task / Status

**COMPLETE（2026-09-29）。** 仅执行 E4-T05，未执行 E4-T06。E4-T04 已标 COMPLETE 并有表单报告；E2-T06 的 [原子写入报告](E2-T06_ATOMIC_LEDGER_WRITE.md)、`LedgerRepository.createTimeBlock`、Drift 事务实现及真实库测试均已核对。Q-011、Q-012、Q-018 为 DECIDED，没有阻塞性 Open Question。

依据 Source of Truth 的 TimeBlock、Gap / Unknown 和主轴不重叠结论，以及 DOMAIN_RULES / TB-001–009、LEDGER-004、DATA_ARCHITECTURE / 事务与重叠、APP_ARCHITECTURE / 写入失败处理、IMPLEMENTATION_PLAN / Epic 4。本次没有改变领域模型、数据库 schema 或依赖。

## Changes

| 文件 | 本任务修改 |
| --- | --- |
| `lib/features/ledger/application/recording_entry_saver.dart` | 新建提交协调：注入 UUID v4 与 now，调用现有原子 `createTimeBlock`；区分未提交、冲突和已提交；已提交后分别尝试清草稿与重读投影；恢复时识别与遗留草稿完全一致的正式事实，仅继续清理刷新 |
| `lib/features/ledger/presentation/recording_form_controller.dart`、`recording_form.dart` | 等待草稿写入队列、校验、锁定提交和防重复点击；失败保留输入，显示冲突类型、身份及完整区间；提交后收尾失败只给清理 / 刷新操作，不再显示创建操作 |
| `lib/app/bootstrap/recording_submission.dart`、`app_bootstrap.dart` | 以安全随机字节生成本地 UUID v4；复用 app 管理的正式库、独立草稿库、设备取时和账本加载器完成组装 |
| `lib/app/main_app.dart` | 保存后接收重读投影，显示已交代、Unknown 子集和本窗口普通记录数量；读取失败单独反馈 |
| `test/features/ledger/application/recording_entry_saver_test.dart` | 真实 SQLite 的 known / Unknown 创建、TB / Sleep 冲突、草稿后事实变化、读回重算、清理 / 刷新失败及重启遗留草稿恢复 |
| `test/features/ledger/presentation/recording_submission_controller_test.dart`、`recording_form_test.dart`、`test/app/bootstrap/app_bootstrap_test.dart` | 失败保留、重复提交、可见冲突、收尾失败与真实启动链路的 Unknown 覆盖刷新 |
| `TASKS.md`、本报告 | 记录 E4-T05 的完成状态与证据 |

`Random.secure()` 的安全随机源与缺失时抛出 `UnsupportedError` 合同见 [Dart 3.13.4 API](https://api.dart.dev/dart-math/Random/Random.secure.html)；未降级为普通伪随机源。正式库仍由 data 层在写事务内复核跨表冲突，不用 UI 预检代替原子约束。冲突不截断、覆盖或移动已有事实。Unknown 正式写入后由原投影计入 accounted，并仅作为其子集显示。

## Validation

在仓库根目录执行：

| 命令 | 结果 |
| --- | --- |
| `dart format`（本任务修改的 10 个 Dart 文件） | 退出 0 |
| `dart format --output=none --set-exit-if-changed`（同 10 文件） | 退出 0；0 changed |
| `flutter analyze --no-pub` | 退出 0；No issues found |
| `flutter test --no-pub test/features/ledger/application/recording_entry_saver_test.dart test/features/ledger/presentation/recording_submission_controller_test.dart test/features/ledger/presentation/recording_form_test.dart` | 退出 0；16 项通过 |
| `flutter test --no-pub test/app/bootstrap/app_bootstrap_test.dart` | 退出 0；6 项通过 |
| `flutter test --no-pub` | 最终退出 0；351 项通过、2 项 skip |
| `git diff --check` | 退出 0 |

首轮相关测试曾因测试使用对象同一性比较持久化读回对象、以及新增按钮使旧 widget 测试目标延迟构建而失败；修正断言与滚动定位后相关测试和全量测试通过。静态分析曾提示新增 widget 测试的未使用 import，删除后重跑通过。全量测试输出既有 Drift 多实例调试提醒，没有失败。

## Self-review / Blockers / Open Questions

已检查修改差异及新增文件、任务边界、提交和清理的先后顺序、异常分支与草稿恢复。开始前工作区已有大量前序任务的未提交与未跟踪文件；均予保留，没有改动 ledger/data 写入实现、schema、pubspec、平台配置或后续 Task。提交后清草稿与刷新是独立 I/O，失败不会将已提交事实重新标为未提交；重开时同内容、区间、精度和已知性的遗留草稿先比对正式事实，命中后只执行收尾。

无 blocker 或新增 Open Question。本任务的真实持久化集成验证在本机 SQLite 完成；Android 关闭及 Web 刷新后的草稿端到端恢复证据按计划属于 E4-T08，本报告不将其记作已验证。

## Next executable task

**E4-T06 — 接通已有 TimeBlock 更正与删除。** 本次完成 E4-T05 后停止。
