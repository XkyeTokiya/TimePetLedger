import 'package:flutter/material.dart';

import '../domain/block_knowledge_state.dart';
import '../domain/projection/derived_duration.dart';
import '../domain/projection/goal_rhythm_summary.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/rhythm_details.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart';
import 'recording_rhythm_input.dart';
import 'summary_formatting.dart';

enum LedgerDetailAction { edit, delete }

/// Reads the committed snapshot only. Mutations stay with the caller's existing
/// editor, confirmation and post-commit cleanup path.
Future<LedgerDetailAction?> showLedgerFactDetails(
  BuildContext context, {
  required LedgerSegment segment,
  GoalSummary? goal,
  required bool canEdit,
  required bool canDelete,
}) => showModalBottomSheet<LedgerDetailAction>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .82,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(switch (segment) {
                  SleepSessionSegment(:final source) =>
                    source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
                  _ => '记录详情',
                }, style: const TextStyle(fontSize: 20)),
              ),
              IconButton(
                tooltip: '关闭详情',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: _Details(segment: segment, goal: goal),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canEdit)
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, LedgerDetailAction.edit),
                    child: const Text('编辑完整记录'),
                  ),
                if (canDelete)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: segment is SleepSessionSegment
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () =>
                        Navigator.pop(context, LedgerDetailAction.delete),
                    child: Text(
                      segment is SleepSessionSegment ? '管理与删除' : '删除记录',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

class _Details extends StatelessWidget {
  const _Details({required this.segment, this.goal});
  final LedgerSegment segment;
  final GoalSummary? goal;
  String boundary(int value, TimePrecision precision) {
    final parts = formatRecordingTime(value).split(' ');
    return '${parts.first}  ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    void record(
      String title,
      int start,
      int end,
      TimePrecision startPrecision,
      TimePrecision endPrecision,
    ) {
      children.addAll([
        SelectableText(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        SelectableText(
          '${boundary(start, startPrecision)}\n→ ${boundary(end, endPrecision)}',
          style: const TextStyle(fontSize: 18, height: 1.6),
        ),
        const SizedBox(height: 12),
        SelectableText(
          formatDerivedDuration(
            DerivedDuration(
              milliseconds: end - start,
              hasApproximation:
                  startPrecision == TimePrecision.approximate ||
                  endPrecision == TimePrecision.approximate,
            ),
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
      ]);
      if (start != segment.startedAt || end != segment.endedAt) {
        final date = DateTime.fromMillisecondsSinceEpoch(segment.startedAt);
        children.addAll([
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '计入${date.month}月${date.day}日',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${boundary(segment.startedAt, segment.startPrecision)}\n→ ${boundary(segment.endedAt, segment.endPrecision)}',
          ),
          const SizedBox(height: 8),
          Text(formatDerivedDuration(segment.duration)),
          const SizedBox(height: 24),
        ]);
      }
    }

    void item(String label, String? text) {
      if (text == null) return;
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              SelectableText(text),
            ],
          ),
        ),
      );
    }

    switch (segment) {
      case TimeBlockSegment(:final source, :final annotation):
        record(
          source.knowledgeState == BlockKnowledgeState.unknown
              ? '想不起来 · 已交代'
              : source.title!,
          source.startedAt,
          source.endedAt,
          source.startPrecision,
          source.endPrecision,
        );
        if (source.knowledgeState == BlockKnowledgeState.unknown) {
          item('原文字', source.title);
        }
        item(
          '目标',
          goal == null
              ? null
              : '${goal!.name}${goal!.isArchived ? '（已归档）' : ''}',
        );
        if (annotation != null) {
          item('节奏', rhythmInputLabel(annotation.state));
          item('接续点', annotation.continuationHint);
          item('卡住原因', switch (annotation.applicableStuckReasonCode) {
            null => null,
            StuckReasonCode.taskTooLarge => '任务太大',
            StuckReasonCode.unclearNextStep => '不知道下一步',
            StuckReasonCode.sleepy => '困',
            StuckReasonCode.brainFog => '脑雾',
            StuckReasonCode.anxious => '焦虑',
            StuckReasonCode.interrupted => '被打断',
            StuckReasonCode.unsure => '说不清',
            StuckReasonCode.other => '其他',
          });
          item('原因补充', annotation.applicableStuckReasonText);
          item('恢复方式', switch (annotation.applicableRecoveryMethod) {
            null => null,
            RecoveryMethod.walk => '散步',
            RecoveryMethod.meal => '吃饭',
            RecoveryMethod.shower => '洗澡',
            RecoveryMethod.empty => '放空',
            RecoveryMethod.entertainment => '娱乐',
            RecoveryMethod.switchTask => '切换任务',
            RecoveryMethod.breakDownTask => '拆小任务',
            RecoveryMethod.askForHelp => '寻求帮助',
            RecoveryMethod.other => '其他',
          });
          item('恢复感受', switch (annotation.applicableRecoveryQuality) {
            null => null,
            RecoveryQuality.notRecovered => '没缓过来',
            RecoveryQuality.partlyRecovered => '缓过来一些',
            RecoveryQuality.readyToContinue => '可以继续了',
          });
        }
        item('备注', source.note);
      case SleepSessionSegment(:final source):
        String endpoint(
          int instant,
          TimePrecision precision, {
          bool date = false,
        }) {
          final local = DateTime.fromMillisecondsSinceEpoch(instant);
          final clock = formatRecordingTime(instant).split(' ').last;
          final year =
              DateTime.fromMillisecondsSinceEpoch(source.startedAt).year !=
              DateTime.fromMillisecondsSinceEpoch(source.endedAt).year;
          return '${date ? '${year ? '${local.year}年' : ''}${local.month}月${local.day}日 ' : ''}$clock';
        }
        String duration(DerivedDuration value) {
          final text = formatDerivedDuration(value).replaceAll(' ', '');
          return text.contains('小时') ? text.replaceAll('分钟', '分') : text;
        }
        children.addAll([
          if (source.startedAt != segment.startedAt ||
              source.endedAt != segment.endedAt) ...[
            _DetailPair(
              label: '当日片段',
              value:
                  '${endpoint(segment.startedAt, segment.startPrecision)}–${endpoint(segment.endedAt, segment.endPrecision)}',
            ),
            _DetailPair(label: '当日时长', value: duration(segment.duration)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            const Text('完整睡眠'),
          ],
          const SizedBox(height: 12),
          _DetailPair(
            label: '入睡',
            value: endpoint(
              source.startedAt,
              source.startPrecision,
              date: true,
            ),
          ),
          _DetailPair(
            label: '醒来',
            value: endpoint(source.endedAt, source.endPrecision, date: true),
          ),
          _DetailPair(
            label: '完整时长',
            value: duration(
              DerivedDuration(
                milliseconds: source.endedAt - source.startedAt,
                hasApproximation:
                    source.startPrecision == TimePrecision.approximate ||
                    source.endPrecision == TimePrecision.approximate,
              ),
            ),
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
        ]);
        item('备注', source.note);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        );
        final valueWidget = SelectableText(
          value,
          style: TextStyle(color: color, fontSize: 16),
        );
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(280)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: valueWidget,
              ),
            ),
          ],
        );
      },
    ),
  );
}
