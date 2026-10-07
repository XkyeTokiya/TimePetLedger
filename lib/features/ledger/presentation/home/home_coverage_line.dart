import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../summary_formatting.dart';
import 'home_value_transition.dart';

/// 首页覆盖概览：已交代 / 尚未记录双列小标签与时长。
///
/// 只统计当前浏览日的同一次投影；数字与单位分层显示，长时长在窄屏或
/// 大字下整体缩放而不是挤成不稳定的两行。整块可进入当日摘要。
class HomeCoverageLine extends StatelessWidget {
  const HomeCoverageLine({super.key, required this.view, this.onTap});

  final DayLedgerView view;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('home-coverage'),
    onTap: onTap,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: HomePalette.hairline),
          bottom: BorderSide(color: HomePalette.hairline),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _CoverageMetric(
                label: '已交代',
                text: formatDerivedDuration(view.accountedDuration),
                valueKey: const ValueKey('coverage-已交代'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _CoverageMetric(
                label: '尚未记录',
                text: formatDerivedDuration(view.unresolvedDuration),
                valueKey: const ValueKey('coverage-尚未记录'),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_outward,
                size: 18,
                color: HomePalette.muted,
              ),
          ],
        ),
      ),
    ),
  );
}

class _CoverageMetric extends StatelessWidget {
  const _CoverageMetric({
    required this.label,
    required this.text,
    required this.valueKey,
  });

  final String label;
  final String text;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 2),
      HomeValueTransition(
        value: text,
        height: MediaQuery.textScalerOf(context).scale(25) * 1.25,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: _spans(text)),
            key: valueKey,
            maxLines: 1,
            softWrap: false,
            // 合并样式与数字同色：整段是一块强调色文字，而不是默认墨色。
            style: _numberStyle,
          ),
        ),
      ),
    ],
  );

  /// 数字用大号衬线，单位保持小号，长时长时整体缩放。
  List<InlineSpan> _spans(String value) {
    final spans = <InlineSpan>[];
    var index = 0;
    for (final match in RegExp(r'\d+').allMatches(value)) {
      if (match.start > index) {
        spans.add(
          TextSpan(
            text: value.substring(index, match.start),
            style: _unitStyle,
          ),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: _numberStyle));
      index = match.end;
    }
    if (index < value.length) {
      spans.add(TextSpan(text: value.substring(index), style: _unitStyle));
    }
    return spans;
  }
}

const _labelStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 12,
  height: 1.4,
  color: HomePalette.muted,
);

const _numberStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 25,
  height: 1.25,
  fontWeight: FontWeight.w600,
  color: HomePalette.accentDeep,
);

const _unitStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  height: 1.25,
  fontWeight: FontWeight.w600,
  color: HomePalette.accentDeep,
);
