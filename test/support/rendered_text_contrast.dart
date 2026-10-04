import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Check effective text colors against pixels inside each rendered paragraph.
class RenderedTextContrast extends AccessibilityGuideline {
  const RenderedTextContrast({required this.captureKey});
  final Key captureKey;

  @override
  String get description => 'Rendered text contrast against its own surface';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    try {
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      var result = const Evaluation.pass();
      final textWidgets = find
          .byWidgetPredicate(
            (widget) => widget is Text || widget is EditableText,
          )
          .hitTestable();
      for (final element in textWidgets.evaluate()) {
        final paragraph = element.renderObject;
        final InlineSpan span;
        if (paragraph is RenderParagraph) {
          span = paragraph.text;
        } else if (paragraph is RenderEditable) {
          span = paragraph.text!;
        } else {
          continue;
        }
        final box = paragraph!;
        final style = element.widget is EditableText
            ? (element.widget as EditableText).style
            : span.style!;
        final rect = MatrixUtils.transformRect(
          box.getTransformTo(boundary),
          box.paintBounds,
        );
        if (rect.isEmpty) continue;
        final histogram = <int, int>{};
        for (
          var y = rect.top.ceil().clamp(0, image.height);
          y < rect.bottom.floor().clamp(0, image.height);
          y++
        ) {
          for (
            var x = rect.left.ceil().clamp(0, image.width);
            x < rect.right.floor().clamp(0, image.width);
            x++
          ) {
            final offset = (y * image.width + x) * 4;
            final color =
                (data.getUint8(offset + 3) << 24) |
                (data.getUint8(offset) << 16) |
                (data.getUint8(offset + 1) << 8) |
                data.getUint8(offset + 2);
            if (color == style.color!.toARGB32()) continue;
            histogram.update(color, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        if (histogram.isEmpty) {
          result += Evaluation.fail(
            '${span.toPlainText()}: text has no contrasting background',
          );
          continue;
        }
        final background = Color(
          histogram.entries.reduce((a, b) => a.value > b.value ? a : b).key,
        );
        final foreground = Color.alphaBlend(style.color!, background);
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        final ratio = ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05);
        // RenderParagraph and Flutter's guideline both use 14 when the span
        // has no explicit size.
        final fontSize = style.fontSize ?? 14;
        final minimum =
            (fontSize >= 18 ||
                (fontSize >= 14 && style.fontWeight == FontWeight.bold))
            ? 3.0
            : 4.5;
        if (ratio < minimum) {
          result += Evaluation.fail(
            '${span.toPlainText()}: rendered contrast ${ratio.toStringAsFixed(2)} < $minimum',
          );
        }
      }
      return result;
    } finally {
      image.dispose();
    }
  }
}
