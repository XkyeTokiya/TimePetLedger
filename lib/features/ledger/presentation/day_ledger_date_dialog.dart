import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';
import 'recording_form.dart';

String ledgerDateText(CivilDate date) =>
    '${date.year < 0 ? '-' : ''}${date.year.abs().toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 只移动自然日，不以 epoch 上的固定 24 小时推算日期。
CivilDate adjacentLedgerDate(CivilDate date, int direction) {
  assert(direction == -1 || direction == 1);
  try {
    return CivilDate(
      year: date.year,
      month: date.month,
      day: date.day + direction,
    );
  } on ArgumentError {
    final month = date.month + direction;
    final year =
        date.year +
        (month == 0
            ? -1
            : month == 13
            ? 1
            : 0);
    final normalized = month == 0
        ? 12
        : month == 13
        ? 1
        : month;
    if (direction == 1) return CivilDate(year: year, month: normalized, day: 1);
    for (var day = 31; day >= 28; day--) {
      try {
        return CivilDate(year: year, month: normalized, day: day);
      } on ArgumentError {
        // 前一个月最后一个合法自然日。
      }
    }
    throw StateError('CivilDate month has no last day');
  }
}

Future<CivilDate?> showDayLedgerDateDialog(
  BuildContext context,
  CivilDate date, {
  bool manual = false,
  VoidCallback? onToday,
  String? modeDescription,
}) => showDialog<CivilDate>(
  context: context,
  builder: (_) => _DateDialog(
    date: date,
    manual: manual,
    onToday: onToday,
    modeDescription: modeDescription,
  ),
);

class _DateDialog extends StatefulWidget {
  const _DateDialog({
    required this.date,
    required this.manual,
    this.onToday,
    this.modeDescription,
  });
  final VoidCallback? onToday;
  final String? modeDescription;
  final CivilDate date;
  final bool manual;
  @override
  State<_DateDialog> createState() => _DateDialogState();
}

class _DateDialogState extends State<_DateDialog> {
  late CivilDate selected = widget.date;
  // 日历显示范围是控件能力，手动解析仍接受原来的合法领域日期。
  late CivilDate month = CivilDate(
    year: widget.date.year.clamp(1, 9999),
    month: widget.date.month,
    day: 1,
  );
  late bool manual =
      widget.manual || widget.date.year < 1 || widget.date.year > 9999;
  late final text = TextEditingController(text: ledgerDateText(widget.date));
  bool invalid = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _confirm() {
    final date = manual ? parseRecordingDate(text.text) : selected;
    if (date == null) {
      setState(() => invalid = true);
    } else {
      Navigator.pop(context, date);
    }
  }

  void _moveMonth(int direction) {
    final next = month.month + direction;
    setState(
      () => month = CivilDate(
        year:
            month.year +
            (next == 0
                ? -1
                : next == 13
                ? 1
                : 0),
        month: next == 0
            ? 12
            : next == 13
            ? 1
            : next,
        day: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    scrollable: true,
    title: const Text('选择账本日期'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 368),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.modeDescription != null) Text(widget.modeDescription!),
          if (widget.onToday != null)
            TextButton(
              onPressed: () {
                widget.onToday!();
                Navigator.pop(context);
              },
              child: const Text('今天'),
            ),
          if (manual)
            TextField(
              controller: text,
              decoration: InputDecoration(
                labelText: '账本日期',
                hintText: 'YYYY-MM-DD',
                errorText: invalid ? '请输入有效日期 YYYY-MM-DD。' : null,
              ),
              onChanged: (_) {
                if (invalid) setState(() => invalid = false);
              },
            )
          else ...[
            Text(
              '${month.year}年${month.month}月',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: '上个月',
                  onPressed: month.year == 1 && month.month == 1
                      ? null
                      : () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: month.year == 9999 && month.month == 12
                      ? null
                      : () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            // 七列在窄屏也完整可见：按可用宽度分配单元格，不再横向滚动。
            LayoutBuilder(
              builder: (context, constraints) {
                final cell = (constraints.maxWidth / 7).floorToDouble();
                return SizedBox(width: cell * 7, child: _calendar(cell));
              },
            ),
            const SizedBox(height: 8),
            Text('已选 ${ledgerDateText(selected)}'),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              manual = !manual;
              invalid = false;
              if (manual) text.text = ledgerDateText(selected);
            }),
            child: Text(manual ? '使用日历' : '手动输入日期'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('确认日期')),
    ],
  );

  Widget _calendar(double cell) {
    final weekday = DateTime.utc(month.year, month.month, 1).weekday - 1;
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['一', '二', '三', '四', '五', '六', '日'])
              SizedBox(
                width: cell,
                height: cell,
                child: Center(child: Text(day)),
              ),
          ],
        ),
        for (var week = 0; week < (weekday + count + 6) ~/ 7; week++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                _day(week * 7 + column - weekday + 1, count, cell),
            ],
          ),
      ],
    );
  }

  Widget _day(int day, int count, double cell) {
    if (day < 1 || day > count) return SizedBox(width: cell, height: cell);
    final date = CivilDate(year: month.year, month: month.month, day: day);
    return SizedBox(
      width: cell,
      height: cell,
      child: Semantics(
        label: ledgerDateText(date),
        selected: date == selected,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: date == selected
                ? Theme.of(context).colorScheme.primary
                : null,
            foregroundColor: date == selected
                ? Theme.of(context).colorScheme.onPrimary
                : null,
          ),
          onPressed: () => setState(() => selected = date),
          child: Text('$day'),
        ),
      ),
    );
  }
}
