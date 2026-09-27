# E2-T02 — 接入单库连接与测试环境

状态：COMPLETE。执行日期：2026-09-27（Asia/Shanghai）。

## 前置与授权

Epic 0、1 由项目负责人确认完成，见 [完成记录](EPIC_0_1_COMPLETION.md)。[E2-T01](E2-T01_DRIVER_REPORT.md) 已完成选型核验；用户明确采用该方案并授权继续 E2-T02。工程选型已记入 [DATA_ARCHITECTURE](../architecture/DATA_ARCHITECTURE.md)，没有改写领域合同或重新要求历史验收证据。

## 交付与修改文件

- `pubspec.yaml` / `pubspec.lock`：固定 drift 2.35.0、drift_flutter 0.3.1、drift_dev 2.35.0，接入 build_runner 2.16.1 与 Flutter SDK integration_test；复用 flutter_test。解析得到 sqlite3 3.5.2。其余新增项为依赖树中的传递依赖，未直接接入其他功能包。
- `build.yaml`：限制 Drift 生成入口，禁用本任务不使用的 manager 代码。
- `lib/core/persistence/app_database.dart` / `.g.dart`：没有业务表的数据库连接；实际打开成功、逐连接启用并核验 FK 后才返回；打开失败关闭资源并保留原始错误与可能的清理错误。
- `lib/core/persistence/database_connection.dart`、`database_connection_native.dart`、`database_connection_web.dart`：条件导入；Android 使用 drift_flutter 的后台连接，Web 使用配套 WASM / worker，拒绝并关闭 inMemory / unsafeIndexedDb 回退。
- `lib/app/bootstrap/app_bootstrap.dart`、`lib/main.dart`：启动组装拥有一个连接，重建不重复创建；dispose 时关闭，初始化晚于 dispose 完成时也会关闭。打开失败显示简短启动错误，不显示原始 SQL / 路径。成功后保持现有 Hello World 启动界面。
- `test/core/persistence/app_database_test.dart`、`test/app/bootstrap/app_bootstrap_test.dart`：8 项新增真实数据库 / 启动资源测试。
- `integration_test/persistence_test.dart`、`integration_test/support/persistence_fixture.dart`、`test_driver/integration_test.dart`：两平台共用的真实驱动测试及人工测试表。使用独立名称 `time_pet_ledger_test_<run>_a/b`；不打开正式 `time_pet_ledger` 库。完成后删测试表并关闭；平台存储中可能保留空的专用测试库。
- `web/sqlite3.wasm`、`web/drift_worker.dart.js`、`web/PERSISTENCE_ASSETS.md`：同一 Drift 2.35.0 release 的配套资产、下载来源、SHA-256 与部署要求。
- `docs/architecture/DATA_ARCHITECTURE.md`、本报告及 `E2-T01_DRIVER_REPORT.md`：记录批准及任务结果。

## 规则与测试覆盖

依据 DATA 的逐连接 FK 和原子事务合同、APP 的 app 组装 / 释放边界：

1. 空库无任何业务表，连接真正打开后才能使用。
2. 每个连接读回 `PRAGMA foreign_keys = 1`；无父记录的子记录被 SQLite 拒绝。
3. 真实 SQLite 无法开启 FK 时拒绝打开；真实文件打开失败返回 DatabaseOpenException。
4. 同一事务先写父、子记录，再触发 FK 失败，父子两表均回滚为空。
5. 内存库、临时文件、两个平台独立命名的测试库互不影响。
6. 关闭后原连接拒绝查询；重新打开文件 / 平台持久库能读回标记，FK 仍开启。
7. app 重建不重复打开；dispose 及初始化期间提前 dispose 均释放连接；失败不显示 ready 界面。

## 实际验证

环境：Flutter 3.47.5、Dart 3.13.4；Android Medium_Phone AVD（Android 13 / API 33，x86_64，emulator-5554）；Chromium / ChromeDriver 153.0.8010.52。

| 命令 | 最终结果 |
| --- | --- |
| `flutter pub get` | 退出 0，依赖与 lockfile 已解析 |
| `dart run build_runner build` | 退出 0，生成空数据库连接代码 |
| `dart format lib/main.dart lib/app/bootstrap lib/core/persistence test/core/persistence test/app/bootstrap integration_test test_driver` | 退出 0 |
| `dart format --output=none --set-exit-if-changed lib/main.dart lib/app/bootstrap lib/core/persistence test/core/persistence test/app/bootstrap integration_test test_driver` | 退出 0，12 个文件，0 changed |
| `flutter analyze --no-pub` | 退出 0，No issues found |
| `flutter test --no-pub test/core/persistence test/app/bootstrap` | 退出 0，8 项通过 |
| `flutter test --no-pub` | 退出 0，全量 176 项通过 |
| `flutter test --no-pub integration_test/persistence_test.dart -d emulator-5554` | 退出 0，Android 真实驱动集成场景通过 |
| `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/persistence_test.dart -d web-server --web-port=7357 --browser-name=chrome --chrome-binary=/usr/bin/chromium --headless` | 退出 0，Web 真实驱动集成场景通过 |

Web 命令执行前运行 `chromedriver --port=4444 --allowed-ips=127.0.0.1`。Android 使用已有 Medium_Phone AVD 启动，不新增平台或 AVD。构建过程自动补齐 Android SDK Platform 35 和 CMake 3.22.1；这属于所接入插件的 Android 构建工具依赖，不是产品运行依赖。

首次检查发现并已修复：空库生成的未使用 manager 字段（通过生成选项关闭）；原先错误假设“父目录不存在会打开失败”的测试（驱动会创建目录，改用目录自身作为不可打开文件）；Web 不能读取入口目录外的相对测试夹具（移入 integration_test/support）。这些首轮失败不记为通过，上表记录修复后的实际结果。

已知非失败输出：Drift 对同时创建多个 AppDatabase 发出调试警告，本测试刻意使用不同 executor / 独立库验证隔离，没有共享 executor；未全局关闭此警告。Android 构建另有 JDK native-access 与 SDK XML 版本警告，构建和运行均成功。

## 范围、自检与限制

没有实现业务五表、repository、领域保存操作或 E2-T03；人工 fixture 表仅存在于隔离测试库。没有修改已有 domain 实现及测试、既有 DOMAIN_RULES / OPEN_QUESTIONS 改动。Flutter 自动产生的 Linux 插件清单改动已移除，Linux 不纳入首发支持。

当前空库的 Drift user_version 为 1。E2-T03 必须处理这种已创建的空库升级（例如升级版本后创建业务表），不能仅添加 onCreate 并假设所有库仍为全新。本任务不提前实现该迁移。

本次平台测试验证同一进程内关闭全部相关连接后重开，不把它冒充应用杀进程 / 浏览器刷新、崩溃耐久性、多标签页竞争或完整五类事实读回验收。五类事实重启验证仍属于 E2-T08；Web 广泛浏览器兼容矩阵和生产托管响应头未宣称已验证。进程强制终止不保证 Flutter dispose 被调用；本任务没有依赖退出回调保存数据，提交由真实数据库事务完成。

本任务无未解决 blocker。完成 E2-T02 后停止；下一项为 E2-T03，需另行指定执行。
