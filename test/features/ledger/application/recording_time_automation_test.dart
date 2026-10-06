import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/app/time/device_recording_date.dart';
import 'package:time_pet_ledger/app/time/device_sleep_prediction_calendar.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_entry_saver.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_ledger_loader.dart';
import 'package:time_pet_ledger/features/ledger/application/recording_time_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/application/sleep_time_prediction_loader.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/data/drift_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/ledger_repository.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/ledger/presentation/recording_form_controller.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
int at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute).millisecondsSinceEpoch;
final today = CivilDate(year: 2026, month: 10, day: 7);
void main() {
  late AppDatabase db;
  late DriftLedgerRepository repo;
  late RecordingLedgerLoader loader;
  setUp(() async {
    db = await AppDatabase.open(NativeDatabase.memory());
    repo = DriftLedgerRepository(db);
    loader = RecordingLedgerLoader(
      repository: repo,
      resolveDate: resolveDeviceRecordingDate,
    );
  });
  tearDown(() => db.close());
  Future<void> block(int n, int start, int end, {bool unknown = false}) async {
    await repo.createTimeBlock(
      id: id(n),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      knowledgeState: unknown
          ? BlockKnowledgeState.unknown
          : BlockKnowledgeState.known,
      title: unknown ? null : '活动',
      now: 1,
    );
  }

  Future<void> sleep(
    int n,
    int start,
    int end, {
    SleepType type = SleepType.nap,
  }) async {
    await repo.createSleepSession(
      id: id(n),
      startedAt: start,
      endedAt: end,
      startPrecision: TimePrecision.approximate,
      endPrecision: TimePrecision.approximate,
      type: type,
      now: 1,
    );
  }

  void expectTimes(RecordingTimeSuggestion value, int start, int end) {
    final input = (value as DirectTimeSuggestion).input;
    expect((input.startedAt, input.endedAt), (start, end));
    expect(input.startPrecision, TimePrecision.approximate);
    expect(input.endPrecision, TimePrecision.approximate);
  }

  test(
    'closed overnight gap takes real boundaries beyond the day slice',
    () async {
      await block(1, at(6, 22), at(6, 23, 40));
      await block(2, at(7, 8, 10), at(7, 9));
      final view = await loader.load(date: today, now: at(7, 12));
      final gap = view.coverage.unresolvedSpans.first;
      expect(gap.startedAt, at(7, 0));
      expectTimes(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 12),
          explicitGap: gap,
        ),
        at(6, 23, 40),
        at(7, 8, 10),
      );
      expectTimes(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 12),
          preferClosedGaps: true,
        ),
        at(6, 23, 40),
        at(7, 8, 10),
      );
      // Ordinary new activity uses the open tail, not the closed backfill gap.
      expectTimes(
        await loader.loadTimeSuggestion(date: today, now: at(7, 12)),
        at(7, 9),
        at(7, 12),
      );
    },
  );
  test('open tail uses a 30 minute initial floor, not now plus 30', () async {
    await block(1, at(7, 13), at(7, 14));
    for (final now in [
      at(7, 14),
      at(7, 14, 20),
      at(7, 14, 30),
      at(7, 15, 20),
    ]) {
      expectTimes(
        await loader.loadTimeSuggestion(date: today, now: now),
        at(7, 14),
        now > at(7, 14, 30) ? now : at(7, 14, 30),
      );
    }
  });
  test('multi-day inactivity initializes only the recent hour', () async {
    await block(1, at(3, 23), at(3, 23, 40));
    expectTimes(
      await loader.loadTimeSuggestion(date: today, now: at(7, 7, 20)),
      at(7, 6, 20),
      at(7, 7, 20),
    );
  });
  test(
    'sleep new entry does not attribute a multi-day gap to one session',
    () async {
      await block(1, at(4, 21), at(4, 22, 13));
      final suggestion = await SleepTimePredictionLoader(
        repository: repo,
        resolveDate: resolveDeviceRecordingDate,
        calendar: const DeviceSleepPredictionCalendar(),
      ).load(date: today, now: at(7, 6, 54));
      final input = suggestion.mainSleep;
      expect(
        input.startedAt,
        isNot(at(4, 22, 13)),
        reason:
            'An adjacent fact bounds unrecorded time, not one sleep session.',
      );
      expect((input.startedAt, input.endedAt), (at(6, 23), at(7, 7)));
    },
  );
  test(
    'minimum suggestion crosses midnight and does not split the interval',
    () async {
      await sleep(1, at(7, 22), at(7, 23, 50));
      expectTimes(
        await loader.loadTimeSuggestion(date: today, now: at(7, 23, 55)),
        at(7, 23, 50),
        at(8, 0, 20),
      );
    },
  );
  test('daytime sleep gap uses unknown and nap neighbors without night assumptions', () async {
    await block(1, at(7, 8), at(7, 9), unknown: true);
    await sleep(2, at(7, 17), at(7, 18));
    expectTimes(
      await loader.loadTimeSuggestion(
        date: today,
        now: at(7, 20),
        preferClosedGaps: true,
      ),
      at(7, 9),
      at(7, 17),
    );
  });
  test(
    'short empty, future and currently occupied contexts retain their behavior',
    () async {
      expect(
        await loader.loadTimeSuggestion(date: today, now: at(7, 4, 59)),
        isA<ManualTimeEntry>(),
      );
      await block(1, at(7, 10), at(7, 14));
      expect(
        await loader.loadTimeSuggestion(date: today, now: at(7, 12)),
        isA<ManualTimeEntry>(),
      );
      expect(
        await loader.loadTimeSuggestion(
          date: CivilDate(year: 2026, month: 10, day: 8),
          now: at(7, 12),
        ),
        isA<ManualTimeEntry>(),
      );
    },
  );
  test('five-hour threshold uses exact elapsed milliseconds', () async {
    final now = at(7, 15, 20);
    await block(1, at(7, 9), at(7, 10, 20));
    // One millisecond below the threshold retains the existing tail.
    expectTimes(
      await loader.loadTimeSuggestion(date: today, now: now - 1),
      at(7, 10, 20),
      now - 1,
    );
    for (final openedAt in [now, now + 1, at(7, 16)]) {
      expectTimes(
        await loader.loadTimeSuggestion(date: today, now: openedAt),
        openedAt - const Duration(hours: 1).inMilliseconds,
        openedAt,
      );
    }
  });
  test('midnight does not reset the continuous tail', () async {
    await block(1, at(6, 17), at(6, 18));
    final now = at(7, 0, 20);
    final view = await loader.load(date: today, now: now);
    expect(view.coverage.unresolvedSpans.single.startedAt, at(7, 0));
    expectTimes(
      await loader.loadTimeSuggestion(date: today, now: now),
      at(6, 23, 20),
      now,
    );
  });
  test(
    'without predecessor only the known day window determines the threshold',
    () async {
      expect(
        await loader.loadTimeSuggestion(date: today, now: at(7, 5) - 1),
        isA<ManualTimeEntry>(),
      );
      for (final now in [at(7, 5), at(7, 15, 20)]) {
        expectTimes(
          await loader.loadTimeSuggestion(date: today, now: now),
          now - const Duration(hours: 1).inMilliseconds,
          now,
        );
      }
      expect(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 15, 20),
          preferClosedGaps: true,
        ),
        isA<ManualTimeEntry>(),
      );
    },
  );
  for (final kind in ['activity', 'unknown', 'mainSleep', 'nap']) {
    test(
      '$kind interrupts a multi-day tail before activity initialization',
      () async {
        await block(1, at(3, 9), at(3, 10));
        if (kind == 'activity' || kind == 'unknown') {
          await block(2, at(7, 13), at(7, 14), unknown: kind == 'unknown');
        } else {
          await sleep(
            2,
            at(7, 13),
            at(7, 14),
            type: kind == 'mainSleep' ? SleepType.mainSleep : SleepType.nap,
          );
        }
        expectTimes(
          await loader.loadTimeSuggestion(date: today, now: at(7, 15, 20)),
          at(7, 14),
          at(7, 15, 20),
        );
      },
    );
  }
  test(
    'legacy gap helper and explicit backfill keep complete real boundaries',
    () async {
      await block(1, at(3, 9), at(3, 10));
      final now = at(7, 15, 20);
      final gap = (await loader.load(
        date: today,
        now: now,
      )).coverage.unresolvedSpans.single;
      expectTimes(
        await loader.loadTimeSuggestion(
          date: today,
          now: now,
          preferClosedGaps: true,
        ),
        at(3, 10),
        now,
      );
      expectTimes(
        await loader.loadTimeSuggestion(
          date: today,
          now: now,
          explicitGap: gap,
        ),
        at(3, 10),
        now,
      );
    },
  );
  test(
    'historical entry never receives the current recent-hour branch',
    () async {
      await block(1, at(3, 9), at(3, 10));
      expectTimes(
        await loader.loadTimeSuggestion(
          date: CivilDate(year: 2026, month: 10, day: 6),
          now: at(7, 15, 20),
        ),
        at(3, 10),
        at(7, 15, 20),
      );
    },
  );
  test(
    'long current gap does not include a future occupied interval',
    () async {
      await block(1, at(7, 9), at(7, 10));
      await sleep(2, at(7, 16), at(7, 17));
      expectTimes(
        await loader.loadTimeSuggestion(date: today, now: at(7, 15, 20)),
        at(7, 14, 20),
        at(7, 15, 20),
      );
    },
  );
  test('entry initializes cache immediately and saving leaves earlier gaps intact', () async {
    await block(1, at(3, 9), at(3, 10));
    final drafts = await DriftRecordingDraftStore.open(NativeDatabase.memory());
    addTearDown(drafts.close);
    final context = RecordingDraftContext.newEntry(date: today);
    await drafts.save(
      RecordingDraft(
        context: context,
        title: '刚完成的一件事',
        note: '保留内容',
        noteProvided: true,
        startedAt: at(7, 1),
        endedAt: at(7, 2),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
      ),
    );
    var now = at(7, 15, 20);
    var loads = 0;
    RecordingFormController makeController() => RecordingFormController(
      context: context,
      store: drafts,
      loadSuggestion: () {
        loads++;
        return loader.loadTimeSuggestion(date: today, now: now);
      },
      entrySaver: RecordingEntrySaver(
        repository: repo,
        drafts: drafts,
        refresh: loader.load,
        newId: () => id(3),
        now: () => now,
      ),
    );
    final first = makeController();
    var firstDisposed = false;
    addTearDown(() {
      if (!firstDisposed) first.dispose();
    });
    await first.initialize();
    expect(first.loadError, isNull);
    expect((first.time.startedAt, first.time.endedAt), (at(7, 14, 20), now));
    expect(await first.flush(), isTrue);
    final cached = (await drafts.read(context))!;
    expect((cached.startedAt, cached.endedAt), (at(7, 14, 20), now));
    expect(cached.title, '刚完成的一件事');
    expect(cached.note, '保留内容');
    // No formal record or inferred sleep is written by initialization.
    final before = await repo.readWindow(startedAt: at(3, 0), endedAt: now);
    expect(before.timeBlocks.map((v) => v.id), [id(1)]);
    expect(before.sleepSessions, isEmpty);
    // Manual adjustment can represent a long event, and initialization is stable.
    first.setTime(start: at(5, 12), end: now);
    expect(first.valid, isTrue);
    now = at(7, 15, 40);
    await first.initialize();
    expect(
      (first.time.startedAt, first.time.endedAt),
      (at(5, 12), at(7, 15, 20)),
    );
    expect(loads, 1);
    expect(await first.flush(), isTrue);
    first.dispose();
    firstDisposed = true;
    // A new entry session recomputes rather than restoring those cached times.
    final second = makeController();
    addTearDown(second.dispose);
    await second.initialize();
    expect((second.time.startedAt, second.time.endedAt), (at(7, 14, 40), now));
    expect(loads, 2);
    final refreshed = await second.submit();
    expect(second.submitError, isNull);
    expect(refreshed, isNotNull);
    expect(refreshed!.facts.timeBlocks.single.id, id(3));
    expect(refreshed.coverage.unresolvedSpans.single.startedAt, at(7, 0));
    expect(refreshed.coverage.unresolvedSpans.single.endedAt, at(7, 14, 40));
    expect(refreshed.coverage.unknownDuration.milliseconds, 0);
    expect(refreshed.facts.sleepSessions, isEmpty);
    expect(await drafts.read(context), isNull);
    final past = await loader.load(
      date: CivilDate(year: 2026, month: 10, day: 6),
      now: now,
    );
    expect(past.coverage.unresolvedSpans.single.startedAt, at(6, 0));
    expect(past.coverage.unresolvedSpans.single.endedAt, at(7, 0));
  });
  test(
    'known future neighbor bounds sleep; new tail never crosses it',
    () async {
      await block(1, at(7, 13), at(7, 14));
      await sleep(2, at(7, 14, 10), at(7, 14, 40));
      expectTimes(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 14, 5),
          preferClosedGaps: true,
        ),
        at(7, 14),
        at(7, 14, 10),
      );
      expect(
        await loader.loadTimeSuggestion(date: today, now: at(7, 14, 5)),
        isA<ManualTimeEntry>(),
      );
    },
  );
  test(
    'stale gap and leading gap without a real start become manual',
    () async {
      await block(1, at(7, 10), at(7, 11));
      final view = await loader.load(date: today, now: at(7, 12));
      expect(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 12),
          explicitGap: view.coverage.unresolvedSpans.first,
        ),
        isA<ManualTimeEntry>(),
      );
      final tail = view.coverage.unresolvedSpans.last;
      await block(2, at(7, 11, 10), at(7, 11, 20));
      expect(
        await loader.loadTimeSuggestion(
          date: today,
          now: at(7, 12),
          explicitGap: tail,
        ),
        isA<ManualTimeEntry>(),
      );
    },
  );
  test(
    'neighbor read preserves ordering and exposes actual storage failure',
    () async {
      await block(1, at(6, 23), at(6, 23, 40));
      await sleep(2, at(8, 7), at(8, 8));
      final facts = await repo.readRecordingContext(
        startedAt: at(7, 0),
        endedAt: at(8, 0),
      );
      expect(facts.map((v) => v.reference.id), [id(1), id(2)]);
      await expectLater(
        repo.readRecordingContext(startedAt: 2, endedAt: 1),
        throwsArgumentError,
      );
      await db.close();
      await expectLater(
        loader.loadTimeSuggestion(date: today, now: at(7, 12)),
        throwsA(isA<LedgerStorageException>()),
      );
    },
  );
}
