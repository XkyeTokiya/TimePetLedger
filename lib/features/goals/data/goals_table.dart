import 'package:drift/drift.dart';

@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get status => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get archivedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('active', 'archived'))",
    "CHECK ((status = 'active' AND archived_at IS NULL) OR "
        "(status = 'archived' AND archived_at IS NOT NULL))",
  ];
}
