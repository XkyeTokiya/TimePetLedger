import 'package:flutter_test/flutter_test.dart';

import 'root_navigation.dart';

/// Let real NativeDatabase continuations run between fake-async frames.
Future<void> settleNative(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await t.pumpAndSettle();
}

/// Tap a visible text, or route the label through the root navigation actions.
Future<void> tapText(WidgetTester t, String text) async {
  if (await tapRootAction(t, text)) {
    await settleNative(t);
    return;
  }
  final finder = find.text(text).last;
  await t.ensureVisible(finder);
  await t.tap(finder);
  await settleNative(t);
}
