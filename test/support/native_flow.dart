import 'package:flutter/material.dart';
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

/// Scroll a target into view (building lazily as needed), then tap it.
Future<void> tapFinder(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await t.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    final position = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
      position.jumpTo(
        (position.pixels + 160).clamp(0, position.maxScrollExtent),
      );
      await t.pumpAndSettle();
    }
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .5);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await t.pumpAndSettle();
}
