import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportReviewPlatformPhase(int completedPhase) {
  _documentTitle = 'E9-T09 phase $completedPhase passed';
}
