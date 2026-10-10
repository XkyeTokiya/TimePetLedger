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
  TimeOfDay? first,
  TimeOfDay? last,
}) async {
  FocusScope.of(context).unfocus();
  final base = _base(value, date);
  final clock = await showLedgerClockPicker(
    context,
    initial: TimeOfDay.fromDateTime(base),
    first: first,
    last: last,
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
  TimeOfDay? first,
  TimeOfDay? last,
}) {
  FocusScope.of(context).unfocus();
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) =>
        _ChineseTimePicker(initial: initial, first: first, last: last),
  );
}

/// 按“当前组合中的另一端”推导时分选择范围（用户 2026-10-10 决定）。
///
/// 领域要求 startedAt < endedAt（严格正区间，见 DOMAIN_RULES「时间区间必须为正」）。
/// 两端处于同一自然日时：终点最早 = 起点 + 1 分钟，起点最晚 = 终点 − 1 分钟；
/// 另一端无值、跨日或当日没有合法分钟时不约束，仍由提交校验兜底。无值端点
/// 按 [entryDate] 计算日期，与 [showRecordingTimePicker] 的初值口径一致。
/// 只约束时间范围，不自动改日期、不串联另一端（Q-038 继续有效）。
({TimeOfDay? first, TimeOfDay? last}) ledgerClockRangeFor({
  required int? startedAt,
  required int? endedAt,
  required bool isStart,
  required CivilDate entryDate,
}) {
  final other = isStart ? endedAt : startedAt;
  if (other == null) return (first: null, last: null);
  final otherDate = DateTime.fromMillisecondsSinceEpoch(other);
  final own = isStart ? startedAt : endedAt;
  final ownDate = own != null
      ? DateTime.fromMillisecondsSinceEpoch(own)
      : DateTime(entryDate.year, entryDate.month, entryDate.day);
  final sameDay =
      ownDate.year == otherDate.year &&
      ownDate.month == otherDate.month &&
      ownDate.day == otherDate.day;
  if (!sameDay) return (first: null, last: null);
  final otherMinutes = otherDate.hour * 60 + otherDate.minute;
  if (isStart) {
    final max = otherMinutes - 1;
    if (max < 0) return (first: null, last: null);
    return (first: null, last: TimeOfDay(hour: max ~/ 60, minute: max % 60));
  }
  final min = otherMinutes + 1;
  if (min > 23 * 60 + 59) return (first: null, last: null);
  return (first: TimeOfDay(hour: min ~/ 60, minute: min % 60), last: null);
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
                  child: _WheelColumn(
                    label: '小时',
                    wheelKey: const ValueKey('duration-picker-hour'),
                    bandKey: const ValueKey('duration-picker-hour-band'),
                    controller: hourScroll,
                    childCount: null,
                    onSelectedItemChanged: (v) => setState(() => hours = v),
                    itemBuilder: (context, index) => index < 0
                        ? null
                        : _wheelNumber(context, index, index == hours),
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    label: '分钟',
                    wheelKey: const ValueKey('duration-picker-minute'),
                    bandKey: const ValueKey('duration-picker-minute-band'),
                    controller: minuteScroll,
                    childCount: 60,
                    onSelectedItemChanged: (v) => setState(() => minutes = v),
                    itemBuilder: (context, index) =>
                        _wheelNumber(context, index, index == minutes),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: const Text('选择日期'),
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
                    style: theme.textTheme.titleLarge,
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
  }

  Widget _calendar(BuildContext context) {
    final available = (MediaQuery.sizeOf(context).width - 80).clamp(
      180.0,
      320.0,
    );
    final cell = (available / 7).floorToDouble();
    return SizedBox(width: cell * 7, child: _grid(context, cell));
  }

  Widget _grid(BuildContext context, double cell) {
    final theme = Theme.of(context);
    final weekday = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['一', '二', '三', '四', '五', '六', '日'])
              SizedBox(
                width: cell,
                height: 32,
                child: Center(
                  child: Text(
                    day,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
      child: Semantics(
        label: '${date.year}年${date.month}月${date.day}日',
        selected: selectedDay,
        child: TextButton(
          style: TextButton.styleFrom(
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            backgroundColor: selectedDay ? colors.primary : null,
            foregroundColor: selectedDay ? colors.onPrimary : colors.onSurface,
          ),
          onPressed: () => setState(() => selected = date),
          child: Text('$day'),
        ),
      ),
    );
  }
}

/// 账本风格的中文时分选择器：小时 / 分钟两列，不使用英文 Material 拨盘。
///
/// 可选传入 [first] / [last] 把可选时分限制在另一端点决定的范围；中央选中
/// 项以底带、放大与选中色高亮，非中间项降不透明度。
class _ChineseTimePicker extends StatefulWidget {
  const _ChineseTimePicker({required this.initial, this.first, this.last});
  final TimeOfDay initial;
  final TimeOfDay? first;
  final TimeOfDay? last;

  @override
  State<_ChineseTimePicker> createState() => _ChineseTimePickerState();
}

class _ChineseTimePickerState extends State<_ChineseTimePicker> {
  TimeOfDay? first;
  TimeOfDay? last;
  late int hour;
  late int minute;
  late final FixedExtentScrollController hourScroll;
  late final FixedExtentScrollController minuteScroll;

  @override
  void initState() {
    super.initState();
    var f = widget.first;
    var l = widget.last;
    if (f != null && l != null && _minutesOf(f) > _minutesOf(l)) {
      // 当日没有合法分钟：退回不约束，仍由提交校验兜底。
      f = null;
      l = null;
    }
    first = f;
    last = l;
    var h = widget.initial.hour;
    var m = widget.initial.minute;
    if (f != null &&
        _minutesOf(TimeOfDay(hour: h, minute: m)) < _minutesOf(f)) {
      h = f.hour;
      m = f.minute;
    }
    if (l != null &&
        _minutesOf(TimeOfDay(hour: h, minute: m)) > _minutesOf(l)) {
      h = l.hour;
      m = l.minute;
    }
    hour = h;
    minute = m;
    hourScroll = FixedExtentScrollController(initialItem: h - _hourMin);
    minuteScroll = FixedExtentScrollController(initialItem: m - _minuteMin(h));
  }

  int get _hourMin => first?.hour ?? 0;
  int get _hourMax => last?.hour ?? 23;
  int _minuteMin(int h) => first != null && h == _hourMin ? first!.minute : 0;
  int _minuteMax(int h) => last != null && h == _hourMax ? last!.minute : 59;

  static int _minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

  @override
  void dispose() {
    hourScroll.dispose();
    minuteScroll.dispose();
    super.dispose();
  }

  void _onHour(int index) {
    final next = _hourMin + index;
    final min = _minuteMin(next);
    final max = _minuteMax(next);
    final nextMinute = minute < min
        ? min
        : minute > max
        ? max
        : minute;
    setState(() {
      hour = next;
      minute = nextMinute;
    });
    if (minuteScroll.hasClients) {
      final target = nextMinute - _minuteMin(hour);
      if (minuteScroll.selectedItem != target) minuteScroll.jumpToItem(target);
    }
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
            child: _WheelColumn(
              label: '小时',
              wheelKey: const ValueKey('time-picker-hour'),
              bandKey: const ValueKey('time-picker-hour-band'),
              controller: hourScroll,
              childCount: _hourMax - _hourMin + 1,
              onSelectedItemChanged: _onHour,
              itemBuilder: (context, index) {
                final value = _hourMin + index;
                return _wheelNumber(context, value, value == hour);
              },
            ),
          ),
          Expanded(
            child: _WheelColumn(
              label: '分钟',
              wheelKey: const ValueKey('time-picker-minute'),
              bandKey: const ValueKey('time-picker-minute-band'),
              controller: minuteScroll,
              childCount: _minuteMax(hour) - _minuteMin(hour) + 1,
              onSelectedItemChanged: (index) =>
                  setState(() => minute = _minuteMin(hour) + index),
              itemBuilder: (context, index) {
                final value = _minuteMin(hour) + index;
                return _wheelNumber(context, value, value == minute);
              },
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
}

/// 拨轮中央选中项的数字文本：选中项使用主题主色与更重字重。
Widget _wheelNumber(BuildContext context, int value, bool selected) {
  final colors = Theme.of(context).colorScheme;
  return Center(
    child: Text(
      value.toString().padLeft(2, '0'),
      style: TextStyle(
        fontSize: 22,
        fontWeight: selected ? FontWeight.w600 : null,
        color: selected ? colors.primary : colors.onSurface,
      ),
    ),
  );
}

/// 单列拨轮：中央底带 + 放大中央项 + 非中间项降不透明度。
class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.label,
    required this.controller,
    required this.childCount,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
    required this.bandKey,
    this.wheelKey,
  });
  final String label;
  final FixedExtentScrollController controller;
  final int? childCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;
  final Key bandKey;
  final Key? wheelKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: IgnorePointer(
                    child: Container(
                      key: bandKey,
                      width: double.infinity,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                key: wheelKey,
                controller: controller,
                itemExtent: 44,
                physics: const FixedExtentScrollPhysics(),
                useMagnifier: true,
                magnification: 1.15,
                overAndUnderCenterOpacity: .45,
                onSelectedItemChanged: onSelectedItemChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: childCount,
                  builder: itemBuilder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
