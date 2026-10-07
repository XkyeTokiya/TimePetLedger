import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';

/// 顶部大日期当前展示的浏览日文本。
String homeDateTitle(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('home-date-title')).last)
    .data!;

/// 覆盖数值是数字 / 单位分层的富文本，按 key 读取纯文本。
String coverageText(WidgetTester tester, String label) => tester
    .widget<Text>(find.byKey(ValueKey('coverage-$label')).last)
    .textSpan!
    .toPlainText();

Finder dayDivider(CivilDate date) =>
    find.byKey(ValueKey('day-divider-${date.year}-${date.month}-${date.day}'));

/// 让真实 NativeDatabase 的异步续体在 fake-async 帧之间运行。
Future<void> settleNative(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
}

/// 在时间轴主体上做一次明确的横向滑动。
Future<void> swipeFeed(
  WidgetTester tester,
  double dx, {
  double startY = 300,
  double? startX,
}) async {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final from = Offset(startX ?? width / 2, startY);
  final gesture = await tester.startGesture(from);
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(Offset(dx / 6, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}
