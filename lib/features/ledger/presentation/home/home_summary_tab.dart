import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../domain/sleep_session.dart';
import '../day_ledger_controller.dart';
import '../goal_rhythm_summary_view.dart';
import '../sleep_summary_view.dart';

/// Summary tab. Reads the same committed [DayLedgerView] as the timeline;
/// no separate query or recomputation. Ring chart is deferred to the next round.
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
