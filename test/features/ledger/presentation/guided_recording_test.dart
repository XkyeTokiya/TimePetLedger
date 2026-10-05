import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/time_ledger_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/dev/guided_recording_sample.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/guided_recording_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

Future<void> tap(WidgetTester t, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await t.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).last;
    t.state<ScrollableState>(scrollable).position.jumpTo(0);
    await t.pumpAndSettle();
    if (finder.evaluate().isEmpty)
      await t.scrollUntilVisible(finder, 160, scrollable: scrollable);
  }
  await t.ensureVisible(finder.first);
  await t.pumpAndSettle();
  await t.tap(finder.first);
  await t.pumpAndSettle();
}

Finder key(String value) => find.byKey(ValueKey(value));
Future<void> mount(
  WidgetTester t,
  RecordingFormController model,
  GuidedRecordingNavigation flow, {
  VoidCallback? saved,
  VoidCallback? exit,
  RecordingInputMode mode = RecordingInputMode.guided,
  Future<Goal> Function(String)? createGoal,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: timeLedgerTheme,
      home: GuidedRecordingPage(
        key: ObjectKey(model),
        model: model,
        navigation: flow,
        mode: mode,
        createGoal: createGoal,
        onSaved: saved ?? () {},
        onExit: exit ?? () {},
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<GuidedSampleSession> session(GuidedSampleScenario scenario) async {
  final value = GuidedSampleSession(scenario);
  value.commonGoalId = guidedSampleId(10);
  await value.open();
  return value;
}

Future<void> toTime(WidgetTester t, {String? title}) async {
  await tap(t, key('guided-primary'));
  if (title != null) await t.enterText(key('guided-activity'), title);
  await tap(t, key('guided-primary'));
}

void main() {
  testWidgets(
    'goal creation failure is retryable and committed association survives metadata refresh failure',
    (t) async {
      for (final scenario in [
        GuidedSampleScenario.goalWriteFailure,
        GuidedSampleScenario.goalRefreshFailure,
      ]) {
        final s = await session(scenario);
        await mount(t, s.model!, s.navigation, createGoal: s.createGoal);
        await tap(t, find.text('更换'));
        await tap(t, find.text('创建长期目标'));
        await t.enterText(key('guided-goal-name'), '练习听力');
        await tap(t, find.text('创建并关联'));
        if (scenario == GuidedSampleScenario.goalWriteFailure) {
          expect(find.text('目标未创建成功，输入已保留，请重试。'), findsOneWidget);
          expect(
            t.widget<TextField>(key('guided-goal-name')).controller!.text,
            '练习听力',
          );
          await tap(t, find.text('创建并关联'));
        } else {
          expect(s.model!.goalsError, isNotNull);
        }
        await s.model!.flush();
        final created = s.goals.values.where((g) => g.name == '练习听力').single;
        expect(s.model!.goalId, created.id);
        expect(s.drafts.value!.goalId, created.id);
        expect(s.commonGoalId, guidedSampleId(10));
        if (s.model!.goalsError != null) await tap(t, find.text('重试读取目标'));
        expect(s.model!.selectedGoal!.name, '练习听力');
        await t.pumpWidget(const SizedBox());
        s.dispose();
      }
    },
  );

  testWidgets(
    'goal reads preserve selected id on failure and empty goals do not block recording',
    (t) async {
      final s = await session(GuidedSampleScenario.basic);
      s.goals.failedReads = 1;
      await s.model!.loadGoals();
      await mount(t, s.model!, s.navigation);
      expect(s.model!.goalId, guidedSampleId(10));
      expect(find.text('重试读取目标'), findsOneWidget);
      await tap(t, find.text('重试读取目标'));
      expect(s.model!.goalId, guidedSampleId(10));
      await t.pumpWidget(const SizedBox());
      s.dispose();
      final empty = await session(GuidedSampleScenario.emptyGoals);
      await mount(t, empty.model!, empty.navigation);
      await toTime(t, title: '吃午饭');
      await tap(t, key('guided-primary'));
      expect(empty.model!.committed!.complete, isTrue);
      expect(empty.model!.committed!.timeBlock.goalId, isNull);
      await t.pumpWidget(const SizedBox());
      empty.dispose();
    },
  );
  testWidgets(
    'rhythm first, persistent goal, cancellable answer and returning edits preserve input',
    (t) async {
      final s = await session(GuidedSampleScenario.basic);
      addTearDown(s.dispose);
      await mount(t, s.model!, s.navigation);
      expect(find.text('这段时间，节奏怎么样？'), findsOneWidget);
      expect(key('guided-activity'), findsNothing);
      expect(t.testTextInput.isVisible, isFalse);
      expect(find.text('备考'), findsOneWidget);
      await tap(t, key('guided-rhythm-stuck'));
      expect(s.navigation.step, 0);
      await tap(t, key('guided-rhythm-stuck'));
      expect(s.model!.rhythmState, isNull);
      await tap(t, key('guided-rhythm-stuck'));
      await toTime(t, title: '理数据库的表关系');
      expect(find.text('备考'), findsOneWidget);
      final applied = s.model!.time;
      await tap(t, key('guided-edit-rhythm'));
      await tap(t, key('guided-rhythm-progress'));
      await tap(t, key('guided-primary'));
      expect(s.navigation.step, 2);
      expect(s.model!.title, '理数据库的表关系');
      expect(s.model!.time, same(applied));
      expect(s.model!.rhythmState, RhythmState.progress);
    },
  );

  testWidgets(
    'Unknown keeps original text and rhythm; new title remains required for Known',
    (t) async {
      final s = await session(GuidedSampleScenario.basic);
      addTearDown(s.dispose);
      await mount(t, s.model!, s.navigation);
      await tap(t, key('guided-rhythm-stuck'));
      await tap(t, key('guided-primary'));
      await tap(t, key('guided-primary'));
      expect(find.text('请填写活动内容。'), findsOneWidget);
      await t.enterText(key('guided-activity'), '尝试整理题目');
      await tap(t, key('guided-unknown'));
      expect(key('guided-activity'), findsNothing);
      await tap(t, key('guided-unknown'));
      expect(
        t.widget<TextField>(key('guided-activity')).controller!.text,
        '尝试整理题目',
      );
      await tap(t, key('guided-unknown'));
      await tap(t, key('guided-primary'));
      await tap(t, key('guided-primary'));
      final saved = s.model!.committed!.timeBlock;
      expect(saved.knowledgeState, BlockKnowledgeState.unknown);
      expect(saved.title, '尝试整理题目');
      expect(s.ledger.annotations.single.state, RhythmState.stuck);
    },
  );

  testWidgets(
    'ordinary life can clear association and skip rhythm; does not alter preference',
    (t) async {
      final s = await session(GuidedSampleScenario.basic);
      addTearDown(s.dispose);
      await mount(t, s.model!, s.navigation);
      await tap(t, find.text('取消关联'));
      await toTime(t, title: '吃午饭');
      await tap(t, key('guided-primary'));
      expect(s.model!.committed!.timeBlock.goalId, isNull);
      expect(s.ledger.annotations, isEmpty);
      expect(s.commonGoalId, guidedSampleId(10));
    },
  );

  testWidgets(
    'candidate is never preselected and form/guided share restored answers',
    (t) async {
      final s = await session(GuidedSampleScenario.oneCandidate);
      addTearDown(s.dispose);
      await mount(t, s.model!, s.navigation);
      await toTime(t, title: '阅读');
      expect(s.model!.time.startedAt, isNull);
      await tap(t, find.byType(ListTile).first);
      expect(s.model!.time.startedAt, guidedSampleTime(8));
      await s.model!.flush();
      await t.pumpWidget(const SizedBox());
      await s.open();
      await mount(t, s.model!, s.navigation, mode: RecordingInputMode.form);
      await t.scrollUntilVisible(
        key('guided-activity'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        t.widget<TextField>(key('guided-activity')).controller!.text,
        '阅读',
      );
      expect(s.model!.time.startedAt, guidedSampleTime(8));
      expect(s.model!.goalId, guidedSampleId(10));
    },
  );

  testWidgets('restored association and archived edit override common goal', (
    t,
  ) async {
    for (final scenario in [
      GuidedSampleScenario.restored,
      GuidedSampleScenario.archived,
    ]) {
      final s = await session(scenario);
      await mount(t, s.model!, s.navigation);
      expect(
        s.model!.goalId,
        scenario == GuidedSampleScenario.restored
            ? guidedSampleId(11)
            : guidedSampleId(14),
      );
      if (scenario == GuidedSampleScenario.archived)
        expect(find.text('已归档 · 保留本笔原关联'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    }
  });

  testWidgets(
    'time adjustment cancel and invalid apply preserve parent and independent precision',
    (t) async {
      final s = await session(GuidedSampleScenario.crossDay);
      addTearDown(s.dispose);
      s.navigation.step = 2;
      await mount(t, s.model!, s.navigation);
      final before = s.model!.time;
      await tap(t, key('guided-edit-time'));
      await tap(t, find.text('直接输入日期时间'));
      await t.enterText(key('guided-start-manual'), '2026-02-30 23:40');
      await tap(t, key('guided-time-apply'));
      expect(find.text('调整这段时间'), findsOneWidget);
      expect(s.model!.time, same(before));
      await tap(t, find.text('取消修改'));
      await tap(t, key('guided-edit-time'));
      expect(key('guided-start-manual'), findsNothing);
      expect(find.text('2026-10-04'), findsOneWidget);
      await tap(t, find.text('直接输入日期时间'));
      await t.enterText(key('guided-start-manual'), '2026-10-04 23:37');
      await tap(t, key('guided-time-apply'));
      expect(s.model!.time.startedAt, guidedSampleTime(23, 37, 4));
      expect(s.model!.time.endPrecision, TimePrecision.exact);
      expect(s.model!.time.startPrecision, TimePrecision.approximate);
    },
  );

  testWidgets(
    'unset times are filled entirely with calendar and dial, including arbitrary minute and next day',
    (t) async {
      final s = await session(GuidedSampleScenario.manual);
      addTearDown(s.dispose);
      s.navigation.step = 2;
      await mount(t, s.model!, s.navigation);
      await tap(t, key('guided-edit-time'));
      await tap(t, key('guided-start-date'));
      expect(find.byType(TextField), findsNothing);
      await tap(t, find.text('取消'));
      await tap(t, find.text('取消修改'));
      expect(s.model!.time.startedAt, isNull);
      await tap(t, key('guided-edit-time'));
      for (final endpoint in ['start', 'end']) {
        await tap(t, key('guided-$endpoint-date'));
        expect(
          t
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialEntryMode,
          DatePickerEntryMode.calendarOnly,
        );
        if (endpoint == 'end') await tap(t, find.text('6').last);
        await tap(t, find.text('确定'));
        await tap(t, key('guided-$endpoint-clock'));
        expect(
          t
              .widget<TimePickerDialog>(find.byType(TimePickerDialog))
              .initialEntryMode,
          TimePickerEntryMode.dialOnly,
        );
        final dial = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_Dial',
        );
        final rect = t.getRect(dial);
        // Native 24h double ring: inner 14h, then outer 17 minutes.
        final angle = 2 * math.pi * 2 / 12;
        await t.tapAt(
          rect.center +
              Offset(math.sin(angle), -math.cos(angle)) * rect.width * .25,
        );
        await t.pumpAndSettle();
        final minuteAngle = 2 * math.pi * 17 / 60;
        final gesture = await t.startGesture(
          rect.center + Offset(rect.width * .4, 0),
        );
        await gesture.moveTo(
          rect.center +
              Offset(math.sin(minuteAngle), -math.cos(minuteAngle)) *
                  rect.width *
                  .4,
        );
        await gesture.up();
        await t.pumpAndSettle();
        await tap(t, find.text('确定'));
      }
      expect(t.testTextInput.isVisible, isFalse);
      expect(find.byType(TextField), findsNothing);
      await tap(t, key('guided-time-apply'));
      expect(s.model!.time.startedAt, guidedSampleTime(14, 17));
      expect(s.model!.time.endedAt, guidedSampleTime(14, 17, 6));
    },
  );

  testWidgets(
    'supplement cancellation does not change draft and switching rhythm preserves details',
    (t) async {
      final s = await session(GuidedSampleScenario.stuck);
      addTearDown(s.dispose);
      s.navigation.step = 2;
      await mount(t, s.model!, s.navigation);
      await tap(t, find.text('补充这笔记录'));
      await t.enterText(key('guided-hint'), '下一次先做第一题');
      await tap(t, find.text('取消补充'));
      expect(s.model!.continuationHint, '下次先列出三个小标题。');
      await tap(t, find.text('补充这笔记录'));
      await t.enterText(key('guided-reason'), '题目很大');
      await tap(t, find.text('保留补充'));
      await tap(t, key('guided-edit-rhythm'));
      await tap(t, key('guided-rhythm-recovery'));
      await tap(t, key('guided-primary'));
      expect(find.text('题目很大'), findsNothing);
      expect(s.model!.stuckReasonText, '题目很大');
    },
  );

  testWidgets(
    'conflict and save failure retain answers; finishing retries never writes twice',
    (t) async {
      for (final scenario in [
        GuidedSampleScenario.conflict,
        GuidedSampleScenario.saveFailure,
        GuidedSampleScenario.cleanupFailure,
        GuidedSampleScenario.refreshFailure,
      ]) {
        final s = await session(scenario);
        s.model!.setTitle('阅读');
        s.navigation.step = 2;
        var saved = 0;
        await mount(t, s.model!, s.navigation, saved: () => saved++);
        await tap(t, key('guided-primary'));
        expect(saved, 0);
        expect(s.model!.title, '阅读');
        if (scenario == GuidedSampleScenario.conflict) {
          expect(s.model!.conflicts, isNotEmpty);
          expect(s.ledger.writes, 0);
          s.model!.setTime(
            start: guidedSampleTime(10),
            end: guidedSampleTime(11),
          );
          await t.pumpAndSettle();
        } else if (scenario == GuidedSampleScenario.saveFailure) {
          expect(s.model!.submitError, isNotNull);
        } else {
          expect(s.model!.committed!.complete, isFalse);
          expect(find.text('重试收尾'), findsOneWidget);
          expect(s.ledger.writes, 1);
        }
        await tap(t, key('guided-primary'));
        expect(saved, 1);
        expect(s.ledger.writes, 1);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      }
    },
  );

  testWidgets(
    'failed draft flush prevents exit; missing edit source never creates a record',
    (t) async {
      final s = await session(GuidedSampleScenario.draftFailure);
      addTearDown(s.dispose);
      var exits = 0;
      await mount(t, s.model!, s.navigation, exit: () => exits++);
      await tap(t, key('guided-rhythm-stuck'));
      await tap(t, find.byTooltip('保留草稿并退出'));
      expect(exits, 0);
      expect(find.text('重试保留草稿'), findsOneWidget);
      await tap(t, find.text('重试保留草稿'));
      await tap(t, find.byTooltip('保留草稿并退出'));
      expect(exits, 1);
      await t.pumpWidget(const SizedBox());
      final missing = await session(GuidedSampleScenario.missing);
      addTearDown(missing.dispose);
      await mount(t, missing.model!, missing.navigation);
      expect(find.text('记录已不存在，无法更正。'), findsOneWidget);
      expect(key('guided-primary'), findsNothing);
      expect(missing.ledger.writes, 0);
    },
  );

  testWidgets(
    'new wizard writes through real SQLite services and restores saved fact and annotation',
    (t) async {
      final db = await AppDatabase.open(NativeDatabase.memory());
      final drafts = await DriftRecordingDraftStore.open(
        NativeDatabase.memory(),
      );
      final repo = DriftLedgerRepository(db);
      final goals = DriftGoalRepository(db);
      final goal = await goals.create(
        id: guidedSampleId(10),
        name: '备考',
        now: guidedSampleTime(8),
      );
      final loader = RecordingLedgerLoader(
        repository: repo,
        resolveDate: resolveDeviceRecordingDate,
      );
      var counter = 100;
      final saver = RecordingEntrySaver(
        repository: repo,
        drafts: drafts,
        refresh: loader.load,
        newId: () => guidedSampleId(counter++),
        now: () => guidedSampleTime(12),
      );
      final model = RecordingFormController(
        context: RecordingDraftContext.newEntry(date: guidedSampleDate),
        store: drafts,
        goals: goals,
        entrySaver: saver,
        loadSuggestion: () async => DirectTimeSuggestion(
          RecordingTimeInput(
            startedAt: guidedSampleTime(10),
            endedAt: guidedSampleTime(11),
          ),
        ),
      );
      final flow = GuidedRecordingNavigation();
      await model.initialize();
      model.selectGoal(goal.id);
      await mount(t, model, flow);
      await tap(t, key('guided-rhythm-stuck'));
      await toTime(t, title: '理数据库的表关系');
      await tap(t, key('guided-primary'));
      final committed = model.committed!;
      expect(committed.complete, isTrue);
      final result = (await repo.readTimeBlock(committed.timeBlock.id))!;
      expect(result.timeBlock.goalId, goal.id);
      expect(result.annotation!.state, RhythmState.stuck);
      expect(result.annotation!.stuckReasonCode, isNull);
      expect(await drafts.read(model.context), isNull);
      await t.pumpWidget(const SizedBox());
      await model.flush();
      model.dispose();
      flow.dispose();
      await drafts.close();
      await db.close();
    },
  );

  testWidgets(
    '320/360/412, large text and short/IME windows keep wizard and MD3 picker actions reachable',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetViewInsets);
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          t.view.physicalSize = Size(width, 640);
          final s = await session(GuidedSampleScenario.stuck);
          await t.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: timeLedgerTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: GuidedRecordingPage(
                model: s.model!,
                navigation: s.navigation,
                onSaved: () {},
                onExit: () {},
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'rhythm $width/$scale');
          await toTime(t, title: '整理跨学科资料并完成阅读笔记');
          expect(t.takeException(), isNull, reason: 'answers $width/$scale');
          await tap(t, key('guided-edit-time'));
          await tap(t, key('guided-start-date'));
          expect(find.byType(CalendarDatePicker), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(find.text('确定').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull, reason: 'calendar $width/$scale');
          await tap(t, find.text('取消'));
          await tap(t, key('guided-start-clock'));
          expect(
            find
                .byWidgetPredicate((w) => w.runtimeType.toString() == '_Dial')
                .hitTestable(),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          expect(find.text('确定').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull, reason: 'clock $width/$scale');
          await tap(t, find.text('取消'));
          await tap(t, find.text('取消修改'));
          await tap(t, key('guided-edit-activity'));
          t.view.viewInsets = const FakeViewPadding(bottom: 240);
          await t.pumpAndSettle();
          await tap(t, key('guided-activity'));
          expect(key('guided-primary').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull, reason: 'IME $width/$scale');
          t.view.resetViewInsets();
          await t.pumpWidget(const SizedBox());
          await s.model!.flush();
          s.dispose();
        }
      }
    },
  );
}
