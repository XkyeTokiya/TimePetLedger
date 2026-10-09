import 'package:flutter/material.dart';

/// 为显式样式补齐当前主题字体族。
///
/// `Text` 渲染会通过 `DefaultTextStyle` 继承主题字体，但 `TextPainter` 测量、
/// `ButtonStyle.textStyle` 与 `DefaultTextStyle` 覆写不会。字体选项（系统 /
/// 衬线）必须经该函数传导到这些位置，页面不得再写死字体族。
TextStyle withThemeFont(BuildContext context, TextStyle style) =>
    style.fontFamily != null
    ? style
    : style.copyWith(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      );
