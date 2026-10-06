import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/time/time_contract.dart';
import '../../ledger/domain/rhythm_annotation.dart';
import '../../ledger/data/ledger_mapping.dart';
import '../domain/goal_history.dart';

/// 按目标读取时间投入与历史记录；不修改事实，不经过日投影。
///
/// 与日窗口不同：这里以 goalId 为主键直接查询 time_blocks，供目标详情
/// 的柱状 / 热力图与"此前记录"使用（Q-033）。Unknown、休息和未标记节奏
/// 都计入投入；睡眠、Gap 与复盘不计入。
final class DriftGoalHistoryReader implements GoalHistoryReader {
  DriftGoalHistoryReader(this._database);
  final AppDatabase _database;

  @override
  Future<List<GoalInvestmentRecord>> recordsFor(String goalId) async {
    try {
      return await _database.transaction(() async {
        return _read(goalId, null);
      });
    } catch (error, stack) {
      Error.throwWithStackTrace(GoalHistoryStorageException(error), stack);
    }
  }

  @override
  Future<List<GoalInvestmentRecord>> recordsWithin({
    required String goalId,
    required InstantMilliseconds startedAt,
    required InstantMilliseconds endedAt,
  }) async {
    if (startedAt > endedAt) {
      throw ArgumentError('Read window must not be reversed.');
    }
    try {
      return await _database.transaction(
        () => _read(goalId, (startedAt, endedAt)),
      );
    } catch (error, stack) {
      Error.throwWithStackTrace(GoalHistoryStorageException(error), stack);
    }
  }

  Future<List<GoalInvestmentRecord>> _read(
    String goalId,
    (int, int)? window,
  ) async {
    final variables = <Variable<Object>>[Variable(goalId)];
    var sql =
        'SELECT * FROM time_blocks WHERE goal_id = ? ORDER BY started_at, id';
    if (window != null) {
      sql =
          'SELECT * FROM time_blocks WHERE goal_id = ? '
          'AND started_at < ? AND ended_at > ? ORDER BY started_at, id';
      variables
        ..add(Variable(window.$2))
        ..add(Variable(window.$1));
    }
    final rows = await _database
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_database.timeBlocks},
        )
        .get();
    final annotations = await _database
        .customSelect(
          'SELECT a.* FROM rhythm_annotations a '
          'JOIN time_blocks t ON t.id = a.time_block_id '
          'WHERE t.goal_id = ?',
          variables: [Variable(goalId)],
          readsFrom: {_database.timeBlocks, _database.rhythmAnnotations},
        )
        .get();
    final byBlock = <String, RhythmAnnotation>{
      for (final row in annotations)
        rhythmAnnotationFromDatabase(row.data)
            .timeBlockId: rhythmAnnotationFromDatabase(
          row.data,
        ),
    };
    return List.unmodifiable([
      for (final row in rows)
        GoalInvestmentRecord(
          block: timeBlockFromDatabase(row.data),
          annotation: byBlock[timeBlockFromDatabase(row.data).id],
        ),
    ]);
  }
}
