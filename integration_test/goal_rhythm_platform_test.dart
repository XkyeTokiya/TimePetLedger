import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/data/drift_goal_repository.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';

import 'support/goal_rhythm_platform_status_native.dart'
    if (dart.library.js_interop) 'support/goal_rhythm_platform_status_web.dart'
    as platform_status;
import 'support/schema_contract.dart' show clearSchemaRows;

const runId = String.fromEnvironment('E7_T07_RUN_ID');
const competitorId = '00000000-0000-4000-8000-000000000071';
const rawHint = '  从字段关系接上\n检查边界 🐾  ';
const editHint = '  换个例子\n继续检查 🐾  ';
final date = CivilDate(year: 2026, month: 10, day: 2);
final newContext = RecordingDraftContext.newEntry(date: date);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2000, month: 1, day: 1),
);
int at(int h, [int m = 0]) =>
    DateTime(2026, 10, 2, h, m).millisecondsSinceEpoch;

// Only a legacy input-store fixture. The production v3 -> v4 migration opens
// this same named platform database before the real app restores its input.
class LegacyInputs extends GeneratedDatabase {
  LegacyInputs(super.executor);
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''CREATE TABLE recording_drafts (
 context_key TEXT NOT NULL PRIMARY KEY, entry TEXT NOT NULL,
 year INTEGER NOT NULL, month INTEGER NOT NULL, day INTEGER NOT NULL,
 time_block_id TEXT, gap_start INTEGER, gap_end INTEGER,
 title TEXT, started_at INTEGER, ended_at INTEGER,
 start_precision TEXT NOT NULL, end_precision TEXT NOT NULL,
 knowledge_state TEXT, note TEXT,
 note_provided INTEGER NOT NULL DEFAULT 0 CHECK(note_provided IN (0,1)),
 goal_id TEXT, goal_provided INTEGER NOT NULL DEFAULT 0 CHECK(goal_provided IN (0,1))
)'''),
  );
}

class Handles {
  Handles(this.db, this.drafts);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  DateTime clock = DateTime(2026, 10, 2, 12);
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  DriftGoalRepository get goals => DriftGoalRepository(db);
  Future<Map<String, List<Map<String, Object?>>>> facts() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  };
}

Future<Handles> openApp(WidgetTester t, {bool legacy = false}) async {
  if (legacy) {
    final old = LegacyInputs(await connectDatabase('e7_t07_drafts_$runId'));
    await old.customStatement(
      '''INSERT INTO recording_drafts
(context_key,entry,year,month,day,title,started_at,ended_at,start_precision,end_precision,knowledge_state,note,note_provided)
VALUES ('new:2026:10:2','ordinary',2026,10,2,'  旧普通草稿 🐾  ',${at(10)},${at(11)},'exact','approximate','known','旧备注',1)''',
    );
    expect(
      (await old.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      3,
    );
    await old.close();
  }
  final app = Handles(
    await AppDatabase.open(await connectDatabase('e7_t07_formal_$runId')),
    await DriftRecordingDraftStore.open(
      await connectDatabase('e7_t07_drafts_$runId'),
    ),
  );
  await t.pumpWidget(
    AppBootstrap(
      openDatabase: () async => app.db,
      openDrafts: () async => app.drafts,
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e7_t07_sleep_drafts_$runId'),
      ),
      openSleepOpenings: () async {
        final openings = await DriftSleepOpeningStore.open(
          await connectDatabase('e7_t07_openings_$runId'),
        );
        await openings.claim(
          date,
        ); // Scenario begins after today's confirmation.
        return openings;
      },
      now: () => app.clock,
    ),
  );
  await t.pumpAndSettle();
  for (var i = 0; i < 150 && find.text('打开目标').evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
  expect(find.text('打开目标'), findsOneWidget);
  return app;
}

// pumpAndSettle waits for frames, not outstanding platform SQL. Observe busy
// UI before sending the next action; do not race input against async clear.
Future<void> waitForUI(WidgetTester t) async {
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 100));
    final dialog = find.byType(Dialog).evaluate().isNotEmpty;
    final busy =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
        find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
        find
            .byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing)
            .evaluate()
            .isNotEmpty ||
        (!dialog && find.text('正在保存目标…').evaluate().isNotEmpty) ||
        find.text('正在保存名称…').evaluate().isNotEmpty;
    if (!busy) {
      await t.pumpAndSettle();
      return;
    }
  }
  fail('Platform UI did not finish its operation');
}

Future<void> visible(WidgetTester t, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(t.element(target.first), alignment: .5);
  await t.pumpAndSettle();
}

Future<void> tapFinder(WidgetTester t, Finder target) async {
  await visible(t, target);
  await t.tap(target.first);
  await waitForUI(t);
}

Future<void> tap(WidgetTester t, String label) async {
  debugPrint('E7-T07 action=$label');
  await tapFinder(t, find.text(label));
}

Future<void> enter(WidgetTester t, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  await visible(t, target);
  // Re-entering the same field must refocus its real IME connection.
  await t.tap(target);
  await t.pumpAndSettle();
  await t.enterText(target, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
}

Future<String> input(WidgetTester t, String key) async {
  final target = find.byKey(ValueKey(key));
  await visible(t, target);
  return t.widget<TextField>(target).controller!.text;
}

Future<void> time(WidgetTester t, String label, String value) async {
  await tap(t, label);
  await t.enterText(find.byKey(const ValueKey('time-dialog-input')), value);
  await tap(t, '确认');
}

Future<void> back(WidgetTester t) async {
  await t.pageBack();
  await waitForUI(t);
}

Future<void> state(WidgetTester t, RhythmState? state) =>
    tapFinder(t, find.byKey(ValueKey('rhythm-${state?.name ?? 'none'}')));
Future<void> choose(WidgetTester t, String id) async {
  await tap(t, '选择目标');
  await tapFinder(t, find.byKey(ValueKey('goal-option-$id')));
}

Future<void> action(WidgetTester t, String id, String label) async {
  await tapFinder(t, find.byKey(ValueKey('goal-actions-$id')));
  await tap(t, label);
}

Future<void> edit(WidgetTester t, String id) => tapFinder(
  t,
  find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id))),
);
DayLedgerView view(WidgetTester t) =>
    t.widget<DayLedgerTimeline>(find.byType(DayLedgerTimeline)).view;
void projection(
  WidgetTester t, {
  required int minutes,
  required RhythmState? rhythm,
  required bool archived,
}) {
  final v = view(t);
  final g = v.goalSummaries.single;
  expect(g.totalDuration.milliseconds, minutes * 60000);
  expect(g.isArchived, archived);
  expect(
    (
      g.progressDuration.milliseconds,
      g.stuckDuration.milliseconds,
      g.recoveryDuration.milliseconds,
      g.unannotatedDuration.milliseconds,
    ),
    (
      rhythm == RhythmState.progress ? minutes * 60000 : 0,
      rhythm == RhythmState.stuck ? minutes * 60000 : 0,
      rhythm == RhythmState.recovery ? minutes * 60000 : 0,
      rhythm == null ? minutes * 60000 : 0,
    ),
  );
  expect(
    v.accountedDuration.milliseconds + v.unresolvedDuration.milliseconds,
    v.window.milliseconds,
  );
}

Future<void> phase0(WidgetTester t) async {
  final app = await openApp(t, legacy: true);
  expect((await app.facts()).values.every((rows) => rows.isEmpty), isTrue);
  final old = (await app.drafts.read(newContext))!;
  expect(old.title, '  旧普通草稿 🐾  ');
  expect(old.note, '旧备注');
  expect(old.goalProvided, isFalse);
  expect(old.annotationIntent, RecordingAnnotationIntent.keep);
  expect(old.hintProvided, isFalse);
  await tap(t, '打开目标');
  for (var i = 0; i < 2; i++) {
    await enter(t, 'goal-name', '  同名平台目标 🐾  ');
    expect(await input(t, 'goal-name'), '  同名平台目标 🐾  ');
    await tap(t, '创建目标');
    for (var attempt = 0; attempt < 150; attempt++) {
      final created = await app.goals.listActive();
      if (created.length == i + 1) break;
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(await app.goals.listActive(), hasLength(i + 1));
    await visible(t, find.byKey(const ValueKey('goal-name')));
    for (var attempt = 0; attempt < 150; attempt++) {
      final field = t.widget<TextField>(
        find.byKey(const ValueKey('goal-name')),
      );
      if (field.enabled == true && field.controller!.text.isEmpty) break;
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(await input(t, 'goal-name'), isEmpty);
  }
  final goals = await app.goals.listActive();
  expect(goals, hasLength(2));
  expect(goals.map((g) => g.id).toSet(), hasLength(2));
  await back(t);
  await tap(t, '补一笔');
  expect(find.text('已恢复上次输入'), findsOneWidget);
  expect(await input(t, 'activity'), old.title);
  expect(await input(t, 'note'), old.note);
  await choose(t, goals.last.id);
  await state(t, RhythmState.progress);
  await enter(t, 'continuation-hint', rawHint);
  final before = await app.facts();
  await tap(t, '保留草稿并返回');
  expect(await app.facts(), before);
  final draft = (await app.drafts.read(newContext))!;
  expect(draft.goalId, goals.last.id);
  expect(draft.rhythmState, RhythmState.progress);
  expect(draft.annotationId, isNotNull);
  expect(draft.continuationHint, rawHint);
  await tap(t, '补一笔');
  expect(await input(t, 'continuation-hint'), rawHint);
  // External driver closes the actual process / refreshes this open form.
}

Future<void> phase1(WidgetTester t) async {
  final app = await openApp(t);
  final draft = (await app.drafts.read(newContext))!;
  expect((await app.facts())['time_blocks'], isEmpty);
  expect((await app.goals.listActive()).length, 2);
  await tap(t, '打开目标');
  await action(t, draft.goalId!, '归档目标');
  await back(t);
  await tap(t, '补一笔');
  expect(find.text('已恢复上次输入'), findsOneWidget);
  expect(await input(t, 'continuation-hint'), rawHint);
  await visible(t, find.byKey(const ValueKey('selected-goal')));
  expect(find.text('同名平台目标 🐾（已归档）'), findsOneWidget);
  expect(find.text('此目标已归档，请重新选择或移除后保存。'), findsOneWidget);
  final before = await app.facts();
  await tap(t, '确认并保存到账本');
  expect(find.text('正式保存失败，输入和草稿已保留，请重试。'), findsOneWidget);
  expect(await app.facts(), before);
  final failed = (await app.drafts.read(newContext))!;
  expect(failed.annotationId, draft.annotationId);
  expect(failed.continuationHint, rawHint);
  // Leave failed input open: failure retention must also survive lifecycle.
}

Future<void> phase2(WidgetTester t) async {
  final app = await openApp(t);
  final draft = (await app.drafts.read(newContext))!;
  await tap(t, '补一笔');
  expect(await input(t, 'continuation-hint'), rawHint);
  await tap(t, '保留草稿并返回');
  await tap(t, '打开目标');
  await tap(t, '查看已归档目标');
  await action(t, draft.goalId!, '恢复目标');
  await back(t);
  await back(t);
  await tap(t, '补一笔');
  await tap(t, '确认并保存到账本');
  expect(await app.drafts.read(newContext), isNull);
  final rows = await app.facts();
  final id = rows['time_blocks']!.single['id']! as String;
  final saved = (await app.repo.readTimeBlock(id))!;
  expect(saved.timeBlock.goalId, draft.goalId);
  expect(saved.timeBlock.startPrecision, TimePrecision.exact);
  expect(saved.timeBlock.endPrecision, TimePrecision.approximate);
  expect(saved.annotation!.id, draft.annotationId);
  expect(saved.annotation!.continuationHint, rawHint.trim());
  await app.repo.updateTimeBlock(
    id: id,
    now: at(12),
    categoryId: (value: '原分类'),
    annotation: const EditAnnotation(
      stuckReasonText: (value: '原原因'),
      recoveryMethod: (value: RecoveryMethod.walk),
    ),
  );
  final original = await app.facts();
  await tap(t, '打开日账本');
  projection(t, minutes: 60, rhythm: RhythmState.progress, archived: false);
  await edit(t, id);
  await tap(t, '想不起来');
  await time(t, '开始时间', '2026-10-02 09:00');
  await time(t, '结束时间', '2026-10-02 10:00');
  await state(t, RhythmState.stuck);
  await enter(t, 'continuation-hint', editHint);
  await tap(t, '保留草稿并返回');
  expect(await app.facts(), original);
  projection(t, minutes: 60, rhythm: RhythmState.progress, archived: false);
  await edit(t, id);
  expect(find.text('已恢复上次输入'), findsOneWidget);
  expect(await input(t, 'continuation-hint'), editHint);
}

Future<void> phase3(WidgetTester t) async {
  final app = await openApp(t);
  expect(await app.drafts.read(newContext), isNull);
  final original = await app.facts();
  final id = original['time_blocks']!.single['id']! as String;
  final source = (await app.repo.readTimeBlock(id))!;
  final context = RecordingDraftContext.edit(date: date, timeBlockId: id);
  expect((await app.drafts.read(context))!.rhythmState, RhythmState.stuck);
  await tap(t, '打开目标');
  await action(t, source.timeBlock.goalId!, '归档目标');
  await back(t);
  await tap(t, '打开日账本');
  projection(t, minutes: 60, rhythm: RhythmState.progress, archived: true);
  await edit(t, id);
  expect(await input(t, 'continuation-hint'), editHint);
  await app.repo.createSleepSession(
    id: competitorId,
    startedAt: at(9, 30),
    endedAt: at(10),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    type: SleepType.nap,
    now: at(12),
  );
  final before = await app.facts();
  await tap(t, '保存更正');
  expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
  expect(await app.facts(), before);
  expect((await app.drafts.read(context))!.continuationHint, editHint);
  await time(t, '结束时间', '2026-10-02 09:30');
  app.clock = DateTime(2026, 10, 2, 12, 1);
  await tap(t, '保存更正');
  expect(await app.drafts.read(context), isNull);
  final changed = (await app.repo.readTimeBlock(id))!;
  expect(changed.timeBlock.id, source.timeBlock.id);
  expect(changed.timeBlock.createdAt, source.timeBlock.createdAt);
  expect(changed.timeBlock.updatedAt, app.clock.millisecondsSinceEpoch);
  expect(changed.timeBlock.categoryId, '原分类');
  expect(changed.timeBlock.note, '旧备注');
  expect(changed.timeBlock.knowledgeState, BlockKnowledgeState.unknown);
  expect(changed.annotation!.id, source.annotation!.id);
  expect(changed.annotation!.createdAt, source.annotation!.createdAt);
  expect(changed.annotation!.stuckReasonText, '原原因');
  expect(changed.annotation!.recoveryMethod, RecoveryMethod.walk);
  projection(t, minutes: 30, rhythm: RhythmState.stuck, archived: true);
  expect(view(t).unknownDuration.milliseconds, 30 * 60000);
  final blockRows = (await app.facts())['time_blocks'];
  await edit(t, id);
  await state(t, null);
  await tap(t, '保存更正');
  expect((await app.facts())['rhythm_annotations'], isEmpty);
  expect((await app.facts())['time_blocks'], blockRows);
  projection(t, minutes: 30, rhythm: null, archived: true);
  await edit(t, id);
  await state(t, RhythmState.recovery);
  await enter(t, 'continuation-hint', '恢复后从小段接上 🐾');
  await tap(t, '保存更正');
  expect((await app.facts())['rhythm_annotations'], hasLength(1));
  expect((await app.facts())['time_blocks'], blockRows);
  projection(t, minutes: 30, rhythm: RhythmState.recovery, archived: true);
  expect(await app.drafts.read(context), isNull);
  // The next real restart / refresh reads these committed rows again.
}

Future<void> phase4(WidgetTester t) async {
  final app = await openApp(t);
  final rows = await app.facts();
  expect(rows['goals'], hasLength(2));
  expect(rows['time_blocks'], hasLength(1));
  expect(rows['rhythm_annotations'], hasLength(1));
  expect(rows['sleep_sessions'], hasLength(1));
  expect(rows['daily_reviews'], isEmpty);
  final id = rows['time_blocks']!.single['id']! as String;
  final block = (await app.repo.readTimeBlock(id))!;
  expect(block.annotation!.state, RhythmState.recovery);
  expect(block.annotation!.continuationHint, '恢复后从小段接上 🐾');
  expect(block.timeBlock.goalId, isNotNull);
  expect(
    (await app.goals.findById(block.timeBlock.goalId!))!.status,
    GoalStatus.archived,
  );
  expect(await app.drafts.read(newContext), isNull);
  expect(
    await app.drafts.read(
      RecordingDraftContext.edit(date: date, timeBlockId: id),
    ),
    isNull,
  );
  await tap(t, '打开日账本');
  projection(t, minutes: 30, rhythm: RhythmState.recovery, archived: true);
  await visible(t, find.text('接续点：恢复后从小段接上 🐾'));
  expect(find.text('目标：同名平台目标 🐾（已归档）'), findsOneWidget);
  await back(t);
  await tap(t, '打开目标');
  await tap(t, '查看已归档目标');
  await action(t, block.timeBlock.goalId!, '恢复目标');
  await back(t);
  await action(t, block.timeBlock.goalId!, '改名');
  await enter(t, 'goal-rename-name', '平台目标新名称');
  await tap(t, '保存名称');
  await back(t);
  await tap(t, '打开日账本');
  projection(t, minutes: 30, rhythm: RhythmState.recovery, archived: false);
  expect(view(t).goalSummaries.single.name, '平台目标新名称');
  expect((await app.facts())['time_blocks'], rows['time_blocks']);
  expect((await app.facts())['rhythm_annotations'], rows['rhythm_annotations']);
  await back(t);
  await tap(t, '补一笔');
  expect(find.text('已恢复上次输入'), findsNothing);
  await enter(t, 'activity', '主动放弃');
  await choose(t, block.timeBlock.goalId!);
  await state(t, RhythmState.stuck);
  await enter(t, 'continuation-hint', '不提交这个接续点');
  final before = await app.facts();
  await tap(t, '放弃草稿');
  expect(await app.drafts.read(newContext), isNull);
  expect(await app.facts(), before);
  await clearSchemaRows(app.db);
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(runId)) {
    throw StateError('Pass a unique E7_T07_RUN_ID.');
  }
  testWidgets(
    'E7-T07 Goal/rhythm input and facts survive actual platform lifecycle',
    (t) async {
      final control = await DriftRecordingDraftStore.open(
        await connectDatabase('e7_t07_control_$runId'),
      );
      try {
        final previous = await control.read(controlContext);
        final phase = previous == null ? 0 : int.parse(previous.title!);
        final phases = [phase0, phase1, phase2, phase3, phase4];
        if (phase < 0 || phase >= phases.length) {
          throw StateError('Run already finished: $phase');
        }
        debugPrint(
          'E7-T07 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
        );
        await phases[phase](t);
        await control.save(
          RecordingDraft(
            context: controlContext,
            title: '${phase + 1}',
            startedAt: null,
            endedAt: null,
            startPrecision: TimePrecision.exact,
            endPrecision: TimePrecision.exact,
            knowledgeState: null,
          ),
        );
        await control.close();
        platform_status.reportGoalRhythmPlatformPhase(phase + 1);
        debugPrint(
          'E7-T07 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
        );
      } catch (_) {
        await control.close();
        rethrow;
      }
    },
  );
}
