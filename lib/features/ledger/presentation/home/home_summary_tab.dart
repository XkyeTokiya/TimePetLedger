import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
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
/// no separate query or recomputation. First version answers "各部分占多少"
/// with rings (Q-027): day composition first, then goal composition, with the
/// complete sleep / goal rhythm / global recovery kept as supplement.
class HomeSummaryTab extends StatelessWidget {
  const HomeSummaryTab({
    super.key,
    required this.controller,
    this.onEditSleep,
    this.onRetry,
  });

  final DayLedgerController controller;
  final ValueChanged<SleepSession>? onEditSleep;
  final VoidCallback? onRetry;

  static const _goalColors = [
    HomePalette.accent,
    HomePalette.activity,
    HomePalette.recovery,
    HomePalette.sleep,
    HomePalette.unknown,
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final view = controller.view;
      final dateContext = controller.dateContext;
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
            const _SectionLabel('一天时间构成'),
            HomeDonutChart(
              key: const ValueKey('summary-day-chart'),
              parts: _dayParts(view),
              centerLabel: '已交代',
              centerValue: formatDerivedDuration(view.accountedDuration),
              semanticsLabel: _daySemantics(view),
            ),
            const SizedBox(height: 28),
            if (view.goalSummaries.isNotEmpty) ...[
              const _SectionLabel('目标时间构成'),
              HomeDonutChart(
                key: const ValueKey('summary-goal-chart'),
                parts: _goalParts(view.goalSummaries),
                centerLabel: '目标相关',
                centerValue: formatDerivedDuration(
                  _goalTotal(view.goalSummaries),
                ),
                semanticsLabel: _goalSemantics(view.goalSummaries),
              ),
              const SizedBox(height: 28),
            ],
            const _SectionLabel('睡眠背景'),
            const Text('按所选日期的醒来日期汇总完整睡眠；账本覆盖仅计当日窗口内的部分。'),
            const SizedBox(height: 8),
            SleepSummaryView(summary: view.sleepSummary, onEdit: onEditSleep),
            const SizedBox(height: 28),
            GoalRhythmSummaryView(
              goals: view.goalSummaries,
              rhythm: view.rhythmSummary,
            ),
          ] else if (controller.status == DayLedgerStatus.empty)
            const Text('此账本窗口及醒来日期尚无正式记录。'),
        ],
      );
    },
  );

  List<DonutPart> _dayParts(DayLedgerView view) {
    final composition = projectDayComposition(
      coverage: view.coverage,
      segments: view.segments,
    );
    return [
      DonutPart(
        id: 'sleep',
        label: '睡眠',
        color: HomePalette.sleep,
        duration: composition.sleep,
      ),
      DonutPart(
        id: 'activity',
        label: '活动',
        color: HomePalette.activity,
        duration: composition.knownActivity,
      ),
      DonutPart(
        id: 'unknown',
        label: '想不起来',
        color: HomePalette.unknown,
        duration: composition.unknown,
      ),
      DonutPart(
        id: 'gap',
        label: '尚未记录',
        color: HomePalette.gap,
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

  List<DonutPart> _goalParts(List<GoalSummary> goals) => [
    for (var i = 0; i < goals.length; i++)
      DonutPart(
        id: goals[i].goalId,
        label: goals[i].name,
        color: _goalColors[i % _goalColors.length],
        duration: goals[i].totalDuration.duration,
      ),
  ];

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
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: homeSerifFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: HomePalette.ink,
      ),
    ),
  );
}
