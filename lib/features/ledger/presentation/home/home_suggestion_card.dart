import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../../application/home_suggestion.dart';
import 'home_value_transition.dart';

/// 首页建议区域：随情境给出当前最该做的一件事，或普通问候（Q-028 / Q-029）。
///
/// 只呈现已由 application 解析出的建议；不读取时钟、账本或偏好。
class HomeSuggestionCard extends StatelessWidget {
  const HomeSuggestionCard({
    super.key,
    required this.suggestion,
    this.onAction,
  });

  final HomeSuggestion suggestion;

  /// 记录睡眠 / 补记一笔 / 开始复盘入口；问候为 null。
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = suggestion.action;
    return Material(
      key: const ValueKey('home-suggestion-card'),
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        alignment: Alignment.bottomCenter,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: action == null ? null : onAction,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: HomeValueTransition(
              value: (suggestion.kind, suggestion.title, action),
              child: KeyedSubtree(
                key: ValueKey('home-suggestion-${suggestion.kind.name}'),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final large =
                        MediaQuery.textScalerOf(context).scale(16) > 24 &&
                        constraints.maxWidth < 400;
                    if (large) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _iconFor(suggestion.kind),
                                size: 26,
                                color: HomePalette.accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  suggestion.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: HomePalette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (action != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      action,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: HomePalette.accentDeep,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: HomePalette.accentDeep,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _iconFor(suggestion.kind),
                          size: 26,
                          color: HomePalette.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: homeSerifFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: HomePalette.ink,
                            ),
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            action,
                            style: const TextStyle(
                              fontFamily: homeSerifFamily,
                              fontSize: 14,
                              color: HomePalette.accentDeep,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: HomePalette.accentDeep,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(HomeSuggestionKind kind) => switch (kind) {
    HomeSuggestionKind.sleep => Icons.bedtime_outlined,
    HomeSuggestionKind.record => Icons.edit_outlined,
    HomeSuggestionKind.review => Icons.description_outlined,
    HomeSuggestionKind.greeting => Icons.wb_sunny_outlined,
  };
}
