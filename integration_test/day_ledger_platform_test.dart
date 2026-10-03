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
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';

import 'support/day_ledger_platform_status_native.dart'
    if (dart.library.js_interop) 'support/day_ledger_platform_status_web.dart'
    as platform_status;
import 'support/schema_contract.dart' show clearSchemaRows;

const runId = String.fromEnvironment('E6_T06_RUN_ID');
const phaseCount = 5;
const sleepId = '00000000-0000-4000-8000-000000000061';
const competitorId = '00000000-0000-4000-8000-000000000062';
final date = CivilDate(year: 2026, month: 9, day: 29);
final controlContext = RecordingDraftContext.newEntry(
  date: CivilDate(year: 2000, month: 1, day: 1),
);
int at(int h, [int m = 0]) =>
    DateTime(2026, 9, 29, h, m).millisecondsSinceEpoch;
RecordingDraftContext gapContext(int from, int to) =>
    RecordingDraftContext.gap(date: date, startedAt: from, endedAt: to);
final knownContext = gapContext(at(7, 40), at(12));
final unknownContext = gapContext(at(9), at(12));
final retryContext = gapContext(at(10), at(12));

class Handles {
  Handles(this.database, this.drafts);
  final AppDatabase database;
  final DriftRecordingDraftStore drafts;
  DriftLedgerRepository get repo => DriftLedgerRepository(database);
  Future<Map<String, List<Map<String, Object?>>>> facts() async => {
    for (final name in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      name:
          (await database.customSelect('SELECT * FROM $name ORDER BY id').get())
              .map((r) => r.data)
              .toList(),
  };
}

Future<Handles> openApp(WidgetTester tester, {bool seed = false}) async {
  final db = await AppDatabase.open(
    await connectDatabase('e6_t06_formal_$runId'),
  );
  final drafts = await DriftRecordingDraftStore.open(
    await connectDatabase('e6_t06_drafts_$runId'),
  );
  final app = Handles(db, drafts);
  if (seed) {
    expect((await app.facts()).values.every((rows) => rows.isEmpty), isTrue);
    await app.repo.createSleepSession(
      id: sleepId,
      startedAt: DateTime(2026, 9, 28, 23, 50).millisecondsSinceEpoch,
      endedAt: at(7, 40),
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.exact,
      type: SleepType.mainSleep,
      note: '保留完整跨日事实',
      now: 1,
    );
  }
  await tester.pumpWidget(
    AppBootstrap(
      openDatabase: () async => db,
      openDrafts: () async => drafts,
      openSleepDrafts: () async => DriftSleepDraftStore.open(
        await connectDatabase('e6_t06_sleep_drafts_$runId'),
      ),
      openSleepOpenings: () async => DriftSleepOpeningStore.open(
        await connectDatabase('e6_t06_openings_$runId'),
      ),
      now: () => DateTime(2026, 9, 29, 12),
    ),
  );
  await tester.pumpAndSettle();
  for (
    var i = 0;
    i < 150 && find.textContaining('已交代 ').evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
  expect(find.text('确认主睡眠'), findsNothing);
  await tap(tester, '打开日账本');
  return app;
}

Future<void> top(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> visible(WidgetTester tester, Finder target) async {
  await top(tester);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  debugPrint('E6-T06 action=$label');
  final target = find.text(label);
  await visible(tester, target);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await visible(tester, field);
  await tester.enterText(field, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> time(WidgetTester tester, String label, String value) async {
  await tap(tester, label);
  await tester.enterText(
    find.byKey(const ValueKey('time-dialog-input')),
    value,
  );
  await tester.tap(find.text('确认'));
  await tester.pumpAndSettle();
}

Future<void> gap(WidgetTester tester, int start, int end) async {
  final target = find.byWidgetPredicate(
    (w) =>
        w is LedgerGapTimelineTile &&
        w.gap.startedAt == start &&
        w.gap.endedAt == end,
  );
  await visible(tester, target);
  await tester.tap(find.descendant(of: target, matching: find.text('补一笔')));
  await tester.pumpAndSettle();
}

DayLedgerView view(WidgetTester tester) =>
    tester.widget<DayLedgerTimeline>(find.byType(DayLedgerTimeline)).view;
DayLedgerView check(
  WidgetTester tester, {
  required int accounted,
  required int unknown,
  required List<(int, int)> gaps,
}) {
  final v = view(tester);
  expect((v.window.startedAt, v.window.endedAt), (at(0), at(12)));
  expect(v.accountedDuration.milliseconds, accounted * 60000);
  expect(v.unknownDuration.milliseconds, unknown * 60000);
  expect(
    v.accountedDuration.milliseconds + v.unresolvedDuration.milliseconds,
    v.window.milliseconds,
  );
  expect(v.unresolvedSpans.map((g) => (g.startedAt, g.endedAt)).toList(), gaps);
  expect(find.byType(LedgerGapTimelineTile), findsNWidgets(gaps.length));
  return v;
}

Future<void> edit(WidgetTester tester, LedgerFactType type, String id) async {
  final tile = find.byKey(ValueKey((type: type, id: id)));
  await visible(tester, tile);
  await tester.tap(
    find.descendant(of: tile, matching: find.byTooltip('更正完整记录')),
  );
  await tester.pumpAndSettle();
}

Future<void> deleteBlock(WidgetTester tester, String id) async {
  final tile = find.byKey(ValueKey((type: LedgerFactType.timeBlock, id: id)));
  await visible(tester, tile);
  await tester.tap(find.descendant(of: tile, matching: find.byTooltip('删除记录')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('删除记录'));
  await tester.pumpAndSettle();
}

Future<void> knownInput(WidgetTester tester, String title, String end) async {
  await enter(tester, 'activity', title);
  await tap(tester, '记得做了什么');
  await time(tester, '结束时间', end);
}

void restored() => expect(find.text('已恢复上次输入'), findsOneWidget);

Future<void> phase0(WidgetTester tester) async {
  final app = await openApp(tester, seed: true);
  check(tester, accounted: 460, unknown: 0, gaps: [(at(7, 40), at(12))]);
  await gap(tester, at(7, 40), at(12));
  await knownInput(tester, 'Gap活动', '2026-09-29 09:00');
  await tap(tester, '开始准确');
  await tap(tester, '保留草稿并返回');
  check(tester, accounted: 460, unknown: 0, gaps: [(at(7, 40), at(12))]);
  expect((await app.facts())['time_blocks'], isEmpty);
  final draft = (await app.drafts.read(knownContext))!;
  expect(
    (draft.title, draft.startedAt, draft.endedAt),
    ('Gap活动', at(7, 40), at(9)),
  );
  expect(
    (draft.startPrecision, draft.endPrecision),
    (TimePrecision.exact, TimePrecision.approximate),
  );
  await gap(tester, at(7, 40), at(12));
  restored(); // Leave the input page open for actual force-stop / refresh.
}

Future<void> phase1(WidgetTester tester) async {
  final app = await openApp(tester);
  check(tester, accounted: 460, unknown: 0, gaps: [(at(7, 40), at(12))]);
  await gap(tester, at(7, 40), at(12));
  restored();
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('activity')))
        .controller!
        .text,
    'Gap活动',
  );
  expect(find.text('2026-09-29 09:00'), findsOneWidget);
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '开始准确')).selected,
    isTrue,
  );
  await tap(tester, '确认并保存到账本');
  check(tester, accounted: 540, unknown: 0, gaps: [(at(9), at(12))]);
  expect(await app.drafts.read(knownContext), isNull);
  await gap(tester, at(9), at(12));
  await tap(tester, '想不起来');
  await time(tester, '结束时间', '2026-09-29 10:00');
  await tap(tester, '保留草稿并返回');
  check(tester, accounted: 540, unknown: 0, gaps: [(at(9), at(12))]);
  expect((await app.facts())['time_blocks'], hasLength(1));
  await gap(tester, at(9), at(12));
  restored();
}

Future<void> phase2(WidgetTester tester) async {
  final app = await openApp(tester);
  expect(await app.drafts.read(knownContext), isNull);
  check(tester, accounted: 540, unknown: 0, gaps: [(at(9), at(12))]);
  await gap(tester, at(9), at(12));
  restored();
  expect(
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '想不起来')).selected,
    isTrue,
  );
  expect(find.text('2026-09-29 10:00'), findsOneWidget);
  await tap(tester, '确认并保存到账本');
  final v = check(
    tester,
    accounted: 600,
    unknown: 60,
    gaps: [(at(10), at(12))],
  );
  expect(
    v.segments
        .whereType<TimeBlockSegment>()
        .singleWhere(
          (s) => s.source.knowledgeState == BlockKnowledgeState.unknown,
        )
        .source
        .title,
    isNull,
  );
  expect(await app.drafts.read(unknownContext), isNull);
  await gap(tester, at(10), at(12));
  await knownInput(tester, '冲突后手动修正', '2026-09-29 11:00');
  await tap(tester, '保留草稿并返回');
  check(tester, accounted: 600, unknown: 60, gaps: [(at(10), at(12))]);
  await gap(tester, at(10), at(12));
  restored();
}

Future<void> phase3(WidgetTester tester) async {
  final app = await openApp(tester);
  expect(await app.drafts.read(knownContext), isNull);
  expect(await app.drafts.read(unknownContext), isNull);
  final original = check(
    tester,
    accounted: 600,
    unknown: 60,
    gaps: [(at(10), at(12))],
  );
  final known = original.segments
      .whereType<TimeBlockSegment>()
      .singleWhere((s) => s.source.knowledgeState == BlockKnowledgeState.known)
      .source;
  final unknown = original.segments
      .whereType<TimeBlockSegment>()
      .singleWhere(
        (s) => s.source.knowledgeState == BlockKnowledgeState.unknown,
      )
      .source;
  await gap(tester, at(10), at(12));
  restored();
  await app.repo.createSleepSession(
    id: competitorId,
    startedAt: at(10, 30),
    endedAt: at(11),
    startPrecision: TimePrecision.exact,
    endPrecision: TimePrecision.exact,
    type: SleepType.nap,
    now: 1,
  );
  final before = await app.facts();
  await tap(tester, '确认并保存到账本');
  expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
  expect(await app.facts(), before);
  expect((await app.drafts.read(retryContext))!.endedAt, at(11));
  await time(tester, '结束时间', '2026-09-29 10:30');
  await tap(tester, '确认并保存到账本');
  check(tester, accounted: 660, unknown: 60, gaps: [(at(11), at(12))]);
  expect(await app.drafts.read(retryContext), isNull);
  await edit(tester, LedgerFactType.timeBlock, known.id);
  await enter(tester, 'activity', '已更正Gap活动');
  await tap(tester, '保存更正');
  expect(find.text('已更正Gap活动'), findsOneWidget);
  final afterKnown = (await app.repo.readTimeBlock(known.id))!.timeBlock;
  expect(afterKnown.createdAt, known.createdAt);
  await edit(tester, LedgerFactType.sleepSession, sleepId);
  await enter(tester, 'sleep-end', '2026-09-29 07:30');
  await tap(tester, '保存更正');
  check(
    tester,
    accounted: 650,
    unknown: 60,
    gaps: [(at(7, 30), at(7, 40)), (at(11), at(12))],
  );
  await edit(tester, LedgerFactType.sleepSession, competitorId);
  await tap(tester, '删除睡眠');
  await tester.tap(find.text('确认删除'));
  await tester.pumpAndSettle();
  check(
    tester,
    accounted: 620,
    unknown: 60,
    gaps: [(at(7, 30), at(7, 40)), (at(10, 30), at(12))],
  );
  await deleteBlock(tester, unknown.id);
  check(
    tester,
    accounted: 560,
    unknown: 0,
    gaps: [(at(7, 30), at(7, 40)), (at(9), at(10)), (at(10, 30), at(12))],
  );
}

Future<void> phase4(WidgetTester tester) async {
  final app = await openApp(tester);
  final v = check(
    tester,
    accounted: 560,
    unknown: 0,
    gaps: [(at(7, 30), at(7, 40)), (at(9), at(10)), (at(10, 30), at(12))],
  );
  expect(
    v.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
    460 * 60000,
  );
  final sleep = (await app.repo.readSleepSession(sleepId))!;
  expect(sleep.startedAt, DateTime(2026, 9, 28, 23, 50).millisecondsSinceEpoch);
  expect(
    (sleep.endedAt, sleep.createdAt, sleep.note),
    (at(7, 30), 1, '保留完整跨日事实'),
  );
  expect(await app.repo.readSleepSession(competitorId), isNull);
  for (final context in [knownContext, unknownContext, retryContext]) {
    expect(await app.drafts.read(context), isNull);
  }
  expect(find.text('已更正Gap活动'), findsOneWidget);
  await gap(tester, at(10, 30), at(12));
  expect(find.text('已恢复上次输入'), findsNothing);
  await enter(tester, 'activity', '主动放弃Gap');
  await tap(tester, '放弃草稿');
  expect(await app.drafts.read(gapContext(at(10, 30), at(12))), isNull);
  check(
    tester,
    accounted: 560,
    unknown: 0,
    gaps: [(at(7, 30), at(7, 40)), (at(9), at(10)), (at(10, 30), at(12))],
  );
  // Other dates are fresh reads, not a persisted Day / slice cache.
  await top(tester);
  await tester.enterText(find.widgetWithText(TextField, '账本日期'), '2026-09-28');
  await tester.pumpAndSettle();
  expect(view(tester).segments.single.duration.milliseconds, 10 * 60000);
  final rows = await app.facts();
  expect(rows['time_blocks'], hasLength(2));
  expect(rows['sleep_sessions'], hasLength(1));
  for (final name in ['goals', 'rhythm_annotations', 'daily_reviews']) {
    expect(rows[name], isEmpty);
  }
  await clearSchemaRows(app.database);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(runId)) {
    throw StateError('Pass a unique E6_T06_RUN_ID.');
  }
  testWidgets('E6-T06 timeline and Gap input survive actual platform lifecycle', (
    tester,
  ) async {
    final control = await DriftRecordingDraftStore.open(
      await connectDatabase('e6_t06_control_$runId'),
    );
    try {
      final previous = await control.read(controlContext);
      final phase = previous == null ? 0 : int.parse(previous.title!);
      final phases = [phase0, phase1, phase2, phase3, phase4];
      if (phase < 0 || phase >= phaseCount) {
        throw StateError('Run already finished: $phase');
      }
      debugPrint(
        'E6-T06 phase=$phase platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
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
      platform_status.reportDayLedgerPlatformPhase(phase + 1);
      debugPrint(
        'E6-T06 phase=${phase + 1} passed platform=${kIsWeb ? 'web' : defaultTargetPlatform.name} run=$runId',
      );
    } catch (_) {
      await control.close();
      rethrow;
    }
  });
}
