import 'package:flutter/material.dart';

import '../../../core/widgets/editor_body.dart';
import '../../../core/time/civil_date.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart' show editRecordingTime;
import 'sleep_time_input.dart';

typedef EditorTimes = ({
  String start,
  String end,
  TimePrecision? startPrecision,
  TimePrecision? endPrecision,
});

/// Local working copy: only Apply returns data to the caller's draft.
class EditorTimePage extends StatefulWidget {
  const EditorTimePage({
    super.key,
    required this.initial,
    required this.date,
    this.sleep = false,
  });
  final CivilDate date;
  final EditorTimes initial;
  final bool sleep;
  @override
  State<EditorTimePage> createState() => _EditorTimePageState();
}

class _EditorTimePageState extends State<EditorTimePage> {
  late final start = TextEditingController(text: widget.initial.start);
  late final end = TextEditingController(text: widget.initial.end);
  late TimePrecision? startPrecision = widget.initial.startPrecision;
  late TimePrecision? endPrecision = widget.initial.endPrecision;
  bool manual = false;

  @override
  void dispose() {
    start.dispose();
    end.dispose();
    super.dispose();
  }

  Future<void> choose(bool first) async {
    final input = first ? start : end;
    final result = await editRecordingTime(
      context,
      initial: parseSleepTime(input.text),
      initialDate: widget.date,
      label: first
          ? (widget.sleep ? '入睡时间' : '开始时间')
          : (widget.sleep ? '醒来时间' : '结束时间'),
    );
    if (result != null && mounted) {
      setState(() => input.text = formatSleepTime(result));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.sleep ? '调整睡眠时间' : '调整记录时间')),
    body: EditorBody(
      status: '尚未应用',
      action: FilledButton(
        onPressed: () => Navigator.pop(context, (
          start: start.text,
          end: end.text,
          startPrecision: startPrecision,
          endPrecision: endPrecision,
        )),
        child: const Text('应用时间'),
      ),
      children: [
        for (final first in [true, false]) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: () => choose(first),
                    child: Text(
                      widget.sleep
                          ? (first ? '入睡' : '醒来')
                          : (first ? '开始时间' : '结束时间'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => choose(first),
                    child: Text(
                      (first ? start : end).text.isEmpty
                          ? '选择日期与时间'
                          : (first ? start : end).text,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final precision in TimePrecision.values)
                        ChoiceChip(
                          label: Text(
                            precision == TimePrecision.exact ? '准确' : '大约',
                          ),
                          selected:
                              (first ? startPrecision : endPrecision) ==
                              precision,
                          onSelected: (_) => setState(() {
                            if (first) {
                              startPrecision = precision;
                            } else {
                              endPrecision = precision;
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextButton(
          onPressed: () => setState(() => manual = !manual),
          child: const Text('手动输入日期与时间'),
        ),
        if (manual) ...[
          TextField(
            key: ValueKey(widget.sleep ? 'sleep-start' : 'time-start'),
            controller: start,
            decoration: const InputDecoration(
              labelText: '开始日期与时间',
              hintText: 'YYYY-MM-DD HH:mm',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey(widget.sleep ? 'sleep-end' : 'time-end'),
            controller: end,
            decoration: const InputDecoration(
              labelText: '结束日期与时间',
              hintText: 'YYYY-MM-DD HH:mm',
            ),
          ),
        ],
      ],
    ),
  );
}
