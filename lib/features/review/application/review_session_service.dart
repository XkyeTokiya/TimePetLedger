import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../ledger/domain/block_knowledge_state.dart';
import '../../ledger/domain/ledger_repository.dart';
import '../../ledger/domain/time_precision.dart';
import '../domain/daily_review.dart';
import '../domain/review_draft_store.dart';
import 'review_entry_saver.dart';

/// 复盘会话的可展示失败；消息直接呈现给用户。
class ReviewSessionException implements Exception {
  const ReviewSessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 复盘四步会话的定点写入。
///
/// 只改单笔记录的内容 / 时间 / 存在性与当日复盘本身；节奏解释与目标
/// 关联仍由 `ActivityUnderstandingService` 承担。失败向上抛出，由页面
/// 提示并允许重试，不静默吞掉。
class ReviewSessionService {
  ReviewSessionService({
    required this.repository,
    required this.saver,
    required this.now,
    required this.newId,
  });

  final LedgerRepository repository;
  final ReviewEntrySaver saver;
  final int Function() now;
  final EntityId Function() newId;

  Future<void> renameRecord(EntityId id, String title) async {
    final trimmed = title.trim();
    await _guard(
      () => repository.updateTimeBlock(
        id: id,
        now: now(),
        title: (value: trimmed.isEmpty ? null : trimmed),
      ),
    );
  }

  Future<void> retimeRecord(
    EntityId id, {
    required int startedAt,
    required int endedAt,
  }) => _guard(
    () => repository.updateTimeBlock(
      id: id,
      now: now(),
      startedAt: startedAt,
      endedAt: endedAt,
    ),
  );

  Future<void> deleteRecord(EntityId id) =>
      _guard(() => repository.deleteTimeBlock(id));

  /// Gap「想不起来」：为该区间建立 Unknown 事实（时间已交代，内容未知）。
  Future<void> markGapUnknown({required int startedAt, required int endedAt}) =>
      _guard(
        () => repository.createTimeBlock(
          id: newId(),
          startedAt: startedAt,
          endedAt: endedAt,
          startPrecision: TimePrecision.exact,
          endPrecision: TimePrecision.exact,
          knowledgeState: BlockKnowledgeState.unknown,
          now: now(),
        ),
      );

  /// 完成（或重新整理完成）复盘：写入 / 更新 DailyReview 与必填的下一步。
  ///
  /// 重新整理沿用原 summary / reflection 值，不因新流程而清空旧文本。
  Future<void> complete({
    required CivilDate date,
    required DailyReview? original,
    required String nextStep,
    required EntityId? nextStepGoalId,
  }) async {
    final draft = ReviewDraft(
      context: original == null
          ? ReviewDraftContext.newEntry(date: date)
          : ReviewDraftContext.edit(reviewId: original.id),
      date: date,
      summary: original?.summary,
      reflection: original?.reflection,
      tomorrowFirstStepText: nextStep,
      tomorrowFirstStepGoalId: nextStepGoalId,
    );
    final result = await _guard(() => saver.submit(draft));
    if (result is ReviewSubmitFailed) {
      throw ReviewSessionException(switch (result.reason) {
        ReviewSubmitFailure.invalidInput => '下一步需要写一句再完成。',
        ReviewSubmitFailure.dateOccupied => '这一天已有另一份复盘，请刷新后重试。',
        ReviewSubmitFailure.invalidGoal => '所选目标已不可用，请重新选择。',
        ReviewSubmitFailure.missingSource => '这份复盘已不存在，请刷新后重试。',
        ReviewSubmitFailure.storage => '复盘保存失败，请重试。',
      });
    }
  }

  Future<void> deleteReview(DailyReview original) async {
    final result = await _guard(
      () => saver.delete(
        context: ReviewDraftContext.edit(reviewId: original.id),
        original: original,
      ),
    );
    if (result is ReviewDeleteFailed) {
      throw const ReviewSessionException('删除失败，请重试。');
    }
  }

  /// 已提交残留：识别后只收尾（清快照 / 读回），不重复提交。
  ///
  /// 返回命中的正式复盘；null 表示残留与现有内容不一致或不属于新建态，
  /// 由调用方决定是否提供恢复选择。
  Future<DailyReview?> recoverCommittedDraft(ReviewDraft draft) async {
    final result = await _guard(() => saver.recoverCommittedDraft(draft));
    return result?.review;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ReviewSessionException {
      rethrow;
    } on ReviewDraftStorageException catch (error) {
      throw ReviewSessionException('本机存储暂时不可用（${error.operation.name}）。');
    } catch (_) {
      throw const ReviewSessionException('操作没有保存成功，请重试。');
    }
  }
}
