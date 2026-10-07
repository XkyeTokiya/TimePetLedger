import '../domain/sleep_draft_store.dart';

/// 当前应用会话内的睡眠输入快照；不承载持久化的睡眠学习证据。
final class SessionSleepDraftStore implements SleepDraftStore {
  final Map<String, SleepDraft> _values = {};

  @override
  Future<SleepDraft?> read(SleepDraftContext context) async =>
      _values[_key(context)];

  @override
  Future<void> save(SleepDraft draft) async {
    _values[_key(draft.context)] = draft;
  }

  @override
  Future<void> clear(SleepDraftContext context) async {
    _values.remove(_key(context));
  }

  int get count => _values.length;
  void clearAll() => _values.clear();
}

String _key(SleepDraftContext context) => context.isEditing
    ? 'edit:${context.sleepSessionId}'
    : 'new:${context.date.year}:${context.date.month}:${context.date.day}';
