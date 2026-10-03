import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/app/bootstrap/review_drafts.dart';
import 'package:time_pet_ledger/app/main_app.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';

import '../features/review/data/review_draft_store_test.dart'
    show context, date, draft, failure, Faults;
import 'support/checked_sleep_opening.dart';

void main() {
  test('unused session closes without opening; subsequent operations reject with their own operation', () async {
    var opens = 0;
    final session = ReviewDraftSession(
      openStore: () async {
        opens++;
        return DriftReviewDraftStore.open(NativeDatabase.memory());
      },
    );
    await session.close();
    expect(opens, 0);
    await expectLater(
      session.read(context),
      failure(ReviewDraftOperation.read),
    );
    await expectLater(
      session.save(draft(context)),
      failure(ReviewDraftOperation.save),
    );
    await expectLater(
      session.clear(context),
      failure(ReviewDraftOperation.clear),
    );
  });

  test('session open failure is explicit and retryable; queued calls share one successfully opened store', () async {
    final store = await DriftReviewDraftStore.open(NativeDatabase.memory());
    var attempts = 0;
    final session = ReviewDraftSession(
      openStore: () async {
        if (++attempts == 1) throw StateError('private opening path');
        return store;
      },
    );
    await expectLater(
      session.read(context),
      failure(ReviewDraftOperation.open),
    );
    final save = session.save(draft(context, summary: '重试输入'));
    final read = session.read(context);
    await save;
    expect((await read)!.summary, '重试输入');
    expect(attempts, 2);
    await session.clear(context);
    expect(await session.read(context), isNull);
    await session.close();
    await expectLater(store.read(context), failure(ReviewDraftOperation.read));
  });

  test('closing during delayed opening drains accepted operations before closing the real file', () async {
    final dir = await Directory.systemTemp.createTemp('review_session_close_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/drafts.sqlite');
    final store = await DriftReviewDraftStore.open(NativeDatabase(file));
    final pending = Completer<DriftReviewDraftStore>();
    final session = ReviewDraftSession(openStore: () => pending.future);
    final write = session.save(draft(context, summary: '关闭前保留'));
    final read = session.read(context);
    final closing = session.close();
    await expectLater(
      session.clear(context),
      failure(ReviewDraftOperation.clear),
    );
    pending.complete(store);
    await write;
    expect((await read)!.summary, '关闭前保留');
    await closing;
    await expectLater(store.read(context), failure(ReviewDraftOperation.read));
    final reopened = await DriftReviewDraftStore.open(NativeDatabase(file));
    expect((await reopened.read(context))!.summary, '关闭前保留');
    await reopened.close();
  });

  testWidgets(
    'bootstrap exposes lazy review store across rebuilds, closes it on disposal and restores raw input on file reopen',
    (t) async {
      final dir = (await t.runAsync(
        () => Directory.systemTemp.createTemp('review_draft_app_'),
      ))!;
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/drafts.sqlite');
      final db = (await t.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final reviewStore = (await t.runAsync(
        () => DriftReviewDraftStore.open(NativeDatabase(file)),
      ))!;
      var opens = 0;
      AppBootstrap app() => AppBootstrap(
        openDatabase: () async => db,
        openDrafts: () async => recording,
        openReviewDrafts: () {
          opens++;
          return Future.value(reviewStore);
        },
        openSleepOpenings: () => openCheckedSleepOpening(DateTime(2026, 10, 2)),
        now: () => DateTime(2026, 10, 2, 12),
      );
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      final dependency = t.widget<MainApp>(find.byType(MainApp)).reviewDrafts!;
      expect(opens, 0);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(
        identical(
          t.widget<MainApp>(find.byType(MainApp)).reviewDrafts,
          dependency,
        ),
        isTrue,
      );
      expect(opens, 0);
      await t.runAsync(
        () => dependency.save(
          draft(
            context,
            selected: date,
            summary: '  尚未完成\n ',
            step: '',
            rawDate: '2026-10-02',
          ),
        ),
      );
      await t.pump();
      expect(opens, 1);
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
        await expectLater(
          reviewStore.read(context),
          failure(ReviewDraftOperation.read),
        );
        final reopened = await DriftReviewDraftStore.open(NativeDatabase(file));
        expect((await reopened.read(context))!.summary, '  尚未完成\n ');
        expect((await reopened.read(context))!.tomorrowFirstStepText, '');
        await reopened.close();
      });
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'bootstrap reports review close failure through Flutter error handling',
    (t) async {
      final db = (await t.runAsync(
        () => AppDatabase.open(NativeDatabase.memory()),
      ))!;
      final recording = (await t.runAsync(
        () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
      ))!;
      final faults = Faults()..failClose = true;
      final store = (await t.runAsync(
        () => DriftReviewDraftStore.open(
          NativeDatabase.memory().interceptWith(faults),
        ),
      ))!;
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => recording,
          openReviewDrafts: () async => store,
          openSleepOpenings: () =>
              openCheckedSleepOpening(DateTime(2026, 10, 2)),
          now: () => DateTime(2026, 10, 2, 12),
        ),
      );
      await t.pumpAndSettle();
      final dependency = t.widget<MainApp>(find.byType(MainApp)).reviewDrafts!;
      await t.runAsync(
        () => dependency.save(draft(context, reflection: '未提交')),
      );
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
      expect(
        t.takeException(),
        isA<ReviewDraftStorageException>().having(
          (e) => e.operation,
          'operation',
          ReviewDraftOperation.close,
        ),
      );
    },
  );
}
