import 'package:flutter/material.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'dev/seed_demo_data.dart';

void main() {
  // Development-only: seed demo data on first launch (no-op once data exists).
  runApp(const AppBootstrap(seed: seedDemoDataIfEmpty));
}
