import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal.dart';
import '../../ledger/domain/projection/day_ledger_view.dart';
import '../domain/daily_review.dart';

/// 一次一致读取的正式复盘、当前事实投影及下一步原目标元数据。
/// null review 仅表示按日读取成功且不存在；读取异常向 presentation 传播。
final class ReviewContext {
  const ReviewContext({
    required this.ledger,
    required this.review,
    required this.firstStepGoal,
  });

  final DayLedgerView ledger;
  final DailyReview? review;
  final Goal? firstStepGoal;
}

final class ReviewContextLoader {
  const ReviewContextLoader({required this.readContext});

  /// app 组装层保证复盘、ledger 摘要和目标在同一读取事务内取得。
  final Future<ReviewContext> Function({
    required CivilDate date,
    required int now,
  })
  readContext;

  Future<ReviewContext> load({required CivilDate date, required int now}) =>
      readContext(date: date, now: now);
}
