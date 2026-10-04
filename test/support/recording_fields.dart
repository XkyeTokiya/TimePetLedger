import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

/// 通过实际展开动作定位活动字段，不改变表单输入或 controller。
Future<void> revealRecordingField(WidgetTester tester, String field) async {
  if (find.byType(RecordingForm).evaluate().isEmpty) return;
  if (['continuation-hint', 'stuck-reason-text'].contains(field) &&
      find.byKey(const ValueKey('recording-hint-toggle')).evaluate().isEmpty) {
    final parent = find.byKey(const ValueKey('recording-rhythm-toggle'));
    await tester.ensureVisible(parent);
    await tester.pumpAndSettle();
    await tester.tap(parent);
    await tester.pumpAndSettle();
  }
  final toggle = switch (field) {
    'note' => 'recording-note-toggle',
    'continuation-hint' => 'recording-hint-toggle',
    'stuck-reason-text' => 'recording-stuck-toggle',
    '开始时间' || '结束时间' => 'edit-recording-time',
    _ => null,
  };
  if (toggle == null) return;
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  final target = field == '开始时间' || field == '结束时间'
      ? find.text(field)
      : find.byKey(ValueKey(field));
  if (target.evaluate().isNotEmpty) return;
  final action = find.byKey(ValueKey(toggle));
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Finder recordingTimeSummaryContaining(String value) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data == value ||
          (widget.key == const ValueKey('recording-time-summary') &&
              (widget.data?.contains(value) ?? false))),
);
