import 'package:flutter/material.dart';

import '../../../app/theme/home_theme.dart';
import '../domain/block_knowledge_state.dart';
import '../domain/projection/derived_duration.dart';
import '../domain/projection/goal_rhythm_summary.dart';
import '../domain/projection/ledger_segment.dart';
import '../domain/rhythm_details.dart';
import '../domain/rhythm_state.dart';
import '../domain/sleep_type.dart';
import '../domain/time_precision.dart';
import 'recording_form.dart' show formatRecordingTime;
import 'recording_rhythm_input.dart' show rhythmInputLabel;
import 'summary_formatting.dart';

/// What the reader asks for after reading a committed fact.
enum LedgerDetailAction { edit, delete }

/// 记录详情页：只读已提交的完整源事实，版式按记录详情与删除第一轮原型
/// （assets/record-detail-round-one）。它不持有写入合同，编辑与删除仍由宿主
/// 的既有编辑器 / 删除服务执行；本页只负责阅读、确认与返回意图。
///
/// 编辑由本页自行压入编辑器路由（[onEdit]），详情页始终留在返回栈中：
/// 取消或保留草稿后回到原详情；只有真正提交了变更才连同详情一起退出，
/// 回到时间线。删除仍以 [LedgerDetailAction.delete] 交回宿主执行。
Future<LedgerDetailAction?> showFactDetail(
  BuildContext context, {
  required LedgerSegment segment,
  GoalSummary? goal,
  required bool canEdit,
  required bool canDelete,
  bool hasDraft = false,
  VoidCallback? onDiscardDraft,
  Future<bool> Function()? onEdit,
}) => Navigator.of(context).push<LedgerDetailAction>(
  MaterialPageRoute<LedgerDetailAction>(
    builder: (_) => FactDetailPage(
      segment: segment,
      goal: goal,
      canEdit: canEdit,
      canDelete: canDelete,
      hasDraft: hasDraft,
      onDiscardDraft: onDiscardDraft,
      onEdit: onEdit,
    ),
  ),
);

class FactDetailPage extends StatefulWidget {
  const FactDetailPage({
    super.key,
    required this.segment,
    this.goal,
    required this.canEdit,
    required this.canDelete,
    this.hasDraft = false,
    this.onDiscardDraft,
    this.onEdit,
  });

  final LedgerSegment segment;
  final GoalSummary? goal;
  final bool canEdit;
  final bool canDelete;
  final bool hasDraft;
  final VoidCallback? onDiscardDraft;

  /// 压入编辑器并在返回时告知是否提交了正式变更；详情页保持挂载。
  final Future<bool> Function()? onEdit;

  @override
  State<FactDetailPage> createState() => _FactDetailPageState();
}

class _FactDetailPageState extends State<FactDetailPage> {
  bool confirming = false;
  bool editing = false;

  Future<void> _edit() async {
    final onEdit = widget.onEdit;
    if (onEdit == null || editing) return;
    setState(() => editing = true);
    try {
      final changed = await onEdit();
      if (!mounted) return;
      // 取消或保留草稿没有提交变更：留在原详情继续阅读。
      if (changed) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => editing = false);
    }
  }

  LedgerSegment get segment => widget.segment;

  int get sourceStart => switch (segment) {
    TimeBlockSegment(:final source) => source.startedAt,
    SleepSessionSegment(:final source) => source.startedAt,
  };

  int get sourceEnd => switch (segment) {
    TimeBlockSegment(:final source) => source.endedAt,
    SleepSessionSegment(:final source) => source.endedAt,
  };

  TimePrecision get sourceStartPrecision => switch (segment) {
    TimeBlockSegment(:final source) => source.startPrecision,
    SleepSessionSegment(:final source) => source.startPrecision,
  };

  TimePrecision get sourceEndPrecision => switch (segment) {
    TimeBlockSegment(:final source) => source.endPrecision,
    SleepSessionSegment(:final source) => source.endPrecision,
  };

  @override
  Widget build(BuildContext context) => Theme(
    data: homeTheme,
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(
          key: const ValueKey('fact-detail-back'),
          onPressed: () {
            if (confirming) {
              setState(() => confirming = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(confirming ? '删除记录' : '记录详情'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: confirming ? _confirmBody() : _detailBody(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: HomePalette.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: confirming ? _confirmFooter() : _detailFooter(),
        ),
      ),
    ),
  );

  // ----- read -----

  List<Widget> _detailBody() {
    final children = <Widget>[
      Text(_eyebrow, style: _eyebrowStyle),
      const SizedBox(height: 6),
      Semantics(
        header: true,
        label: _title,
        child: SelectableText(_title, style: _heading),
      ),
      const SizedBox(height: 16),
      _durationBlock(),
      _intervalBlock(),
    ];
    switch (segment) {
      case TimeBlockSegment(:final source, :final annotation):
        if (source.knowledgeState == BlockKnowledgeState.unknown &&
            source.title != null) {
          children.add(_field('原文字', source.title!));
        }
        final goal = widget.goal;
        if (goal != null) {
          children.add(
            _field('目标', '${goal.name}${goal.isArchived ? '（已归档）' : ''}'),
          );
        }
        if (annotation != null) {
          children.add(_field('节奏', rhythmInputLabel(annotation.state)));
          if (annotation.state == RhythmState.stuck &&
              (annotation.applicableStuckReasonCode != null ||
                  annotation.applicableStuckReasonText != null)) {
            children.add(
              _field(
                '卡住的原因',
                [
                  _reasonLabel(annotation.applicableStuckReasonCode),
                  annotation.applicableStuckReasonText,
                ].whereType<String>().join(' · '),
              ),
            );
          }
          if (annotation.state == RhythmState.recovery &&
              (annotation.applicableRecoveryMethod != null ||
                  annotation.applicableRecoveryQuality != null)) {
            children.add(
              _field(
                '休息',
                [
                  _methodLabel(annotation.applicableRecoveryMethod),
                  _qualityLabel(annotation.applicableRecoveryQuality),
                ].whereType<String>().join(' · '),
              ),
            );
          }
          if (annotation.continuationHint case final hint?) {
            children.add(_field('接续点', hint));
          }
        }
        if (source.note case final note?) children.add(_field('备注', note));
      case SleepSessionSegment(:final source):
        if (source.note case final note?) children.add(_field('备注', note));
    }
    if (widget.hasDraft) {
      children.add(const SizedBox(height: 20));
      children.add(_draftNotice());
    }
    return children;
  }

  String get _eyebrow => switch (segment) {
    SleepSessionSegment() => '睡眠记录',
    TimeBlockSegment(:final source)
        when source.knowledgeState == BlockKnowledgeState.unknown =>
      '已交代这段时间',
    _ => '时间记录',
  };

  String get _title => switch (segment) {
    SleepSessionSegment(:final source) =>
      source.type == SleepType.mainSleep ? '主睡眠' : '小睡',
    TimeBlockSegment(:final source) =>
      source.knowledgeState == BlockKnowledgeState.unknown
          ? '想不起来'
          : source.title ?? '未命名记录',
  };

  Widget _durationBlock() => Container(
    padding: const EdgeInsets.only(bottom: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: HomePalette.hairline)),
    ),
    child: MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            segment is SleepSessionSegment ? '这次睡眠' : '这段时间',
            style: _labelStyle,
          ),
          const SizedBox(height: 6),
          Text(
            formatDerivedDuration(
              DerivedDuration(
                milliseconds: sourceEnd - sourceStart,
                hasApproximation:
                    sourceStartPrecision == TimePrecision.approximate ||
                    sourceEndPrecision == TimePrecision.approximate,
              ),
            ),
            key: const ValueKey('fact-detail-duration'),
            style: _durationStyle,
          ),
        ],
      ),
    ),
  );

  Widget _intervalBlock() {
    final sleep = segment is SleepSessionSegment;
    final sliced =
        sourceStart != segment.startedAt || sourceEnd != segment.endedAt;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sleep ? '完整睡眠区间' : '时间区间', style: _labelStyle),
          const SizedBox(height: 8),
          _timeLine(sleep ? '入睡' : '开始', sourceStart),
          const SizedBox(height: 6),
          _timeLine(sleep ? '醒来' : '结束', sourceEnd),
          if (sliced) ...[
            const SizedBox(height: 6),
            Text(
              '${_dateText(segment.startedAt)}时间线计入 '
              '${formatDerivedDuration(segment.duration)}',
              style: _mutedStyle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeLine(String label, int instant) => MergeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 44, child: Text(label, style: _labelStyle)),
        Expanded(
          child: SelectableText(
            '${_dateText(instant)} ${_clock(instant)}',
            style: _valueStyle,
          ),
        ),
      ],
    ),
  );

  Widget _field(String label, String text) => MergeSemantics(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HomePalette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle),
          const SizedBox(height: 6),
          SelectableText(text, style: _noteStyle),
        ],
      ),
    ),
  );

  Widget _draftNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HomePalette.tint,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('上次的修改还没保存。', style: _noteStyle),
        if (widget.onDiscardDraft != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('fact-detail-discard-draft'),
              onPressed: widget.onDiscardDraft,
              child: const Text('放弃这份草稿'),
            ),
          ),
      ],
    ),
  );

  Widget _detailFooter() => Row(
    children: [
      if (widget.canDelete)
        Expanded(
          flex: 4,
          child: TextButton(
            key: const ValueKey('fact-detail-delete'),
            onPressed: () => setState(() => confirming = true),
            style: TextButton.styleFrom(
              foregroundColor: HomePalette.accentDeep,
            ),
            child: const Text('删除'),
          ),
        ),
      if (widget.canDelete && widget.canEdit) const SizedBox(width: 12),
      if (widget.canEdit)
        Expanded(
          flex: widget.canDelete ? 6 : 1,
          child: FilledButton(
            key: const ValueKey('fact-detail-edit'),
            onPressed: editing
                ? null
                : () {
                    if (widget.onEdit != null) {
                      _edit();
                    } else {
                      Navigator.pop(context, LedgerDetailAction.edit);
                    }
                  },
            child: Text(widget.hasDraft ? '继续修改' : '编辑完整记录'),
          ),
        ),
    ],
  );

  // ----- confirm -----

  List<Widget> _confirmBody() {
    final sleep = segment is SleepSessionSegment;
    final cross = _dateOnly(sourceStart) != _dateOnly(sourceEnd);
    return [
      Text(sleep ? '睡眠记录' : '时间记录', style: _eyebrowStyle),
      const SizedBox(height: 8),
      Text(sleep ? '删除这段睡眠？' : '删除这条记录？', style: _confirmHeading),
      const SizedBox(height: 16),
      SelectableText(_title, style: _valueStyle),
      const SizedBox(height: 10),
      Text(
        '${_dateText(sourceStart)} ${_clock(sourceStart)}\n'
        '至 ${_dateText(sourceEnd)} ${_clock(sourceEnd)}',
        style: _mutedStyle,
      ),
      const SizedBox(height: 14),
      Text(sleep && cross ? '会删除整段跨夜睡眠，包括其他日期里显示的部分。' : '删除后，这段时间会重新显示为尚未记录。'),
      if (sleep && cross) ...[
        const SizedBox(height: 8),
        const Text('相关日期的时间线会随之更新。', style: _mutedStyle),
      ],
      if (widget.hasDraft) ...[
        const SizedBox(height: 8),
        const Text('这条记录未保存的修改也会一并清除。', style: _mutedStyle),
      ],
    ];
  }

  Widget _confirmFooter() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          key: const ValueKey('fact-detail-keep'),
          onPressed: () => setState(() => confirming = false),
          child: const Text('保留记录'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          key: const ValueKey('fact-detail-confirm-delete'),
          onPressed: () => Navigator.pop(context, LedgerDetailAction.delete),
          child: const Text('确认删除'),
        ),
      ),
    ],
  );

  // ----- formatting -----

  String _dateOnly(int instant) {
    final d = DateTime.fromMillisecondsSinceEpoch(instant);
    return '${d.year}-${d.month}-${d.day}';
  }

  String _dateText(int instant) {
    final d = DateTime.fromMillisecondsSinceEpoch(instant);
    final year = DateTime.fromMillisecondsSinceEpoch(sourceStart).year;
    return d.year == year
        ? '${d.month}月${d.day}日'
        : '${d.year}年${d.month}月${d.day}日';
  }

  String _clock(int instant) => formatRecordingTime(instant).split(' ').last;

  String? _reasonLabel(StuckReasonCode? value) => switch (value) {
    null => null,
    StuckReasonCode.taskTooLarge => '任务太大',
    StuckReasonCode.unclearNextStep => '不知道下一步',
    StuckReasonCode.sleepy => '困',
    StuckReasonCode.brainFog => '脑雾',
    StuckReasonCode.anxious => '焦虑',
    StuckReasonCode.interrupted => '被打断',
    StuckReasonCode.unsure => '说不清',
    StuckReasonCode.other => '其他',
  };

  String? _methodLabel(RecoveryMethod? value) => switch (value) {
    null => null,
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

  String? _qualityLabel(RecoveryQuality? value) => switch (value) {
    null => null,
    RecoveryQuality.notRecovered => '没缓过来',
    RecoveryQuality.partlyRecovered => '缓过来一些',
    RecoveryQuality.readyToContinue => '可以继续了',
  };
}

const _eyebrowStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  color: HomePalette.muted,
);
const _heading = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 30,
  height: 1.35,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _confirmHeading = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 24,
  height: 1.4,
  fontWeight: FontWeight.w600,
  color: HomePalette.ink,
);
const _durationStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 30,
  height: 1.3,
  color: HomePalette.ink,
);
const _labelStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 13,
  color: HomePalette.muted,
);
const _valueStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 18,
  height: 1.6,
  color: HomePalette.ink,
);
const _noteStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 16,
  height: 1.7,
  color: HomePalette.ink,
);
const _mutedStyle = TextStyle(
  fontFamily: homeSerifFamily,
  fontSize: 14,
  height: 1.6,
  color: HomePalette.muted,
);
