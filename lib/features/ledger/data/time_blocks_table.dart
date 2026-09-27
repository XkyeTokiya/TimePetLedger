import 'package:drift/drift.dart';

import '../../goals/data/goals_table.dart';

@DataClassName('TimeBlockRow')
@TableIndex(name: 'idx_time_blocks_started_at', columns: {#startedAt})
@TableIndex(
  name: 'idx_time_blocks_goal_started_at',
  columns: {#goalId, #startedAt},
)
class TimeBlocks extends Table {
  TextColumn get id => text()();
  // Explicit epoch milliseconds; Drift's DateTime encoding is not used.
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer()();
  TextColumn get startPrecision => text()();
  TextColumn get endPrecision => text()();
  TextColumn get knowledgeState => text()();
  TextColumn get title => text().nullable()();
  TextColumn get goalId => text().nullable().references(
    Goals,
    #id,
    onDelete: KeyAction.restrict,
    onUpdate: KeyAction.restrict,
  )();
  TextColumn get categoryId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (started_at < ended_at)',
    "CHECK (start_precision IN ('exact', 'approximate'))",
    "CHECK (end_precision IN ('exact', 'approximate'))",
    "CHECK (knowledge_state IN ('known', 'unknown'))",
    // IS NOT NULL is essential: SQLite accepts a NULL CHECK result.
    "CHECK (knowledge_state <> 'known' OR "
        "(title IS NOT NULL AND title <> ''))",
  ];
}
