import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/projection/day_ledger_view.dart';
import '../summary_formatting.dart';
import 'home_ledger_style.dart';
import 'home_value_transition.dart';

/// Both states show the real durations from one committed projection. System
/// text is allowed to wrap; the coverage bar describes time, never a score.
class HomeCoverageLine extends StatefulWidget {
  const HomeCoverageLine({
    super.key,
    required this.view,
    this.onTap,
    this.progress = 0,
  });
  final DayLedgerView view;
  final VoidCallback? onTap;
  final double progress;
  @override
  State<HomeCoverageLine> createState() => _HomeCoverageLineState();
}

class _HomeCoverageLineState extends State<HomeCoverageLine> {
  DayLedgerView? _measuredView;
  String? _accountedText;
  String? _unresolvedText;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final onTap = widget.onTap;
    final progress = widget.progress;
    if (!identical(_measuredView, view)) {
      _measuredView = view;
      _accountedText = formatDerivedDuration(view.accountedDuration);
      _unresolvedText = formatDerivedDuration(view.unresolvedDuration);
    }
    final window = view.window.endedAt - view.window.startedAt;
    final fraction = window == 0
        ? 0.0
        : view.accountedDuration.milliseconds / window;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        key: const ValueKey('home-coverage'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(
                alpha: lerpDouble(.5, .2, progress)!,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: lerpDouble(12, 8, progress)!,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CoverageMetric(
                          label: '已交代',
                          text: _accountedText!,
                          valueKey: const ValueKey('coverage-已交代'),
                          progress: progress,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CoverageMetric(
                          label: '尚未记录',
                          text: _unresolvedText!,
                          valueKey: const ValueKey('coverage-尚未记录'),
                          progress: progress,
                        ),
                      ),
                    ],
                  ),
                  if (progress < 1)
                    ClipRect(
                      child: Align(
                        heightFactor: 1 - progress,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ExcludeSemantics(
                            child: LinearProgressIndicator(
                              key: const ValueKey('home-coverage-ratio'),
                              value: fraction,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(8),
                              color: colors.primary,
                              backgroundColor: colors.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageMetric extends StatelessWidget {
  const _CoverageMetric({
    required this.label,
    required this.text,
    required this.valueKey,
    required this.progress,
  });
  final String label;
  final String text;
  final Key valueKey;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final numberStyle = TextStyle(
      fontSize: lerpDouble(
        HomeLedgerStyle.metricSize,
        HomeLedgerStyle.compactMetricSize,
        progress,
      ),
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: colors.primary,
    );
    final unitStyle = TextStyle(
      fontSize: 11,
      height: 1.2,
      color: colors.primary,
    );
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in RegExp(r'\d+').allMatches(text)) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: text.substring(index, match.start), style: unitStyle),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: numberStyle));
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: unitStyle));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        HomeValueTransition(
          value: text,
          child: Text.rich(
            TextSpan(children: spans),
            key: valueKey,
            style: numberStyle,
          ),
        ),
      ],
    );
  }
}
