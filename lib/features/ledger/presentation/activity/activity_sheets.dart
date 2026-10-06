import 'package:flutter/material.dart';

import '../../../../app/theme/home_theme.dart';
import '../recording_form_controller.dart';

/// 目标选择的临时结果。`id == null` 表示“不关联”，与取消（返回 null）不同。
class ActivityGoalChoice {
  const ActivityGoalChoice(this.id);
  final String? id;
}

/// 顶部目标条的编辑入口：只调整这一笔的归属，不改常用目标或目标本身。
Future<ActivityGoalChoice?> showActivityGoalSheet(
  BuildContext context, {
  required RecordingFormController model,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<ActivityGoalChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * .7,
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          Widget row(String? id, String name) {
            final selected = model.goalId == id;
            return InkWell(
              key: ValueKey('activity-goal-${id ?? 'none'}'),
              onTap: () => Navigator.pop(sheetContext, ActivityGoalChoice(id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: homeSerifFamily,
                          fontSize: 17,
                          color: selected
                              ? HomePalette.accentDeep
                              : HomePalette.ink,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check,
                        size: 22,
                        color: HomePalette.accentDeep,
                      ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text('这笔关联哪个目标？', style: _sheetTitle),
              const SizedBox(height: 4),
              const Text('只调整这一笔。', style: _sheetHint),
              const SizedBox(height: 12),
              if (model.goalsLoading) const LinearProgressIndicator(),
              if (model.goalsError != null) ...[
                Text(model.goalsError!, style: _errorText),
                TextButton(
                  onPressed: model.loadGoals,
                  child: const Text('重试读取目标'),
                ),
              ] else if (!model.goalsLoading) ...[
                if (model.activeGoals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('还没有可关联的目标。也可以不关联，继续记录。', style: _sheetHint),
                  ),
                row(null, '不关联目标'),
                for (final goal in model.activeGoals) row(goal.id, goal.name),
              ],
            ],
          );
        },
      ),
    ),
  );
}

/// 补充内容：时间页只承接可选接续点与备注。
Future<({String hint, String note})?> showActivityDetailsSheet(
  BuildContext context, {
  required String? rhythmLabel,
  required String hint,
  required String note,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<({String hint, String note})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _DetailsSheet(rhythmLabel: rhythmLabel, hint: hint, note: note),
  );
}

class _DetailsSheet extends StatefulWidget {
  const _DetailsSheet({
    required this.rhythmLabel,
    required this.hint,
    required this.note,
  });
  final String? rhythmLabel;
  final String hint;
  final String note;

  @override
  State<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends State<_DetailsSheet> {
  late final hint = TextEditingController(text: widget.hint);
  late final note = TextEditingController(text: widget.note);
  bool errors = false;

  @override
  void dispose() {
    hint.dispose();
    note.dispose();
    super.dispose();
  }

  String? error(TextEditingController value) =>
      errors && value.text.trim().runes.length > 2000 ? '最多 2000 个字符。' : null;

  void apply() {
    setState(() => errors = true);
    if (error(hint) != null || error(note) != null) return;
    Navigator.pop(context, (hint: hint.text, note: note.text));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .72,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('再补充一点', style: _sheetTitle),
            const SizedBox(height: 4),
            const Text('都可以留空。', style: _sheetHint),
            if (widget.rhythmLabel != null) ...[
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('continuation-hint'),
                controller: hint,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: '下次从哪里接上？',
                  errorText: error(hint),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('activity-note'),
              controller: note,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: '备注',
                errorText: error(note),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('activity-details-apply'),
              onPressed: apply,
              child: const Text('保留补充'),
            ),
          ],
        ),
      ),
    ),
  );
}

const _sheetTitle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _sheetHint = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.5,
  color: HomePalette.muted,
);
const _errorText = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  color: HomePalette.error,
);
