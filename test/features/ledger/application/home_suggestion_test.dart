import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/features/ledger/application/home_suggestion.dart';
import 'package:time_pet_ledger/features/ledger/domain/projection/reconciliation_window.dart';

const sleepAt = 8 * 60;
const reviewAt = 22 * 60;

HomeSuggestion resolve({
  LedgerDateRelation relation = LedgerDateRelation.today,
  int nowMinutes = 9 * 60,
  int sleep = sleepAt,
  int review = reviewAt,
  bool sleepRecorded = false,
  int? trailingGapMinutes,
}) => resolveHomeSuggestion(
  relation: relation,
  nowMinutes: nowMinutes,
  sleepReminderMinutes: sleep,
  reviewReminderMinutes: review,
  hasRecordedMainSleepToday: sleepRecorded,
  trailingGapMinutes: trailingGapMinutes,
);

void main() {
  test(
    'sleep uses a half-open window, requires no record, and has priority',
    () {
      expect(resolve(nowMinutes: 8 * 60).kind, HomeSuggestionKind.sleep);
      expect(resolve(nowMinutes: 12 * 60 - 1).kind, HomeSuggestionKind.sleep);
      expect(resolve(nowMinutes: 12 * 60).kind, HomeSuggestionKind.greeting);
      expect(
        resolve(nowMinutes: 7 * 60 + 59).kind,
        HomeSuggestionKind.greeting,
      );
      expect(
        resolve(nowMinutes: 9 * 60, sleepRecorded: true).kind,
        HomeSuggestionKind.greeting,
      );
      final suggestion = resolve(nowMinutes: 9 * 60, trailingGapMinutes: 300);
      expect(suggestion.kind, HomeSuggestionKind.sleep);
      expect(suggestion.action, '记录睡眠');
    },
  );

  test('record starts at two hours and outranks review', () {
    expect(
      resolve(nowMinutes: 15 * 60, trailingGapMinutes: 119).kind,
      HomeSuggestionKind.greeting,
    );
    expect(
      resolve(nowMinutes: 15 * 60, trailingGapMinutes: 120).kind,
      HomeSuggestionKind.record,
    );
    final late = resolve(nowMinutes: 23 * 60, trailingGapMinutes: 120);
    expect(late.kind, HomeSuggestionKind.record);
    expect(late.action, '补记一笔');
  });

  test('editable reminder times move sleep and review boundaries', () {
    final suggestion = resolve(nowMinutes: 22 * 60);
    expect(suggestion.kind, HomeSuggestionKind.review);
    expect(suggestion.action, '开始复盘');
    expect(resolve(nowMinutes: 21 * 60 + 59).kind, HomeSuggestionKind.greeting);
    expect(
      resolve(nowMinutes: 6 * 60, sleep: 6 * 60, review: 21 * 60).kind,
      HomeSuggestionKind.sleep,
    );
    expect(
      resolve(nowMinutes: 21 * 60, sleep: 30 * 60, review: 21 * 60).kind,
      HomeSuggestionKind.review,
    );
  });

  test('non-today dates and unmatched times use a greeting without action', () {
    expect(
      resolve(nowMinutes: 6 * 60, sleep: 30 * 60, review: 40 * 60).title,
      '早上好。',
    );
    expect(
      resolve(nowMinutes: 14 * 60, sleep: 30 * 60, review: 40 * 60).title,
      '下午好。',
    );
    expect(
      resolve(nowMinutes: 18 * 60 - 1, sleep: 30 * 60, review: 40 * 60).title,
      '下午好。',
    );
    expect(
      resolve(nowMinutes: 18 * 60, sleep: 30 * 60, review: 40 * 60).title,
      '晚上好。',
    );
    for (final relation in [
      LedgerDateRelation.historical,
      LedgerDateRelation.future,
    ]) {
      final suggestion = resolve(
        relation: relation,
        nowMinutes: 23 * 60,
        trailingGapMinutes: 300,
      );
      expect(suggestion.kind, HomeSuggestionKind.greeting);
      expect(suggestion.action, isNull);
    }
    final greeting = greetingSuggestion(9 * 60);
    expect(greeting.kind, HomeSuggestionKind.greeting);
    expect(greeting.action, isNull);
  });
}
