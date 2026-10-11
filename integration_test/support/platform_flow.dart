import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 平台测试共用的真实 UI 等待与定位助手（从旧 goal_rhythm_platform_test 迁出）。

// pumpAndSettle waits for frames, not outstanding platform SQL. Observe busy
// UI before sending the next action; do not race input against async clear.
Future<void> waitForUI(WidgetTester t) async {
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 100));
    final busy =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
        find
            .byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing)
            .evaluate()
            .isNotEmpty;
    if (!busy) {
      await t.pumpAndSettle();
      return;
    }
  }
  fail('Platform UI did not finish its operation');
}

Future<void> visible(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> tapFinder(WidgetTester t, Finder target) async {
  await visible(t, target);
  await t.tap(target.first);
  await waitForUI(t);
}

Future<void> enter(WidgetTester t, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  await visible(t, target);
  // Re-entering the same field must refocus its real IME connection.
  await t.tap(target);
  await t.pumpAndSettle();
  await t.enterText(target, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

Future<String> input(WidgetTester t, String key) async {
  final target = find.byKey(ValueKey(key));
  await visible(t, target);
  return t.widget<TextField>(target).controller!.text;
}
