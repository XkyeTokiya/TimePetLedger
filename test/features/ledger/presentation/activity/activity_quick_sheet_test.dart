import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/activity_understanding.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_editor.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_quick_sheet.dart';

import '../../../../app/review_form_entry_test.dart' show settleNative;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final date = CivilDate(year: 2026, month: 10, day: 1);
final start = DateTime(2026, 10, 1, 10).millisecondsSinceEpoch;
final end = DateTime(2026, 10, 1, 11).millisecondsSinceEpoch;
final newContext = RecordingDraftContext.newEntry(date: date);
final editContext = RecordingDraftContext.edit(date: date, timeBlockId: id(8));

class Fixture {
  Fixture(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  late final repo = DriftLedgerRepository(db);
  late final goals = DriftGoalRepository(db);
  late final loader = RecordingLedgerLoader(
    repository: repo,
    resolveDate: resolveDeviceRecordingDate,
  );
  int ids = 100;
  late final saver = RecordingEntrySaver(
    repository: repo,
    drafts: drafts,
    refresh: ({required date, required now}) =>
        loader.load(date: date, now: now),
    newId: () => id(ids++),
    now: () => end + 1,
  );
  late final editor = RecordingEntryEditor(
    repository: repo,
    drafts: drafts,
    saver: saver,
  );
  late final understanding = ActivityUnderstandingService(
    repository: repo,
    now: () => end + 1,
    newId: () => id(ids++),
  );

  Future<Goal> goal() => goals.create(id: id(1), name: '毕业设计', now: 1);

  static Future<Fixture> open() async => Fixture(
    await AppDatabase.open(NativeDatabase.memory()),
    await DriftRecordingDraftStore.open(NativeDatabase.memory()),
  );

  Future<void> close() async {
    await drafts.close();
    await db.close();
  }

  Future<void> source() => repo.createTimeBlock(
    id: id(8),
    startedAt: start,
    endedAt: end,
    startPrecision: TimePrecision.approximate,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '原活动',
    now: 1,
    annotation: AddAnnotation(
      id: id(7),
      state: RhythmState.stuck,
      continuationHint: '原接续点',
      stuckReasonCode: StuckReasonCode.unclearNextStep,
    ),
  );

  /// 记录面板宿主；打开后把提交结果写入 [closedResult]。
  Widget app(
    RecordingDraftContext context, {
    required void Function(ActivityQuickSheetResult?) closedResult,
    RecordingTimeInput? suggestedTime,
    ActivityUnderstandingService? understanding,
    Future<List<Goal>> Function()? loadGoals,
  }) => MaterialApp(
    theme: homeTheme,
    home: Builder(
      builder: (outer) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () async {
            final result = await showActivityQuickSheet(
              outer,
              entryContext: context,
              store: drafts,
              entrySaver: saver,
              entryEditor: editor,
              understanding: understanding,
              loadGoals: loadGoals,
              loadSuggestion: () async => DirectTimeSuggestion(
                suggestedTime ??
                    RecordingTimeInput(startedAt: start, endedAt: end),
              ),
            );
            closedResult(result);
          },
          child: const Text('打开'),
        ),
      ),
    ),
  );
}

Future<Fixture> open(WidgetTester t) async {
  final fixture = (await t.runAsync(Fixture.open))!;
  addTearDown(fixture.close);
  return fixture;
}

Finder key(String value) => find.byKey(ValueKey(value));

Future<void> tapKey(WidgetTester t, String value) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await settleNative(t);
  final target = key(value);
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await t.scrollUntilVisible(target, 160, scrollable: scrollable.last);
    }
  }
  if (target.evaluate().isEmpty) fail('key "$value" not found');
  await t.ensureVisible(target.first);
  await settleNative(t);
  await t.tap(target.first);
  await settleNative(t);
}

Future<void> tapText(WidgetTester t, String text) async {
  final target = find.text(text);
  await t.ensureVisible(target.first);
  await settleNative(t);
  await t.tap(target.first);
  await settleNative(t);
}

void main() {
  testWidgets(
    'sheet shows the suggested time, saves the fact first and returns the block',
    (t) async {
      final f = await open(t);
      ActivityQuickSheetResult? result;
      await t.pumpWidget(f.app(newContext, closedResult: (r) => result = r));
      await settleNative(t);
      await tapKey(t, 'open');
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('开始和结束可以按大概填写'), findsNothing);
      await t.enterText(key('activity'), '  写作 🐾  ');
      await tapKey(t, 'activity-primary');
      expect(key('activity-primary').evaluate(), isEmpty);
      expect(result, isNotNull);
      expect(result!.isEdit, isFalse);
      expect(result!.timeBlock.knowledgeState, BlockKnowledgeState.known);
      expect(result!.timeBlock.title, '写作 🐾');
      final stored = (await t.runAsync(
        () => f.repo.readTimeBlock(result!.timeBlock.id),
      ))!;
      expect(stored.timeBlock.title, '写作 🐾');
      expect(stored.annotation, isNull);
      expect(await t.runAsync(() => f.drafts.read(newContext)), isNull);
    },
  );

  testWidgets('duration quick-select works when only the start is filled', (
    t,
  ) async {
    final f = await open(t);
    ActivityQuickSheetResult? result;
    await t.pumpWidget(
      f.app(
        newContext,
        closedResult: (r) => result = r,
        suggestedTime: RecordingTimeInput(startedAt: start),
      ),
    );
    await settleNative(t);
    await tapKey(t, 'open');
    // 只填了开始：给出补齐入口，不再要求两端齐全。
    expect(find.text('用时长补上结束'), findsOneWidget);
    await tapKey(t, 'activity-duration');
    expect(find.text('选择时长'), findsOneWidget);
    final wheels = t
        .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
        .toList();
    (wheels[0].controller! as FixedExtentScrollController).jumpToItem(2);
    (wheels[1].controller! as FixedExtentScrollController).jumpToItem(0);
    await settleNative(t);
    await t.tap(find.byKey(const ValueKey('duration-picker-confirm')));
    await settleNative(t);
    // 结束被补齐为开始 + 2 小时，并可直接保存。
    expect(find.text('2 小时'), findsOneWidget);
    await t.enterText(key('activity'), '写作');
    await tapKey(t, 'activity-primary');
    expect(result, isNotNull);
    expect(result!.timeBlock.startedAt, start);
    expect(
      result!.timeBlock.endedAt,
      start + const Duration(hours: 2).inMilliseconds,
    );
  });

  testWidgets('duration quick-select works when only the end is filled', (
    t,
  ) async {
    final f = await open(t);
    ActivityQuickSheetResult? result;
    await t.pumpWidget(
      f.app(
        newContext,
        closedResult: (r) => result = r,
        suggestedTime: RecordingTimeInput(endedAt: end),
      ),
    );
    await settleNative(t);
    await tapKey(t, 'open');
    expect(find.text('用时长补上开始'), findsOneWidget);
    await tapKey(t, 'activity-duration');
    // 方向自动从结束算，默认 30 分钟：开始 = 结束 − 30 分钟。
    await t.tap(find.byKey(const ValueKey('duration-picker-confirm')));
    await settleNative(t);
    expect(find.text('30 分钟'), findsOneWidget);
    await t.enterText(key('activity'), '写作');
    await tapKey(t, 'activity-primary');
    expect(result, isNotNull);
    expect(
      result!.timeBlock.startedAt,
      end - const Duration(minutes: 30).inMilliseconds,
    );
    expect(result!.timeBlock.endedAt, end);
  });

  testWidgets(
    'unknown exits the input focus, blurs the question area and saves without a title',
    (t) async {
      final f = await open(t);
      ActivityQuickSheetResult? result;
      await t.pumpWidget(f.app(newContext, closedResult: (r) => result = r));
      await settleNative(t);
      await tapKey(t, 'open');
      final panelHeight = t.getSize(key('sheet-stage-form')).height;
      // 先进入输入状态。
      await t.tap(key('activity'));
      await settleNative(t);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(t.testTextInput.isVisible, isTrue);
      expect(key('activity-unknown-mask'), findsNothing);
      final questionTop = t.getRect(find.text('这段时间大概在做什么？')).top;
      final fieldRect = t.getRect(key('activity'));
      await tapText(t, '想不起来');
      // 退出输入焦点并盖上磨砂层：问题与输入框原地保留，只是被模糊遮住；
      // 元素之间的相对位置与面板高度都不变化。
      expect(t.testTextInput.isVisible, isFalse);
      expect(key('activity-unknown-mask'), findsOneWidget);
      expect(key('activity'), findsOneWidget);
      expect(
        t.getRect(key('activity')).top -
            t.getRect(find.text('这段时间大概在做什么？')).top,
        fieldRect.top - questionTop,
      );
      expect(t.getRect(key('activity')).height, fieldRect.height);
      expect(t.getSize(key('sheet-stage-form')).height, panelHeight);
      // 切回“记得”恢复输入区。
      await tapText(t, '记得');
      expect(key('activity-unknown-mask'), findsNothing);
      expect(
        t.getRect(key('activity')).top -
            t.getRect(find.text('这段时间大概在做什么？')).top,
        fieldRect.top - questionTop,
      );
      expect(t.getSize(key('sheet-stage-form')).height, panelHeight);
      await tapText(t, '想不起来');
      await tapKey(t, 'activity-primary');
      expect(result, isNotNull);
      expect(result!.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
      expect(result!.timeBlock.title, isNull);
    },
  );

  testWidgets('edit prefills the title and preserves the annotation', (
    t,
  ) async {
    final f = await open(t);
    await t.runAsync(f.source);
    ActivityQuickSheetResult? result;
    await t.pumpWidget(f.app(editContext, closedResult: (r) => result = r));
    await settleNative(t);
    await tapKey(t, 'open');
    expect(find.text('更正记录'), findsOneWidget);
    expect(t.widget<TextField>(key('activity')).controller!.text, '原活动');
    await t.enterText(key('activity'), '更正后的活动');
    await tapKey(t, 'activity-primary');
    expect(result, isNotNull);
    expect(result!.isEdit, isTrue);
    final stored = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(stored.timeBlock.title, '更正后的活动');
    expect(stored.annotation!.id, id(7));
    expect(stored.annotation!.state, RhythmState.stuck);
    expect(stored.annotation!.continuationHint, '原接续点');
  });

  testWidgets(
    'header reset icon appears after input and clears it on confirm',
    (t) async {
      final f = await open(t);
      ActivityQuickSheetResult? result;
      await t.pumpWidget(f.app(newContext, closedResult: (r) => result = r));
      await settleNative(t);
      await tapKey(t, 'open');
      expect(key('activity-reset'), findsNothing);
      await t.enterText(key('activity'), '临时内容');
      await settleNative(t);
      expect(key('activity-reset'), findsOneWidget);
      await tapKey(t, 'activity-reset');
      expect(find.text('重新填写？'), findsOneWidget);
      await t.tap(find.text('重新填写'));
      await settleNative(t);
      expect(t.widget<TextField>(key('activity')).controller!.text, '');
      expect(key('activity-reset'), findsNothing);
      await tapKey(t, 'activity-close');
      expect(result, isNull);
    },
  );

  testWidgets('after save the same sheet switches to the understanding stage', (
    t,
  ) async {
    final f = await open(t);
    final goal = (await t.runAsync(f.goal))!;
    ActivityQuickSheetResult? result;
    await t.pumpWidget(
      f.app(
        newContext,
        closedResult: (r) => result = r,
        understanding: f.understanding,
        loadGoals: () async => [goal],
      ),
    );
    await settleNative(t);
    await tapKey(t, 'open');
    final panelHeight = t.getSize(key('sheet-stage-form')).height;
    await t.enterText(key('activity'), '写作');
    await tapKey(t, 'activity-primary');
    // 表单 → 目标：理解层沿用记录面板高度，窗口不跳动。
    expect(t.getSize(key('activity-sheet-frame')).height, panelHeight);
    expect(key('activity-primary'), findsNothing);
    expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
    // 摘要卡显示刚保存的事实（时间范围 + 标题）。
    expect(find.text('10:00 → 11:00'), findsOneWidget);
    await tapKey(t, 'understanding-goal-${goal.id}');
    expect(t.getSize(key('activity-sheet-frame')).height, panelHeight);
    expect(find.text('回头看，这段时间整体是什么状态？'), findsOneWidget);
    // 系统返回 / 鼠标后退：状态 → 目标。
    await t.binding.handlePopRoute();
    await settleNative(t);
    expect(find.text('这段时间和某个目标有关吗？'), findsOneWidget);
    expect(find.text('回头看，这段时间整体是什么状态？'), findsNothing);
    await tapKey(t, 'understanding-goal-${goal.id}');
    await tapKey(t, 'understanding-state-progress');
    expect(find.textContaining('已选：推进'), findsOneWidget);
    // 状态 → 补充：同样不改变窗口高度。
    expect(t.getSize(key('activity-sheet-frame')).height, panelHeight);
    // 补充 → 状态。
    await t.binding.handlePopRoute();
    await settleNative(t);
    expect(find.text('回头看，这段时间整体是什么状态？'), findsOneWidget);
    await tapKey(t, 'understanding-state-progress');
    await tapKey(t, 'understanding-finish');
    expect(key('activity-understanding'), findsNothing);
    expect(result, isNotNull);
    final stored = (await t.runAsync(
      () => f.repo.readTimeBlock(result!.timeBlock.id),
    ))!;
    expect(stored.timeBlock.goalId, goal.id);
    expect(stored.annotation!.state, RhythmState.progress);
  });

  testWidgets('reopening with a saved draft asks to continue or refill', (
    t,
  ) async {
    final f = await open(t);
    await t.runAsync(
      () => f.drafts.save(
        RecordingDraft(
          context: newContext,
          title: '未完成的草稿',
          note: null,
          noteProvided: false,
          goalId: null,
          goalProvided: false,
          annotationIntent: RecordingAnnotationIntent.keep,
          annotationId: null,
          rhythmState: null,
          continuationHint: '',
          hintProvided: false,
          stuckReasonCode: null,
          stuckReasonCodeProvided: false,
          stuckReasonText: '',
          stuckReasonTextProvided: false,
          recoveryMethod: null,
          recoveryMethodProvided: false,
          recoveryQuality: null,
          recoveryQualityProvided: false,
          startedAt: start,
          endedAt: end,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.known,
          presentationStep: 0,
        ),
      ),
    );
    ActivityQuickSheetResult? result;
    await t.pumpWidget(f.app(newContext, closedResult: (r) => result = r));
    await settleNative(t);
    await tapKey(t, 'open');
    expect(find.text('继续上次填写？'), findsOneWidget);
    await t.tap(find.text('继续填写'));
    await settleNative(t);
    expect(t.widget<TextField>(key('activity')).controller!.text, '未完成的草稿');
    await tapKey(t, 'activity-close');
    expect(result, isNull);
  });
}
