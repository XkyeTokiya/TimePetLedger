# E0-T01 工程与验证基线完成报告

## 报告信息

| 项目 | 结果 |
| --- | --- |
| Task | E0-T01 — 核查现有工程与验证基线 |
| Task 状态 | **COMPLETE** |
| 基线执行日期 | 2026-09-24（Asia/Shanghai） |
| 报告归档日期 | 2026-09-25（Asia/Shanghai） |
| 工程基线结论 | 格式检查通过；静态分析通过；没有测试，因此测试未执行 |
| 变更性质 | 基线执行本身为只读；本文件是事后归档的正式报告 |

> 本报告整理自 E0-T01 执行时保存的命令、退出码与输出。报告归档时工作区已经出现后续入口重组改动，因此没有用当前代码重跑后再冒充原始基线。本报告中的工程状态均指 2026-09-24 的 E0-T01 快照。

## Environment and existing project state

- 工程是最小 Flutter 项目，唯一 Dart 源文件为 `lib/main.dart`。
- Flutter：`3.47.5` stable，framework revision `6a19cca564`。
- Dart：`3.13.4` stable，Linux x64。
- DevTools：`2.60.0`。
- `pubspec.yaml` 的 Dart SDK 约束为 `^3.13.4`。
- 直接运行依赖只有 Flutter SDK；开发依赖为 Flutter SDK 的 `flutter_test` 和 `flutter_lints ^6.0.0`。
- E0-T01 开始前已存在 `.dart_tool/package_config.json`、`pubspec.lock` 和 `build/`。分析使用现有解析结果，没有安装或重新解析依赖。
- 仓库存在 Android、Linux 和 Web 平台壳。当时本机检测到 Linux 与 Chrome 设备；平台目录和本机设备均不构成发布支持承诺。
- `README.md` 仍是默认的 “A new Flutter project.” 说明。
- 未发现专用验证脚本、Makefile 或 CI 配置。

路径说明：执行环境将 `/home/tokiya/Projects/21-TimePetLedger` 与 `/kiyodata/Projects/21-TimePetLedger` 映射到同一工作区；命令在该工程根目录执行。

## Entry points and existing tests

E0-T01 快照中的实际入口：

```text
lib/main.dart
  main()
    -> runApp(const MainApp())
      -> MaterialApp
        -> Scaffold
          -> Center
            -> Text('Hello World!')
```

当时的实现只有 `lib/main.dart`，尚无 `lib/app/`、`lib/core/` 或 `lib/features/`。

测试发现结果：

| 路径 | 状态 |
| --- | --- |
| `test/` | 不存在 |
| `integration_test/` | 不存在 |
| 现有测试文件 | 0 |

因此 E0-T01 没有执行 `flutter test`，也没有把“没有测试”表述为“测试通过”。

## Validation results

### 通过

| 检查 | 命令 | 退出码 | 结果 |
| --- | --- | ---: | --- |
| Flutter 工具链 | `flutter --version` | 0 | Flutter 3.47.5，Dart 3.13.4 |
| Dart 工具链 | `dart --version` | 0 | Dart 3.13.4 stable |
| 本机设备枚举 | `flutter devices --machine` | 0 | 检测到 Linux、Chrome；仅作为环境事实 |
| 格式检查 | `dart format --output=none --set-exit-if-changed lib/main.dart` | 0 | `Formatted 1 file (0 changed)` |
| 静态分析 | `flutter analyze --no-pub` | 0 | `No issues found! (ran in 4.3s)` |
| 受保护文件复核 | `sha256sum -c /tmp/time_pet_ledger_e0_t01_before.sha256` | 0 | `pubspec.yaml`、`pubspec.lock`、`lib/main.dart`、`analysis_options.yaml` 均为 `OK` |
| 工作区状态复核 | `git status --short --untracked-files=all` | 0 | 执行前后状态一致；没有由基线检查产生的源文件变化 |

### 未执行

| 检查 | 状态 | 原因 |
| --- | --- | --- |
| `flutter test --no-pub <测试路径>` | **未执行** | `test/` 与 `integration_test/` 均不存在，没有可执行测试路径 |
| Android 构建或启动 | **未执行** | 不属于 E0-T01；会产生构建产物，平台启动验证属于 E0-T03 |
| Web 构建或启动 | **未执行** | 不属于 E0-T01；会产生构建产物，平台启动验证属于 E0-T03 |
| 依赖安装或解析 | **未执行** | 任务明确禁止安装包或解析新依赖 |

### 测试发现命令说明

执行了以下只读发现命令：

```bash
rg --files test integration_test
```

命令退出码为 `2`，原因是两个目标目录都不存在。这是“没有测试路径”的发现结果，不是测试运行失败，也不是测试通过。

## Reusable validation commands

后续代码 Task 可复用以下命令，并把占位路径替换为本次实际改动或实际存在的测试路径：

```bash
dart format --output=none --set-exit-if-changed <本次涉及的 Dart 文件>
flutter analyze --no-pub
flutter test --no-pub <实际存在的相关测试路径>
```

如依赖或 `.dart_tool/package_config.json` 已改变，不能继续假定 `--no-pub` 使用的旧解析结果有效；应由明确授权的依赖接入 Task 处理，而不是在普通验证中隐式安装或升级依赖。

## Existing workspace state and preservation

E0-T01 执行开始及结束时，Git 均报告 14 个既有未跟踪文档，包括 `AGENTS.md`、`TASKS.md`、Source of Truth 及 `docs/` 下的领域、产品、架构和规划文档。这些文件不是 E0-T01 产生的改动，检查过程中没有覆盖或删除。

`.dart_tool/`、`build/` 和平台工具缓存也在执行前已经存在。E0-T01 没有把这些既有缓存或构建产物当作新生成的产品代码。

## Blockers and open questions

- E0-T01 本机基线核查没有 blocker。
- 执行当日 Q-022 尚为 `UNDECIDED`，但它不阻塞本机基线核查。
- 2026-09-25 后续产品决定已将 Q-022 更新为 `DECIDED`：第一版正式支持 Android 和 Web；其他平台不进入首发支持与验收范围。该后续决定不改变本报告的历史验证结果。
- 当前基线的明确缺口是没有自动化测试。E0-T01 不授权补建测试，因此该项记录为缺失，而不是失败修复或通过。

## Acceptance criteria traceability

| Acceptance criterion | 证据 | 结论 |
| --- | --- | --- |
| 列出实际入口 | `lib/main.dart` 的 `main()` → `MainApp` → `MaterialApp` → `Hello World!` | 满足 |
| 列出已有测试 | `test/`、`integration_test/` 均不存在；测试文件为 0 | 满足 |
| 区分通过、失败和未执行 | 格式与分析列为通过；测试和平台启动列为未执行 | 满足 |
| 给出可复用验证命令 | 本报告列出 formatter、analyzer 和存在测试时的 test 命令 | 满足 |
| 没有测试时不声明测试通过 | 测试明确记录为未执行 | 满足 |
| 不修改源文件、配置或 lockfile | 受保护文件前后哈希一致，Git 状态前后一致 | 满足 |

## Final conclusion

E0-T01 的报告交付和只读基线核查已完成。基线中格式检查与静态分析通过；测试因不存在而未执行。该结论满足 E0-T01 的完成条件，但不等同于 Android、Web 启动验证通过，也不等同于存在自动化测试覆盖。

下一项主线任务为 E0-T02；本报告不执行或验收 E0-T02、E0-T03、E1-T01 或任何后续 Task。
