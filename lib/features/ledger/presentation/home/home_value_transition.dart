import 'package:flutter/material.dart';

/// 日期和真实时长的轻量过渡；同值重建不动画，退出文本不参与读屏。
class HomeValueTransition extends StatelessWidget {
  const HomeValueTransition({
    super.key,
    required this.value,
    required this.child,
    this.height,
  });

  final Object value;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: ClipRect(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, child.key == ValueKey(value) ? 1 : -1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (previous.isNotEmpty)
              IgnorePointer(child: ExcludeSemantics(child: previous.last)),
            ?current,
          ],
        ),
        child: KeyedSubtree(key: ValueKey(value), child: child),
      ),
    ),
  );
}
