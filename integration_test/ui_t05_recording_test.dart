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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'UI-T05 actual Android keyboard, back, retained draft and edit instance',
    (t) async {
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
        final reviews = await DriftReviewDraftStore.open(
          NativeDatabase.memory(),
        );
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
            'UI_T05_STEP ${jsonEncode({'name': name, if (point != null) 'x': point.dx.round(), if (point != null) 'y': point.dy.round()})}',
          );
        }

        final create = find.byKey(const ValueKey('root-create'));
        final activity = find.byKey(const ValueKey('activity'));
        final note = find.byKey(const ValueKey('note'));
        await wait(
          () =>
              create.evaluate().isNotEmpty &&
              find.text('日账本已读取。').evaluate().isNotEmpty,
        );
        step('create', create);
        await wait(() => find.text('记录活动').evaluate().isNotEmpty);
        step('activity', find.text('记录活动'));
        await wait(() => activity.evaluate().isNotEmpty);
        final formState = t.state(find.byType(RecordingForm));
        final model = (formState as dynamic).model;
        expect(create, findsNothing);
        expect(find.text('修改时间'), findsOneWidget);
        expect(find.text('开始时间'), findsNothing);
        expect(t.view.viewInsets.bottom, 0);
        expect(t.widget<TextField>(activity).focusNode!.hasFocus, isFalse);
        step('input', activity);
        await wait(
          () =>
              t.widget<TextField>(activity).controller!.text == '123456' &&
              t.view.viewInsets.bottom > 0,
        );
        step('keyboard_back');
        await wait(() => t.view.viewInsets.bottom == 0);
        expect(t.state(find.byType(RecordingForm)), same(formState));
        final noteToggle = find.byKey(const ValueKey('recording-note-toggle'));
        await t.ensureVisible(noteToggle);
        await t.pumpAndSettle();
        step('open_note', noteToggle);
        await wait(() => note.evaluate().isNotEmpty);
        await t.ensureVisible(note);
        await t.pumpAndSettle();
        step('note_input', note);
        await wait(
          () =>
              t.widget<TextField>(note).controller!.text == '987654' &&
              t.view.viewInsets.bottom > 0,
        );
        final save = find.byKey(const ValueKey('recording-submit'));
        await Scrollable.ensureVisible(t.element(save), alignment: .5);
        await t.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        final availableBottom =
            (t.view.physicalSize.height - t.view.viewInsets.bottom) /
            t.view.devicePixelRatio;
        expect(t.getRect(save).bottom, lessThanOrEqualTo(availableBottom));
        step('save_above_keyboard');
        // The host captures the real IME and then presses system Back.
        await wait(() => t.view.viewInsets.bottom == 0);
        final leave = find.text('保留草稿并返回');
        await t.ensureVisible(leave);
        await t.pumpAndSettle();
        step('retain_and_return', leave);
        await wait(() => create.evaluate().isNotEmpty);
        final context = RecordingDraftContext.newEntry(date: date);
        expect((await drafts.read(context))!.title, '123456');
        expect((await drafts.read(context))!.note, '987654');
        expect(
          (await repo.readWindow(
            startedAt: DateTime(2026, 10, 3).millisecondsSinceEpoch,
            endedAt: DateTime(2026, 10, 4).millisecondsSinceEpoch,
          )).timeBlocks.length,
          1,
        );
        step('reopen_create', create);
        await wait(() => find.text('记录活动').evaluate().isNotEmpty);
        step('reopen_activity', find.text('记录活动'));
        await wait(() => find.text('已恢复上次输入').evaluate().isNotEmpty);
        expect(note, findsOneWidget);
        expect(t.widget<TextField>(note).controller!.text, '987654');
        expect(t.view.viewInsets.bottom, 0);
        final restoredState = t.state(find.byType(RecordingForm));
        final restoredModel = (restoredState as dynamic).model;
        expect(restoredModel, isNot(same(model)));
        final portrait = t.view.physicalSize;
        step('rotate_landscape');
        await wait(
          () => t.view.physicalSize.width > t.view.physicalSize.height,
        );
        expect(t.state(find.byType(RecordingForm)), same(restoredState));
        expect(
          (t.state(find.byType(RecordingForm)) as dynamic).model,
          same(restoredModel),
        );
        expect(t.widget<TextField>(activity).controller!.text, '123456');
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        step('restore_portrait');
        await wait(() => t.view.physicalSize == portrait);
        expect(
          (t.state(find.byType(RecordingForm)) as dynamic).model,
          same(restoredModel),
        );
        expect(t.widget<TextField>(note).controller!.text, '987654');
        step('form_back');
        await wait(() => create.evaluate().isNotEmpty);
        expect(find.text('日期：2026-10-03'), findsOneWidget);
        expect(find.text('确认主睡眠'), findsNothing);
        expect((await drafts.read(context))!.note, '987654');
        step('finished');
        await Future<void>.delayed(const Duration(seconds: 2));
        await t.pumpWidget(const SizedBox.shrink());
        debugPrint('UI-T05 Android actual keyboard/back/rotation passed');
      } finally {
        t.binding.shouldPropagateDevicePointerEvents = false;
      }
    },
  );
}
