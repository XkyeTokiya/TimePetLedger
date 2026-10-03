import 'package:flutter/material.dart';

import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import 'recording_form_controller.dart';

String rhythmInputLabel(RhythmState? state) => switch (state) {
  null => '不标记',
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '恢复',
};

/// Optional details retain raw input when their applicable state is hidden.
class RecordingRhythmInput extends StatelessWidget {
  const RecordingRhythmInput({
    super.key,
    required this.model,
    required this.hint,
    required this.reason,
  });
  final RecordingFormController model;
  final TextEditingController hint;
  final TextEditingController reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('节奏解释（可选）'),
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
          TextField(
            key: const ValueKey('continuation-hint'),
            controller: hint,
            readOnly: !model.editable,
            minLines: 1,
            maxLines: 5,
            onChanged: model.setContinuationHint,
            decoration: InputDecoration(
              labelText: '接续点（可选）',
              helperText: '下次回到这件事，从哪里接上？',
              errorText: model.hintError,
            ),
          ),
          if (model.rhythmState == RhythmState.stuck) ...[
            const Text('卡住原因（可选，单选）'),
            _choices<StuckReasonCode>(
              'stuck-reason',
              StuckReasonCode.values,
              model.stuckReasonCode,
              _reason,
              model.setStuckReasonCode,
            ),
            TextField(
              key: const ValueKey('stuck-reason-text'),
              controller: reason,
              readOnly: !model.editable,
              minLines: 1,
              maxLines: 5,
              onChanged: model.setStuckReasonText,
              decoration: InputDecoration(
                labelText: '原因说明（可选）',
                helperText: '可以只写文字；选择“其他”也可以不补充。',
                errorText: model.reasonError,
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
          if (model.rhythmState == RhythmState.recovery) ...[
            const Text('恢复方式（可选，单选）'),
            _choices<RecoveryMethod>(
              'recovery-method',
              RecoveryMethod.values,
              model.recoveryMethod,
              _method,
              model.setRecoveryMethod,
            ),
            const Text('恢复效果（可选，主观感受）'),
            _choices<RecoveryQuality>(
              'recovery-quality',
              RecoveryQuality.values,
              model.recoveryQuality,
              _quality,
              model.setRecoveryQuality,
            ),
          ],
          if (model.rhythmState != RhythmState.stuck &&
              model.reasonError != null)
            Text('${model.reasonError}请切回卡住修改或清空原因说明。'),
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
