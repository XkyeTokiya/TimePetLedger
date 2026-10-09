import 'package:flutter/material.dart';

import '../../../../app/theme/semantic_colors.dart';
import '../../domain/projection/day_composition.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../../domain/projection/derived_duration.dart';
import '../../domain/projection/goal_rhythm_summary.dart';
import '../../domain/sleep_session.dart';
import '../day_ledger_controller.dart';
import '../goal_rhythm_summary_view.dart';
import '../sleep_summary_view.dart';
import '../summary_formatting.dart';
import 'home_donut_chart.dart';

/// Summary tab. Reads the same committed [DayLedgerView] as the timeline;
/// no separate query or recomputation. 第一版回答“各部分占多少”（Q-027）：
/// 这一天的时间 → 目标投入 → 睡眠背景；完整睡眠与节奏明细保留为补充内容。
class HomeSummaryTab extends StatelessWidget {
  const HomeSummaryTab({
    super.key,
    required this.controller,
    this.onEditSleep,
    this.onRetry,
    this.footer,
  });

  final DayLedgerController controller;
  final ValueChanged<SleepSession>? onEditSleep;
  final VoidCallback? onRetry;

  /// 页面级入口（例如打开这一天的复盘）；为空时不显示。
  final Widget? footer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final view = controller.view;
      final dateContext = controller.dateContext;
      final colors = Theme.of(context).colorScheme;
      final semantics = context.semanticColors;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (controller.status == DayLedgerStatus.loading)
            const Center(child: CircularProgressIndicator()),
          if (controller.status == DayLedgerStatus.failed) ...[
            const Text('摘要读取失败，请重试。'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onRetry, child: const Text('重试读取')),
            ),
          ],
          if (view != null && dateContext != null) ...[
            if (controller.status == DayLedgerStatus.empty)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text('此账本窗口及醒来日期尚无正式记录。'),
              ),
            const _SectionLabel('这一天的时间'),
            Text(
              '已交代 ${formatDerivedDuration(view.accountedDuration)}'
              ' · 尚未记录 ${formatDerivedDuration(view.unresolvedDuration)}',
              style: _sectionSubStyle(colors),
            ),
            // 账本窗口本身是统计口径（23/25 小时日不同），保留为辅助说明。
            Text(
              '账本窗口：'
              '${formatDerivedDuration(DerivedDuration(milliseconds: view.window.milliseconds, hasApproximation: false))}',
              style: _captionStyle(colors),
            ),
            const SizedBox(height: 10),
            HomeDonutChart(
              key: const ValueKey('summary-day-chart'),
              parts: _dayParts(view, semantics),
              centerLabel: '已交代',
              centerValue: formatDerivedDuration(view.accountedDuration),
              semanticsLabel: _daySemantics(view),
            ),
            const SizedBox(height: 28),
            if (view.goalSummaries.isNotEmpty) ...[
              const _SectionLabel('目标投入'),
              HomeDonutChart(
                key: const ValueKey('summary-goal-chart'),
                parts: _goalParts(view.goalSummaries, colors, semantics),
                centerLabel: '目标相关',
                centerValue: formatDerivedDuration(
                  _goalTotal(view.goalSummaries),
                ),
                semanticsLabel: _goalSemantics(view.goalSummaries),
              ),
            ],
            ExpansionTile(
              key: const ValueKey('summary-rhythm-details'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text('目标与节奏明细', style: _sectionStyle(colors)),
              children: [
                GoalRhythmSummaryView(
                  goals: view.goalSummaries,
                  rhythm: view.rhythmSummary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionLabel('睡眠背景'),
            const SizedBox(height: 8),
            SleepSummaryView(
              summary: view.sleepSummary,
              onEdit: onEditSleep,
              foldRecords: true,
            ),
            if (footer case final footer?) ...[
              const SizedBox(height: 18),
              Align(alignment: Alignment.centerLeft, child: footer),
            ],
          ] else if (controller.status == DayLedgerStatus.empty)
            const Text('此账本窗口及醒来日期尚无正式记录。'),
        ],
      );
    },
  );

  List<DonutPart> _dayParts(DayLedgerView view, TimeLedgerSemanticColors sem) {
    final composition = projectDayComposition(
      coverage: view.coverage,
      segments: view.segments,
    );
    return [
      DonutPart(
        id: 'sleep',
        label: '睡眠',
        color: sem.sleep,
        duration: composition.sleep,
      ),
      DonutPart(
        id: 'activity',
        label: '活动',
        color: sem.activity,
        duration: composition.knownActivity,
      ),
      DonutPart(
        id: 'unknown',
        label: '想不起来',
        color: sem.unknown,
        duration: composition.unknown,
      ),
      DonutPart(
        id: 'gap',
        label: '尚未记录',
        color: sem.gap,
        duration: composition.gap,
        dashed: true,
      ),
    ];
  }

  String _daySemantics(DayLedgerView view) {
    final composition = projectDayComposition(
      coverage: view.coverage,
      segments: view.segments,
    );
    final total =
        composition.sleep.milliseconds +
        composition.knownActivity.milliseconds +
        composition.unknown.milliseconds +
        composition.gap.milliseconds;
    String percent(DerivedDuration part) =>
        total == 0 ? '0%' : '${(part.milliseconds * 100 / total).round()}%';
    return '一天时间构成：'
        '睡眠 ${formatDerivedDuration(composition.sleep)}，${percent(composition.sleep)}；'
        '活动 ${formatDerivedDuration(composition.knownActivity)}，${percent(composition.knownActivity)}；'
        '想不起来 ${formatDerivedDuration(composition.unknown)}，${percent(composition.unknown)}；'
        '尚未记录 ${formatDerivedDuration(composition.gap)}，${percent(composition.gap)}';
  }

  List<DonutPart> _goalParts(
    List<GoalSummary> goals,
    ColorScheme colors,
    TimeLedgerSemanticColors sem,
  ) {
    final palette = [
      colors.primary,
      sem.activity,
      sem.recovery,
      sem.sleep,
      sem.unknown,
    ];
    return [
      for (var i = 0; i < goals.length; i++)
        DonutPart(
          id: goals[i].goalId,
          label: goals[i].name,
          color: palette[i % palette.length],
          duration: goals[i].totalDuration.duration,
        ),
    ];
  }

  DerivedDuration _goalTotal(List<GoalSummary> goals) =>
      DerivedDuration.sum(goals.map((goal) => goal.totalDuration.duration));

  String _goalSemantics(List<GoalSummary> goals) {
    final total = _goalTotal(goals).milliseconds;
    final parts = goals
        .map((goal) {
          final percent = total == 0
              ? '0%'
              : '${(goal.totalDuration.milliseconds * 100 / total).round()}%';
          return '${goal.name} ${formatDerivedDuration(goal.totalDuration.duration)}，$percent';
        })
        .join('；');
    return '目标时间构成：$parts';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: _sectionStyle(Theme.of(context).colorScheme)),
  );
}

TextStyle _sectionStyle(ColorScheme colors) => TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: colors.onSurface,
);

TextStyle _sectionSubStyle(ColorScheme colors) =>
    TextStyle(fontSize: 13, height: 1.5, color: colors.onSurfaceVariant);

TextStyle _captionStyle(ColorScheme colors) =>
    TextStyle(fontSize: 12, height: 1.5, color: colors.onSurfaceVariant);
