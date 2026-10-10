import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 记录 / 理解面板的统一视口高度。
///
/// 同一面板的所有阶段（表单、目标、状态、补充）共用这个高度：按屏幕
/// 比例取目标高度，内容较多的阶段不被压缩，较短的阶段留白；键盘弹出时
/// 视口收缩到可用高度，内容整体上移，不会被键盘遮挡。
double activitySheetViewportHeight(BuildContext context) {
  final media = MediaQuery.of(context);
  final target = (media.size.height * .8).clamp(420.0, 760.0).toDouble();
  final available =
      media.size.height - media.padding.top - 24 - media.viewInsets.bottom;
  return math.min(target, math.max(available, 280.0));
}

/// 固定高度的面板内容框：阶段切换不再改变面板高度。
///
/// 缺省按 [activitySheetViewportHeight] 取屏幕比例；保存后的理解层传入
/// 记录面板当时的高度，使“保存 → 理解”这一步窗口也不跳动。键盘弹出时
/// 整体上移 `viewInsets`，可见视口保持不变；内容超出视口时由宿主自己的
/// 滚动容器处理。
class ActivitySheetFrame extends StatelessWidget {
  const ActivitySheetFrame({super.key, this.height, required this.child});

  /// 面板内容视口高度；为 null 时按屏幕比例计算。
  final double? height;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: (height ?? activitySheetViewportHeight(context)) + insets,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: child,
      ),
    );
  }
}
