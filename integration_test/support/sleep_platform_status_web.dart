import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportSleepPlatformPhase(int completedPhase) {
  _documentTitle = 'E5-T08 phase $completedPhase passed';
}
