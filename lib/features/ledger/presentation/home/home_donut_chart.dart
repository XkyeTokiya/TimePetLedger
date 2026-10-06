import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../domain/projection/derived_duration.dart';
import '../summary_formatting.dart';

/// 环图分段：实际时长与展示颜色；[dashed] 用于派生缺口。
final class DonutPart {
  const DonutPart({
    required this.id,
    required this.label,
    required this.color,
    required this.duration,
    this.dashed = false,
  });

  final String id;
  final String label;
  final Color color;
  final DerivedDuration duration;
  final bool dashed;
}

/// 只读时间构成环图：按实际毫秒计算占比，点击图例查看所选部分百分比。
///
/// 不查询或重算时长；中心展示调用方给定的汇总文案，比例最终展示才取整
/// （Q-017）。分母为各部分实际时长之和，即该窗口或该范围内的总时长。
class HomeDonutChart extends StatefulWidget {
  const HomeDonutChart({
    super.key,
    required this.parts,
    required this.centerLabel,
    required this.centerValue,
    required this.semanticsLabel,
  });

  final List<DonutPart> parts;
  final String centerLabel;
  final String centerValue;
  final String semanticsLabel;

  @override
  State<HomeDonutChart> createState() => _HomeDonutChartState();
}

class _HomeDonutChartState extends State<HomeDonutChart> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final total = widget.parts.fold<int>(
      0,
      (sum, part) => sum + part.duration.milliseconds,
    );
    if (total <= 0) {
      return const Text(
        '当前窗口暂无可显示的时间构成。',
        style: TextStyle(
          fontFamily: homeSerifFamily,
          fontSize: 14,
          height: 1.5,
          color: HomePalette.muted,
        ),
      );
    }
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in widget.parts)
          _LegendRow(
            part: part,
            total: total,
            selected: _selected == part.id,
            onTap: () => setState(
              () => _selected = _selected == part.id ? null : part.id,
            ),
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final ring = _Ring(
          parts: widget.parts,
          total: total,
          selected: _selected,
          centerLabel: widget.centerLabel,
          centerValue: widget.centerValue,
          semanticsLabel: widget.semanticsLabel,
        );
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: ring),
              const SizedBox(height: 16),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ring,
            const SizedBox(width: 20),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.parts,
    required this.total,
    required this.selected,
    required this.centerLabel,
    required this.centerValue,
    required this.semanticsLabel,
  });

  final List<DonutPart> parts;
  final int total;
  final String? selected;
  final String centerLabel;
  final String centerValue;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: semanticsLabel,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 168,
        height: 168,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(168),
              painter: _DonutPainter(
                parts: parts,
                total: total,
                selected: selected,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 13,
                    color: HomePalette.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  centerValue,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: HomePalette.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.part,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final DonutPart part;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final durationText = formatDerivedDuration(part.duration);
    final percent = (part.duration.milliseconds * 100 / total).round();
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '${part.label} $durationText，占 $percent%'
          : '${part.label} $durationText',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('summary-part-${part.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                _Swatch(color: part.color, dashed: part.dashed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    part.label,
                    style: const TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 14,
                      color: HomePalette.ink,
                    ),
                  ),
                ),
                Text(
                  durationText,
                  style: const TextStyle(
                    fontFamily: homeSerifFamily,
                    fontSize: 14,
                    color: HomePalette.muted,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$percent%',
                    key: ValueKey('summary-part-percent-${part.id}'),
                    style: const TextStyle(
                      fontFamily: homeSerifFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HomePalette.accentDeep,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: dashed
        ? CustomPaint(painter: _DashedSwatch(color))
        : DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.parts,
    required this.total,
    required this.selected,
  });

  final List<DonutPart> parts;
  final int total;
  final String? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    var start = -math.pi / 2;
    for (final part in parts) {
      final sweep = total == 0
          ? 0.0
          : 2 * math.pi * part.duration.milliseconds / total;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected == part.id ? stroke + 4 : stroke
        ..color = part.color;
      if (part.dashed) {
        _drawDashedArc(canvas, rect, start, sweep, paint);
      } else {
        canvas.drawArc(rect, start, sweep, false, paint);
      }
      start += sweep;
    }
  }

  void _drawDashedArc(
    Canvas canvas,
    Rect rect,
    double start,
    double sweep,
    Paint paint,
  ) {
    const step = 0.07;
    final end = start + sweep;
    var angle = start;
    while (angle < end) {
      final segment = math.min(step, end - angle);
      canvas.drawArc(rect, angle, segment * 0.55, false, paint);
      angle += segment;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}

class _DashedSwatch extends CustomPainter {
  const _DashedSwatch(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
          const Radius.circular(3),
        ),
      );
    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashes.addPath(metric.extractPath(distance, distance + 3), Offset.zero);
        distance += 5;
      }
    }
    canvas.drawPath(dashes, paint);
  }

  @override
  bool shouldRepaint(_DashedSwatch oldDelegate) => color != oldDelegate.color;
}
