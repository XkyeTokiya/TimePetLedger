import 'package:flutter/material.dart';

import '../application/recording_time_suggestion.dart';
import '../domain/time_precision.dart';
import 'sleep_time_input.dart';

Future<RecordingTimeInput?> showActivityTimeSheet(
  BuildContext context,
  RecordingTimeInput input,
) => showModalBottomSheet<RecordingTimeInput>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .88,
      child: ActivityTimeEditor(
        input: input,
        onApply: (value) => Navigator.pop(context, value),
        onCancel: () => Navigator.pop(context),
      ),
    ),
  ),
);

/// Owns unapplied text only. The host owns insets, navigation and persistence.
class ActivityTimeEditor extends StatefulWidget {
  const ActivityTimeEditor({
    super.key,
    required this.input,
    required this.onApply,
    required this.onCancel,
  });
  final RecordingTimeInput input;
  final ValueChanged<RecordingTimeInput> onApply;
  final VoidCallback onCancel;

  @override
  State<ActivityTimeEditor> createState() => _ActivityTimeEditorState();
}

class _ActivityTimeEditorState extends State<ActivityTimeEditor> {
  late final start = TextEditingController(
    text: formatSleepTime(widget.input.startedAt),
  );
  late final end = TextEditingController(
    text: formatSleepTime(widget.input.endedAt),
  );
  late var startPrecision = widget.input.startPrecision;
  late var endPrecision = widget.input.endPrecision;
  String? startError;
  String? endError;

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    super.dispose();
  }

  void apply() {
    // Untouched minute displays must not quantize the original fact.
    final a = start.text == formatSleepTime(widget.input.startedAt)
        ? widget.input.startedAt
        : parseSleepTime(start.text);
    final b = end.text == formatSleepTime(widget.input.endedAt)
        ? widget.input.endedAt
        : parseSleepTime(end.text);
    setState(() {
      startError = a == null ? '请输入有效日期与时间，如 2026-10-05 10:30' : null;
      endError = b == null ? '请输入有效日期与时间，如 2026-10-05 11:15' : null;
      if (a != null && b != null && b <= a) endError = '结束时间必须晚于开始时间';
    });
    if (startError != null || endError != null) return;
    // Unedited endpoints keep their milliseconds; displaying minutes is not rounding storage.
    widget.onApply(
      RecordingTimeInput(
        startedAt: a,
        endedAt: b,
        startPrecision: startPrecision,
        endPrecision: endPrecision,
      ),
    );
  }

  Future<void> clock(TextEditingController field, bool first) async {
    final raw = field.text.trim();
    final parsed = parseSleepTime(raw);
    final dateOnly = raw.split(' ').first;
    final date = parsed ?? parseSleepTime('$dateOnly 00:00');
    if (date == null) {
      setState(() {
        if (first) {
          startError = '请先填写有效日期';
        } else {
          endError = '请先填写有效日期';
        }
      });
      return;
    }
    final d = DateTime.fromMillisecondsSinceEpoch(date);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: d.hour, minute: d.minute),
      helpText: '选择时分',
      cancelText: '取消',
      confirmText: '确定',
      hourLabelText: '小时',
      minuteLabelText: '分钟',
      errorInvalidText: '请输入有效时分',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    final value = DateTime(d.year, d.month, d.day, picked.hour, picked.minute);
    setState(() {
      field.text = formatSleepTime(value.millisecondsSinceEpoch);
      if (first) {
        startError = null;
      } else {
        endError = null;
      }
    });
  }

  Widget endpoint(bool first) {
    final precision = first ? startPrecision : endPrecision;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          first ? '开始' : '结束',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey(first ? 'activity-time-start' : 'activity-time-end'),
          controller: first ? start : end,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            hintText: '2026-10-05 10:30',
            errorText: first ? startError : endError,
            suffixIcon: IconButton(
              tooltip: first ? '选择开始时分' : '选择结束时分',
              onPressed: () => clock(first ? start : end, first),
              icon: const Icon(Icons.schedule),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in TimePrecision.values)
              ChoiceChip(
                key: ValueKey('${first ? 'start' : 'end'}-${p.name}'),
                label: Text(p == TimePrecision.exact ? '准确' : '大约'),
                selected: p == precision,
                onSelected: (_) => setState(() {
                  if (first) {
                    startPrecision = p;
                  } else {
                    endPrecision = p;
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '调整时间',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: '取消时间修改',
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        endpoint(true),
        const SizedBox(height: 24),
        endpoint(false),
        const SizedBox(height: 24),
        FilledButton(onPressed: apply, child: const Text('应用时间')),
      ]),
    ),
  );
}
