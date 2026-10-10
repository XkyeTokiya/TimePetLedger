import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/day_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/presentation/home/ledger_feed_controller.dart';

final day1 = CivilDate(year: 2026, month: 10, day: 1);
final day2 = CivilDate(year: 2026, month: 10, day: 2);
final day3 = CivilDate(year: 2026, month: 10, day: 3);
final day4 = CivilDate(year: 2026, month: 10, day: 4);

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

LedgerFeedController feedWith(
  Future<DayLedgerFacts> Function(RecordingDateContext) read, {
  int windowDays = 1,
  int Function()? clock,
}) => LedgerFeedController(
  loader: DayLedgerLoader(
    resolveDate: resolveDeviceRecordingDate,
    readFacts: read,
  ),
  now: clock ?? () => DateTime(2026, 10, 3, 12).millisecondsSinceEpoch,
  dateOfInstant: deviceDateOfInstant,
  initialDate: day2,
  windowDays: windowDays,
);

void main() {
  test(
    'selected future date is a temporary upper bound until today succeeds',
    () async {
      var fail = false;
      final feed = feedWith((_) async {
        if (fail) throw StateError('unavailable');
        return emptyFacts();
      });
      addTearDown(feed.dispose);
      expect(await feed.showDate(day2), isTrue);
      expect(feed.navigationLimit(day2), day2);
      expect(feed.canNavigateTo(day3, day2), isFalse);

      fail = true;
      expect(await feed.showSelectedDate(day3, today: day2), isFalse);
      expect(feed.futureNavigationLimit, isNull);
      expect(feed.navigationLimit(day2), day2);

      fail = false;
      expect(await feed.showSelectedDate(day3, today: day2), isTrue);
      expect(feed.futureNavigationLimit, day3);
      expect(feed.canNavigateTo(day3, day2), isTrue);
      expect(feed.canNavigateTo(day4, day2), isFalse);

      fail = true;
      expect(await feed.returnToToday(day2), isFalse);
      expect(feed.focusDate, day3);
      expect(feed.futureNavigationLimit, day3);

      fail = false;
      expect(await feed.returnToToday(day2), isTrue);
      expect(feed.focusDate, day2);
      expect(feed.futureNavigationLimit, isNull);
      expect(feed.navigationLimit(day2), day2);
    },
  );

  test(
    'exiting frame retains its committed projection after a new date loads',
    () async {
      final feed = feedWith((_) async => emptyFacts());
      addTearDown(feed.dispose);
      await feed.showDate(day2);
      final frame = feed.captureFrame();
      final view = frame.viewFor(day2);
      await feed.showDate(day1);
      expect(frame.endDate, day2);
      expect(frame.focusDate, day2);
      expect(frame.dates, [day2]);
      expect(frame.viewFor(day2), same(view));
      expect(frame.viewFor(day1), isNull);
      expect(feed.focusDate, day1);
      expect(() => frame.dates.clear(), throwsUnsupportedError);
    },
  );

  test(
    'date, window, view and reveal commit together; failed jump retries target',
    () async {
      var fail = false;
      final requested = <CivilDate>[];
      final feed = feedWith((context) async {
        requested.add(context.window.date);
        if (fail) throw StateError('unavailable');
        return emptyFacts();
      });
      addTearDown(feed.dispose);
      expect(await feed.showDate(day2), isTrue);
      expect(feed.takeRevealRequest(), day2);
      final oldView = feed.focusView;
      final oldContext = feed.focusContext;
      final version = feed.dataVersion;
      fail = true;
      final pending = feed.showDate(day1);
      expect(feed.focusDate, day2);
      expect(feed.startDate, day2);
      expect(feed.endDate, day2);
      expect(feed.navigationDate, day1);
      expect(await pending, isFalse);
      expect(feed.status, LedgerFeedStatus.ready);
      expect(feed.refreshFailed, isTrue);
      expect(feed.focusView, same(oldView));
      expect(feed.focusContext, same(oldContext));
      expect(feed.loadedDates, [day2]);
      expect(feed.navigationDate, day2);
      expect(feed.dataVersion, version);
      expect(feed.takeRevealRequest(), isNull);

      fail = false;
      expect(await feed.refresh(), isTrue);
      expect(requested, [day2, day1, day1]);
      expect(feed.focusDate, day1);
      expect(feed.startDate, day1);
      expect(feed.endDate, day1);
      expect(feed.focusView!.date, day1);
      expect(feed.focusContext!.window.date, day1);
      expect(feed.refreshFailed, isFalse);
      expect(feed.dataVersion, version + 1);
      expect(feed.takeRevealRequest(), day1);
    },
  );

  test(
    'latest date wins over stale success and failure; disposal cancels commit',
    () async {
      final requests = <Completer<DayLedgerFacts>>[];
      final feed = feedWith((_) {
        final pending = Completer<DayLedgerFacts>();
        requests.add(pending);
        return pending.future;
      });
      final old = feed.showDate(day1);
      final latest = feed.showDate(day3);
      expect(feed.navigationDate, day3);
      requests[1].complete(emptyFacts());
      expect(await latest, isTrue);
      requests[0].completeError(StateError('stale'));
      expect(await old, isFalse);
      expect(feed.focusDate, day3);
      expect(feed.loadedDates, [day3]);
      expect(feed.refreshFailed, isFalse);

      final staleSuccess = feed.showDate(day1);
      final selection = feed.showDate(day2);
      requests[3].complete(emptyFacts());
      expect(await selection, isTrue);
      requests[2].complete(emptyFacts());
      expect(await staleSuccess, isFalse);
      expect(feed.focusDate, day2);
      expect(feed.focusView!.date, day2);
      final disposed = feed.refresh();
      feed.dispose();
      requests[4].completeError(StateError('late failure'));
      expect(await disposed, isFalse);
      expect(await feed.showDate(day1), isFalse);
      expect(requests, hasLength(5));
    },
  );

  test(
    'first load failure is distinct from successfully loaded empty day',
    () async {
      var fail = true;
      final feed = feedWith((_) async {
        if (fail) throw StateError('storage unavailable');
        return emptyFacts();
      });
      addTearDown(feed.dispose);
      expect(await feed.showDate(day2), isFalse);
      expect(feed.status, LedgerFeedStatus.failed);
      expect(feed.focusView, isNull);
      expect(feed.focusContext, isNull);
      expect(feed.dataVersion, 0);
      fail = false;
      expect(await feed.refresh(), isTrue);
      expect(feed.status, LedgerFeedStatus.ready);
      expect(feed.focusView, isNotNull);
      expect(feed.focusContext!.window.date, day2);
      expect(feed.dataVersion, 1);
    },
  );

  test('failed refresh keeps browsing focus and historical window', () async {
    var fail = false;
    final feed = feedWith((_) async {
      if (fail) throw StateError('unavailable');
      return emptyFacts();
    }, windowDays: 2);
    addTearDown(feed.dispose);
    await feed.showDate(day2);
    feed.takeRevealRequest();
    feed.noteFocus(day1);
    final view = feed.focusView;
    fail = true;
    expect(await feed.refresh(), isFalse);
    expect(feed.focusDate, day1);
    expect(feed.loadedDates, [day1, day2]);
    expect(feed.focusView, same(view));
    fail = false;
    expect(await feed.refresh(), isTrue);
    expect(feed.focusDate, day1);
    expect(feed.loadedDates, [day1, day2]);
    expect(feed.takeRevealRequest(), isNull);
  });

  test(
    'all days share captured now and extension cannot cancel a date jump',
    () async {
      var clock = DateTime(2026, 10, 3, 12).millisecondsSinceEpoch;
      final captured = clock;
      final contexts = <RecordingDateContext>[];
      final feed = feedWith(
        (context) async {
          contexts.add(context);
          clock += 60000;
          return emptyFacts();
        },
        windowDays: 2,
        clock: () => clock,
      );
      addTearDown(feed.dispose);
      final load = feed.showDate(day3);
      await feed.extendEarlier();
      expect(await load, isTrue);
      expect(contexts, hasLength(2));
      expect(contexts.map((context) => context.now), everyElement(captured));
      expect(feed.focusDate, day3);
      expect(feed.loadedDates, [day2, day3]);
    },
  );

  test('a failed date jump does not block extending earlier', () async {
    var fail = false;
    final feed = feedWith((_) async {
      if (fail) throw StateError('unavailable');
      return emptyFacts();
    }, windowDays: 2);
    addTearDown(feed.dispose);
    expect(await feed.showDate(day2), isTrue);
    final loadedBefore = feed.loadedDates.length;

    fail = true;
    expect(await feed.showDate(day3), isFalse);
    fail = false;
    // 失败跳转保留待重试目标（refresh 仍会重发），但不得阻塞向前装载。
    expect(await feed.extendEarlier(), isTrue);
    expect(feed.loadedDates.length, greaterThan(loadedBefore));

    expect(await feed.refresh(), isTrue);
    expect(feed.focusDate, day3);
  });

  test(
    'extending later loads toward today without moving the window anchor',
    () async {
      final feed = feedWith((_) async => emptyFacts(), windowDays: 2);
      addTearDown(feed.dispose);
      expect(await feed.showDate(day2), isTrue);
      expect(feed.loadedDates, [day1, day2]);
      expect(feed.endDate, day2);
      expect(feed.focusDate, day2);

      // 跳到过去日期后：向下滚动可继续装载到上限（今天），不越过。
      expect(await feed.extendLater(day4), isTrue);
      expect(feed.loadedDates, [day1, day2, day3, day4]);
      expect(feed.endDate, day2);
      expect(feed.focusDate, day2);
      expect(feed.contains(day4), isTrue);

      // 已在上限：不再装载。
      expect(await feed.extendLater(day4), isFalse);

      // 失败可重试，不改变锚点与浏览日期。
      var fail = false;
      final retry = feedWith((_) async {
        if (fail) throw StateError('unavailable');
        return emptyFacts();
      }, windowDays: 1);
      addTearDown(retry.dispose);
      expect(await retry.showDate(day1), isTrue);
      fail = true;
      expect(await retry.extendLater(day3), isFalse);
      expect(retry.refreshFailed, isTrue);
      expect(retry.endDate, day1);
      fail = false;
      expect(await retry.extendLater(day3), isTrue);
      expect(retry.loadedDates, [day1, day2, day3]);
    },
  );

  test('later extension stops at a selected future limit', () async {
    final feed = feedWith((_) async => emptyFacts(), windowDays: 1);
    addTearDown(feed.dispose);
    expect(await feed.showSelectedDate(day3, today: day1), isTrue);
    expect(feed.loadedDates, [day3]);
    expect(await feed.extendLater(day1), isFalse);
    expect(feed.loadedDates, [day3]);
    expect(feed.endDate, day3);
  });
}
