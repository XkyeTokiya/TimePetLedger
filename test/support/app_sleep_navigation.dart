import 'package:flutter_test/flutter_test.dart';

import '../features/ledger/presentation/sleep_form_test.dart' as form;
import 'root_navigation.dart';
export '../features/ledger/presentation/sleep_form_test.dart'
    show enter, showField;

Future<void> tapText(WidgetTester tester, String text) async {
  if (await tapRootAction(tester, text)) return;
  await form.tapText(tester, text);
}
