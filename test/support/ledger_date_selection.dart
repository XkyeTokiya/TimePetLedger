import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openManualLedgerDate(WidgetTester tester) async {
  final button = find.text('手动输入日期');
  if (button.evaluate().isEmpty) {
    final datePicker = find.byKey(const ValueKey('ledger-date-picker')).first;
    // The date header is eagerly built even while scrolled offscreen.
    await Scrollable.ensureVisible(tester.element(datePicker));
    await tester.pump();
    await tester.tap(datePicker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (find.widgetWithText(TextField, '账本日期').evaluate().isNotEmpty) return;
  }
  await Scrollable.ensureVisible(tester.element(button), alignment: .5);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> selectLedgerDate(WidgetTester tester, String date) async {
  final legacy = find.widgetWithText(TextField, '复盘日期 YYYY-MM-DD');
  if (legacy.evaluate().isNotEmpty) {
    await tester.enterText(legacy, date);
    await tester.pump();
    return;
  }
  if (find.widgetWithText(TextField, '账本日期').evaluate().isEmpty) {
    await openManualLedgerDate(tester);
  }
  await tester.enterText(find.widgetWithText(TextField, '账本日期'), date);
  await tester.tap(find.text('确认日期'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}
