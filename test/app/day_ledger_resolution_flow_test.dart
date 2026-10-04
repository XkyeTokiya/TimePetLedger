import '../support/ledger_date_selection.dart';

import 'dart:io';

import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/ledger_segment.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import 'gap_recording_flow_test.dart' show tap, enterTime, disposeApp;
import 'day_ledger_editing_flow_test.dart'
    show controller, editFact, deleteBlock;
import 'sleep_recording_flow_test.dart' show fill;

const minute = Duration.millisecondsPerMinute;
String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
String dateText(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

// All writes execute on SQLite. Only reads after a committed TimeBlock write
// are intercepted; failed submission is never replaced by a mock result.
class BlockReadFailure extends QueryInterceptor {
  bool arm = false;
  bool failReads = false;
  bool wroteBlock = false;
  int blockInserts = 0;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(sql, args);
    if (sql.contains('time_blocks')) {
      blockInserts++;
      wroteBlock = true;
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (wroteBlock && arm) failReads = true;
    wroteBlock = false;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    wroteBlock = false;
    await inner.rollback();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failReads &&
        sql.contains('time_blocks') &&
        sql.toUpperCase().contains('WHERE')) {
      throw StateError('test committed read failure');
    }
    return executor.runSelect(sql, args);
  }
}

class LedgerApp {
  LedgerApp(this.dir, this.db, this.drafts, this.trace, this.clock);
  final Directory dir;
  final AppDatabase db;
  final DriftRecordingDraftStore drafts;
  final BlockReadFailure trace;
  DateTime clock;
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  Future<Map<String, List<Map<String, Object?>>>> facts() async => {
    for (final name in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      name: (await db.customSelect('SELECT * FROM $name ORDER BY id').get())
          .map((r) => r.data)
          .toList(),
  };
  AppBootstrap build() => AppBootstrap(
    openDatabase: () async => db,
    openDrafts: () async => drafts,
    openSleepDrafts: () => DriftSleepDraftStore.open(
      NativeDatabase(File('${dir.path}/sleep.sqlite')),
    ),
    openSleepOpenings: () => DriftSleepOpeningStore.open(
      NativeDatabase(File('${dir.path}/openings.sqlite')),
    ),
    now: () => clock,
  );
  static Future<LedgerApp> open(WidgetTester tester, DateTime clock) async {
    final app = (await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('day_ledger_loop_');
      final trace = BlockReadFailure();
      final db = await AppDatabase.open(
        NativeDatabase(File('${dir.path}/formal.sqlite')).interceptWith(trace),
      );
      final drafts = await DriftRecordingDraftStore.open(
        NativeDatabase(File('${dir.path}/ordinary.sqlite')),
      );
      return LedgerApp(dir, db, drafts, trace, clock);
    }))!;
    addTearDown(() async {
      await app.db.close();
      await app.drafts.close();
      await app.dir.delete(recursive: true);
    });
    await tester.pumpWidget(app.build());
    await tester.pumpAndSettle();
    return app;
  }
}

Future<void> chooseDate(WidgetTester tester, DateTime date) async {
  await selectLedgerDate(tester, dateText(date));
  await tester.pumpAndSettle();
}

Future<void> gapAt(WidgetTester tester, int from, int to) async {
  final target = find.byWidgetPredicate(
    (w) =>
        w is LedgerGapTimelineTile &&
        w.gap.startedAt == from &&
        w.gap.endedAt == to,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: target, matching: find.text('补记')));
  await tester.pumpAndSettle();
}

DayLedgerView expectLedger(
  WidgetTester tester, {
  required int start,
  required int end,
  required int accounted,
  required int unknown,
  required List<(int, int)> gaps,
}) {
  final view = controller(tester).view!;
  expect((view.window.startedAt, view.window.endedAt), (start, end));
  expect(view.accountedDuration.milliseconds, accounted);
  expect(view.unknownDuration.milliseconds, unknown);
  expect(
    view.unknownDuration.milliseconds,
    lessThanOrEqualTo(view.accountedDuration.milliseconds),
  );
  expect(
    view.accountedDuration.milliseconds + view.unresolvedDuration.milliseconds,
    end - start,
  );
  expect(
    view.segments.fold<int>(0, (total, s) => total + s.duration.milliseconds),
    accounted,
  );
  expect(
    view.unresolvedSpans.map((g) => (g.startedAt, g.endedAt)).toList(),
    gaps,
  );
  expect(find.byType(LedgerGapTimelineTile), findsNWidgets(gaps.length));
  expect(
    find.byType(LedgerFactTimelineTile),
    findsNWidgets(view.segments.length),
  );
  expect(
    find.descendant(
      of: find.byType(DayLedgerTimeline),
      matching: find.text('尚未记录'),
    ),
    findsNWidgets(gaps.length),
  );
  return view;
}

Future<void> onlyFacts(
  WidgetTester tester,
  LedgerApp app, {
  required int blocks,
  required int sleeps,
}) async {
  final rows = (await tester.runAsync(app.facts))!;
  expect(rows['time_blocks'], hasLength(blocks));
  expect(rows['sleep_sessions'], hasLength(sleeps));
  for (final table in ['goals', 'rhythm_annotations', 'daily_reviews']) {
    expect(rows[table], isEmpty);
  }
  final names = (await tester.runAsync(
    () => app.db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get(),
  ))!.map((r) => r.read<String>('name')).toList();
  expect(names, [
    'daily_reviews',
    'goals',
    'rhythm_annotations',
    'sleep_sessions',
    'time_blocks',
  ]);
}

void main() {
  testWidgets(
    'one real app resolves cross-day sleep, partial known and Unknown while leaving gaps, then edits/deletes and reopens only persisted facts',
    (tester) async {
      int at(int day, int hour, [int m = 0]) =>
          DateTime(2026, 9, day, hour, m).millisecondsSinceEpoch;
      final app = await LedgerApp.open(tester, DateTime(2026, 9, 29, 12));
      await tap(tester, '确认睡眠起止');
      await fill(
        tester,
        '2026-09-28 23:50',
        '2026-09-29 07:40',
        approxStart: true,
      );
      await tap(tester, '确认并保存到账本');
      await tap(tester, '打开日账本');
      var view = expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 460 * minute,
        unknown: 0,
        gaps: [(at(29, 7, 40), at(29, 12))],
      );
      expect(
        view.sleepSummary.mainSleep.totalDuration.duration.milliseconds,
        470 * minute,
      );
      expect(
        view.sleepSummary.mainSleep.totalDuration.duration.hasApproximation,
        isTrue,
      );
      expect(
        view.accountedDuration.hasApproximation,
        isFalse,
      ); // clipped approximate sleep start
      final sleepId = view.segments.single.reference.id;
      final originalSleep = (await tester.runAsync(
        () => app.repo.readSleepSession(sleepId),
      ))!;
      await onlyFacts(tester, app, blocks: 0, sleeps: 1);

      await gapAt(tester, at(29, 7, 40), at(29, 12));
      await tester.enterText(find.byKey(const ValueKey('activity')), '写作');
      await tap(tester, '记得做了什么');
      await enterTime(tester, '结束时间', '2026-09-29 09:00');
      await tap(tester, '保存到账本');
      view = expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 540 * minute,
        unknown: 0,
        gaps: [(at(29, 9), at(29, 12))],
      );
      final known = view.segments.whereType<TimeBlockSegment>().single.source;
      expect(
        (known.startPrecision, known.endPrecision),
        (TimePrecision.approximate, TimePrecision.approximate),
      );
      expect(view.accountedDuration.hasApproximation, isTrue);
      expect(find.text('已知'), findsNothing);
      expect(find.text('写作'), findsOneWidget);

      await gapAt(tester, at(29, 9), at(29, 12));
      await tap(tester, '想不起来');
      await enterTime(tester, '结束时间', '2026-09-29 10:00');
      // Draft selections are not facts or accounted time.
      await onlyFacts(tester, app, blocks: 1, sleeps: 1);
      await tap(tester, '保留草稿并返回');
      expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 540 * minute,
        unknown: 0,
        gaps: [(at(29, 9), at(29, 12))],
      );
      await gapAt(tester, at(29, 9), at(29, 12));
      expect(find.text('已恢复上次输入'), findsOneWidget);
      await tap(tester, '保存到账本');
      view = expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 600 * minute,
        unknown: 60 * minute,
        gaps: [(at(29, 10), at(29, 12))],
      );
      final unknown = view.segments
          .whereType<TimeBlockSegment>()
          .singleWhere(
            (s) => s.source.knowledgeState == BlockKnowledgeState.unknown,
          )
          .source;
      expect(unknown.title, isNull);
      expect(find.text('想不起来'), findsOneWidget);
      expect(view.unknownDuration.hasApproximation, isTrue);
      expect(view.segments.map((s) => (s.startedAt, s.endedAt)).toList(), [
        (at(29, 0), at(29, 7, 40)),
        (at(29, 7, 40), at(29, 9)),
        (at(29, 9), at(29, 10)),
      ]);

      await editFact(tester, LedgerFactType.timeBlock, known.id);
      await enterTime(tester, '结束时间', '2026-09-29 08:30');
      await tap(tester, '保存更正');
      view = expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 570 * minute,
        unknown: 60 * minute,
        gaps: [(at(29, 8, 30), at(29, 9)), (at(29, 10), at(29, 12))],
      );
      expect(
        view.unresolvedSpans.every((g) => g.duration.hasApproximation),
        isTrue,
      );
      expect(
        (await tester.runAsync(() => app.repo.readTimeBlock(known.id)))!
            .timeBlock
            .createdAt,
        known.createdAt,
      );
      await deleteBlock(tester, unknown.id);
      expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 510 * minute,
        unknown: 0,
        gaps: [(at(29, 8, 30), at(29, 12))],
      );
      await editFact(tester, LedgerFactType.sleepSession, sleepId);
      await tap(tester, '删除睡眠');
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 50 * minute,
        unknown: 0,
        gaps: [(at(29, 0), at(29, 7, 40)), (at(29, 8, 30), at(29, 12))],
      );
      await onlyFacts(tester, app, blocks: 1, sleeps: 0);
      final finalRows = (await tester.runAsync(app.facts))!;
      expect(originalSleep.startedAt, at(28, 23, 50));
      await disposeApp(tester);
      final reopened = (await tester.runAsync(
        () => AppDatabase.open(
          NativeDatabase(File('${app.dir.path}/formal.sqlite')),
        ),
      ))!;
      final reopenedDrafts = (await tester.runAsync(
        () => DriftRecordingDraftStore.open(
          NativeDatabase(File('${app.dir.path}/ordinary.sqlite')),
        ),
      ))!;
      await tester.pumpWidget(
        AppBootstrap(
          openDatabase: () async => reopened,
          openDrafts: () async => reopenedDrafts,
          openSleepOpenings: () => DriftSleepOpeningStore.open(
            NativeDatabase(File('${app.dir.path}/openings.sqlite')),
          ),
          now: () => app.clock,
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '打开日账本');
      expectLedger(
        tester,
        start: at(29, 0),
        end: at(29, 12),
        accounted: 50 * minute,
        unknown: 0,
        gaps: [(at(29, 0), at(29, 7, 40)), (at(29, 8, 30), at(29, 12))],
      );
      expect(
        (await tester.runAsync(
          () => reopened
              .customSelect('SELECT * FROM time_blocks ORDER BY id')
              .get(),
        ))!.map((r) => r.data).toList(),
        finalRows['time_blocks'],
      );
      await disposeApp(tester);
    },
  );

  testWidgets(
    'current Gap conflict remains unresolved until manual adjacent correction; committed read retry never inserts twice; refreshed now and future contexts stay distinct',
    (tester) async {
      int at(int h) => DateTime(2026, 9, 29, h).millisecondsSinceEpoch;
      final app = await LedgerApp.open(tester, DateTime(2026, 9, 29, 12));
      await tap(tester, '确认睡眠起止');
      await fill(tester, '2026-09-28 23:50', '2026-09-29 08:00');
      await tap(tester, '确认并保存到账本');
      await tap(tester, '打开日账本');
      expectLedger(
        tester,
        start: at(0),
        end: at(12),
        accounted: 480 * minute,
        unknown: 0,
        gaps: [(at(8), at(12))],
      );
      await gapAt(tester, at(8), at(12));
      await tester.enterText(find.byKey(const ValueKey('activity')), '阅读');
      await tap(tester, '记得做了什么');
      await enterTime(tester, '结束时间', '2026-09-29 10:00');
      await tester.runAsync(
        () => app.repo.createSleepSession(
          id: id(9),
          startedAt: at(9),
          endedAt: at(10),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        ),
      );
      final before = (await tester.runAsync(app.facts))!;
      await tap(tester, '保存到账本');
      expect(find.textContaining('冲突记录：睡眠'), findsOneWidget);
      expect((await tester.runAsync(app.facts))!, before);
      expect(app.trace.blockInserts, 0);
      final draftContext = tester
          .widget<RecordingForm>(find.byType(RecordingForm))
          .context;
      expect(
        (await tester.runAsync(() => app.drafts.read(draftContext)))!.endedAt,
        at(10),
      );
      await enterTime(tester, '结束时间', '2026-09-29 09:00');
      app.trace.arm = true;
      await tap(tester, '保存到账本');
      expect(find.text('已正式保存到账本，请不要再次提交。'), findsOneWidget);
      expect(find.text('保存到账本'), findsNothing);
      await tap(tester, '继续清理并刷新');
      expect(app.trace.blockInserts, 1);
      app.trace.arm = false;
      app.trace.failReads = false;
      await tap(tester, '继续清理并刷新');
      var view = expectLedger(
        tester,
        start: at(0),
        end: at(12),
        accounted: 600 * minute,
        unknown: 0,
        gaps: [(at(10), at(12))],
      );
      expect(
        view.segments.whereType<TimeBlockSegment>().single.source.title,
        '阅读',
      );
      expect(app.trace.blockInserts, 1);
      expect(
        await tester.runAsync(() => app.drafts.read(draftContext)),
        isNull,
      );
      app.clock = DateTime(2026, 9, 29, 13);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tap(tester, '刷新账本');
      expectLedger(
        tester,
        start: at(0),
        end: at(13),
        accounted: 600 * minute,
        unknown: 0,
        gaps: [(at(10), at(13))],
      );
      await chooseDate(tester, DateTime(2026, 9, 30));
      expectLedger(
        tester,
        start: DateTime(2026, 9, 30).millisecondsSinceEpoch,
        end: DateTime(2026, 9, 30).millisecondsSinceEpoch,
        accounted: 0,
        unknown: 0,
        gaps: [],
      );
      expect(find.text('补记'), findsNothing);
      await chooseDate(tester, DateTime(2026, 9, 28));
      view = expectLedger(
        tester,
        start: DateTime(2026, 9, 28).millisecondsSinceEpoch,
        end: at(0),
        accounted: 10 * minute,
        unknown: 0,
        gaps: [
          (
            DateTime(2026, 9, 28).millisecondsSinceEpoch,
            DateTime(2026, 9, 28, 23, 50).millisecondsSinceEpoch,
          ),
        ],
      );
      expect(view.sleepSummary.mainSleep.records, isEmpty);
      await onlyFacts(tester, app, blocks: 1, sleeps: 2);
      await disposeApp(tester);
    },
  );

  for (final (month, day, hours) in [(3, 8, 23), (11, 1, 25)]) {
    final start = DateTime(2026, month, day);
    final next = DateTime(2026, month, day + 1);
    testWidgets(
      'real application fills a $hours-hour historical day across the device DST boundary and retains unresolved time',
      (tester) async {
        int at(int h) => DateTime(2026, month, day, h).millisecondsSinceEpoch;
        final app = await LedgerApp.open(
          tester,
          DateTime(2026, month, day + 1, 12),
        );
        // Keep the first-open prompt out of the timeline route without writing sleep.
        await tap(tester, '继续账本');
        await tap(tester, '打开日账本');
        await chooseDate(tester, start);
        expectLedger(
          tester,
          start: start.millisecondsSinceEpoch,
          end: next.millisecondsSinceEpoch,
          accounted: 0,
          unknown: 0,
          gaps: [(start.millisecondsSinceEpoch, next.millisecondsSinceEpoch)],
        );
        await gapAt(
          tester,
          start.millisecondsSinceEpoch,
          next.millisecondsSinceEpoch,
        );
        await tester.enterText(find.byKey(const ValueKey('activity')), '跨偏移活动');
        await tap(tester, '记得做了什么');
        await enterTime(tester, '结束时间', '${dateText(start)} 04:00');
        await tap(tester, '保存到账本');
        var view = expectLedger(
          tester,
          start: start.millisecondsSinceEpoch,
          end: next.millisecondsSinceEpoch,
          accounted: at(4) - at(0),
          unknown: 0,
          gaps: [(at(4), next.millisecondsSinceEpoch)],
        );
        expect(
          view.segments.single.duration.milliseconds,
          (hours == 23 ? 3 : 5) * 60 * minute,
        );
        await gapAt(tester, at(4), next.millisecondsSinceEpoch);
        await tap(tester, '想不起来');
        await enterTime(tester, '结束时间', '${dateText(start)} 05:00');
        await tap(tester, '保存到账本');
        view = expectLedger(
          tester,
          start: start.millisecondsSinceEpoch,
          end: next.millisecondsSinceEpoch,
          accounted: at(5) - at(0),
          unknown: 60 * minute,
          gaps: [(at(5), next.millisecondsSinceEpoch)],
        );
        expect(view.window.milliseconds, hours * 60 * minute);
        expect(view.accountedDuration.hasApproximation, isTrue);
        expect(view.unresolvedDuration.milliseconds, 19 * 60 * minute);
        await onlyFacts(tester, app, blocks: 2, sleeps: 0);
        await disposeApp(tester);
      },
      skip: next.difference(start).inHours != hours,
    );
  }
}
