import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';

/// Local home typography in logical sp; capture resolution is independent.
/// Spacing uses TimeLedgerSpacing. None of these values determine time height.
class HomeLedgerStyle {
  const HomeLedgerStyle._();

  static const dateSize = 28.0;
  static const compactDateSize = 18.0;
  static const metricSize = 18.0;
  static const compactMetricSize = 12.0;
  static const title = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: HomePalette.ink,
  );
  static const state = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: HomePalette.ink,
  );
  static const metadata = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 10,
    height: 1.2,
    color: HomePalette.muted,
  );
  static const tick = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 10,
    height: 1,
    color: HomePalette.muted,
  );
  static const button = TextStyle(
    fontFamily: homeSerifFamily,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
  static const iconSize = 16.0;
}
