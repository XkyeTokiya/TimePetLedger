import 'sleep_draft_store.dart';
import 'sleep_prediction.dart';

abstract interface class SleepLearningStore {
  Future<List<SleepPredictionFeedback>> readSleepFeedback();

  /// Auxiliary evidence and draft removal succeed together after the formal
  /// commit. Retrying this step never creates another SleepSession.
  Future<void> completeSleepDraft({
    required SleepDraftContext context,
    SleepPredictionFeedback? feedback,
  });
}
