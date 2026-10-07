import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openManualLedgerDate(WidgetTester tester) async {
  for (final key in ['review-context-date', 'summary-date']) {
    final field = find.byKey(ValueKey(key));
    if (field.evaluate().isNotEmpty) {
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      break;
    }
  }
  final button = find.text('手动输入日期');
  if (button.evaluate().isEmpty) {
    final datePicker = find.byKey(const ValueKey('ledger-date-picker')).first;
    // The date header is eagerly built even while scrolled offscreen.
    await tester.ensureVisible(datePicker);
    await tester.pump();
    await tester.tap(datePicker);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (find.widgetWithText(TextField, '账本日期').evaluate().isNotEmpty) return;
  }
  // 日历弹窗内容可滚动，“手动输入日期”可能贴在下缘；先滚到可见再点击，
  // 否则点击会落在遮罩上关闭弹窗。
  await tester.ensureVisible(button);
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
