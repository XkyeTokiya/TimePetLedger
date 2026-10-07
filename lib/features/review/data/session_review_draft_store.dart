import '../domain/review_draft_store.dart';

/// 当前应用会话内的复盘输入快照；不会跨冷启动或网页刷新恢复。
final class SessionReviewDraftStore implements ReviewDraftStore {
  final Map<String, ReviewDraft> _values = {};

  @override
  Future<ReviewDraft?> read(ReviewDraftContext context) async =>
      _values[_key(context)];

  @override
  Future<void> save(ReviewDraft draft) async {
    _values[_key(draft.context)] = draft;
  }

  @override
  Future<void> clear(ReviewDraftContext context) async {
    _values.remove(_key(context));
  }

  int get count => _values.length;
  void clearAll() => _values.clear();
}

String _key(ReviewDraftContext context) => context.isEditing
    ? 'edit:${context.reviewId}'
    : 'new:${context.entryDate!.year}:${context.entryDate!.month}:'
        '${context.entryDate!.day}';
