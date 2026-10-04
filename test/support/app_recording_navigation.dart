import 'package:flutter_test/flutter_test.dart';

import '../features/ledger/presentation/recording_rhythm_test.dart' as form;
import 'root_navigation.dart';
export '../features/ledger/presentation/recording_rhythm_test.dart'
    show show, tap, enter, stateTap;

Future<void> textTap(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) return;
  await form.textTap(tester, text);
}
