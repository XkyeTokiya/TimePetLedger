import 'package:flutter/material.dart';

import 'dev/activity_preview.dart';
import 'app/theme/time_ledger_theme.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '记录活动',
      theme: timeLedgerTheme,
      home: const ActivityPreview(),
    ),
  );
}
