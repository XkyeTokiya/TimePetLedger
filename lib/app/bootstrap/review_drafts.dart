import '../../core/persistence/database_connection.dart';
import '../../features/review/data/drift_review_draft_store.dart';
import '../../features/review/domain/review_draft_store.dart';

Future<DriftReviewDraftStore> openReviewDraftStore() async {
  try {
    return await DriftReviewDraftStore.open(
      await connectDatabase('time_pet_ledger_review_drafts'),
    );
  } on ReviewDraftStorageException {
    rethrow;
  } catch (error, stack) {
    Error.throwWithStackTrace(
      ReviewDraftStorageException(ReviewDraftOperation.open, error),
      stack,
    );
  }
}

/// app 拥有按需打开的独立连接；presentation 仅取得 ReviewDraftStore。
/// 失败后可重试，关闭等待已接受的操作（含尚未完成的打开）。
final class ReviewDraftSession implements ReviewDraftStore {
  ReviewDraftSession({required this.openStore});
  final Future<DriftReviewDraftStore> Function() openStore;
  DriftReviewDraftStore? _store;
  Future<void> _tail = Future.value();
  Future<void>? _closing;

  Future<T> _use<T>(
    ReviewDraftOperation operation,
    Future<T> Function(ReviewDraftStore) action,
  ) {
    if (_closing != null) {
      return Future.error(
        ReviewDraftStorageException(
          operation,
          StateError('Session is closed.'),
        ),
      );
    }
    final result = _tail.then((_) async {
      if (_store == null) {
        try {
          _store = await openStore();
        } on ReviewDraftStorageException {
          rethrow;
        } catch (error, stack) {
          Error.throwWithStackTrace(
            ReviewDraftStorageException(ReviewDraftOperation.open, error),
            stack,
          );
        }
      }
      return action(_store!);
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<ReviewDraft?> read(ReviewDraftContext context) =>
      _use(ReviewDraftOperation.read, (store) => store.read(context));
  @override
  Future<void> save(ReviewDraft draft) =>
      _use(ReviewDraftOperation.save, (store) => store.save(draft));
  @override
  Future<void> clear(ReviewDraftContext context) =>
      _use(ReviewDraftOperation.clear, (store) => store.clear(context));

  Future<void> close() => _closing ??= _tail.then((_) async {
    await _store?.close();
  });
}
