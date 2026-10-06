# TIME-01 活动与睡眠时间自动化交付

日期：2026-10-07（Asia/Shanghai）。基准HEAD：`55bca8017c98377343760c844b25f187dbd01e77`。状态：实现已交付，平台验收未完成；不标COMPLETE，未提交Git。

## 行为与依据

依据用户本轮决定、源提案后续决定、Q-032 / Q-035及DOMAIN_RULES。新建 / 补记不恢复旧缓存端点：闭区间取前后完整事实边界；已知起点的尾部结束为`max(打开时当前时刻, 起点+30分钟)`；全开区间由用户本次填写。事项、备注、目标与睡眠类型保留，同次编辑稳定。既有事实更正与提交后收尾恢复继续使用自身输入 / 提交结果。

跨自然日读取活动、Unknown、主睡眠与小睡邻居，不用午夜或08:00推断边界，也不按昼夜猜睡眠类型。普通活动新建使用尾部 / 手动；明确Gap补记使用前后记录，睡眠补记优先闭区间。已知闭区间不被当前时刻截断；普通新建的30分钟初值会跨入已知记录时转手动，不生成明知重叠的初值。

生产活动 / 睡眠两端编辑弹层已删除。点击单端点直接选时分，随后接日历；日历自动定位合适日期，两组件完成即更新当前缓存，取消任一步不应用。时长支持固定开始推算结束、固定结束反推开始，跨日 / 跨年保留完整日期。调整一端不舍入另一端的毫秒边界。

## 文件范围

| 职责 | 文件 |
| --- | --- |
| 完整相邻事实读取 | `lib/features/ledger/domain/ledger_repository.dart`、`lib/features/ledger/data/drift_ledger_repository.dart` |
| 初始化计算与加载 | `lib/features/ledger/application/recording_time_suggestion.dart`、`recording_ledger_loader.dart` |
| 生产入口接线 | `lib/app/main_app.dart`、`lib/app/bootstrap/app_bootstrap.dart`、`sleep_entry.dart` |
| 当前编辑缓存 | `lib/features/ledger/presentation/recording_form_controller.dart`、`sleep_form_controller.dart` |
| 时间 / 日期 / 时长组件 | 新增`lib/features/ledger/presentation/recording_time_picker.dart`；删除`presentation/activity/activity_time_sheet.dart` |
| 当前页面 | `lib/features/ledger/presentation/activity/activity_recording_page.dart`、`presentation/sleep/sleep_recording_page.dart` |
| 验证 | 新增`test/features/ledger/application/recording_time_automation_test.dart`、`test/features/ledger/presentation/recording_time_picker_test.dart`、`integration_test/time_automation_test.dart`；更新活动 / 睡眠当前页面与两个控制器测试 |
| 需求与交接 | 源提案、DOMAIN_RULES / MODEL、OPEN_QUESTIONS、PRODUCT_PRINCIPLES、DATA_ARCHITECTURE、TIME_RECORDING_AUTOMATION、UI_REBUILD_PLAN、TASKS、DOCUMENT_REGISTER与本报告 |

无依赖、schema、旧事实精度迁移或额外进行中生命周期。历史样板及其Q-023建议函数保留，并标注其历史职责；当前生产入口使用Q-035。

## 实际验证

环境中的Flutter包装脚本在受限文件系统下尝试更新SDK stamp，因此实际Flutter调用使用已安装工具的snapshot，无安装或升级。调用前缀为：

```sh
FLUTTER_ROOT=/home/tokiya/Projects/00-develop/flutter FLUTTER_ALREADY_LOCKED=true \
/home/tokiya/Projects/00-develop/flutter/bin/cache/dart-sdk/bin/dart \
/home/tokiya/Projects/00-develop/flutter/bin/cache/flutter_tools.snapshot \
--suppress-analytics --no-version-check <下述子命令>
```

| 命令 / 检查 | 实际结果 |
| --- | --- |
| SDK内`dart format --output=none --set-exit-if-changed`全部19个新增 / 修改Dart文件 | 退出0，0文件需要重排 |
| `analyze --no-pub`全部19个改动文件；最后缓存调整后再分析4个相关文件 | 均退出0，无问题 |
| `analyze --no-pub`全仓库 | 退出1，只有`guided_recording_test.dart:33 / :256`两个既有`curly_braces_in_flow_control_structures` info；该文件未修改 |
| `test --no-pub`下方相关套件 | 退出0，133通过，2按时区条件跳过 |
| 缓存初始化最终调整后，两个控制器、提交控制器和当前活动 / 睡眠页面共5个文件再验 | 退出0，29通过，含新增2项“手动区间不恢复旧端点”用例 |
| `drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/time_automation_test.dart -d web-server --web-port=7396 --browser-name=chrome --chrome-binary=/usr/bin/chromium --driver-port=4444 --browser-dimension=390x844 --headless --timeout=180` | 最终版本退出0；跨年相邻读取、真实Web草稿关闭重开、重算起止保留备注 / 类型、时间接日期、稳定编辑、正式保存与清草稿通过 |
| 扩大回归，加入旧应用闭环与旧睡眠提交 / 编辑界面用例 | 141通过、2跳过、20失败；在`git archive HEAD`临时副本运行对应旧用例，同名20项全部复现，无新增失败名称 |
| `git diff --check`与新增文档链接 / Q编号检查 | 通过 |
| `adb devices` | 无连接设备，Android实测未执行 |

相关套件命令参数：

```text
test --no-pub
  test/features/ledger/application
  test/features/ledger/data/ledger_read_test.dart
  test/features/ledger/data/sleep_ledger_read_test.dart
  test/features/ledger/presentation/recording_form_controller_test.dart
  test/features/ledger/presentation/sleep_form_controller_test.dart
  test/features/ledger/presentation/recording_submission_controller_test.dart
  test/features/ledger/presentation/recording_time_picker_test.dart
  test/features/ledger/presentation/activity/activity_recording_page_test.dart
  test/features/ledger/presentation/sleep/sleep_recording_page_test.dart
```

跳过项为既有`day_ledger_loader_test.dart`和`sleep_ledger_loader_test.dart`的特定时区用例，本轮未声称其通过。新组件测试包含320×640、360×800及2倍文字，不出现布局异常。

Web使用现有正式连接工厂、独立测试库及临时浏览器，关闭后重开真实草稿连接；未验证浏览器刷新或Android重启。本机SQLite测试覆盖空上下文、午夜裁剪扩展、长跨日邻居、30分钟不足 / 等于 / 超过、昼间睡眠、未来已知邻居、过期Gap、读取错误与保存 / 更正 / 删除。正式跨事实冲突仍由既有原子写入检查。

日志与失败名称对照见[证据目录](assets/time01/)。全仓库既有失败不在本轮修复范围，Android设备验证仍需后续实际环境；不得将本次交付视为全仓库或全部平台验收通过。
