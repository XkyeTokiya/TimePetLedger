import 'package:flutter/material.dart';

import 'ledger_feed_controller.dart';

/// 保留退出窗口，等新窗口定位后才启动过渡，避免绘制临时滚动位置。
class HomeFeedTransition extends StatefulWidget {
  const HomeFeedTransition({
    super.key,
    required this.frame,
    required this.builder,
  });

  final LedgerFeedFrame frame;
  final Widget Function(LedgerFeedFrame frame, VoidCallback positioned) builder;

  @override
  State<HomeFeedTransition> createState() => _HomeFeedTransitionState();
}

class _HomeFeedTransitionState extends State<HomeFeedTransition>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addStatusListener(_finished);
  late final _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
  );
  late Widget _current;
  Widget? _previous;
  LedgerFeedFrame? _previousFrame;
  bool _ready = false;
  int _generation = 0;
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    _updateCurrent();
  }

  void _updateCurrent() {
    final generation = _generation;
    _current = widget.builder(widget.frame, () => _positioned(generation));
  }

  @override
  void didUpdateWidget(HomeFeedTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frame.endDate != oldWidget.frame.endDate) {
      // 新窗口尚未定位时继续保留上一个可见窗口，快速切日不会露出空白。
      if (_ready || _previous == null) {
        _previous = _current;
        _previousFrame = oldWidget.frame;
      }
      if (_previousFrame?.endDate == widget.frame.endDate) {
        _previous = null;
        _previousFrame = null;
      }
      final a = oldWidget.frame.endDate;
      final b = widget.frame.endDate;
      _direction =
          DateTime.utc(
            b.year,
            b.month,
            b.day,
          ).isAfter(DateTime.utc(a.year, a.month, a.day))
          ? 1
          : -1;
      _generation++;
      _ready = false;
      _motion.stop();
      _motion.value = 0;
    }
    _updateCurrent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) &&
        _ready &&
        _previous != null) {
      _motion.value = 1;
    }
  }

  void _positioned(int generation) {
    if (!mounted || generation != _generation || _ready) return;
    setState(() => _ready = true);
    if (_previous == null || MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
  }

  void _finished(AnimationStatus status) {
    if (status != AnimationStatus.completed || _previous == null || !mounted) {
      return;
    }
    setState(() {
      _previous = null;
      _previousFrame = null;
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _motion.dispose();
    super.dispose();
  }

  Widget _layer(
    BuildContext context,
    Widget child,
    LedgerFeedFrame frame, {
    required bool outgoing,
  }) {
    // 失败帧不会走定位回调（onPositioned），但错误页的重试必须可点、可读屏；
    // 只有 ready 帧需要等定位完成后再接管指针。
    final interactive = _ready || frame.status == LedgerFeedStatus.failed;
    return SlideTransition(
      key: ValueKey(frame.endDate),
      position: _previous == null
          ? const AlwaysStoppedAnimation(Offset.zero)
          : Tween<Offset>(
              begin: outgoing ? Offset.zero : Offset(_direction, 0),
              end: outgoing ? Offset(-_direction, 0) : Offset.zero,
            ).animate(_curve),
      child: ClipRect(
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: IgnorePointer(
            ignoring: outgoing || !interactive,
            child: ExcludeSemantics(
              excluding: outgoing || !interactive,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (_previous case final previous?)
          _layer(context, previous, _previousFrame!, outgoing: true),
        _layer(context, _current, widget.frame, outgoing: false),
      ],
    ),
  );
}
