import '../../../core/time/time_contract.dart';
import '../../ledger/domain/rhythm_annotation.dart';
import '../../ledger/domain/time_block.dart';

/// 目标范围内的一条正时长时间事实及其解释；不是日切片，也不含睡眠。
final class GoalInvestmentRecord {
  const GoalInvestmentRecord({required this.block, this.annotation});

  final TimeBlock block;
  final RhythmAnnotation? annotation;

  InstantMilliseconds get startedAt => block.startedAt;
  InstantMilliseconds get endedAt => block.endedAt;
}

/// 读取某个 Goal 的时间投入记录；只按完整事实区间，不裁剪到自然日。
///
/// 调用方按需要自行按自然日切片（chart / 累计），本接口不读取时钟，
/// 不修改事实，也不把睡眠或 Gap 算作目标投入。
abstract interface class GoalHistoryReader {
  Future<List<GoalInvestmentRecord>> recordsFor(String goalId);

  Future<List<GoalInvestmentRecord>> recordsWithin({
    required String goalId,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  });
}

class GoalHistoryStorageException implements Exception {
  const GoalHistoryStorageException(this.cause);
  final Object cause;
  @override
  String toString() => 'Goal history is unavailable.';
}
