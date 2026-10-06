import '../../../core/identity/entity_id.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/data/drift_goal_repository.dart';
import '../../ledger/data/drift_ledger_repository.dart';
import '../../ledger/domain/annotation_change.dart';
import '../../ledger/domain/block_knowledge_state.dart';
import '../../ledger/domain/rhythm_state.dart';
import '../../ledger/domain/sleep_type.dart';
import '../../ledger/domain/time_precision.dart';
import '../../review/data/drift_review_repository.dart';
import '../domain/data_overview.dart';

/// 高级设置的数据概况与清空 / 添加测试数据（Q-034）。
///
/// 只操作正式事实表；草稿由独立连接承载，通过注入的回调计数与清除。
/// 清空保留本机偏好；添加仅在业务数据为空时执行，不引入导入导出 / 同步。
final class DriftDataMaintenance implements DataMaintenance {
  DriftDataMaintenance(
    this._database, {
    this.draftCount = _noDrafts,
    this.clearDrafts,
  });

  final AppDatabase _database;

  /// 草稿计数与清除由宿主注入，避免把三个草稿连接耦合进本类。
  final Future<int> Function() draftCount;
  final Future<void> Function()? clearDrafts;

  static Future<int> _noDrafts() async => 0;

  @override
  Future<DataCounts> counts() async {
    Future<int> count(String table) async =>
        (await _database
                .customSelect('SELECT COUNT(*) AS c FROM $table')
                .getSingle())
            .read<int>('c');
    return DataCounts(
      activities: await count('time_blocks'),
      sleep: await count('sleep_sessions'),
      goals: await count('goals'),
      reviews: await count('daily_reviews'),
      drafts: await draftCount(),
    );
  }

  @override
  Future<void> clear() async {
    await _database.transaction(() async {
      // 顺序遵守外键：事实先于目标。
      await _database.customStatement('DELETE FROM time_blocks');
      await _database.customStatement('DELETE FROM sleep_sessions');
      await _database.customStatement('DELETE FROM daily_reviews');
      await _database.customStatement('DELETE FROM goals');
    });
    await clearDrafts?.call();
  }

  @override
  Future<void> seed({
    required EntityId Function() newGoalId,
    required EntityId Function() newFactId,
    required int now,
  }) async {
    await _database.transaction(() async {
      final goals = DriftGoalRepository(_database);
      final ledger = DriftLedgerRepository(_database);
      final reviews = DriftReviewRepository(_database);
      if ((await goals.listActive()).isNotEmpty) {
        throw const DataMaintenanceConflict();
      }
      final goal = await goals.create(id: newGoalId(), name: '示例目标', now: now);
      final today = DateTime.fromMillisecondsSinceEpoch(now);
      int at(int day, int hour, int minute) => DateTime(
        today.year,
        today.month,
        today.day + day,
        hour,
        minute,
      ).millisecondsSinceEpoch;
      await ledger.createTimeBlock(
        id: newFactId(),
        startedAt: at(0, 9, 0),
        endedAt: at(0, 10, 0),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        knowledgeState: BlockKnowledgeState.known,
        title: '示例记录',
        goalId: goal.id,
        annotation: AddAnnotation(id: newFactId(), state: RhythmState.progress),
        now: now,
      );
      await ledger.createSleepSession(
        id: newFactId(),
        startedAt: at(-1, 23, 0),
        endedAt: at(0, 7, 0),
        startPrecision: TimePrecision.approximate,
        endPrecision: TimePrecision.approximate,
        type: SleepType.mainSleep,
        now: now,
      );
      await reviews.create(
        id: newFactId(),
        date: CivilDate(year: today.year, month: today.month, day: today.day),
        tomorrowFirstStepText: '继续示例目标',
        now: now,
      );
    });
  }
}
