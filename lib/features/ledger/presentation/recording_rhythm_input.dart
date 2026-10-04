import 'package:flutter/material.dart';

import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import 'recording_form_controller.dart';
import 'recording_optional_section.dart';

String rhythmInputLabel(RhythmState? state) => switch (state) {
  null => '不标记',
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '恢复',
};

/// Optional details retain raw input when their applicable state is hidden.
class RecordingRhythmInput extends StatefulWidget {
  const RecordingRhythmInput({
    super.key,
    required this.model,
    required this.hint,
    required this.reason,
    this.showErrors = false,
  });
  final RecordingFormController model;
  final TextEditingController hint;
  final TextEditingController reason;
  final bool showErrors;

  @override
  State<RecordingRhythmInput> createState() => _RecordingRhythmInputState();
}

class _RecordingRhythmInputState extends State<RecordingRhythmInput> {
  final hintFocus = FocusNode();
  final reasonFocus = FocusNode();
  final hintKey = GlobalKey();
  final reasonKey = GlobalKey();
  bool hintVisited = false;
  bool reasonVisited = false;
  String? revealed;
  RecordingFormController get model => widget.model;
  TextEditingController get hint => widget.hint;
  TextEditingController get reason => widget.reason;
  String? get hintError =>
      widget.showErrors || hintVisited ? model.hintError : null;
  String? get reasonError =>
      widget.showErrors || reasonVisited ? model.reasonError : null;

  @override
  void initState() {
    super.initState();
    hintFocus.addListener(() {
      if (!hintFocus.hasFocus && mounted) setState(() => hintVisited = true);
    });
    reasonFocus.addListener(() {
      if (!reasonFocus.hasFocus && mounted) {
        setState(() => reasonVisited = true);
      }
    });
  }

  @override
  void didUpdateWidget(RecordingRhythmInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final error = hintError ?? reasonError;
    if (error == null) {
      revealed = null;
      return;
    }
    if (error == revealed ||
        model.titleError != null ||
        model.timeError != null ||
        model.noteError != null) {
      return;
    }
    revealed = error;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = hintError != null ? hintKey : reasonKey;
      if (target.currentContext != null) {
        await Scrollable.ensureVisible(target.currentContext!, alignment: .2);
        if (mounted) {
          (target == hintKey ? hintFocus : reasonFocus).requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    hintFocus.dispose();
    reasonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('节奏', style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 12,
          children: [
            for (final state in [null, ...RhythmState.values])
              ChoiceChip(
                key: ValueKey('rhythm-${state?.name ?? 'none'}'),
                label: Text(rhythmInputLabel(state)),
                selected: model.rhythmState == state,
                onSelected: model.editable
                    ? (_) => model.setRhythmState(state)
                    : null,
              ),
          ],
        ),
        if (model.rhythmState != null) ...[
          const SizedBox(height: 8),
          RecordingOptionalSection(
            id: 'recording-hint',
            title: '接续点',
            summary: recordingDetailPreview(model.continuationHint),
            hasContent: model.continuationHint.isNotEmpty,
            hasError: hintError != null,
            enabled: model.editable,
            child: Container(
              key: hintKey,
              child: TextField(
                key: const ValueKey('continuation-hint'),
                controller: hint,
                focusNode: hintFocus,
                readOnly: !model.editable,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onChanged: model.setContinuationHint,
                decoration: InputDecoration(
                  labelText: '接续点内容',
                  helperText: '下次回到这件事，从哪里接上？',
                  errorText: hintError,
                ),
              ),
            ),
          ),
          if (model.rhythmState == RhythmState.stuck) ...[
            const SizedBox(height: 16),
            RecordingOptionalSection(
              key: const ValueKey('stuck-details'),
              id: 'recording-stuck',
              title: '卡住细节',
              summary:
                  '${model.stuckReasonCode == null ? '未选原因' : _reason(model.stuckReasonCode!)} · ${recordingDetailPreview(model.stuckReasonText)}',
              hasContent:
                  model.stuckReasonCode != null ||
                  model.stuckReasonText.isNotEmpty,
              hasError: reasonError != null,
              enabled: model.editable,
              expandOnEntry: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('卡住原因'),
                  _choices<StuckReasonCode>(
                    'stuck-reason',
                    StuckReasonCode.values,
                    model.stuckReasonCode,
                    _reason,
                    model.setStuckReasonCode,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: reasonKey,
                    child: TextField(
                      key: const ValueKey('stuck-reason-text'),
                      controller: reason,
                      focusNode: reasonFocus,
                      readOnly: !model.editable,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onChanged: model.setStuckReasonText,
                      decoration: InputDecoration(
                        labelText: '原因说明',
                        helperText: '可以只写文字；选择“其他”也可以不补充。',
                        errorText: reasonError,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('clear-stuck-reason-text'),
                    onPressed: model.editable
                        ? () {
                            reason.clear();
                            model.setStuckReasonText('');
                          }
                        : null,
                    child: const Text('清空原因说明'),
                  ),
                ],
              ),
            ),
          ],
          if (model.rhythmState == RhythmState.recovery) ...[
            const SizedBox(height: 16),
            RecordingOptionalSection(
              key: const ValueKey('recovery-details'),
              id: 'recording-recovery',
              title: '恢复细节',
              summary:
                  '${model.recoveryMethod == null ? '未选方式' : _method(model.recoveryMethod!)} · ${model.recoveryQuality == null ? '未选效果' : _quality(model.recoveryQuality!)}',
              hasContent:
                  model.recoveryMethod != null || model.recoveryQuality != null,
              hasError: false,
              enabled: model.editable,
              expandOnEntry: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('恢复方式'),
                  _choices<RecoveryMethod>(
                    'recovery-method',
                    RecoveryMethod.values,
                    model.recoveryMethod,
                    _method,
                    model.setRecoveryMethod,
                  ),
                  const SizedBox(height: 8),
                  const Text('恢复感受'),
                  _choices<RecoveryQuality>(
                    'recovery-quality',
                    RecoveryQuality.values,
                    model.recoveryQuality,
                    _quality,
                    model.setRecoveryQuality,
                  ),
                ],
              ),
            ),
          ],
          if (model.rhythmState != RhythmState.stuck &&
              reasonError != null) ...[
            Text(
              '${model.reasonError}请切回卡住修改或清空原因说明。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: model.editable
                  ? () => model.setRhythmState(RhythmState.stuck)
                  : null,
              child: const Text('切回卡住修改原因'),
            ),
          ],
        ],
      ],
    );
  }

  Widget _choices<T extends Enum>(
    String key,
    List<T> values,
    T? selected,
    String Function(T) label,
    void Function(T?) change,
  ) => Wrap(
    spacing: 8,
    children: [
      for (final value in <T?>[null, ...values])
        ChoiceChip(
          key: ValueKey('$key-${value?.name ?? 'none'}'),
          label: Text(value == null ? '不填写' : label(value)),
          selected: selected == value,
          onSelected: model.editable ? (_) => change(value) : null,
        ),
    ],
  );
}

String _reason(StuckReasonCode code) => switch (code) {
  StuckReasonCode.taskTooLarge => '任务太大',
  StuckReasonCode.unclearNextStep => '不知道下一步',
  StuckReasonCode.sleepy => '困',
  StuckReasonCode.brainFog => '脑雾',
  StuckReasonCode.anxious => '焦虑',
  StuckReasonCode.interrupted => '被打断',
  StuckReasonCode.unsure => '说不清',
  StuckReasonCode.other => '其他',
};
String _method(RecoveryMethod method) => switch (method) {
  RecoveryMethod.walk => '散步',
  RecoveryMethod.meal => '吃饭',
  RecoveryMethod.shower => '洗澡',
  RecoveryMethod.empty => '放空',
  RecoveryMethod.entertainment => '娱乐',
  RecoveryMethod.switchTask => '切换任务',
  RecoveryMethod.breakDownTask => '拆小任务',
  RecoveryMethod.askForHelp => '寻求帮助',
  RecoveryMethod.other => '其他',
};
String _quality(RecoveryQuality quality) => switch (quality) {
  RecoveryQuality.notRecovered => '没缓过来',
  RecoveryQuality.partlyRecovered => '缓过来一些',
  RecoveryQuality.readyToContinue => '可以继续了',
};
