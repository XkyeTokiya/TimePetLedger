import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/ledger/data/session_recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/data/session_sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/block_knowledge_state.dart';
import 'package:time_pet_ledger/features/ledger/domain/recording_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_draft_store.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/data/session_review_draft_store.dart';
import 'package:time_pet_ledger/features/review/domain/review_draft_store.dart';

final date = CivilDate(year: 2026, month: 10, day: 8);

void main() {
  test('activity contexts are isolated and a new store starts empty', () async {
    final store = SessionRecordingDraftStore();
    final ordinary = RecordingDraftContext.newEntry(date: date);
    final gap = RecordingDraftContext.gap(
      date: date,
      startedAt: 10,
      endedAt: 20,
    );
    RecordingDraft value(RecordingDraftContext context, String title) =>
        RecordingDraft(
          context: context,
          title: title,
          startedAt: 10,
          endedAt: 20,
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: BlockKnowledgeState.known,
          presentationStep: 2,
        );

    await store.save(value(ordinary, '普通'));
    await store.save(value(gap, '补记'));
    expect((await store.read(ordinary))!.presentationStep, 2);
    expect((await store.read(gap))!.title, '补记');
    expect(store.count, 2);
    expect(await SessionRecordingDraftStore().read(ordinary), isNull);
    store.clearAll();
    expect(store.count, 0);
  });

  test('sleep and review snapshots never cross store instances', () async {
    final sleepContext = SleepDraftContext.newEntry(date: date);
    final sleeps = SessionSleepDraftStore();
    await sleeps.save(
      SleepDraft(
        context: sleepContext,
        startedAt: 10,
        endedAt: 20,
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        note: '本次会话',
        noteProvided: true,
      ),
    );
    expect((await sleeps.read(sleepContext))!.note, '本次会话');
    expect(await SessionSleepDraftStore().read(sleepContext), isNull);

    final reviewContext = ReviewDraftContext.newEntry(date: date);
    final reviews = SessionReviewDraftStore();
    await reviews.save(
      ReviewDraft(
        context: reviewContext,
        date: date,
        summary: '本次会话',
      ),
    );
    expect((await reviews.read(reviewContext))!.summary, '本次会话');
    expect(await SessionReviewDraftStore().read(reviewContext), isNull);
  });
}
