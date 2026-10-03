import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/annotation_change.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_details.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import 'support/rhythm_details_platform_status_native.dart'
    if (dart.library.js_interop) 'support/rhythm_details_platform_status_web.dart'
    as platform_status;
import 'support/schema_contract.dart' show clearSchemaRows;

const runId = String.fromEnvironment('E7_T08_RUN_ID');
const sourceId = '00000000-0000-4000-8000-000000000081';
const sourceAnnotationId = '00000000-0000-4000-8000-000000000082';
const rawReason = '  平台原因\n恢复原始输入 🐾  ';
final date = CivilDate(year: 2026, month: 10, day: 2);
final newContext = RecordingDraftContext.newEntry(date: date);
final editContext = RecordingDraftContext.edit(
  date: date,
  timeBlockId: sourceId,
);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2000, month: 1, day: 1),
);
int at(int h) => DateTime(2026, 10, 2, h).millisecondsSinceEpoch;

class LegacyInputs extends GeneratedDatabase {
  LegacyInputs(super.executor);
  @override
  int get schemaVersion => 4;
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
 knowledge_state TEXT, note TEXT, note_provided INTEGER NOT NULL DEFAULT 0,
 goal_id TEXT, goal_provided INTEGER NOT NULL DEFAULT 0,
 annotation_intent TEXT NOT NULL DEFAULT 'keep', annotation_id TEXT,
 rhythm_state TEXT, continuation_hint TEXT, hint_provided INTEGER NOT NULL DEFAULT 0
)'''),
  );
}

class DraftFaults extends QueryInterceptor {
  bool failClear = false;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failClear && sql.startsWith('DELETE FROM recording_drafts')) {
      throw StateError('platform clear failure');
    }
    return executor.runCustom(sql, args);
  }
}

class Handles {
  Handles(this.db, this.drafts, this.faults);
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  final DraftFaults faults;
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  Future<List<Object?>> facts() async => [
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'sleep_sessions',
      'daily_reviews',
    ])
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  ];
}

Future<Handles> openApp(WidgetTester t, {bool legacy = false}) async {
  if (legacy) {
    final old = LegacyInputs(await connectDatabase('e7_t08_drafts_$runId'));
    await old.customStatement(
      '''INSERT INTO recording_drafts
(context_key,entry,year,month,day,time_block_id,title,started_at,ended_at,start_precision,end_precision,knowledge_state,note,note_provided,annotation_intent,rhythm_state,continuation_hint,hint_provided)
VALUES ('edit:$sourceId','edit',2026,10,2,'$sourceId','平台事实',${at(10)},${at(11)},'approximate','exact','known','原备注',1,'edit','progress','旧接续点',1)''',
    );
    expect(
      (await old.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      4,
    );
    await old.close();
  }
  final faults = DraftFaults();
  final app = Handles(
    await AppDatabase.open(await connectDatabase('e7_t08_formal_$runId')),
    await DriftRecordingDraftStore.open(
      (await connectDatabase('e7_t08_drafts_$runId')).interceptWith(faults),
    ),
    faults,
  );
  if (legacy) {
    await app.repo.createTimeBlock(
      id: sourceId,
      startedAt: at(10),
      endedAt: at(11),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      knowledgeState: BlockKnowledgeState.known,
      title: '平台事实',
      note: '原备注',
      categoryId: '原分类',
      now: 1,
      annotation: const AddAnnotation(
        id: sourceAnnotationId,
        state: RhythmState.stuck,
        stuckReasonCode: StuckReasonCode.sleepy,
        stuckReasonText: '原原因',
        recoveryMethod: RecoveryMethod.walk,
        recoveryQuality: RecoveryQuality.partlyRecovered,
        continuationHint: '原接续点',
      ),
    );
  }
  await t.pumpWidget(
    AppBootstrap(
      openDatabase: () async => app.db,
      openDrafts: () async => app.drafts,
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e7_t08_sleep_$runId'),
      ),
      openSleepOpenings: () async {
        final openings = await DriftSleepOpeningStore.open(
          await connectDatabase('e7_t08_openings_$runId'),
        );
        await openings.claim(date);
        return openings;
      },
      now: () => DateTime(2026, 10, 2, 12),
    ),
  );
  await waitForUI(t);
  for (var i = 0; i < 150 && find.text('打开日账本').evaluate().isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('打开日账本'), findsOneWidget);
  return app;
}

Future<void> waitForUI(WidgetTester t) async {
  for (var i = 0; i < 150; i++) {
    await t.pump(const Duration(milliseconds: 100));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        find.byType(LinearProgressIndicator).evaluate().isEmpty &&
        find
            .byWidgetPredicate((w) => w is AbsorbPointer && w.absorbing)
            .evaluate()
            .isEmpty) {
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
    final position = t
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(0);
    await t.pumpAndSettle();
    // A drag over a multiline field scrolls its text instead of the page.
    for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
      position.jumpTo(
        (position.pixels + 150).clamp(0, position.maxScrollExtent),
      );
      await t.pumpAndSettle();
    }
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
  debugPrint('E7-T08 action=$label');
  await tapFinder(t, find.text(label));
}

Future<void> enter(WidgetTester t, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  await visible(t, target);
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

Future<void> state(WidgetTester t, RhythmState? value) =>
    tapFinder(t, find.byKey(ValueKey('rhythm-${value?.name ?? 'none'}')));
Future<void> choice(WidgetTester t, String prefix, Enum? value) =>
    tapFinder(t, find.byKey(ValueKey('$prefix-${value?.name ?? 'none'}')));
Future<void> edit(WidgetTester t) async {
  await tap(t, '打开日账本');
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
}

Future<void> selected(WidgetTester t, String prefix, Enum? value) async {
  final target = find.byKey(ValueKey('$prefix-${value?.name ?? 'none'}'));
  await visible(t, target);
  expect(t.widget<ChoiceChip>(target).selected, isTrue);
}

Future<void> restoredDetails(WidgetTester t) async {
  await selected(t, 'recovery-method', RecoveryMethod.shower);
  await selected(t, 'recovery-quality', RecoveryQuality.notRecovered);
  await state(t, RhythmState.stuck);
  await selected(t, 'stuck-reason', StuckReasonCode.other);
  expect(await input(t, 'stuck-reason-text'), rawReason);
}

Future<void> phase0(WidgetTester t) async {
  final app = await openApp(t, legacy: true);
  final old = (await app.drafts.read(editContext))!;
  expect(old.stuckReasonTextProvided, isFalse);
  await edit(t);
  await state(t, RhythmState.stuck);
  await selected(t, 'stuck-reason', StuckReasonCode.sleepy);
  expect(await input(t, 'stuck-reason-text'), '原原因');
  await choice(t, 'stuck-reason', StuckReasonCode.other);
  await enter(t, 'stuck-reason-text', rawReason);
  await state(t, RhythmState.recovery);
  await choice(t, 'recovery-method', RecoveryMethod.shower);
  await choice(t, 'recovery-quality', RecoveryQuality.notRecovered);
  final before = await app.facts();
  await tap(t, '保留草稿并返回');
  expect(await app.facts(), before);
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
  await restoredDetails(t);
  await state(t, RhythmState.recovery);
  await tap(t, '保留草稿并返回');
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
}

Future<void> phase1(WidgetTester t) async {
  final app = await openApp(t);
  await edit(t);
  await restoredDetails(t);
  final before = await app.facts();
  await app.db.customStatement(
    "CREATE TRIGGER fail_e7_t08 AFTER UPDATE ON rhythm_annotations BEGIN SELECT RAISE(FAIL,'details failure'); END",
  );
  await tap(t, '保存更正');
  expect(find.text('正式保存失败，输入和草稿已保留，请重试。'), findsOneWidget);
  expect(await app.facts(), before);
  expect((await app.drafts.read(editContext))!.stuckReasonText, rawReason);
  await tap(t, '保留草稿并返回');
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
  expect(await input(t, 'stuck-reason-text'), rawReason);
  // Leave the failed edit open for the actual process close / tab refresh.
}

Future<void> phase2(WidgetTester t) async {
  final app = await openApp(t);
  await edit(t);
  expect(await input(t, 'stuck-reason-text'), rawReason);
  expect(find.textContaining('请不要再次提交'), findsNothing);
  await app.db.customStatement('DROP TRIGGER fail_e7_t08');
  await tap(t, '保存更正');
  final a = (await app.repo.readTimeBlock(sourceId))!.annotation!;
  expect(
    (a.stuckReasonCode, a.stuckReasonText, a.recoveryMethod, a.recoveryQuality),
    (
      StuckReasonCode.other,
      rawReason.trim(),
      RecoveryMethod.shower,
      RecoveryQuality.notRecovered,
    ),
  );
  expect(a.id, sourceAnnotationId);
  expect((await app.repo.readTimeBlock(sourceId))!.timeBlock.updatedAt, 1);
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
  await choice(t, 'stuck-reason', null);
  await tapFinder(t, find.byKey(const ValueKey('clear-stuck-reason-text')));
  await state(t, RhythmState.recovery);
  await choice(t, 'recovery-method', null);
  await choice(t, 'recovery-quality', null);
  await tap(t, '保留草稿并返回');
  final draft = (await app.drafts.read(editContext))!;
  expect([
    draft.stuckReasonCodeProvided,
    draft.stuckReasonTextProvided,
    draft.recoveryMethodProvided,
    draft.recoveryQualityProvided,
  ], everyElement(isTrue));
  await tapFinder(
    t,
    find.byKey(const ValueKey((type: LedgerFactType.timeBlock, id: sourceId))),
  );
}

Future<void> phase3(WidgetTester t) async {
  final app = await openApp(t);
  await edit(t);
  await selected(t, 'recovery-method', null);
  await selected(t, 'recovery-quality', null);
  await state(t, RhythmState.stuck);
  await selected(t, 'stuck-reason', null);
  expect(await input(t, 'stuck-reason-text'), '');
  await state(t, RhythmState.progress);
  await tap(t, '保存更正');
  final a = (await app.repo.readTimeBlock(sourceId))!.annotation!;
  expect([
    a.stuckReasonCode,
    a.stuckReasonText,
    a.recoveryMethod,
    a.recoveryQuality,
  ], everyElement(isNull));
  await t.pageBack();
  await waitForUI(t);
  await tap(t, '补一笔');
  await tap(t, '想不起来');
  await state(t, RhythmState.stuck);
  await enter(t, 'stuck-reason-text', rawReason);
  await state(t, RhythmState.recovery);
  await choice(t, 'recovery-method', RecoveryMethod.askForHelp);
  await choice(t, 'recovery-quality', RecoveryQuality.readyToContinue);
  app.faults.failClear = true;
  await tap(t, '确认并保存到账本');
  expect(find.text('已正式保存到账本，请不要再次提交。'), findsOneWidget);
  final draft = (await app.drafts.read(newContext))!;
  final snapshot = await app.repo.readWindow(startedAt: at(0), endedAt: at(12));
  expect(snapshot.timeBlocks, hasLength(2));
  final added = snapshot.annotations.singleWhere(
    (a) => a.id == draft.annotationId,
  );
  expect(added.stuckReasonText, rawReason.trim());
  expect(added.stuckReasonCode, isNull); // Text-only reason on a new fact.
  expect(added.recoveryQuality, RecoveryQuality.readyToContinue);
}

Future<void> phase4(WidgetTester t) async {
  final app = await openApp(t);
  final before = await app.facts();
  final draft = (await app.drafts.read(newContext))!;
  // Recovery automatically attempts cleanup. Keep the fault for this read,
  // then explicitly retry only cleanup/refresh after verifying restored input.
  app.faults.failClear = true;
  await tap(t, '补一笔');
  await visible(t, find.text('已正式保存到账本，请不要再次提交。'));
  expect(find.text('已正式保存到账本，请不要再次提交。'), findsOneWidget);
  await selected(t, 'recovery-method', RecoveryMethod.askForHelp);
  await selected(t, 'recovery-quality', RecoveryQuality.readyToContinue);
  app.faults.failClear = false;
  await tap(t, '继续清理并刷新');
  expect(await app.drafts.read(newContext), isNull);
  expect(await app.facts(), before);
  final snapshot = await app.repo.readWindow(startedAt: at(0), endedAt: at(12));
  expect(
    snapshot.annotations.where((a) => a.id == draft.annotationId),
    hasLength(1),
  );
  await tap(t, '补一笔');
  await state(t, RhythmState.stuck);
  await enter(t, 'stuck-reason-text', '主动放弃');
  await tap(t, '放弃草稿');
  expect(await app.drafts.read(newContext), isNull);
  expect(await app.facts(), before);
  expect(app.db.schemaVersion, 2);
  await clearSchemaRows(app.db);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(runId)) {
    throw StateError('Pass a unique E7_T08_RUN_ID.');
  }
  testWidgets('E7-T08 optional details survive actual platform lifecycle', (
    t,
  ) async {
    final control = await DriftRecordingDraftStore.open(
      await connectDatabase('e7_t08_control_$runId'),
    );
    try {
      final previous = await control.read(controlContext);
      final phase = previous == null ? 0 : int.parse(previous.title!);
      final phases = [phase0, phase1, phase2, phase3, phase4];
      if (phase < 0 || phase >= phases.length) {
        throw StateError('Run already finished: $phase');
      }
      debugPrint(
        'E7-T08 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
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
      platform_status.reportRhythmDetailsPlatformPhase(phase + 1);
      debugPrint(
        'E7-T08 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
    } catch (_) {
      await control.close();
      rethrow;
    }
  });
}
