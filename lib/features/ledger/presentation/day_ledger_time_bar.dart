import 'package:flutter/material.dart';

import '../application/recording_ledger_loader.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/projection/day_ledger_view.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart';
import 'summary_formatting.dart';

/// 只读刻度的实际 instant，不是覆盖或统计模型。
typedef DayLedgerTimeTick = ({int instant, String label});

String _clock(int instant) => formatRecordingTime(instant).split(' ').last;

String _offset(Duration offset) {
  final minutes = offset.inMinutes.abs();
  return 'UTC${offset.isNegative ? '-' : '+'}'
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

/// 从实际日窗口内出现的时区偏移解析当地整点。重复时刻保留两个
/// instant；不存在的整点不产生刻度。所有位置仍以 epoch 毫秒计算。
List<DayLedgerTimeTick> dayLedgerTimeTicks(RecordingDateContext context) {
  final start = context.dayStartedAt;
  final end = context.nextDayStartedAt;
  final localDate = DateTime.fromMillisecondsSinceEpoch(start);
  final offsets = <Duration>{};
  for (var instant = start; instant < end; instant += 15 * 60000) {
    offsets.add(DateTime.fromMillisecondsSinceEpoch(instant).timeZoneOffset);
  }
  final ticks = <DayLedgerTimeTick>[(instant: start, label: _clock(start))];
  for (var hour = 0; hour < 24; hour++) {
    final wall = DateTime.utc(
      localDate.year,
      localDate.month,
      localDate.day,
      hour,
    ).millisecondsSinceEpoch;
    final candidates = <int>[];
    for (final offset in offsets) {
      final instant = wall - offset.inMilliseconds;
      if (instant < start || instant >= end) continue;
      final local = DateTime.fromMillisecondsSinceEpoch(instant);
      if (local.year == localDate.year &&
          local.month == localDate.month &&
          local.day == localDate.day &&
          local.hour == hour &&
          local.minute == 0 &&
          local.second == 0) {
        candidates.add(instant);
      }
    }
    candidates.sort();
    if (hour % 6 != 0 && candidates.length < 2) continue;
    for (final instant in candidates) {
      final offset = DateTime.fromMillisecondsSinceEpoch(instant)
          .timeZoneOffset;
      if (instant == start) {
        if (candidates.length > 1) {
          ticks[0] = (
            instant: start,
            label: '${_clock(start)} (${_offset(offset)})',
          );
        }
        continue;
      }
      ticks.add((
        instant: instant,
        label:
            '${_clock(instant)}'
            '${candidates.length > 1 ? ' (${_offset(offset)})' : ''}',
      ));
    }
  }
  ticks.sort((a, b) => a.instant.compareTo(b.instant));
  ticks.add((instant: end, label: '次日 ${_clock(end)}'));
  return List.unmodifiable(ticks);
}

class DayLedgerTimeBar extends StatelessWidget {
  const DayLedgerTimeBar({
    super.key,
    required this.view,
    required this.dateContext,
    this.showLegend = true,
  });
  final DayLedgerView view;
  final RecordingDateContext dateContext;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ticks = dayLedgerTimeTicks(dateContext)
        .map(
          (tick) =>
              !showLegend &&
                  tick.instant == dateContext.nextDayStartedAt &&
                  tick.label == '次日 00:00'
              ? (instant: tick.instant, label: '24:00')
              : tick,
        )
        .toList();
    final start = dateContext.dayStartedAt;
    final end = dateContext.nextDayStartedAt;
    final semantics = <String>[
      '全天时间分布：${formatRecordingTime(start)} 至 ${formatRecordingTime(end)}',
      for (final segment in view.segments)
        '${_kind(segment)}：${_precisionTime(segment.startedAt, segment.startPrecision)}'
            ' 至 ${_precisionTime(segment.endedAt, segment.endPrecision)}，${formatDerivedDuration(segment.duration)}',
      for (final gap in view.unresolvedSpans)
        '尚未记录：${_precisionTime(gap.startedAt, gap.startPrecision)}'
            ' 至 ${_precisionTime(gap.endedAt, gap.endPrecision)}，${formatDerivedDuration(gap.duration)}',
      if (view.window.endedAt < end)
        '尚未发生：${_clock(view.window.endedAt)} 至 ${_clock(end)}，不可补记',
      '刻度：${ticks.map((tick) => tick.label).join('，')}',
      '时间条只读，编辑和补记请使用下方时间轴',
    ].join('；');
    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                double x(int instant) =>
                    width * (instant - start) / (end - start);
                Widget part({
                  required Key key,
                  required int from,
                  required int to,
                  required Widget child,
                }) => Positioned(
                  left: x(from),
                  width: x(to) - x(from),
                  top: 0,
                  bottom: 0,
                  child: KeyedSubtree(key: key, child: child),
                );
                return SizedBox(
                  key: const ValueKey('day-time-bar'),
                  height: showLegend ? 16 : 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: colors.surfaceContainerHighest,
                          ),
                        ),
                        for (final segment in view.segments)
                          part(
                            key: ValueKey(
                              'bar-${segment.reference.type.name}:${segment.reference.id}',
                            ),
                            from: segment.startedAt,
                            to: segment.endedAt,
                            child: ColoredBox(
                              color: switch (segment) {
                                SleepSessionSegment() => colors.secondary,
                                TimeBlockSegment() =>
                                  segment.source.knowledgeState ==
                                          BlockKnowledgeState.unknown
                                      ? colors.tertiary
                                      : colors.primary,
                              },
                            ),
                          ),
                        for (final gap in view.unresolvedSpans)
                          part(
                            key: ValueKey('bar-gap-${gap.startedAt}'),
                            from: gap.startedAt,
                            to: gap.endedAt,
                            child: CustomPaint(
                              painter: _GapOutline(colors.onSurfaceVariant),
                            ),
                          ),
                        if (view.window.endedAt < end)
                          part(
                            key: const ValueKey('bar-not-yet'),
                            from: view.window.endedAt,
                            to: end,
                            child: ColoredBox(
                              color: colors.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _TimeTicks(ticks: ticks, startedAt: start, endedAt: end),
            const SizedBox(height: 8),
            if (showLegend)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Legend('睡眠', colors.secondary),
                  _Legend('活动', colors.primary),
                  _Legend('想不起来', colors.tertiary),
                  _Legend('尚未记录', colors.onSurfaceVariant, gap: true),
                  if (view.window.endedAt < end)
                    Text(
                      '尚未发生',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 13),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _kind(LedgerSegment segment) => switch (segment) {
  SleepSessionSegment() => '睡眠',
  TimeBlockSegment() =>
    segment.source.knowledgeState == BlockKnowledgeState.unknown
        ? '想不起来，已交代'
        : '活动',
};
String _precisionTime(int instant, TimePrecision precision) =>
    '${precision == TimePrecision.approximate ? '约' : ''}${_clock(instant)}';

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color, {this.gap = false});
  final String label;
  final Color color;
  final bool gap;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 12,
        height: 12,
        child: gap
            ? CustomPaint(painter: _GapOutline(color))
            : ColoredBox(color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
    ],
  );
}

class _TimeTicks extends StatelessWidget {
  const _TimeTicks({
    required this.ticks,
    required this.startedAt,
    required this.endedAt,
  });
  final List<DayLedgerTimeTick> ticks;
  final int startedAt;
  final int endedAt;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodySmall!
          .copyWith(fontSize: 12);
      final scaler = MediaQuery.textScalerOf(context);
      final width = constraints.maxWidth;
      final labels = ticks.map((tick) {
        final painter = TextPainter(
          text: TextSpan(text: tick.label, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        final x = width * (tick.instant - startedAt) / (endedAt - startedAt);
        final left = (x - painter.width / 2).clamp(
          0.0,
          (width - painter.width).clamp(0.0, width),
        );
        final measured = (
          tick: tick,
          left: left,
          width: painter.width,
          height: painter.height,
        );
        painter.dispose();
        return measured;
      }).toList();
      if (labels.first.width + labels.last.width + 8 > width) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(ticks.first.label, style: style)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ticks.last.label,
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ],
        );
      }
      final visible = [labels.first];
      for (final label in labels.skip(1).take(labels.length - 2)) {
        final previous = visible.last;
        if (label.left >= previous.left + previous.width + 8 &&
            label.left + label.width + 8 <= labels.last.left) {
          visible.add(label);
        }
      }
      visible.add(labels.last);
      return SizedBox(
        height: labels.first.height,
        child: Stack(
          children: [
            for (final label in visible)
              Positioned(
                left: label.left,
                top: 0,
                child: Text(label.tick.label, style: style),
              ),
          ],
        ),
      );
    },
  );
}

class _GapOutline extends CustomPainter {
  const _GapOutline(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = 0.0; x < size.width; x += 7) {
      final right = (x + 4).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, .5), Offset(right, .5), paint);
      canvas.drawLine(
        Offset(x, size.height - .5),
        Offset(right, size.height - .5),
        paint,
      );
    }
    canvas.drawLine(const Offset(.5, 0), Offset(.5, size.height), paint);
    canvas.drawLine(
      Offset(size.width - .5, 0),
      Offset(size.width - .5, size.height),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GapOutline oldDelegate) => color != oldDelegate.color;
}
