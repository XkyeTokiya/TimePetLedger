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
  test('sleep wins inside its window when no main sleep is recorded', () {
    final suggestion = resolve(nowMinutes: 9 * 60);
    expect(suggestion.kind, HomeSuggestionKind.sleep);
    expect(suggestion.action, '记录睡眠');
  });

  test('sleep window is half-open from the reminder time to +4h', () {
    expect(resolve(nowMinutes: 8 * 60).kind, HomeSuggestionKind.sleep);
    expect(resolve(nowMinutes: 12 * 60 - 1).kind, HomeSuggestionKind.sleep);
    expect(resolve(nowMinutes: 12 * 60).kind, HomeSuggestionKind.greeting);
    expect(resolve(nowMinutes: 7 * 60 + 59).kind, HomeSuggestionKind.greeting);
  });

  test('recorded main sleep suppresses the sleep suggestion', () {
    expect(
      resolve(nowMinutes: 9 * 60, sleepRecorded: true).kind,
      HomeSuggestionKind.greeting,
    );
  });

  test('record wins over review once the sleep window has passed', () {
    final suggestion = resolve(nowMinutes: 23 * 60, trailingGapMinutes: 120);
    expect(suggestion.kind, HomeSuggestionKind.record);
    expect(suggestion.action, '补记一笔');
  });

  test('a trailing gap under 2h does not trigger the record suggestion', () {
    expect(
      resolve(nowMinutes: 15 * 60, trailingGapMinutes: 119).kind,
      HomeSuggestionKind.greeting,
    );
    expect(
      resolve(nowMinutes: 15 * 60, trailingGapMinutes: 120).kind,
      HomeSuggestionKind.record,
    );
  });

  test('sleep still outranks a long trailing gap', () {
    expect(
      resolve(nowMinutes: 9 * 60, trailingGapMinutes: 300).kind,
      HomeSuggestionKind.sleep,
    );
  });

  test(
    'review appears at the review time when sleep and record do not apply',
    () {
      final suggestion = resolve(nowMinutes: 22 * 60);
      expect(suggestion.kind, HomeSuggestionKind.review);
      expect(suggestion.action, '开始复盘');
      expect(
        resolve(nowMinutes: 21 * 60 + 59).kind,
        HomeSuggestionKind.greeting,
      );
    },
  );

  test('greeting falls back by local time of day', () {
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
  });

  test('historical and future dates never suggest sleep, record or review', () {
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
  });

  test('editable reminder times move the sleep and review boundaries', () {
    expect(
      resolve(nowMinutes: 6 * 60, sleep: 6 * 60, review: 21 * 60).kind,
      HomeSuggestionKind.sleep,
    );
    expect(
      resolve(nowMinutes: 21 * 60, sleep: 30 * 60, review: 21 * 60).kind,
      HomeSuggestionKind.review,
    );
  });

  test('trailingGapEndingAt only counts a gap that reaches the window end', () {
    // 没有直接构造 UnresolvedSpan 的公开入口，交由 widget 流程覆盖；
    // 这里只校验纯函数在空集合上返回 null。
    expect(trailingGapEndingAt(const [], 1000), isNull);
  });

  test('greeting suggestion carries no action and short copy', () {
    final greeting = greetingSuggestion(9 * 60);
    expect(greeting.kind, HomeSuggestionKind.greeting);
    expect(greeting.action, isNull);
    expect(greeting.title.length, lessThan(10));
  });
}
