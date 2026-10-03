import 'package:flutter/material.dart';

import '../../ledger/domain/projection/day_ledger_view.dart';
import '../../ledger/presentation/goal_rhythm_summary_view.dart';
import '../../ledger/presentation/sleep_summary_view.dart';
import '../../ledger/presentation/summary_formatting.dart';
import 'review_form_controller.dart' show formatReviewDate;

class ReviewFactsView extends StatelessWidget {
  const ReviewFactsView({super.key, required this.ledger});
  final DayLedgerView ledger;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('当天事实上下文：${formatReviewDate(ledger.date)}'),
      Text('已交代：${formatDerivedDuration(ledger.accountedDuration)}'),
      Text('其中未知：${formatDerivedDuration(ledger.unknownDuration)}'),
      const Text('未知已包含在已交代时间中。'),
      Text('尚未记录：${formatDerivedDuration(ledger.unresolvedDuration)}'),
      const Text('睡眠背景（按醒来日期汇总完整记录）'),
      SleepSummaryView(summary: ledger.sleepSummary),
      GoalRhythmSummaryView(
        goals: ledger.goalSummaries,
        rhythm: ledger.rhythmSummary,
      ),
    ],
  );
}
