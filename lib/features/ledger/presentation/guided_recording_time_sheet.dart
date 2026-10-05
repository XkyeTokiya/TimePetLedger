import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../application/recording_time_suggestion.dart';
import '../domain/time_precision.dart';
import 'sleep_time_input.dart';

/// A temporary copy. Dismissal never writes to the recording controller.
Future<RecordingTimeInput?> showGuidedRecordingTimeSheet(
  BuildContext context, {
  required RecordingTimeInput initial,
  required CivilDate date,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<RecordingTimeInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GuidedRecordingTimeSheet(initial: initial, date: date),
  );
}

class _Endpoint {
  _Endpoint(this.original) {
    if (original != null) {
      final value = DateTime.fromMillisecondsSinceEpoch(original!);
      date = DateTime(value.year, value.month, value.day);
      clock = TimeOfDay.fromDateTime(value);
    }
    text = TextEditingController(text: formatSleepTime(original));
  }
  final int? original;
  DateTime? date;
  TimeOfDay? clock;
  late final TextEditingController text;
  bool changed = false;

  int? get value {
    if (!changed) return original;
    return parseSleepTime(text.text);
  }

  void syncText() {
    changed = true;
    if (date == null || clock == null) return;
    String two(int value) => value.toString().padLeft(2, '0');
    text.text =
        '${date!.year.toString().padLeft(4, '0')}-'
        '${two(date!.month)}-${two(date!.day)} '
        '${two(clock!.hour)}:${two(clock!.minute)}';
  }
}

class GuidedRecordingTimeSheet extends StatefulWidget {
  const GuidedRecordingTimeSheet({
    super.key,
    required this.initial,
    required this.date,
  });
  final RecordingTimeInput initial;
  final CivilDate date;
  @override
  State<GuidedRecordingTimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<GuidedRecordingTimeSheet> {
  late final start = _Endpoint(widget.initial.startedAt);
  late final end = _Endpoint(widget.initial.endedAt);
  late var startPrecision = widget.initial.startPrecision;
  late var endPrecision = widget.initial.endPrecision;
  String? error;
  bool manual = false;

  @override
  void dispose() {
    start.text.dispose();
    end.text.dispose();
    super.dispose();
  }

  DateTime baseDate(_Endpoint endpoint) =>
      endpoint.date ??
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  Future<void> pickDate(_Endpoint endpoint, String label) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: baseDate(endpoint),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '$label日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || picked == null) return;
    setState(() {
      endpoint.date = picked;
      endpoint.syncText();
      error = null;
    });
  }

  Future<void> pickClock(_Endpoint endpoint, String label) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endpoint.clock ?? const TimeOfDay(hour: 12, minute: 0),
      initialEntryMode: TimePickerEntryMode.dialOnly,
      helpText: '$label时分',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      endpoint.clock = picked;
      endpoint.syncText();
      error = null;
    });
  }

  void apply() {
    final a = start.value;
    final b = end.value;
    if (a == null || b == null || a >= b) {
      setState(
        () => error = a == null || b == null
            ? '请为两端选择日期和时分。直接输入时请使用有效的 YYYY-MM-DD HH:mm。'
            : '结束时间必须晚于开始时间。跨日时，请明确选择结束日期。',
      );
      return;
    }
    Navigator.pop(
      context,
      RecordingTimeInput(
        startedAt: a,
        endedAt: b,
        startPrecision: startPrecision,
        endPrecision: endPrecision,
      ),
    );
  }

  Widget endpoint(
    _Endpoint value,
    String name,
    String key,
    TimePrecision precision,
  ) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = value.date;
    final clock = value.clock;
    return Card.outlined(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: ValueKey('$key-date'),
              onPressed: () => pickDate(value, name),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                date == null
                    ? '选择日期'
                    : '${date.year}-${two(date.month)}-${two(date.day)}',
              ),
            ),
            OutlinedButton.icon(
              key: ValueKey('$key-clock'),
              onPressed: () => pickClock(value, name),
              icon: const Icon(Icons.schedule),
              label: Text(
                clock == null
                    ? '选择时分'
                    : '${two(clock.hour)}:${two(clock.minute)}',
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TimePrecision>(
              key: ValueKey('$key-precision'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TimePrecision.exact, label: Text('准确')),
                ButtonSegment(
                  value: TimePrecision.approximate,
                  label: Text('大概'),
                ),
              ],
              selected: {precision},
              onSelectionChanged: (selected) => setState(() {
                if (value == start) {
                  startPrecision = selected.single;
                } else {
                  endPrecision = selected.single;
                }
              }),
            ),
            if (manual) ...[
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('$key-manual'),
                controller: value.text,
                decoration: const InputDecoration(
                  labelText: 'YYYY-MM-DD HH:mm',
                ),
                onChanged: (_) {
                  value.changed = true;
                  final parsed = parseSleepTime(value.text.text);
                  setState(() {
                    final time = parsed == null
                        ? null
                        : DateTime.fromMillisecondsSinceEpoch(parsed);
                    value.date = time == null
                        ? null
                        : DateTime(time.year, time.month, time.day);
                    value.clock = time == null
                        ? null
                        : TimeOfDay.fromDateTime(time);
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('调整这段时间', style: Theme.of(context).textTheme.titleLarge),
              const Text('分别选择两端。修改只在应用后保留。'),
              endpoint(start, '开始', 'guided-start', startPrecision),
              endpoint(end, '结束', 'guided-end', endPrecision),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => manual = !manual),
                child: Text(manual ? '收起直接输入' : '直接输入日期时间'),
              ),
              FilledButton(
                key: const ValueKey('guided-time-apply'),
                onPressed: apply,
                child: const Text('应用时间'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消修改'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
