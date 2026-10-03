import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportRecordingPlatformPhase(int completedPhase) {
  _documentTitle = 'E4-T08 phase $completedPhase passed';
}
