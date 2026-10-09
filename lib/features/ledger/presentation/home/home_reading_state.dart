import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/time/civil_date.dart';

final class HomeReadPosition {
  const HomeReadPosition(this.date, this.instant, this.relativeY);
  final CivilDate date;
  final int instant;
  final double relativeY;
}

enum HomeHeaderState { expanded, collapsed }

/// 只有真实的纵向阅读手势进入该状态机。程序定位、布局补偿、
/// 刷新与回弹不得伪造收起 / 回展（Q-042）。
final class HomeReadingState extends ChangeNotifier {
  HomeReadingState({required TickerProvider vsync})
    : _animation = AnimationController(
        vsync: vsync,
        duration: _transitionDuration,
      ) {
    _animation.addListener(notifyListeners);
  }

  static const _transitionDuration = Duration(milliseconds: 200);
  final AnimationController _animation;
  double _downwardDistance = 0;
  bool _gestureActive = false;
  double? _animationTarget;
  HomeReadPosition? _origin;
  HomeReadPosition? get origin => _origin;
  void rememberOrigin(HomeReadPosition? position) => _origin ??= position;
  HomeHeaderState get state =>
      progress == 1 ? HomeHeaderState.collapsed : HomeHeaderState.expanded;
  double get progress => _animation.value;
  bool get isAnimating => _animation.isAnimating;

  void reset() {
    _origin = null;
    _downwardDistance = 0;
    _gestureActive = false;
    _animationTarget = null;
    _animation.stop();
    _animation.value = 0;
  }

  void beginUserRead() {
    _animation.stop();
    _animationTarget = null;
    _gestureActive = true;
    if (progress == 0) {
      _downwardDistance = 0;
    } else if (progress < 1) {
      _downwardDistance = 40 + progress * 80;
    }
  }

  /// [fingerUp] 指手指方向。时间轴是断点在视口下沿的纸带：
  /// 向下拖读取更早内容，累计40 / 120dp收起顶部。紧凑态的
  /// 同日上拖不在这里回展；日期横线到达时间轴窗口顶部后由
  /// [expandForDayDividerAtTop] 单独提交。
  void updateUserRead({required bool fingerUp, required double distance}) {
    if (!_gestureActive || distance <= 0) return;
    if (_animationTarget == 0 && _animation.isAnimating) return;
    if (progress == 1) return;
    if (fingerUp) {
      if (progress > 0) _animateTo(1);
    } else {
      _animation.stop();
      _animationTarget = null;
      _downwardDistance += distance;
      _animation.value = ((_downwardDistance - 40) / 80).clamp(0.0, 1.0);
    }
  }

  void endUserRead() {
    _gestureActive = false;
    if (_animationTarget == 0) return;
    if (progress > 0 && progress < 1) _animateTo(1);
  }

  /// 仅该次上拖（含松手后的同次惯性）使日期横线到达
  /// 时间轴窗口顶部时开始连续回展。
  void expandForDayDividerAtTop() {
    _downwardDistance = 0;
    if (progress > 0) _animateTo(0);
  }

  void _animateTo(double target) {
    if (progress == target) return;
    _animationTarget = target;
    final milliseconds =
        (_transitionDuration.inMilliseconds * (target - progress).abs())
            .round()
            .clamp(1, _transitionDuration.inMilliseconds);
    _animation.animateTo(
      target,
      duration: Duration(milliseconds: milliseconds),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}
