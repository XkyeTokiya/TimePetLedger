import 'package:drift/drift.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../domain/review_draft_store.dart';

/// 独立复盘草稿连接，不使用正式库或普通 / 睡眠草稿表。
final class DriftReviewDraftStore implements ReviewDraftStore {
  DriftReviewDraftStore._(this._database);
  final _ReviewDraftDatabase _database;
  Future<void> _tail = Future.value();
  Future<void>? _closing;

  static Future<DriftReviewDraftStore> open(QueryExecutor executor) async {
    final database = _ReviewDraftDatabase(executor);
    try {
      await database.customSelect('SELECT 1').getSingle();
      return DriftReviewDraftStore._(database);
    } catch (error, stack) {
      try {
        await database.close();
      } catch (_) {
        // 保留打开失败，避免清理错误覆盖原始原因。
      }
      Error.throwWithStackTrace(
        ReviewDraftStorageException(ReviewDraftOperation.open, error),
        stack,
      );
    }
  }

  @override
  Future<ReviewDraft?> read(ReviewDraftContext context) =>
      _run(ReviewDraftOperation.read, () async {
        final row = await _database
            .customSelect(
              'SELECT * FROM review_drafts WHERE context_key = ?',
              variables: [Variable(_key(context))],
            )
            .getSingleOrNull();
        if (row == null) return null;
        try {
          final draft = _decode(row.data);
          if (_key(draft.context) != _key(context)) {
            throw const ReviewDraftDataException();
          }
          return draft;
        } catch (_) {
          throw const ReviewDraftDataException();
        }
      });

  @override
  Future<void> save(ReviewDraft draft) =>
      _run(ReviewDraftOperation.save, () async {
        final c = draft.context;
        final date = draft.date;
        final goalId = draft.tomorrowFirstStepGoalId;
        if (goalId != null) requireUuidV4(goalId);
        // 事务覆盖语句及触发器：失败不留下部分更新或清除原草稿。
        await _database.transaction(
          () => _database.customStatement(
            '''
INSERT INTO review_drafts (
 context_key, entry_year, entry_month, entry_day, review_id,
 draft_year, draft_month, draft_day, date_input,
 summary, reflection, tomorrow_first_step_text, tomorrow_first_step_goal_id
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(context_key) DO UPDATE SET
 entry_year=excluded.entry_year, entry_month=excluded.entry_month,
 entry_day=excluded.entry_day, review_id=excluded.review_id,
 draft_year=excluded.draft_year, draft_month=excluded.draft_month,
 draft_day=excluded.draft_day, date_input=excluded.date_input,
 summary=excluded.summary, reflection=excluded.reflection,
 tomorrow_first_step_text=excluded.tomorrow_first_step_text,
 tomorrow_first_step_goal_id=excluded.tomorrow_first_step_goal_id
''',
            [
              _key(c),
              c.entryDate?.year,
              c.entryDate?.month,
              c.entryDate?.day,
              c.reviewId,
              date?.year,
              date?.month,
              date?.day,
              draft.dateInput,
              draft.summary,
              draft.reflection,
              draft.tomorrowFirstStepText,
              goalId,
            ],
          ),
        );
      });

  @override
  Future<void> clear(ReviewDraftContext context) => _run(
    ReviewDraftOperation.clear,
    () => _database.transaction(
      () => _database.customStatement(
        'DELETE FROM review_drafts WHERE context_key = ?',
        [_key(context)],
      ),
    ),
  );

  /// 顺序完成已接受的操作，再释放；关闭后不接受新的操作。
  Future<void> close() =>
      _closing ??= _run(ReviewDraftOperation.close, _database.close);

  /// 高级设置数据概况：现存草稿数（Q-034）。
  Future<int> countAll() => _run(ReviewDraftOperation.read, () async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS c FROM review_drafts')
        .getSingle();
    return row.read<int>('c');
  });

  /// 高级设置清空：删除全部草稿，不影响正式事实。
  Future<void> clearAll() => _run(
    ReviewDraftOperation.clear,
    () => _database.customStatement('DELETE FROM review_drafts'),
  );

  Future<T> _run<T>(
    ReviewDraftOperation operation,
    Future<T> Function() action,
  ) {
    if (_closing != null) {
      return Future.error(
        ReviewDraftStorageException(operation, StateError('Store is closed.')),
      );
    }
    final result = _tail.then((_) async {
      try {
        return await action();
      } on ReviewDraftDataException {
        rethrow;
      } catch (error, stack) {
        Error.throwWithStackTrace(
          ReviewDraftStorageException(operation, error),
          stack,
        );
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

String _key(ReviewDraftContext context) => context.isEditing
    ? 'edit:${context.reviewId}'
    : 'new:${context.entryDate!.year}:${context.entryDate!.month}:${context.entryDate!.day}';

CivilDate? _date(Map<String, Object?> row, String prefix) {
  final year = row['${prefix}_year'];
  final month = row['${prefix}_month'];
  final day = row['${prefix}_day'];
  if (year == null && month == null && day == null) return null;
  return CivilDate(year: year as int, month: month as int, day: day as int);
}

ReviewDraft _decode(Map<String, Object?> row) {
  final entryDate = _date(row, 'entry');
  final id = row['review_id'] as String?;
  if ((id == null) == (entryDate == null)) {
    throw const ReviewDraftDataException();
  }
  final goalId = row['tomorrow_first_step_goal_id'] as String?;
  if (goalId != null) requireUuidV4(goalId);
  return ReviewDraft(
    context: id == null
        ? ReviewDraftContext.newEntry(date: entryDate!)
        : ReviewDraftContext.edit(reviewId: id),
    date: _date(row, 'draft'),
    dateInput: row['date_input'] as String?,
    summary: row['summary'] as String?,
    reflection: row['reflection'] as String?,
    tomorrowFirstStepText: row['tomorrow_first_step_text'] as String?,
    tomorrowFirstStepGoalId: goalId,
  );
}

class _ReviewDraftDatabase extends GeneratedDatabase {
  _ReviewDraftDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement('''
CREATE TABLE review_drafts (
 context_key TEXT NOT NULL PRIMARY KEY,
 entry_year INTEGER, entry_month INTEGER, entry_day INTEGER, review_id TEXT,
 draft_year INTEGER, draft_month INTEGER, draft_day INTEGER, date_input TEXT,
 summary TEXT, reflection TEXT, tomorrow_first_step_text TEXT,
 tomorrow_first_step_goal_id TEXT
)
'''),
    onUpgrade: (_, from, to) async {
      throw StateError('Unsupported review draft schema: $from -> $to');
    },
  );
}
