import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form.dart';
import 'package:time_pet_ledger/features/review/presentation/review_form_controller.dart';

String reviewDateInput(WidgetTester tester) =>
    tester.widget<ReviewForm>(find.byType(ReviewForm)).controller.dateInput;

Future<void> changeReviewDate(WidgetTester tester, String value) async {
  final date = parseReviewDate(value);
  if (date == null) {
    // 模拟旧草稿的未完成文本，日历本身不会产生无效日期。
    tester
        .widget<ReviewForm>(find.byType(ReviewForm))
        .controller
        .setDateInput(value);
    await tester.pump();
    return;
  }
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  final field = find.byKey(const ValueKey('review-date'));
  await Scrollable.ensureVisible(tester.element(field), alignment: .5);
  await tester.pump();
  await tester.tap(field);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.widgetWithText(TextField, '复盘日期 YYYY-MM-DD'), findsNothing);
  final heading = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((t) => RegExp(r'^\d+年\d+月$').hasMatch(t));
  final parts = RegExp(r'^(\d+)年(\d+)月$').firstMatch(heading)!;
  final delta =
      (date.year - int.parse(parts[1]!)) * 12 +
      date.month -
      int.parse(parts[2]!);
  for (var n = 0; n < delta.abs(); n++) {
    await tester.tap(find.byTooltip(delta > 0 ? '下个月' : '上个月'));
    await tester.pump();
  }
  await tester.tap(find.text('${date.day}').last);
  await tester.pump();
  await tester.tap(find.text('确认日期'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(AlertDialog), findsNothing);
}
