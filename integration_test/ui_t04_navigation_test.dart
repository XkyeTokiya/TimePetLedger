import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_opening_store.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';
import 'package:time_pet_ledger/features/review/data/drift_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UI-T04 actual Android input, system back, flush and rotation', (
    t,
  ) async {
    t.binding.shouldPropagateDevicePointerEvents = true;
    try {
      final date = CivilDate(year: 2026, month: 10, day: 3);
      final db = await AppDatabase.open(NativeDatabase.memory());
      final drafts = await DriftRecordingDraftStore.open(
        NativeDatabase.memory(),
      );
      final sleepDrafts = await DriftSleepDraftStore.open(
        NativeDatabase.memory(),
      );
      final reviews = await DriftReviewDraftStore.open(NativeDatabase.memory());
      final openings = await DriftSleepOpeningStore.open(
        NativeDatabase.memory(),
      );
      await openings.claim(date);
      final repo = DriftLedgerRepository(db);
      await repo.createTimeBlock(
        id: '00000000-0000-4000-8000-000000000101',
        startedAt: DateTime(2026, 10, 3, 8).millisecondsSinceEpoch,
        endedAt: DateTime(2026, 10, 3, 9).millisecondsSinceEpoch,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.exact,
        knowledgeState: BlockKnowledgeState.known,
        title: '已有活动🐾\n实际 Android 导航验证',
        now: 1,
      );
      await t.pumpWidget(
        AppBootstrap(
          openDatabase: () async => db,
          openDrafts: () async => drafts,
          openSleepDrafts: () async => sleepDrafts,
          openReviewDrafts: () async => reviews,
          openSleepOpenings: () async => openings,
          now: () => DateTime(2026, 10, 3, 12),
        ),
      );
      Future<void> wait(bool Function() condition) async {
        for (var i = 0; i < 900; i++) {
          await t.pump(const Duration(milliseconds: 100));
          if (condition()) {
            await t.pump(const Duration(milliseconds: 400));
            return;
          }
        }
        throw StateError(
          'Android driver did not complete the expected action.',
        );
      }

      void step(String name, [Finder? target]) {
        final point = target == null
            ? null
            : t.getCenter(target) * t.view.devicePixelRatio;
        debugPrint(
          'UI_T04_STEP ${jsonEncode({'name': name, if (point != null) 'x': point.dx.round(), if (point != null) 'y': point.dy.round()})}',
        );
      }

      final create = find.byKey(const ValueKey('root-create'));
      await wait(
        () =>
            create.evaluate().isNotEmpty &&
            find.text('日账本已读取。').evaluate().isNotEmpty,
      );
      step('portrait_create', create);
      await wait(() => find.text('记录活动').evaluate().isNotEmpty);
      expect(find.byType(RecordingForm), findsNothing);
      step('cancel_creation');
      await wait(() => find.text('记录活动').evaluate().isEmpty);
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      step('review', find.byKey(const ValueKey('root-复盘')));
      await wait(
        () =>
            find.byType(ReviewContextPage).evaluate().isNotEmpty &&
            find.text('这一天尚无复盘。').evaluate().isNotEmpty,
      );
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      step('back_to_ledger');
      await wait(() => find.text('日账本').evaluate().isNotEmpty);
      step('more', find.byTooltip('更多'));
      await wait(() => find.text('当日摘要').evaluate().isNotEmpty);
      step('summary', find.text('当日摘要'));
      await wait(
        () =>
            find.text('基础摘要').evaluate().isNotEmpty &&
            find.text('摘要已读取。').evaluate().isNotEmpty,
      );
      expect(create, findsNothing);
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      step('summary_back');
      await wait(() => create.evaluate().isNotEmpty);
      step('create_activity', create);
      await wait(() => find.text('记录活动').evaluate().isNotEmpty);
      step('activity', find.text('记录活动'));
      await wait(() => find.byType(RecordingForm).evaluate().isNotEmpty);
      final formState = t.state(find.byType(RecordingForm));
      expect(create, findsNothing);
      final activity = find.byKey(const ValueKey('activity'));
      await t.ensureVisible(activity);
      await t.pumpAndSettle();
      step('input', activity);
      await wait(
        () =>
            t.widget<TextField>(activity).controller!.text == '123456' &&
            t.view.viewInsets.bottom > 0,
      );
      step('keyboard_back');
      await wait(() => t.view.viewInsets.bottom == 0);
      expect(t.state(find.byType(RecordingForm)), same(formState));
      expect(t.widget<TextField>(activity).controller!.text, '123456');
      step('form_back');
      await wait(() => create.evaluate().isNotEmpty);
      expect(
        (await drafts.read(RecordingDraftContext.newEntry(date: date)))!.title,
        '123456',
      );
      expect(
        (await repo.readWindow(
          startedAt: DateTime(2026, 10, 3).millisecondsSinceEpoch,
          endedAt: DateTime(2026, 10, 4).millisecondsSinceEpoch,
        )).timeBlocks.length,
        1,
      );
      final portrait = t.view.physicalSize;
      step('rotate_landscape');
      await wait(() => t.view.physicalSize.width > t.view.physicalSize.height);
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      expect(find.text('确认主睡眠'), findsNothing);
      expect(create.hitTestable(), findsOneWidget);
      step('restore_portrait');
      await wait(() => t.view.physicalSize == portrait);
      expect(find.text('日期：2026-10-03'), findsOneWidget);
      step('finished');
      await Future<void>.delayed(const Duration(seconds: 2));
      await t.pumpWidget(const SizedBox.shrink());
      debugPrint('UI-T04 Android actual input/back/rotation passed');
    } finally {
      t.binding.shouldPropagateDevicePointerEvents = false;
    }
  });
}
