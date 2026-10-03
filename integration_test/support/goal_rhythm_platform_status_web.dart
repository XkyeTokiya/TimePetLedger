import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportGoalRhythmPlatformPhase(int completedPhase) {
  _documentTitle = 'E7-T07 phase $completedPhase passed';
}
