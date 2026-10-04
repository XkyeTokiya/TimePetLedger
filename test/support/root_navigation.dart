import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_overview.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';

/// Routes existing flow assertions through UI-T04's actual root controls.
Future<bool> tapRootAction(WidgetTester tester, String text) async {
  final root = find.byKey(const ValueKey('root-create'));
  if (root.evaluate().isEmpty) return false;
  Future<void> tap(Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  switch (text) {
    case '打开日账本':
      await tap(find.byKey(const ValueKey('root-回看')));
      return true;
    case '打开此日复盘':
    case '打开按日复盘':
      await tap(find.byKey(const ValueKey('root-复盘')));
      return true;
    case '查看记录':
      await tap(find.byKey(const ValueKey('root-回看')));
      await tap(find.byTooltip('更多'));
      await tap(find.text('刷新账本'));
      return true;
    case '打开基础摘要':
    case '打开目标':
      await tap(find.byTooltip('更多'));
      await tap(find.text(text == '打开目标' ? '目标管理' : '当日摘要'));
      return true;
    case '记录活动':
    case '记录睡眠':
      await tap(root);
      await tap(find.text(text));
      return true;
    default:
      return false;
  }
}

Future<void> backFromPage(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

Finder ledgerDuration(String label, String value) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is Column &&
        widget.children.any((child) => child is Text && child.data == label),
  ),
  matching: find.text(value),
);

int ledgerFactCount(WidgetTester tester, String type) {
  final view = tester
      .widget<DayLedgerOverview>(find.byType(DayLedgerOverview))
      .view;
  return view.segments
      .where(
        (segment) => type == '睡眠'
            ? segment is SleepSessionSegment
            : segment is TimeBlockSegment,
      )
      .length;
}

Finder recordingFact(String id) =>
    find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id)));

Finder sleepFact(String id) {
  final complete = find.byKey(ValueKey('sleep-edit-$id'));
  return complete.evaluate().isNotEmpty
      ? complete
      : find.byKey(ValueKey((type: LedgerFactType.sleepSession, id: id)));
}
