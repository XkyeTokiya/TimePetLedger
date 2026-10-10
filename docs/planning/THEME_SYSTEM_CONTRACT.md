# 主题系统实施前合同（2026-10-09，Q-041）

本文件固定 Q-041 主题方向的**实施前合同与 spike 证据**：预设配色清单、默认值、语义色与热力图映射、动态取色行为、暖纸深色版候选、依赖路线、根部管道要求与验证计划。来源为 [Q-041](../domain/OPEN_QUESTIONS.md#q-041)、[design.md §12](../../design.md#12-主题与配色专项合同2026-10-09q-041) 与 [UI_REBUILD_PLAN](UI_REBUILD_PLAN.md#默认-material-3-与可切换主题--字体2026-10-09q-041)。

**状态：** 合同与隔离 spike 完成后，用户于 2026-10-09 授权实施，四步均已执行：取色 / 字体解耦（生产代码零 `HomePalette` / `homeSerifFamily` / `Theme(data: homeTheme)` 直引）、主题系统与设置切换（`dynamic_color 1.9.0` 接入、根部管道、偏好键与设置页入口）、测试与平台验证（新增矩阵 / 回退 / 持久化 / 对比度测试通过；全量 `+756 ~11 -141` 与基线失败集合逐条一致、无新增；Android 调试 APK 与 Web 构建通过）。暖纸深色视觉确认、Android 真机动态取色 / 系统栏与人工读屏未执行（THEME-03 记 PARTIAL）。任务状态见 [TASKS](../../TASKS.md)。

## 1. Spike 结论（已验证）

| 项 | 结论 | 证据 |
| --- | --- | --- |
| 依赖路线 | pin `dynamic_color 1.9.0`（迁移 `material_ui` 前最后一版，返回 `flutter/material` 类型）+ dev `dynamic_color_testing 0.1.0` | §1.1 |
| 无插件回退 | 无插件 / Web 下 `DynamicColorBuilder` 返回 null/null、不抛异常，回退渲染通过 | VM + Chromium 实测 |
| 测试集成 | mock 核心调色板在 VM 下返回可用浅 / 深方案，类型可直接用于 `ThemeData` | VM 测试通过 |
| Android 嵌入 | `flutter build apk --debug` 通过（AGP 9.1.0 / Gradle 9.3.1 / Kotlin 2.4.0，49.7s，`app-debug.apk` 产出） | 构建输出 |
| Web | Chromium 运行时验证 no-op 回退；`dynamic_color_testing` mock 在浏览器测试内不生效（跳过，不影响回退） | chrome 测试 1 通过 1 跳过 |
| 对比度 | 6 预设 × 明暗关键文字对全 ≥6.4（浅）/ ≥7.1（深）；语义角色对背景 ≥6.1 | §3 审计 |

### 1.1 依赖路线细节

- `dynamic_color 1.9.0` 的 `DynamicColorBuilder` / `ColorScheme` 与 `package:flutter/material.dart` 同类型，可直接进入 `MaterialApp(theme:)`；使用 `OptionalMethodChannel`，无插件返回 null。
- `dynamic_color 2.1.0` 依赖 `material_ui ^1.0.0`（官方拆包），返回 `material_ui` 的 `ColorScheme`，与 framework 内类型不兼容；实测 `flutter analyze` 报 `argument_type_not_assignable`（material_ui-1.6.0 vs flutter `color_scheme.dart`）。
- 备选路线：① 2.x + 字段转换（把 material_ui scheme 映射为 flutter `ColorScheme`）；② 自写可选 MethodChannel（约 50 行 + testing）。若 1.9.0 在目标平台出现嵌入问题，选 ②；不做整包 `material_ui` 迁移。
- spike 工程位于 `/tmp/opencode/theme-spike`（1.9.0）与 `/tmp/opencode/theme-spike-dc2`（2.x 证据），与主仓库隔离。

**2026-10-10 用户决定：暂不迁移 `material_ui`。** 全 app 继续使用框架 `package:flutter/material.dart`（`useMaterial3: true`），`dynamic_color` 保持 pin `1.9.0`；设置页等新页面同样不引入第二套组件库。评估依据：lib 61 个、test / integration 91 个文件引用 `flutter/material`，`fl_chart 1.2.0` 仍返回旧类型；迁移收益主要是解锁 `material_ui` 类型的新依赖，目前无此需求。重评触发条件（满足两条以上再启动）：① Flutter 官方宣布框架 material 弃用 / 退役，或所需 M3 能力仅在 `material_ui`；② 关键依赖（如 `fl_chart`）迁至 `material_ui` 类型或旧版 pin 被生态抛弃；③ 需要仅支持 `material_ui` 的新依赖；④ 存在稳定迁移窗口（基线失败清理、并行 UI 工作合并）。届时按 `dart fix --code=migrate_design_widgets` + `MaterialUiCompatibilityBridge`（未迁移依赖）+ 全量基线对比与双平台验证执行，预计一个专项 Epic（3–4 任务）。

## 2. 可执行合同

### 2.1 配色清单

| 名称 | 生成方式 | 种子 / 基准 | 备注 |
| --- | --- | --- | --- |
| 默认 M3 | framework 基准 | `ThemeData(useMaterial3: true)` 默认 `colorScheme`（浅 primary `#6750A4`，深 `#D0BCFF`） | 首套默认 |
| 蓝 | `ColorScheme.fromSeed` | `0xFF0B57D0` | |
| 绿 | `ColorScheme.fromSeed` | `0xFF146C2E` | |
| 橙 | `ColorScheme.fromSeed` | `0xFFE8710A` | |
| 青 | `ColorScheme.fromSeed` | `0xFF006A6A` | |
| 暖纸 | 自定义 | 浅色沿用现行 `homeTheme` ColorScheme 值；深色为 `fromSeed(0xFFB65F48, dark)` 候选 | 深色视觉待确认（§2.3 / §5） |
| 跟随壁纸 | Android 12+ 动态取色 | core palette → 浅 / 深 scheme | 不可用时隐藏并回退（§2.5） |

固定生成参数：`ColorScheme.fromSeed` 使用默认 `DynamicSchemeVariant.tonalSpot`；不启用 `contrastLevel` 调整。

### 2.2 初始默认值（实施合同定稿）

- 首套配色：**默认 M3**。
- 外观模式：**跟随系统**（浅 / 深 / 跟随系统三态）。
- 字体：**系统字体**（M3 默认；衬线 `NotoSerifSC` 可选）。

以上由“默认 Google Material 3 外观”方向推导；用户可在实施前调整。

### 2.3 语义色映射（ThemeExtension）

| 语义 | 预设 / 动态配色 | 暖纸浅色（现行） | 暖纸深色（候选） |
| --- | --- | --- | --- |
| 活动 | `primary` | `#B08968` | `#D9AE86` |
| 睡眠 | `tertiary` | `#7E8FA0` | `#A9B9CA` |
| 恢复 | `secondary` | `#6D7E64` | `#9FB891` |
| Unknown | `outline` | `#8A8177` | `#B3A79C` |
| Gap | `outlineVariant`（虚线 / 形状区分） | `#9A9088` | `#94897E` |
| 错误 | `scheme.error` | `error` | `error` |

- 依据：预设中 `primary/tertiary/secondary` 两两 min ΔE(CIE76) 15.1–20.1，对背景对比 ≥6.1；`*FixedDim` 不可用（浅色对背景对比仅 1.6）。
- 暖纸深色候选对深色 surface 对比：睡眠 9.3、活动 9.2、恢复 8.6、Unknown 7.9、Gap 5.4（Gap 对 `surfaceContainerHighest` 3.6，≥3 图形阈值，且沿虚线区分）。
- 规则不变：颜色不得作为唯一状态信号；Gap 虚线、Unknown 形状继续使用。

### 2.4 热力图规则

- 空 / 无记录：`surfaceContainerHighest`；未来格沿用现行禁用样式。
- 档位 `t=0.25/0.5/0.75/1.0`：`Color.lerp(surfaceContainerHighest, primary, t)`。
- 档位文字：优先取 `{onSurface, onPrimary}` 中对比度高者；若 <4.5，改取 `{white, black}` 高者。规则在主题构建期计算并存入扩展。
- 实测：12 组（6 预设 × 浅深）四档 worst 对比 5.07（含黑白回退）；应用"优先主题色"规则时下限 ≥4.5（回退兜底 ≥4.58）。

### 2.5 动态取色行为

- 可用性：`DynamicColorBuilder` 浅 / 深均非 null → 显示“跟随壁纸”；否则选项隐藏；若已存偏好为动态而当前不可用，回退渲染**默认 M3** 并在设置内说明，偏好保留。
- 快照：应用启动时取一次；运行中壁纸变化不保证实时生效（恢复前台时可重取，作为实现增强项）。
- 系统栏：按 `scheme.brightness` 设置状态栏 / 导航栏明暗图标（全仓现无 `SystemChrome` 用法，属新增，实施时随页面壳验证）。
- 仅 Android 提供动态取色（用户选择）；Web / 桌面使用所选预设。

### 2.6 字体

- 选项：M3 系统字体 / 衬线 `NotoSerifSC`；默认系统字体；`NotoSerifSC` 资产保留。
- 实施必须清理硬编码 `fontFamily: homeSerifFamily`（实测 105 处 / 16 文件，含 dead / 历史文件；`home_ledger_style.dart`、目标页、睡眠页等），否则切到系统字体后仍渲染衬线。

### 2.7 根部管道要求（实施输入）

1. `app_bootstrap` 加载 / 错误态两个独立 `MaterialApp` 使用默认 M3 主题；就绪后在首帧前预读偏好（与 `_ready` 并行），避免冷启动闪变。
2. `MainApp` 之上持有主题状态（`ValueNotifier<AppPreferences>` 或等价物），`MaterialApp` 设置 `theme` / `darkTheme` / `themeMode`。
3. 设置页保存成功后通知根部即时重建；写失败按现有乐观回滚模式恢复上一主题并报错。
4. `themeMode.system` 跟随系统明暗；动态取色在根部解析。
5. 迁移顺序：先取色 / 字体解耦（§2.6、design.md §12），再接主题系统。

### 2.8 偏好键与依赖（实施接线）

- 新增偏好键（沿用 snake_case）：`theme_scheme`（`defaultM3/blue/green/orange/teal/warmPaper/dynamic`）、`theme_mode`（`system/light/dark`）、`font_choice`（`system/serif`）；null 表示未选择，读取时按 §2.2 解析默认。
- `pubspec.yaml` 新增 `dynamic_color: 1.9.0`（exact，仓库惯例如 drift / fl_chart），dev 新增 `dynamic_color_testing: 0.1.0`；`pub get` 解析与平台验证在实施任务执行（spike 中已在隔离工程验证 material_color_utilities 0.13.0 无冲突）。

## 3. 审计数据（复现命令）

| 审计 | 命令（隔离工程内） | 关键结果 |
| --- | --- | --- |
| 回退 / mock | `flutter test test/dynamic_color_spike_test.dart` | 2 项通过 |
| Web 回退 | `flutter test --platform chrome test/dynamic_color_spike_test.dart` | 1 通过 1 跳过 |
| 配色对比度 | `flutter test test/contrast_audit_test.dart` | 浅 min 6.42 / 深 min 7.19；语义 ΔE ≥15.1 |
| 暖纸深色 + 热力图 | `flutter test test/warm_dark_audit_test.dart`、`test/heatmap_rule_test.dart` | 暖纸深色候选对比达标；热力图 worst 5.07 |
| Android 构建 | `flutter build apk --debug` | `app-debug.apk` 产出 |

视觉原型：[assets/theme-round-one](assets/theme-round-one/)（本目录：`theme-preview.html` 由实际 `ColorScheme.fromSeed` 输出生成，含全部预设浅 / 深、暖纸候选、语义色与热力图档位；截图 `theme-preview-wide.png`、`theme-preview-warm.png`）。仅作评审候选，不构成验收。

## 4. 测试与验证计划（实施时执行）

- 纯 Dart 对比度测试：把 §2.3 / §2.4 规则固化为测试（阈值 ≥4.5 文字、≥3 图形），覆盖 6 预设 × 浅深。
- 主题矩阵 widget 测试：每个配色 × 浅深 × 两字体各断言关键色与字体生效、无异常。
- 动态回退测试：无 mock → 默认 M3；mock → 动态 scheme；设置为动态但不可用 → 回退且偏好保留。
- 持久化测试：新键读写、非法值清理、设置页返回后根部即时切换（不重启）。
- 平台验收：Android 12+ 真机 / 模拟器动态取色与状态栏；Web 浏览器回退；两平台构建；全量测试与既有失败基线逐条对比，不以构建通过代替运行时验证。

## 5. 待确认与限制

1. **暖纸深色版视觉**：候选已生成并通过对比审计，未经用户视觉确认；确认前不得对外声称暖纸支持深色。
2. **动态取色真机**：Android 12+ 实际取色、壁纸变化与时序未在设备验证。
3. **预设命名**：表中名称为合同工作名，设置页展示文案可随评审调整。
4. 本合同的默认值与生成参数如需调整，先更新本文件与 Q-041 / design.md，再进入实施。
