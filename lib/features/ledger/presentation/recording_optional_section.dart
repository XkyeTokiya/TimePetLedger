import 'package:flutter/material.dart';

String recordingDetailPreview(String text) {
  final value = text.trim().replaceAll('\n', ' · ');
  return value.isEmpty
      ? '未填写'
      : '${String.fromCharCodes(value.runes.take(40))}${value.runes.length > 40 ? '…' : ''}';
}

/// 只折叠展示；输入及草稿始终由活动表单的原 controller 持有。
class RecordingOptionalSection extends StatefulWidget {
  const RecordingOptionalSection({
    super.key,
    required this.id,
    required this.title,
    required this.summary,
    required this.hasContent,
    required this.hasError,
    required this.enabled,
    required this.child,
    this.expandOnEntry = false,
  });
  final String id;
  final String title;
  final String summary;
  final bool hasContent;
  final bool hasError;
  final bool enabled;
  final bool expandOnEntry;
  final Widget child;

  @override
  State<RecordingOptionalSection> createState() =>
      _RecordingOptionalSectionState();
}

class _RecordingOptionalSectionState extends State<RecordingOptionalSection> {
  late bool expanded = widget.expandOnEntry;

  @override
  void didUpdateWidget(RecordingOptionalSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.expandOnEntry && widget.expandOnEntry) {
      expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = expanded || widget.hasError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: open,
          child: OutlinedButton(
            key: ValueKey('${widget.id}-toggle'),
            onPressed: widget.enabled
                ? () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => expanded = !open);
                  }
                : null,
            child: Row(
              children: [
                Expanded(child: Text(widget.title)),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          widget.child,
        ] else if (widget.hasContent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.summary,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
