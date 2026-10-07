# HOME-NAV-03 · 首页切换动效与闪烁修复

2026-10-07。本轮实现与相关验证完成；全仓库仍有103项既存失败，真实设备动效观感 / 帧率未实测。

用户在HOME-NAV-02后反馈“当前缺少动效，切换的时候很多数字和文字还会闪烁”，授权继续修复首页表现。依据见[方案](../planning/HOME_NAV_MOTION.md)、[Q-027](../domain/OPEN_QUESTIONS.md#q-027)与[Source of Truth](../../time-ledger-domain-model-v4-proposal.md)。先委派code_mapper只读定位切日 / 焦点 / 阅读锚点路径，再由主agent检查证据、实现和验证，保留其他agent已有改版。

## 原因与结果

显式切日的目标定位与旧锚点恢复在同一轮布局中同时执行，且jumpTo后立即用上一布局的坐标更新焦点，导致顶部日期 / 当日统计短暂回到旧日；数字和文字此前直接替换，也没有过渡。

| 位置 | 最终行为与涉及文件 |
| --- | --- |
| 时间轴定位 | `home_timeline_tab.dart`用单一布局协调过程，显式定位优先于旧锚点恢复，移动后等待下一布局再更新焦点。目标轴完成定位后才绘制；退出轴不读取新定位请求、不反写焦点。 |
| 时间轴切日 | 新`home_feed_transition.dart`用220ms / easeOutCubic按日期方向左右平移。新旧页面保持相邻、不透明，防止文字重影；退出层禁止操作及读屏，结束后移除。`ledger_feed_controller.dart`增加只读窗口快照，`home_shell.dart`接入。相同窗口刷新继续使用原State及阅读锚点。 |
| 日期 / 星期 / 时长 | 新`home_value_transition.dart`提供160ms裁剪上下切换，`home_day_header.dart`与`home_coverage_line.dart`使用固定日期 / 数值行高，标签和按钮稳定。同值重建不动画；仅显示真实日期与统计值，不插值生成中间时长。 |
| 建议卡 | `home_suggestion_card.dart`保持底纸与点击入口稳定，内容上下过渡，高度用AnimatedSize平滑变化，避免底纸淡出露出时间轴文字。 |
| 系统关闭动画 | 全部新增动效尊重`MediaQuery.disableAnimations`，无需等待动画时长；退出文本不参与读屏。 |

保持HOME-NAV-02的失败保留 / 原目标重试、待装载日期连续导航、午夜跟随及独立页日期 / 草稿合同。Unknown、Gap、跨日事实及统计公式均未改变，没有新增依赖或修改数据库 / 持久化事实。摘要、复盘及其他编辑页动效不在本轮范围。

## 回归证据

新增8项正式测试，相关测试共72项通过：

- `test/app/home_motion_test.dart`新增6项：逐帧焦点与真实数值、退出快照 / 触控 / 实际语义树隔离、左右方向及页面相邻、同值刷新保留State和滚动位置、定位前 / 动画中快速反向、关闭动画直接完成、320宽大字跨年切日无异常。
- `test/features/ledger/presentation/ledger_feed_controller_test.dart`新增1项：退出窗口快照不随后续提交改变。
- `test/app/home_feed_nav_capture_test.dart`新增1项：真实字体下前 / 后一天逐帧捕获，检查每帧焦点且无布局异常；原窄屏大字截图断言继续通过。

`test/support/home_feed.dart`更新为读取动画中的当前值；`test/app/home_feed_flow_test.dart`的装载夹具支持关闭动画。以上5个测试 / 支持文件与8个生产文件是本轮Dart修改范围。

## 实际验证

均在仓库根目录执行，测试时区为Asia/Shanghai。

| 检查 | 结果 |
| --- | --- |
| 本轮13个Dart文件，`dart format --output=none --set-exit-if-changed` | 退出0，0 changed |
| `flutter analyze --no-pub` | 退出0，No issues found |
| 下方12个相关测试文件 | 72项全部通过 |
| `TZ=Asia/Shanghai flutter test --no-pub --reporter json` | 800通过、7跳过、103失败，退出1；全量基线未通过 |
| 失败集合比对（文件 + 用例名） | 与HOME-NAV-02的103项失败完全一致，无新增或消失的失败；此前已与改版工作区及HEAD基线核对一致 |
| `flutter build web --no-pub` | 退出0，生成build/web，Wasm dry run成功 |
| `flutter build apk --debug --no-pub` | 退出0，生成build/app/outputs/flutter-apk/app-debug.apk |
| `git diff --check` | 退出0 |

相关测试实际命令：

```sh
TZ=Asia/Shanghai R1_CAPTURE_DIR=/tmp/timepet-home-motion-capture flutter test --no-pub test/app/home_feed_flow_test.dart test/app/home_navigation_flow_test.dart test/app/home_r1_visual_test.dart test/app/home_feed_nav_capture_test.dart test/app/home_suggestion_entry_test.dart test/app/review_context_entry_test.dart test/app/review_form_entry_test.dart test/app/review_submission_flow_test.dart test/app/review_draft_storage_test.dart test/features/ledger/presentation/home_summary_donut_test.dart test/features/ledger/presentation/ledger_feed_controller_test.dart test/app/home_motion_test.dart --reporter expanded
```

会话日志：`/tmp/timepet-home-motion-{focused.log,analyze.log,full.jsonl,web-build.log,apk-build.log}`；失败集合及比对结果为`/tmp/timepet-home-motion-failures.txt`和`/tmp/timepet-home-motion-comparison.json`。没有为取基线重置工作区。

## 视觉证据与限制

[动效慢放预览](assets/home-motion/home-date-motion.gif)由实际组件测试的37张截图合成，包含前一天和后一天，GIF合并相同画面后为35帧。每个16ms采样画面显示40ms，约2.5倍慢放，起点 / 两次终点额外停留，便于查看过渡；生产时长仍是220ms / 160ms。

已查看的静帧：[起点](assets/home-motion/motion-00.png)、[前一天过渡](assets/home-motion/motion-05.png)、[前一天终点](assets/home-motion/motion-18.png)、[后一天过渡](assets/home-motion/motion-23.png)、[返回起点](assets/home-motion/motion-36.png)、[320大字](assets/home-motion/home-320-large-text.png)。最终时间轴页面相邻且没有整页文字交叠，日期 / 数值行框稳定，建议卡保持不透明底纸。

组件逐帧测试和构建不等于真机或浏览器交互验收；本轮未安装APK、未部署Web、未测真实设备帧率。103项既存失败仍需其原迁移任务处理。Web的CupertinoIcons字体提示和Android的Java native access提示为非阻断警告，没有为此改依赖或环境。保留用户及其他agent已有改动，未提交或创建PR，不推进其他任务。
