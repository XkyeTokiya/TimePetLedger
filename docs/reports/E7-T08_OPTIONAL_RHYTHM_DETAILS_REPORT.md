# E7-T08 — 提供可选原因与恢复细节入口（Should Have）

## Task / Status

**E7-T08 / COMPLETE（2026-10-02，Asia/Shanghai）。** 仅执行 E7-T08，完成后停止；未执行 Epic 8 或后续任务。

已阅读 AGENTS、完整 Task、共同必读 SOT / OQ / MVP / PLAN，核对 MODEL 的原因 / 恢复值域、STATES 的字段保留、RULES 的解释合同与 DATA 的独立草稿边界。E7-T04 / E7-T05 的完整定义、报告及实际表单、提交、恢复和时间轴编辑入口已核对。Q-005、Q-007、Q-012、Q-015 均为 DECIDED，未发现来源冲突或产品阻塞。按 AGENTS 委派 code_mapper 有界只读定位草稿 / 提交 / 恢复路径，主 agent 检查实际证据后实现、集成与验证。

## Changes

| 文件 | 本次交付 |
| --- | --- |
| [recording_rhythm_input.dart](../../lib/features/ledger/presentation/recording_rhythm_input.dart)、[recording_form.dart](../../lib/features/ledger/presentation/recording_form.dart) | 既有解释编辑器接入原因单选 / 原因说明、恢复方式单选、主观恢复效果单选；“不填写”和“清空原因说明”表达清空意图；只显示当前状态适用细节 |
| [recording_form_controller.dart](../../lib/features/ledger/presentation/recording_form_controller.dart) | 保留原始输入、逐字段修改意图、状态切换与草稿恢复；原因说明反馈调用现有 RhythmAnnotation 领域校验，保留超长输入供修改 |
| [recording_draft_store.dart](../../lib/features/ledger/domain/recording_draft_store.dart)、[drift_recording_draft_store.dart](../../lib/features/ledger/data/drift_recording_draft_store.dart) | 四个可选字段及各自 provided 标记；独立普通草稿 schema v5，v1–v4 事务升级；旧行未提供的字段保留原解释，明确 null 则清空 |
| [recording_annotation_change.dart](../../lib/features/ledger/application/recording_annotation_change.dart) | add / edit 传入已有领域操作；未修改字段省略；恢复匹配包含四个细节，防止仅状态 / 接续点相同便误认提交成功 |
| [recording_rhythm_details_test.dart](../../test/features/ledger/presentation/recording_rhythm_details_test.dart) | 9 项真实 repository + controller / widget 测试，覆盖全部代码、文字、状态保留、边界、清空、写入失败、重试与恢复匹配 |
| [recording_rhythm_details_migration_test.dart](../../test/features/ledger/data/recording_rhythm_details_migration_test.dart) | 3 项真实 SQLite 文件测试：v4 编辑草稿省略字段、明确清空 / 原始输入 / 稳定 id 重开、DDL 失败回滚与重试 |
| [recording_rhythm_test.dart](../../test/features/ledger/presentation/recording_rhythm_test.dart)、[recording_draft_store_test.dart](../../test/features/ledger/data/recording_draft_store_test.dart) | 六向切换断言改为检查实际输入选择，保留正式字段断言；滚动辅助方法避免多行文本吸收拖动；版本探针 / 未来版本夹具及草稿字段比较随 v5 更新 |
| [rhythm_details_platform_test.dart](../../integration_test/rhythm_details_platform_test.dart)、两个 rhythm_details_platform_status 文件、[Android 驱动](../../tool/e7_t08_relaunch_android.py)、[Web 驱动](../../tool/e7_t08_refresh_web.py) | 独立五阶段真实 AppBootstrap 测试，复用前序驱动的实际进程关闭 / 同页刷新机制；使用独立 run 名称，不修改前序平台测试 |
| TASKS、COMPLETED_TASKS、IMPLEMENTATION_PLAN、本报告 | 完成依据、原完整 Task 归档、稳定锚点索引与进度同步 |

已有四处普通记录 / 编辑入口共用 RecordingForm，本次无需修改 app 组装。复用已有 AnnotationChange、LedgerRepository 和真实 Drift 原子写入；没有新增值域、依赖、通用 use-case 或正式 schema。

## Acceptance evidence

- 8 个原因代码、9 个恢复方式代码、3 个效果代码均由 widget 选择后经真实 repository 保存 / 读回；效果的正式 SQLite 字段读回为既定文字代码，没有数值评分或睡眠选项。全部可不填；“其他”不要求补充文字。已有无细节组合测试、明确全部清空的 widget 测试及全回归继续通过。
- 无 Goal 的 Unknown 可创建仅文字原因。首尾空白由既有领域规范化为正式文本或 null，内部换行保留；2000 Unicode 码点（含补充平面字符）成功，2001 拒绝，原始草稿不截断。超长原因切到非 stuck 状态后仍保留并提供切回修改的反馈；不标记则不写解释。
- 六向切换保留已有全部细节；新增原始输入在 stuck / recovery / progress / 不标记之间切换、离开和重开后保持，切回时恢复。只显示适用输入，inactive 字段仍保存供以后更正。各字段独立 provided：明确清空可恢复，未修改字段不覆盖其他写入者的最新值。
- 真实 annotation AFTER UPDATE + RAISE(FAIL) 保证组合写入回滚，正式五表保持原样，细节原文和意图保留；重开后可解除故障并重试。草稿写入故障保留当前输入和上次持久化草稿，尚未保留成功时不提交正式事实。
- 只有细节不同、而事实 / 状态 / 接续点相同的编辑草稿不会被误识别为已提交。新建提交恢复逐一核对原因代码、原因文字、方式和效果；相同稳定 id 的任一细节变化仍不匹配。真正已提交的输入锁定再次提交，继续清理 / 刷新不会重复写正式事实。
- v1–v3 原迁移回归保持；新增真实 v4 编辑草稿带既有 state / hint 意图，升级时四个新标记默认 false，保留原细节。v4→v5 DDL 中途失败回滚新增列，user_version 保持 4，原始行保持，可修复后重试。新库文件关闭 / 重开保留原始超长输入、所有代码、明确清空和稳定 annotation id；主动放弃仅清草稿。

## Android / Web affected recovery

使用已安装工具和独立测试库，固定注入 2026-10-02 12:00，设备 / 浏览器时区 Asia/Shanghai。Android 为 Medium_Phone 模拟器、Android 13 / API 33；Web 为 Chromium / ChromeDriver 153.0.8010.52，单标签页、临时独立 profile。

| 阶段 | 实际验证 |
| --- | --- |
| 1 | 真实平台 v4→v5 草稿升级，旧细节保留；编辑四种细节、离开 / 重开，正式事实保持，留下打开的草稿 |
| 2 | 第一次强停重开 / 同页刷新恢复所有细节；真实 SQLite 触发器导致保存失败，原五表保持，原始失败输入留在草稿 |
| 3 | 第二次恢复失败草稿，解除正式 SQL 故障成功重试；TimeBlock 更新时间保持；明确清空四种细节，离开 / 重开保留清空意图 |
| 4 | 第三次恢复明确清空，切到 progress 后保存仍清空；新建无 Goal 的 Unknown、仅文字原因并保留隐藏原因；正式提交成功而草稿清理失败时锁定重复提交 |
| 5 | 第四次恢复已提交输入，识别全部细节和稳定 id；清理故障继续注入时仍锁定，再解除并只重试清理 / 刷新；五表不重复写入，主动放弃新草稿不改变事实 |

最终 Android run `e7t08_android_20261002_c` 和 Web run `e7t08_web_20261002_c` 均从空的独立测试命名空间开始，五阶段全部通过。Android 驱动确认强停后 pid 消失再启动 Activity，四次实际强停重开；Web 驱动在同一 session / 标签页执行四次 refresh，未以文件重开替代平台生命周期。

## Validation

工程根目录，已有 Flutter 3.47.5 / Dart 3.13.4 与缓存依赖。改动 Dart 文件共 13 个，清单记录在 `/tmp/e7_t08_dart_files.txt`。

| 实际命令 | 结果 |
| --- | --- |
| `dart format`（改动 Dart 文件，分批） | 退出 0；随后格式检查通过 |
| `xargs -d '\n' dart format --output=none --set-exit-if-changed < /tmp/e7_t08_dart_files.txt` | 退出 0，13 files / 0 changed |
| `PYTHONPYCACHEPREFIX=/tmp/e7_t08_pycache python3 -m py_compile tool/e7_t08_relaunch_android.py tool/e7_t08_refresh_web.py` | 退出 0，缓存位于工作区外 |
| `flutter analyze --no-pub` | 最终退出 0，No issues found |
| `TZ=Asia/Shanghai flutter test --no-pub test/features/ledger/presentation/recording_rhythm_details_test.dart test/features/ledger/data/recording_rhythm_details_migration_test.dart test/features/ledger/data/recording_draft_store_test.dart` | 退出 0，19 项通过 |
| `TZ=Asia/Shanghai flutter test --no-pub` | 最终退出 0，580 项通过，3 项既有时区条件场景跳过 |
| `TZ=Asia/Shanghai python tool/e7_t08_relaunch_android.py --run-id=e7t08_android_20261002_c` | 退出 0，五阶段 / 四次实际强停重开通过 |
| `TZ=Asia/Shanghai flutter run --no-pub -d web-server --web-hostname=127.0.0.1 --web-port=7380 -t integration_test/rhythm_details_platform_test.dart --dart-define=E7_T08_RUN_ID=e7t08_web_20261002_c` + `TZ=Asia/Shanghai python tool/e7_t08_refresh_web.py --url=http://127.0.0.1:7380 --run-id=e7t08_web_20261002_c --driver-port=9539` | 服务成功启动；驱动退出 0，五阶段 / 四次同页刷新通过 |
| `git diff --check`、本次新建文件自审、执行前 SHA-256 对照、归档全文 / 后续任务定义 / 本地链接 / whitespace 检查 | 通过 |

初轮编译 / 静态检查发现测试方法名、夹具构造和 lint 问题，已修正。原测试的 schema 探针随 v5 更新；新增多行输入会吸收测试辅助方法的拖动，改为有界定位外层滚动位置。Android a 在恢复后的提示定位失败；b 已定位到正确的提交锁定，但测试误以为成功自动清理后仍有补偿按钮。核对既有 finishCommitted 合同后，在 c 的重开阶段继续注入清理故障，解除后验证补偿按钮。Web a 已通过前四阶段，旧定位版本在第五阶段等待期间被中止；Web b 仅启动服务，未跑浏览器；c 全阶段通过。未修改产品恢复行为或放宽正式数据 / 不重复写入断言。

存在既有 Drift 同类独立数据库实例的调试提示，各自 executor / 数据库名称独立，未静默屏蔽。3 项纽约 DST 条件测试在上海时区跳过，未算通过。日志保留于 `/tmp/e7_t08_android_c.log`、`/tmp/e7_t08_web_c.log`、`/tmp/e7_t08_webserver_c.log`、`/tmp/e7_t08_analyze_final2.log`、`/tmp/e7_t08_full_final.log`、`/tmp/e7_t08_target_final2.log`；初轮日志按 a / b 或 initial / tests 编号保留。

## Self-review / scope

检查 6 个生产文件、4 个共用测试文件、3 个平台 Dart 文件、2 个 Python 驱动，复核字段值域 / raw text / provided、迁移原子性、只显示适用细节、明确清空、add / edit 恢复匹配、提交锁定与失败重试。对照执行前 318 个既有 tracked / untracked 文件：只修改本任务 8 个代码 / 测试文件及 3 份完成文档；其余既有内容保持。没有改 pubspec、正式 schema、Goal / Sleep 业务或派生计算；没有增加统计、项目管理或后续生命周期 UI。

平台验证后停止测试应用，删除仅本次 E7-T08 命名空间的 12 个模拟器夹具文件，保留其他任务 / 应用库；关闭本次启动的模拟器、Web 服务及临时浏览器会话。

原 E7-T08 完整定义归档，仅增加 COMPLETE 和报告链接；后续 Task 完整定义不变。Epic 7 核心及本次 Should Have 已交付，不表示全 MVP 完成。

## Blockers / Open Questions / Limitations

无剩余 blocker，无新增 Open Question。未执行物理 Android 设备、整机重启 / 断电、系统时区切换、其他浏览器矩阵或发布；本任务要求的两平台受影响草稿恢复已有实际证据。

## Next executable task

**E8-T01 — 接通摘要日期上下文与一致读取。** 前置 E3-T06 / E3-T07 / E5-T01 / E6-T01 已有完成依据；仅报告，不执行。E7-T08 完成后停止。
