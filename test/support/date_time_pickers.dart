import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openEndpointField(WidgetTester tester, String field) async {
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  final target = find.byKey(ValueKey(field));
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> chooseEndpointDate(
  WidgetTester tester,
  String prefix,
  DateTime value,
) async {
  await openEndpointField(tester, '$prefix-date');
  expect(find.byType(ListWheelScrollView), findsNothing);
  final heading = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((t) => RegExp(r'^\d+年\d+月$').hasMatch(t));
  final parts = RegExp(r'^(\d+)年(\d+)月$').firstMatch(heading)!;
  final delta =
      (value.year - int.parse(parts[1]!)) * 12 +
      value.month -
      int.parse(parts[2]!);
  for (var n = 0; n < delta.abs(); n++) {
    await tester.tap(find.byTooltip(delta > 0 ? '下个月' : '上个月'));
    await tester.pump();
  }
  await tester.tap(find.text('${value.day}').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('date-picker-confirm')));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}

Future<void> chooseEndpointTime(
  WidgetTester tester,
  String prefix,
  DateTime value,
) async {
  await openEndpointField(tester, '$prefix-time');
  expect(find.byKey(const ValueKey('date-picker-confirm')), findsNothing);
  final wheels = tester
      .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
      .toList();
  (wheels[0].controller! as FixedExtentScrollController).jumpToItem(value.hour);
  (wheels[1].controller! as FixedExtentScrollController).jumpToItem(
    value.minute,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('time-picker-confirm')));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsNothing);
}

Future<void> chooseEndpoint(
  WidgetTester tester,
  String prefix,
  String value,
) async {
  final date = DateTime.parse(value);
  await chooseEndpointDate(tester, prefix, date);
  await chooseEndpointTime(tester, prefix, date);
}
