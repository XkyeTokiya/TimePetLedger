import '../../../core/identity/entity_id.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/data/drift_goal_repository.dart';
import '../../ledger/data/drift_ledger_repository.dart';
import '../../ledger/domain/annotation_change.dart';
import '../../ledger/domain/block_knowledge_state.dart';
import '../../ledger/domain/rhythm_details.dart';
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

  /// 添加一周的示例痕迹（Q-034 补充）。
  ///
  /// 以调用日（点击“添加测试数据”的当天）为最后一天，向前覆盖七个自然日：
  /// 每晚主睡眠与一个小睡、若干带自然空白的日常活动（含未知、目标归属和
  /// 节奏解释）以及已经过去各日的复盘。当天只写入已经结束的条目，避免
  /// 出现未来时间的“使用痕迹”；过去日期不受影响。
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
      final goal = await goals.create(id: newGoalId(), name: '毕业设计', now: now);

      final today = DateTime.fromMillisecondsSinceEpoch(now);
      int hm(int hour, int minute) => hour * 60 + minute;
      int at(int day, int minutes) => DateTime(
        today.year,
        today.month,
        today.day + day,
        minutes ~/ 60,
        minutes % 60,
      ).millisecondsSinceEpoch;
      CivilDate dateAt(int day) {
        final date = DateTime(today.year, today.month, today.day + day);
        return CivilDate(year: date.year, month: date.month, day: date.day);
      }

      // 当天只保留已经结束的条目；过去的日期全部保留。
      bool happened(int day, int end) => day < 0 || at(day, end) <= now;

      Future<void> addBlock(
        int day,
        int from,
        int to,
        String title, {
        bool goalLinked = false,
        bool unknown = false,
        String? note,
        RhythmState? rhythm,
        StuckReasonCode? stuckReason,
        String? stuckText,
        RecoveryMethod? recoveryMethod,
        RecoveryQuality? recoveryQuality,
        String? continuationHint,
      }) async {
        if (!happened(day, to)) return;
        await ledger.createTimeBlock(
          id: newFactId(),
          startedAt: at(day, from),
          endedAt: at(day, to),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          knowledgeState: unknown
              ? BlockKnowledgeState.unknown
              : BlockKnowledgeState.known,
          title: title,
          note: note,
          goalId: goalLinked ? goal.id : null,
          annotation: rhythm == null
              ? null
              : AddAnnotation(
                  id: newFactId(),
                  state: rhythm,
                  stuckReasonCode: stuckReason,
                  stuckReasonText: stuckText,
                  recoveryMethod: recoveryMethod,
                  recoveryQuality: recoveryQuality,
                  continuationHint: continuationHint,
                ),
          now: now,
        );
      }

      Future<void> addSleep(
        int fromDay,
        int from,
        int toDay,
        int to, {
        bool nap = false,
      }) async {
        if (!happened(toDay, to)) return;
        await ledger.createSleepSession(
          id: newFactId(),
          startedAt: at(fromDay, from),
          endedAt: at(toDay, to),
          startPrecision: TimePrecision.approximate,
          endPrecision: TimePrecision.approximate,
          type: nap ? SleepType.nap : SleepType.mainSleep,
          now: now,
        );
      }

      Future<void> addReview(
        int day, {
        String? summary,
        String? reflection,
        required String nextStep,
        bool goalLinked = false,
      }) async {
        await reviews.create(
          id: newFactId(),
          date: dateAt(day),
          summary: summary,
          reflection: reflection,
          tomorrowFirstStepText: nextStep,
          tomorrowFirstStepGoalId: goalLinked ? goal.id : null,
          now: now,
        );
      }

      // day -6：最早的一天。
      await addSleep(-7, hm(23, 20), -6, hm(7, 10));
      await addBlock(-6, hm(7, 30), hm(8, 0), '早餐');
      await addBlock(-6, hm(8, 30), hm(9, 0), '骑车去学校');
      await addBlock(
        -6,
        hm(9, 20),
        hm(11, 30),
        '毕业设计：整理文献',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '先列出第三章框架',
      );
      await addBlock(-6, hm(12, 10), hm(12, 40), '午餐');
      await addBlock(-6, hm(14, 0), hm(15, 30), '组会');
      await addBlock(-6, hm(18, 20), hm(19, 0), '晚餐');
      await addBlock(-6, hm(20, 0), hm(20, 40), '散步');

      // day -5。
      await addSleep(-6, hm(22, 50), -5, hm(6, 50));
      await addBlock(-5, hm(7, 20), hm(7, 50), '早餐');
      await addBlock(-5, hm(8, 20), hm(9, 0), '去图书馆还书');
      await addBlock(-5, hm(9, 30), hm(11, 20), '毕业设计：画流程草图', goalLinked: true);
      await addBlock(-5, hm(12, 0), hm(12, 40), '午餐');
      await addBlock(-5, hm(14, 0), hm(15, 0), '回复邮件');
      await addBlock(
        -5,
        hm(16, 0),
        hm(17, 30),
        '毕业设计：写第三章',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '明天把图表补上',
      );
      await addBlock(-5, hm(19, 30), hm(20, 10), '晚餐');
      await addBlock(-5, hm(21, 0), hm(22, 40), '只记得在看剧休息', unknown: true);

      // day -4：前一天睡得晚，醒来也晚一点。
      await addSleep(-4, hm(0, 30), -4, hm(7, 40));
      await addBlock(-4, hm(8, 10), hm(8, 40), '早餐');
      await addBlock(-4, hm(9, 10), hm(11, 30), '毕业设计：跑实验', goalLinked: true);
      await addBlock(-4, hm(12, 20), hm(13, 0), '午餐');
      await addBlock(
        -4,
        hm(14, 30),
        hm(16, 30),
        '毕业设计：调试程序',
        goalLinked: true,
        rhythm: RhythmState.stuck,
        stuckReason: StuckReasonCode.unclearNextStep,
        stuckText: '数据和图表对不上',
      );
      await addBlock(
        -4,
        hm(16, 30),
        hm(17, 0),
        '下楼散步',
        rhythm: RhythmState.recovery,
        recoveryMethod: RecoveryMethod.walk,
        recoveryQuality: RecoveryQuality.partlyRecovered,
      );
      await addBlock(
        -4,
        hm(17, 0),
        hm(18, 0),
        '毕业设计：重新核对数据',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '先手工核对第一条',
      );
      await addBlock(-4, hm(19, 0), hm(19, 40), '晚餐');

      // day -3：下午小睡了一会儿。
      await addSleep(-4, hm(23, 30), -3, hm(7, 0));
      await addBlock(-3, hm(7, 50), hm(8, 20), '早餐');
      await addBlock(
        -3,
        hm(9, 0),
        hm(11, 30),
        '毕业设计：写第四章',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '下午把结论补上',
      );
      await addBlock(-3, hm(12, 10), hm(12, 50), '午餐');
      await addSleep(-3, hm(13, 20), -3, hm(13, 50), nap: true);
      await addBlock(-3, hm(14, 0), hm(15, 0), '整理答辩材料');
      await addBlock(-3, hm(15, 30), hm(17, 0), '毕业设计：补结论', goalLinked: true);
      await addBlock(-3, hm(18, 30), hm(19, 10), '晚餐');
      await addBlock(-3, hm(20, 0), hm(21, 30), '打羽毛球');

      // day -2。
      await addSleep(-3, hm(23, 10), -2, hm(7, 30));
      await addBlock(-2, hm(8, 0), hm(8, 30), '早餐');
      await addBlock(-2, hm(9, 30), hm(11, 0), '毕业设计：修改摘要', goalLinked: true);
      await addBlock(-2, hm(12, 20), hm(13, 0), '午餐');
      await addBlock(-2, hm(14, 0), hm(16, 0), '答辩彩排');
      await addBlock(-2, hm(17, 0), hm(17, 40), '跑步');
      await addBlock(-2, hm(19, 0), hm(19, 40), '晚餐');
      await addBlock(-2, hm(21, 0), hm(22, 40), '只记得在收拾东西', unknown: true);

      // day -1。
      await addSleep(-2, hm(23, 0), -1, hm(6, 40));
      await addBlock(-1, hm(7, 30), hm(8, 0), '早餐');
      await addBlock(
        -1,
        hm(8, 40),
        hm(10, 40),
        '毕业设计：做汇报 PPT',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '先改图表配色',
      );
      await addBlock(-1, hm(11, 0), hm(12, 0), '与导师讨论', note: '导师说图表要再简化一点');
      await addBlock(-1, hm(12, 30), hm(13, 10), '午餐');
      await addBlock(-1, hm(14, 30), hm(16, 30), '毕业设计：改图表', goalLinked: true);
      await addBlock(-1, hm(19, 0), hm(19, 40), '晚餐');
      await addBlock(-1, hm(20, 30), hm(22, 0), '收拾房间');

      // day 0：点击当天，只落到已经结束的时刻。
      await addSleep(-1, hm(23, 30), 0, hm(7, 0));
      await addBlock(0, hm(7, 20), hm(7, 50), '早餐');
      await addBlock(
        0,
        hm(8, 30),
        hm(10, 0),
        '毕业设计：整理答辩稿',
        goalLinked: true,
        rhythm: RhythmState.progress,
        continuationHint: '把引用检查一遍',
      );
      await addBlock(0, hm(12, 10), hm(12, 40), '午餐');
      await addBlock(0, hm(14, 0), hm(15, 30), '毕业设计：检查引用', goalLinked: true);
      await addBlock(0, hm(18, 30), hm(19, 10), '晚餐');
      await addBlock(0, hm(20, 0), hm(20, 40), '散步');

      // 已经过去的六天各有一次晚间复盘；当天留白，等用户自己写。
      await addReview(
        -6,
        summary: '上午把第三章的文献重新梳理了一遍，下午组会讨论后方向清楚多了。',
        reflection: '组会前那两小时效率最高，晚上有点拖。',
        nextStep: '先画出第三章的流程图',
        goalLinked: true,
      );
      await addReview(
        -5,
        summary: '在图书馆把流程草图补完，第三章写起来还是有点卡。',
        reflection: '换到图书馆比在宿舍专注。',
        nextStep: '继续写第三章，把图表补上',
        goalLinked: true,
      );
      await addReview(
        -4,
        summary: '跑实验发现数据和图表对不上，下楼走了一圈再核对，找到一处口径问题。',
        reflection: '卡住的时候先离开屏幕，比硬撑有用。',
        nextStep: '把剩下的数据核对完',
        goalLinked: true,
      );
      await addReview(
        -3,
        summary: '上午写第四章，下午把结论补上了，晚上打了会球。',
        nextStep: '整理答辩材料，准备彩排',
      );
      await addReview(
        -2,
        summary: '答辩彩排发现时间超了，晚上把材料重新收拾了一遍。',
        reflection: '彩排还是有必要的，能提前发现问题。',
        nextStep: '把 PPT 做完，找导师过一遍',
        goalLinked: true,
      );
      await addReview(
        -1,
        summary: 'PPT 做完了，导师给了几条修改意见，图表和引用还要再顺一遍。',
        reflection: '今天收尾比预想顺利，明天把答辩稿最后过一遍。',
        nextStep: '上午整理答辩稿，逐条检查引用',
        goalLinked: true,
      );
    });
  }
}
