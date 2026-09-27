import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

Future<QueryExecutor> connectDatabase(String name) async {
  return driftDatabase(name: name);
}
