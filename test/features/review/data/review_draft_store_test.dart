import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';

import '../../../../integration_test/support/ledger_read_contract.dart'
    show
        insertLedgerRow,
        blockRow,
        sleepRow,
        annotationRow,
        ledgerId,
        secondLedgerId;

final date = CivilDate(year: 2026, month: 10, day: 2);
final context = ReviewDraftContext.newEntry(date: date);
ReviewDraft draft(
  ReviewDraftContext c, {
  CivilDate? selected,
  String? rawDate,
  String? summary,
  String? reflection,
  String? step,
  String? goal,
}) => ReviewDraft(
  context: c,
  date: selected,
  dateInput: rawDate,
  summary: summary,
  reflection: reflection,
  tomorrowFirstStepText: step,
  tomorrowFirstStepGoalId: goal,
);
List<Object?> fields(ReviewDraft d) => [
  d.context.entryDate,
  d.context.reviewId,
  d.date,
  d.dateInput,
  d.summary,
  d.reflection,
  d.tomorrowFirstStepText,
  d.tomorrowFirstStepGoalId,
];
Matcher failure(ReviewDraftOperation op) => throwsA(
  isA<ReviewDraftStorageException>().having(
    (e) => e.operation,
    'operation',
    op,
  ),
);
Future<File> tempFile() async {
  final dir = await Directory.systemTemp.createTemp('review_draft_test_');
  addTearDown(() => dir.delete(recursive: true));
  return File('${dir.path}/review.sqlite');
}

class Probe extends GeneratedDatabase {
  Probe(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}

Future<void> mutate(File file, Future<void> Function(Probe) action) async {
  final db = Probe(NativeDatabase(file));
  try {
    await action(db);
  } finally {
    await db.close();
  }
}

void main() {
  test('reopen preserves raw incomplete/overlong text, entry dates, edit source identities and independently changed dates', () async {
    final file = await tempFile();
    final otherDate = CivilDate(year: 2027, month: 1, day: 1);
    final nextContext = ReviewDraftContext.newEntry(date: otherDate);
    final editA = ReviewDraftContext.edit(reviewId: ledgerId);
    final editB = ReviewDraftContext.edit(reviewId: secondLedgerId);
    final overlong = '  ${List.filled(2001, '🐾').join()}\n  保留内部  空格\n\n末段  ';
    final inputs = [
      draft(
        context,
        selected: otherDate,
        rawDate: ' 2027-01-01 ',
        summary: overlong,
        reflection: overlong,
        step: overlong,
        goal: ledgerId,
      ),
      draft(
        nextContext,
        rawDate: '2027-01-',
        summary: '',
        reflection: ' \n ',
        step: '',
      ),
      draft(
        editA,
        selected: otherDate,
        rawDate: '2027-01-01',
        summary: '编辑A',
        step: '  ',
      ),
      draft(editB, selected: date, reflection: '编辑B'),
    ];
    var store = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect(await store.read(context), isNull);
    for (final input in inputs) {
      await store.save(input);
    }
    await store.close();
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    for (final input in inputs) {
      expect(fields((await store.read(input.context))!), fields(input));
    }
    // 改后的日期不会变成新的草稿键，也不会占据另一个新建草稿。
    await store.save(
      draft(
        editA,
        selected: date,
        rawDate: '2026-10-02',
        summary: '再次改日期',
        goal: secondLedgerId,
      ),
    );
    await store.save(draft(context, rawDate: '不完整日期', summary: '另改新建日期'));
    expect((await store.read(editA))!.date, date);
    expect((await store.read(nextContext))!.dateInput, '2027-01-');
    expect((await store.read(editB))!.reflection, '编辑B');
    await store.clear(editA);
    await store.clear(editA);
    expect(await store.read(editA), isNull);
    expect((await store.read(context))!.summary, '另改新建日期');
    await store.close();
  });

  test('Goal select/replace/clear and null vs empty raw fields survive reopen without formal validation', () async {
    final file = await tempFile();
    var store = await DriftReviewDraftStore.open(NativeDatabase(file));
    for (final goal in [ledgerId, secondLedgerId, null]) {
      await store.save(
        draft(
          context,
          selected: date,
          summary: null,
          reflection: '',
          step: ' \n ',
          goal: goal,
        ),
      );
      await store.close();
      store = await DriftReviewDraftStore.open(NativeDatabase(file));
      final loaded = (await store.read(context))!;
      expect(loaded.tomorrowFirstStepGoalId, goal);
      expect(loaded.summary, isNull);
      expect(loaded.reflection, '');
      expect(loaded.tomorrowFirstStepText, ' \n ');
    }
    // 草稿空下一步合法，正式值对象仍拒绝。
    expect(
      () => TomorrowFirstStep(reviewDate: date, text: ' \n '),
      throwsArgumentError,
    );
    await store.close();
  });

  test('draft operations do not change populated formal five tables, schema, ordinary/sleep drafts or occupy review uniqueness', () async {
    final db = await AppDatabase.open(NativeDatabase.memory());
    addTearDown(db.close);
    await insertLedgerRow(db, 'goals', {
      'id': ledgerId,
      'name': '目标',
      'status': 'active',
      'created_at': 1,
      'updated_at': 1,
    });
    await insertLedgerRow(db, 'time_blocks', blockRow(start: 10, end: 20));
    await insertLedgerRow(db, 'sleep_sessions', sleepRow(start: 0, end: 10));
    await insertLedgerRow(db, 'rhythm_annotations', annotationRow());
    final reviews = DriftReviewRepository(db);
    await reviews.create(
      id: ledgerId,
      date: date,
      summary: '正式概述',
      reflection: '正式反思',
      tomorrowFirstStepText: '正式下一步',
      tomorrowFirstStepGoalId: ledgerId,
      now: 1,
    );
    Future<Object> facts() async => [
      for (final table in [
        'goals',
        'time_blocks',
        'sleep_sessions',
        'rhythm_annotations',
        'daily_reviews',
      ])
        (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
            .map((r) => r.data)
            .toList(),
    ];
    final before = await facts();
    final schema =
        (await db
                .customSelect(
                  "SELECT name, sql FROM sqlite_master WHERE type IN ('table','index') ORDER BY name",
                )
                .get())
            .map((r) => r.data)
            .toList();
    final ordinary = await DriftRecordingDraftStore.open(
      NativeDatabase.memory(),
    );
    final sleep = await DriftSleepDraftStore.open(NativeDatabase.memory());
    addTearDown(ordinary.close);
    addTearDown(sleep.close);
    final ordinaryContext = RecordingDraftContext.newEntry(date: date);
    final sleepContext = SleepDraftContext.newEntry(date: date);
    await ordinary.save(
      RecordingDraft(
        context: ordinaryContext,
        title: '普通草稿',
        startedAt: null,
        endedAt: null,
        startPrecision: TimePrecision.exact,
        endPrecision: TimePrecision.approximate,
        knowledgeState: null,
      ),
    );
    await sleep.save(
      SleepDraft(
        context: sleepContext,
        startedAt: null,
        endedAt: null,
        startPrecision: null,
        endPrecision: null,
        type: null,
        note: '睡眠草稿',
      ),
    );
    final file = await tempFile();
    final store = await DriftReviewDraftStore.open(NativeDatabase(file));
    final edit = ReviewDraftContext.edit(reviewId: ledgerId);
    final emptyDate = CivilDate(year: 2026, month: 10, day: 3);
    final newContext = ReviewDraftContext.newEntry(date: emptyDate);
    await store.save(draft(edit, selected: emptyDate, reflection: '未提交修改'));
    await store.save(draft(context, selected: date, step: ''));
    await store.save(draft(newContext, selected: emptyDate, step: ''));
    expect(await facts(), before);
    expect(
      (await db
              .customSelect(
                "SELECT name, sql FROM sqlite_master WHERE type IN ('table','index') ORDER BY name",
              )
              .get())
          .map((r) => r.data)
          .toList(),
      schema,
    );
    // 草稿允许与已有正式复盘同日；新建草稿也不妨碍同日正式创建。
    await reviews.create(
      id: secondLedgerId,
      date: emptyDate,
      tomorrowFirstStepText: '合法下一步',
      now: 2,
    );
    await reviews.delete(secondLedgerId);
    final ledger = await DriftLedgerRepository(db)
        .readWindow(startedAt: 0, endedAt: 30);
    expect(ledger.timeBlocks, hasLength(1));
    expect(ledger.sleepSessions, hasLength(1));
    for (final c in [edit, context, newContext]) {
      await store.clear(c);
    }
    expect(await facts(), before);
    expect((await ordinary.read(ordinaryContext))!.title, '普通草稿');
    expect((await sleep.read(sleepContext))!.note, '睡眠草稿');
    await store.close();
    await mutate(file, (probe) async {
      final names =
          (await probe
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
                  )
                  .get())
              .map((r) => r.read<String>('name'))
              .toList();
      expect(names, ['review_drafts']);
      final columns =
          (await probe.customSelect('PRAGMA table_info(review_drafts)').get())
              .map((r) => r.read<String>('name'));
      expect(columns, isNot(contains('intended_date')));
      expect(columns, isNot(contains('progress_minutes')));
    });
  });

  test('real AFTER INSERT/UPDATE/DELETE failures roll back; save and clear retries do not poison queued operations', () async {
    final file = await tempFile();
    var store = await DriftReviewDraftStore.open(NativeDatabase(file));
    final original = draft(
      context,
      selected: date,
      summary: '  原始\n ',
      reflection: '旧反思',
      step: '旧下一步',
      goal: ledgerId,
    );
    await store.save(original);
    await store.close();
    await mutate(file, (db) async {
      for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
        await db.customStatement(
          "CREATE TRIGGER fail_${action.toLowerCase()} AFTER $action ON review_drafts BEGIN SELECT RAISE(FAIL, 'injected'); END",
        );
      }
    });
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    final other = ReviewDraftContext.newEntry(
      date: CivilDate(year: 2026, month: 10, day: 3),
    );
    await expectLater(
      store.save(draft(other, step: '新草稿')),
      failure(ReviewDraftOperation.save),
    );
    await expectLater(
      store.save(draft(context, step: '覆盖')),
      failure(ReviewDraftOperation.save),
    );
    await expectLater(
      store.clear(context),
      failure(ReviewDraftOperation.clear),
    );
    expect(fields((await store.read(context))!), fields(original));
    expect(await store.read(other), isNull);
    await store.close();
    await mutate(file, (db) async {
      for (final action in ['insert', 'update', 'delete']) {
        await db.customStatement('DROP TRIGGER fail_$action');
      }
    });
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect(fields((await store.read(context))!), fields(original));
    // 不逐次 await 的写 / 清顺序及 close drain。
    final first = store.save(draft(context, summary: '第一版'));
    final second = store.save(draft(context, summary: '第二版'));
    final clear = store.clear(context);
    final finalSave = store.save(draft(context, summary: '最后一版'));
    final closing = store.close();
    await Future.wait([first, second, clear, finalSave, closing]);
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect((await store.read(context))!.summary, '最后一版');
    await store.clear(context);
    await store.close();
    store = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect(await store.read(context), isNull);
    await store.close();
  });

  test('read failure, closed operations, unusable path/version and close failure report correct operations', () async {
    final file = await tempFile();
    final trace = Faults();
    var store = await DriftReviewDraftStore.open(
      NativeDatabase(file).interceptWith(trace),
    );
    await store.save(draft(context, summary: '保留'));
    trace.failRead = true;
    await expectLater(store.read(context), failure(ReviewDraftOperation.read));
    trace.failRead = false;
    expect((await store.read(context))!.summary, '保留');
    await store.close();
    await store.close();
    await expectLater(store.read(context), failure(ReviewDraftOperation.read));
    await expectLater(
      store.save(draft(context)),
      failure(ReviewDraftOperation.save),
    );
    await expectLater(
      store.clear(context),
      failure(ReviewDraftOperation.clear),
    );
    await expectLater(
      DriftReviewDraftStore.open(NativeDatabase(File(file.parent.path))),
      failure(ReviewDraftOperation.open),
    );
    await mutate(file, (db) => db.customStatement('PRAGMA user_version = 2'));
    await expectLater(
      DriftReviewDraftStore.open(NativeDatabase(file)),
      failure(ReviewDraftOperation.open),
    );
    final closeFault = Faults()..failClose = true;
    store = await DriftReviewDraftStore.open(
      NativeDatabase.memory().interceptWith(closeFault),
    );
    await expectLater(store.close(), failure(ReviewDraftOperation.close));
  });

  test('malformed persisted rows raise data error and remain intact rather than becoming absent or defaulted', () async {
    for (final mutation in [
      'entry_month=13',
      'entry_day=NULL',
      'entry_year=NULL, entry_month=NULL, entry_day=NULL',
      "review_id='invalid'",
      'draft_year=2026, draft_month=2, draft_day=30',
      'draft_year=NULL, draft_month=1',
      "tomorrow_first_step_goal_id='invalid'",
      "entry_day=3",
      "summary=x'FF'",
      "date_input=x'FF'",
    ]) {
      final file = await tempFile();
      var store = await DriftReviewDraftStore.open(NativeDatabase(file));
      await store.save(draft(context, selected: date));
      await store.close();
      await mutate(
        file,
        (db) => db.customStatement('UPDATE review_drafts SET $mutation'),
      );
      store = await DriftReviewDraftStore.open(NativeDatabase(file));
      await expectLater(
        store.read(context),
        throwsA(isA<ReviewDraftDataException>()),
      );
      await store.close();
      await mutate(file, (db) async {
        expect(
          await db.customSelect('SELECT * FROM review_drafts').get(),
          hasLength(1),
        );
      });
    }
  });
}

class Faults extends QueryInterceptor {
  bool failRead = false;
  bool failClose = false;
  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String sql,
    List<Object?> args,
  ) {
    if (failRead && sql.contains('FROM review_drafts')) {
      throw StateError('private path');
    }
    return executor.runSelect(sql, args);
  }

  @override
  Future<void> close(QueryExecutor executor) async {
    await executor.close();
    if (failClose) throw StateError('close failure');
  }
}
