import '../support/recording_fields.dart';
import '../support/root_navigation.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/legacy_input_stores.dart';

import 'package:time_pet_ledger/app/bootstrap/app_bootstrap.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_conflicts.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/rhythm_state.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_timeline.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form.dart';

import '../support/app_recording_navigation.dart' show show;
import 'recording_goal_flow_test.dart' show disposeApp, time;
import 'support/checked_sleep_opening.dart';

Future<void> tap(WidgetTester tester, Finder target) async {
  await show(tester, target);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

Future<void> textTap(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) return;
  await tap(tester, find.text(text));
}

void main() {
  for (final gap in [false, true]) {
    testWidgets(
      'bootstrap ${gap ? 'Gap/timeline' : 'ordinary/home'} routes save optional hint and edit/remove through the real repository',
      (tester) async {
        final db = (await tester.runAsync(
          () => AppDatabase.open(NativeDatabase.memory()),
        ))!;
        final drafts = (await tester.runAsync(
          () => DriftRecordingDraftStore.open(NativeDatabase.memory()),
        ))!;
        final repo = DriftLedgerRepository(db);
        await tester.pumpWidget(
          AppBootstrap(
            openDatabase: () async => db,
            openDrafts: () async => drafts,
            openSleepDrafts: emptyLegacySleepDrafts,
            openReviewDrafts: emptyLegacyReviewDrafts,
            openSleepOpenings: () =>
                openCheckedSleepOpening(DateTime(2026, 10, 1)),
            now: () => DateTime(2026, 10, 1, 12),
          ),
        );
        await tester.pumpAndSettle();
        if (gap) await textTap(tester, '打开日账本');
        await textTap(tester, gap ? '补一笔' : '记录活动');
        final context = tester
            .widget<RecordingForm>(find.byType(RecordingForm))
            .context;
        expect(
          context.entry,
          gap ? RecordingDraftEntry.gap : RecordingDraftEntry.ordinary,
        );
        await textTap(tester, '想不起来');
        if (!gap) {
          await time(tester, '开始时间', '2026-10-01 10:00');
          await time(tester, '结束时间', '2026-10-01 11:00');
        }
        await tap(tester, find.byKey(const ValueKey('rhythm-stuck')));
        await revealRecordingField(tester, 'continuation-hint');
        await tester.enterText(
          find.byKey(const ValueKey('continuation-hint')),
          '  下次看笔记\n🐾  ',
        );
        await textTap(tester, '返回');
        expect(
          (await tester.runAsync(() => drafts.read(context)))!.annotationIntent,
          RecordingAnnotationIntent.add,
        );
        expect(
          await tester.runAsync(
            () => db.customSelect('SELECT * FROM rhythm_annotations').get(),
          ),
          isEmpty,
        );
        await textTap(tester, gap ? '补一笔' : '记录活动');
        await textTap(tester, '保存到账本');
        final window = (await tester.runAsync(
          () => repo.readWindow(
            startedAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
            endedAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
          ),
        ))!;
        final block = window.timeBlocks.single;
        final factRow = (await tester.runAsync(
          () => db.customSelect('SELECT * FROM time_blocks').getSingle(),
        ))!.data;
        final source = (await tester.runAsync(
          () => repo.readTimeBlock(block.id),
        ))!;
        expect(source.annotation!.state, RhythmState.stuck);
        expect(source.annotation!.continuationHint, '下次看笔记\n🐾');
        expect(source.annotation!.stuckReasonCode, isNull);
        expect(block.goalId, isNull);
        Finder entry() => gap
            ? find.byKey(
                ValueKey((type: LedgerFactType.timeBlock, id: block.id)),
              )
            : recordingFact(block.id);
        await tap(tester, entry());
        await tap(tester, find.byKey(const ValueKey('rhythm-recovery')));
        await textTap(tester, '保存更正');
        final edited = (await tester.runAsync(
          () => repo.readTimeBlock(block.id),
        ))!;
        expect(edited.annotation!.id, source.annotation!.id);
        expect(edited.annotation!.state, RhythmState.recovery);
        expect(
          edited.annotation!.continuationHint,
          source.annotation!.continuationHint,
        );
        expect(
          (await tester.runAsync(
            () => db.customSelect('SELECT * FROM time_blocks').getSingle(),
          ))!.data,
          factRow,
        );
        await tap(tester, entry());
        await tap(tester, find.byKey(const ValueKey('rhythm-none')));
        await textTap(tester, '保存更正');
        final removed = (await tester.runAsync(
          () => repo.readTimeBlock(block.id),
        ))!;
        expect(removed.annotation, isNull);
        expect(
          (await tester.runAsync(
            () => db.customSelect('SELECT * FROM time_blocks').getSingle(),
          ))!.data,
          factRow,
        );
        if (gap) expect(find.byType(LedgerGapTimelineTile), findsNothing);
        expect(await tester.runAsync(() => drafts.read(context)), isNull);
        await disposeApp(tester);
      },
    );
  }
}
