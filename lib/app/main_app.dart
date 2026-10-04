import 'package:flutter/material.dart';

import 'theme/time_ledger_theme.dart';
import 'navigation/ledger_shell.dart';
import '../features/ledger/presentation/day_date_selection.dart';
import '../features/ledger/presentation/day_read_scroll.dart';
import '../features/ledger/presentation/sleep_summary_view.dart';
import '../features/ledger/domain/sleep_session.dart';

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
import '../features/ledger/domain/recording_draft_store.dart';
import '../features/ledger/domain/sleep_draft_store.dart';
import '../features/ledger/presentation/recording_form.dart';

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
    theme: timeLedgerTheme,
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
    with WidgetsBindingObserver, RouteAware {
  final selection = DayDateSelection();
  final ledgerPageKey = GlobalKey<DayLedgerPageState>();
  final scrollSession = DayReadScrollSession();
  bool reviewSelected = false;
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

  Widget _activity(CivilDate date) => RecordingForm(
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

  Future<String?> _choices(
    String title,
    List<({String text, IconData icon})> choices,
  ) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              for (final choice in choices)
                ListTile(
                  leading: Icon(choice.icon),
                  title: Text(choice.text),
                  onTap: () => Navigator.pop(sheetContext, choice.text),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _create() async {
    if (busy) return;
    final date = selectedDate;
    setState(() => opening = true);
    try {
      final choice = await _choices('记录一笔', [
        (text: '记录活动', icon: Icons.article_outlined),
        (text: '记录睡眠', icon: Icons.bedtime_outlined),
      ]);
      if (!mounted) return;
      if (choice == '记录活动') {
        final result = await Navigator.of(context).push<RecordingLedger>(
          MaterialPageRoute(builder: (_) => _activity(date)),
        );
        if (mounted && result != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('已保存到账本。')));
        }
      } else if (choice == '记录睡眠') {
        await _pushSleep(date);
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  Future<void> _more() async {
    if (busy) return;
    setState(() => opening = true);
    try {
      final choice = await _choices('更多', [
        if (!reviewSelected) (text: '刷新账本', icon: Icons.refresh),
        if (!reviewSelected) (text: '时间分布说明', icon: Icons.info_outline),
        if (widget.dayLedger != null)
          (text: '当日摘要', icon: Icons.summarize_outlined),
        if (widget.goalEntry != null) (text: '目标管理', icon: Icons.flag_outlined),
      ]);
      if (!mounted) return;
      if (choice == '刷新账本') {
        ledgerPageKey.currentState?.refreshFromMenu();
      } else if (choice == '时间分布说明') {
        ledgerPageKey.currentState?.showDistribution();
      } else if (choice == '当日摘要') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => DaySummaryPage(
              loader: widget.dayLedger!,
              now: () => widget.now().millisecondsSinceEpoch,
              dateOfInstant: deviceDateOfInstant,
              routeObserver: widget.dayRoutes,
              selection: selection,
              reviewEntry: widget.reviewContext == null
                  ? null
                  : (date) => _reviewPage(date),
            ),
          ),
        );
      } else if (choice == '目标管理') {
        await Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => widget.goalEntry!()));
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
        selection.refresh();
        await _checkSleepOnReturn();
      }
    }
  }

  Widget _reviewPage(CivilDate date, {bool embedded = false}) =>
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
        embedded: embedded,
        active: !embedded || reviewSelected,
        scrollSession: embedded ? scrollSession : null,
        onInteraction: embedded
            ? (value) => _interaction(value, review: true)
            : null,
      );

  Widget _ledgerPage() => DayLedgerPage(
    key: ledgerPageKey,
    loader: widget.dayLedger!,
    now: () => widget.now().millisecondsSinceEpoch,
    dateOfInstant: deviceDateOfInstant,
    routeObserver: widget.dayRoutes,
    selection: selection,
    embedded: true,
    active: !reviewSelected,
    scrollSession: scrollSession,
    onInteraction: (value) => _interaction(value, review: false),
    completeSleep: (date, summary) => SleepSummaryView(
      summary: summary,
      onEdit: busy ? null : (sleep) => _editCompleteSleep(date, sleep),
    ),
    recordingEditor: widget.entryEditor,
    factEntry: (date, segment) => switch (segment) {
      TimeBlockSegment(:final source) => RecordingForm(
        goals: widget.goals,
        context: RecordingDraftContext.edit(date: date, timeBlockId: source.id),
        store: widget.drafts,
        entryEditor: widget.entryEditor,
        loadSuggestion: () async => const ManualTimeEntry(),
      ),
      SleepSessionSegment(:final source) => widget.sleepEntry(
        SleepDraftContext.edit(date: date, sleepSessionId: source.id),
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
  );

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

  void _destination(bool review) {
    if (busy || reviewSelected == review) return;
    setState(() => reviewSelected = review);
  }

  @override
  void dispose() {
    widget.dayRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !reviewSelected,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _destination(false);
    },
    child: LedgerShell(
      reviewSelected: reviewSelected,
      busy: busy,
      onLedger: () => _destination(false),
      onReview: widget.reviewContext == null ? null : () => _destination(true),
      onCreate: _create,
      onMore: _more,
      body: Column(
        children: [
          if (firstSleepError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(firstSleepError!),
                  TextButton(
                    onPressed: busy ? null : _checkFirstSleep,
                    child: const Text('重试主睡眠检查'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: reviewSelected ? 1 : 0,
              children: [
                if (widget.dayLedger == null)
                  const Center(child: Text('日账本入口尚未配置。'))
                else
                  Offstage(offstage: reviewSelected, child: _ledgerPage()),
                if (widget.reviewContext == null)
                  const SizedBox.shrink()
                else
                  Offstage(
                    offstage: !reviewSelected,
                    child: _reviewPage(selectedDate, embedded: true),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
