import 'package:flutter/foundation.dart';

import '../../../core/time/civil_date.dart';

/// 根读取入口的会话选择；null 跟随今天，不写入事实或草稿。
final class DayDateSelection extends ChangeNotifier {
  CivilDate? date;

  void select(CivilDate? value) {
    date = value;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
