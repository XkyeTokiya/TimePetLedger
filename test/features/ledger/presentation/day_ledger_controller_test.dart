import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/ledger/presentation/day_ledger_controller.dart';

DayLedgerFacts emptyFacts() => DayLedgerFacts(
  ledger: SleepLedgerSnapshot(
    windowFacts: LedgerSnapshot(
      timeBlocks: [],
      sleepSessions: [],
      annotations: [],
    ),
    sleepSummaryCandidates: [],
  ),
  goals: [],
);

void main() {
  test('latest date wins over stale success and stale failure; invalid input and disposal invalidate requests', () async {
    final requests = <Completer<DayLedgerFacts>>[];
    final controller = DayLedgerController(
      loader: DayLedgerLoader(
        resolveDate: resolveDeviceRecordingDate,
        readFacts: (_) {
          final pending = Completer<DayLedgerFacts>();
          requests.add(pending);
          return pending.future;
        },
      ),
      now: () => DateTime(2026, 9, 30, 12).millisecondsSinceEpoch,
      dateOfInstant: deviceDateOfInstant,
    );
    final old = controller.select(CivilDate(year: 2026, month: 9, day: 28));
    final latest = controller.select(CivilDate(year: 2026, month: 9, day: 29));
    expect(controller.status, DayLedgerStatus.loading);
    requests[1].complete(emptyFacts());
    await latest;
    expect(controller.view!.date.day, 29);
    requests[0].completeError(StateError('stale'));
    await old;
    expect(controller.status, DayLedgerStatus.empty);
    final staleSuccess = controller.refresh();
    final newSelection = controller.select(
      CivilDate(year: 2026, month: 10, day: 1),
    );
    requests[3].complete(emptyFacts());
    await newSelection;
    requests[2].complete(emptyFacts());
    await staleSuccess;
    expect(controller.view!.date.month, 10);
    expect(controller.view!.unresolvedSpans, isEmpty);
    final invalidated = controller.refresh();
    controller.invalidate();
    requests[4].complete(emptyFacts());
    await invalidated;
    expect(controller.status, DayLedgerStatus.idle);
    expect(controller.view, isNull);
    final disposed = controller.refresh();
    controller.dispose();
    requests[5].completeError(StateError('late failure'));
    await disposed;
  });

  test('failure retry and every refresh acquire new now and date context across midnight and timezone changes', () async {
    var instant = DateTime.utc(2026, 9, 30, 23, 59).millisecondsSinceEpoch;
    var offset = 0;
    var fail = true;
    final contexts = <RecordingDateContext>[];
    CivilDate dateOf(int value) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        value + offset * 3600000,
        isUtc: true,
      );
      return CivilDate(year: local.year, month: local.month, day: local.day);
    }

    final loader = DayLedgerLoader(
      resolveDate: ({required date, required now}) {
        final start =
            DateTime.utc(
              date.year,
              date.month,
              date.day,
            ).millisecondsSinceEpoch -
            offset * 3600000;
        final today = dateOf(now);
        final relation = date == today
            ? LedgerDateRelation.today
            : start < now
            ? LedgerDateRelation.historical
            : LedgerDateRelation.future;
        final context = RecordingDateContext(
          date: date,
          relation: relation,
          now: now,
          dayStartedAt: start,
          nextDayStartedAt: start + 86400000,
        );
        contexts.add(context);
        return context;
      },
      readFacts: (_) async {
        if (fail) throw StateError('storage detail');
        return emptyFacts();
      },
    );
    final controller = DayLedgerController(
      loader: loader,
      now: () => instant,
      dateOfInstant: dateOf,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.status, DayLedgerStatus.failed);
    expect(controller.view, isNull);
    fail = false;
    await controller.refresh();
    expect(controller.status, DayLedgerStatus.empty);
    expect(controller.date!.day, 30);
    instant = DateTime.utc(2026, 10, 1, 0, 1).millisecondsSinceEpoch;
    await controller.refresh();
    expect(controller.date!.day, 1);
    expect(controller.view!.window.milliseconds, 60000);
    offset = -4;
    await controller.refresh();
    expect(controller.date!.day, 30);
    expect(
      contexts.last.dayStartedAt,
      DateTime.utc(2026, 9, 30, 4).millisecondsSinceEpoch,
    );
    await controller.select(CivilDate(year: 2026, month: 9, day: 29));
    offset = 8;
    await controller.refresh();
    expect(controller.date!.day, 29);
    expect(
      contexts.last.dayStartedAt,
      DateTime.utc(2026, 9, 28, 16).millisecondsSinceEpoch,
    );
    expect(controller.view!.unresolvedDuration.milliseconds, 86400000);
  });
}
