import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/day_ledger_view.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';
import 'package:time_pet_ledger/features/review/application/review_context_loader.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';
import 'package:time_pet_ledger/features/review/presentation/review_context_controller.dart';

ReviewContext contextFor(
  CivilDate date, {
  bool existing = false,
  int offset = 0,
}) {
  final start =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch -
      offset * 3600000;
  return ReviewContext(
    ledger: projectDayLedgerView(
      date: date,
      relation: LedgerDateRelation.historical,
      dayStartedAt: start,
      nextDayStartedAt:
          DateTime.utc(
            date.year,
            date.month,
            date.day + 1,
          ).millisecondsSinceEpoch -
          offset * 3600000,
      now: DateTime.utc(2027).millisecondsSinceEpoch,
      timeBlocks: [],
      windowSleepSessions: [],
      annotations: [],
      sleepSummaryCandidates: [],
      goals: [],
    ),
    review: existing
        ? DailyReview(
            id: '00000000-0000-4000-8000-000000000001',
            date: date,
            tomorrowFirstStep: TomorrowFirstStep(
              reviewDate: date,
              text: '用户下一步',
            ),
            createdAt: 1,
            updatedAt: 2,
          )
        : null,
    firstStepGoal: null,
  );
}

void main() {
  final date = CivilDate(year: 2025, month: 12, day: 31);
  test(
    'latest date wins over old success/failure, invalid input and disposal',
    () async {
      final requests =
          <({CivilDate date, Completer<ReviewContext> response})>[];
      final controller = ReviewContextController(
        loader: ReviewContextLoader(
          readContext: ({required date, required now}) {
            final response = Completer<ReviewContext>();
            requests.add((date: date, response: response));
            return response.future;
          },
        ),
        now: () => 1,
        dateOfInstant: deviceDateOfInstant,
        selectedDate: date,
      );
      final old = controller.refresh();
      final latest = controller.select(CivilDate(year: 2026, month: 1, day: 1));
      requests[1].response.complete(
        contextFor(requests[1].date, existing: true),
      );
      await latest;
      requests[0].response.complete(contextFor(date));
      await old;
      expect(controller.status, ReviewReadStatus.ready);
      expect(controller.context!.review!.date, requests[1].date);
      final staleError = controller.refresh();
      final retry = controller.select(date);
      expect(controller.context, isNull);
      requests[3].response.complete(contextFor(date));
      await retry;
      requests[2].response.completeError(StateError('old failure'));
      await staleError;
      expect(controller.status, ReviewReadStatus.absent);
      final invalid = controller.refresh();
      controller.invalidate();
      requests[4].response.complete(contextFor(date, existing: true));
      await invalid;
      expect(controller.status, ReviewReadStatus.idle);
      expect(controller.context, isNull);
      final disposed = controller.refresh();
      controller.dispose();
      requests[5].response.completeError(StateError('disposed'));
      await disposed;
    },
  );

  test('failure retry, midnight and simulated timezone change preserve selected stored date and next day', () async {
    var fail = true;
    var now = DateTime.utc(2026, 10, 2, 23, 59).millisecondsSinceEpoch;
    var offset = 0;
    final instants = <int>[];
    CivilDate deviceDate(int value) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        value + offset * 3600000,
        isUtc: true,
      );
      return CivilDate(year: local.year, month: local.month, day: local.day);
    }

    final controller = ReviewContextController(
      loader: ReviewContextLoader(
        readContext: ({required date, required now}) async {
          instants.add(now);
          if (fail) throw StateError('read failure');
          return contextFor(date, existing: true, offset: offset);
        },
      ),
      now: () => now,
      dateOfInstant: deviceDate,
      selectedDate: date,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.status, ReviewReadStatus.failed);
    expect(controller.context, isNull);
    fail = false;
    await controller.refresh();
    final before = controller.context!;
    now += 120000;
    offset = 8;
    await controller.refresh();
    expect(instants.last, now);
    expect(controller.selectedDate, date);
    expect(controller.context!.review!.date, date);
    expect(
      controller.context!.review!.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2026, month: 1, day: 1),
    );
    expect(
      controller.context!.ledger.window.startedAt,
      before.ledger.window.startedAt - 8 * 3600000,
    );
    await controller.selectToday();
    expect(controller.selectedDate, CivilDate(year: 2026, month: 10, day: 3));
  });
}
