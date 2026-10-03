import 'package:flutter/material.dart';

import '../features/goals/domain/goal_repository.dart';
import '../features/review/application/review_context_loader.dart';
import '../features/review/application/review_entry_saver.dart';
import '../features/review/domain/review_draft_store.dart';
import '../features/review/presentation/review_context_page.dart';

import '../features/ledger/application/day_ledger_loader.dart';
import '../features/ledger/presentation/day_ledger_page.dart';
import '../features/ledger/presentation/day_summary_page.dart';
import '../features/ledger/domain/projection/ledger_segment.dart';

import 'time/device_recording_date.dart';
import '../features/ledger/application/sleep_first_open.dart';

import '../core/time/civil_date.dart';
import '../features/ledger/application/recording_entry_saver.dart';
import '../features/ledger/application/recording_entry_editor.dart';
import '../features/ledger/application/recording_ledger_loader.dart';
import '../features/ledger/application/recording_time_suggestion.dart';
import '../features/ledger/application/sleep_ledger_loader.dart';
import '../features/ledger/presentation/sleep_summary_view.dart';
import '../features/ledger/domain/block_knowledge_state.dart';
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/sleep_draft_store.dart';
import '../features/ledger/domain/sleep_session.dart';
import '../features/ledger/domain/sleep_type.dart';
import '../features/ledger/domain/time_block.dart';
import '../features/ledger/domain/time_precision.dart';
import '../features/ledger/presentation/recording_form.dart';
import '../features/ledger/presentation/summary_formatting.dart';

String _recordingBoundary(int value, TimePrecision precision) =>
    '${precision == TimePrecision.approximate ? '约' : ''}${formatRecordingTime(value)}';

String _recordingTitle(TimeBlock block) =>
    block.knowledgeState == BlockKnowledgeState.unknown
    ? block.title == null
          ? '想不起来'
          : '想不起来 · ${block.title}'
    : block.title!;

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.ledger,
    required this.drafts,
    required this.now,
    required this.entrySaver,
    required this.entryEditor,
    required this.sleepEntry,
    required this.sleepLedger,
    this.firstSleepOpen,
    this.dayLedger,
    this.reviewContext,
    this.reviewDrafts,
    this.reviewSaver,
    this.goalEntry,
    this.goals,
  });
  final Widget Function()? goalEntry;
  final GoalRepository? goals;
  final DayLedgerLoader? dayLedger;
  final ReviewContextLoader? reviewContext;
  final ReviewDraftStore? reviewDrafts;
  final ReviewEntrySaver? reviewSaver;
  final RecordingLedgerLoader ledger;
  final SleepLedgerLoader sleepLedger;
  final SleepFirstOpenCoordinator? firstSleepOpen;
  final RecordingDraftStore drafts;
  final DateTime Function() now;
  final RecordingEntrySaver entrySaver;
  final RecordingEntryEditor entryEditor;
  final Widget Function(SleepDraftContext) sleepEntry;
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _dayRoutes = RouteObserver<ModalRoute<void>>();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Time Pet Ledger',
    navigatorObservers: [_dayRoutes],
    home: _RecordingHome(
      goals: widget.goals,
      goalEntry: widget.goalEntry,
      dayLedger: widget.dayLedger,
      reviewContext: widget.reviewContext,
      reviewDrafts: widget.reviewDrafts,
      reviewSaver: widget.reviewSaver,
      dayRoutes: _dayRoutes,
      ledger: widget.ledger,
      drafts: widget.drafts,
      now: widget.now,
      entrySaver: widget.entrySaver,
      entryEditor: widget.entryEditor,
      sleepEntry: widget.sleepEntry,
      sleepLedger: widget.sleepLedger,
      firstSleepOpen: widget.firstSleepOpen,
    ),
  );
}

class _RecordingHome extends StatefulWidget {
  const _RecordingHome({
    required this.ledger,
    required this.drafts,
    required this.now,
    required this.entrySaver,
    required this.entryEditor,
    required this.sleepEntry,
    required this.sleepLedger,
    required this.firstSleepOpen,
    required this.dayLedger,
    required this.reviewContext,
    required this.reviewDrafts,
    required this.reviewSaver,
    required this.dayRoutes,
    required this.goalEntry,
    required this.goals,
  });
  final Widget Function()? goalEntry;
  final GoalRepository? goals;
  final DayLedgerLoader? dayLedger;
  final ReviewContextLoader? reviewContext;
  final ReviewDraftStore? reviewDrafts;
  final ReviewEntrySaver? reviewSaver;
  final RouteObserver<ModalRoute<void>> dayRoutes;
  final RecordingLedgerLoader ledger;
  final SleepLedgerLoader sleepLedger;
  final SleepFirstOpenCoordinator? firstSleepOpen;
  final RecordingDraftStore drafts;
  final DateTime Function() now;
  final RecordingEntrySaver entrySaver;
  final RecordingEntryEditor entryEditor;
  final Widget Function(SleepDraftContext) sleepEntry;
  @override
  State<_RecordingHome> createState() => _RecordingHomeState();
}

class _RecordingHomeState extends State<_RecordingHome>
    with WidgetsBindingObserver {
  late final dateText = TextEditingController(
    text: formatRecordingTime(widget.now().millisecondsSinceEpoch)
        .split(' ')
        .first,
  );
  String? error;
  String? refreshError;
  String? deleteError;
  String? firstSleepError;
  bool _checkingSleep = false;
  CivilDate? _sleepCheckDate;
  RecordingLedger? view;
  SleepLedger? sleepView;
  ({RecordingDraftContext context, RecordingDeleteCommitted result})?
  pendingDelete;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstSleep());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkFirstSleep();
  }

  Future<void> _checkSleepOnReturn() async {
    if (deviceDateOfInstant(widget.now().millisecondsSinceEpoch) !=
        _sleepCheckDate) {
      await _checkFirstSleep();
    }
  }

  Future<void> _checkFirstSleep() async {
    final coordinator = widget.firstSleepOpen;
    if (!mounted ||
        coordinator == null ||
        _checkingSleep ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _checkingSleep = true;
    final instant = widget.now().millisecondsSinceEpoch;
    final today = deviceDateOfInstant(instant);
    _sleepCheckDate = today;
    setState(() => firstSleepError = null);
    try {
      final result = await coordinator.check(date: today, now: instant);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        return;
      }
      if (parseRecordingDate(dateText.text) == today) {
        setState(() {
          view = null;
          sleepView = result.ledger;
        });
      }
      if (!result.shouldConfirm) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认主睡眠'),
          content: const Text('今天几点醒来？请确认主睡眠的入睡和醒来时间。已有睡眠输入会继续保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('继续账本'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确认睡眠起止'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        setState(() {
          dateText.text =
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          view = null;
          sleepView = null;
        });
        await _openSleep(date: today);
      }
    } catch (_) {
      if (mounted) {
        setState(() => firstSleepError = '主睡眠确认检查失败；可继续记账，或重试检查。');
      }
    } finally {
      _checkingSleep = false;
      if (mounted &&
          deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        _checkFirstSleep();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    dateText.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    final result = await Navigator.of(context).push<RecordingLedger>(
      MaterialPageRoute<RecordingLedger>(
        builder: (_) => RecordingForm(
          goals: widget.goals,
          context: RecordingDraftContext.newEntry(date: date),
          store: widget.drafts,
          entrySaver: widget.entrySaver,
          loadSuggestion: () async {
            final view = await widget.ledger.load(
              date: date,
              now: widget.now().millisecondsSinceEpoch,
            );
            return suggestRecordingTime(
              relation: view.context.relation,
              coverage: view.coverage,
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        view = result;
        refreshError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存到账本。')));
    } else {
      await _reload(date);
    }
    await _checkSleepOnReturn();
  }

  Future<void> _openSleep({CivilDate? date}) async {
    final selectedDate = date ?? parseRecordingDate(dateText.text);
    if (selectedDate == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    final result = await Navigator.of(context).push<SleepLedger>(
      MaterialPageRoute<SleepLedger>(
        builder: (_) =>
            widget.sleepEntry(SleepDraftContext.newEntry(date: selectedDate)),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        view = null;
        sleepView = result;
        refreshError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('睡眠已保存到账本。')));
    } else {
      await _reload(selectedDate);
    }
    await _checkSleepOnReturn();
  }

  Future<void> _editSleep(SleepSession sleep) async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) return;
    final result = await Navigator.of(context).push<SleepLedger>(
      MaterialPageRoute(
        builder: (_) => widget.sleepEntry(
          SleepDraftContext.edit(date: date, sleepSessionId: sleep.id),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        view = null;
        sleepView = result;
        refreshError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('睡眠更改已应用。')));
    } else {
      await _reload(date);
    }
    await _checkSleepOnReturn();
  }

  Future<void> _reload(CivilDate date) async {
    try {
      final reloaded = await widget.sleepLedger.load(
        date: date,
        now: widget.now().millisecondsSinceEpoch,
      );
      if (mounted) {
        setState(() {
          view = null;
          sleepView = reloaded;
          refreshError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          view = null;
          sleepView = null;
          refreshError = '账本读取失败，请稍后重试。';
        });
      }
    }
  }

  Future<void> _openSummary() async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    final today = deviceDateOfInstant(widget.now().millisecondsSinceEpoch);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DaySummaryPage(
          loader: widget.dayLedger!,
          now: () => widget.now().millisecondsSinceEpoch,
          dateOfInstant: deviceDateOfInstant,
          routeObserver: widget.dayRoutes,
          initialDate: date == today ? null : date,
          reviewEntry: widget.reviewContext == null ? null : _reviewPage,
        ),
      ),
    );
    if (mounted) await _checkSleepOnReturn();
  }

  Future<void> _openReview() async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => _reviewPage(date)));
    if (mounted) await _checkSleepOnReturn();
  }

  Widget _reviewPage(CivilDate date) => ReviewContextPage(
    loader: widget.reviewContext!,
    drafts: widget.reviewDrafts,
    saver: widget.reviewSaver,
    goals: widget.goals,
    now: () => widget.now().millisecondsSinceEpoch,
    dateOfInstant: deviceDateOfInstant,
    routeObserver: widget.dayRoutes,
    initialDate: date,
  );

  Future<void> _openDay() async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    final today = deviceDateOfInstant(widget.now().millisecondsSinceEpoch);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DayLedgerPage(
          loader: widget.dayLedger!,
          now: () => widget.now().millisecondsSinceEpoch,
          dateOfInstant: deviceDateOfInstant,
          routeObserver: widget.dayRoutes,
          initialDate: date == today ? null : date,
          reviewEntry: widget.reviewContext == null ? null : _reviewPage,
          recordingEditor: widget.entryEditor,
          factEntry: (selectedDate, segment) => switch (segment) {
            TimeBlockSegment(:final source) => RecordingForm(
              goals: widget.goals,
              context: RecordingDraftContext.edit(
                date: selectedDate,
                timeBlockId: source.id,
              ),
              store: widget.drafts,
              entryEditor: widget.entryEditor,
              loadSuggestion: () async => const ManualTimeEntry(),
            ),
            SleepSessionSegment(:final source) => widget.sleepEntry(
              SleepDraftContext.edit(
                date: selectedDate,
                sleepSessionId: source.id,
              ),
            ),
          },
          gapEntry: (draftContext, gap) => RecordingForm(
            goals: widget.goals,
            context: draftContext,
            store: widget.drafts,
            entrySaver: widget.entrySaver,
            loadSuggestion: () async {
              final ledger = await widget.ledger.load(
                date: draftContext.date,
                now: widget.now().millisecondsSinceEpoch,
              );
              return suggestRecordingTime(
                relation: ledger.context.relation,
                coverage: ledger.coverage,
                explicitGap: gap,
              );
            },
          ),
        ),
      ),
    );
    if (mounted) await _checkSleepOnReturn();
  }

  Future<void> _view() async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) {
      setState(() => error = '请输入有效日期 YYYY-MM-DD。');
      return;
    }
    setState(() => error = null);
    await _reload(date);
  }

  Future<void> _edit(TimeBlock block) async {
    final date = parseRecordingDate(dateText.text);
    if (date == null) return;
    final result = await Navigator.of(context).push<RecordingLedger>(
      MaterialPageRoute<RecordingLedger>(
        builder: (_) => RecordingForm(
          goals: widget.goals,
          context: RecordingDraftContext.edit(
            date: date,
            timeBlockId: block.id,
          ),
          store: widget.drafts,
          entryEditor: widget.entryEditor,
          loadSuggestion: () async => const ManualTimeEntry(),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        view = result;
        refreshError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('更正已保存到账本。')));
    } else {
      await _reload(date);
    }
    await _checkSleepOnReturn();
  }

  Future<void> _delete(TimeBlock block) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除时间记录'),
        content: const Text('删除此记录时，依附的节奏解释也会删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除记录'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final date = parseRecordingDate(dateText.text);
    if (date == null) return;
    final draftContext = RecordingDraftContext.edit(
      date: date,
      timeBlockId: block.id,
    );
    final result = await widget.entryEditor.delete(draftContext);
    if (!mounted) return;
    switch (result) {
      case RecordingDeleteFailed():
        setState(() => deleteError = '删除失败，记录未改变，请重试。');
      case RecordingDeleteCommitted():
        _showDeleteResult(draftContext, result);
    }
  }

  void _showDeleteResult(
    RecordingDraftContext draftContext,
    RecordingDeleteCommitted result,
  ) {
    setState(() {
      if (result.refreshed == null) {
        view = null;
        sleepView = null;
      } else if (parseRecordingDate(dateText.text) == draftContext.date) {
        view = result.refreshed;
      }
      pendingDelete = result.complete
          ? null
          : (context: draftContext, result: result);
      deleteError = result.complete
          ? null
          : !result.draftCleared && result.refreshed == null
          ? '记录已删除，但草稿清理和账本刷新失败；请继续处理。'
          : result.refreshed == null
          ? '记录已删除，但账本刷新失败；请继续刷新。'
          : '记录已删除，但编辑草稿清理失败；请继续清理。';
    });
    if (result.complete) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('记录已删除。')));
    }
  }

  Future<void> _finishDelete() async {
    final pending = pendingDelete;
    if (pending == null) return;
    final result = await widget.entryEditor.finishDelete(
      context: pending.context,
      draftCleared: pending.result.draftCleared,
    );
    if (mounted) _showDeleteResult(pending.context, result);
  }

  @override
  Widget build(BuildContext context) {
    final facts = view?.facts ?? sleepView?.facts.windowFacts;
    final coverage = view?.coverage ?? sleepView?.coverage;
    return Scaffold(
      appBar: AppBar(title: const Text('时间账本')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: dateText,
            onChanged: (_) => setState(() {
              view = null;
              sleepView = null;
              refreshError = null;
            }),
            decoration: InputDecoration(
              labelText: '查看日期',
              hintText: 'YYYY-MM-DD',
              errorText: error,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(onPressed: _open, child: const Text('补一笔')),
              OutlinedButton(onPressed: _openSleep, child: const Text('记录睡眠')),
              OutlinedButton(onPressed: _view, child: const Text('查看记录')),
              if (widget.dayLedger != null)
                OutlinedButton(onPressed: _openDay, child: const Text('打开日账本')),
              if (widget.dayLedger != null)
                OutlinedButton(
                  onPressed: _openSummary,
                  child: const Text('打开基础摘要'),
                ),
              if (widget.reviewContext != null)
                OutlinedButton(
                  onPressed: _openReview,
                  child: const Text('打开按日复盘'),
                ),
              if (widget.goalEntry != null)
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => widget.goalEntry!(),
                      ),
                    );
                    if (mounted) await _checkSleepOnReturn();
                  },
                  child: const Text('打开目标'),
                ),
            ],
          ),
          if (refreshError != null) Text(refreshError!),
          if (firstSleepError != null) ...[
            Text(firstSleepError!),
            TextButton(
              onPressed: _checkFirstSleep,
              child: const Text('重试主睡眠检查'),
            ),
          ],
          if (deleteError != null) Text(deleteError!),
          if (pendingDelete != null)
            TextButton(onPressed: _finishDelete, child: const Text('继续清理并刷新')),
          if (facts != null && coverage != null) ...[
            const SizedBox(height: 16),
            Text('已交代 ${formatDerivedDuration(coverage.accountedDuration)}'),
            Text('其中未知 ${formatDerivedDuration(coverage.unknownDuration)}'),
            Text('待补记 ${formatDerivedDuration(coverage.unresolvedDuration)}'),
            Text('本窗口普通记录 ${facts.timeBlocks.length} 条'),
            if (facts.sleepSessions.isNotEmpty)
              Text('本窗口睡眠记录 ${facts.sleepSessions.length} 条'),
            for (final sleep in facts.sleepSessions.where(
              (record) =>
                  !(sleepView?.facts.sleepSummaryCandidates.any(
                        (candidate) => candidate.id == record.id,
                      ) ??
                      false),
            ))
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        sleep.type == SleepType.mainSleep
                            ? '主睡眠（跨日原始记录）'
                            : '小睡（原始记录）',
                      ),
                      subtitle: Text(
                        '${_recordingBoundary(sleep.startedAt, sleep.startPrecision)} → ${_recordingBoundary(sleep.endedAt, sleep.endPrecision)}',
                      ),
                    ),
                    TextButton(
                      key: ValueKey('sleep-edit-${sleep.id}'),
                      onPressed: () => _editSleep(sleep),
                      child: const Text('更正 / 删除'),
                    ),
                  ],
                ),
              ),
            for (final block in facts.timeBlocks)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(_recordingTitle(block)),
                      subtitle: Text(
                        '${_recordingBoundary(block.startedAt, block.startPrecision)} → ${_recordingBoundary(block.endedAt, block.endPrecision)}',
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          key: ValueKey('edit-${block.id}'),
                          onPressed: () => _edit(block),
                          child: const Text('更正'),
                        ),
                        TextButton(
                          key: ValueKey('delete-${block.id}'),
                          onPressed: () => _delete(block),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          if (sleepView case final sleep?)
            SleepSummaryView(summary: sleep.sleepSummary, onEdit: _editSleep),
        ],
      ),
    );
  }
}
