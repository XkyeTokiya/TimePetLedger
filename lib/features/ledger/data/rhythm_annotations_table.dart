import 'package:drift/drift.dart';

import 'time_blocks_table.dart';

@DataClassName('RhythmAnnotationRow')
class RhythmAnnotations extends Table {
  TextColumn get id => text()();
  TextColumn get timeBlockId => text().unique().references(
    TimeBlocks,
    #id,
    onDelete: KeyAction.cascade,
    onUpdate: KeyAction.restrict,
  )();
  TextColumn get state => text()();
  TextColumn get stuckReasonCode => text().nullable()();
  TextColumn get stuckReasonText => text().nullable()();
  TextColumn get recoveryMethod => text().nullable()();
  TextColumn get recoveryQuality => text().nullable()();
  TextColumn get continuationHint => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (state IN ('progress', 'stuck', 'recovery'))",
    "CHECK (stuck_reason_code IN ('taskTooLarge', 'unclearNextStep', "
        "'sleepy', 'brainFog', 'anxious', 'interrupted', 'unsure', 'other'))",
    "CHECK (recovery_method IN ('walk', 'meal', 'shower', 'empty', "
        "'entertainment', 'switchTask', 'breakDownTask', 'askForHelp', 'other'))",
    "CHECK (recovery_quality IN "
        "('notRecovered', 'partlyRecovered', 'readyToContinue'))",
    // Optional codes may be NULL. Q-005 preserves details across state changes.
  ];
}
