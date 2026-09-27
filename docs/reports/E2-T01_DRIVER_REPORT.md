# E2-T01 — 核验持久化驱动选择

状态：COMPLETE（官方资料只读核验）。核验日期：2026-09-27。

Epic 0、1 完成依据见 [完成记录](EPIC_0_1_COMPLETION.md)。原任务报告已在对话中交付，此文件归档其选择结论及后续批准。

## 选择与批准

推荐单库 SQLite + Drift 2.35.0 + drift_flutter 0.3.1，Android 使用 NativeDatabase，Web 使用 WasmDatabase。用户随后明确表示“我明确采用你的方案，继续 E2-T02”，因此该工程选型已批准采用。它不是 Source of Truth 原本强制的产品要求。

## 官方依据与限制

- [Drift 平台支持](https://drift.simonbinder.eu/platforms/)：Android 原生 SQLite、Web WASM；sqlite3 3.x 自动打包原生库。
- [Drift 2.34.0 发布说明](https://github.com/simolus3/drift/releases/tag/drift-2.34.0)：事务改用 BEGIN IMMEDIATE；[2.35.0 共用实现](https://github.com/simolus3/drift/blob/drift-2.35.0/drift/lib/src/sqlite3/database.dart#L59)覆盖原生和 WASM。
- [事务 API](https://pub.dev/documentation/drift/latest/drift/DatabaseConnectionUser/transaction.html)：异常回滚；必须等待事务内所有操作完成。
- [SQLite 外键](https://sqlite.org/foreignkeys.html)：逐连接在事务外启用并核验，不能仅声明 FK。
- [SQLite 隔离](https://sqlite.org/isolation.html)：多表查询应共用事务，避免混合提交时刻。
- [Drift Web](https://drift.simonbinder.eu/platforms/web/)：OPFS / sharedIndexedDb 可作为候选持久模式；拒绝 inMemory / unsafeIndexedDb 正式存储回退。WASM / worker 必须配套，opfsLocks 需要 COOP/COEP，WASM MIME 为 application/wasm；Web 不支持 WAL。
- [Drift 测试](https://drift.simonbinder.eu/testing/)及 [Flutter 集成测试](https://docs.flutter.dev/testing/integration-tests)：真实 SQLite 单测和 Android/Web 集成验证分开，内存库不能替代持久化读回。
- [sqflite_common_ffi_web](https://pub.dev/packages/sqflite_common_ffi_web)仍为实验性，无 SharedWorker 时跨标签页不安全，因此非首选。
- [直接 sqlite3 的 IndexedDB 文件系统](https://pub.dev/documentation/sqlite3/latest/wasm/IndexedDbFileSystem-class.html)存在异步落盘限制；自行处理 worker / 协调增加实现成本，因此非首选。

## 最小依赖与验收边界

运行依赖 drift、drift_flutter；生成式接入使用 drift_dev、build_runner；平台测试使用 Flutter SDK 的 integration_test，复用已有 flutter_test。配套 sqlite3.wasm 与 drift worker 是部署资产。路径及 sqlite3 库可由传递依赖提供，不额外直接安装旧版原生库包或其他功能包。

Android 的事务、FK、文件存储和测试入口，以及 Web 的事务、FK、浏览器存储和测试入口，均已核验官方资料。E2-T01 没有安装依赖或改写实现，没有执行驱动运行测试。具体浏览器发布矩阵、部署配置和真实运行证据由后续对应任务落实。
