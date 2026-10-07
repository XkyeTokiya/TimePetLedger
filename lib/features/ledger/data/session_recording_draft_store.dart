import '../domain/recording_draft_store.dart';

/// 当前应用会话内的活动输入快照；进程或网页重新载入后自然清空。
final class SessionRecordingDraftStore implements RecordingDraftStore {
  final Map<String, RecordingDraft> _values = {};

  @override
  Future<RecordingDraft?> read(RecordingDraftContext context) async =>
      _values[_key(context)];

  @override
  Future<void> save(RecordingDraft draft) async {
    _values[_key(draft.context)] = draft;
  }

  @override
  Future<void> clear(RecordingDraftContext context) async {
    _values.remove(_key(context));
  }

  int get count => _values.length;
  void clearAll() => _values.clear();
}

String _key(RecordingDraftContext context) => switch (context.entry) {
  RecordingDraftEntry.edit => 'edit:${context.timeBlockId}',
  RecordingDraftEntry.ordinary =>
    'new:${context.date.year}:${context.date.month}:${context.date.day}',
  RecordingDraftEntry.gap =>
    'gap:${context.date.year}:${context.date.month}:${context.date.day}:'
        '${context.gapStartedAt}:${context.gapEndedAt}',
};
