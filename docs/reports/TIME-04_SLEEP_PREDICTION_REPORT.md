# TIME-04 — 个人睡眠初值与多日空白修复

日期：2026-10-07。基准HEAD：`55bca80`；工作区已有TIME-01 / TIME-02 / TIME-03及其他线程未提交变更。本报告只描述本轮增量，未提交Git。

**结果：本任务范围实现与验证完成。** 用户截图的根因是生产睡眠入口复用TIME-01通用Gap建议，把10月4日22:13到7日06:54全段当成一次睡眠。现改为独立睡眠模型；无历史时该场景直接预填10月6日23:00–7日07:00。用户已明确选择“采用推荐模型与参数”，来源见Q-037与[任务定义](../planning/SLEEP_TIME_PREDICTION.md)。

有历史分别学习主睡眠 / 小睡的循环本地时刻和完整实际时长，保留昼夜多峰；不以createdAt把补录旧睡眠当成新作息，也不因长时间未打开自动抹掉原模式。未来结束的睡眠暂不训练。默认主睡眠保留本地23:00–07:00，夏令时实际时长可为7 / 9小时；无历史小睡取最近实际30分钟。

进入固定时刻、事实和两种类型的初值，立即写缓存；重新进入重算，备注 / 类型保留。同次重复初始化不覆盖时间，切换类型用同一快照，已手调端点不覆盖。预测只产生编辑输入，提交才写正式事实，旧Gap与Unknown分层不变。

## 模型与存储

- 样本选择采用56天 / 最多60条、14天半衰期、90分钟循环时刻核、0.25对数时长核、先验量2与1 / 0.5 / 0.1来源权重。每端分别限制弱反馈至独立证据20%，无独立证据时不自行强化；优先保留独立样本，原样预测不会挤走过去作息。
- 首版用历史联合模板及默认模板评分；宽先验的3倍带宽是工程平滑实现，非合法时长规则。今日比较最近已结束 / 当前睡眠，历史 / 未来日期以所选醒来日定位。真实占用只调整新估计，完整时长移到边界；无合适位置则保留完整冲突估计供手改，不将主睡眠压成几分钟，不移动正式事实。
- 学习元数据与正式事实分开，睡眠草稿专用数据库从v2升级到v3，保留v1 / v2原输入。保存模型初值、实际提交值、版本和每端当地UTC offset；正式五表schema仍为2。更正后按当前端点重新赋权，删除后不再训练。
- 正式睡眠先按原原子不重叠合同提交，再在辅助库同一事务保存反馈 / 清草稿。辅助失败保留草稿，重新进入先识别已提交事实、重试收尾，禁止重复创建。高级数据清空包含辅助反馈；普通放弃不删除既有反馈。

## 修改文件

| 职责 | 文件 |
| --- | --- |
| 纯预测与学习合同 | 新增`ledger/domain/sleep_prediction.dart`、`sleep_learning_store.dart`；更新`sleep_draft_store.dart`、`ledger_repository.dart` |
| 完整历史 / 辅助存储 | `ledger/data/drift_ledger_repository.dart`、`drift_sleep_draft_store.dart` |
| 预测加载 / 提交收尾 | 新增`ledger/application/sleep_time_prediction_loader.dart`；更新`sleep_entry_saver.dart`，通用旧建议注释标明兼容用途 |
| 生产日期适配 / 接线 / 缓存 | 新增`app/time/device_sleep_prediction_calendar.dart`；更新`app_bootstrap.dart`、`sleep_entry.dart`、`sleep_submission.dart`及`sleep_form_controller.dart` |
| 行为与存储验证 | 新增3个模型 / loader / 日历测试；更新自动化、睡眠草稿、生产入口测试和Web集成 |
| 决定与追溯 | 源提案、Q-037、DOMAIN_RULES、DATA_ARCHITECTURE、算法设计稿、TASKS、文档台账、任务定义及本报告 |

没有新增依赖、正式事实字段、进行中状态或时长上限。TIME-03活动5小时 / 60分钟规则和Q-038独立日期时间编辑保留。修改相对于本轮文件副本检查，保留其他线程变更。

## 实际验证

使用已安装Flutter SDK工具snapshot，前缀：

```sh
FLUTTER_ROOT=/kiyodata/Projects/00-develop/flutter FLUTTER_ALREADY_LOCKED=true \
/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart \
/kiyodata/Projects/00-develop/flutter/bin/cache/flutter_tools.snapshot \
--suppress-analytics --no-version-check <子命令>
```

| 命令 / 范围 | 最终结果 |
| --- | --- |
| `test --no-pub`下列13文件，`--reporter expanded` | 退出0，101通过，无失败 / 跳过 |
| `TZ=America/New_York ... test --no-pub test/app/time/device_sleep_prediction_calendar_test.dart --reporter expanded` | 退出0，3通过：春季 / 秋季冷启动钟点、重复当地时刻的小睡绝对时刻 |
| 全仓库`analyze --no-pub`最终代码 | 退出0，No issues found |
| SDK `dart format --output=none --set-exit-if-changed`本轮21个Dart文件 | 退出0，0文件改变 |
| `drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/time_automation_test.dart -d web-server --web-port=7458 --browser-name=chrome --chrome-binary=/usr/bin/chromium --driver-port=4456 --browser-dimension=390x844 --headless --timeout=180` | 退出0，真实Web SQLite、草稿关闭重开、独立预测、跨年 / 毫秒保持、手调、正式保存、辅助反馈与清草稿通过 |
| 本轮Markdown相对链接 / Q编号检查、`git diff --check` | 通过 |

13文件参数：

```text
test/features/ledger/domain/sleep_prediction_test.dart
test/app/time/device_sleep_prediction_calendar_test.dart
test/features/ledger/application/sleep_time_prediction_loader_test.dart
test/features/ledger/application/recording_time_automation_test.dart
test/features/ledger/application/sleep_entry_saver_test.dart
test/features/ledger/application/sleep_entry_editor_test.dart
test/features/ledger/application/recording_entry_editor_test.dart
test/features/ledger/data/sleep_draft_store_test.dart
test/features/ledger/data/sleep_ledger_read_test.dart
test/features/ledger/presentation/sleep_form_controller_test.dart
test/features/ledger/presentation/sleep/sleep_recording_page_test.dart
test/features/ledger/presentation/recording_form_controller_test.dart
test/app/sleep_draft_entry_test.dart
```

截图回归先复现失败，再由独立预测通过。第一次扩大回归为99通过 / 1失败：旧生产入口测试寻找已废弃文本框并依赖旧时间恢复 / 无确认放弃路径；同名失败已在TIME-01 HEAD基线记录。此次按本任务当前入口合同更新该测试，验证实际AppBootstrap接线、缓存重算 / 内容保留、磁盘重开和既有放弃确认；未为通过测试改动UI行为。最后增加辅助损坏数据检查后101全部通过。

本轮覆盖截图、多日断记、漏睡眠、昼间睡眠、午夜相位、多峰、单次熬夜、小睡分离、长睡眠、弱反馈、自身预测不挤走旧模式、正式占用、缓存 / 类型切换 / 手调、两版旧库迁移及真实提交失败恢复。真实用户80%覆盖率 / 边界准确率尚未测量；更细的星期条件、模式变化、其他活动估计及变形求解仍为未决范围。未重跑全仓库测试或Android设备实测，不改变其他任务历史验收结论。
