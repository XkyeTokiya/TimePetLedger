import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';

CivilDate date(int year, int month, int day) =>
    CivilDate(year: year, month: month, day: day);

void main() {
  test('historical, today, future and midnight use explicit local now', () {
    final midnight = DateTime(2026, 9, 28).millisecondsSinceEpoch;
    final now = midnight + 1234567;
    final today = resolveDeviceRecordingDate(date: date(2026, 9, 28), now: now);
    expect(today.relation, LedgerDateRelation.today);
    expect(today.now, now);
    expect(today.window.startedAt, midnight);
    expect(today.window.endedAt, now);
    final past = resolveDeviceRecordingDate(date: date(2026, 9, 27), now: now);
    expect(past.relation, LedgerDateRelation.historical);
    expect(past.window.startedAt, DateTime(2026, 9, 27).millisecondsSinceEpoch);
    expect(past.window.endedAt, midnight);
    final future = resolveDeviceRecordingDate(
      date: date(2026, 9, 29),
      now: now,
    );
    expect(future.relation, LedgerDateRelation.future);
    expect(future.window.isEmpty, isTrue);
    expect(
      future.window.startedAt,
      DateTime(2026, 9, 29).millisecondsSinceEpoch,
    );
    expect(
      resolveDeviceRecordingDate(
        date: date(2026, 9, 28),
        now: midnight,
      ).window.isEmpty,
      isTrue,
    );
  });

  test('calendar rollover handles leap day and year boundary', () {
    for (final pair in [
      (date(2024, 2, 29), DateTime(2024, 3, 1)),
      (date(2025, 12, 31), DateTime(2026, 1, 1)),
    ]) {
      final result = resolveDeviceRecordingDate(
        date: pair.$1,
        now: DateTime(2026, 9, 28).millisecondsSinceEpoch,
      );
      expect(result.window.endedAt, pair.$2.millisecondsSinceEpoch);
    }
  });

  final zone = Platform.environment['TZ'];
  test('device timezone controls absolute boundaries and local today', () {
    final now = DateTime.utc(2026, 9, 28, 2).millisecondsSinceEpoch;
    final result = resolveDeviceRecordingDate(
      date: date(2026, 9, 28),
      now: now,
    );
    if (zone == 'America/New_York') {
      expect(result.relation, LedgerDateRelation.future);
      expect(
        result.window.startedAt,
        DateTime.utc(2026, 9, 28, 4).millisecondsSinceEpoch,
      );
    } else {
      expect(result.relation, LedgerDateRelation.today);
      expect(
        result.window.startedAt,
        DateTime.utc(2026, 9, 27, 16).millisecondsSinceEpoch,
      );
    }
  }, skip: zone != 'America/New_York' && zone != 'Asia/Shanghai');

  test('real device calendar resolves spring 23h and autumn 25h days', () {
    final now = DateTime.utc(2026, 12, 1).millisecondsSinceEpoch;
    for (final sample in [(3, 8, 23), (11, 1, 25)]) {
      final result = resolveDeviceRecordingDate(
        date: date(2026, sample.$1, sample.$2),
        now: now,
      );
      final hours = zone == 'America/New_York' ? sample.$3 : 24;
      expect(result.window.milliseconds, Duration(hours: hours).inMilliseconds);
      final end = DateTime.fromMillisecondsSinceEpoch(result.window.endedAt);
      expect((end.month, end.day, end.hour), (sample.$1, sample.$2 + 1, 0));
    }
  }, skip: zone != 'America/New_York' && zone != 'Asia/Shanghai');
}
