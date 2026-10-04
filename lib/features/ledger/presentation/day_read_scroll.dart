import 'package:flutter/material.dart';

import '../../../core/time/civil_date.dart';

/// 最近七个自然日期的读取位置，只存在于当前根会话。
final class DayReadScrollSession {
  final _dates = <CivilDate, Map<String, _ReadPosition>>{};

  _ReadPosition? _read(CivilDate date, String destination) =>
      _dates[date]?[destination];

  void _write(CivilDate date, String destination, _ReadPosition position) {
    final entries = _dates.remove(date) ?? <String, _ReadPosition>{};
    entries[destination] = position;
    _dates[date] = entries;
    while (_dates.length > 7) {
      _dates.remove(_dates.keys.first);
    }
  }
}

final class _ReadPosition {
  const _ReadPosition(this.id, this.order, this.top, this.pixels);
  final Object? id;
  final int? order;
  final double top;
  final double pixels;
}

class ReadScrollAnchor extends StatelessWidget {
  const ReadScrollAnchor({
    super.key,
    required this.id,
    required this.order,
    required this.child,
  });
  final Object id;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// 使用实际可见源锚点恢复，尺寸变化或删除后不沿用旧项的像素位置。
class DayReadScrollView extends StatefulWidget {
  const DayReadScrollView({
    super.key,
    required this.date,
    required this.destination,
    required this.ready,
    required this.children,
    this.session,
    this.active = true,
    this.padding = const EdgeInsets.all(16),
  });
  final bool active;
  final EdgeInsets padding;
  final CivilDate? date;
  final String destination;
  final bool ready;
  final DayReadScrollSession? session;
  final List<Widget> children;

  @override
  State<DayReadScrollView> createState() => _DayReadScrollViewState();
}

class _DayReadScrollViewState extends State<DayReadScrollView> {
  final _localSession = DayReadScrollSession();
  DayReadScrollSession get _session => widget.session ?? _localSession;
  final _scroll = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  _ReadPosition? _pending;
  bool _restoring = false;
  Size? _layoutSize;

  List<({ReadScrollAnchor anchor, RenderBox box})> _cachedAnchors = [];

  List<({ReadScrollAnchor anchor, RenderBox box})> _anchors() => _cachedAnchors
      .where((item) => item.box.attached && item.box.hasSize)
      .toList();

  void _collectAnchors() {
    final result = <({ReadScrollAnchor anchor, RenderBox box})>[];
    void visit(Element element) {
      if (element.widget case final ReadScrollAnchor anchor) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.attached && render.hasSize) {
          result.add((anchor: anchor, box: render));
        }
      }
      element.visitChildren(visit);
    }

    _viewport.currentContext?.visitChildElements(visit);
    _cachedAnchors = result;
  }

  _ReadPosition? _capture() {
    if (!_scroll.hasClients) return null;
    final viewport = _viewport.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return null;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (final item in _anchors()) {
      final y = item.box.localToGlobal(Offset.zero).dy - top;
      if (y + item.box.size.height > 0 && y < viewport.size.height) {
        return _ReadPosition(
          item.anchor.id,
          item.anchor.order,
          y,
          _scroll.offset,
        );
      }
    }
    return _ReadPosition(null, null, 0, _scroll.offset);
  }

  void _save() {
    if (_restoring || !widget.active || !widget.ready || widget.date == null) {
      return;
    }
    final position = _capture();
    if (position != null) {
      _session._write(widget.date!, widget.destination, position);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_save);
  }

  @override
  void didUpdateWidget(DayReadScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && oldWidget.ready && oldWidget.date != null) {
      final position = _capture();
      if (position != null) {
        (oldWidget.session ?? _localSession)._write(
          oldWidget.date!,
          oldWidget.destination,
          position,
        );
      }
    }
    if ((!oldWidget.active && widget.active) ||
        oldWidget.date != widget.date ||
        oldWidget.ready != widget.ready) {
      _pending = widget.date == null
          ? null
          : _session._read(widget.date!, widget.destination);
      if (widget.active && widget.ready) _scheduleRestore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.sizeOf(context);
    MediaQuery.textScalerOf(context);
    if (widget.active && widget.ready) {
      _pending =
          _capture() ??
          (widget.date == null
              ? null
              : _session._read(widget.date!, widget.destination));
      _scheduleRestore();
    }
  }

  void _scheduleRestore() {
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !widget.active || !widget.ready) {
        _restoring = false;
        return;
      }
      _collectAnchors();
      final saved = _pending;
      var target = saved?.pixels ?? 0.0;
      if (saved?.id != null) {
        final anchors = _anchors();
        final exact = anchors.where((item) => item.anchor.id == saved!.id);
        if (exact.isNotEmpty) {
          final top =
              (_viewport.currentContext!.findRenderObject()! as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy;
          target =
              _scroll.offset +
              exact.first.box.localToGlobal(Offset.zero).dy -
              top -
              saved!.top;
        } else if (anchors.isNotEmpty && saved!.order != null) {
          anchors.sort(
            (a, b) => (a.anchor.order - saved.order!).abs().compareTo(
              (b.anchor.order - saved.order!).abs(),
            ),
          );
          final top =
              (_viewport.currentContext!.findRenderObject()! as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy;
          target =
              _scroll.offset +
              anchors.first.box.localToGlobal(Offset.zero).dy -
              top;
        }
      }
      _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
      _restoring = false;
      _pending = null;
      _save();
    });
  }

  @override
  void dispose() {
    _save();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && widget.ready) {
        _collectAnchors();
        _save();
      }
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_layoutSize != null &&
            _layoutSize != size &&
            widget.active &&
            widget.ready) {
          _pending = widget.date == null
              ? null
              : _session._read(widget.date!, widget.destination);
          _scheduleRestore();
        }
        _layoutSize = size;
        if (widget.session == null) {
          return ListView(
            key: _viewport,
            controller: _scroll,
            padding: widget.padding,
            children: widget.children,
          );
        }
        return SingleChildScrollView(
          key: _viewport,
          controller: _scroll,
          padding: widget.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.children,
          ),
        );
      },
    );
  }
}
