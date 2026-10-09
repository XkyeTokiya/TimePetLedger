import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/theme_text.dart';
import '../../domain/projection/derived_duration.dart';
import '../summary_formatting.dart';

/// 实际时长与展示颜色；[dashed] 仅用于派生缺口。
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

/// fl_chart圆环与Material 3图例，共用调用方给定的事实投影。
///
/// 分母是各部分实际毫秒之和，百分比最终展示才取整（Q-017）。
/// 中心仍显示调用方给定的汇总，不查询、不修改或重新解释时间事实。
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
  void didUpdateWidget(HomeDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.parts.any((part) => part.id == _selected)) _selected = null;
  }

  void _select(String id) =>
      setState(() => _selected = _selected == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final total = widget.parts.fold<int>(
      0,
      (sum, part) => sum + part.duration.milliseconds,
    );
    if (total <= 0) {
      return Text(
        '当前窗口暂无可显示的时间构成。',
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final diameter = math.min(
          constraints.maxWidth,
          224 * textScale.clamp(1.0, 1.35),
        );
        final ring = _Ring(
          parts: widget.parts,
          total: total,
          selected: _selected,
          diameter: diameter,
          centerLabel: widget.centerLabel,
          centerValue: widget.centerValue,
          semanticsLabel: widget.semanticsLabel,
          onSelect: _select,
        );
        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final part in widget.parts)
              _LegendRow(
                part: part,
                total: total,
                selected: _selected == part.id,
                onTap: () => _select(part.id),
              ),
          ],
        );
        // 图例至少保有约300宽；大字模式直接纵向排列。
        if (constraints.maxWidth < 560 || textScale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(width: 24),
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
    required this.diameter,
    required this.centerLabel,
    required this.centerValue,
    required this.semanticsLabel,
    required this.onSelect,
  });

  final List<DonutPart> parts;
  final int total;
  final String? selected;
  final double diameter;
  final String centerLabel;
  final String centerValue;
  final String semanticsLabel;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thickness = diameter * 0.105;
    final centerRadius = diameter / 2 - thickness - 6;
    final valueStyle = withThemeFont(
      context,
      TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: colors.onSurface,
      ),
    );
    final valueMeasure = TextPainter(
      text: TextSpan(text: centerValue, style: valueStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final displayValue = valueMeasure.width > centerRadius * 1.7
        ? centerValue.replaceFirst('小时 ', '小时\n')
        : centerValue;
    valueMeasure.dispose();
    final slices = <({String id, PieChartSectionData section})>[];
    for (final part in parts) {
      if (part.duration.milliseconds <= 0) continue;
      final value = part.duration.milliseconds.toDouble();
      final radius = thickness + (selected == part.id ? 4 : 0);
      void add(double value, Color color) => slices.add((
        id: part.id,
        section: PieChartSectionData(
          value: value,
          color: color,
          radius: radius,
          showTitle: false,
        ),
      ));
      if (!part.dashed) {
        add(value, part.color);
        continue;
      }
      // fl_chart以实色/透明短段绘制Gap虚线，全部短段仍映射到同一类别。
      // 透明间隔也占原时长，不能删掉它们而放大其他类别的比例。
      final count = math.max(1, (value / total * 90).ceil());
      final dashValue = value / count;
      for (var dash = 0; dash < count; dash++) {
        add(dashValue * 0.55, part.color);
        add(dashValue * 0.45, Colors.transparent);
      }
    }
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: diameter,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [for (final slice in slices) slice.section],
                  centerSpaceRadius: centerRadius,
                  centerSpaceColor: Colors.transparent,
                  sectionsSpace: 0,
                  startDegreeOffset: 270,
                  borderData: FlBorderData(show: false),
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      if (index == null ||
                          index < 0 ||
                          index >= slices.length) {
                        return;
                      }
                      onSelect(slices[index].id);
                    },
                  ),
                ),
                // 刷新、切日和Gap短段数量变化立即反映实际占比。
                duration: Duration.zero,
              ),
              IgnorePointer(
                child: SizedBox(
                  width: centerRadius * 1.7,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        centerLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayValue,
                        textAlign: TextAlign.center,
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final colors = Theme.of(context).colorScheme;
    final durationText = formatDerivedDuration(part.duration);
    final percent = (part.duration.milliseconds * 100 / total).round();
    final duration = Text(
      durationText,
      style: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: colors.onSurfaceVariant,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final valuesBelow =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        return Semantics(
          button: true,
          selected: selected,
          label: selected
              ? '${part.label} $durationText，占 $percent%'
              : '${part.label} $durationText',
          onTap: onTap,
          child: ExcludeSemantics(
            child: ListTile(
              key: ValueKey('summary-part-${part.id}'),
              onTap: onTap,
              selected: selected,
              selectedTileColor: colors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              horizontalTitleGap: 12,
              minLeadingWidth: 20,
              leading: _Swatch(color: part.color, dashed: part.dashed),
              title: Text(
                part.label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colors.onSurface,
                ),
              ),
              trailing: valuesBelow ? null : duration,
              subtitle: valuesBelow || selected
                  ? Wrap(
                      spacing: 12,
                      children: [
                        if (valuesBelow) duration,
                        if (selected)
                          Text(
                            '$percent%',
                            key: ValueKey('summary-part-percent-${part.id}'),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 20,
    child: dashed
        ? Icon(Icons.more_horiz, color: color, size: 20)
        : Center(
            child: SizedBox.square(
              dimension: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
  );
}
