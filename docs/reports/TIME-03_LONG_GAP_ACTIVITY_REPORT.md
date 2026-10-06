# TIME-03 — 长Gap后的活动新建初值交付

日期：2026-10-07（Asia/Shanghai）。基准HEAD：`55bca80`，工作区已有TIME-01 / TIME-02及其他线程未提交修改。本报告仅描述TIME-03本轮增量；未提交Git。

**结果：本任务范围实现与验证完成。** 当前日普通活动新建，真实尾部连续Gap≥5小时时直接初始化最近60分钟。15:20进入即14:20–15:20，完整日期跨日保留；午夜不会重置阈值。没有前序事实时只用当前已知对账窗口。起止直接写入本次编辑缓存，可手调；同次稳定，新会话重算。

初始化只生成编辑输入。提交后只增加用户记录的一笔，较早Gap继续保留；不自动生成Unknown或睡眠。活动、Unknown、主睡眠、小睡均截断真实连续空白。显式Gap、睡眠、历史 / 未来日期、正式更正与提交收尾恢复不扩用该分支。小于5小时的原规则与其他30分钟初值保留。

## 修改与依据

| 文件 / 职责 | 本轮增量 |
| --- | --- |
| `lib/features/ledger/application/recording_time_suggestion.dart` | 正式占用检查之后、旧尾部规则之前，增加Q-037已确认5小时 / 60分钟分支；复用TIME-01完整邻居读取与控制器接线 |
| `test/features/ledger/application/recording_time_automation_test.dart` | 原有9项扩展至20项：毫秒边界、跨午夜、多日断记、无前序事实、四种事实中断、入口排除、真实SQLite缓存 / 提交 / 剩余Gap |
| `test/features/ledger/presentation/recording_form_storage_test.dart` | 纠正旧缓存端点优先的过期前提；保留磁盘持久化断言，重进保留内容、时间重新初始化，并检查正式事实未变 |
| Source of Truth、DOMAIN_RULES、OPEN_QUESTIONS、TASKS、算法设计稿与文档台账 | 记录本轮实施授权和职责 / 追溯；Q-037其余参数仍UNDECIDED |
| [任务定义](../planning/LONG_GAP_ACTIVITY_INITIALIZATION.md)、本报告 | 明确TIME-03范围、验收与实际验证 |

未新增依赖、字段、schema或时长限制。保留现有工作区日期 / 时间独立编辑及其他线程修改。源码增量相对于本轮进入时的文件副本检查，未将TIME-01已有未提交改动算成本轮新增。

## 实际验证

Flutter使用已安装SDK的工具snapshot。命令前缀：

```sh
FLUTTER_ROOT=/kiyodata/Projects/00-develop/flutter FLUTTER_ALREADY_LOCKED=true \
/kiyodata/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart \
/kiyodata/Projects/00-develop/flutter/bin/cache/flutter_tools.snapshot \
--suppress-analytics --no-version-check <子命令>
```

| 检查 | 最终结果 |
| --- | --- |
| `test --no-pub`下列8文件，`--reporter expanded` | 退出0，62通过，无失败 / 跳过 |
| `test --no-pub`活动 / 睡眠editor下列2文件 | 退出0，16通过，无失败 / 跳过 |
| `analyze --no-pub`全仓库，最后测试修改后重跑 | 退出0，No issues found |
| SDK `dart format --output=none --set-exit-if-changed`本轮3个Dart文件 | 退出0，0文件改变 |
| 本轮Markdown相对文件链接检查、`git diff --check` | 通过 |

共78项相关测试（新自动化文件20项包含在62项中，不重复计数）：

```text
test/features/ledger/application/recording_time_automation_test.dart
test/features/ledger/application/recording_time_suggestion_test.dart
test/features/ledger/presentation/recording_form_controller_test.dart
test/features/ledger/presentation/recording_form_storage_test.dart
test/features/ledger/presentation/recording_submission_controller_test.dart
test/features/ledger/presentation/sleep_form_controller_test.dart
test/features/ledger/data/ledger_read_test.dart
test/features/ledger/data/sleep_ledger_read_test.dart
test/features/ledger/application/recording_entry_editor_test.dart
test/features/ledger/application/sleep_entry_editor_test.dart
```

首次测试因沙箱禁止本机回环端口未能加载，随后在允许本地通信的环境通过。首次扩大回归为61通过 / 1失败；失败测试注入“旧输入必须优先”的异常，未调用本次算法，与Q-035 / Q-037进入重算合同冲突。纠正上述测试前提后最终62通过；未为通过测试修改控制器或存储行为。

本轮未改UI或平台适配，验证使用真实Native SQLite（含磁盘草稿重开）。未重跑全仓库测试或设备 / Web交互；本任务通过不改变TIME-01 / TIME-02历史平台验收结论。个人睡眠学习、其他活动预测与80%目标验证仍依赖Q-037其余决定，本报告不宣称其已实现。
