import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
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
import 'package:time_pet_ledger/features/ledger/presentation/activity/activity_recording_entry.dart';

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
  bool failRefresh = false;
  late final saver = RecordingEntrySaver(
    repository: repo,
    drafts: drafts,
    refresh: ({required date, required now}) {
      if (failRefresh) throw StateError('refresh');
      return loader.load(date: date, now: now);
    },
    newId: () => id(ids++),
    now: () => end + 1,
  );
  late final editor = RecordingEntryEditor(
    repository: repo,
    drafts: drafts,
    saver: saver,
  );

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

  Widget app(RecordingDraftContext context, {VoidCallback? onSaved}) =>
      MaterialApp(
        theme: homeTheme,
        home: Builder(
          builder: (outer) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.push(
                outer,
                MaterialPageRoute<Object?>(
                  builder: (_) => ActivityRecordingEntry(
                    context: context,
                    store: drafts,
                    entrySaver: saver,
                    entryEditor: editor,
                    goals: goals,
                    loadSuggestion: () async => DirectTimeSuggestion(
                      RecordingTimeInput(startedAt: start, endedAt: end),
                    ),
                  ),
                ),
              ).then((_) => onSaved?.call()),
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
  if (target.evaluate().isEmpty) {
    fail('key "$value" not found; on screen: ${_screen(t)}');
  }
  await t.ensureVisible(target.first);
  await settleNative(t);
  await t.tap(target.first);
  await settleNative(t);
}

String _screen(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data)
    .whereType<String>()
    .join(' | ');

void main() {
  testWidgets('steps 节奏 → 事项 → 时间 save one known record with a hint', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    // Step 1: pick 推进, which advances straight to the activity step.
    expect(find.text('这段时间，\n节奏怎么样？'), findsOneWidget);
    await tapKey(t, 'activity-rhythm-progress');

    // Step 2: title is required.
    await tapKey(t, 'activity-primary');
    expect(find.text('请填写活动内容。'), findsOneWidget);
    await t.enterText(key('activity'), '设计首页');
    await settleNative(t);
    await tapKey(t, 'activity-primary');

    // Step 3: duration preview and the details sheet.
    expect(key('activity-time-summary'), findsOneWidget);
    await tapKey(t, 'activity-details');
    await t.enterText(key('continuation-hint'), '先画补记弹层');
    await settleNative(t);
    await tapKey(t, 'activity-details-apply');

    await tapKey(t, 'activity-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.timeBlocks, hasLength(1));
    expect(saved.timeBlocks.single.title, '设计首页');
    expect(saved.timeBlocks.single.startPrecision, TimePrecision.approximate);
    expect(saved.annotations.single.state, RhythmState.progress);
    expect(saved.annotations.single.continuationHint, '先画补记弹层');
    expect(
      await t.runAsync(() => f.drafts.read(newContext)),
      isNull,
    );
  });

  testWidgets('想不起来 skips the title and still saves an unknown fact', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    // No rhythm at all: step 1 continues straight to the activity question.
    await tapKey(t, 'activity-primary');
    expect(find.text('这段主要做了什么？'), findsOneWidget);
    await t.tap(find.text('想不起来'));
    await settleNative(t);
    expect(key('activity'), findsNothing);
    await tapKey(t, 'activity-primary');
    await tapKey(t, 'activity-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.timeBlocks.single.knowledgeState, BlockKnowledgeState.unknown);
    expect(saved.timeBlocks.single.title, isNull);
  });

  testWidgets('卡住 collects the applicable reason and hides recovery fields', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    // 卡住 has applicable sub-options, so picking it advances to that step.
    await tapKey(t, 'activity-rhythm-stuck');
    expect(find.text('是什么让你卡住了？'), findsOneWidget);
    expect(key('activity-method-walk'), findsNothing);
    await tapKey(t, 'activity-reason-unclearNextStep');
    await t.enterText(key('activity-reason-text'), '需求没定');
    await settleNative(t);
    await tapKey(t, 'activity-primary');
    await t.enterText(key('activity'), '写方案');
    await settleNative(t);
    await tapKey(t, 'activity-primary');
    await tapKey(t, 'activity-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.annotations.single.state, RhythmState.stuck);
    expect(
      saved.annotations.single.applicableStuckReasonCode,
      StuckReasonCode.unclearNextStep,
    );
    expect(saved.annotations.single.applicableStuckReasonText, '需求没定');
  });

  testWidgets('上一步 returns through the steps and keeps the rhythm choice', (
    t,
  ) async {
    final f = await open(t);
    await t.pumpWidget(f.app(newContext));
    await settleNative(t);
    await tapKey(t, 'open');

    // Picking 休息 advances straight to the recovery details step.
    await tapKey(t, 'activity-rhythm-recovery');
    await tapKey(t, 'activity-method-walk');
    await tapKey(t, 'activity-quality-readyToContinue');
    await tapKey(t, 'activity-primary');
    await t.enterText(key('activity'), '散步');
    await settleNative(t);
    await tapKey(t, 'activity-primary');

    // 上一步 returns to the activity step, then to the recovery details step.
    await tapKey(t, 'activity-previous');
    expect(find.text('这段怎么休息的？'), findsOneWidget);
    await tapKey(t, 'activity-previous');
    expect(find.text('怎么让自己缓一缓？'), findsOneWidget);

    // Going forward again keeps the recovery answers, and the save carries
    // them through even though the user never re-tapped them.
    await tapKey(t, 'activity-primary');
    await tapKey(t, 'activity-primary');
    await tapKey(t, 'activity-primary');
    await settleNative(t);

    final saved = (await t.runAsync(
      () => f.repo.readWindow(
        startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
      ),
    ))!;
    expect(saved.timeBlocks.single.title, '散步');
    expect(saved.annotations.single.state, RhythmState.recovery);
    expect(saved.annotations.single.applicableRecoveryMethod, RecoveryMethod.walk);
    expect(
      saved.annotations.single.applicableRecoveryQuality,
      RecoveryQuality.readyToContinue,
    );
  });

  testWidgets('edit mode loads the source and saves the correction', (t) async {
    final f = await open(t);
    await t.runAsync(f.source);
    await t.pumpWidget(f.app(editContext));
    await settleNative(t);
    await tapKey(t, 'open');

    expect(find.text('更正记录'), findsOneWidget);
    // The source has a stuck annotation, so the order is
    // 节奏 → 适用子选项 → 事项 → 时间. Walk to the activity step.
    await tapKey(t, 'activity-primary');
    expect(find.text('是什么让你卡住了？'), findsOneWidget);
    await tapKey(t, 'activity-primary');
    expect(find.text('刚才在做什么时卡住了？'), findsOneWidget);
    await t.enterText(key('activity'), '改了标题');
    await settleNative(t);
    await tapKey(t, 'activity-primary');
    await tapKey(t, 'activity-primary');
    await settleNative(t);

    final saved = (await t.runAsync(() => f.repo.readTimeBlock(id(8))))!;
    expect(saved.timeBlock.id, id(8));
    expect(saved.timeBlock.title, '改了标题');
    expect(saved.annotation?.state, RhythmState.stuck);
    expect(saved.annotation?.continuationHint, '原接续点');
  });
}
