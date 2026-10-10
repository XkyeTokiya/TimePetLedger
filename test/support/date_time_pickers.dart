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
  // 端点选择器可能按另一端限制首项（同一自然日）；拨轮索引不等于小时值，
  // 因此按“当前中央选中项 → 目标值”的相对距离跳转。
  Future<void> setWheel(String kind, int target) async {
    final wheel = find.byKey(ValueKey('time-picker-$kind'));
    final controller =
        tester.widget<ListWheelScrollView>(wheel).controller
            as FixedExtentScrollController;
    final selected = find.descendant(
      of: wheel,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.style?.fontWeight == FontWeight.w600 &&
            int.tryParse(widget.data ?? '') != null,
      ),
    );
    final current = int.parse(tester.widget<Text>(selected.first).data!);
    controller.jumpToItem(controller.selectedItem + (target - current));
    await tester.pumpAndSettle();
  }

  await setWheel('hour', value.hour);
  await setWheel('minute', value.minute);
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
