import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/home_timeline_tab.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';

/// Routes existing flow assertions through UI-T04's actual root controls.
Future<bool> tapRootAction(WidgetTester tester, String text) async {
  final root = find.byKey(const ValueKey('home-record-activity'));
  if (root.evaluate().isEmpty) return false;
  Future<void> tap(Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  switch (text) {
    case '打开日账本':
    case '查看记录':
      await tap(find.byKey(const ValueKey('home-tab-timeline')));
      return true;
    case '打开此日复盘':
    case '打开按日复盘':
      await tap(find.byKey(const ValueKey('home-tab-review')));
      return true;
    case '打开基础摘要':
      await tap(find.byKey(const ValueKey('home-tab-summary')));
      return true;
    case '打开目标':
      await tap(find.byKey(const ValueKey('home-menu')));
      await tap(find.text('目标管理'));
      return true;
    case '记录活动':
      await tap(root);
      return true;
    case '记录睡眠':
      await tap(find.byKey(const ValueKey('home-record-sleep')));
      return true;
    default:
      return false;
  }
}

Future<void> backFromPage(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
}

/// Matches a coverage metric by its label key, so "0 分钟" for 已交代 never
/// collides with the identical value shown for 尚未记录.
Finder ledgerDuration(String label, String value) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.key == ValueKey('coverage-$label') &&
      widget.data == value,
);

int ledgerFactCount(WidgetTester tester, String type) {
  final view = tester
      .widget<HomeTimelineTab>(
        find.byType(HomeTimelineTab, skipOffstage: false),
      )
      .view!;
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
