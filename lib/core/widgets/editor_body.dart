import 'package:flutter/material.dart';

/// Keeps the action above the platform IME; very short windows scroll it
/// with the content instead of squeezing the writing area to zero.
class EditorBody extends StatelessWidget {
  const EditorBody({
    super.key,
    required this.children,
    required this.action,
    this.status = '',
    this.accessory,
    this.prototypeSpacing = false,
  });
  final List<Widget> children;
  final Widget action;
  final String status;
  final Widget? accessory;
  final bool prototypeSpacing;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final footer = Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            prototypeSpacing ? 12 : 8,
            16,
            prototypeSpacing ? 12 : 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?accessory,
              Row(
                children: [
                  if (status.isNotEmpty)
                    Expanded(
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: action),
                ],
              ),
            ],
          ),
        );
        final compact =
            constraints.maxHeight < MediaQuery.textScalerOf(context).scale(240);
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  prototypeSpacing ? 12 : 16,
                  16,
                  16,
                ),
                children: [...children, if (compact) footer],
              ),
            ),
            if (!compact) footer,
          ],
        );
      },
    ),
  );
}
