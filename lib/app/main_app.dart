import 'package:flutter/material.dart';

import 'theme/home_theme.dart';
import '../features/ledger/presentation/day_date_selection.dart';
import '../features/ledger/presentation/day_read_scroll.dart';
import '../features/ledger/domain/sleep_session.dart';

import '../features/goals/domain/goal_repository.dart';
import '../features/review/application/review_context_loader.dart';
import '../features/review/application/review_entry_saver.dart';
import '../features/review/domain/review_draft_store.dart';
import '../features/review/presentation/review_context_page.dart';

import '../features/ledger/application/day_ledger_loader.dart';
import '../features/ledger/presentation/day_ledger_controller.dart';
import '../features/ledger/presentation/home/home_menu_page.dart';
import '../features/ledger/presentation/home/home_review_card.dart';
import '../features/ledger/presentation/home/home_shell.dart';
import '../features/ledger/presentation/home/home_summary_tab.dart';
import '../features/ledger/presentation/home/home_timeline_tab.dart';
import '../features/ledger/domain/projection/ledger_coverage.dart';
import '../features/ledger/domain/projection/ledger_segment.dart';

import 'time/device_recording_date.dart';
import '../features/ledger/application/sleep_first_open.dart';

import '../core/time/civil_date.dart';
import '../features/ledger/application/recording_entry_saver.dart';
import '../features/ledger/application/recording_entry_editor.dart';
import '../features/ledger/application/recording_ledger_loader.dart';
import '../features/ledger/application/recording_time_suggestion.dart';
import '../features/ledger/application/sleep_ledger_loader.dart';
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/sleep_draft_store.dart';
import '../features/ledger/presentation/activity/activity_recording_entry.dart';

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
    this.settingsEntry,
    this.goals,
  });
  final Widget Function()? goalEntry;
  final Widget Function()? settingsEntry;
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
    theme: homeTheme,
    navigatorObservers: [_dayRoutes],
    home: _RecordingHome(
      goals: widget.goals,
      goalEntry: widget.goalEntry,
      settingsEntry: widget.settingsEntry,
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
    required this.settingsEntry,
    required this.goals,
  });
  final Widget Function()? goalEntry;
  final Widget Function()? settingsEntry;
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
    with WidgetsBindingObserver, RouteAware {
  final selection = DayDateSelection();
  final homeShellKey = GlobalKey<HomeShellState>();
  final scrollSession = DayReadScrollSession();
  bool opening = false;
  bool ledgerInteraction = false;
  bool reviewInteraction = false;
  bool checkingSleep = false;
  CivilDate? sleepCheckDate;
  CivilDate? pendingSleepConfirmation;
  String? firstSleepError;
  ModalRoute<void>? route;

  bool get busy => opening || ledgerInteraction || reviewInteraction;
  CivilDate get selectedDate =>
      selection.date ??
      deviceDateOfInstant(widget.now().millisecondsSinceEpoch);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstSleep());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context);
    if (route != current) {
      widget.dayRoutes.unsubscribe(this);
      route = current;
      if (current != null) widget.dayRoutes.subscribe(this, current);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkFirstSleep();
  }

  @override
  void didPopNext() => WidgetsBinding.instance.addPostFrameCallback(
    (_) => _checkSleepOnReturn(),
  );

  Future<void> _checkSleepOnReturn() async {
    if (!mounted || busy || route?.isCurrent != true) return;
    final today = deviceDateOfInstant(widget.now().millisecondsSinceEpoch);
    if (pendingSleepConfirmation == today) {
      await _checkFirstSleep();
    } else if (today != sleepCheckDate) {
      await _checkFirstSleep();
    }
  }

  Future<void> _checkFirstSleep() async {
    final coordinator = widget.firstSleepOpen;
    if (!mounted ||
        coordinator == null ||
        checkingSleep ||
        busy ||
        route?.isCurrent != true) {
      return;
    }
    checkingSleep = true;
    final instant = widget.now().millisecondsSinceEpoch;
    final today = deviceDateOfInstant(instant);
    sleepCheckDate = today;
    setState(() => firstSleepError = null);
    try {
      final result = await coordinator.check(date: today, now: instant);
      if (!mounted ||
          deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        return;
      }
      if (result.ledger.recordedMainSleepToday == true) {
        pendingSleepConfirmation = null;
      }
      if (result.shouldConfirm) pendingSleepConfirmation = today;
      if (!busy &&
          route?.isCurrent == true &&
          pendingSleepConfirmation == today) {
        await _showSleepConfirmation(today);
      }
    } catch (_) {
      if (mounted) setState(() => firstSleepError = '主睡眠确认检查失败；可继续记账，或重试检查。');
    } finally {
      checkingSleep = false;
      if (mounted &&
          deviceDateOfInstant(widget.now().millisecondsSinceEpoch) != today) {
        _checkFirstSleep();
      }
    }
  }

  Future<void> _showSleepConfirmation(CivilDate today) async {
    if (!mounted || busy || route?.isCurrent != true) return;
    pendingSleepConfirmation = null;
    setState(() => opening = true);
    try {
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
      if (confirm == true && mounted) await _pushSleep(today);
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
      }
    }
  }

  void _interaction(bool value, {required bool review}) {
    if (!mounted) return;
    setState(() {
      if (review) {
        reviewInteraction = value;
      } else {
        ledgerInteraction = value;
      }
    });
    if (!value) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkSleepOnReturn(),
      );
    }
  }

  Widget _activity(CivilDate date) => ActivityRecordingEntry(
    goals: widget.goals,
    context: RecordingDraftContext.newEntry(date: date),
    store: widget.drafts,
    entrySaver: widget.entrySaver,
    loadSuggestion: () async {
      final ledger = await widget.ledger.load(
        date: date,
        now: widget.now().millisecondsSinceEpoch,
      );
      return suggestRecordingTime(
        relation: ledger.context.relation,
        coverage: ledger.coverage,
      );
    },
  );

  Future<void> _pushSleep(CivilDate date) async {
    final result = await Navigator.of(context).push<SleepLedger>(
      MaterialPageRoute(
        builder: (_) =>
            widget.sleepEntry(SleepDraftContext.newEntry(date: date)),
      ),
    );
    if (mounted && result != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('睡眠已保存到账本。')));
    }
  }

  Future<void> _recordActivity() async {
    if (busy) return;
    final date = selectedDate;
    setState(() => opening = true);
    try {
      final result = await Navigator.of(context).push<RecordingLedger>(
        MaterialPageRoute(builder: (_) => _activity(date)),
      );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存到账本。')));
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  Future<void> _recordSleep() async {
    if (busy) return;
    final date = selectedDate;
    setState(() => opening = true);
    try {
      await _pushSleep(date);
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  /// 菜单入口：进入独立「菜单」整页（只有我的目标 / 设置）。
  ///
  /// 账本自身的刷新与时间分布说明不再占用菜单，改由首页正文承接。
  Future<void> _menu() async {
    if (busy) return;
    setState(() => opening = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => HomeMenuPage(
            goalsPage: widget.goalEntry,
            settingsPage: widget.settingsEntry,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  Widget _reviewPage(CivilDate date, {required bool active}) =>
      ReviewContextPage(
        loader: widget.reviewContext!,
        drafts: widget.reviewDrafts,
        saver: widget.reviewSaver,
        goals: widget.goals,
        now: () => widget.now().millisecondsSinceEpoch,
        dateOfInstant: deviceDateOfInstant,
        routeObserver: widget.dayRoutes,
        initialDate: date,
        selection: selection,
        embedded: true,
        active: active,
        scrollSession: scrollSession,
        onInteraction: (value) => _interaction(value, review: true),
      );

  Widget _ledgerTimeline(DayLedgerController controller, bool active) =>
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HomeTimelineTab(
          view: controller.view,
          scrollSession: scrollSession,
          // While an editor or modal is on top the list is not the active
          // reading surface; on return it restores the saved anchor.
          active: active && !busy,
          placeholder: switch (controller.status) {
            DayLedgerStatus.failed => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('账本读取失败。'),
                TextButton(
                  onPressed: busy ? null : controller.refresh,
                  child: const Text('重试读取'),
                ),
              ],
            ),
            DayLedgerStatus.empty => const Text('这一天还没有记录。'),
            _ => const Center(child: CircularProgressIndicator()),
          },
          onEditFact: busy ? null : _openFact,
          onDeleteTimeBlock: busy ? null : _deleteTimeBlock,
          onFillGap: busy ? null : _openGap,
          bottomInset: widget.reviewContext == null ? 0 : 88,
        ),
      );

  Future<void> _openGap(CivilDate date, UnresolvedSpan gap) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      final committed = await Navigator.of(context).push<RecordingLedger>(
        MaterialPageRoute<RecordingLedger>(
          builder: (_) => ActivityRecordingEntry(
            goals: widget.goals,
            context: RecordingDraftContext.gap(
              date: date,
              startedAt: gap.startedAt,
              endedAt: gap.endedAt,
            ),
            store: widget.drafts,
            entrySaver: widget.entrySaver,
            loadSuggestion: () async {
              final ledger = await widget.ledger.load(
                date: date,
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
      );
      if (mounted && committed != null) _snack('已保存到账本。');
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  /// 从详情压入编辑器；返回是否提交了正式变更，供详情页决定是否离开。
  Future<bool> _openFact(CivilDate date, LedgerSegment segment) async {
    if (busy) return false;
    setState(() => opening = true);
    var committed = false;
    try {
      final result = await Navigator.of(context).push<Object>(
        MaterialPageRoute<Object>(
          builder: (_) => switch (segment) {
            TimeBlockSegment(:final source) => ActivityRecordingEntry(
              goals: widget.goals,
              context: RecordingDraftContext.edit(
                date: date,
                timeBlockId: source.id,
              ),
              store: widget.drafts,
              entryEditor: widget.entryEditor,
              loadSuggestion: () async => const ManualTimeEntry(),
            ),
            SleepSessionSegment(:final source) => widget.sleepEntry(
              SleepDraftContext.edit(date: date, sleepSessionId: source.id),
            ),
          },
        ),
      );
      if (result != null) {
        committed = true;
        if (mounted) _snack('记录更改已应用。');
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
    return committed;
  }

  Future<void> _deleteTimeBlock(TimeBlockSegment segment) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('删除时间记录'),
          content: const Text('删除完整记录时，依附的节奏解释也会删除。'),
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
      final draftContext = RecordingDraftContext.edit(
        date: selectedDate,
        timeBlockId: segment.reference.id,
      );
      final result = await widget.entryEditor.delete(draftContext);
      if (!mounted) return;
      if (result is RecordingDeleteFailed) {
        _snack('删除失败，记录未改变，请重试。');
      } else if (result is RecordingDeleteCommitted) {
        if (!result.complete) {
          await widget.entryEditor.finishDelete(
            context: draftContext,
            draftCleared: result.draftCleared,
          );
          if (!mounted) return;
        }
        _snack('记录已删除。');
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editCompleteSleep(CivilDate date, SleepSession sleep) async {
    if (busy) return;
    setState(() => opening = true);
    try {
      await Navigator.of(context).push<SleepLedger>(
        MaterialPageRoute(
          builder: (_) => widget.sleepEntry(
            SleepDraftContext.edit(date: date, sleepSessionId: sleep.id),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  @override
  void dispose() {
    widget.dayRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayLedger = widget.dayLedger;
    if (dayLedger == null) {
      return const Scaffold(body: Center(child: Text('日账本入口尚未配置。')));
    }
    return HomeShell(
      key: homeShellKey,
      selection: selection,
      ledgerLoader: dayLedger,
      now: () => widget.now().millisecondsSinceEpoch,
      dateOfInstant: deviceDateOfInstant,
      busy: busy,
      banner: firstSleepError == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(firstSleepError!, style: const TextStyle(fontSize: 13)),
                  TextButton(
                    onPressed: busy ? null : _checkFirstSleep,
                    child: const Text('重试主睡眠检查'),
                  ),
                ],
              ),
            ),
      onMenu: _menu,
      onRecordActivity: _recordActivity,
      onRecordSleep: _recordSleep,
      reviewEnabled: widget.reviewContext != null,
      floatingCard: widget.reviewContext == null
          ? null
          : (controller) {
              final view = controller.view;
              if (view == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: HomeReviewCard(
                  loader: widget.reviewContext!,
                  date: view.date,
                  now: () => widget.now().millisecondsSinceEpoch,
                  onOpen: busy
                      ? null
                      : () => homeShellKey.currentState?.openReviewTab(),
                ),
              );
            },
      timeline: _ledgerTimeline,
      summary: (controller, _) => HomeSummaryTab(
        controller: controller,
        onEditSleep: busy
            ? null
            : (sleep) => _editCompleteSleep(selectedDate, sleep),
        onRetry: controller.refresh,
      ),
      review: (active) => _reviewPage(selectedDate, active: active),
    );
  }
}
