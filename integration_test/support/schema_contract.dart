import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:time_pet_ledger/core/persistence/app_database.dart';

// Raw SQL deliberately bypasses Drift's Dart validation to exercise SQLite.
const _id = '00000000-0000-4000-8000-000000000001';
const _otherId = '00000000-0000-4000-8000-000000000002';
const _missingId = '00000000-0000-4000-8000-000000000003';
const _instant = 1790467200123;

const _rows = <String, Map<String, Object?>>{
  'goals': {
    'id': _id,
    'name': '毕业设计',
    'status': 'active',
    'created_at': _instant,
    'updated_at': _instant,
  },
  'time_blocks': {
    'id': _id,
    'started_at': _instant,
    'ended_at': _instant + 60001,
    'start_precision': 'approximate',
    'end_precision': 'exact',
    'knowledge_state': 'known',
    'title': '修改设计',
    'created_at': _instant,
    'updated_at': _instant,
  },
  'rhythm_annotations': {
    'id': _id,
    'time_block_id': _id,
    'state': 'stuck',
    'created_at': _instant,
    'updated_at': _instant,
  },
  'sleep_sessions': {
    'id': _id,
    'started_at': _instant - 28800000,
    'ended_at': _instant,
    'start_precision': 'exact',
    'end_precision': 'approximate',
    'sleep_type': 'mainSleep',
    'created_at': _instant,
    'updated_at': _instant,
  },
  'daily_reviews': {
    'id': _id,
    'review_date': '2026-09-27',
    'tomorrow_first_step_text': '先补数据库字段',
    'created_at': _instant,
    'updated_at': _instant,
  },
};

const _optional = <String, List<String>>{
  'goals': ['archived_at'],
  'time_blocks': ['title', 'goal_id', 'category_id', 'note'],
  'rhythm_annotations': [
    'stuck_reason_code',
    'stuck_reason_text',
    'recovery_method',
    'recovery_quality',
    'continuation_hint',
  ],
  'sleep_sessions': ['note'],
  'daily_reviews': ['summary', 'reflection', 'tomorrow_first_step_goal_id'],
};

Future<void> _insert(
  AppDatabase db,
  String table,
  Map<String, Object?> values,
) => db.customStatement(
  'INSERT INTO $table (${values.keys.join(', ')}) '
  'VALUES (${List.filled(values.length, '?').join(', ')})',
  values.values.toList(),
);

Future<Map<String, Object?>> _row(AppDatabase db, String table) async =>
    (await db
            .customSelect(
              'SELECT * FROM $table WHERE id = ?',
              variables: [Variable(_id)],
            )
            .getSingle())
        .data;

// Constraint rejection is verified by SQLite's own error, not any exception.
Future<void> _reject(Future<void> write) => expectLater(
  write,
  throwsA(
    predicate<Object>(
      (error) => error.toString().contains('constraint failed'),
      'SQLite constraint failure',
    ),
  ),
);

final schemaChecks = <String, Future<void> Function(AppDatabase)>{
  'five tables expose only the specified columns, nullability and indexes': (db) async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(
      tables.map((row) => row.read<String>('name')),
      unorderedEquals(_rows.keys),
    );
    for (final table in _rows.keys) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      final expected = {..._rows[table]!.keys, ..._optional[table]!};
      expect(
        columns.map((row) => row.read<String>('name')),
        unorderedEquals(expected),
        reason: table,
      );
      for (final column in columns) {
        final name = column.read<String>('name');
        expect(
          column.read<int>('notnull'),
          _optional[table]!.contains(name) ? 0 : 1,
          reason: '$table.$name',
        );
        expect(column.data['dflt_value'], isNull);
        expect(column.read<int>('pk'), name == 'id' ? 1 : 0);
        final integer = name.endsWith('_at');
        expect(column.read<String>('type'), integer ? 'INTEGER' : 'TEXT');
      }
    }
    const indexes = {
      'idx_time_blocks_started_at': ['started_at'],
      'idx_time_blocks_goal_started_at': ['goal_id', 'started_at'],
      'idx_sleep_sessions_started_at': ['started_at'],
      'idx_daily_reviews_first_step_goal': ['tomorrow_first_step_goal_id'],
    };
    final explicit = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL",
        )
        .get();
    expect(
      explicit.map((row) => row.read<String>('name')),
      unorderedEquals(indexes.keys),
    );
    for (final entry in indexes.entries) {
      final columns = await db
          .customSelect('PRAGMA index_info(${entry.key})')
          .get();
      expect(columns.map((row) => row.read<String>('name')), entry.value);
    }
    expect(
      await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type IN ('view', 'trigger')",
          )
          .get(),
      isEmpty,
    );
  },
  'legal five-table rows preserve milliseconds, independent precision and nulls':
      (db) async {
        for (final entry in _rows.entries) {
          await _insert(db, entry.key, entry.value);
          final saved = await _row(db, entry.key);
          for (final field in entry.value.entries) {
            expect(saved[field.key], field.value);
          }
          for (final field in _optional[entry.key]!) {
            if (!entry.value.containsKey(field)) expect(saved[field], isNull);
          }
        }
        final block = await db.select(db.timeBlocks).getSingle();
        expect(block.startedAt, _instant);
        expect(block.endedAt, _instant + 60001);
        expect(block.startPrecision, 'approximate');
        expect(block.endPrecision, 'exact');
        expect(
          (await db.select(db.dailyReviews).getSingle()).reviewDate,
          '2026-09-27',
        );
      },
  'all required columns reject omission and NULL; primary keys reject duplicates':
      (db) async {
        // The annotation's parent exists before testing its independent constraints.
        await _insert(db, 'time_blocks', _rows['time_blocks']!);
        for (final entry in _rows.entries) {
          final values = {...entry.value, 'id': _otherId};
          for (final field in entry.value.keys) {
            if (_optional[entry.key]!.contains(field)) continue;
            await _reject(_insert(db, entry.key, {...values}..remove(field)));
            await _reject(_insert(db, entry.key, {...values, field: null}));
          }
          await _insert(db, entry.key, values);
          await _reject(_insert(db, entry.key, values));
        }
      },
  'closed code sets reject invalid values and accept every approved option':
      (db) async {
        for (final entry in _rows.entries) {
          await _insert(db, entry.key, entry.value);
        }
        const codes = <String, Map<String, List<String>>>{
          'goals': {
            'status': ['active', 'archived'],
          },
          'time_blocks': {
            'start_precision': ['exact', 'approximate'],
            'end_precision': ['exact', 'approximate'],
            'knowledge_state': ['known', 'unknown'],
          },
          'sleep_sessions': {
            'start_precision': ['exact', 'approximate'],
            'end_precision': ['exact', 'approximate'],
            'sleep_type': ['mainSleep', 'nap'],
          },
          'rhythm_annotations': {
            'state': ['progress', 'stuck', 'recovery'],
            'stuck_reason_code': [
              'taskTooLarge',
              'unclearNextStep',
              'sleepy',
              'brainFog',
              'anxious',
              'interrupted',
              'unsure',
              'other',
            ],
            'recovery_method': [
              'walk',
              'meal',
              'shower',
              'empty',
              'entertainment',
              'switchTask',
              'breakDownTask',
              'askForHelp',
              'other',
            ],
            'recovery_quality': [
              'notRecovered',
              'partlyRecovered',
              'readyToContinue',
            ],
          },
        };
        for (final table in codes.entries) {
          for (final field in table.value.entries) {
            for (final invalid in [
              'invalid',
              '',
              field.value.first.toUpperCase(),
              'sleep',
              '0',
            ]) {
              await _reject(
                db.customStatement('UPDATE ${table.key} SET ${field.key} = ?', [
                  invalid,
                ]),
              );
            }
            for (final valid in field.value) {
              final extra = table.key == 'goals'
                  ? ', archived_at = ${valid == 'archived' ? _instant : 'NULL'}'
                  : '';
              await db.customStatement(
                'UPDATE ${table.key} SET ${field.key} = ?$extra',
                [valid],
              );
            }
          }
        }
        final annotation = await _row(db, 'rhythm_annotations');
        await db.customStatement(
          "UPDATE rhythm_annotations SET state = 'progress'",
        );
        final switched = await _row(db, 'rhythm_annotations');
        expect({...switched, 'state': annotation['state']}, annotation);
      },
  'known title NULL/empty and non-positive intervals fail on insert and update':
      (db) async {
        for (final title in [null, '']) {
          await _reject(
            _insert(db, 'time_blocks', {
              ..._rows['time_blocks']!,
              'title': title,
            }),
          );
        }
        for (final table in ['time_blocks', 'sleep_sessions']) {
          final row = _rows[table]!;
          for (final end in [
            row['started_at'],
            (row['started_at']! as int) - 1,
          ]) {
            await _reject(_insert(db, table, {...row, 'ended_at': end}));
          }
          await _insert(db, table, row);
          await _reject(
            db.customStatement('UPDATE $table SET ended_at = started_at'),
          );
        }
        await db.customStatement(
          "UPDATE time_blocks SET knowledge_state = 'unknown', title = NULL",
        );
        await _reject(
          db.customStatement(
            "UPDATE time_blocks SET knowledge_state = 'known'",
          ),
        );
        await db.customStatement(
          "UPDATE time_blocks SET title = '保留的描述', category_id = 'extension'",
        );
        await db.customStatement(
          "UPDATE time_blocks SET knowledge_state = 'known'",
        );
        await db.customStatement(
          "UPDATE time_blocks SET knowledge_state = 'unknown'",
        );
        expect((await _row(db, 'time_blocks'))['title'], '保留的描述');
        expect((await _row(db, 'time_blocks'))['category_id'], 'extension');
      },
  'annotation parent/uniqueness and daily date uniqueness reject conflicts':
      (db) async {
        await _insert(db, 'sleep_sessions', _rows['sleep_sessions']!);
        await _reject(
          _insert(db, 'rhythm_annotations', _rows['rhythm_annotations']!),
        );
        await _insert(db, 'time_blocks', _rows['time_blocks']!);
        await _insert(db, 'time_blocks', {
          ..._rows['time_blocks']!,
          'id': _otherId,
        });
        await _insert(db, 'rhythm_annotations', _rows['rhythm_annotations']!);
        await _reject(
          _insert(db, 'rhythm_annotations', {
            ..._rows['rhythm_annotations']!,
            'id': _otherId,
          }),
        );
        await _reject(
          db.customStatement(
            'UPDATE rhythm_annotations SET time_block_id = ?',
            [_missingId],
          ),
        );
        await _insert(db, 'rhythm_annotations', {
          ..._rows['rhythm_annotations']!,
          'id': _otherId,
          'time_block_id': _otherId,
        });
        await _reject(
          db.customStatement(
            'UPDATE rhythm_annotations SET time_block_id = ? WHERE id = ?',
            [_id, _otherId],
          ),
        );
        await _insert(db, 'daily_reviews', _rows['daily_reviews']!);
        await _reject(
          _insert(db, 'daily_reviews', {
            ..._rows['daily_reviews']!,
            'id': _otherId,
          }),
        );
        await _insert(db, 'daily_reviews', {
          ..._rows['daily_reviews']!,
          'id': _otherId,
          'review_date': '2026-09-28',
        });
        await _reject(
          db.customStatement(
            'UPDATE daily_reviews SET review_date = ? WHERE id = ?',
            ['2026-09-27', _otherId],
          ),
        );
      },
  'Goal links restrict deletion and rekeying; only block deletion cascades':
      (db) async {
        for (final entry in {
          'time_blocks': 'goal_id',
          'daily_reviews': 'tomorrow_first_step_goal_id',
        }.entries) {
          await _reject(
            _insert(db, entry.key, {
              ..._rows[entry.key]!,
              entry.value: _missingId,
            }),
          );
        }
        await _insert(db, 'goals', _rows['goals']!);
        await _insert(db, 'goals', {
          ..._rows['goals']!,
          'id': _otherId,
        }); // Same name legal.
        await _reject(
          db.customStatement(
            "UPDATE goals SET status = 'archived' WHERE id = ?",
            [_id],
          ),
        );
        await _reject(
          db.customStatement('UPDATE goals SET archived_at = ? WHERE id = ?', [
            _instant,
            _id,
          ]),
        );
        await _insert(db, 'time_blocks', {
          ..._rows['time_blocks']!,
          'goal_id': _id,
        });
        await _insert(db, 'rhythm_annotations', _rows['rhythm_annotations']!);
        await _reject(
          db.customStatement('UPDATE time_blocks SET id = ?', [_missingId]),
        );
        await _reject(
          db.customStatement('DELETE FROM goals WHERE id = ?', [_id]),
        );
        await _reject(
          db.customStatement('UPDATE goals SET id = ? WHERE id = ?', [
            _missingId,
            _id,
          ]),
        );
        await _insert(db, 'daily_reviews', {
          ..._rows['daily_reviews']!,
          'tomorrow_first_step_goal_id': _id,
        });
        await _insert(db, 'sleep_sessions', _rows['sleep_sessions']!);
        await db.customStatement('DELETE FROM rhythm_annotations');
        expect(await db.select(db.timeBlocks).get(), hasLength(1));
        await _insert(db, 'rhythm_annotations', _rows['rhythm_annotations']!);
        await db.customStatement('DELETE FROM time_blocks');
        expect(await db.select(db.rhythmAnnotations).get(), isEmpty);
        expect(await db.select(db.dailyReviews).get(), hasLength(1));
        expect(await db.select(db.sleepSessions).get(), hasLength(1));
        await _reject(
          db.customStatement('DELETE FROM goals WHERE id = ?', [_id]),
        );
        await _reject(
          db.customStatement('UPDATE goals SET id = ? WHERE id = ?', [
            _missingId,
            _id,
          ]),
        );
        await db.customStatement(
          "UPDATE goals SET status = 'archived', archived_at = ? WHERE id = ?",
          [_instant, _id],
        );
        expect(
          (await _row(db, 'daily_reviews'))['tomorrow_first_step_goal_id'],
          _id,
        );
        await db.customStatement('DELETE FROM daily_reviews');
        expect(await db.select(db.sleepSessions).get(), hasLength(1));
        await db.customStatement('DELETE FROM goals');
        expect(await db.select(db.goals).get(), isEmpty);
      },
};

Future<void> clearSchemaRows(AppDatabase db) => db.transaction(() async {
  for (final table in [
    'rhythm_annotations',
    'time_blocks',
    'sleep_sessions',
    'daily_reviews',
    'goals',
  ]) {
    await db.customStatement('DELETE FROM $table');
  }
});
