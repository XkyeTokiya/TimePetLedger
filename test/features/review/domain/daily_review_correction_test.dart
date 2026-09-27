import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_session_correction.dart';
import 'package:time_pet_ledger/features/ledger/domain/sleep_type.dart';
import 'package:time_pet_ledger/features/ledger/domain/time_precision.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review_correction.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _otherId = '87654321-4321-4abc-9123-123456789abc';
final _date = CivilDate(year: 2026, month: 9, day: 26);

DailyReview _review({String id = _id, CivilDate? date, String? goalId}) {
  final reviewDate = date ?? _date;
  return DailyReview(
    id: id,
    date: reviewDate,
    summary: '概述  内容\n第二段',
    reflection: '自己的反思',
    tomorrowFirstStep: TomorrowFirstStep(
      reviewDate: reviewDate,
      text: '打开文档',
      goalId: goalId,
    ),
    createdAt: 100,
    updatedAt: 200,
  );
}

DailyReviewCorrectionResult _correct(
  DailyReview? original, {
  Iterable<DailyReview> existing = const [],
  Goal? goal,
  int now = 300,
  CivilDate? date,
  ({String? value})? summary,
  ({String? value})? reflection,
  String? text,
  ({String? value})? goalId,
}) => correctDailyReview(
  original: original,
  existing: existing,
  goal: goal,
  now: now,
  date: date,
  summary: summary,
  reflection: reflection,
  tomorrowFirstStepText: text,
  tomorrowFirstStepGoalId: goalId,
);

void main() {
  test('Q-001：改日期重新推导次日，保留全部文字及身份，覆盖日历边界', () {
    final original = _review();
    for (final (year, month, day, nextYear, nextMonth, nextDay) in [
      (2026, 4, 30, 2026, 5, 1),
      (2026, 12, 31, 2027, 1, 1),
      (2000, 2, 28, 2000, 2, 29),
      (2000, 2, 29, 2000, 3, 1),
      (1900, 2, 28, 1900, 3, 1),
      (2100, 2, 28, 2100, 3, 1),
      (9999, 12, 31, 10000, 1, 1),
    ]) {
      final date = CivilDate(year: year, month: month, day: day);
      final result = _correct(original, date: date);
      final review = result.review;
      expect(result.changed, isTrue);
      expect(review.date, date);
      expect(
        review.tomorrowFirstStep.intendedDate,
        CivilDate(year: nextYear, month: nextMonth, day: nextDay),
      );
      expect(review.summary, original.summary);
      expect(review.reflection, original.reflection);
      expect(review.tomorrowFirstStep.text, original.tomorrowFirstStep.text);
      expect((review.id, review.createdAt, review.updatedAt), (_id, 100, 300));
    }
    expect(original.date, _date);
    expect(original.updatedAt, 200);
  });

  test('获准字段可同次或独立更正；可选文字、目标可显式清空', () {
    final original = _review(goalId: _otherId);
    final result = _correct(
      original,
      summary: (value: null),
      reflection: (value: ' \n '),
      text: '  下一步\n\n具体说明  ',
      goalId: (value: null),
    );
    expect(result.review.summary, isNull);
    expect(result.review.reflection, isNull);
    expect(result.review.tomorrowFirstStep.goalId, isNull);
    expect(result.review.tomorrowFirstStep.text, '下一步\n\n具体说明');
    expect(result.review.date, original.date);
    final plain = _review();
    final goal = Goal.create(id: _otherId, name: '目标', now: 0);
    for (final changed in [
      _correct(plain, summary: (value: '新概述')),
      _correct(plain, reflection: (value: '新反思')),
      _correct(plain, text: '新下一步'),
      _correct(plain, goalId: (value: goal.id), goal: goal),
    ]) {
      expect(changed.changed, isTrue);
      expect(changed.review.updatedAt, 300);
      expect(changed.review.id, plain.id);
      expect(changed.review.createdAt, plain.createdAt);
    }
  });

  test('无修改、等值日期、文本规范化后等值与重复请求均幂等', () {
    final original = _review();
    final result = _correct(
      original,
      date: CivilDate(year: 2026, month: 9, day: 26),
      summary: (value: ' 概述  内容\n第二段 '),
      reflection: (value: ' 自己的反思 '),
      text: ' 打开文档 ',
    );
    expect(result.changed, isFalse);
    expect(result.review, same(original));
    expect(_correct(original).review, same(original));
    final changed = _correct(original, text: '新下一步').review;
    final repeated = _correct(changed, text: ' 新下一步 ', now: 999);
    expect(repeated.changed, isFalse);
    expect(repeated.review, same(changed));
    expect(repeated.review.updatedAt, 300);
  });

  test('Q-013：缺失对象拒绝更正，不自动创建', () {
    expect(
      () => _correct(null),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('记录已不存在'),
        ),
      ),
    );
  });

  test('复盘日期必须是合法 CivilDate，非法闰日拒绝', () {
    expect(
      () => _correct(_review(), date: CivilDate(year: 2100, month: 2, day: 29)),
      throwsArgumentError,
    );
  });

  test('DR-001：排除原身份，目标日期被其他复盘占用时拒绝而非覆盖', () {
    final original = _review();
    final date = CivilDate(year: 2026, month: 9, day: 27);
    final other = _review(id: _otherId, date: date);
    expect(_correct(original, existing: [original, other]).changed, isFalse);
    expect(
      _correct(original, date: date, existing: [original]).review.date,
      date,
    );
    expect(
      () => _correct(original, date: date, existing: [original, other]),
      throwsA(
        isA<DailyReviewDateConflict>().having(
          (e) => e.existingReview,
          'existingReview',
          same(other),
        ),
      ),
    );
    expect(original.date, _date);
    expect(other.date, date);
    expect((original.updatedAt, other.updatedAt), (200, 200));
    // 无变化也不能绕过错误快照中的同日冲突。
    expect(
      () => _correct(original, existing: [_review(id: _otherId)]),
      throwsA(isA<DailyReviewDateConflict>()),
    );
  });

  test('Q-006：改日期保留归档历史关联，新增或更换归档目标拒绝', () {
    final active = Goal.create(id: _otherId, name: '目标', now: 0);
    final archived = active.archive(now: 1);
    final original = _review(goalId: _otherId);
    final result = _correct(
      original,
      goal: archived,
      date: CivilDate(year: 2026, month: 9, day: 27),
    );
    expect(result.review.tomorrowFirstStep.goalId, _otherId);
    expect(
      _correct(
        _review(),
        goal: active,
        goalId: (value: active.id),
      ).review.tomorrowFirstStep.goalId,
      active.id,
    );
    for (final previousGoal in [null, _id]) {
      expect(
        () => _correct(
          _review(goalId: previousGoal),
          goal: archived,
          goalId: (value: archived.id),
        ),
        throwsArgumentError,
      );
    }
    for (final wrong in [null, Goal.create(id: _id, name: '其他', now: 0)]) {
      expect(() => _correct(original, goal: wrong), throwsArgumentError);
    }
    expect(
      () => _correct(_review(), goalId: (value: 'invalid')),
      throwsArgumentError,
    );
  });

  test('下一步必需：空串和空白不能删除行动意向', () {
    for (final text in ['', ' \n\t ', '\u3000']) {
      expect(() => _correct(_review(), text: text), throwsArgumentError);
    }
  });

  for (final field in ['summary', 'reflection', 'text']) {
    test('Q-015：$field 更正仍接受 2000 码点，拒绝 2001', () {
      DailyReviewCorrectionResult change(String value) => switch (field) {
        'summary' => _correct(_review(), summary: (value: value)),
        'reflection' => _correct(_review(), reflection: (value: value)),
        _ => _correct(_review(), text: value),
      };
      for (final text in ['😀' * 2000, 'e\u0301' * 1000]) {
        final review = change(' $text ').review;
        final actual = switch (field) {
          'summary' => review.summary,
          'reflection' => review.reflection,
          _ => review.tomorrowFirstStep.text,
        };
        expect(actual, text);
        expect(() => change('${text}x'), throwsArgumentError);
      }
    });
  }

  test('Q-018：显式时间回拨不被纠正，未采用候选时原值保持', () {
    final original = _review();
    final result = _correct(original, text: '新下一步', now: -1);
    expect(result.review.updatedAt, -1);
    expect(result.review.createdAt, 100);
    expect(original.updatedAt, 200);
    expect(original.tomorrowFirstStep.text, '打开文档');
  });

  test('睡眠与复盘更正独立，睡眠变化不改写反思或下一步', () {
    final review = _review();
    final sleep = SleepSession(
      id: _id,
      startedAt: 1000,
      endedAt: 2000,
      startPrecision: TimePrecision.exact,
      endPrecision: TimePrecision.approximate,
      type: SleepType.mainSleep,
      createdAt: 100,
      updatedAt: 200,
    );
    final changedSleep = correctSleepSession(
      original: sleep,
      existing: [],
      now: 300,
      endedAt: 3000,
      type: SleepType.nap,
    ).sleepSession;
    expect(review.reflection, '自己的反思');
    expect(review.summary, '概述  内容\n第二段');
    expect(review.tomorrowFirstStep.text, '打开文档');
    expect(review.updatedAt, 200);
    _correct(review, reflection: (value: '用户主动修改'));
    expect(changedSleep.endedAt, 3000);
    expect(changedSleep.type, SleepType.nap);
    expect((sleep.endedAt, sleep.updatedAt), (2000, 200));
  });
}
