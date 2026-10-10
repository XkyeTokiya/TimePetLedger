import 'package:flutter/material.dart';

import '../../../core/identity/entity_id.dart';
import '../../../core/time/civil_date.dart';
import '../../goals/domain/goal.dart';
import '../../goals/domain/goal_repository.dart';
import '../../ledger/application/activity_understanding.dart';
import '../../ledger/domain/block_knowledge_state.dart';
import '../../ledger/domain/projection/day_ledger_view.dart';
import '../../ledger/domain/projection/derived_duration.dart';
import '../../ledger/domain/projection/goal_rhythm_summary.dart';
import '../../ledger/domain/projection/ledger_coverage.dart';
import '../../ledger/domain/projection/ledger_segment.dart';
import '../../ledger/domain/rhythm_state.dart';
import '../../ledger/domain/time_block.dart';
import '../../ledger/presentation/activity/goal_picker.dart';
import '../../ledger/presentation/activity/understanding_stage_widgets.dart';
import '../../ledger/presentation/summary_formatting.dart';
import '../application/review_context_loader.dart';
import '../application/review_session_service.dart';
import '../domain/daily_review.dart';
import '../domain/review_draft_store.dart';
import '../domain/review_text.dart';
import 'review_record_sheet.dart';

String _dateText(CivilDate date) =>
    '${date.year < 0 ? '-' : ''}${date.year.abs().toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _clock(int value) {
  final date = DateTime.fromMillisecondsSinceEpoch(value);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

String _duration(int startedAt, int endedAt) => formatDerivedDuration(
  DerivedDuration(milliseconds: endedAt - startedAt, hasApproximation: false),
);

String _recordTitle(TimeBlock block) =>
    block.knowledgeState == BlockKnowledgeState.unknown
    ? '想不起来'
    : (block.title ?? '未写内容');

String _stateLabel(RhythmState? state) => switch (state) {
  RhythmState.progress => '推进',
  RhythmState.stuck => '卡住',
  RhythmState.recovery => '恢复',
  null => '不判断',
};

/// 每日复盘：四步向导（整理 → 关心的事 → 卡住 → 总结）与已完成 Detail。
///
/// 与记录面板同构的一页：顶部返回 / 标题 / 步骤点，底部固定动作栏；
/// 注解与目标关联即时写入，下一步在“完成”时写入复盘本体。
class ReviewFlowPage extends StatefulWidget {
  const ReviewFlowPage({
    super.key,
    required this.loader,
    required this.session,
    required this.understanding,
    required this.drafts,
    required this.initialDate,
    this.goals,
    this.onAddRecord,
  });

  final ReviewContextLoader loader;
  final ReviewSessionService session;
  final ActivityUnderstandingService understanding;

  /// Q-012 会话快照存储；由 app 生命周期持有（SessionReviewDraftStore）。
  final ReviewDraftStore drafts;
  final GoalRepository? goals;
  final CivilDate initialDate;

  /// Gap 补记：打开活动记录面板（由 app 组装层注入），返回是否已保存。
  final Future<bool> Function(CivilDate date, UnresolvedSpan gap)? onAddRecord;

  @override
  State<ReviewFlowPage> createState() => _ReviewFlowPageState();
}

class _ReviewFlowPageState extends State<ReviewFlowPage> {
  ReviewContext? _context;
  List<Goal> _activeGoals = const [];
  String? _error;
  bool _loading = true;
  bool _busy = false;

  bool _reflow = false;
  int _step = 1;
  final _extraFocus = <EntityId>{};
  final _hiddenGaps = <String>{};
  EntityId? _stuckPick;
  bool _stuckNone = false;
  final _nextStep = TextEditingController();
  final _reason = TextEditingController();
  EntityId? _nextStepGoalId;
  EntityId? _reasonFor;
  bool _nextStepTouched = false;

  // ----- Q-012 会话快照（REVIEW-R2-14） -----
  ReviewDraft? _pendingRecovery;
  ReviewDraft? _flowBaseline;
  bool _recoveryPromptShown = false;
  bool _restoringFlow = false;
  bool _flowReadFailed = false;
  bool _allowPop = false;
  int _flowEpoch = 0;
  String? _flowStorageError;
  Future<void> _flowWrites = Future.value();

  CivilDate get _date => _context?.ledger.date ?? widget.initialDate;
  DayLedgerView get _ledger => _context!.ledger;
  List<LedgerSegment> get _segments => _ledger.segments;
  List<TimeBlockSegment> get _records =>
      _segments.whereType<TimeBlockSegment>().toList();
  List<UnresolvedSpan> get _gaps => _ledger.unresolvedSpans;
  bool get _hasReview => _context?.review != null;
  DailyReview? get _review => _context?.review;

  List<TimeBlockSegment> get _focusRecords => _records
      .where(
        (s) =>
            s.source.goalId != null ||
            s.annotation != null ||
            _extraFocus.contains(s.source.id),
      )
      .toList();

  List<GoalSummary> get _goalGroups => _ledger.goalSummaries;

  List<TimeBlockSegment> get _stuckRecords =>
      _records.where((s) => s.annotation?.state == RhythmState.stuck).toList();

  TimeBlockSegment? get _effectiveStuckPick {
    if (_stuckNone) return null;
    final stuck = _stuckRecords;
    if (stuck.isEmpty) return null;
    for (final record in stuck) {
      if (record.source.id == _stuckPick) return record;
    }
    return stuck.first;
  }

  @override
  void initState() {
    super.initState();
    _nextStep.addListener(() {
      if (_restoringFlow) return;
      if (!_nextStepTouched) {
        _nextStepTouched = true;
        setState(() {});
      }
      _persistFlow();
    });
    _reason.addListener(() {
      if (!_restoringFlow) _persistFlow();
    });
    _load();
  }

  @override
  void dispose() {
    _nextStep.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<List<Goal>> _loadGoals() async {
    final repository = widget.goals;
    if (repository == null) return const [];
    return repository.listActive();
  }

  Future<Goal> Function(String)? get _createGoal {
    final repository = widget.goals;
    if (repository == null) return null;
    return (name) => repository.create(
      id: widget.session.newId(),
      name: name,
      now: widget.session.now(),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final context = await widget.loader.load(
        date: widget.initialDate,
        now: widget.session.now(),
      );
      final goals = await _loadGoals();
      if (!mounted) return;
      setState(() {
        _context = context;
        _activeGoals = goals;
        _nextStepGoalId = context.review?.tomorrowFirstStep.goalId;
        if (!_nextStepTouched) {
          _nextStep.text = context.review?.tomorrowFirstStep.text ?? '';
        }
        _loading = false;
      });
      if (_flowContext == null) {
        await _initDetailResidualCleanup();
      } else {
        await _initNewEntryTracking();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '复盘读取失败，请重试。';
      });
    }
  }

  /// 写入后刷新同日投影与复盘，保留向导位置与已添加的关注记录。
  Future<void> _reload({bool resetNextStep = false}) async {
    try {
      final context = await widget.loader.load(
        date: _date,
        now: widget.session.now(),
      );
      final goals = await _loadGoals();
      if (!mounted) return;
      setState(() {
        _context = context;
        _activeGoals = goals;
        if (resetNextStep) {
          _nextStepTouched = false;
          _nextStep.text = context.review?.tomorrowFirstStep.text ?? '';
          _nextStepGoalId = context.review?.tomorrowFirstStep.goalId;
        }
      });
    } catch (_) {
      if (mounted) _message('刷新失败，显示的可能不是最新状态。');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _write(
    Future<void> Function() action, {
    String? notice,
    String failure = '没有保存成功，请重试。',
    bool resetNextStep = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _reload(resetNextStep: resetNextStep);
      if (notice != null) _message(notice);
    } on ActivityUnderstandingException catch (error) {
      _message(error.message);
    } on ReviewSessionException catch (error) {
      _message(error.message);
    } catch (_) {
      _message(failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----- Q-012 会话快照（REVIEW-R2-14） -----

  /// 当前向导 / 重新整理对应的会话入口；已完成 Detail 没有未完成输入。
  ReviewDraftContext? get _flowContext {
    final context = _context;
    if (context == null) return null;
    final review = context.review;
    if (_reflow) {
      return review == null
          ? null
          : ReviewDraftContext.edit(reviewId: review.id);
    }
    return review == null
        ? ReviewDraftContext.newEntry(date: context.ledger.date)
        : null;
  }

  ReviewDraft _flowDraft(ReviewDraftContext context, {required int step}) =>
      ReviewDraft(
        context: context,
        date: context.isEditing ? null : _date,
        tomorrowFirstStepText: _nextStep.text,
        tomorrowFirstStepGoalId: _nextStepGoalId,
        flowStep: step,
        extraFocusIds: _extraFocus.toList(),
        hiddenGapKeys: _hiddenGaps.toList(),
        stuckPickId: _stuckPick,
        stuckNone: _stuckNone,
        stuckReasonText: _reason.text,
        stuckReasonForId: _reasonFor,
      );

  /// 预置第 3 步原因，避免渲染同步本身造成相对基线的假修改。
  void _seedStep3Reason() {
    final pick = _effectiveStuckPick;
    _reasonFor = pick?.source.id;
    _reason.text = pick?.annotation?.stuckReasonText ?? '';
  }

  void _captureFlowBaseline({required int step}) {
    final context = _flowContext;
    _flowBaseline = context == null ? null : _flowDraft(context, step: step);
  }

  bool _sameFlow(ReviewDraft a, ReviewDraft b) =>
      a.flowStep == b.flowStep &&
      (a.tomorrowFirstStepText ?? '') == (b.tomorrowFirstStepText ?? '') &&
      a.tomorrowFirstStepGoalId == b.tomorrowFirstStepGoalId &&
      a.stuckPickId == b.stuckPickId &&
      (a.stuckNone ?? false) == (b.stuckNone ?? false) &&
      (a.stuckReasonText ?? '') == (b.stuckReasonText ?? '') &&
      a.stuckReasonForId == b.stuckReasonForId &&
      _sameIds(a.extraFocusIds, b.extraFocusIds) &&
      _sameIds(a.hiddenGapKeys, b.hiddenGapKeys);

  bool _sameIds(List<String>? a, List<String>? b) {
    final left = Set<String>.from(a ?? const []);
    final right = Set<String>.from(b ?? const []);
    return left.length == right.length && left.containsAll(right);
  }

  /// 与基线一致时清除快照，否则保存；失败保留输入并提示，离开前需确认。
  void _persistFlow() {
    final context = _flowContext;
    final baseline = _flowBaseline;
    if (_loading || _restoringFlow || _flowReadFailed) return;
    if (context == null || baseline == null) return;
    final draft = _flowDraft(context, step: _step);
    final same = _sameFlow(baseline, draft);
    final epoch = _flowEpoch;
    _flowWrites = _flowWrites.then((_) async {
      if (epoch != _flowEpoch) return;
      try {
        if (same) {
          await widget.drafts.clear(context);
        } else {
          await widget.drafts.save(draft);
        }
        if (mounted && _flowStorageError != null) {
          setState(() => _flowStorageError = null);
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _flowStorageError = '本次填写暂时无法保留，输入仍在此页，请重试。';
          });
        }
      }
    });
  }

  void _applyFlowState(ReviewDraft saved) {
    _restoringFlow = true;
    setState(() {
      _step = saved.flowStep ?? _step;
      _extraFocus
        ..clear()
        ..addAll(saved.extraFocusIds ?? const []);
      _hiddenGaps
        ..clear()
        ..addAll(saved.hiddenGapKeys ?? const []);
      _stuckPick = saved.stuckPickId;
      _stuckNone = saved.stuckNone ?? false;
      _nextStep.text = saved.tomorrowFirstStepText ?? '';
      _nextStepTouched = true;
      _nextStepGoalId = saved.tomorrowFirstStepGoalId;
      _reasonFor = saved.stuckReasonForId;
      _reason.text = saved.stuckReasonText ?? '';
    });
    _restoringFlow = false;
  }

  Future<bool?> _askRecovery({required bool editing}) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(editing ? '继续上次修改？' : '继续上次填写？'),
      content: const Text('这个入口还有本次使用期间未完成的内容。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(editing ? '重新编辑' : '重新填写'),
        ),
        FilledButton(
          key: const ValueKey('review-recovery-continue'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('继续填写'),
        ),
      ],
    ),
  );

  Future<void> _chooseRecovery({required bool editing}) async {
    final saved = _pendingRecovery;
    if (!mounted || saved == null) return;
    final resume = await _askRecovery(editing: editing);
    if (!mounted) return;
    if (resume == true) {
      _applyFlowState(saved);
      _persistFlow();
    } else {
      await _restartFlow();
    }
    if (mounted) setState(() => _pendingRecovery = null);
  }

  Future<void> _restartFlow() async {
    final context = _flowContext;
    if (context == null) return;
    try {
      await widget.drafts.clear(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _flowStorageError = '暂时无法清空本次填写，请重试。';
        });
      }
      return;
    }
    final baseline = _flowBaseline;
    if (baseline != null) {
      _applyFlowState(baseline);
    }
    if (mounted) {
      setState(() {
        _flowStorageError = null;
        _flowReadFailed = false;
      });
    }
    _flowEpoch += 1;
    _persistFlow();
  }

  Future<void> _initNewEntryTracking() async {
    final context = _flowContext;
    if (context == null || context.isEditing) return;
    _seedStep3Reason();
    _captureFlowBaseline(step: 1);
    ReviewDraft? saved;
    try {
      saved = await widget.drafts.read(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _flowReadFailed = true;
          _flowStorageError = '暂时无法恢复本次填写，请重试。';
        });
      }
      return;
    }
    if (saved != null) {
      try {
        final committed = await widget.session.recoverCommittedDraft(saved);
        if (committed != null) saved = null;
      } catch (_) {
        // 残留识别失败不阻塞向导；保留快照交给用户选择。
      }
    }
    if (!mounted) return;
    if (saved != null) {
      setState(() => _pendingRecovery = saved);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_recoveryPromptShown) {
          _recoveryPromptShown = true;
          _chooseRecovery(editing: false);
        }
      });
    }
  }

  Future<void> _initReflowTracking(int step) async {
    _seedStep3Reason();
    _captureFlowBaseline(step: step);
    final context = _flowContext;
    final review = _review;
    if (context == null || review == null) return;
    ReviewDraft? saved;
    try {
      saved = await widget.drafts.read(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _flowReadFailed = true;
          _flowStorageError = '暂时无法恢复本次填写，请重试。';
        });
      }
      return;
    }
    if (saved != null && _snapshotMatchesCommitted(saved, review)) {
      try {
        await widget.drafts.clear(context);
      } catch (_) {
        // 收尾失败不回滚；下次进入再清理。
      }
      saved = null;
    }
    if (!mounted || saved == null) return;
    final resume = await _askRecovery(editing: true);
    if (!mounted) return;
    if (resume == true) {
      _applyFlowState(saved);
      _persistFlow();
    } else {
      await _restartFlow();
    }
  }

  Future<void> _initDetailResidualCleanup() async {
    final review = _review;
    if (review == null) return;
    try {
      final saved = await widget.drafts.read(
        ReviewDraftContext.newEntry(date: _date),
      );
      if (saved != null) await widget.session.recoverCommittedDraft(saved);
    } catch (_) {
      // 详情态残留清理失败不阻塞；快照保留。
    }
  }

  bool _snapshotMatchesCommitted(ReviewDraft saved, DailyReview review) {
    String? step;
    try {
      step = normalizeReviewText(saved.tomorrowFirstStepText, 'text');
    } on ArgumentError {
      return false;
    }
    return (step ?? '') == review.tomorrowFirstStep.text &&
        saved.tomorrowFirstStepGoalId == review.tomorrowFirstStep.goalId;
  }

  void _resetFlowTracking() {
    _pendingRecovery = null;
    _flowReadFailed = false;
    _flowStorageError = null;
    _allowPop = false;
    _flowEpoch += 1;
    _seedStep3Reason();
    _captureFlowBaseline(step: _step);
  }

  void _retryFlowStorage() {
    if (_flowReadFailed) {
      _flowReadFailed = false;
      setState(() => _flowStorageError = null);
      if (_reflow) {
        _initReflowTracking(_step);
      } else {
        _initNewEntryTracking();
      }
      return;
    }
    _persistFlow();
  }

  bool get _flowLeaveBlocked => _flowStorageError != null && !_allowPop;

  Future<bool> _confirmLeaveWithoutRecovery() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('本次填写暂时无法保留'),
          content: const Text('仍然离开可能丢失最近的修改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续填写'),
            ),
            TextButton(
              key: const ValueKey('review-leave-anyway'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然离开'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmLeave() async {
    if (!mounted) return;
    final leave = await _confirmLeaveWithoutRecovery();
    if (!mounted || !leave) return;
    _allowPop = true;
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  String? _goalName(EntityId? id) {
    if (id == null) return null;
    for (final summary in _goalGroups) {
      if (summary.goalId == id) return summary.name;
    }
    for (final goal in _activeGoals) {
      if (goal.id == id) return goal.name;
    }
    return null;
  }

  // ----- 写入 -----

  Future<void> _setRhythm(TimeBlockSegment segment, String value) async {
    final block = segment.source;
    final current = segment.annotation;
    if (value == 'none') {
      if (current == null) return;
      await _write(
        () => widget.understanding.setRhythm(
          block.id,
          current: current,
          state: null,
        ),
        notice: '已移除节奏判断。',
      );
      return;
    }
    final state = RhythmState.values.byName(value);
    if (state == RhythmState.progress && block.goalId == null) {
      final goal = await showProgressGoalPicker(
        context,
        loadGoals: _loadGoals,
        createGoal: _createGoal,
      );
      if (!mounted || goal == null) return;
      await _write(() async {
        await widget.understanding.linkGoal(block.id, goal.id);
        await widget.understanding.setRhythm(
          block.id,
          current: current,
          state: RhythmState.progress,
        );
      }, notice: '已关联「${goal.name}」并记为推进。');
      return;
    }
    await _write(
      () => widget.understanding.setRhythm(
        block.id,
        current: current,
        state: state,
      ),
    );
  }

  Future<void> _linkGoal(
    TimeBlockSegment segment, {
    required bool unlink,
  }) async {
    final block = segment.source;
    if (unlink) {
      await _write(
        () => widget.understanding.linkGoal(block.id, null),
        failure: '推进中的记录必须有目标，请先改状态。',
      );
      return;
    }
    final goal = await showProgressGoalPicker(
      context,
      loadGoals: _loadGoals,
      createGoal: _createGoal,
      title: '关联目标',
      guidance: '目标只是这段时间的归属；之后可以随时改。',
    );
    if (!mounted || goal == null) return;
    await _write(
      () => widget.understanding.linkGoal(block.id, goal.id),
      notice: '已关联「${goal.name}」。',
    );
  }

  Future<void> _openRecord(TimeBlockSegment segment) async {
    final block = segment.source;
    await showReviewRecordSheet(
      context,
      date: _date,
      block: block,
      annotation: segment.annotation,
      goalName: _goalName(block.goalId),
      loadGoals: _loadGoals,
      createGoal: _createGoal,
      onLinkGoal: (goalId) => widget.understanding.linkGoal(block.id, goalId),
      onRename: (title) => widget.session.renameRecord(block.id, title),
      onRetime: (startedAt, endedAt) => widget.session.retimeRecord(
        block.id,
        startedAt: startedAt,
        endedAt: endedAt,
      ),
      onDelete: () => widget.session.deleteRecord(block.id),
    );
    if (mounted) await _reload();
  }

  Future<void> _markGapUnknown(UnresolvedSpan gap) => _write(
    () => widget.session.markGapUnknown(
      startedAt: gap.startedAt,
      endedAt: gap.endedAt,
    ),
    notice: '这段时间已记为想不起来。',
  );

  Future<void> _addRecordForGap(UnresolvedSpan gap) async {
    final add = widget.onAddRecord;
    if (add == null) {
      _message('请从首页的时间轴补记这段时间。');
      return;
    }
    final saved = await add(_date, gap);
    if (mounted && saved) await _reload();
  }

  /// 第 3 步的卡住原因：写入所选记录并保留接续点（RH-008 与复盘下一步分离）。
  Future<void> _saveStuckReason() async {
    final record = _effectiveStuckPick;
    if (record == null) return;
    final annotation = record.annotation;
    if (annotation == null) return;
    final text = _reason.text;
    if ((annotation.stuckReasonText ?? '') == text.trim()) return;
    await _write(
      () => widget.understanding.updateDetails(
        record.source.id,
        state: RhythmState.stuck,
        reasonCode: annotation.stuckReasonCode,
        reasonText: text,
        continuationHint: annotation.continuationHint,
      ),
    );
  }

  void _next() {
    final target = switch (_step) {
      1 => 2,
      2 => 3,
      _ => 4,
    };
    setState(() => _step = target);
    _persistFlow();
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step -= 1);
      _persistFlow();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _skip() async {
    await _saveStuckReason();
    if (mounted) {
      setState(() => _step = 4);
      _persistFlow();
    }
  }

  Future<void> _finish() async {
    if (_nextStep.text.trim().isEmpty) {
      setState(() => _step = 3);
      _persistFlow();
      _message('写下下次的第一步，再完成今天的回顾。');
      return;
    }
    await _saveStuckReason();
    if (!mounted) return;
    await _write(
      () => widget.session.complete(
        date: _date,
        original: _review,
        nextStep: _nextStep.text,
        nextStepGoalId: _nextStepGoalId,
      ),
      notice: '今天的回顾已保存。',
      resetNextStep: true,
    );
    if (mounted) {
      setState(() {
        _step = 1;
        _resetFlowTracking();
      });
    }
  }

  Future<void> _deleteReview() async {
    final review = _review;
    if (review == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这次回顾？'),
        content: const Text('当天的记录与节奏解释都会保留，只会移除这次回顾。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('review-delete-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _write(
      () => widget.session.deleteReview(review),
      notice: '已删除这次回顾；当天的记录保留。',
      resetNextStep: true,
    );
    if (mounted) {
      setState(() {
        _step = 1;
        _reflow = false;
        _resetFlowTracking();
      });
    }
  }

  Future<void> _reflowToStep(int step) async {
    if (_review == null) return;
    setState(() {
      _reflow = true;
      _step = step;
    });
    await _initReflowTracking(step);
  }

  // ----- 构建 -----

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope<void>(
      canPop: !_flowLeaveBlocked,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              if (_busy)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _errorBlock()
                    : _hasReview && !_reflow
                    ? _detail(colors)
                    : _wizard(colors),
              ),
              if (!_loading && _error == null && _flowStorageError != null)
                _flowNotice(),
              if (!_loading && _error == null && !(_hasReview && !_reflow))
                _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flowNotice() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _flowStorageError!,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('review-flow-retry'),
          onPressed: _busy ? null : _retryFlowStorage,
          child: Text(_flowReadFailed ? '重试恢复本次填写' : '重试保留本次填写'),
        ),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('review-back'),
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
        ),
        Expanded(
          child: Text(
            _hasReview && !_reflow ? _dateText(_date) : '每日复盘',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_hasReview && !_reflow)
          PopupMenuButton<String>(
            key: const ValueKey('review-menu'),
            tooltip: '更多',
            onSelected: (value) async {
              if (value == 'reflow') await _reflowToStep(1);
              if (value == 'delete') await _deleteReview();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                key: const ValueKey('review-reflow'),
                value: 'reflow',
                child: const Text('重新整理今天'),
              ),
              const PopupMenuItem(
                key: ValueKey('review-delete'),
                value: 'delete',
                child: Text('删除这次回顾'),
              ),
            ],
          )
        else
          _StepDots(step: _step),
      ],
    ),
  );

  Widget _errorBlock() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!),
        const SizedBox(height: 8),
        FilledButton(onPressed: _load, child: const Text('重试')),
      ],
    ),
  );

  Widget _wizard(ColorScheme colors) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasReview) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '正在重新整理这次复盘。完成或返回都不会删除已保存的内容。',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          _step == 4 ? '今天' : '${_date.month}月${_date.day}日',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(_stepTitle(), style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          _stepHint(),
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        ..._stepBody(colors),
      ],
    ),
  );

  String _stepTitle() => switch (_step) {
    1 => '整理今天',
    2 => '今天关心过的事情',
    3 => _stuckRecords.isEmpty ? '有什么想留给下次的？' : '今天哪里最难继续？',
    _ => '${_date.month}月${_date.day}日',
  };

  String _stepHint() => switch (_step) {
    1 => '不用全部处理完；缺口留在那里也随时可以再回来。',
    2 => '回头看，这些时间整体是什么状态？“不判断”＝不添加节奏解释。',
    3 => _stuckRecords.isEmpty ? '' : '选一条最值得记住的，写下当时卡在哪里。',
    _ => '看一眼今天，然后留下下次的第一步。',
  };

  List<Widget> _stepBody(ColorScheme colors) => switch (_step) {
    1 => _stepTimeline(),
    2 => _stepFocus(colors),
    3 => _stepStuck(colors),
    _ => _stepSummary(colors),
  };

  // ----- 第 1 步：整理今天 -----

  List<Widget> _stepTimeline({bool interactive = true}) {
    final items = <_TimelineItem>[
      for (final segment in _segments)
        switch (segment) {
          TimeBlockSegment() => _TimelineItem.record(segment),
          SleepSessionSegment() => _TimelineItem.sleep(segment),
        },
      for (final gap in _gaps) _TimelineItem.gap(gap),
    ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return [
      for (final item in items) ...[
        switch (item.kind) {
          _TimelineKind.record => _recordRow(item.record!),
          _TimelineKind.sleep => _sleepRow(item.sleep!),
          _TimelineKind.gap => _gapBlock(item.gap!, interactive: interactive),
        },
        const SizedBox(height: 2),
      ],
    ];
  }

  Widget _recordRow(TimeBlockSegment segment) => InkWell(
    key: ValueKey('review-record-${segment.source.id}'),
    borderRadius: BorderRadius.circular(10),
    onTap: _busy ? null : () => _openRecord(segment),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _clock(segment.source.startedAt),
              style: TextStyle(fontSize: 13, color: _muted(context)),
            ),
          ),
          Expanded(
            child: Text(
              _recordTitle(segment.source),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            _duration(segment.source.startedAt, segment.source.endedAt),
            style: TextStyle(fontSize: 13, color: _muted(context)),
          ),
        ],
      ),
    ),
  );

  Widget _sleepRow(SleepSessionSegment segment) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    child: Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            _clock(segment.source.startedAt),
            style: TextStyle(fontSize: 13, color: _muted(context)),
          ),
        ),
        const Expanded(child: Text('睡眠', style: TextStyle(fontSize: 15))),
        Text(
          _duration(segment.source.startedAt, segment.source.endedAt),
          style: TextStyle(fontSize: 13, color: _muted(context)),
        ),
      ],
    ),
  );

  Widget _gapBlock(UnresolvedSpan gap, {required bool interactive}) {
    final key = '${gap.startedAt}:${gap.endedAt}';
    final hidden = _hiddenGaps.contains(key);
    final colors = Theme.of(context).colorScheme;
    if (!interactive) {
      // Detail 里的缺口只读，不提供补记 / 想不起来 / 先留着。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                _clock(gap.startedAt),
                style: TextStyle(fontSize: 13, color: _muted(context)),
              ),
            ),
            Expanded(
              child: Text(
                '未记录',
                style: TextStyle(fontSize: 14, color: _muted(context)),
              ),
            ),
            Text(
              _duration(gap.startedAt, gap.endedAt),
              style: TextStyle(fontSize: 13, color: _muted(context)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  _clock(gap.startedAt),
                  style: TextStyle(fontSize: 13, color: _muted(context)),
                ),
              ),
              Expanded(
                child: Text(
                  '未记录',
                  style: TextStyle(fontSize: 14, color: _muted(context)),
                ),
              ),
              Text(
                _duration(gap.startedAt, gap.endedAt),
                style: TextStyle(fontSize: 13, color: _muted(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hidden)
            InkWell(
              key: ValueKey('review-gap-restore-$key'),
              onTap: _busy
                  ? null
                  : () {
                      setState(() => _hiddenGaps.remove(key));
                      _persistFlow();
                    },
              child: Text(
                '已先留着 · 点按可再处理',
                style: TextStyle(fontSize: 13, color: _muted(context)),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (widget.onAddRecord != null)
                  ActionChip(
                    key: ValueKey('review-gap-add-$key'),
                    onPressed: _busy ? null : () => _addRecordForGap(gap),
                    label: const Text('补一条记录'),
                  ),
                ActionChip(
                  key: ValueKey('review-gap-unknown-$key'),
                  onPressed: _busy ? null : () => _markGapUnknown(gap),
                  label: const Text('想不起来'),
                ),
                ActionChip(
                  key: ValueKey('review-gap-later-$key'),
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _hiddenGaps.add(key));
                          _persistFlow();
                        },
                  label: const Text('先留着'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ----- 第 2 步：今天关心过的事情（目标优先） -----

  List<Widget> _stepFocus(ColorScheme colors) {
    final records = _records;
    final remaining = records.where((s) => !_focusRecords.contains(s)).toList();
    if (_focusRecords.isEmpty) {
      return [
        Text(
          '今天还没有值得进一步理解的记录。可以从其他记录里选，也可以直接进入下一步。',
          style: TextStyle(fontSize: 14, color: _muted(context)),
        ),
        const SizedBox(height: 12),
        if (remaining.isNotEmpty) _addFocusButton(),
      ];
    }
    final groups = _goalGroups;
    final noGoal = _focusRecords.where((s) => s.source.goalId == null).toList();
    return [
      for (final group in groups) _goalCard(group),
      if (noGoal.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          '没有关联目标的记录',
          style: TextStyle(fontSize: 13, color: _muted(context)),
        ),
        const SizedBox(height: 6),
        for (final segment in noGoal) _focusRow(segment, showGoalLink: true),
      ],
      if (remaining.isNotEmpty) _addFocusButton(),
    ];
  }

  Widget _goalCard(GoalSummary group) {
    final records = _records
        .where((s) => s.source.goalId == group.goalId)
        .toList();
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatDerivedDuration(group.totalDuration.duration),
                style: TextStyle(fontSize: 13, color: _muted(context)),
              ),
            ],
          ),
          const Divider(height: 18),
          for (final segment in records)
            _focusRow(segment, showGoalLink: false),
        ],
      ),
    );
  }

  Widget _focusRow(TimeBlockSegment segment, {required bool showGoalLink}) {
    final block = segment.source;
    final goalName = _goalName(block.goalId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showGoalLink) ...[
                SizedBox(
                  width: 46,
                  child: Text(
                    _clock(block.startedAt),
                    style: TextStyle(fontSize: 13, color: _muted(context)),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  _recordTitle(block),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              Text(
                _duration(block.startedAt, block.endedAt),
                style: TextStyle(fontSize: 13, color: _muted(context)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (showGoalLink && goalName != null)
                Text(
                  goalName,
                  style: TextStyle(fontSize: 13, color: _muted(context)),
                ),
              if (showGoalLink && goalName == null)
                TextButton(
                  key: ValueKey('review-link-goal-${block.id}'),
                  onPressed: _busy
                      ? null
                      : () => _linkGoal(segment, unlink: false),
                  child: const Text('＋ 关联目标'),
                ),
              const Spacer(),
              if (!showGoalLink && goalName != null)
                Text(
                  goalName,
                  style: TextStyle(fontSize: 12, color: _muted(context)),
                ),
            ],
          ),
          SegmentedButton<String>(
            key: ValueKey('review-rhythm-${block.id}'),
            segments: const [
              ButtonSegment(value: 'progress', label: Text('推进')),
              ButtonSegment(value: 'stuck', label: Text('卡住')),
              ButtonSegment(value: 'recovery', label: Text('恢复')),
              ButtonSegment(value: 'none', label: Text('不判断')),
            ],
            selected: {segment.annotation?.state.name ?? 'none'},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (values) => _setRhythm(segment, values.single),
          ),
        ],
      ),
    );
  }

  Widget _addFocusButton() => OutlinedButton(
    key: const ValueKey('review-extra-open'),
    onPressed: _busy ? null : _openAddFocus,
    child: const Text('＋ 从今天其他记录中选择'),
  );

  Future<void> _openAddFocus() async {
    final remaining = _records
        .where((s) => !_focusRecords.contains(s))
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetContext) => Padding(
        key: const ValueKey('review-extra-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '从今天其他记录中选择',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            for (final segment in remaining) ...[
              Material(
                color: Theme.of(sheetContext).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: ValueKey('review-extra-${segment.source.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _extraFocus.add(segment.source.id));
                    _persistFlow();
                    Navigator.of(sheetContext).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_recordTitle(segment.source))),
                        Text(
                          _duration(
                            segment.source.startedAt,
                            segment.source.endedAt,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ----- 第 3 步：今天哪里最难继续 -----

  List<Widget> _stepStuck(ColorScheme colors) {
    final stuck = _stuckRecords;
    final pick = _effectiveStuckPick;
    if (pick != null && _reasonFor != pick.source.id) {
      // 渲染同步不是用户输入；避免触发快照写入。
      _restoringFlow = true;
      _reasonFor = pick.source.id;
      _reason.text = pick.annotation?.stuckReasonText ?? '';
      _restoringFlow = false;
    }
    return [
      if (stuck.isNotEmpty) ...[
        for (final record in stuck)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: UnderstandingOptionTile(
              key: ValueKey('review-stuck-${record.source.id}'),
              icon: Icons.hourglass_bottom,
              label: _recordTitle(record.source),
              description:
                  '${_clock(record.source.startedAt)} – ${_clock(record.source.endedAt)}'
                  ' · ${_duration(record.source.startedAt, record.source.endedAt)}',
              selected: pick?.source.id == record.source.id,
              onTap: _busy
                  ? null
                  : () {
                      setState(() {
                        _stuckPick = record.source.id;
                        _stuckNone = false;
                      });
                      _persistFlow();
                    },
            ),
          ),
        UnderstandingOptionTile(
          key: const ValueKey('review-stuck-none'),
          icon: Icons.check_circle_outline,
          label: '今天没有特别想记的',
          action: true,
          onTap: _busy
              ? null
              : () {
                  setState(() => _stuckNone = true);
                  _persistFlow();
                },
        ),
        const SizedBox(height: 14),
      ],
      if (pick != null) ...[
        TextField(
          key: const ValueKey('review-reason'),
          controller: _reason,
          enabled: !_busy,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '当时卡在哪里？',
            hintText: '写一句就好',
          ),
        ),
        const SizedBox(height: 14),
      ],
      TextField(
        key: const ValueKey('review-next-step'),
        controller: _nextStep,
        enabled: !_busy,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: '下次继续时，第一步是什么？',
          hintText: '比如：下次先做什么，从哪里继续',
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Text(
              _nextStepGoalId == null
                  ? '不关联目标'
                  : '目标：${_goalName(_nextStepGoalId) ?? '已归档'}',
              style: TextStyle(fontSize: 13, color: _muted(context)),
            ),
          ),
          TextButton(
            key: const ValueKey('review-next-step-goal'),
            onPressed: _busy ? null : _pickNextStepGoal,
            child: Text(_nextStepGoalId == null ? '关联目标' : '更改目标'),
          ),
          if (_nextStepGoalId != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _nextStepGoalId = null);
                      _persistFlow();
                    },
              child: const Text('清除'),
            ),
        ],
      ),
    ];
  }

  Future<void> _pickNextStepGoal() async {
    final goal = await showProgressGoalPicker(
      context,
      loadGoals: _loadGoals,
      createGoal: _createGoal,
      title: '这一步和哪个目标有关？',
      guidance: '可选；不关联也可以。',
    );
    if (!mounted || goal == null) return;
    setState(() => _nextStepGoalId = goal.id);
    _persistFlow();
  }

  // ----- 第 4 步：看一眼今天 -----

  List<Widget> _stepSummary(ColorScheme colors) {
    final ledger = _ledger;
    final byState = <RhythmState?, List<String>>{};
    for (final record in _records) {
      final state = record.annotation?.state;
      if (state == null) continue;
      (byState[state] ??= []).add(_recordTitle(record.source));
    }
    final nextStep = _nextStep.text.trim();
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            _summaryRow(
              '今天记录',
              formatDerivedDuration(ledger.accountedDuration),
            ),
            _summaryRow(
              '睡眠',
              formatSummaryDuration(
                ledger.sleepSummary.mainSleep.totalDuration,
                kind: SummaryDurationKind.mainSleep,
              ),
            ),
            _summaryRow('未知', formatDerivedDuration(ledger.unknownDuration)),
            _summaryRow(
              '仍未整理',
              formatDerivedDuration(ledger.unresolvedDuration),
            ),
          ],
        ),
      ),
      if (_goalGroups.isNotEmpty || byState.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('你关心的事情', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final group in _goalGroups)
          _summaryRow(
            group.name,
            formatDerivedDuration(group.totalDuration.duration),
          ),
        for (final state in const [
          RhythmState.progress,
          RhythmState.stuck,
          RhythmState.recovery,
        ])
          if ((byState[state] ?? const []).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _stateLabel(state),
              style: TextStyle(fontSize: 13, color: _muted(context)),
            ),
            Text(
              byState[state]!.join(' · '),
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ],
      ],
      if (nextStep.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('下次从这里继续', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            nextStep,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(value, style: TextStyle(fontSize: 14, color: _muted(context))),
      ],
    ),
  );

  // ----- 已完成 Detail -----

  Widget _detail(ColorScheme colors) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '今天 · 已回顾',
          style: TextStyle(fontSize: 13, color: _muted(context)),
        ),
        const SizedBox(height: 8),
        for (final item in _stepTimeline(interactive: false)) item,
        _detailFocus(colors),
        _detailStory(colors),
        if (_nextStep.text.trim().isNotEmpty) _detailNext(colors),
      ],
    ),
  );

  Widget _detailFocus(ColorScheme colors) {
    final focus = _focusRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Text('今天关心过的事情', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (focus.isEmpty)
          Text(
            '今天还没有标记过的记录。',
            style: TextStyle(fontSize: 14, color: _muted(context)),
          )
        else
          for (final segment in focus)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recordTitle(segment.source),
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    [
                      if (_goalName(segment.source.goalId) != null)
                        _goalName(segment.source.goalId)!,
                      _stateLabel(segment.annotation?.state),
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: _muted(context)),
                  ),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _reflowToStep(2),
            child: const Text('编辑节奏'),
          ),
        ),
      ],
    );
  }

  Widget _detailStory(ColorScheme colors) {
    TimeBlockSegment? story;
    for (final record in _stuckRecords) {
      if ((record.annotation?.stuckReasonText ?? '').trim().isNotEmpty) {
        story = record;
        break;
      }
    }
    if (story == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Text('当时卡在哪里', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${_recordTitle(story.source)} · '
          '${_clock(story.source.startedAt)} – ${_clock(story.source.endedAt)}',
          style: TextStyle(fontSize: 13, color: _muted(context)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            story.annotation!.stuckReasonText!.trim(),
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _reflowToStep(3),
            child: const Text('编辑'),
          ),
        ),
      ],
    );
  }

  Widget _detailNext(ColorScheme colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 28),
      Text('下次从这里继续', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _nextStep.text.trim(),
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _busy ? null : () => _reflowToStep(3),
          child: const Text('编辑'),
        ),
      ),
    ],
  );

  // ----- 底部动作栏 -----

  Widget _footer() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Row(
      children: [
        if (_step == 3)
          TextButton(
            key: const ValueKey('review-skip'),
            onPressed: _busy ? null : _skip,
            child: const Text('跳过'),
          ),
        Expanded(
          child: FilledButton(
            key: ValueKey(_step == 4 ? 'review-finish' : 'review-next'),
            onPressed: _busy ? null : (_step == 4 ? _finish : _next),
            child: Text(_step == 4 ? '完成今天的回顾' : '下一步'),
          ),
        ),
      ],
    ),
  );

  Color _muted(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 4; i++) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == step ? colors.primary : colors.outlineVariant,
              ),
            ),
            if (i != 4) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

enum _TimelineKind { record, sleep, gap }

class _TimelineItem {
  _TimelineItem.record(TimeBlockSegment this.record)
    : kind = _TimelineKind.record,
      sleep = null,
      gap = null;
  _TimelineItem.sleep(SleepSessionSegment this.sleep)
    : kind = _TimelineKind.sleep,
      record = null,
      gap = null;
  _TimelineItem.gap(UnresolvedSpan this.gap)
    : kind = _TimelineKind.gap,
      record = null,
      sleep = null;

  final _TimelineKind kind;
  final TimeBlockSegment? record;
  final SleepSessionSegment? sleep;
  final UnresolvedSpan? gap;

  int get startedAt => switch (kind) {
    _TimelineKind.record => record!.startedAt,
    _TimelineKind.sleep => sleep!.startedAt,
    _TimelineKind.gap => gap!.startedAt,
  };
}
