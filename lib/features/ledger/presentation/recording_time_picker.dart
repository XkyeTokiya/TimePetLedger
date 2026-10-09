import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import '../domain/time_precision.dart';

/// 保留的表单 / 预览页面也使用四个独立字段，不再承载双端编辑面板。
class RecordingEndpointFields extends StatelessWidget {
  const RecordingEndpointFields({
    super.key,
    required this.label,
    required this.value,
    required this.keyPrefix,
    required this.onDate,
    required this.onTime,
    this.enabled = true,
    this.precision,
    this.onPrecision,
    this.dateFocus,
    this.timeFocus,
  });
  final String label;
  final int? value;
  final String keyPrefix;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final bool enabled;
  final FocusNode? dateFocus;
  final FocusNode? timeFocus;
  final TimePrecision? precision;
  final ValueChanged<TimePrecision>? onPrecision;
  @override
  Widget build(BuildContext context) {
    final date = value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(value!);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: ValueKey('$keyPrefix-date'),
                focusNode: dateFocus,
                onPressed: enabled ? onDate : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  date == null
                      ? '选日期'
                      : '${date.year}-${two(date.month)}-${two(date.day)}',
                ),
              ),
              TextButton.icon(
                key: ValueKey('$keyPrefix-time'),
                focusNode: timeFocus,
                onPressed: enabled ? onTime : null,
                icon: const Icon(Icons.schedule),
                label: Text(
                  date == null
                      ? '选时间'
                      : '${two(date.hour)}:${two(date.minute)}',
                ),
              ),
            ],
          ),
          if (onPrecision != null)
            Wrap(
              spacing: 8,
              children: [
                for (final choice in TimePrecision.values)
                  ChoiceChip(
                    label: Text(
                      '$label${choice == TimePrecision.exact ? '准确' : '大约'}',
                    ),
                    selected: precision == choice,
                    onSelected: enabled ? (_) => onPrecision!(choice) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 时间字段直达时分组件，保留同一端日期与未选择的秒 / 毫秒。
Future<int?> showRecordingTimePicker(
  BuildContext context, {
  required int? value,
  required CivilDate date,
}) async {
  FocusScope.of(context).unfocus();
  final base = _base(value, date);
  final clock = await showLedgerClockPicker(
    context,
    initial: TimeOfDay.fromDateTime(base),
  );
  if (!context.mounted || clock == null) return null;
  return _combine(context, base, hour: clock.hour, minute: clock.minute);
}

/// 日期字段直达日历，保留同一端时分与未选择的秒 / 毫秒。
Future<int?> showRecordingDatePicker(
  BuildContext context, {
  required int? value,
  required CivilDate date,
}) async {
  FocusScope.of(context).unfocus();
  final base = _base(value, date);
  final day = await showDialog<DateTime>(
    context: context,
    builder: (_) => _ChineseDatePicker(initial: base),
  );
  if (!context.mounted || day == null) return null;
  return _combine(context, base, day: day);
}

Future<TimeOfDay?> showLedgerClockPicker(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  FocusScope.of(context).unfocus();
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _ChineseTimePicker(initial: initial),
  );
}

DateTime _base(int? value, CivilDate date) => value == null
    ? DateTime(date.year, date.month, date.day, 12)
    : DateTime.fromMillisecondsSinceEpoch(value);

int? _combine(
  BuildContext context,
  DateTime base, {
  DateTime? day,
  int? hour,
  int? minute,
}) {
  final chosenDay = day ?? base;
  final h = hour ?? base.hour;
  final m = minute ?? base.minute;
  if (chosenDay.year == base.year &&
      chosenDay.month == base.month &&
      chosenDay.day == base.day &&
      h == base.hour &&
      m == base.minute) {
    return base.millisecondsSinceEpoch;
  }
  final result = DateTime(
    chosenDay.year,
    chosenDay.month,
    chosenDay.day,
    h,
    m,
    base.second,
    base.millisecond,
  );
  if (result.year != chosenDay.year ||
      result.month != chosenDay.month ||
      result.day != chosenDay.day ||
      result.hour != h ||
      result.minute != m) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('所选日期与时间在当地不存在，请重新选择。')));
    return null;
  }
  return result.millisecondsSinceEpoch;
}

Future<({int start, int end})?> showRecordingDurationPicker(
  BuildContext context, {
  required int? startedAt,
  required int? endedAt,
}) async {
  if (startedAt == null && endedAt == null) return null;
  FocusScope.of(context).unfocus();
  return showDialog<({int start, int end})>(
    context: context,
    builder: (_) => _DurationPicker(startedAt: startedAt, endedAt: endedAt),
  );
}

class _DurationPicker extends StatefulWidget {
  const _DurationPicker({required this.startedAt, required this.endedAt});
  final int? startedAt;
  final int? endedAt;
  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late bool fromStart = widget.startedAt != null;
  late final initialMinutes =
      widget.startedAt != null &&
          widget.endedAt != null &&
          widget.endedAt! > widget.startedAt!
      ? (widget.endedAt! - widget.startedAt!) ~/ 60000
      : 30;
  late int hours = initialMinutes ~/ 60;
  late int minutes = initialMinutes % 60;
  late final hourScroll = FixedExtentScrollController(initialItem: hours);
  late final minuteScroll = FixedExtentScrollController(initialItem: minutes);
  @override
  void dispose() {
    hourScroll.dispose();
    minuteScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('调整时长'),
    content: SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: const Text('从开始算'),
                enabled: widget.startedAt != null,
              ),
              ButtonSegment(
                value: false,
                label: const Text('从结束算'),
                enabled: widget.endedAt != null,
              ),
            ],
            selected: {fromStart},
            onSelectionChanged: (v) => setState(() => fromStart = v.single),
          ),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: _wheel(
                    hourScroll,
                    null,
                    '小时',
                    (v) => setState(() => hours = v),
                  ),
                ),
                Expanded(
                  child: _wheel(
                    minuteScroll,
                    60,
                    '分钟',
                    (v) => setState(() => minutes = v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('duration-picker-confirm'),
        onPressed: hours + minutes == 0
            ? null
            : () {
                final duration = Duration(
                  hours: hours,
                  minutes: minutes,
                ).inMilliseconds;
                final start = fromStart
                    ? widget.startedAt!
                    : widget.endedAt! - duration;
                Navigator.pop(context, (start: start, end: start + duration));
              },
        child: const Text('确定'),
      ),
    ],
  );
  Widget _wheel(
    FixedExtentScrollController controller,
    int? count,
    String label,
    ValueChanged<int> onPick,
  ) => Column(
    children: [
      const SizedBox(height: 12),
      Text(label),
      Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onPick,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (_, index) => index < 0
                ? null
                : Center(
                    child: Text('$index', style: const TextStyle(fontSize: 22)),
                  ),
          ),
        ),
      ),
    ],
  );
}

class _ChineseDatePicker extends StatefulWidget {
  const _ChineseDatePicker({required this.initial});
  final DateTime initial;

  @override
  State<_ChineseDatePicker> createState() => _ChineseDatePickerState();
}

class _ChineseDatePickerState extends State<_ChineseDatePicker> {
  late DateTime month = DateTime.utc(
    widget.initial.year,
    widget.initial.month,
    1,
  );
  late DateTime selected = DateTime.utc(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  void _move(int direction) => setState(() {
    month = DateTime.utc(month.year, month.month + direction, 1);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '上个月',
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.year}年${month.month}月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: '下个月',
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          _calendar(context),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('date-picker-confirm'),
        onPressed: () => Navigator.pop(context, selected),
        child: const Text('确定'),
      ),
    ],
  );

  Widget _calendar(BuildContext context) {
    final available = (MediaQuery.sizeOf(context).width - 80).clamp(
      180.0,
      320.0,
    );
    final cell = (available / 7).floorToDouble();
    return SizedBox(width: cell * 7, child: _grid(context, cell));
  }

  Widget _grid(BuildContext context, double cell) {
    final weekday = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['一', '二', '三', '四', '五', '六', '日'])
              SizedBox(
                width: cell,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < (weekday + count + 6) ~/ 7; week++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                _cell(context, week * 7 + column - weekday + 1, count, cell),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int count, double cell) {
    if (day < 1 || day > count) return SizedBox(width: cell, height: cell);
    final date = DateTime.utc(month.year, month.month, day);
    final colors = Theme.of(context).colorScheme;
    final selectedDay =
        date.year == selected.year &&
        date.month == selected.month &&
        date.day == selected.day;
    return SizedBox(
      width: cell,
      height: cell,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selectedDay ? colors.primary : null,
          foregroundColor: selectedDay ? colors.onPrimary : colors.onSurface,
        ),
        onPressed: () => setState(() => selected = date),
        child: Text('$day', style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// 账本风格的中文时分选择器：小时 / 分钟两列，不使用英文 Material 拨盘。
class _ChineseTimePicker extends StatefulWidget {
  const _ChineseTimePicker({required this.initial});
  final TimeOfDay initial;

  @override
  State<_ChineseTimePicker> createState() => _ChineseTimePickerState();
}

class _ChineseTimePickerState extends State<_ChineseTimePicker> {
  late int hour = widget.initial.hour;
  late int minute = widget.initial.minute;
  late final hourScroll = FixedExtentScrollController(initialItem: hour);
  late final minuteScroll = FixedExtentScrollController(initialItem: minute);
  @override
  void dispose() {
    hourScroll.dispose();
    minuteScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择时分'),
    content: SizedBox(
      height: 260,
      width: 220,
      child: Row(
        children: [
          Expanded(
            child: _column(
              context,
              24,
              hourScroll,
              (v) => setState(() => hour = v),
              '小时',
            ),
          ),
          Expanded(
            child: _column(
              context,
              60,
              minuteScroll,
              (v) => setState(() => minute = v),
              '分钟',
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('time-picker-confirm'),
        onPressed: () =>
            Navigator.pop(context, TimeOfDay(hour: hour, minute: minute)),
        child: const Text('确定'),
      ),
    ],
  );

  Widget _column(
    BuildContext context,
    int count,
    FixedExtentScrollController controller,
    ValueChanged<int> onPick,
    String label,
  ) => Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          onSelectedItemChanged: onPick,
          physics: const FixedExtentScrollPhysics(),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) => Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
