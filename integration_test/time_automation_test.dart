import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:time_pet_ledger/app/theme/home_theme.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/app/time/device_sleep_prediction_calendar.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/persistence/database_connection.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_time_prediction_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep/sleep_recording_page.dart';
import 'package:time_pet_ledger/features/ledger/presentation/sleep_form_controller.dart';

import 'support/schema_contract.dart' show clearSchemaRows;

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, int minute) =>
    DateTime(2027, 1, day, hour, minute).millisecondsSinceEpoch;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real storage reinitializes cross-year sleep then saves the chosen endpoint',
    (tester) async {
      final name = 'time04_${DateTime.now().microsecondsSinceEpoch}';
      final db = await AppDatabase.open(await connectDatabase(name));
      var drafts = await DriftSleepDraftStore.open(
        await connectDatabase('${name}_draft'),
      );
      SleepFormController? controller;
      final date = CivilDate(year: 2027, month: 1, day: 1);
      final context = SleepDraftContext.newEntry(date: date);
      final start = DateTime(2026, 12, 31, 23, 40).millisecondsSinceEpoch + 123;
      try {
        final repo = DriftLedgerRepository(db);
        await repo.createTimeBlock(
          id: id(1),
          startedAt: start - 3600000,
          endedAt: start,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.unknown,
          now: 1,
        );
        await repo.createSleepSession(
          id: id(2),
          startedAt: at(1, 8, 10),
          endedAt: at(1, 9, 0),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          type: SleepType.nap,
          now: 1,
        );
        final loader = RecordingLedgerLoader(
          repository: repo,
          resolveDate: resolveDeviceRecordingDate,
        );
        final ordinary = (await loader.loadTimeSuggestion(
          date: date,
          now: at(1, 12, 0),
        )) as DirectTimeSuggestion;
        expect(
          (ordinary.input.startedAt, ordinary.input.endedAt),
          (at(1, 9, 0), at(1, 12, 0)),
        );
        await drafts.save(
          SleepDraft(
            context: context,
            startedAt: at(1, 1, 0),
            endedAt: at(1, 2, 0),
            startPrecision: TimePrecision.approximate,
            endPrecision: TimePrecision.approximate,
            type: SleepType.mainSleep,
            note: '保留备注',
            noteProvided: true,
          ),
        );
        await drafts.close();
        drafts = await DriftSleepDraftStore.open(
          await connectDatabase('${name}_draft'),
        );
        final sleepLedger = SleepLedgerLoader(
          repository: repo,
          resolveDate: resolveDeviceRecordingDate,
        );
        controller = SleepFormController(
          context: context,
          store: drafts,
          loadPredictions: () => SleepTimePredictionLoader(
            repository: repo,
            resolveDate: resolveDeviceRecordingDate,
            calendar: const DeviceSleepPredictionCalendar(),
          ).load(date: date, now: at(1, 12, 0), learning: drafts),
          entrySaver: SleepEntrySaver(
            repository: repo,
            drafts: drafts,
            learning: drafts,
            offsetMinutes: const DeviceSleepPredictionCalendar().offsetMinutes,
            refresh: sleepLedger.load,
            newId: () => id(3),
            now: () => at(1, 12, 0),
          ),
        );
        await controller.initialize();
        await controller.flush();
        expect(
          (controller.startedAt, controller.endedAt),
          (start, at(1, 7, 40) + 123),
        );
        expect(controller.note, '保留备注');
        expect(controller.type, SleepType.mainSleep);
        final cached = (await drafts.read(context))!;
        expect((cached.startedAt, cached.endedAt), (start, at(1, 7, 40) + 123));

        await tester.pumpWidget(
          MaterialApp(
            theme: homeTheme,
            home: SleepRecordingPage(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2026年12月31日'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('sleep-end-time')),
        );
        await tester.tap(find.byKey(const ValueKey('sleep-end-time')));
        await tester.pumpAndSettle();
        expect(find.text('选择时分'), findsOneWidget);
        final wheels = tester
            .widgetList<ListWheelScrollView>(find.byType(ListWheelScrollView))
            .toList();
        (wheels[0].controller! as FixedExtentScrollController).jumpToItem(7);
        (wheels[1].controller! as FixedExtentScrollController).jumpToItem(20);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('time-picker-confirm')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(controller.endedAt, at(1, 7, 20) + 123);
        // 日期直接打开日历；确认日期保留刚选定的时分与另一端。
        await tester.ensureVisible(
          find.byKey(const ValueKey('sleep-end-date')),
        );
        await tester.tap(find.byKey(const ValueKey('sleep-end-date')));
        await tester.pumpAndSettle();
        expect(find.text('2027年1月'), findsOneWidget);
        expect(find.byType(ListWheelScrollView), findsNothing);
        await tester.tap(find.text('2').last);
        await tester.tap(find.byKey(const ValueKey('date-picker-confirm')));
        await tester.pumpAndSettle();
        expect(controller.endedAt, at(2, 7, 20) + 123);
        expect(controller.startedAt, start);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.byKey(const ValueKey('sleep-end-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1').last);
        await tester.tap(find.byKey(const ValueKey('date-picker-confirm')));
        await tester.pumpAndSettle();
        expect(
          (controller.startedAt, controller.endedAt),
          (start, at(1, 7, 20) + 123),
        );
        await controller.initialize();
        expect(controller.endedAt, at(1, 7, 20) + 123);
        expect(await controller.submit(), isNotNull);
        expect(await drafts.read(context), isNull);
        final saved = (await repo.readSleepSession(id(3)))!;
        expect((saved.startedAt, saved.endedAt), (start, at(1, 7, 20) + 123));
        expect(saved.note, '保留备注');
        final feedback = (await drafts.readSleepFeedback()).single;
        expect(feedback.sleepId, id(3));
        expect(feedback.origin.endedAt, at(1, 7, 40) + 123);
        expect(feedback.endedAt, at(1, 7, 20) + 123);
        expect(saved.startPrecision, TimePrecision.approximate);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller?.dispose();
        await controller?.flush();
        await drafts.clearAll();
        await drafts.close();
        await clearSchemaRows(db);
        await db.close();
      }
    },
  );
}
