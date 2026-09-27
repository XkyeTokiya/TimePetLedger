import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import '../domain/goal_status.dart';

/// Use raw SQLite values so a REAL or non-numeric TEXT timestamp is not
/// silently converted to an integer by the driver's typed row accessor.
Goal goalFromDatabase(Map<String, Object?> row) {
  final id = row['id'];
  final name = row['name'];
  final createdAt = row['created_at'];
  final updatedAt = row['updated_at'];
  final archivedAt = row['archived_at'];
  if (id is! String ||
      name is! String ||
      createdAt is! int ||
      updatedAt is! int ||
      (archivedAt != null && archivedAt is! int)) {
    throw const GoalDataException();
  }
  final status = switch (row['status']) {
    'active' => GoalStatus.active,
    'archived' => GoalStatus.archived,
    _ => throw const GoalDataException(),
  };
  try {
    final goal = Goal.reconstitute(
      id: id,
      name: name,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt as int?,
    );
    if (goal.name != name) throw const GoalDataException();
    return goal;
  } on ArgumentError {
    throw const GoalDataException();
  }
}

GoalsCompanion goalToDatabase(Goal goal) => GoalsCompanion(
  id: Value(goal.id),
  name: Value(goal.name),
  status: Value(switch (goal.status) {
    GoalStatus.active => 'active',
    GoalStatus.archived => 'archived',
  }),
  createdAt: Value(goal.createdAt),
  updatedAt: Value(goal.updatedAt),
  archivedAt: Value(goal.archivedAt),
);
