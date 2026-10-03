import '../../../core/time/civil_date.dart';

/// Local interaction state, never evidence that a SleepSession exists.
abstract interface class SleepOpeningStore {
  /// Atomically records a successfully checked opening of this device date.
  /// True only for its first claim; failures must not look like a prior opening.
  Future<bool> claim(CivilDate date);
}

class SleepOpeningStorageException implements Exception {
  const SleepOpeningStorageException(this.cause);
  final Object cause;
  @override
  String toString() => 'Local sleep opening state is unavailable.';
}
