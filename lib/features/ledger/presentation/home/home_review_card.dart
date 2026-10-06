import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../../../core/time/civil_date.dart';
import '../../../review/application/review_context_loader.dart';

/// Bottom card of the timeline tab: shows the saved review and its next-day
/// first step for the selected date, or nothing when no review exists.
class HomeReviewCard extends StatefulWidget {
  const HomeReviewCard({
    super.key,
    required this.loader,
    required this.date,
    required this.now,
    this.onOpen,
  });

  final ReviewContextLoader loader;
  final CivilDate date;
  final int Function() now;
  final VoidCallback? onOpen;

  @override
  State<HomeReviewCard> createState() => _HomeReviewCardState();
}

class _HomeReviewCardState extends State<HomeReviewCard> {
  ReviewContext? _context;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomeReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _context = null;
      _load();
    }
  }

  Future<void> _load() async {
    final date = widget.date;
    try {
      final context = await widget.loader.load(date: date, now: widget.now());
      if (mounted && widget.date == date) setState(() => _context = context);
    } catch (_) {
      // A failed read just hides the card; the timeline stays usable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _context?.review;
    if (review == null) return const SizedBox.shrink();
    final step = review.tomorrowFirstStep;
    final stepDate = '${step.intendedDate.month}月${step.intendedDate.day}日';
    return Material(
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.description_outlined,
                size: 26,
                color: HomePalette.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '复盘已保存',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: homeSerifFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: HomePalette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // A pointer to the review, not the review itself: the card
                    // must keep a predictable height so the action bar below it
                    // never gets pushed off screen.
                    Text(
                      '$stepDate第一步：${step.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: homeSerifFamily,
                        fontSize: 13,
                        height: 1.5,
                        color: HomePalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onOpen != null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Text(
                        '查看复盘',
                        style: TextStyle(
                          fontFamily: homeSerifFamily,
                          fontSize: 14,
                          color: HomePalette.accentDeep,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: HomePalette.accentDeep,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
