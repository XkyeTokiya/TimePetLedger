import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportSummaryPlatformPhase(int completedPhase) {
  _documentTitle = 'E8-T06 phase $completedPhase passed';
}
