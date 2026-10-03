import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_summary_view.dart';

import '../features/ledger/presentation/sleep_form_test.dart'
    show tapText, enter, showField;
import 'sleep_editing_flow_test.dart' show selectDate;

const conflictBlock = '00000000-0000-4000-8000-000000000001';
const conflictNap = '00000000-0000-4000-8000-000000000002';
final date = CivilDate(year: 2026, month: 9, day: 29);
final newContext = SleepDraftContext.newEntry(date: date);
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

/// All statements execute on real SQLite. Only post-write selects are faulted;
/// there is no fake repository, projection or formal write result.
class SqlFailure extends QueryInterceptor {
  bool arm = false;
  bool failReads = false;
  bool _wroteSleep = false;
  int inserts = 0;
  int updates = 0;
  int deletes = 0;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runInsert(sql, args);
    if (sql.contains('sleep_sessions')) {
      inserts++;
      _wroteSleep = true;
    }
    return result;
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runUpdate(sql, args);
    if (sql.contains('sleep_sessions')) {
      updates++;
      _wroteSleep = true;
    }
    return result;
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) async {
    final result = await executor.runDelete(sql, args);
    if (sql.contains('sleep_sessions')) {
      deletes++;
      _wroteSleep = true;
    }
    return result;
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    if (_wroteSleep && arm) failReads = true;
    _wroteSleep = false;
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    _wroteSleep = false;
    await inner.rollback();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failReads &&
        sql.contains('sleep_sessions') &&
        sql.toUpperCase().contains('WHERE')) {
      throw StateError('test post-commit read failure');
    }
    return executor.runSelect(sql, args);
  }
}

class LocalSleepApp {
  LocalSleepApp(this.dir, this.db, this.ordinary, this.trace);
  final Directory dir;
  final AppDatabase db;
  final DriftRecordingDraftStore ordinary;
  final SqlFailure trace;
  DriftSleepDraftStore? currentDrafts;
  File get draftsFile => File('${dir.path}/drafts.sqlite');
  DriftLedgerRepository get repo => DriftLedgerRepository(db);
  AppBootstrap build() => AppBootstrap(
    openDatabase: () async => db,
    openDrafts: () async => ordinary,
    openSleepDrafts: () async {
      final store = await DriftSleepDraftStore.open(NativeDatabase(draftsFile));
      currentDrafts = store;
      return store;
    },
    openSleepOpenings: () => DriftSleepOpeningStore.open(
      NativeDatabase(File('${dir.path}/openings.sqlite')),
    ),
    now: () => DateTime(2026, 9, 29, 12),
  );
  Future<SleepDraft?> readDraft(
    SleepDraftContext context, {
    bool whileOpen = false,
  }) async {
    if (whileOpen) return currentDrafts!.read(context);
    final store = await DriftSleepDraftStore.open(NativeDatabase(draftsFile));
    try {
      return await store.read(context);
    } finally {
      await store.close();
    }
  }

  Future<List<Map<String, Object?>>> sleeps() async =>
      (await db
              .customSelect('SELECT * FROM sleep_sessions ORDER BY started_at')
              .get())
          .map((row) => row.data)
          .toList();
  Future<Map<String, List<Map<String, Object?>>>> facts() async => {
    for (final table in [
      'goals',
      'time_blocks',
      'sleep_sessions',
      'rhythm_annotations',
      'daily_reviews',
    ])
      table: (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((row) => row.data)
          .toList(),
  };
  Future<void> noOtherFacts({int blocks = 0}) async {
    final rows = await facts();
    expect(rows['time_blocks'], hasLength(blocks));
    for (final table in ['goals', 'rhythm_annotations', 'daily_reviews']) {
      expect(rows[table], isEmpty);
    }
  }
}

Future<LocalSleepApp> setup(WidgetTester tester) async {
  final app = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('sleep_loop_');
    final trace = SqlFailure();
    final db = await AppDatabase.open(
      NativeDatabase(File('${dir.path}/formal.sqlite')).interceptWith(trace),
    );
    final ordinary = await DriftRecordingDraftStore.open(
      NativeDatabase(File('${dir.path}/ordinary.sqlite')),
    );
    return LocalSleepApp(dir, db, ordinary, trace);
  }))!;
  addTearDown(() async {
    await app.db.close();
    await app.ordinary.close();
    await app.dir.delete(recursive: true);
  });
  await tester.pumpWidget(app.build());
  await tester.pumpAndSettle();
  expect(find.text('确认主睡眠'), findsOneWidget);
  return app;
}

Future<void> stop(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> fill(
  WidgetTester tester,
  String from,
  String to, {
  bool nap = false,
  bool approxStart = false,
  bool approxEnd = false,
}) async {
  await tapText(tester, nap ? '小睡' : '主睡眠');
  await enter(tester, 'sleep-start', from);
  await enter(tester, 'sleep-end', to);
  await tapText(tester, approxStart ? '入睡大约' : '入睡准确');
  await tapText(tester, approxEnd ? '醒来大约' : '醒来准确');
}

Future<void> editSleep(WidgetTester tester, String id) async {
  final target = find.byKey(ValueKey('sleep-edit-$id'));
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

Future<SleepSummaryView> summary(WidgetTester tester) async {
  final target = find.byType(SleepSummaryView);
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  return tester.widget<SleepSummaryView>(target);
}

Future<void> removeSleep(WidgetTester tester, String id) async {
  await editSleep(tester, id);
  await tapText(tester, '删除睡眠');
  await tester.tap(find.text('确认删除'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'first real entry persists a draft, submits cross-day/multiple main sleeps and nap, edits and deletes with independent approximation',
    (tester) async {
      final app = await setup(tester);
      await tapText(tester, '确认睡眠起止');
      await fill(
        tester,
        '2026-09-28 23:50',
        '2026-09-29 07:40',
        approxStart: true,
      );
      await tapText(tester, '保留草稿并返回');
      expect(find.text('已交代 0 分钟'), findsOneWidget);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      expect(await tester.runAsync(app.sleeps), isEmpty);
      final draft = (await tester.runAsync(() => app.readDraft(newContext)))!;
      expect(draft.startedAt, at(28, 23, 50));
      expect(draft.endPrecision, TimePrecision.exact);
      await tapText(tester, '记录睡眠');
      expect(find.text('已恢复上次睡眠输入'), findsOneWidget);
      await tapText(tester, '确认并保存到账本');
      expect(find.text('已交代 460 分钟'), findsOneWidget);
      expect(find.text('待补记 260 分钟'), findsOneWidget);
      var displayed = (await summary(tester)).summary;
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        470 * 60000,
      );
      expect(
        displayed.mainSleep.totalDuration.duration.hasApproximation,
        isTrue,
      );
      expect(
        find.text('约2026-09-28 23:50 → 2026-09-29 07:40 · 完整时长 约470 分钟'),
        findsOneWidget,
      );
      final original = (await tester.runAsync(app.sleeps))!.single;
      final id = original['id'] as String;
      expect(await tester.runAsync(() => app.readDraft(newContext)), isNull);
      await selectDate(tester, '2026-09-28');
      expect(find.text('已交代 约10 分钟'), findsOneWidget);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      await selectDate(tester, '2026-09-29');
      for (final item in [
        (false, '09:00', '10:00', false),
        (true, '10:00', '10:20', true),
      ]) {
        await tapText(tester, '记录睡眠');
        await fill(
          tester,
          '2026-09-29 ${item.$2}',
          '2026-09-29 ${item.$3}',
          nap: item.$1,
          approxEnd: item.$4,
        );
        await tapText(tester, '确认并保存到账本');
      }
      expect(find.text('已交代 约540 分钟'), findsOneWidget);
      expect(find.text('待补记 约180 分钟'), findsOneWidget);
      displayed = (await summary(tester)).summary;
      expect(displayed.mainSleep.records, hasLength(2));
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        530 * 60000,
      );
      expect(displayed.nap.records, hasLength(1));
      expect(displayed.nap.totalDuration.duration.milliseconds, 20 * 60000);
      expect(displayed.nap.totalDuration.duration.hasApproximation, isTrue);
      expect(find.text('约530 分钟'), findsOneWidget);
      expect(find.text('约20 分钟'), findsOneWidget);
      expect(find.textContaining('完整时长'), findsNWidgets(3));
      await editSleep(tester, id);
      await enter(tester, 'sleep-end', '2026-09-29 07:30');
      expect((await tester.runAsync(app.sleeps))!.first, original);
      await tapText(tester, '保存更正');
      expect(find.text('已交代 约530 分钟'), findsOneWidget);
      displayed = (await summary(tester)).summary;
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        520 * 60000,
      );
      final updated = (await tester.runAsync(app.sleeps))!.first;
      expect(updated['id'], id);
      expect(updated['created_at'], original['created_at']);
      await removeSleep(tester, id);
      displayed = (await summary(tester)).summary;
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        60 * 60000,
      );
      expect(
        displayed.mainSleep.totalDuration.duration.hasApproximation,
        isFalse,
      );
      final remaining = (await tester.runAsync(app.sleeps))!;
      await removeSleep(tester, remaining.first['id'] as String);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      await removeSleep(tester, remaining.last['id'] as String);
      expect(find.text('已交代 0 分钟'), findsOneWidget);
      expect(find.text('待补记 720 分钟'), findsOneWidget);
      displayed = (await summary(tester)).summary;
      expect(displayed.mainSleep.records, isEmpty);
      expect(displayed.nap.records, isEmpty);
      expect(find.text('尚未记录小睡'), findsOneWidget);
      expect(find.textContaining('未睡'), findsNothing);
      await tester.runAsync(() => app.noOtherFacts());
      await stop(tester);
    },
  );

  testWidgets(
    'midnight wake saved via entry remains in complete summary with zero day contribution and is editable',
    (tester) async {
      final app = await setup(tester);
      await tapText(tester, '确认睡眠起止');
      await fill(
        tester,
        '2026-09-28 23:00',
        '2026-09-29 00:00',
        approxStart: true,
      );
      await tapText(tester, '确认并保存到账本');
      expect(find.text('已交代 0 分钟'), findsOneWidget);
      expect(find.text('待补记 720 分钟'), findsOneWidget);
      var displayed = (await summary(tester)).summary;
      expect(displayed.mainSleep.records, hasLength(1));
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        60 * 60000,
      );
      expect(find.text('约60 分钟'), findsOneWidget);
      expect(find.text('尚未记录主睡眠'), findsNothing);
      final id = (await tester.runAsync(app.sleeps))!.single['id'] as String;
      await selectDate(tester, '2026-09-28');
      expect(find.text('已交代 约60 分钟'), findsOneWidget);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      await selectDate(tester, '2026-09-29');
      await editSleep(tester, id);
      await enter(tester, 'sleep-start', '2026-09-28 23:50');
      await tapText(tester, '保存更正');
      displayed = (await summary(tester)).summary;
      expect(
        displayed.mainSleep.totalDuration.duration.milliseconds,
        10 * 60000,
      );
      expect(find.text('已交代 0 分钟'), findsOneWidget);
      await removeSleep(tester, id);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      await tester.runAsync(() => app.noOtherFacts());
      await stop(tester);
    },
  );

  testWidgets(
    'facts changed after drafting reject both conflicts; manual correction survives real rollback and editing conflicts',
    (tester) async {
      final app = await setup(tester);
      await tapText(tester, '确认睡眠起止');
      await fill(
        tester,
        '2026-09-29 10:00',
        '2026-09-29 11:00',
        approxStart: true,
      );
      await tester.runAsync(() async {
        await app.repo.createTimeBlock(
          id: conflictBlock,
          startedAt: at(29, 10),
          endedAt: at(29, 10, 30),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.known,
          title: '已有活动',
          now: 1,
        );
        await app.repo.createSleepSession(
          id: conflictNap,
          startedAt: at(29, 10, 30),
          endedAt: at(29, 11),
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          type: SleepType.nap,
          now: 1,
        );
      });
      final before = await tester.runAsync(app.facts);
      await tapText(tester, '确认并保存到账本');
      expect(find.text('时间与已有记录冲突，请手动调整后再保存。'), findsOneWidget);
      expect(find.textContaining('普通记录 $conflictBlock'), findsOneWidget);
      expect(find.textContaining('睡眠记录 $conflictNap'), findsOneWidget);
      expect(await tester.runAsync(app.facts), before);
      expect(
        (await tester.runAsync(
          () => app.readDraft(newContext, whileOpen: true),
        ))!.startedAt,
        at(29, 10),
      );
      await tapText(tester, '保留草稿并返回');
      await tapText(tester, '记录睡眠');
      expect(find.text('已恢复上次睡眠输入'), findsOneWidget);
      await enter(tester, 'sleep-end', '2026-09-29 12:00');
      await enter(tester, 'sleep-start', '2026-09-29 11:00');
      await tester.runAsync(
        () => app.db.customStatement(
          "CREATE TRIGGER fail_sleep_insert AFTER INSERT ON sleep_sessions BEGIN SELECT RAISE(ABORT, 'test rollback'); END",
        ),
      );
      await tapText(tester, '确认并保存到账本');
      expect(find.text('正式保存失败，睡眠输入和草稿已保留，请重试。'), findsOneWidget);
      expect(await tester.runAsync(app.facts), before);
      expect(
        (await tester.runAsync(
          () => app.readDraft(newContext, whileOpen: true),
        ))!.startedAt,
        at(29, 11),
      );
      await showField(tester, 'sleep-start');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('sleep-start')))
            .enabled,
        isTrue,
      );
      await tester.runAsync(
        () => app.db.customStatement('DROP TRIGGER fail_sleep_insert'),
      );
      await tapText(tester, '确认并保存到账本');
      expect(find.text('已交代 约120 分钟'), findsOneWidget);
      expect(await tester.runAsync(() => app.readDraft(newContext)), isNull);
      final inserted = (await tester.runAsync(app.sleeps))!.last;
      final id = inserted['id'] as String;
      await editSleep(tester, id);
      await enter(tester, 'sleep-start', '2026-09-29 10:15');
      await enter(tester, 'sleep-end', '2026-09-29 11:00');
      final saved = await tester.runAsync(app.facts);
      await tapText(tester, '保存更正');
      expect(find.textContaining('普通记录 $conflictBlock'), findsOneWidget);
      expect(find.textContaining('睡眠记录 $conflictNap'), findsOneWidget);
      expect(await tester.runAsync(app.facts), saved);
      await enter(tester, 'sleep-end', '2026-09-29 12:00');
      await enter(tester, 'sleep-start', '2026-09-29 11:15');
      await tapText(tester, '保存更正');
      expect(find.text('已交代 约105 分钟'), findsOneWidget);
      expect((await tester.runAsync(app.sleeps))!.last['id'], id);
      await removeSleep(tester, id);
      expect(await tester.runAsync(app.facts), before);
      await tester.runAsync(() => app.noOtherFacts(blocks: 1));
      await stop(tester);
    },
  );

  testWidgets(
    'committed create/edit/delete with real cleanup and read failures only retries cleanup and reads',
    (tester) async {
      final app = await setup(tester);
      await tapText(tester, '确认睡眠起止');
      await fill(
        tester,
        '2026-09-28 23:50',
        '2026-09-29 07:40',
        approxStart: true,
      );
      final probe = _DraftProbe(NativeDatabase(app.draftsFile));
      addTearDown(probe.close);
      for (final operation in ['create', 'edit', 'delete']) {
        if (operation != 'create') {
          final id =
              (await tester.runAsync(app.sleeps))!.single['id'] as String;
          await editSleep(tester, id);
          // Change the input even before deletion so a persisted edit draft
          // exists for the real DELETE trigger to reject during cleanup.
          await enter(
            tester,
            'sleep-end',
            operation == 'delete' ? '2026-09-29 07:20' : '2026-09-29 07:30',
          );
        }
        await tester.runAsync(
          () => probe.customStatement(
            "CREATE TRIGGER fail_clear BEFORE DELETE ON sleep_drafts BEGIN SELECT RAISE(ABORT, 'test cleanup failure'); END",
          ),
        );
        app.trace.arm = true;
        if (operation == 'delete') {
          await tapText(tester, '删除睡眠');
          await tester.tap(find.text('确认删除'));
          await tester.pumpAndSettle();
        } else {
          await tapText(tester, operation == 'create' ? '确认并保存到账本' : '保存更正');
        }
        final action = operation == 'delete' ? '删除' : '保存';
        expect(
          find.text('睡眠已$action，但草稿清理和摘要 / 账本刷新失败；请继续处理，无需再次$action。'),
          findsOneWidget,
        );
        expect(find.text('确认并保存到账本'), findsNothing);
        expect(find.text('保存更正'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('sleep-start')))
              .enabled,
          isFalse,
        );
        final snapshot = await tester.runAsync(app.facts);
        final counts = (
          app.trace.inserts,
          app.trace.updates,
          app.trace.deletes,
        );
        expect(
          snapshot!['sleep_sessions'],
          hasLength(operation == 'delete' ? 0 : 1),
        );
        expect(
          await tester.runAsync(
            () => probe.customSelect('SELECT * FROM sleep_drafts').get(),
          ),
          hasLength(1),
        );
        await tapText(tester, '继续清理并刷新');
        expect((
          app.trace.inserts,
          app.trace.updates,
          app.trace.deletes,
        ), counts);
        expect(await tester.runAsync(app.facts), snapshot);
        await tester.runAsync(
          () => probe.customStatement('DROP TRIGGER fail_clear'),
        );
        app.trace.arm = false;
        app.trace.failReads = false;
        await tapText(tester, '继续清理并刷新');
        expect((
          app.trace.inserts,
          app.trace.updates,
          app.trace.deletes,
        ), counts);
        expect(await tester.runAsync(app.facts), snapshot);
        expect(
          await tester.runAsync(
            () => probe.customSelect('SELECT * FROM sleep_drafts').get(),
          ),
          isEmpty,
        );
        expect(find.text('时间账本'), findsOneWidget);
      }
      expect(
        (app.trace.inserts, app.trace.updates, app.trace.deletes),
        (1, 1, 1),
      );
      expect(find.text('已交代 0 分钟'), findsOneWidget);
      expect(find.text('待补记 720 分钟'), findsOneWidget);
      expect((await summary(tester)).summary.mainSleep.records, isEmpty);
      expect(find.text('尚未记录主睡眠'), findsOneWidget);
      await tester.runAsync(() => app.noOtherFacts());
      await tester.runAsync(probe.close);
      await stop(tester);
    },
  );
}

class _DraftProbe extends GeneratedDatabase {
  _DraftProbe(super.executor);
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}
