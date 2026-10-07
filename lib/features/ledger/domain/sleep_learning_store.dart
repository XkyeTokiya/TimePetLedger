import 'sleep_prediction.dart';

abstract interface class SleepLearningStore {
  Future<List<SleepPredictionFeedback>> readSleepFeedback();

  /// Persist auxiliary evidence after the formal fact has committed.
  Future<void> saveSleepFeedback(SleepPredictionFeedback feedback);
}
