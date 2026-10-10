import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeToast;

/// 顶部轻提示：短暂停留后自动消失。
///
/// 传入 [anchor] 时贴在锚点（通常为时间轴区域）顶部，避免占用状态栏与
/// 日期行；未传时退回安全区下方。同一时间只保留一条。
void showTopToast(BuildContext context, String message, {GlobalKey? anchor}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final previous = _activeToast;
  if (previous != null) {
    _activeToast = null;
    if (previous.mounted) previous.remove();
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      anchor: anchor,
      onDone: () {
        if (identical(_activeToast, entry)) _activeToast = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  const _TopToast({required this.message, required this.onDone, this.anchor});

  final String message;
  final VoidCallback onDone;
  final GlobalKey? anchor;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 1800), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final anchorContext = widget.anchor?.currentContext;
    final box = anchorContext?.findRenderObject();
    final double top;
    if (box is RenderBox && box.attached) {
      top = box.localToGlobal(Offset.zero).dy + 10;
    } else {
      top = media.padding.top + 72;
    }
    return Positioned(
      top: top.clamp(media.padding.top + 8, media.size.height - 120),
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: _controller,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -.35), end: Offset.zero)
                  .animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: Semantics(
                liveRegion: true,
                label: widget.message,
                child: Material(
                  key: const ValueKey('top-toast'),
                  color: colors.inverseSurface,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
