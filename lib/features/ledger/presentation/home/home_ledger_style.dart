import 'package:flutter/material.dart';

/// Local home typography in logical sp; capture resolution is independent.
/// Spacing uses TimeLedgerSpacing. None of these values determine time height.
///
/// Family and color come from the active theme: [title] / [state] / [button]
/// inherit the default text color (onSurface), while [metadata] / [tick] call
/// sites copy with onSurfaceVariant where the weaker tone is required.
class HomeLedgerStyle {
  const HomeLedgerStyle._();

  static const dateSize = 28.0;
  static const compactDateSize = 18.0;
  static const metricSize = 18.0;
  static const compactMetricSize = 12.0;
  static const title = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static const state = TextStyle(
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
  static const metadata = TextStyle(fontSize: 10, height: 1.2);
  static const tick = TextStyle(fontSize: 10, height: 1);
  static const button = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
  static const iconSize = 16.0;
}
