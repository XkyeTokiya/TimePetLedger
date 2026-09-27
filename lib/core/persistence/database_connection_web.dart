import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

Future<QueryExecutor> connectDatabase(String name) async {
  final result = await WasmDatabase.open(
    databaseName: name,
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );
  switch (result.chosenImplementation) {
    case WasmStorageImplementation.opfsShared:
    case WasmStorageImplementation.opfsLocks:
    case WasmStorageImplementation.sharedIndexedDb:
      return result.resolvedExecutor;
    case WasmStorageImplementation.unsafeIndexedDb:
    case WasmStorageImplementation.inMemory:
      // Close the rejected worker/connection instead of silently losing data.
      await result.resolvedExecutor.close();
      throw UnsupportedError('Reliable browser storage is unavailable.');
  }
}
