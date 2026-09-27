# SQLite Web 资产

来源：[Drift 2.35.0 官方 release](https://github.com/simolus3/drift/releases/tag/drift-2.35.0)。以下两个文件于 2026-09-27 从同一 release 下载，与 pubspec 中固定的 Drift 版本配套。

| 本地文件 | 官方下载文件 | SHA-256 |
| --- | --- | --- |
| sqlite3.wasm | [sqlite3.wasm](https://github.com/simolus3/drift/releases/download/drift-2.35.0/sqlite3.wasm) | `13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4` |
| drift_worker.dart.js | [drift_worker.js](https://github.com/simolus3/drift/releases/download/drift-2.35.0/drift_worker.js) | `df0066e75363a9bed59a14eedbbded421c1f5910f8379812df164716aa2e6eed` |

哈希是本次下载文件的本地校验记录，不冒充维护者签名。worker 仅重命名，没有修改内容。Drift 为 MIT 许可；SQLite 为 public domain，资产内保留上游注释。

部署时同源提供这两个文件；sqlite3.wasm 的 Content-Type 必须为 application/wasm。需要 opfsLocks 时配置 Cross-Origin-Opener-Policy: same-origin，以及 Cross-Origin-Embedder-Policy: require-corp（或 credentialless）。运行时只允许 opfsShared / opfsLocks / sharedIndexedDb，其他模式关闭连接并反馈失败，不静默退到临时存储。

本机验证使用 Chromium 与固定端口。浏览器发布矩阵、托管方响应头配置及隐私模式不在本任务中声明已全面验证。升级 Drift 时同时更新配套资产及本记录，执行 Web 驱动测试。[官方 Web 文档](https://drift.simonbinder.eu/platforms/web/)
