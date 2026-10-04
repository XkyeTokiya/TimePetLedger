import 'package:flutter/material.dart';

class LedgerShell extends StatelessWidget {
  const LedgerShell({
    super.key,
    required this.reviewSelected,
    required this.busy,
    required this.body,
    required this.onLedger,
    required this.onReview,
    required this.onCreate,
    required this.onMore,
  });
  final bool reviewSelected;
  final bool busy;
  final Widget body;
  final VoidCallback onLedger;
  final VoidCallback? onReview;
  final VoidCallback onCreate;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: reviewSelected ? null : 48,
        title: Text(
          reviewSelected ? '按日复盘' : '日账本',
          style: reviewSelected
              ? Theme.of(context).textTheme.headlineSmall
              : const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: '更多',
            onPressed: busy ? null : onMore,
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: Material(
        color: colors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: reviewSelected ? 76 : 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _destination(
                        context,
                        '回看',
                        Icons.calendar_month_outlined,
                        !reviewSelected,
                        onLedger,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const ValueKey('root-create'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              reviewSelected ? 16 : 24,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onPressed: busy ? null : onCreate,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text('记录一笔', textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _destination(
                        context,
                        '复盘',
                        Icons.description_outlined,
                        reviewSelected,
                        onReview,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context,
    String text,
    IconData icon,
    bool selected,
    VoidCallback? action,
  ) => Semantics(
    selected: selected,
    child: TextButton(
      key: ValueKey('root-$text'),
      onPressed: busy ? null : action,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 4),
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Container(
            height: 3,
            width: 24,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}
