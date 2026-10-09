import 'package:flutter/foundation.dart';

import '../../../../core/time/civil_date.dart';

final class HomeReadPosition {
  const HomeReadPosition(this.date, this.instant, this.relativeY);
  final CivilDate date;
  final int instant;
  final double relativeY;
}

enum HomeHeaderState { expanded, collapsed }

/// Only effective user reading events call updateDistance. Restoration and
/// programmatic positioning never enter this state machine (Q-039).
final class HomeReadingState extends ChangeNotifier {
  HomeHeaderState _state = HomeHeaderState.expanded;
  double _progress = 0;
  HomeReadPosition? _origin;
  HomeReadPosition? get origin => _origin;
  void rememberOrigin(HomeReadPosition? position) => _origin ??= position;
  HomeHeaderState get state => _state;
  double get progress => _progress;

  void reset() {
    _origin = null;
    if (_state == HomeHeaderState.expanded && _progress == 0) return;
    _state = HomeHeaderState.expanded;
    _progress = 0;
    notifyListeners();
  }

  void updateDistance(double distance) {
    final d = distance.abs();
    final previousState = _state;
    final previousProgress = _progress;
    if (_state == HomeHeaderState.collapsed) {
      if (d <= 32) {
        _state = HomeHeaderState.expanded;
        _progress = 0;
      }
    } else if (d >= 120) {
      _state = HomeHeaderState.collapsed;
      _progress = 1;
    } else {
      _progress = ((d - 40) / 80).clamp(0.0, 1.0);
    }
    if (_state != previousState || _progress != previousProgress) {
      notifyListeners();
    }
  }
}
