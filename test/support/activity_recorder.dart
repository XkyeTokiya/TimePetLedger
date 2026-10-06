import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';

/// Navigation helpers for the rebuilt stepped activity recorder
/// (节奏 → 适用子选项 → 事项 → 时间). Presentation only: they never touch the
/// controller or the draft store, so the tests still assert the real contract.
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
  await t.ensureVisible(target.first);
  await t.pumpAndSettle();
  await t.tap(target.first);
  await t.pumpAndSettle();
}

/// 继续 / 保存 / 重试收尾 — the single primary action.
Future<void> recorderAdvance(WidgetTester t) => recorderTap(t, 'activity-primary');

/// Advances until the 时间 step, where the primary action saves.
Future<void> recorderToTime(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    if (recorderKey('activity-time-summary').evaluate().isNotEmpty) return;
    await recorderAdvance(t);
  }
  fail('did not reach the time step');
}

/// Fills the title if the recorder is on the 事项 step, then advances to 时间.
Future<void> recorderAdvanceTimed(WidgetTester t) => recorderToTime(t);

/// Selects a rhythm; selecting advances to the next step automatically.
/// Already-selected values are left alone so callers stay in control.
Future<void> recorderRhythm(WidgetTester t, RhythmState? state) async {
  if (state != null) {
    if (_rhythmSelected(t, state)) return;
    await recorderTap(t, 'activity-rhythm-${state.name}');
    return;
  }
  // Deselect whatever is currently selected (stays on this step).
  for (final value in RhythmState.values) {
    if (_rhythmSelected(t, value)) {
      await recorderTap(t, 'activity-rhythm-${value.name}');
      return;
    }
  }
}

bool _rhythmSelected(WidgetTester t, RhythmState state) => find
    .descendant(
      of: recorderKey('activity-rhythm-${state.name}'),
      matching: find.byIcon(Icons.check),
    )
    .evaluate()
    .isNotEmpty;

/// Enters the activity title (step 事项).
Future<void> recorderTitle(WidgetTester t, String value) async {
  await recorderTap(t, 'activity');
  await t.enterText(recorderKey('activity'), value);
  await t.pumpAndSettle();
}

/// Hint / note live in the optional-details sheet.
Future<void> recorderDetail(WidgetTester t, String key, String value) async {
  await recorderOpenDetails(t);
  await recorderTap(t, key);
  await t.enterText(recorderKey(key), value);
  await t.pumpAndSettle();
  await recorderTap(t, 'activity-details-apply');
}

Future<void> recorderOpenDetails(WidgetTester t) async {
  if (recorderKey('activity-note').evaluate().isEmpty) {
    await recorderTap(t, 'activity-details');
  }
}

/// Picks one endpoint through the time sheet's direct-input path.
Future<void> recorderTime(WidgetTester t, String label, String value) async {
  final key = label == '开始时间' ? 'activity-start' : 'activity-end';
  await recorderTap(t, '$key-row');
  if (recorderKey('$key-manual').evaluate().isEmpty) {
    await recorderTap(t, 'activity-time-manual');
  }
  await t.enterText(recorderKey('$key-manual'), value);
  await t.pumpAndSettle();
  await recorderTap(t, 'activity-time-apply');
}

Future<void> recorderChooseGoal(WidgetTester t, String id) async {
  await recorderTap(t, 'activity-goal');
  await recorderTap(t, 'activity-goal-$id');
}

/// Keeps the draft and returns (leading back button or the more menu).
Future<void> recorderKeep(WidgetTester t) async {
  final exit = find.byKey(const ValueKey('activity-exit'));
  if (exit.evaluate().isNotEmpty) {
    await t.tap(exit.first);
    await t.pumpAndSettle();
    return;
  }
  if (find.byType(BackButton).evaluate().isNotEmpty) {
    await t.tap(find.byType(BackButton).first);
    await t.pumpAndSettle();
    return;
  }
  await recorderTap(t, 'activity-more');
  await recorderTap(t, 'activity-more-keep');
}
