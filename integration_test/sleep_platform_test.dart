import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';

import 'support/sleep_platform_status_native.dart'
    if (dart.library.js_interop) 'support/sleep_platform_status_web.dart'
    as platform_status;
import 'support/schema_contract.dart' show clearSchemaRows;

/// One isolated run spans eight real Android launches / Web page loads.
/// Never advance the durable phase marker until all assertions have passed.
const runId = String.fromEnvironment('E5_T08_RUN_ID');
const phaseCount = 8;
const rawMainNote = '  第一行\n  第二行😀  ';
const mainNote = '第一行\n  第二行😀';
const rawEditNote = '  更正说明\n第二段  ';
const editNote = '更正说明\n第二段';
const rawNapNote = '  小睡\n说明  ';
const conflictBlock = '00000000-0000-4000-8000-000000000081';
const conflictSleep = '00000000-0000-4000-8000-000000000082';
final date = CivilDate(year: 2026, month: 9, day: 29);
final newContext = SleepDraftContext.newEntry(date: date);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2000, month: 1, day: 1),
);
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

/// The failed clear executes a real SQLite DELETE against an ABORT trigger.
/// This affects only the isolated test draft connection, never production data.
class ClearFailure extends QueryInterceptor {
  bool armed = false;
  bool installed = false;
  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.startsWith('DELETE FROM sleep_drafts')) {
      if (armed && !installed) {
        await executor.runCustom(
          "CREATE TRIGGER fail_clear BEFORE DELETE ON sleep_drafts BEGIN SELECT RAISE(ABORT, 'test cleanup failure'); END",
        );
        installed = true;
      } else if (!armed && installed) {
        await executor.runCustom('DROP TRIGGER fail_clear');
        installed = false;
      }
    }
    await executor.runCustom(statement, args);
  }
}

class Handles {
  late AppDatabase database;
  late DriftSleepDraftStore routeDrafts;
  final clearFailure = ClearFailure();
  DriftLedgerRepository get repo => DriftLedgerRepository(database);
  Future<List<SleepSession>> sleeps() async => (await repo.readWindow(
    startedAt: at(28, 0),
    endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
  )).sleepSessions;
  Future<SleepDraft?> draft(SleepDraftContext context) async {
    // Call after leaving the route, whose owned connection has closed.
    final store = await DriftSleepDraftStore.open(
      await connectDatabase('e5_t08_sleep_drafts_$runId'),
    );
    try {
      return await store.read(context);
    } finally {
      await store.close();
    }
  }

  Future<void> noOtherFacts() async {
    for (final table in [
      'goals',
      'time_blocks',
      'rhythm_annotations',
      'daily_reviews',
    ]) {
      expect(
        await database.customSelect('SELECT * FROM $table').get(),
        isEmpty,
      );
    }
  }
}

Future<Handles> openApp(WidgetTester tester, {int day = 29}) async {
  final app = Handles();
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async {
        app.database = await AppDatabase.open(
          await connectDatabase('e5_t08_formal_$runId'),
        );
        return app.database;
      },
      openDrafts: () async => DriftRecordingDraftStore.open(
        await connectDatabase('e5_t08_ordinary_$runId'),
      ),
      openSleepDrafts: () async {
        app.routeDrafts = await DriftSleepDraftStore.open(
          (await connectDatabase('e5_t08_sleep_drafts_$runId'))
              .interceptWith(app.clearFailure),
        );
        return app.routeDrafts;
      },
      openSleepOpenings: () async => DriftSleepOpeningStore.open(
        await connectDatabase('e5_t08_openings_$runId'),
      ),
      now: () => DateTime(2026, 9, day, 12),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('时间账本'), findsOneWidget);
  // Native file I/O may finish after pumpAndSettle sees no scheduled frame.
  // Await the result of the first check before testing absence of a prompt.
  for (
    var attempt = 0;
    attempt < 150 && find.textContaining('已交代 ').evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  expect(find.textContaining('已交代 '), findsOneWidget);
  return app;
}

Future<void> tap(WidgetTester tester, String label) async {
  debugPrint('E5-T08 action=$label');
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      // Returning from a summary edit preserves the home scroll position.
      // On a short Web viewport the header action can be outside the cache.
      ['记录睡眠', '主睡眠', '小睡', '入睡准确', '入睡大约', '醒来准确', '醒来大约'].contains(label)
          ? -150
          : 150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  debugPrint('E5-T08 input=$key');
  final field = find.byKey(ValueKey(key));
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

String input(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
Future<void> edit(WidgetTester tester, String id) async {
  debugPrint('E5-T08 edit=$id');
  final target = find.byKey(ValueKey('sleep-edit-$id'));
  // A previous edit may return to a later summary row. Start the bounded
  // lookup at the top so a preceding record remains reachable on short Web.
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> remove(WidgetTester tester, String id) async {
  await edit(tester, id);
  await tap(tester, '删除睡眠');
  await tester.tap(find.text('确认删除'));
  await tester.pumpAndSettle();
}

SleepDraftContext editContext(String id) =>
    SleepDraftContext.edit(date: date, sleepSessionId: id);
void noPrompt() => expect(find.text('确认主睡眠'), findsNothing);
void restored() => expect(find.text('已恢复上次睡眠输入'), findsOneWidget);
void mainValues(SleepSession sleep, {int endMinute = 40}) {
  expect(sleep.startedAt, at(28, 23, 50));
  expect(sleep.endedAt, at(29, 7, endMinute));
  expect(sleep.startPrecision, TimePrecision.approximate);
  expect(sleep.endPrecision, TimePrecision.exact);
  expect(sleep.type, SleepType.mainSleep);
}

Future<void> phase0(WidgetTester tester) async {
  final app = await openApp(tester);
  expect(find.text('确认主睡眠'), findsOneWidget);
  await tap(tester, '确认睡眠起止');
  await tap(tester, '主睡眠');
  await enter(tester, 'sleep-start', '2026-09-28 23:50');
  await enter(tester, 'sleep-end', '2026-09-29 07:');
  await enter(tester, 'sleep-note', rawMainNote);
  await tap(tester, '入睡大约');
  await tap(tester, '醒来准确');
  await tap(tester, '保留草稿并返回');
  expect(await app.sleeps(), isEmpty);
  final saved = (await app.draft(newContext))!;
  expect(saved.startedAt, at(28, 23, 50));
  expect(saved.endedAt, isNull);
  expect(saved.endedAtInput, '2026-09-29 07:');
  expect(saved.note, rawMainNote);
  expect(saved.noteProvided, isTrue);
  expect(saved.startPrecision, TimePrecision.approximate);
  expect(saved.endPrecision, TimePrecision.exact);
  expect(find.text('已交代 0 分钟'), findsOneWidget);
  await app.noOtherFacts();
  // Leave the actual platform with incomplete input open, after autosave.
  await tap(tester, '记录睡眠');
  restored();
  expect(input(tester, 'sleep-end'), '2026-09-29 07:');
  expect(input(tester, 'sleep-note'), rawMainNote);
}

Future<void> phase1(WidgetTester tester) async {
  final app = await openApp(tester);
  noPrompt(); // Today's checked marker survived, although no main sleep exists.
  expect(await app.sleeps(), isEmpty);
  await tap(tester, '记录睡眠');
  restored();
  expect(input(tester, 'sleep-start'), '2026-09-28 23:50');
  expect(input(tester, 'sleep-end'), '2026-09-29 07:');
  expect(input(tester, 'sleep-note'), rawMainNote);
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '入睡大约')).selected,
    isTrue,
  );
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '醒来准确')).selected,
    isTrue,
  );
  await enter(tester, 'sleep-end', '2026-09-29 07:40');
  await tap(tester, '确认并保存到账本');
  expect(find.text('已交代 460 分钟'), findsOneWidget);
  expect(find.text('约470 分钟'), findsOneWidget);
  expect(await app.draft(newContext), isNull);
  final original = (await app.sleeps()).single;
  mainValues(original);
  expect(original.note, mainNote);
  await edit(tester, original.id);
  await enter(tester, 'sleep-end', '2026-09-29 08:');
  await enter(tester, 'sleep-note', rawEditNote);
  await tap(tester, '保留草稿并返回');
  final saved = (await app.draft(editContext(original.id)))!;
  expect(saved.endedAtInput, '2026-09-29 08:');
  expect(saved.note, rawEditNote);
  expect(saved.endedAt, isNull);
  mainValues((await app.sleeps()).single);
  await edit(tester, original.id);
  restored();
  expect(input(tester, 'sleep-end'), '2026-09-29 08:');
  expect(input(tester, 'sleep-note'), rawEditNote);
  await app.noOtherFacts();
}

Future<void> phase2(WidgetTester tester) async {
  final app = await openApp(tester);
  noPrompt();
  final original = (await app.sleeps()).single;
  mainValues(original);
  expect(await app.draft(newContext), isNull);
  await edit(tester, original.id);
  restored();
  expect(input(tester, 'sleep-end'), '2026-09-29 08:');
  expect(input(tester, 'sleep-note'), rawEditNote);
  // These facts arrive after a previous process left an incomplete edit.
  await app.repo.createTimeBlock(
    id: conflictBlock,
    startedAt: at(29, 7, 40),
    endedAt: at(29, 7, 50),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    knowledgeState: BlockKnowledgeState.known,
    title: '后来写入的活动',
    now: 1,
  );
  await app.repo.createSleepSession(
    id: conflictSleep,
    startedAt: at(29, 7, 50),
    endedAt: at(29, 8, 10),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    type: SleepType.nap,
    now: 1,
  );
  await enter(tester, 'sleep-end', '2026-09-29 08:00');
  await tap(tester, '保存更正');
  expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
  expect(find.textContaining('普通记录 $conflictBlock'), findsOneWidget);
  expect(find.textContaining('睡眠记录 $conflictSleep'), findsOneWidget);
  mainValues((await app.repo.readSleepSession(original.id))!);
  expect((await app.repo.readSleepSession(original.id))!.note, mainNote);
  expect(
    (await app.routeDrafts.read(editContext(original.id)))!.note,
    rawEditNote,
  );
  expect(
    (await app.routeDrafts.read(editContext(original.id)))!.endedAt,
    at(29, 8),
  );
  await tap(tester, '保留草稿并返回');
}

Future<void> phase3(WidgetTester tester) async {
  final app = await openApp(tester);
  noPrompt();
  final original = (await app.sleeps()).singleWhere(
    (s) => s.type == SleepType.mainSleep,
  );
  mainValues(original);
  await edit(tester, original.id);
  restored();
  expect(input(tester, 'sleep-end'), '2026-09-29 08:00');
  expect(input(tester, 'sleep-note'), rawEditNote);
  await enter(tester, 'sleep-end', '2026-09-29 07:30');
  await app.database.customStatement(
    "CREATE TRIGGER fail_edit AFTER UPDATE ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'test formal rollback'); END",
  );
  await tap(tester, '保存更正');
  expect(find.text('正式保存失败，睡眠输入和草稿已保留，请重试。'), findsOneWidget);
  mainValues((await app.repo.readSleepSession(original.id))!);
  expect((await app.repo.readSleepSession(original.id))!.note, mainNote);
  expect(
    (await app.routeDrafts.read(editContext(original.id)))!.note,
    rawEditNote,
  );
  expect(
    (await app.routeDrafts.read(editContext(original.id)))!.endedAt,
    at(29, 7, 30),
  );
  await app.database.customStatement('DROP TRIGGER fail_edit');
  await tap(tester, '保存更正');
  final updated = (await app.repo.readSleepSession(original.id))!;
  mainValues(updated, endMinute: 30);
  expect(updated.createdAt, original.createdAt);
  expect(updated.note, editNote);
  expect(await app.draft(editContext(original.id)), isNull);
  await app.repo.deleteTimeBlock(conflictBlock);
  await app.repo.deleteSleepSession(conflictSleep);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tap(tester, '记录睡眠');
  await tap(tester, '小睡');
  await enter(tester, 'sleep-start', '2026-09-29 10:00');
  await enter(tester, 'sleep-end', '2026-09-29 10:20');
  await enter(tester, 'sleep-note', rawNapNote);
  await tap(tester, '入睡准确');
  await tap(tester, '醒来大约');
  app.clearFailure.armed = true;
  await tap(tester, '确认并保存到账本');
  expect(find.text('睡眠已保存，但草稿清理失败；请继续清理，无需再次保存。'), findsOneWidget);
  expect(find.text('确认并保存到账本'), findsNothing);
  expect(
    (await app.sleeps()).singleWhere((s) => s.type == SleepType.nap).note,
    '小睡\n说明',
  );
  expect((await app.routeDrafts.read(newContext))!.note, rawNapNote);
  expect(await app.sleeps(), hasLength(2));
  await tap(tester, '继续清理并刷新');
  expect(await app.sleeps(), hasLength(2));
  app.clearFailure.armed = false;
  await tap(tester, '继续清理并刷新');
  expect(await app.sleeps(), hasLength(2));
  expect(await app.draft(newContext), isNull);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tap(tester, '记录睡眠');
  await enter(tester, 'sleep-start', '主动放弃的不完整输入');
  await enter(tester, 'sleep-note', '一并放弃的备注');
  await tap(tester, '放弃草稿');
  expect(await app.draft(newContext), isNull);
  await app.noOtherFacts();
}

Future<void> phase4(WidgetTester tester) async {
  final app = await openApp(tester);
  noPrompt();
  final records = await app.sleeps();
  expect(records, hasLength(2));
  final main = records.singleWhere((s) => s.type == SleepType.mainSleep);
  mainValues(main, endMinute: 30);
  expect(main.note, editNote);
  final nap = records.singleWhere((s) => s.type == SleepType.nap);
  expect(nap.startedAt, at(29, 10));
  expect(nap.endedAt, at(29, 10, 20));
  expect(nap.startPrecision, TimePrecision.exact);
  expect(nap.endPrecision, TimePrecision.approximate);
  expect(nap.note, '小睡\n说明');
  await edit(tester, nap.id);
  expect(input(tester, 'sleep-note'), '小睡\n说明');
  await enter(tester, 'sleep-note', ' \n ');
  await tap(tester, '保留草稿并返回');
  await edit(tester, nap.id);
  restored();
  expect(input(tester, 'sleep-note'), ' \n ');
  await tap(tester, '保存更正');
  expect((await app.repo.readSleepSession(nap.id))!.note, isNull);
  expect(await app.draft(editContext(nap.id)), isNull);
  expect(await app.draft(newContext), isNull);
  expect(await app.draft(editContext(main.id)), isNull);
  await edit(tester, main.id);
  expect(find.text('已恢复上次睡眠输入'), findsNothing);
  await tap(tester, '保留草稿并返回');
  await tap(tester, '记录睡眠');
  expect(find.text('已恢复上次睡眠输入'), findsNothing);
  expect(input(tester, 'sleep-start'), isEmpty);
  await tap(tester, '放弃草稿');
  await remove(tester, main.id);
  expect((await app.sleeps()).single.type, SleepType.nap);
  expect((await app.sleeps()).single.note, isNull);
  await app.noOtherFacts();
}

Future<void> phase5(WidgetTester tester) async {
  final app = await openApp(tester);
  noPrompt(); // Main sleep was deleted; the durable checked marker still applies.
  expect((await app.sleeps()).single.type, SleepType.nap);
  expect((await app.sleeps()).single.note, isNull);
  expect(find.text('尚未记录主睡眠'), findsOneWidget);
  await tap(tester, '记录睡眠');
  expect(find.text('已恢复上次睡眠输入'), findsNothing);
  await tap(tester, '主睡眠');
  await enter(tester, 'sleep-start', '2026-09-29 23:50');
  await enter(tester, 'sleep-end', '2026-09-30 07:40');
  await tap(tester, '入睡大约');
  await tap(tester, '醒来准确');
  await tap(tester, '确认并保存到账本');
  expect(await app.sleeps(), hasLength(2));
  expect(await app.draft(newContext), isNull);
  await app.noOtherFacts();
}

Future<void> phase6(WidgetTester tester) async {
  final app = await openApp(tester, day: 30);
  // This device date has never been checked, but its ended main sleep survived.
  noPrompt();
  final main = (await app.sleeps()).singleWhere(
    (s) => s.type == SleepType.mainSleep,
  );
  expect(main.note, isNull);
  expect(main.startedAt, at(29, 23, 50));
  expect(main.endedAt, at(30, 7, 40));
  expect(main.startPrecision, TimePrecision.approximate);
  expect(main.endPrecision, TimePrecision.exact);
  expect(find.text('已交代 460 分钟'), findsOneWidget);
  expect(find.text('约470 分钟'), findsOneWidget);
  await remove(tester, main.id);
  expect((await app.sleeps()).single.type, SleepType.nap);
  expect((await app.sleeps()).single.note, isNull);
  await app.noOtherFacts();
}

Future<void> phase7(WidgetTester tester) async {
  final app = await openApp(tester, day: 30);
  noPrompt(); // First-check marker on day 30 also survived deletion and restart.
  expect((await app.sleeps()).single.type, SleepType.nap);
  expect((await app.sleeps()).single.note, isNull);
  await app.noOtherFacts();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  final next = await openApp(tester, day: 31); // Calendar rolls to October 1.
  expect(find.text('确认主睡眠'), findsOneWidget);
  await tap(tester, '继续账本');
  expect(find.text('尚未记录主睡眠'), findsOneWidget);
  await clearSchemaRows(next.database);
  await next.noOtherFacts();
  expect(await next.sleeps(), isEmpty);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (runId.isEmpty) throw StateError('Pass a unique E5_T08_RUN_ID.');
  testWidgets('E5-T08 sleep survives actual platform lifecycle steps', (
    tester,
  ) async {
    final control = await DriftRecordingDraftStore.open(
      await connectDatabase('e5_t08_control_$runId'),
    );
    try {
      final previous = await control.read(controlContext);
      final phase = previous == null ? 0 : int.parse(previous.title!);
      debugPrint(
        'E5-T08 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
      final phases = [
        phase0,
        phase1,
        phase2,
        phase3,
        phase4,
        phase5,
        phase6,
        phase7,
      ];
      if (phase >= phaseCount) throw StateError('Run already finished: $phase');
      await phases[phase](tester);
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
      platform_status.reportSleepPlatformPhase(phase + 1);
      debugPrint(
        'E5-T08 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
    } catch (_) {
      await control.close();
      rethrow;
    }
  });
}
