import 'package:flutter/material.dart';

import '../../../../core/identity/entity_id.dart';
import '../../../goals/domain/goal.dart';
import '../../application/activity_understanding.dart';
import '../../domain/rhythm_annotation.dart';
import '../../domain/rhythm_details.dart';
import '../../domain/rhythm_state.dart';
import '../../domain/time_block.dart';
import 'activity_sheet_frame.dart';
import 'understanding_stage_widgets.dart';

/// 理解层的来源：刚保存的新事实，或从详情打开的修改。
enum ActivityUnderstandingMode { afterSave, edit }

/// 保存后理解页：目标（可选）→ 状态（必选）→ 补充（折叠、可留空）。
///
/// 与记录面板同构的一页（相同的标题行样式与左右内边距），由宿主放在
/// 自己的滚动容器里：新建保存后在记录面板原地切换；详情入口放进独立
/// 底部面板。只做增量写入：目标关联、节奏解释 add / edit / remove；
/// “暂时说不清”不写入任何状态。
class ActivityUnderstandingPage extends StatefulWidget {
  const ActivityUnderstandingPage({
    super.key,
    required this.mode,
    required this.recordId,
    required this.service,
    required this.loadGoals,
    this.fact,
    this.onClose,
    this.onWrote,
    this.onNotice,
  });

  final ActivityUnderstandingMode mode;
  final EntityId recordId;
  final ActivityUnderstandingService service;
  final Future<List<Goal>> Function() loadGoals;

  /// 正在解释的事实（保存后由记录面板传入；修改模式读取后填充）。
  final TimeBlock? fact;
  final VoidCallback? onClose;
  final Future<void> Function()? onWrote;
  final ValueChanged<String>? onNotice;

  @override
  State<ActivityUnderstandingPage> createState() =>
      ActivityUnderstandingPageState();
}

/// 公开状态类：宿主（记录面板 / 详情面板）在系统返回时先询问
/// [handleBack]，把返回用于“上一问”，只有首步才交给宿主关闭。
class ActivityUnderstandingPageState extends State<ActivityUnderstandingPage> {
  String _stage = 'goal';
  bool _loading = false;
  String? _loadError;
  bool _busy = false;
  String? _writeError;
  List<Goal>? _goals;
  bool _goalsLoading = false;
  String? _goalsError;
  EntityId? _goalId;
  TimeBlock? _fact;
  RhythmAnnotation? _annotation;
  RhythmState? _state;
  StuckReasonCode? _reasonCode;
  final _reasonText = TextEditingController();
  final _hint = TextEditingController();
  RecoveryMethod? _method;
  RecoveryQuality? _quality;
  bool _foldReason = false;
  bool _foldHint = false;
  bool _skippedGoal = false;

  bool get _editing => widget.mode == ActivityUnderstandingMode.edit;
  bool get _canClose => _editing || _stage == 'goal' || _skippedGoal;

  /// 系统返回 / 鼠标后退：在理解层内退回上一问。
  ///
  /// 状态 → 目标、补充 → 状态；已在第一步（目标）时返回 false，
  /// 由宿主决定收起面板。写入进行中不离开当前页。
  bool handleBack() {
    if (_busy) return true;
    switch (_stage) {
      case 'status':
        setState(() {
          _stage = 'goal';
          _skippedGoal = false;
          _writeError = null;
        });
        return true;
      case 'details':
        setState(() {
          _stage = 'status';
          _writeError = null;
        });
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fact = widget.fact;
    _loadGoals();
    if (_editing) _loadRecord();
  }

  @override
  void dispose() {
    _reasonText.dispose();
    _hint.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() {
      _goalsLoading = true;
      _goalsError = null;
    });
    try {
      final goals = await widget.loadGoals();
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _goalsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _goalsError = '目标读取失败，请重试。';
        _goalsLoading = false;
      });
    }
  }

  Future<void> _loadRecord() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await widget.service.load(widget.recordId);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _loadError = '记录已不存在，请刷新后重试。';
          _loading = false;
        });
        return;
      }
      final annotation = data.annotation;
      setState(() {
        _fact = data.timeBlock;
        _goalId = data.timeBlock.goalId;
        _annotation = annotation;
        _state = annotation?.state;
        _reasonCode = annotation?.stuckReasonCode;
        _reasonText.text = annotation?.stuckReasonText ?? '';
        _hint.text = annotation?.continuationHint ?? '';
        _method = annotation?.recoveryMethod;
        _quality = annotation?.recoveryQuality;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _message(error);
        _loading = false;
      });
    }
  }

  // ----- 写入 -----

  Future<void> _pickGoal(EntityId? id) async {
    if (_busy) return;
    // 从上一问返回后重复点击同一目标：不再重复写入，直接进入状态问题。
    if (id == _goalId) {
      setState(() {
        _stage = 'status';
        _writeError = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _writeError = null;
    });
    try {
      await widget.service.linkGoal(widget.recordId, id);
      if (!mounted) return;
      setState(() {
        _goalId = id;
        _busy = false;
        _stage = 'status';
      });
      await widget.onWrote?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _writeError = _message(error);
      });
    }
  }

  Future<void> _unlinkGoal() async {
    if (!_editing) {
      _close();
      return;
    }
    if (_goalId != null) {
      await _pickGoal(null);
    } else {
      setState(() {
        _stage = 'status';
        _skippedGoal = true;
        _writeError = null;
      });
    }
  }

  void _skipGoal() {
    setState(() {
      _stage = 'status';
      _skippedGoal = true;
      _writeError = null;
    });
  }

  Future<void> _pickState(RhythmState? state) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _writeError = null;
    });
    try {
      if (state == null) {
        final hadAnnotation = _annotation != null;
        if (hadAnnotation) {
          await widget.service.setRhythm(
            widget.recordId,
            current: _annotation,
            state: null,
          );
        }
        if (!mounted) return;
        await widget.onWrote?.call();
        widget.onNotice?.call(
          hadAnnotation ? '已移除节奏判断，事实保留。' : '已跳过判断；之后随时可以从详情补充。',
        );
        _close();
        return;
      }
      final updated = await widget.service.setRhythm(
        widget.recordId,
        current: _annotation,
        state: state,
      );
      if (!mounted) return;
      setState(() {
        _annotation = updated;
        _state = state;
        _stage = 'details';
        _reasonCode = updated?.stuckReasonCode;
        _reasonText.text = updated?.stuckReasonText ?? '';
        _hint.text = updated?.continuationHint ?? '';
        _method = updated?.recoveryMethod;
        _quality = updated?.recoveryQuality;
        _foldReason = false;
        _foldHint = false;
        _busy = false;
      });
      await widget.onWrote?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _writeError = _message(error);
      });
    }
  }

  Future<void> _finishDetails() async {
    final state = _state;
    if (state == null || _busy) return;
    setState(() {
      _busy = true;
      _writeError = null;
    });
    try {
      await widget.service.updateDetails(
        widget.recordId,
        state: state,
        reasonCode: state == RhythmState.stuck ? _reasonCode : null,
        reasonText: state == RhythmState.stuck ? _reasonText.text : null,
        recoveryMethod: state == RhythmState.recovery ? _method : null,
        recoveryQuality: state == RhythmState.recovery ? _quality : null,
        continuationHint: _hint.text,
      );
      if (!mounted) return;
      await widget.onWrote?.call();
      widget.onNotice?.call('已更新。');
      _close();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _writeError = _message(error);
      });
    }
  }

  void _close() => widget.onClose?.call();

  String _message(Object error) =>
      error is ActivityUnderstandingException ? error.message : '暂时没有保存成功，请重试。';

  // ----- 构建 -----

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        if (_fact != null) ...[
          const SizedBox(height: 10),
          UnderstandingFactSummary(fact: _fact!),
        ],
        const SizedBox(height: 12),
        UnderstandingStepBar(stage: _stage),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          _errorBlock(_loadError!)
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            // 旧一帧立即移除，只淡入新一帧：避免两阶段同时布局造成卡顿。
            layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
            child: Column(
              key: ValueKey(_stage),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _body(),
            ),
          ),
      ],
    );
  }

  /// 与记录面板同构的标题行（大标题 + 关闭）。
  Widget _header() => Row(
    children: [
      Expanded(
        child: Text(
          _editing ? '补充理解' : '记录已保存',
          key: const ValueKey('understanding-title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (_canClose)
        IconButton(
          key: const ValueKey('understanding-close'),
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.close),
          tooltip: '关闭',
        ),
    ],
  );

  List<Widget> _body() => [
    if (_writeError != null) ...[
      _errorBlock(_writeError!),
      const SizedBox(height: 8),
    ],
    ...switch (_stage) {
      'goal' => _goalStage(),
      'status' => _statusStage(),
      _ => _detailsStage(),
    },
  ];

  List<Widget> _goalStage() => [
    _stageTitle('这段时间和某个目标有关吗？', '选一个目标；不选也能继续。'),
    const SizedBox(height: 12),
    if (_goalsLoading)
      const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      )
    else if (_goalsError != null)
      Row(
        children: [
          Expanded(child: Text(_goalsError!)),
          TextButton(onPressed: _loadGoals, child: const Text('重试')),
        ],
      )
    else ...[
      for (final goal in _goals ?? const <Goal>[]) ...[
        UnderstandingOptionTile(
          key: ValueKey('understanding-goal-${goal.id}'),
          icon: Icons.flag_outlined,
          label: goal.name,
          selected: _goalId == goal.id,
          onTap: _busy ? null : () => _pickGoal(goal.id),
        ),
        const SizedBox(height: 8),
      ],
    ],
    const SizedBox(height: 4),
    UnderstandingOptionTile(
      key: const ValueKey('understanding-skip-goal'),
      icon: Icons.link_off,
      label: '不关联目标',
      description: '直接判断状态',
      action: true,
      onTap: _busy ? null : _skipGoal,
    ),
    const SizedBox(height: 4),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const ValueKey('understanding-unlink'),
        onPressed: _busy ? null : _unlinkGoal,
        child: Text(_editing && _goalId != null ? '取消关联' : '先不判断，收起'),
      ),
    ),
  ];

  List<Widget> _statusStage() => [
    _stageTitle('回头看，这段时间整体是什么状态？', '需要选一个；之后仍可从详情补充。'),
    const SizedBox(height: 12),
    for (final state in RhythmState.values) ...[
      UnderstandingOptionTile(
        key: ValueKey('understanding-state-${state.name}'),
        icon: _stateIcon(state),
        label: _stateLabel(state),
        description: _stateDescription(state),
        selected: _state == state,
        onTap: _busy ? null : () => _pickState(state),
      ),
      const SizedBox(height: 8),
    ],
    const SizedBox(height: 2),
    UnderstandingOptionTile(
      key: const ValueKey('understanding-state-unsure'),
      icon: Icons.help_outline,
      label: '暂时说不清',
      description: '先不判断，之后随时可补',
      action: true,
      onTap: _busy ? null : () => _pickState(null),
    ),
  ];

  List<Widget> _detailsStage() {
    final state = _state!;
    return [
      _stageTitle(
        '已选：${_stateLabel(state)} · 补充（都可以留空）',
        '选填；再点一次可以取消选择，之后仍可从详情修改。',
      ),
      const SizedBox(height: 14),
      if (state == RhythmState.stuck) ...[
        _sectionLabel('卡住的原因'),
        const SizedBox(height: 8),
        UnderstandingOptionGrid(
          children: [
            for (final code in StuckReasonCode.values)
              UnderstandingCompactOption(
                key: ValueKey('understanding-reason-${code.name}'),
                icon: _reasonIcon(code),
                label: _reasonLabel(code),
                selected: _reasonCode == code,
                onTap: _busy
                    ? null
                    : () => setState(
                        () => _reasonCode = _reasonCode == code ? null : code,
                      ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        UnderstandingNoteCard(
          key: const ValueKey('understanding-fold-reason'),
          icon: Icons.sticky_note_2_outlined,
          label: '补充说明',
          open: _foldReason,
          value: _reasonText.text,
          onTap: () => setState(() => _foldReason = !_foldReason),
          child: _noteField(
            key: const ValueKey('understanding-reason-text'),
            controller: _reasonText,
            hint: '比如：数据库设计一直改来改去',
          ),
        ),
      ],
      if (state == RhythmState.recovery) ...[
        _sectionLabel('恢复的方式'),
        const SizedBox(height: 8),
        UnderstandingOptionGrid(
          children: [
            for (final method in RecoveryMethod.values)
              UnderstandingCompactOption(
                key: ValueKey('understanding-method-${method.name}'),
                icon: _methodIcon(method),
                label: _methodLabel(method),
                selected: _method == method,
                onTap: _busy
                    ? null
                    : () => setState(
                        () => _method = _method == method ? null : method,
                      ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionLabel('现在的感受'),
        const SizedBox(height: 8),
        UnderstandingOptionGrid(
          children: [
            for (final quality in RecoveryQuality.values)
              UnderstandingCompactOption(
                key: ValueKey('understanding-quality-${quality.name}'),
                icon: _qualityIcon(quality),
                label: _qualityLabel(quality),
                selected: _quality == quality,
                onTap: _busy
                    ? null
                    : () => setState(
                        () => _quality = _quality == quality ? null : quality,
                      ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      UnderstandingNoteCard(
        key: const ValueKey('understanding-fold-hint'),
        icon: Icons.bookmark_added_outlined,
        label: '下次从哪儿接上？',
        open: _foldHint,
        value: _hint.text,
        onTap: () => setState(() => _foldHint = !_foldHint),
        child: _noteField(
          key: const ValueKey('understanding-hint'),
          controller: _hint,
          hint: '想留一句时再写',
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: const ValueKey('understanding-finish'),
        onPressed: _busy ? null : _finishDetails,
        child: Text(_busy ? '正在保存' : '完成'),
      ),
    ];
  }

  /// 补充卡展开后的输入框：圆角填充样式，与卡片一致。
  Widget _noteField({
    required Key key,
    required TextEditingController controller,
    required String hint,
  }) => TextField(
    key: key,
    controller: controller,
    enabled: !_busy,
    minLines: 2,
    maxLines: 4,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  /// 分组小标题（补充页内的“卡住的原因 / 恢复的方式 / 现在的感受”）。
  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: _mutedColor,
    ),
  );

  /// 阶段小标题：问题一行 + 一句说明。
  Widget _stageTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(fontSize: 13, color: _mutedColor)),
    ],
  );

  Color get _mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;

  Widget _errorBlock(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      key: const ValueKey('understanding-error'),
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

/// 详情页入口：底部面板承载同一页理解内容（修改模式）。
///
/// 系统返回 / 鼠标后退先交给理解页退回上一问，首步才关闭面板。
Future<void> showActivityUnderstandingSheet(
  BuildContext context, {
  required ActivityUnderstandingService service,
  required EntityId recordId,
  required Future<List<Goal>> Function() loadGoals,
  Future<void> Function()? onWrote,
  ValueChanged<String>? onNotice,
}) {
  final pageKey = GlobalKey<ActivityUnderstandingPageState>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (pageKey.currentState?.handleBack() == true) return;
        Navigator.of(sheetContext).pop();
      },
      child: ActivitySheetFrame(
        key: const ValueKey('understanding-sheet-frame'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ActivityUnderstandingPage(
            key: pageKey,
            mode: ActivityUnderstandingMode.edit,
            recordId: recordId,
            service: service,
            loadGoals: loadGoals,
            onWrote: onWrote,
            onNotice: onNotice,
            onClose: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ),
  );
}

String _stateLabel(RhythmState state) => switch (state) {
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '恢复',
};

IconData _stateIcon(RhythmState state) => switch (state) {
  RhythmState.progress => Icons.trending_up,
  RhythmState.stuck => Icons.hourglass_bottom,
  RhythmState.recovery => Icons.self_improvement,
};

String _stateDescription(RhythmState state) => switch (state) {
  RhythmState.progress => '有进展，在往前走',
  RhythmState.stuck => '停住了，推不动',
  RhythmState.recovery => '在休息或缓过来',
};

IconData _reasonIcon(StuckReasonCode value) => switch (value) {
  StuckReasonCode.taskTooLarge => Icons.unfold_more,
  StuckReasonCode.unclearNextStep => Icons.alt_route,
  StuckReasonCode.sleepy => Icons.bedtime_outlined,
  StuckReasonCode.brainFog => Icons.cloud_outlined,
  StuckReasonCode.anxious => Icons.psychology_outlined,
  StuckReasonCode.interrupted => Icons.notifications_paused_outlined,
  StuckReasonCode.unsure => Icons.help_outline,
  StuckReasonCode.other => Icons.more_horiz,
};

IconData _methodIcon(RecoveryMethod value) => switch (value) {
  RecoveryMethod.walk => Icons.directions_walk,
  RecoveryMethod.meal => Icons.restaurant_outlined,
  RecoveryMethod.shower => Icons.shower_outlined,
  RecoveryMethod.empty => Icons.air,
  RecoveryMethod.entertainment => Icons.sports_esports_outlined,
  RecoveryMethod.switchTask => Icons.swap_horiz,
  RecoveryMethod.breakDownTask => Icons.call_split,
  RecoveryMethod.askForHelp => Icons.handshake_outlined,
  RecoveryMethod.other => Icons.more_horiz,
};

IconData _qualityIcon(RecoveryQuality value) => switch (value) {
  RecoveryQuality.notRecovered => Icons.sentiment_dissatisfied_outlined,
  RecoveryQuality.partlyRecovered => Icons.sentiment_neutral_outlined,
  RecoveryQuality.readyToContinue => Icons.sentiment_satisfied_outlined,
};

String _reasonLabel(StuckReasonCode value) => switch (value) {
  StuckReasonCode.taskTooLarge => '任务太大',
  StuckReasonCode.unclearNextStep => '不知道下一步',
  StuckReasonCode.sleepy => '困',
  StuckReasonCode.brainFog => '脑雾',
  StuckReasonCode.anxious => '焦虑',
  StuckReasonCode.interrupted => '被打断',
  StuckReasonCode.unsure => '说不清',
  StuckReasonCode.other => '其他',
};

String _methodLabel(RecoveryMethod value) => switch (value) {
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

String _qualityLabel(RecoveryQuality value) => switch (value) {
  RecoveryQuality.notRecovered => '没缓过来',
  RecoveryQuality.partlyRecovered => '缓过来一些',
  RecoveryQuality.readyToContinue => '可以继续了',
};
