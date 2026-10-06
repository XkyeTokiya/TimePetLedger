import '../../core/persistence/database_connection.dart';
import '../../features/settings/data/drift_app_preferences_store.dart';
import '../../features/settings/domain/app_preferences.dart';

/// App owns this separately named preferences connection and must close it.
Future<DriftAppPreferencesStore> openAppPreferencesStore() async {
  try {
    return await DriftAppPreferencesStore.open(
      await connectDatabase('time_pet_ledger_preferences'),
    );
  } on AppPreferencesStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(AppPreferencesStorageException(error), stack);
  }
}

/// 按需打开独立连接，首次使用才建立；presentation 只取得接口。
/// 打开失败可重试，成功缓存；关闭顺序等待已接受的操作（沿用草稿会话合同）。
final class AppPreferencesSession implements AppPreferencesStore {
  AppPreferencesSession({required this.openStore});
  final Future<DriftAppPreferencesStore> Function() openStore;
  DriftAppPreferencesStore? _store;
  Future<DriftAppPreferencesStore>? _opening;
  Future<void> _tail = Future.value();
  Future<void>? _closing;

  Future<T> _use<T>(Future<T> Function(AppPreferencesStore store) action) {
    if (_closing != null) {
      return Future.error(
        AppPreferencesStorageException(StateError('Session is closed.')),
      );
    }
    final result = _tail.then((_) async {
      final store = await _resolve();
      return action(store);
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<DriftAppPreferencesStore> _resolve() async {
    if (_store case final store?) return store;
    final pending = _opening ??= openStore();
    try {
      final store = await pending;
      _store = store;
      return store;
    } catch (_) {
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  @override
  Future<AppPreferences> read() => _use((store) => store.read());

  @override
  Future<void> write(AppPreferences preferences) =>
      _use((store) => store.write(preferences));

  Future<void> close() {
    return _closing ??= () async {
      await _tail;
      final store = _store;
      if (store != null) await store.close();
    }();
  }
}
