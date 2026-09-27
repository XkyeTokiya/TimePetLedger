import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/time/civil_date.dart';
import 'package:time_pet_ledger/features/goals/domain/goal.dart';
import 'package:time_pet_ledger/features/goals/domain/goal_status.dart';
import 'package:time_pet_ledger/features/review/domain/daily_review.dart';
import 'package:time_pet_ledger/features/review/domain/review_goal_association.dart';
import 'package:time_pet_ledger/features/review/domain/tomorrow_first_step.dart';

const _id = '12345678-1234-4abc-8123-123456789abc';
const _goalId = '87654321-4321-4abc-9123-123456789abc';
final _date = CivilDate(year: 1999, month: 12, day: 31);

DailyReview _review({
  String id = _id,
  String? summary,
  String? reflection,
  String text = '打开文档，补上第一段',
  String? goalId,
}) => DailyReview(
  id: id,
  date: _date,
  tomorrowFirstStep: TomorrowFirstStep(
    reviewDate: _date,
    text: text,
    goalId: goalId,
  ),
  createdAt: 3003,
  updatedAt: 1001,
  summary: summary,
  reflection: reflection,
);

void main() {
  test('MODEL-001、DR-003：正式复盘保留一个下一步，可省略解释与目标', () {
    final review = _review();
    expect(review.summary, isNull);
    expect(review.reflection, isNull);
    expect(review.tomorrowFirstStep.goalId, isNull);
    expect(review.tomorrowFirstStep.text, '打开文档，补上第一段');
    expect(review.date, _date);
    expect(review.id, _id);
    // 显式元数据不受复盘日期或时钟回拨影响。
    expect(review.createdAt, 3003);
    expect(review.updatedAt, 1001);
    expect(
      review.tomorrowFirstStep.intendedDate,
      CivilDate(year: 2000, month: 1, day: 1),
    );
  });

  test('Q-015：可选空文本归一为 null，必填下一步拒绝空白', () {
    for (final blank in ['', ' ', '\t\n\r', '\u3000']) {
      final review = _review(summary: blank, reflection: blank);
      expect(review.summary, isNull);
      expect(review.reflection, isNull);
      expect(() => _review(text: blank), throwsArgumentError);
    }
  });

  test('MODEL-002：三种文本清理首尾，保留内部空格、换行和段落', () {
    const input = ' \t第一段  内容\n\n下一行\t说明\u3000';
    const expected = '第一段  内容\n\n下一行\t说明';
    final review = _review(summary: input, reflection: input, text: input);
    expect(review.summary, expected);
    expect(review.reflection, expected);
    expect(review.tomorrowFirstStep.text, expected);
  });

  for (final field in ['summary', 'reflection', 'text']) {
    DailyReview withText(String value) => switch (field) {
      'summary' => _review(summary: value),
      'reflection' => _review(reflection: value),
      _ => _review(text: value),
    };
    String? readText(DailyReview review) => switch (field) {
      'summary' => review.summary,
      'reflection' => review.reflection,
      _ => review.tomorrowFirstStep.text,
    };

    test('Q-015：$field 接受清理后 2000 码点，拒绝 2001', () {
      for (final character in ['字', '😀']) {
        final text = character * 2000;
        expect(readText(withText(' $text\n')), text);
        expect(() => withText('$text$character'), throwsArgumentError);
      }
    });

    test('Q-015：$field 组合字符按码点而非字素计数', () {
      final text = 'e\u0301' * 1000;
      expect(readText(withText(text)), text);
      expect(() => withText('${text}e'), throwsArgumentError);
    });
  }

  test('Q-001：普通日、月末、闰日与跨年按公历计算，不依赖当前日期', () {
    for (final (year, month, day, nextYear, nextMonth, nextDay) in [
      (2026, 9, 12, 2026, 9, 13),
      (2026, 4, 30, 2026, 5, 1),
      (2026, 1, 31, 2026, 2, 1),
      (1900, 2, 28, 1900, 3, 1),
      (2000, 2, 28, 2000, 2, 29),
      (2000, 2, 29, 2000, 3, 1),
      (2024, 2, 28, 2024, 2, 29),
      (2100, 2, 28, 2100, 3, 1),
      (1999, 12, 31, 2000, 1, 1),
      (2026, 3, 8, 2026, 3, 9),
      (2026, 11, 1, 2026, 11, 2),
      // 沿用 CivilDate，不附加 1–9999 年或 DateTime 的范围限制。
      (9999, 12, 31, 10000, 1, 1),
      (-1, 12, 31, 0, 1, 1),
      (0, 2, 28, 0, 2, 29),
    ]) {
      final date = CivilDate(year: year, month: month, day: day);
      final step = TomorrowFirstStep(reviewDate: date, text: '开始');
      final review = DailyReview(
        id: _id,
        date: date,
        tomorrowFirstStep: step,
        createdAt: 0,
        updatedAt: 0,
      );
      expect(
        review.tomorrowFirstStep.intendedDate,
        CivilDate(year: nextYear, month: nextMonth, day: nextDay),
      );
      expect(date, CivilDate(year: year, month: month, day: day));
    }
  });

  test('日期入口复用 CivilDate，非法日不自动归一', () {
    for (final (month, day) in [(0, 1), (13, 1), (2, 29), (4, 31), (1, 0)]) {
      expect(
        () => TomorrowFirstStep(
          reviewDate: CivilDate(year: 2025, month: month, day: day),
          text: '开始',
        ),
        throwsArgumentError,
      );
    }
  });

  test('Q-001：拒绝属于另一复盘日期的下一步', () {
    expect(
      () => DailyReview(
        id: _id,
        date: CivilDate(year: 2000, month: 1, day: 1),
        tomorrowFirstStep: _review().tomorrowFirstStep,
        createdAt: 0,
        updatedAt: 0,
      ),
      throwsArgumentError,
    );
  });

  test('Q-018：复盘与可选 Goal 标识遵循 UUID v4 合同', () {
    expect(_review(goalId: _goalId).tomorrowFirstStep.goalId, _goalId);
    expect(() => _review(id: 'invalid'), throwsArgumentError);
    expect(() => _review(goalId: 'invalid'), throwsArgumentError);
  });

  test('Q-006：允许无 Goal、active 新关联及 archived 历史引用', () {
    validateReviewGoalAssociation(
      review: _review(),
      goal: null,
      isNewGoalAssociation: true,
    );
    for (final status in GoalStatus.values) {
      final goal = Goal.reconstitute(
        id: _goalId,
        name: '论文',
        status: status,
        createdAt: 0,
        updatedAt: 1,
        archivedAt: status == GoalStatus.archived ? 1 : null,
      );
      final review = _review(goalId: _goalId);
      validateReviewGoalAssociation(
        review: review,
        goal: goal,
        isNewGoalAssociation: false,
      );
      void validateNew() => validateReviewGoalAssociation(
        review: review,
        goal: goal,
        isNewGoalAssociation: true,
      );
      if (status == GoalStatus.archived) {
        expect(validateNew, throwsArgumentError);
      } else {
        validateNew();
      }
    }
  });

  test('Q-006：有关联时拒绝缺失或不匹配的 Goal', () {
    for (final goal in [null, Goal.create(id: _id, name: '另一目标', now: 0)]) {
      for (final isNew in [false, true]) {
        expect(
          () => validateReviewGoalAssociation(
            review: _review(goalId: _goalId),
            goal: goal,
            isNewGoalAssociation: isNew,
          ),
          throwsArgumentError,
        );
      }
    }
  });
}
