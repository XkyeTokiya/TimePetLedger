import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../domain/projection/day_ledger_view.dart';
import '../summary_formatting.dart';

/// Coverage line for the rebuilt home.
///
/// Reads the committed [DayLedgerView] directly; it does not reuse the old
/// overview widget or its horizontal time bar.
class HomeCoverageLine extends StatelessWidget {
  const HomeCoverageLine({super.key, required this.view});

  final DayLedgerView view;

  @override
  Widget build(BuildContext context) {
    final accounted = formatDerivedDuration(view.accountedDuration);
    final unresolved = formatDerivedDuration(view.unresolvedDuration);
    final unknown = view.unknownDuration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          runSpacing: 2,
          children: [
            const Text('已交代', style: _label),
            Text(accounted, style: _value, key: const ValueKey('coverage-已交代')),
            const Text('/', style: _slash),
            const Text('尚未记录', style: _label),
            Text(
              unresolved,
              style: _value,
              key: const ValueKey('coverage-尚未记录'),
            ),
          ],
        ),
        if (unknown.milliseconds > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '其中想不起来 ${formatDerivedDuration(unknown)}（已包含在已交代时间中）',
              style: const TextStyle(
                fontFamily: homeSerifFamily,
                fontSize: 13,
                height: 1.5,
                color: HomePalette.muted,
              ),
            ),
          ),
      ],
    );
  }
}

const _label = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 20,
  color: HomePalette.ink,
);
const _value = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 24,
  fontWeight: FontWeight.w600,
  color: HomePalette.accent,
);
const _slash = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 20,
  color: HomePalette.muted,
);
