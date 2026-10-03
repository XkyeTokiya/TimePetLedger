import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportRhythmDetailsPlatformPhase(int completedPhase) {
  _documentTitle = 'E7-T08 phase $completedPhase passed';
}
