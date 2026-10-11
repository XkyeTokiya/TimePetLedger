import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_repository.dart';

/// 完整应用的会话夹具：临时目录中的真实 SQLite 库。
class RouteApp {
  RouteApp(this.dir, this.db, this.recording, this.drafts, this.openings);

  final Directory dir;
  final AppDatabase db;
  final DriftRecordingDraftStore recording;
  final DriftReviewDraftStore drafts;
  final DriftSleepOpeningStore openings;
  DateTime clock = DateTime(2026, 10, 2, 12);
  DriftReviewRepository get reviews => DriftReviewRepository(db);

  static Future<RouteApp> open(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final app = (await t.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('review_routes_');
      final db = await AppDatabase.open(
        NativeDatabase(File('${dir.path}/facts.sqlite')),
      );
      final recording = await DriftRecordingDraftStore.open(
        NativeDatabase(File('${dir.path}/recording.sqlite')),
      );
      final drafts = await DriftReviewDraftStore.open(
        NativeDatabase(File('${dir.path}/review.sqlite')),
      );
      final openings = await DriftSleepOpeningStore.open(
        NativeDatabase.memory(),
      );
      await openings.claim(CivilDate(year: 2026, month: 10, day: 2));
      await openings.claim(CivilDate(year: 2026, month: 10, day: 3));
      return RouteApp(dir, db, recording, drafts, openings);
    }))!;
    addTearDown(() => app.close(t));
    return app;
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    var closed = false;
    late Future<void> pending;
    await t.runAsync(() async {
      pending = Future.wait([
        db.close(),
        recording.close(),
        drafts.close(),
        openings.close(),
      ]).then((_) => closed = true);
    });
    for (var i = 0; i < 100 && !closed; i++) {
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(closed, true, reason: 'Drain app-owned native close continuations.');
    await t.runAsync(() => pending);
    await t.runAsync(() => dir.delete(recursive: true));
  }
}
