import 'dart:js_interop';

@JS('document.title')
external set _documentTitle(String value);

void reportDayLedgerPlatformPhase(int completedPhase) {
  _documentTitle = 'E6-T06 phase $completedPhase passed';
}
