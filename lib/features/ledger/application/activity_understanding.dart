import '../../../core/identity/entity_id.dart';
import '../domain/annotation_change.dart';
import '../domain/ledger_repository.dart';
import '../domain/rhythm_annotation.dart';
import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import '../domain/time_block.dart';

/// 保存后理解层的失败反馈；消息可直接展示给用户。
class ActivityUnderstandingException implements Exception {
  const ActivityUnderstandingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 保存后理解层的定点写入：目标关联与节奏解释 add / edit / remove。
///
/// 与完整编辑不同，这里只改单笔的归属或解释，不重建事实、不动时间；
/// 省略字段保留、显式 null 清空（Q-005、Q-013）。
class ActivityUnderstandingService {
  ActivityUnderstandingService({
    required this.repository,
    required this.now,
    required this.newId,
  });

  final LedgerRepository repository;
  final int Function() now;
  final EntityId Function() newId;

  Future<({TimeBlock timeBlock, RhythmAnnotation? annotation})?> load(
    EntityId id,
  ) => _guard(() async {
    final result = await repository.readTimeBlock(id);
    if (result == null) return null;
    return (timeBlock: result.timeBlock, annotation: result.annotation);
  });

  Future<void> linkGoal(EntityId id, EntityId? goalId) => _guard(
    () =>
        repository.updateTimeBlock(id: id, now: now(), goalId: (value: goalId)),
  );

  /// [state] 为 null 表示“暂时说不清”：不新建解释；已有解释则移除。
  Future<RhythmAnnotation?> setRhythm(
    EntityId id, {
    required RhythmAnnotation? current,
    required RhythmState? state,
  }) => _guard(() async {
    final AnnotationChange change;
    if (state == null) {
      change = current == null
          ? const KeepAnnotation()
          : const RemoveAnnotation();
    } else if (current == null) {
      change = AddAnnotation(id: newId(), state: state);
    } else {
      change = EditAnnotation(state: state);
    }
    final result = await repository.updateTimeBlock(
      id: id,
      now: now(),
      annotation: change,
    );
    return result.annotation;
  });

  /// 只写当前状态适用的细节，其他状态的保留字段不动（Q-005）。
  Future<RhythmAnnotation?> updateDetails(
    EntityId id, {
    required RhythmState state,
    StuckReasonCode? reasonCode,
    String? reasonText,
    RecoveryMethod? recoveryMethod,
    RecoveryQuality? recoveryQuality,
    String? continuationHint,
  }) => _guard(() async {
    final AnnotationChange change = switch (state) {
      RhythmState.stuck => EditAnnotation(
        stuckReasonCode: (value: reasonCode),
        stuckReasonText: (value: _normalize(reasonText)),
        continuationHint: (value: _normalize(continuationHint)),
      ),
      RhythmState.recovery => EditAnnotation(
        recoveryMethod: (value: recoveryMethod),
        recoveryQuality: (value: recoveryQuality),
        continuationHint: (value: _normalize(continuationHint)),
      ),
      RhythmState.progress => EditAnnotation(
        continuationHint: (value: _normalize(continuationHint)),
      ),
    };
    final result = await repository.updateTimeBlock(
      id: id,
      now: now(),
      annotation: change,
    );
    return result.annotation;
  });

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on LedgerFactNotFoundException {
      throw const ActivityUnderstandingException('记录已不存在，请刷新后重试。');
    } on LedgerAnnotationOperationException catch (error) {
      throw ActivityUnderstandingException(switch (error.reason) {
        AnnotationOperationFailure.alreadyExists => '这条记录已有节奏解释，请刷新后编辑。',
        AnnotationOperationFailure.notFound => '节奏解释已不存在，请刷新后重试。',
      });
    } on LedgerConflictException {
      throw const ActivityUnderstandingException('时间与其他记录冲突，请刷新后重试。');
    }
  }
}
