# 测试失败基线（2026-10-11）

**HEAD：** `bb5051c`（工作区干净）
**命令：** `flutter test --reporter expanded`（仓库根目录）
**结果：** 941 项 = 789 通过 / 11 跳过 / **141 失败**；`flutter analyze` 0 问题。
**清单：** [failures.json](failures.json)（逐条 file + name + 初判分类 + 理由）。

## 分类（初判）

| 分类 | 条数 | 含义与后续处置 |
| --- | --- | --- |
| `legacy_fixture` | 92 | 测试引用的旧页面 / 组件为生产不可达实现（旧复盘 5 件、旧日账本 7 件、SleepForm、旧主题、LedgerShell、home_menu_page、goal_create_sheet 等 17 个文件，约 4,495 行）；随 DEBT-LEGACY-01 删除或迁移。 |
| `stale_assertion` | 29 | 活跃路径上的陈旧断言：有意变更未同步（“约”前缀 `ad711f6`、“日账本”字标 `f289eb5`、旧入口 / 提示文案、旧磁盘草稿合同被 Q-012 会话内恢复取代、旧表单导航辅助）。DEBT-REBASE-01 按现行合同重写。 |
| `needs_judgment` | 20 | 需对照 Source of Truth / 领域合同判定“测试陈旧 or 真实缺陷”：草稿迁移语义、注解提交时机、摘要页结构、应用层时间初值等。DEBT-REBASE-01 逐条给出结论。 |

初判基于失败证据快照与已记录的有意变更；最终判定在 DEBT-REBASE-01 完成并回填任务报告。

## 使用方式（只减不增）

```bash
flutter test --reporter expanded > /tmp/timepet-tests.log 2>&1
python3 docs/audits/2026-10-11-test-baseline-bb5051c/extract_failures.py /tmp/timepet-tests.log > current_failures.json
```

与 `failures.json` 比对：新增失败必须当轮修复或在任务报告中登记理由；已修复项从清单移除。目标：DEBT-REBASE-01 完成后全仓归零。

## 趋势（记录来源）

| 日期 | 任务 / 来源 | 通过 / 跳过 / 失败 | 完整失败清单 |
| --- | --- | --- | --- |
| 2026-10-06 | 二级 UI 复核（`3f5dd75`） | 665 / 9 / 108 | [审计 JSON](../2026-10-06-secondary-ui-recheck-3f5dd75/validation/test-comparison.json) |
| 2026-10-07 | HOME-NAV-02 / 03 | 792→800 / 7 / 103 | 未入库（当时保存在 /tmp，已失效） |
| 2026-10-09 | THEME 主题系统 | 756 / 11 / 141 | 未入库 |
| 2026-10-10 | PICKER-FIX-01 / HOME-PERF-01 | 786 / 11 / 142；768 / 11 / 141 | 未入库 |
| 2026-10-11 | HOME-SCROLL-FWD-01 | 785 / 11 / 136 | 未入库 |
| 2026-10-11 | 本目录（`bb5051c`） | 789 / 11 / 141 | [failures.json](failures.json) |
| 2026-10-11 | 债务清理 P1（复盘遗留） | 797 / 11 / 116 | [P1 报告](../../reports/REVIEW_R2_12_R2_13_REPORT.md) |
| 2026-10-11 | 债务清理 P2（死代码清除） | 686 / 6 / 25 | [P2 报告](../../reports/DEBT_P2_LEGACY_CLEANUP_REPORT.md) |

103–142 区间的完整失败清单在历史任务中只保留了 /tmp 临时路径，现已失效；本目录是自 2026-10-06 审计以来首个入库的完整清单。

## 限制

- 分类为 P0 初判；`needs_judgment` 项可能包含真实缺陷，不得当作“陈旧”直接删除。
- 失败集合来自一次本机全量运行；11 个跳过项与 `integration_test/`（本命令不运行）不在清单内。
- 计数口径为 expanded reporter 的可见失败，与 2026-10-06 审计的 “visibleTests” 口径不完全可比。
