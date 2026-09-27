import 'package:drift/drift.dart';

@DataClassName('SleepSessionRow')
@TableIndex(name: 'idx_sleep_sessions_started_at', columns: {#startedAt})
class SleepSessions extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer()();
  TextColumn get startPrecision => text()();
  TextColumn get endPrecision => text()();
  TextColumn get sleepType => text()();
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
    "CHECK (sleep_type IN ('mainSleep', 'nap'))",
  ];
}
