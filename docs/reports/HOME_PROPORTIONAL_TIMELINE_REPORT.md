# HOME-TIME-01–04 · 比例首页实施与验证

> 本文保留为首轮实施记录。用户随后提出九点视觉反馈，当前样式与追加验证见[首页视觉细化报告](HOME_TIMELINE_VISUAL_REFINEMENT_REPORT.md)；下文13sp等数字是首轮规格，不能作为当前样式读取。

日期：2026-10-09（Asia/Shanghai）。实施前HEAD：`327f373`。本报告对应当前未提交工作区；不是旧报告所指提交的重验。

首页已采用真实时长比例、展开 / 收起顶部与短段选择。用户先要求整理方案，随后明确“请你开始执行”，并选择Q-040今天靠近当前时刻、历史第一条正式事实。依据为[源提案](../../time-ledger-domain-model-v4-proposal.md)、[Q-039 / Q-040](../domain/OPEN_QUESTIONS.md#q-039)、[获授权方案](../planning/HOME_PROPORTIONAL_TIMELINE_DESIGN.md)和[视觉合同](../../design.md#11-比例首页专项合同2026-10-09q-039)。原图和粘贴原文仍为参考，未经用户采用的建议没有转成产品行为。

## 1. 任务交付状态

| Task | 结果 | 证据与边界 |
| --- | --- | --- |
| HOME-TIME-01 · 固定设计合同 | COMPLETE | Q-039 / Q-040均DECIDED；源提案、设计、任务、交接与台账同步；原参考字节保留 |
| HOME-TIME-02 · 比例日轴与四类状态 | COMPLETE | 同一几何供块、轨道、节点、刻度及边界；Unknown / Sleep / 普通活动 / Gap；半开命中、短段簇及逐段语义 / 键盘路径已有测试 |
| HOME-TIME-03 · 双态壳与阅读定位 | COMPLETE | 32 / 40 / 120dp状态机、日期 + instant + 视口位置锚点、显式切日重设、刷新 / 返回保留、连续手势及窄屏大字回归通过 |
| HOME-TIME-04 · 回归与平台验收 | PARTIAL | 工程回归、Android模拟器及Chromium Web集成、两平台构建通过；TalkBack朗读、人工误触与物理设备验收未执行，不标全部平台 / 无障碍完成 |

本轮没有修改正式领域对象、数据库schema、repository、时间初始化 / 睡眠预测 / 提醒算法或依赖；没有推进其他Task。INPUT-RECOVERY任务状态保留。平台测试仅使用独立命名测试库。

## 2. 实际行为

### 比例、边界与访问

- `p0=72dp / 小时`。20 / 40 / 60 / 80 / 120分钟分别24 / 48 / 72 / 96 / 144dp；正常24小时日1728dp。几何直接使用毫秒，23 / 25小时日按真实窗口长度，不按1440分钟拼接。
- 无逐块min-height、无额外外边距累加、无文字倍率分档扩轴、无用户比例设置。今天只画同次投影的已发生窗口，末端显示实际“现在”；历史末端24:00；未来空窗口没有Gap目标。
- 数据块使用真实矩形；共享边界归后段，窗口起点包含、终点排除。日分隔、按钮、选择行和末端线独立处理，不扩大透明热区或猜测相邻对象。
- 有效高度<32dp的连续短段成簇；单段直接进入原入口，≥2段打开Material 3“时段选择”，行高至少48dp，时间排序，显示范围、类型、标题 / 状态及时长。长段或日边界断簇；簇有“选择”提示。
- Gap传递原日期与完整上下文给现行补记初始化；事实仍进入详情，编辑 / 删除留在详情。选择面板maxWidth560dp；关闭后恢复原段焦点，投影已变化的候选不会路由到失效对象。
- <12dp省略文字，仍保留轨道、节点和状态色；Unknown另有菱形节点 / 问号图标。每段独立语义与键盘焦点，Enter / Space可激活，hover / focus显示行为提示。长块的单个标签保持在可见交集内。

### 双态与定位

展开态保留大日期、完整状态块和情境卡。有效用户纵向阅读离本次起点40dp开始收起、120dp锁定；只有回到32dp以内才展开，32–40dp滞回。收起态保留菜单、日期 / 前后一天、历史日回到今天，以及已交代 / 尚未记录与真实时长；比例条和提醒卡退出绘制 / 触控 / 语义。两个记录入口始终在底部。

阅读起点及恢复位置保存自然日、instant和视口相对位置，按新布局重算。头部变化使用补偿，不取消正在进行的拖动，也不吞掉下一次真实手指位移。程序定位、回弹、刷新、尺寸变化、返回页面及自动跨午夜不引起回展；连续跨日沿原状态。显式箭头、横滑、日期选择、回到今天成功后重设并展开；读取失败保留旧窗口、位置和状态，重试成功后再重设。

Q-040实现：今天将同次读取的当前时刻放在时间轴视口下部，留40dp给末端标记；短窗口从午夜开始。历史日定位到第一条正式事实前8dp，Unknown / Sleep同样适用；无事实历史日从午夜开始。早期Gap仍可向上阅读。

### 窄屏、大字与性能

系统文字正常放大，不再使用首页原有textScaler上限或FittedBox压缩。日期 / 状态 / 操作栏允许换行；高度受限时页头和情境卡内部可滚动，保留正的时间轴视口。320×420、2×文字的控制可达与布局恢复另有测试。

**1.25系数的实测依据：** 使用仓库NotoSerifSC字体，在320dp、2×文字下，20分钟Gap只有24dp，13sp状态词的1.1行高需要约28.6dp，原72比例不显示状态词。对照测试在保持320dp / 2×条件下，仅将全轴系数提高到1.25（90dp / 小时），Gap变为30dp，能显示“尚未记录”。[72比例对照](assets/home-proportional-timeline/a11y-72-320-2.png)、[90比例对照](assets/home-proportional-timeline/a11y-90-320-2.png)和[实测日志](assets/home-proportional-timeline/a11y-evidence.txt)可核对。生产启用条件仅为宽度≤320dp、13sp文字达到2×且测得该状态行高超过24dp；其他矩阵组合仍72。所有轴元素共用同一系数。

密集夹具含14日，每日96个相接5分钟事实。屏幕外日期复用布局与绘制层，仍保留逐段焦点 / 语义；阅读锚点遍历在日分隔 / 日轴处终止，不扫描全部事实后代。单独调试测试中30次指针更新由约6065ms降为1435ms；最终并行回归的耗时受其他测试影响。见[修改前](assets/home-proportional-timeline/density-before.txt)、[修改后](assets/home-proportional-timeline/density-after.txt)。这些是调试构建开销观察，不是release帧率或实机流畅度承诺。

## 3. 修改文件职责

| 文件 | 修改职责 |
| --- | --- |
| `lib/features/ledger/presentation/home/home_timeline_geometry.dart`（新增） | 纯presentation比例、半开几何命中、短段簇；持有原投影引用，不新增事实 |
| `lib/features/ledger/presentation/home/home_reading_state.dart`（新增） | 双态进度、滞回、共享时间起点 |
| `lib/features/ledger/presentation/home/home_day_axis.dart`（新增） | 日轴绘制、可见标签、四类状态、逐段焦点 / 语义与选择面板 |
| `lib/features/ledger/presentation/home/home_timeline_tab.dart` | 用比例日轴替换内容高度列表；时间锚点、真实用户滚动与补偿、窗口恢复 |
| `lib/features/ledger/presentation/home/home_shell.dart` | 共享双态状态、有限a11yFactor、头部 / 情境卡协同、固定操作栏 |
| `lib/features/ledger/presentation/home/home_day_header.dart`、`home_coverage_line.dart` | 大日期 / 紧凑导航、同次投影双指标与覆盖条 |
| `lib/features/ledger/presentation/home/home_suggestion_card.dart` | 窄屏大字下内容与行动分行，不修改建议解析 |
| `lib/features/ledger/presentation/home/ledger_feed_controller.dart` | 区分显式切日和自动跨午夜的阅读重设；保留原子提交、过期请求与失败恢复 |
| `lib/app/theme/home_theme.dart` | 注释明确标准48dp目标与比例数据块例外；未重做主题 |
| `test/app/home_proportional_timeline_test.dart`、`home_timeline_density_test.dart`（新增） | 几何、状态机、命中、短段、失败 / 午夜 / 返回、尺寸、矩阵及密集阅读 |
| `integration_test/home_timeline_platform_test.dart`（新增） | 真实引擎 + 独立SQLite的Android / Web共用入口与返回验证 |
| `test/app/home_feed_flow_test.dart`、`home_motion_test.dart`、`home_r1_visual_test.dart` | 按新几何 / 定位更新原首页相关断言，保留原导航与动效合同 |
| `test/app/home_navigation_flow_test.dart` | 原复盘断言改读Q-012现行会话store，并明确选择继续；正式保存的SQL断言保留，没有改复盘实现 |
| 源提案、`OPEN_QUESTIONS`、`design.md`、方案、UI交接、`TASKS`、文档台账 | 追溯用户新决定、同步任务结果、连接本报告 |

## 4. 验证命令与结果

完整最终命令数组见[commands.json](assets/home-proportional-timeline/commands.json)；以下命令在仓库根目录运行，均exit0。

| 检查 | 结果 / 证据 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed` + 本次17个Dart文件 | 17文件，0变化；[日志](assets/home-proportional-timeline/format.txt) |
| `flutter analyze --no-pub` | No issues found；[日志](assets/home-proportional-timeline/analysis.txt) |
| 下列10个相关测试文件 | **63通过**；[日志](assets/home-proportional-timeline/tests.txt) |
| `flutter test --no-pub integration_test/home_timeline_platform_test.dart -d emulator-5554 --reporter expanded` | **1个端到端场景通过**；真实Android引擎、独立SQLite与指针序列；[日志](assets/home-proportional-timeline/android.txt) |
| `flutter drive --no-pub -d web-server --browser-name=chrome --chrome-binary=/usr/bin/chromium --driver test_driver/integration_test.dart --target integration_test/home_timeline_platform_test.dart --web-port=8765` | 同一端到端场景在Chromium通过，Application finished；[日志](assets/home-proportional-timeline/web.txt) |
| `flutter build web --no-pub` | 成功生成`build/web`；[日志](assets/home-proportional-timeline/build-web.txt) |
| `flutter build apk --debug --no-pub` | 成功生成`build/app/outputs/flutter-apk/app-debug.apk`；[日志](assets/home-proportional-timeline/build-apk.txt) |
| `git diff --check`及本地Markdown链接 / Q编号 / 原参考哈希检查 | 通过；[文档检查](assets/home-proportional-timeline/document-check.json) |

相关测试的实际命令：

```sh
HOME_TIME_CAPTURE_DIR=/tmp/timepet-home-final-captures flutter test --no-pub \
  test/app/home_proportional_timeline_test.dart \
  test/app/home_timeline_density_test.dart \
  test/app/home_feed_flow_test.dart \
  test/app/home_motion_test.dart \
  test/app/home_r1_visual_test.dart \
  test/app/home_navigation_flow_test.dart \
  test/app/home_suggestion_entry_test.dart \
  test/features/ledger/presentation/ledger_feed_controller_test.dart \
  test/features/ledger/application/home_suggestion_test.dart \
  test/app/theme/home_theme_tokens_test.dart --reporter expanded
```

Web验证使用本机Chromium / ChromeDriver 153，驱动命令为`chromedriver --port=4444`，仅绑定本地连接，验证结束后退出本次启动的驱动。最终重跑最初因此前驱动进程已退出而无法创建WebDriver会话；重新启动驱动后，同一完整场景通过。构建日志中的字体查找 / Java告警原样保留，最终命令均exit0。

新增用例涵盖：真实23 / 24 / 25小时窗口、1 / 5 / 10 / 20分钟、恰好32dp及系数变化；共享边界、空窗口和W.end；连续拖动 / 头部补偿、程序定位不回展、有效回原点回展；Gap拆段后恢复同一时刻；失败重试、自动跨午夜、显式切日；逐段语义、键盘进入面板、行高与焦点恢复、失效候选；320 / 360 / 412宽和1 / 1.5 / 2×文字的两态矩阵；多日密集短段阅读。

平台端到端场景实际创建并读取独立测试SQLite事实，检查短段选择→Unknown详情、Gap完整上下文→活动输入、跨日睡眠完整区间、两个记录入口、连续指针收起、菜单→摘要 / 复盘→返回后的状态与时间锚点。输入页进入 / 返回被验证；本场景未另测新事实保存，相关原应用回归仍保留真实保存断言。没有把mock或构建成功替代平台交互。

实施前重新获取的35项相关基线为34通过、1失败，见[基线日志](assets/home-proportional-timeline/baseline.txt)。失败源是复盘旧测试仍读取持久化草稿store，与已决定Q-012冲突；本轮仅更新该测试到现行会话store / 恢复选择，保留正式复盘写入验证。未运行全仓库套件，未沿用其他报告的“103失败”作为本轮基线。相关原测试会打印既存Drift多实例调试警告；平台独立测试库无此警告。

## 5. 视觉证据

截图使用真实仓库字体、360×800等逻辑视口、输出pixelRatio2。它们是widget渲染证据；平台引擎交互证据另见§4。示例为2026-10-07（周三），真实夹具已交代8小时、未记录16小时，没有复制参考图的总量 / 星期。图片中的普通活动使用单一暖色，不从活动名推断类别。

| 逻辑宽度 | 1×文字 | 1.5×文字 | 2×文字 |
| --- | --- | --- | --- |
| 320dp | [展开](assets/home-proportional-timeline/expanded-320.0-1.0.png) / [收起](assets/home-proportional-timeline/collapsed-320.0-1.0.png) | [展开](assets/home-proportional-timeline/expanded-320.0-1.5.png) / [收起](assets/home-proportional-timeline/collapsed-320.0-1.5.png) | [展开](assets/home-proportional-timeline/expanded-320.0-2.0.png) / [收起](assets/home-proportional-timeline/collapsed-320.0-2.0.png)，全轴90 |
| 360dp | [展开](assets/home-proportional-timeline/expanded-360.0-1.0.png) / [收起](assets/home-proportional-timeline/collapsed-360.0-1.0.png) | [展开](assets/home-proportional-timeline/expanded-360.0-1.5.png) / [收起](assets/home-proportional-timeline/collapsed-360.0-1.5.png) | [展开](assets/home-proportional-timeline/expanded-360.0-2.0.png) / [收起](assets/home-proportional-timeline/collapsed-360.0-2.0.png) |
| 412dp | [展开](assets/home-proportional-timeline/expanded-412.0-1.0.png) / [收起](assets/home-proportional-timeline/collapsed-412.0-1.0.png) | [展开](assets/home-proportional-timeline/expanded-412.0-1.5.png) / [收起](assets/home-proportional-timeline/collapsed-412.0-1.5.png) | [展开](assets/home-proportional-timeline/expanded-412.0-2.0.png) / [收起](assets/home-proportional-timeline/collapsed-412.0-2.0.png) |

检查结果：比例边界不随内容高度漂移；日期导航 / 两个记录按钮可达；无水平overflow异常；2×文字允许省略块内次级信息或按钮换行，完整范围 / 时长由语义、tooltip、选择面板和详情提供。实际展开视口仍受历史日回到今天、页头和情境卡占用影响，不能把规划中的约6–7小时当作固定保证。

## 6. 尚未验收的边界

32dp直接访问方案保留了用户明确接受的数据块小指针目标例外：32–48dp数据块及孤立更短段没有宣称符合48×48标准。标准控件和选择行基线、逐段语义与键盘路径已有工程验证；**TalkBack实际朗读、物理设备误触率、release帧率与系统级读屏焦点恢复尚无人工证据**。当前工具没有可用的Android原生UI / 读屏控制面，自动化引擎测试不替代这些检查，因此HOME-TIME-04维持PARTIAL。

未启用48dp严格版，不因尚缺人工验收擅自替换用户决定。下一次仅补验收时，可使用本报告的1 / 5 / 10 / 20分钟密集夹具，对比直达与面板命中、关闭焦点、Unknown形状和大字状态词；若平台要求或误触证据支持改变阈值，再记录该决定。此处是后续验收入口，不授权自动执行其他Task。
