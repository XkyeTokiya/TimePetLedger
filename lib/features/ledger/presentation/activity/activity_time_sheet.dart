import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../domain/projection/derived_duration.dart';
import '../recording_form.dart' show formatRecordingTime;
import '../sleep_time_input.dart' show parseSleepTime;
import '../summary_formatting.dart';

/// 时间页的时间选择器：两端各自独立选日期、选时分，取消不写入父草稿。
///
/// 默认标签与键位服务活动页；睡眠页通过参数复用同一交互，避免另造选择器。
Future<({int? start, int? end})?> showActivityTimeSheet(
  BuildContext context, {
  required int? startedAt,
  required int? endedAt,
  required CivilDate date,
  String title = '这段是什么时候？',
  String subtitle = '两端各自独立。',
  String startLabel = '开始',
  String endLabel = '结束',
  String keyPrefix = 'activity',
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<({int? start, int? end})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ActivityTimeSheet(
      startedAt: startedAt,
      endedAt: endedAt,
      date: date,
      title: title,
      subtitle: subtitle,
      startLabel: startLabel,
      endLabel: endLabel,
      keyPrefix: keyPrefix,
    ),
  );
}

class _Endpoint {
  _Endpoint(this.original) {
    if (original != null) {
      final value = DateTime.fromMillisecondsSinceEpoch(original!);
      date = DateTime(value.year, value.month, value.day);
      clock = TimeOfDay.fromDateTime(value);
    }
  }
  final int? original;
  DateTime? date;
  TimeOfDay? clock;

  /// 直接输入时暂存原文；未触碰端点时保持 null，保留原始毫秒。
  String? manual;

  /// 未修改时保留原始毫秒；显示分钟不代表舍入存储。
  int? get value {
    if (manual != null) return parseSleepTime(manual!);
    if (date == null || clock == null) return original;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      clock!.hour,
      clock!.minute,
    ).millisecondsSinceEpoch;
  }
}

class _ActivityTimeSheet extends StatefulWidget {
  const _ActivityTimeSheet({
    required this.startedAt,
    required this.endedAt,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.startLabel,
    required this.endLabel,
    required this.keyPrefix,
  });
  final int? startedAt;
  final int? endedAt;
  final CivilDate date;
  final String title;
  final String subtitle;
  final String startLabel;
  final String endLabel;
  final String keyPrefix;

  @override
  State<_ActivityTimeSheet> createState() => _ActivityTimeSheetState();
}

class _ActivityTimeSheetState extends State<_ActivityTimeSheet> {
  late final start = _Endpoint(widget.startedAt);
  late final end = _Endpoint(widget.endedAt);
  late final startText = TextEditingController(
    text: widget.startedAt == null ? '' : formatRecordingTime(widget.startedAt),
  );
  late final endText = TextEditingController(
    text: widget.endedAt == null ? '' : formatRecordingTime(widget.endedAt),
  );
  bool manual = false;
  String? error;

  @override
  void dispose() {
    startText.dispose();
    endText.dispose();
    super.dispose();
  }

  DateTime baseDate(_Endpoint endpoint) =>
      endpoint.date ??
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  String? get _preview {
    final a = start.value;
    final b = end.value;
    if (a == null || b == null || b <= a) return null;
    return formatDerivedDuration(
      DerivedDuration(milliseconds: b - a, hasApproximation: true),
    );
  }

  Future<void> pickDate(_Endpoint endpoint, String label) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _ChineseDatePicker(initial: baseDate(endpoint)),
    );
    if (!mounted || picked == null) return;
    setState(() {
      endpoint.date = picked;
      error = null;
    });
  }

  Future<void> pickClock(_Endpoint endpoint, String label) async {
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => _ChineseTimePicker(
        initial: endpoint.clock ?? const TimeOfDay(hour: 12, minute: 0),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      endpoint.clock = picked;
      error = null;
    });
  }

  void apply() {
    if (manual) {
      start.manual = startText.text;
      end.manual = endText.text;
    }
    final a = start.value;
    final b = end.value;
    if (a == null || b == null) {
      setState(
        () => error = manual
            ? '请输入有效日期与时间，如 2026-10-05 10:30。'
            : '先选好开始和结束的日期、时间。',
      );
      return;
    }
    if (b <= a) {
      setState(() => error = '结束要晚于开始。跨日的话，请把结束日期选到第二天。');
      return;
    }
    Navigator.pop(context, (start: a, end: b));
  }

  String _dateLabel(DateTime? value) =>
      value == null ? '选择日期' : '${value.year}年${value.month}月${value.day}日';

  String _clockLabel(TimeOfDay? value) => value == null
      ? '选时间'
      : '${value.hour.toString().padLeft(2, '0')}:'
            '${value.minute.toString().padLeft(2, '0')}';

  Widget _manualField(TextEditingController value, String name, String key) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          key: ValueKey('$key-manual'),
          controller: value,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            labelText: '$name · YYYY-MM-DD HH:mm',
            hintText: '2026-10-05 10:30',
          ),
        ),
      );

  Widget endpoint(_Endpoint value, String name, String key) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: _muted),
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: ValueKey('$key-date'),
              onPressed: () => pickDate(value, name),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(_dateLabel(value.date)),
            ),
            TextButton(
              key: ValueKey('$key-clock'),
              onPressed: () => pickClock(value, name),
              child: Text(_clockLabel(value.clock), style: _clockStyle),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: _title),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: _muted),
              endpoint(start, widget.startLabel, '${widget.keyPrefix}-start'),
              if (manual)
                _manualField(
                  startText,
                  widget.startLabel,
                  '${widget.keyPrefix}-start',
                ),
              endpoint(end, widget.endLabel, '${widget.keyPrefix}-end'),
              if (manual)
                _manualField(
                  endText,
                  widget.endLabel,
                  '${widget.keyPrefix}-end',
                ),
              const SizedBox(height: 8),
              TextButton(
                key: ValueKey('${widget.keyPrefix}-time-manual'),
                onPressed: () => setState(() {
                  manual = !manual;
                  error = null;
                }),
                child: Text(manual ? '收起直接输入' : '直接输入日期时间'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _preview == null ? '选择两端后显示时长' : '共 $_preview',
                  key: ValueKey('${widget.keyPrefix}-time-duration'),
                  style: _muted,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  key: ValueKey('${widget.keyPrefix}-time-error'),
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 14,
                    color: HomePalette.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: ValueKey('${widget.keyPrefix}-time-apply'),
                onPressed: apply,
                child: const Text('确认'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 供时间页与测试复用的“已选区间”文案。
String activityTimeSummary(int? startedAt, int? endedAt) =>
    '${formatRecordingTime(startedAt)} → ${formatRecordingTime(endedAt)}';

/// 账本风格的中文日期选择器：月历网格，标题与星期均为中文，不使用英文
/// Material 日期控件。
class _ChineseDatePicker extends StatefulWidget {
  const _ChineseDatePicker({required this.initial});
  final DateTime initial;

  @override
  State<_ChineseDatePicker> createState() => _ChineseDatePickerState();
}

class _ChineseDatePickerState extends State<_ChineseDatePicker> {
  late DateTime month = DateTime(widget.initial.year, widget.initial.month, 1);
  late DateTime selected = DateTime(
    widget.initial.year,
    widget.initial.month,
    widget.initial.day,
  );

  void _move(int direction) => setState(() {
    month = DateTime(month.year, month.month + direction, 1);
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
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: HomePalette.ink,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final cell = (constraints.maxWidth / 7).floorToDouble();
              return SizedBox(width: cell * 7, child: _grid(cell));
            },
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
        key: const ValueKey('date-picker-confirm'),
        onPressed: () => Navigator.pop(context, selected),
        child: const Text('确定'),
      ),
    ],
  );

  Widget _grid(double cell) {
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
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 13,
                    color: HomePalette.muted,
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < (weekday + count + 6) ~/ 7; week++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                _cell(week * 7 + column - weekday + 1, count, cell),
            ],
          ),
      ],
    );
  }

  Widget _cell(int day, int count, double cell) {
    if (day < 1 || day > count) return SizedBox(width: cell, height: cell);
    final date = DateTime(month.year, month.month, day);
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
          backgroundColor: selectedDay ? HomePalette.accentDeep : null,
          foregroundColor: selectedDay ? Colors.white : HomePalette.ink,
        ),
        onPressed: () => setState(() => selected = date),
        child: Text(
          '$day',
          style: const TextStyle(fontFamily: homeSerifFamily, fontSize: 15),
        ),
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择时分'),
    content: SizedBox(
      height: 260,
      width: 220,
      child: Row(
        children: [
          Expanded(
            child: _column(24, hour, (v) => setState(() => hour = v), '小时'),
          ),
          Expanded(
            child: _column(60, minute, (v) => setState(() => minute = v), '分钟'),
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
    int count,
    int current,
    ValueChanged<int> onPick,
    String label,
  ) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 14,
          color: HomePalette.muted,
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ListWheelScrollView.useDelegate(
          controller: FixedExtentScrollController(initialItem: current),
          itemExtent: 44,
          onSelectedItemChanged: onPick,
          physics: const FixedExtentScrollPhysics(),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) => Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: homeSerifFamily,
                  fontSize: 22,
                  color: HomePalette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

const _title = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 26,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _muted = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.5,
  color: HomePalette.muted,
);
const _clockStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 26,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
