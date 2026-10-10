import 'date_time_pickers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';

/// 记录面板（Q-047 底部面板）与保存后理解层的导航助手。
/// 只按可见控件操作，不直接改控制器或草稿。
Finder recorderKey(String value) => find.byKey(ValueKey(value));

Future<void> recorderTap(WidgetTester t, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await t.pumpAndSettle();
  final target = recorderKey(key);
  if (target.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await t.scrollUntilVisible(target, 160, scrollable: scrollables.last);
    }
  }
  if (target.evaluate().isEmpty) fail('key "$key" not found');
  await t.ensureVisible(target.first);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await t.pumpAndSettle();
}

/// 保存记录 / 保存修改 / 继续清理并刷新。
Future<void> recorderSave(WidgetTester t) => recorderTap(t, 'activity-primary');

/// 收起记录面板（草稿按会话保留）。
Future<void> recorderClose(WidgetTester t) => recorderTap(t, 'activity-close');

/// 输入活动标题。
Future<void> recorderTitle(WidgetTester t, String value) async {
  await recorderTap(t, 'activity');
  await t.enterText(recorderKey('activity'), value);
  await t.pumpAndSettle();
}

/// 选择“想不起来”。
Future<void> recorderUnknown(WidgetTester t) async {
  await t.tap(find.text('想不起来'));
  await t.pumpAndSettle();
}

/// 通过实际日期 / 时间选择器分别修改端点。
Future<void> recorderTime(WidgetTester t, String label, String value) =>
    chooseEndpoint(
      t,
      label == '开始时间' ? 'activity-start' : 'activity-end',
      value,
    );

// ----- 保存后理解层 -----

Future<void> understandingPickGoal(WidgetTester t, String id) =>
    recorderTap(t, 'understanding-goal-$id');

Future<void> understandingPickState(WidgetTester t, RhythmState state) =>
    recorderTap(t, 'understanding-state-${state.name}');

Future<void> understandingUnsure(WidgetTester t) =>
    recorderTap(t, 'understanding-state-unsure');

Future<void> understandingSkipGoal(WidgetTester t) =>
    recorderTap(t, 'understanding-skip-goal');

Future<void> understandingUnlink(WidgetTester t) =>
    recorderTap(t, 'understanding-unlink');

Future<void> understandingOpenReason(WidgetTester t) =>
    recorderTap(t, 'understanding-fold-reason');

Future<void> understandingOpenHint(WidgetTester t) =>
    recorderTap(t, 'understanding-fold-hint');

Future<void> understandingFinish(WidgetTester t) =>
    recorderTap(t, 'understanding-finish');

Future<void> understandingClose(WidgetTester t) =>
    recorderTap(t, 'understanding-close');
